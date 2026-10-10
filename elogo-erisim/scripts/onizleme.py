#!/usr/bin/env python3
"""Fatura ÖNİZLEMESİ — değerleri UBL'in KENDİSİNDEN okur.

🔴 Niçin böyle: Sultan'ın onayladığı şey, gidecek belgenin BİREBİR kendisi olmalı.
   Kaynak veriden (fiş paketi) render etmek, "onaylanan" ile "giden" arasında sessiz
   bir fark bırakabilir. Bu yüzden önizleme kaynak veriye DEĞİL, üretilmiş UBL'e bakar.
   Portal yolunda bu mümkün değildi (tutarı portal hesaplıyordu) — servis yolunun
   asıl kazancı budur.
"""
import glob, html, os, re, sys
import xml.etree.ElementTree as ET
from decimal import Decimal as D

NS = {"cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
      "cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"}


def _t(k, yol, vars=None):
    e = k.find(yol, NS)
    return e.text.strip() if e is not None and e.text else ""


SAP_DESEN = re.compile(r"SAP\s*Belge\s*No\s*:\s*([0-9A-Za-z\-]+)")


def sap_cikar(kok, dosya: str) -> str:
    """Dayanağın KİMLİĞİ: SAP belge no. Belgenin kendi cbc:Note'undan okunur.

    🔴 Niçin Note'tan: dayanak kimliği fatura NUMARASI değildir. Numara sıralamaya göre
    kayabilir (bir test faturası araya girerse hepsi kayar); SAP belge no kaymaz.
    Dosya adı yalnız YEDEK yoldur — dosya yeniden adlandırılabilir, belge içeriği ise
    gidenin kendisidir ("kaynaktan değil üründen doğrula").
    """
    for e in kok.iter():
        if e.tag.endswith("}Note") and e.text:
            m = SAP_DESEN.search(e.text)
            if m:
                return m.group(1)
    tabani = os.path.basename(dosya)
    if "_" in tabani:
        return tabani.rsplit("_", 1)[-1].rsplit(".", 1)[0]
    return ""


def oku(dosya: str) -> dict:
    r = ET.parse(dosya).getroot()
    taraf = lambda p: {
        "unvan": _t(r, f"{p}/cac:Party/cac:PartyName/cbc:Name"),
        "vkn": _t(r, f"{p}/cac:Party/cac:PartyIdentification/cbc:ID"),
        "vd": _t(r, f"{p}/cac:Party/cac:PartyTaxScheme/cac:TaxScheme/cbc:Name"),
    }
    kalemler = []
    for k in r.findall("cac:InvoiceLine", NS):
        kalemler.append({
            "ad": _t(k, "cac:Item/cbc:Name"),
            "miktar": _t(k, "cbc:InvoicedQuantity"),
            "birim_fiyat": _t(k, "cac:Price/cbc:PriceAmount"),
            "tutar": _t(k, "cbc:LineExtensionAmount"),
            "kdv": _t(k, "cac:TaxTotal/cbc:TaxAmount"),
        })
    return {
        "sap": sap_cikar(r, dosya),
        "dosya": os.path.basename(dosya),
        "numara": _t(r, "cbc:ID"), "uuid": _t(r, "cbc:UUID"),
        "tarih": _t(r, "cbc:IssueDate"), "tip": _t(r, "cbc:InvoiceTypeCode"),
        "para": _t(r, "cbc:DocumentCurrencyCode"),
        "satici": taraf("cac:AccountingSupplierParty"),
        "alici": taraf("cac:AccountingCustomerParty"),
        "kalemler": kalemler,
        "matrah": _t(r, "cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount"),
        "kdv": _t(r, "cac:TaxTotal/cbc:TaxAmount"),
        "odenecek": _t(r, "cac:LegalMonetaryTotal/cbc:PayableAmount"),
    }


def tr(x: str) -> str:
    if not x:
        return ""
    tam, _, kes = f"{D(x):.2f}".partition(".")
    return "{:,}".format(int(tam)).replace(",", ".") + "," + kes


def metin(f: dict, dayanak: str | None = None) -> str:
    s = [f"╔══ {f['numara']} ══ {f['dosya']}",
         f"║ tarih {f['tarih']} · tip {f['tip']} · {f['para']}",
         f"║ SATICI  {f['satici']['unvan'][:46]}  VKN {f['satici']['vkn']}",
         f"║ ALICI   {f['alici']['unvan'][:46]}  VKN {f['alici']['vkn']}",
         "║"]
    for k in f["kalemler"]:
        s.append(f"║  {k['ad']:<12} {tr(k['birim_fiyat']):>16}  KDV {tr(k['kdv']):>13}")
    s += ["║",
          f"║  MATRAH     {tr(f['matrah']):>18}",
          f"║  KDV %20    {tr(f['kdv']):>18}",
          f"║  ÖDENECEK   {tr(f['odenecek']):>18}"]
    if dayanak:
        esit = D(f["odenecek"]) == D(dayanak)
        s.append(f"║  dayanak    {tr(dayanak):>18}   {'✅ BİREBİR' if esit else '🔴 FARK VAR'}")
    s.append("╚" + "═" * 52)
    return "\n".join(s)


def dayanak_coz(sap: str):
    """Dayanak tutarını NUMARA DEFTERİNDEN, SAP üzerinden çözer. Bulunamazsa None.

    🔴 BU FONKSİYON BİR KUSURUN PANZEHİRİDİR (ölçüldü 2026-08-23).
    Burada elle yazılmış bir sözlük vardı ve anahtarı FATURA NUMARASIYDI:
        {"<SERİ>…001": "<tutar-A>", "<SERİ>…002": "<tutar-B>"}
    Araya 12 TL'lik bir görünüm-testi faturası girip numaralar kayınca sözlük yalan söyledi:
      · <SERİ>…002 (küçük test faturası) → "dayanak <büyük tutar> · 🔴 FARK VAR"  = YALANCI KIRMIZI
      · <SERİ>…003 (gerçek büyük fatura) → dayanak satırı HİÇ BASILMADI          = TANIKSIZ GEÇTİ
    Yani zincirin en pahalı belgesi, dördüncü tanığın denetiminden SESSİZCE çıktı.
    Kesim defterinde anahtar zaten SAP'tı; burada numara kullanmak tutarsızlıktı.
    """
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import numara_defteri as nd
        for k in nd.canli_tahsisler():
            if k.get("sap") == sap:
                return k.get("tutar")
    except Exception:
        return None
    return None


def raporla(yol: str) -> int:
    """Üretim yolu: deseni tarar, her belgeyi dördüncü tanıkla karşılaştırır.

    🔴 NİÇİN FONKSİYON (2026-09-09): bu gövde `__main__` bloğunun içindeydi ve sınav ona
    ulaşamıyordu. Sınav bu yüzden `dayanak_coz`un mantığını KOPYALAMIŞTI — yani fikrin
    doğruluğunu ölçüyor, GÖNDERİLEN kodun çalıştığını ölçmüyordu. `dayanak_coz` tamamen
    silinse bile sınav yeşil kalıyordu (kapı-sınavı mutasyonu yakaladı).
    Gövde fonksiyona çıkınca sınav gerçek yolu çağırabiliyor; kopya mantık kalktı.

    Dönüş: 0 = her belge tanıklı · 4 = dayanağı çözülemeyen belge var.
    """
    taniksiz = []
    for d in sorted(glob.glob(yol)):
        f = oku(d)
        sap = f.get("sap", "")
        dayanak = dayanak_coz(sap) if sap else None
        print(metin(f, dayanak))
        if dayanak is None:
            taniksiz.append((f["numara"], sap or "(SAP okunamadı)"))
        print()
    # 🔴 TANIKSIZ BELGE SESSİZ KALAMAZ. Eski hâlde dayanak bulunamayınca satır hiç
    #    basılmıyordu ve belge "sorunsuz" görünüyordu — tam da <büyük tutar> TL'lik
    #    faturanın başına gelen buydu. "Ölçemedim" ≠ "eşit".
    if taniksiz:
        print("=" * 54)
        print(f"🔴 DAYANAĞI ÇÖZÜLEMEYEN BELGE: {len(taniksiz)}")
        print("   Bu 'tutar doğru' DEĞİLDİR — dördüncü tanık KOŞMADI, ölçülemedi.")
        for no, sap in taniksiz:
            print(f"   · {no}  SAP={sap}  → numara defterinde kayıt yok")
        print("=" * 54)
    return 4 if taniksiz else 0


if __name__ == "__main__":
    _desen = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "ELOGO_BELGE_DESENI", os.path.expanduser("~/evraklar-fatura/*.xml"))
    raise SystemExit(raporla(_desen))
