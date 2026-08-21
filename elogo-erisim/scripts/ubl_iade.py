#!/usr/bin/env python3
"""
elogo-erisim · UBL-TR **İADE FATURASI** kurucusu — ağsız, kontörsüz, şirketsiz.

NİÇİN AYRI VE SAF BİR MODÜL
---------------------------
e-Fatura'da **iptal operasyonu YOKTUR** (WSDL taraması, 2026-08-21): yanlış kesilen bir
faturanın düzeltmesi *başka bir fatura kesmektir*. Üstelik bugün geçerli bir test/sandbox
ortamı da yok (eski `pbtest.diyalogo.com.tr` DNS-ölü) ve her WS çağrısı **kontör** harcıyor.
Bu üçü birleşince "çalışana kadar dene" yaklaşımı yasaklanır.

Panzehir: belgeyi ÜRETEN kısmı taşımadan ayırmak. Bu modül ağa hiç çıkmaz, kimlik istemez,
kontör yakmaz — bu yüzden sınırsız kez, bedelsiz koşturulabilir. Gönderim hattı ancak
buradan çıkan XML doğrulandıktan sonra devreye girer.

🔴 ŞİRKETSİZ (paketleme md.1): bu dosyada hiçbir firma adı, VKN, cari ya da iş adı GEÇMEZ.
   Hepsi çağrı parametresidir. Ayırt edici test: *"bu satır ikinci bir tüzel kişide de aynı
   mı kalır?"* — kalmıyorsa buraya yazılmaz, türeve (`fatura-<kutu>`) yazılır.

🔴 FAIL-CLOSED: eksik alanla belge ÜRETİLMEZ. `eksikleri_bul()` neyin eksik olduğunu
   ADIYLA söyler; `kur()` eksik varsa `EksikAlan` fırlatır. Yarım bir faturayı sessizce
   üretip GİB'e göndermek, hiç üretmemekten çok daha pahalıdır.

NUMARA — bilerek üretilmiyor
----------------------------
Sultan'ın portal gözlemi (2026-08-21): fatura önce **taslak** doğar, sonra "sıra numarası ver"
denince numarayı **e-Logo atar**, sonra gönderilir. Bu yüzden varsayılan `numara_modu="elogo"`
→ `cbc:ID` boş bırakılır ve numara üretimi HİÇ yapılmaz.
Alternatif `numara_modu="verilen"` yalnız e-Logo desteği "numarayı siz doldurun" derse kullanılır.
Lokal sayaç tutmak bilinçli olarak REDDEDİLDİ: portalden elle kesilen faturalarla çakışma
riski üretir (mükerrer numara = mali müşavir düzeyinde sorun, yazılım hatası değil).

Tutarlar **kuruş (int)** olarak alınır — float para hesabı yapılmaz.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any
from xml.etree import ElementTree as ET

# ── UBL-TR ad alanları (sabit; TR e-fatura paketi) ────────────────────────────
NS = {
    "inv": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
    "cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
    "cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
}

#: İade faturasında `cbc:InvoiceTypeCode`. Ayrı bir "iade gönder" çağrısı YOKTUR —
#: iade normal gönderim + bu tip kodu + zorunlu `BillingReference` demektir.
IADE_TIPI = "IADE"

#: VUK 229 gereği iade faturası bu şerhi taşır (mali müşavir teyidi bekleyen madde).
IADE_SERHI = "İADE FATURASIDIR"

VKN_RE = re.compile(r"^\d{10}$")
TCKN_RE = re.compile(r"^\d{11}$")
TARIH_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class EksikAlan(ValueError):
    """Zorunlu alan eksik/geçersiz — belge ÜRETİLMEZ (fail-closed)."""


@dataclass(frozen=True)
class Taraf:
    """Fatura tarafı. İADE faturasında **iade eden** taraf `saticiTaraf` olur:
    belgeyi düzenleyen her zaman UBL'in `AccountingSupplierParty`sidir."""

    unvan: str
    vkn: str                      # 10 hane VKN ya da 11 hane TCKN
    vergi_dairesi: str = ""
    ulke: str = "Türkiye"
    il: str = ""
    ilce: str = ""
    adres: str = ""

    def kimlik_semasi(self) -> str:
        return "TCKN" if TCKN_RE.match(self.vkn or "") else "VKN"


@dataclass(frozen=True)
class Kalem:
    """Tek fatura satırı. `kdv_orani` **yüzde** (ör. 20 → %20).

    🔴 `kdv_orani=None` kabul edilmez. Kayıtlarımızda bugün yalnız 'KDV dahil/hariç'
    bayrağı var, ORAN yok (ölçüm 2026-08-21) — UBL oranı zorunlu ister, bayraktan
    oran türetilemez. Bu yüzden eksiklik sessizce doldurulmaz, RAPOR edilir.
    """

    ad: str
    miktar: Decimal
    birim: str                    # UN/ECE birim kodu: C62=adet, KGM=kg, MTQ=m³ …
    birim_fiyat_kurus: int        # KDV HARİÇ birim fiyat, kuruş
    kdv_orani: int | None = None
    aciklama: str = ""

    def matrah_kurus(self) -> int:
        # Kuruşa yuvarlama: bankacı yuvarlaması değil, olağan yuvarlama (GİB pratiği).
        toplam = Decimal(self.birim_fiyat_kurus) * self.miktar
        return int(toplam.quantize(Decimal("1")))

    def kdv_kurus(self) -> int:
        if self.kdv_orani is None:
            raise EksikAlan(f"kalem '{self.ad}': kdv_orani yok")
        return int(
            (Decimal(self.matrah_kurus()) * Decimal(self.kdv_orani) / Decimal(100)).quantize(
                Decimal("1")
            )
        )


@dataclass(frozen=True)
class Dayanak:
    """İadenin dayandığı ORİJİNAL fatura. e-Logo/GİB şematronu iade faturasında
    en az bir `cac:BillingReference` ister; eksikse GİB hata kodu **1150** döner."""

    fatura_no: str                # orijinal faturanın 16 haneli numarası
    tarih: str                    # YYYY-MM-DD


@dataclass
class IadeFaturasi:
    duzenleyen: Taraf             # iade eden (biz) → UBL AccountingSupplierParty
    muhatap: Taraf                # malı satan taraf  → UBL AccountingCustomerParty
    tarih: str                    # YYYY-MM-DD (düzenleme tarihi)
    kalemler: list[Kalem]
    dayanaklar: list[Dayanak] = field(default_factory=list)
    para_birimi: str = "TRY"
    numara_modu: str = "elogo"    # "elogo" → cbc:ID boş; "verilen" → fatura_no kullanılır
    fatura_no: str = ""
    notlar: list[str] = field(default_factory=list)

    # ── ölçüm: neyi kuramıyoruz ve NİÇİN ─────────────────────────────────────
    def eksikleri_bul(self) -> list[str]:
        """Belgeyi kurmaya YETMEYEN her alanı adıyla döndürür (boş liste = kurulabilir).

        Bu, 'veri hazır mı?' sorusunun makine cevabıdır. Sürprizi öne çeker:
        eksik varsa gönderim hattına hiç girilmez.
        """
        eksik: list[str] = []

        for etiket, taraf in (("duzenleyen", self.duzenleyen), ("muhatap", self.muhatap)):
            if not taraf.unvan.strip():
                eksik.append(f"{etiket}.unvan")
            if not (VKN_RE.match(taraf.vkn or "") or TCKN_RE.match(taraf.vkn or "")):
                eksik.append(f"{etiket}.vkn (10 hane VKN ya da 11 hane TCKN olmalı)")

        if not TARIH_RE.match(self.tarih or ""):
            eksik.append("tarih (YYYY-MM-DD)")

        if not self.kalemler:
            eksik.append("kalemler (en az bir satır)")
        for i, k in enumerate(self.kalemler, 1):
            if not k.ad.strip():
                eksik.append(f"kalem[{i}].ad")
            if k.miktar <= 0:
                eksik.append(f"kalem[{i}].miktar (>0 olmalı)")
            if not k.birim.strip():
                eksik.append(f"kalem[{i}].birim (UN/ECE kodu, ör. C62)")
            if k.birim_fiyat_kurus <= 0:
                eksik.append(f"kalem[{i}].birim_fiyat_kurus (>0 olmalı)")
            if k.kdv_orani is None:
                eksik.append(f"kalem[{i}].kdv_orani (yüzde; 'dahil/hariç' bayrağından türetilemez)")

        # Şematron kapısı: iade faturası dayanaksız olmaz.
        if not self.dayanaklar:
            eksik.append("dayanaklar (iade faturası orijinal fatura referansı ZORUNLU — GİB 1150)")
        for i, d in enumerate(self.dayanaklar, 1):
            if not d.fatura_no.strip():
                eksik.append(f"dayanaklar[{i}].fatura_no")
            if not TARIH_RE.match(d.tarih or ""):
                eksik.append(f"dayanaklar[{i}].tarih (YYYY-MM-DD)")

        if self.numara_modu not in ("elogo", "verilen"):
            eksik.append("numara_modu ('elogo' | 'verilen')")
        if self.numara_modu == "verilen" and not self.fatura_no.strip():
            eksik.append("fatura_no (numara_modu='verilen' seçildiyse zorunlu)")

        return eksik

    # ── toplamlar ────────────────────────────────────────────────────────────
    def matrah_kurus(self) -> int:
        return sum(k.matrah_kurus() for k in self.kalemler)

    def kdv_kurus(self) -> int:
        return sum(k.kdv_kurus() for k in self.kalemler)

    def genel_toplam_kurus(self) -> int:
        return self.matrah_kurus() + self.kdv_kurus()


def _tl(kurus: int) -> str:
    """Kuruş → UBL ondalık gösterimi (iki hane). Float'a hiç düşmez."""
    return f"{Decimal(kurus) / Decimal(100):.2f}"


def _e(parent: ET.Element, ns: str, ad: str, metin: str | None = None, **attrs) -> ET.Element:
    el = ET.SubElement(parent, f"{{{NS[ns]}}}{ad}", **attrs)
    if metin is not None:
        el.text = metin
    return el


def _taraf_yaz(parent: ET.Element, sarmal: str, t: Taraf) -> None:
    kok = _e(parent, "cac", sarmal)
    party = _e(kok, "cac", "Party")
    kimlik = _e(party, "cac", "PartyIdentification")
    _e(kimlik, "cbc", "ID", t.vkn, schemeID=t.kimlik_semasi())
    ad = _e(party, "cac", "PartyName")
    _e(ad, "cbc", "Name", t.unvan)
    adres = _e(party, "cac", "PostalAddress")
    if t.adres:
        _e(adres, "cbc", "StreetName", t.adres)
    if t.ilce:
        _e(adres, "cbc", "CitySubdivisionName", t.ilce)
    if t.il:
        _e(adres, "cbc", "CityName", t.il)
    ulke = _e(adres, "cac", "Country")
    _e(ulke, "cbc", "Name", t.ulke)
    if t.vergi_dairesi:
        vergi = _e(party, "cac", "PartyTaxScheme")
        sema = _e(vergi, "cac", "TaxScheme")
        _e(sema, "cbc", "Name", t.vergi_dairesi)


def kur(f: IadeFaturasi) -> str:
    """İade faturasının UBL-TR XML'ini üretir.

    🔴 Eksik alan varsa `EksikAlan` fırlatır ve HİÇBİR ŞEY üretmez — yarım belge
       döndürmek, çağıranın onu geçerli sanmasına yol açardı.
    """
    eksik = f.eksikleri_bul()
    if eksik:
        raise EksikAlan("belge kurulamaz — eksik alanlar: " + " · ".join(eksik))

    for onek, uri in NS.items():
        ET.register_namespace("" if onek == "inv" else onek, uri)

    kok = ET.Element(f"{{{NS['inv']}}}Invoice")
    _e(kok, "cbc", "UBLVersionID", "2.1")
    _e(kok, "cbc", "CustomizationID", "TR1.2")
    _e(kok, "cbc", "ProfileID", "TEMELFATURA")

    # Numara: "elogo" modunda BOŞ bırakılır — e-Logo taslağa numarayı kendisi atar.
    _e(kok, "cbc", "ID", f.fatura_no if f.numara_modu == "verilen" else "")

    _e(kok, "cbc", "IssueDate", f.tarih)
    _e(kok, "cbc", "InvoiceTypeCode", IADE_TIPI)
    for satir in [IADE_SERHI, *f.notlar]:
        _e(kok, "cbc", "Note", satir)
    _e(kok, "cbc", "DocumentCurrencyCode", f.para_birimi)
    _e(kok, "cbc", "LineCountNumeric", str(len(f.kalemler)))

    # Şematron: iade → orijinal faturaya atıf zorunlu.
    for d in f.dayanaklar:
        ref = _e(kok, "cac", "BillingReference")
        belge = _e(ref, "cac", "InvoiceDocumentReference")
        _e(belge, "cbc", "ID", d.fatura_no)
        _e(belge, "cbc", "IssueDate", d.tarih)
        _e(belge, "cbc", "DocumentTypeCode", IADE_TIPI)

    _taraf_yaz(kok, "AccountingSupplierParty", f.duzenleyen)
    _taraf_yaz(kok, "AccountingCustomerParty", f.muhatap)

    vergi_toplam = _e(kok, "cac", "TaxTotal")
    _e(vergi_toplam, "cbc", "TaxAmount", _tl(f.kdv_kurus()), currencyID=f.para_birimi)

    toplam = _e(kok, "cac", "LegalMonetaryTotal")
    _e(toplam, "cbc", "LineExtensionAmount", _tl(f.matrah_kurus()), currencyID=f.para_birimi)
    _e(toplam, "cbc", "TaxExclusiveAmount", _tl(f.matrah_kurus()), currencyID=f.para_birimi)
    _e(toplam, "cbc", "TaxInclusiveAmount", _tl(f.genel_toplam_kurus()), currencyID=f.para_birimi)
    _e(toplam, "cbc", "PayableAmount", _tl(f.genel_toplam_kurus()), currencyID=f.para_birimi)

    for i, k in enumerate(f.kalemler, 1):
        satir = _e(kok, "cac", "InvoiceLine")
        _e(satir, "cbc", "ID", str(i))
        _e(satir, "cbc", "InvoicedQuantity", f"{k.miktar:.2f}", unitCode=k.birim)
        _e(satir, "cbc", "LineExtensionAmount", _tl(k.matrah_kurus()), currencyID=f.para_birimi)

        kdv = _e(satir, "cac", "TaxTotal")
        _e(kdv, "cbc", "TaxAmount", _tl(k.kdv_kurus()), currencyID=f.para_birimi)
        alt = _e(kdv, "cac", "TaxSubtotal")
        _e(alt, "cbc", "TaxableAmount", _tl(k.matrah_kurus()), currencyID=f.para_birimi)
        _e(alt, "cbc", "TaxAmount", _tl(k.kdv_kurus()), currencyID=f.para_birimi)
        _e(alt, "cbc", "Percent", str(k.kdv_orani))

        urun = _e(satir, "cac", "Item")
        _e(urun, "cbc", "Name", k.ad)
        if k.aciklama:
            _e(urun, "cbc", "Description", k.aciklama)

        fiyat = _e(satir, "cac", "Price")
        _e(fiyat, "cbc", "PriceAmount", _tl(k.birim_fiyat_kurus), currencyID=f.para_birimi)

    ET.indent(kok, space="  ")
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(kok, encoding="unicode")


def sozlukten(veri: dict[str, Any]) -> IadeFaturasi:
    """JSON/sözlük → `IadeFaturasi`. Türev paketler (`fatura-<kutu>`) bunu kullanır;
    böylece gövde hiçbir kutunun veri şemasını bilmek zorunda kalmaz."""

    def taraf(d: dict[str, Any]) -> Taraf:
        return Taraf(
            unvan=str(d.get("unvan", "")),
            vkn=str(d.get("vkn", "")),
            vergi_dairesi=str(d.get("vergi_dairesi", "")),
            il=str(d.get("il", "")),
            ilce=str(d.get("ilce", "")),
            adres=str(d.get("adres", "")),
        )

    return IadeFaturasi(
        duzenleyen=taraf(veri.get("duzenleyen", {})),
        muhatap=taraf(veri.get("muhatap", {})),
        tarih=str(veri.get("tarih", "")),
        kalemler=[
            Kalem(
                ad=str(k.get("ad", "")),
                miktar=Decimal(str(k.get("miktar", "0"))),
                birim=str(k.get("birim", "C62")),
                birim_fiyat_kurus=int(k.get("birim_fiyat_kurus", 0)),
                kdv_orani=(None if k.get("kdv_orani") is None else int(k["kdv_orani"])),
                aciklama=str(k.get("aciklama", "")),
            )
            for k in veri.get("kalemler", [])
        ],
        dayanaklar=[
            Dayanak(fatura_no=str(d.get("fatura_no", "")), tarih=str(d.get("tarih", "")))
            for d in veri.get("dayanaklar", [])
        ],
        para_birimi=str(veri.get("para_birimi", "TRY")),
        numara_modu=str(veri.get("numara_modu", "elogo")),
        fatura_no=str(veri.get("fatura_no", "")),
        notlar=[str(n) for n in veri.get("notlar", [])],
    )


def _main(argv: list[str]) -> int:
    import json

    if len(argv) < 2 or argv[1] not in ("kur", "denetle"):
        print(
            "kullanım: ubl_iade.py denetle <veri.json>   → eksik alanları listeler (RC 2 = eksik var)\n"
            "          ubl_iade.py kur     <veri.json>   → UBL-TR XML üretir (eksikse RC 2, XML YOK)",
            file=sys.stderr,
        )
        return 2

    fatura = sozlukten(json.load(open(argv[2], encoding="utf-8")))
    eksik = fatura.eksikleri_bul()

    if argv[1] == "denetle":
        if not eksik:
            print("✓ belge kurulabilir — eksik alan yok")
            return 0
        print(f"✗ {len(eksik)} eksik alan:")
        for e in eksik:
            print(f"  · {e}")
        return 2

    if eksik:
        print(f"✗ belge KURULMADI — {len(eksik)} eksik alan:", file=sys.stderr)
        for e in eksik:
            print(f"  · {e}", file=sys.stderr)
        return 2
    print(kur(fatura))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
