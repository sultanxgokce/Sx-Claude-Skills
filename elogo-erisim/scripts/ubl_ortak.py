#!/usr/bin/env python3
"""
elogo-erisim · UBL-TR fatura **ortak gövdesi** — ağsız, kontörsüz, şirketsiz.

NİÇİN VAR
---------
Fatura iki türde kesiliyor: **SATIŞ** (olağan) ve **İADE** (alıcının satıcıya kestiği).
İkisinin UBL gövdesi neredeyse aynıdır; ayrıştıkları yer üç satırdır:

    tür         `cbc:InvoiceTypeCode`   zorunlu şerh        `cac:BillingReference`
    ─────────   ─────────────────────   ─────────────────   ──────────────────────
    SATIŞ       SATIS                   —                   —
    İADE        IADE                    "İADE FATURASIDIR"  ZORUNLU (yoksa GİB 1150)

Bu üç satır için gövdeyi ikinci kez yazmak, bir gün birinde düzeltilip ötekinde
unutulacak bir çatal üretirdi. Bu paket zaten bir çatalın bedelini ödüyor
(`elogo_ws.py` ⟂ `elogo_soap.py`) — üçüncüsü eklenmedi.

🔴 ŞİRKETSİZ: burada hiçbir firma adı, VKN, cari ya da iş adı GEÇMEZ. Hepsi çağrı
   parametresidir. Ayırt edici test: *"bu satır ikinci bir tüzel kişide de aynı mı kalır?"*

🔴 FAIL-CLOSED: eksik alanla belge ÜRETİLMEZ. Yarım bir faturayı sessizce üretip
   GİB'e göndermek, hiç üretmemekten çok daha pahalıdır.

Tutarlar **kuruş (int)** olarak taşınır — para float'a hiç düşmez.
"""
from __future__ import annotations

import base64
import re
import uuid as uuid_mod
from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from xml.etree import ElementTree as ET

# ── UBL-TR ad alanları (sabit; TR e-fatura paketi) ────────────────────────────
NS = {
    "inv": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
    "cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
    "cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
}

#: Vergi türü kodu. Üreticinin "Zorunlu Bilgiler" belgesi faturada "vergi TÜRÜ, oranı ve
#: tutarı" bulunmasını şart koşuyor. UBL-TR'de tür `TaxCategory/TaxScheme/TaxTypeCode`
#: içinde taşınır. 0015 = KDV.
KDV_TUR_KODU = "0015"
KDV_ADI = "KDV"

VKN_RE = re.compile(r"^\d{10}$")
TCKN_RE = re.compile(r"^\d{11}$")
#: Biçim süzgeçleri — VARLIK zorunluluğu iddia ETMEZ, yalnız verilmişse biçimi sınar.
EPOSTA_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")
TELEFON_RE = re.compile(r"^\+?[\d ]{10,20}$")
TARIH_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class EksikAlan(ValueError):
    """Zorunlu alan eksik/geçersiz — belge ÜRETİLMEZ (fail-closed)."""


#: 🔴 Tanınan senaryolar (cbc:ProfileID) — KAPALI KÜME.
#: Yanlış senaryo, alıcının itiraz hakkını SESSİZCE değiştirir (TEMEL'de uygulama yanıtı
#: verilemez, TİCARİ'de verilebilir) ve hiçbir yerde hata üretmez. Bu yüzden serbest metin
#: olamaz. Yeni bir senaryo gerekiyorsa buraya BİLEREK eklenir.
#: 🔴 Son üç değer 2026-08-27'de ÖLÇÜMLE eklendi: canlı `SendDocument`, İADE tipli bir
#: belgeyi reddederken izin verilen senaryoları kendi hata mesajında saydı. Uydurulmadı.
#: Eklenmeseydi iki kapı çelişirdi: `ubl_iade.IADE_SENARYOLARI` izin verir, bu küme reddederdi.
SENARYOLAR = frozenset({"TEMELFATURA", "TICARIFATURA", "IHRACAT", "YOLCUBERABERFATURA",
                        "ISTISNA", "OZELMATRAH", "IHRACKAYITLI", "SGK", "KOMISYONCU",
                        "ILAC_TIBBICIHAZ", "YATIRIMTESVIK", "IDIS",
                        #: e-Arşiv — ölçüldü 2026-09-09, 12 gerçek belgede `EARSIVFATURA`.
                        "EARSIVFATURA"})

#: 🔴 e-ARŞİV — e-Fatura mükellefi OLMAYAN alıcıya kesilen belge.
#: Biçim UYDURULMADI: kendi 12 e-Arşiv faturamızdan ölçüldü (2026-09-09).
#: Farkı YALNIZ senaryo değildir; üç şey daha ister:
#:   `cbc:IssueTime` (kök, IssueDate'ten SONRA) · üç ek `AdditionalDocumentReference`:
#:     ID=gonderimSekli   · DocumentType=KAGIT | ELEKTRONIK
#:     ID=duzenlemeTarihi · DocumentType=<HH:MM:SS>
#:     ID=EINVOICE        · DocumentType=2
#: (`LineCountNumeric` zaten yazılıyordu.)
EARSIV_SENARYO = "EARSIVFATURA"
#: Ölçülen 12 belgenin 12'sinde `KAGIT`. ELEKTRONIK alıcıya e-posta ile gönderim demektir
#: ve alıcı e-postası ister — bizde o alan yok, bu yüzden varsayılan KAGIT.
EARSIV_GONDERIM = frozenset({"KAGIT", "ELEKTRONIK"})
SAAT_RE = re.compile(r"^\d{2}:\d{2}:\d{2}$")


def _simdi_saat() -> str:
    from datetime import datetime
    return datetime.now().strftime("%H:%M:%S")
#: e-Logo biçim kuralı: 3 serbest harf + 4 hane yıl + 9 hane rakam = 16 karakter.
NUMARA_RE = re.compile(r"^[A-Z]{3}\d{4}\d{9}$")
PARA_RE = re.compile(r"^[A-Z]{3}$")


@dataclass(frozen=True)
class Taraf:
    """Fatura tarafı. Belgeyi DÜZENLEYEN her zaman UBL'in `AccountingSupplierParty`sidir —
    satışta satıcı, iadede iade eden. Rol değişir, konum değişmez."""

    unvan: str
    vkn: str                      # 10 hane VKN ya da 11 hane TCKN
    vergi_dairesi: str = ""
    ulke: str = "Türkiye"
    il: str = ""
    ilce: str = ""
    adres: str = ""
    # ── şahıs (TCKN) ve iletişim — e-Arşiv'in ihtiyaç duyduğu alanlar (2026-08-25) ──
    telefon: str = ""      # cac:Contact/cbc:Telephone
    eposta: str = ""       # cac:Contact/cbc:ElectronicMail
    ad: str = ""           # cac:Person/cbc:FirstName  — gerçek kişi
    soyad: str = ""        # cac:Person/cbc:FamilyName — gerçek kişi

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
    # ── İSKONTO (2026-08-29) — biçim UYDURULMADI, GERÇEK faturadan ölçüldü ──
    #: 263 gelen e-Faturanın **240'ında** `cac:AllowanceCharge` var; yapı şu (ölçülen örnek:
    #: brüt 62,50 · oran %30 · iskonto 18,75 · LineExtension 43,75 · KDV 8,75):
    #:   satır : ChargeIndicator=false · MultiplierFactorNumeric=<oran> · Amount=<tutar>
    #:           (LineExtensionAmount'tan SONRA, TaxTotal'dan ÖNCE)
    #:   belge : aynı yapı, oran 0, Amount=<toplam> · + LegalMonetaryTotal/AllowanceTotalAmount
    #:   PriceAmount = **BRÜT** birim fiyat (iskonto öncesi)
    #: 🔴 `birim_fiyat_kurus` bu yüzden BRÜT'tür; matrah ondan iskonto DÜŞÜLEREK bulunur.
    iskonto_kurus: int = 0
    #: Yüzde. Verilirse **çapraz kontrol** edilir: oran×brüt, tutarı AÇIKLAMALIDIR.
    #: Tutar orandan TÜRETİLMEZ — türetseydik tek tanık olurdu; ikisi birbirini sınar.
    iskonto_orani: Decimal | None = None

    def brut_kurus(self) -> int:
        toplam = Decimal(self.birim_fiyat_kurus) * self.miktar
        return int(toplam.quantize(Decimal("1"), rounding=ROUND_HALF_UP))

    def iskonto_eksikleri(self) -> list[str]:
        """🔴 Fail-closed: anlamsız iskonto belge kurmaz."""
        e: list[str] = []
        if self.iskonto_kurus < 0:
            e.append(f"kalem '{self.ad}': iskonto negatif ({self.iskonto_kurus})")
        if self.iskonto_kurus > self.brut_kurus():
            e.append(f"kalem '{self.ad}': iskonto brütten büyük "
                     f"({self.iskonto_kurus} > {self.brut_kurus()})")
        if self.iskonto_orani is not None:
            if self.iskonto_orani < 0 or self.iskonto_orani > 100:
                e.append(f"kalem '{self.ad}': iskonto oranı aralık dışı ({self.iskonto_orani})")
            else:
                bekle = int((Decimal(self.brut_kurus()) * self.iskonto_orani / Decimal(100))
                            .quantize(Decimal("1"), rounding=ROUND_HALF_UP))
                if bekle != self.iskonto_kurus:
                    e.append(f"kalem '{self.ad}': iskonto ORANI tutarı AÇIKLAMIYOR — "
                             f"brüt {self.brut_kurus()} × %{self.iskonto_orani} = {bekle}, "
                             f"verilen {self.iskonto_kurus}")
        return e

    def matrah_kurus(self) -> int:
        # 🔴 Kuruşa yuvarlama: bankacı yuvarlaması DEĞİL, olağan yuvarlama (GİB pratiği).
        # ROUND_HALF_UP AÇIKÇA yazılır — argümansız `quantize` Python'da bağlam varsayılanını
        # kullanır ve o varsayılan ROUND_HALF_EVEN'dır, yani TAM DA bankacı yuvarlaması.
        # Yorum "bankacı değil" diyordu, kod bankacı yapıyordu (ölçüldü 2026-08-23, iki ajan
        # bağımsız doğruladı). Bkz. sınıf altındaki uzun not.
        # 🔴 İSKONTO DÜŞÜLMÜŞ tutardır (UBL `LineExtensionAmount` ile aynı şey).
        #    Ölçülen gerçek fatura: 62,50 brüt − 18,75 iskonto = 43,75 LineExtension,
        #    ve KDV 43,75 üzerinden hesaplanmış (8,75). iskonto_kurus=0 iken davranış
        #    ESKİSİYLE BİREBİR aynıdır — regresyon sınavda kilitli.
        return self.brut_kurus() - self.iskonto_kurus

    def kdv_kurus(self) -> int:
        if self.kdv_orani is None:
            raise EksikAlan(f"kalem '{self.ad}': kdv_orani yok")
        return int(
            (Decimal(self.matrah_kurus()) * Decimal(self.kdv_orani) / Decimal(100)).quantize(
                Decimal("1"), rounding=ROUND_HALF_UP
            )
        )


@dataclass(frozen=True)
class Dayanak:
    """İadenin dayandığı ORİJİNAL fatura. e-Logo/GİB şematronu iade faturasında
    en az bir `cac:BillingReference` ister; eksikse GİB hata kodu **1150** döner."""

    fatura_no: str                # orijinal faturanın 16 haneli numarası
    tarih: str                    # YYYY-MM-DD


@dataclass
class FaturaGovdesi:
    """İki türün de paylaştığı alanlar. Türe özel alanlar (dayanak gibi) alt sınıfta."""

    duzenleyen: Taraf             # belgeyi kesen  → UBL AccountingSupplierParty
    muhatap: Taraf                # karşı taraf    → UBL AccountingCustomerParty
    tarih: str                    # YYYY-MM-DD (düzenleme tarihi)
    kalemler: list[Kalem]
    para_birimi: str = "TRY"
    #: 🔴 SENARYO (cbc:ProfileID) — 2026-08-22 düzeltmesi.
    #: Önceden sabit "TEMELFATURA" gönderiliyordu; Sultan'ın elle kestiği faturalar
    #: **TICARIFATURA** kullanıyor (örnek fatura görüntüsüyle doğrulandı).
    #: Fark davranışsaldır: TİCARİ faturada alıcı kabul/red (uygulama yanıtı) verebilir,
    #: TEMEL faturada veremez. Yanlış senaryo, alıcının itiraz hakkını sessizce değiştirir.
    #: Sabit yerine ALAN yapıldı: iade/istisna gibi belgeler başka senaryo isteyebilir.
    senaryo: str = "TICARIFATURA"
    numara_modu: str = "elogo"    # "elogo" → cbc:ID boş; "verilen" → fatura_no kullanılır
    fatura_no: str = ""
    notlar: list[str] = field(default_factory=list)
    #: 🔴 ETTN — faturanın EVRENSEL kimliği. Numaradan AYRI bir şeydir:
    #: numarayı e-Logo atar (taslak→sıra numarası), ETTN'yi DÜZENLEYEN üretir ve
    #: belge boyunca değişmez. Boş bırakılırsa `kur()` anında üretilir.
    #: Ölçüldü 2026-08-22: UUID'siz belge e-Logo şema doğrulamasından GEÇMEZ.
    uuid: str = ""
    #: 🔴 e-ARŞİVDE ZORUNLU (`cbc:IssueTime`). e-Faturada bugüne dek yazılmıyordu ve
    #: kabul edildi; e-Arşiv belgelerinin 12'sinde de VAR. Boşsa e-Arşiv yolunda üretilir.
    saat: str = ""
    #: e-Arşiv gönderim şekli — `KAGIT` (varsayılan, ölçülen 12/12) ya da `ELEKTRONIK`.
    gonderim_sekli: str = "KAGIT"

    # ── toplamlar ────────────────────────────────────────────────────────────
    def matrah_kurus(self) -> int:
        return sum(k.matrah_kurus() for k in self.kalemler)

    def kdv_kurus(self) -> int:
        return sum(k.kdv_kurus() for k in self.kalemler)

    def iskonto_kurus(self) -> int:
        return sum(k.iskonto_kurus for k in self.kalemler)

    def genel_toplam_kurus(self) -> int:
        return self.matrah_kurus() + self.kdv_kurus()

    def ortak_eksikler(self) -> list[str]:
        """Her iki türde de geçerli eksikler. Türe özel olanları alt sınıf ekler."""
        eksik: list[str] = []
        # 🔴 İskonto doğrulaması BURADA çağrılır — `Kalem.iskonto_eksikleri()` yazılmış
        #    ama çağrılmamış olsaydı "yazılmış ≠ bağlanmış" ailesine katılırdı.
        for k in self.kalemler:
            eksik.extend(k.iskonto_eksikleri())
        # 🔴 e-ARŞİV kapısı — senaryo EARSIVFATURA ise ek alanlar ZORUNLU.
        if getattr(self, "senaryo", "") == EARSIV_SENARYO:
            if self.gonderim_sekli not in EARSIV_GONDERIM:
                eksik.append(f"gonderim_sekli '{self.gonderim_sekli}' tanınmıyor "
                             f"(izinli: {' · '.join(sorted(EARSIV_GONDERIM))})")
            if self.saat and not SAAT_RE.match(self.saat):
                eksik.append(f"saat '{self.saat}' biçimsiz — HH:MM:SS bekleniyor")
            # e-Arşiv e-Fatura MÜKELLEFİNE kesilemez (belge s.1). Kimlik TCKN ise
            # şahıstır, sorun yok; VKN ise mükellef OLABİLİR → çağıran ölçmüş olmalı.

        # 🔴 KAPALI KÜME KAPILARI (2026-08-23'te eklendi — üçü de ÖLÇÜLMÜŞ boşluktu).
        # Ölçüm: `senaryo="SAHTESENARYO"` hiçbir yerde reddedilmiyor, olduğu gibi
        # cbc:ProfileID'ye yazılıyordu; `fatura_no="XY"` ile belge sorunsuz kuruluyordu.
        # 16-hane kuralı yalnız numara ÜRETECİNDE (numara_defteri) yaşıyordu, belge
        # KURUCUSUNDA yoktu — elle numara veren her çağrı o kapının dışındaydı.
        if self.senaryo not in SENARYOLAR:
            eksik.append(f"senaryo '{self.senaryo}' tanınmıyor "
                         f"(kapalı küme: {' · '.join(sorted(SENARYOLAR))})")
        if self.numara_modu not in ("elogo", "verilen"):
            eksik.append(f"numara_modu '{self.numara_modu}' tanınmıyor (elogo | verilen)")
        if self.numara_modu == "verilen":
            if not NUMARA_RE.match(self.fatura_no or ""):
                eksik.append(f"fatura_no '{self.fatura_no}' biçimsiz — e-Logo kuralı: "
                             "3 harf + 4 hane yıl + 9 hane rakam = 16 karakter "
                             "(örn. ABC2026000000001)")
            elif self.tarih and TARIH_RE.match(self.tarih) and self.fatura_no[3:7] != self.tarih[:4]:
                # 🔴 Numaranın yılı BELGENİN yılı olmalı — numara defterindeki yıl kapısının
                #    belge tarafındaki eşi. İkisi ayrı yerlerde yaşadığı için ayrı ayrı sorulur.
                eksik.append(f"fatura_no yılı ({self.fatura_no[3:7]}) belge tarihiyle "
                             f"({self.tarih[:4]}) uyuşmuyor")
        if not PARA_RE.match(self.para_birimi or ""):
            eksik.append(f"para_birimi '{self.para_birimi}' biçimsiz (ISO 4217, örn. TRY)")

        for etiket, taraf in (("duzenleyen", self.duzenleyen), ("muhatap", self.muhatap)):
            if not taraf.unvan.strip():
                eksik.append(f"{etiket}.unvan")
            if not (VKN_RE.match(taraf.vkn or "") or TCKN_RE.match(taraf.vkn or "")):
                eksik.append(f"{etiket}.vkn (10 hane VKN ya da 11 hane TCKN olmalı)")

        # 🔴 Üreticinin "Zorunlu Bilgiler" belgesine göre DÜZENLEYEN tarafı için "iş adresi"
        # ve "bağlı olduğu vergi dairesi" ZORUNLUDUR; MUHATAP için aynı belge "VARSA vergi
        # dairesi" diyor → onda zorunlu DEĞİL. Asimetri bilinçlidir ve kaynağı üreticinin
        # kendi metnidir, bizim yorumumuz değil.
        if not self.duzenleyen.vergi_dairesi.strip():
            eksik.append("duzenleyen.vergi_dairesi (üretici: 'bağlı olduğu vergi dairesi' zorunlu)")
        if not self.duzenleyen.adres.strip():
            eksik.append("duzenleyen.adres (üretici: 'iş adresi' zorunlu)")

        # 🔴 ŞAHIS (TCKN) muhatap — biçim sınaması, ZORUNLULUK İDDİASI DEĞİL.
        #    e-posta ve telefonun UBL-TR'de zorunlu olup olmadığını ÖLÇMEDİK; bu yüzden
        #    yokluğu REDDEDİLMEZ. Reddetmek, ölçmediğimiz bir kuralı dayatmak olurdu.
        #    Ama VARSA biçimi sınanır: bozuk e-posta, yok olan e-postadan kötüdür —
        #    ikincisi belli, birincisi doğru sanılır. (Aynı aile: "eşit ≠ doğrulandı".)
        for etiket, taraf in (("duzenleyen", self.duzenleyen), ("muhatap", self.muhatap)):
            if taraf.eposta and not EPOSTA_RE.match(taraf.eposta):
                eksik.append(f"{etiket}.eposta biçimsiz: {taraf.eposta!r}")
            if taraf.telefon and not TELEFON_RE.match(taraf.telefon):
                eksik.append(f"{etiket}.telefon biçimsiz (rakam/boşluk/+ dışında karakter "
                             f"ya da 10-15 hane değil): {taraf.telefon!r}")

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

        if self.numara_modu not in ("elogo", "verilen"):
            eksik.append("numara_modu ('elogo' | 'verilen')")
        if self.numara_modu == "verilen" and not self.fatura_no.strip():
            eksik.append("fatura_no (numara_modu='verilen' seçildiyse zorunlu)")

        return eksik


# ── XML yardımcıları ─────────────────────────────────────────────────────────
def _tl(kurus: int) -> str:
    """Kuruş → UBL ondalık gösterimi (iki hane). Float'a hiç düşmez."""
    return f"{Decimal(kurus) / Decimal(100):.2f}"

def _oran_metni(o) -> str:
    """İskonto oranını KISALTMADAN yazar. Yoksa "0" (ölçülen fatura deseni).

    En az iki ondalık (30 → "30.00") çünkü ölçülen gerçek faturalarda oran iki haneli
    yazılıyor; ama daha hassas bir oran geldiğinde (70,122) o hassasiyet KORUNUR.
    Bilimsel gösterim üretilmez — XML'e "7E+1" yazmak okuyanı bozar.
    """
    if o is None:
        return "0"
    d = Decimal(o).normalize()
    if -1 < d.as_tuple().exponent < 0 or d == d.to_integral_value():
        pass
    m = format(d, "f")
    if "." not in m:
        m += ".00"
    elif len(m.split(".")[1]) == 1:
        m += "0"
    return m


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

    # ── cac:Contact ve cac:Person ──────────────────────────────────────────────
    # 🔴 SIRA İDDİASI — [ANLATI: UBL 2.1 Party sıralaması], ÖLÇÜLMEDİ.
    #    UBL katı sıralıdır ve yanlış sıra belgeyi reddettirir. Elimizde UBL-TR XSD'si
    #    YOK ve e-Logo'ca kabul edilmiş bir ŞAHIS belgesi de yok — yani bu sıra bugün
    #    doğrulanamadı. İddia şu: Party içinde ... PostalAddress → PartyTaxScheme →
    #    Contact → Person. Kaynağı standart bilgisi, ölçüm DEĞİL.
    #    🔴 İlk gerçek şahıs faturasından ÖNCE `GetDocumentPreView` ile doğrulanmalıdır;
    #    o doğrulama yapılana kadar bu blok "çalışıyor" SAYILMAZ. Sınav yalnız kodun bu
    #    sırayı ÜRETTİĞİNİ kilitler — e-Logo'nun onu KABUL ettiğini değil.
    #    (Aynı ders: "eşit ≠ doğrulandı" — kendi ürettiğimizi kendi niyetimize karşı
    #     doğrulamak, zincirin öteki ucunu sormamaktır.)
    if t.telefon or t.eposta:
        iletisim = _e(party, "cac", "Contact")
        if t.telefon:
            _e(iletisim, "cbc", "Telephone", t.telefon)
        if t.eposta:
            _e(iletisim, "cbc", "ElectronicMail", t.eposta)
    if t.ad or t.soyad:
        kisi = _e(party, "cac", "Person")
        if t.ad:
            _e(kisi, "cbc", "FirstName", t.ad)
        if t.soyad:
            _e(kisi, "cbc", "FamilyName", t.soyad)


def belge_kur(f: FaturaGovdesi, *, tip: str, on_notlar: list[str] | None = None,
              dayanaklar: list[Dayanak] | None = None, xslt: bytes | None = None) -> str:
    """UBL-TR XML gövdesini üretir. Doğrulama ÇAĞIRANIN sorumluluğudur —
    tür-özel eksikleri ancak o bilir, bu yüzden `kur()` sarmalayıcıları kontrol eder.

    `tip`        → `cbc:InvoiceTypeCode` (SATIS | IADE)
    `on_notlar`  → kullanıcı notlarından ÖNCE gelen zorunlu şerhler (iade şerhi gibi)
    `dayanaklar` → `cac:BillingReference` satırları (yalnız iadede dolu)
    """
    for onek, uri in NS.items():
        ET.register_namespace("" if onek == "inv" else onek, uri)

    kok = ET.Element(f"{{{NS['inv']}}}Invoice")
    _e(kok, "cbc", "UBLVersionID", "2.1")
    _e(kok, "cbc", "CustomizationID", "TR1.2")
    _e(kok, "cbc", "ProfileID", getattr(f, "senaryo", "TICARIFATURA"))

    # Numara: "elogo" modunda BOŞ bırakılır — e-Logo taslağa numarayı kendisi atar.
    _e(kok, "cbc", "ID", f.fatura_no if f.numara_modu == "verilen" else "")

    # 🔴 UBL 2.1 ELEMAN SIRASI KATIDIR — ID'den sonra CopyIndicator, sonra UUID gelir.
    #    Bu ikisi eksikken e-Logo şema hatası verdi (ölçüldü 2026-08-22):
    #    "invalid child element 'IssueDate' … expected: 'CopyIndicator'".
    #    Sıra bozulursa hata İÇERİKTE aranır; oysa sebep buradadır.
    _e(kok, "cbc", "CopyIndicator", "false")
    _e(kok, "cbc", "UUID", f.uuid or str(uuid_mod.uuid4()))

    _e(kok, "cbc", "IssueDate", f.tarih)
    # 🔴 SIRA: IssueDate → IssueTime → InvoiceTypeCode (gerçek e-Arşiv belgesinden ölçüldü)
    if getattr(f, "senaryo", "") == EARSIV_SENARYO:
        _e(kok, "cbc", "IssueTime", f.saat or _simdi_saat())
    _e(kok, "cbc", "InvoiceTypeCode", tip)
    for satir in [*(on_notlar or []), *f.notlar]:
        _e(kok, "cbc", "Note", satir)
    _e(kok, "cbc", "DocumentCurrencyCode", f.para_birimi)
    _e(kok, "cbc", "LineCountNumeric", str(len(f.kalemler)))

    # 🔴 e-ARŞİV ÜÇLÜSÜ — LineCountNumeric'ten SONRA, XSLT ekinden ÖNCE (ölçülen sıra).
    if getattr(f, "senaryo", "") == EARSIV_SENARYO:
        for kimlik, deger in (("gonderimSekli", f.gonderim_sekli),
                              ("duzenlemeTarihi", f.saat or _simdi_saat()),
                              ("EINVOICE", "2")):
            ek = _e(kok, "cac", "AdditionalDocumentReference")
            _e(ek, "cbc", "ID", kimlik)
            _e(ek, "cbc", "IssueDate", f.tarih)
            _e(ek, "cbc", "DocumentType", deger)

    for d in dayanaklar or []:
        ref = _e(kok, "cac", "BillingReference")
        belge = _e(ref, "cac", "InvoiceDocumentReference")
        _e(belge, "cbc", "ID", d.fatura_no)
        _e(belge, "cbc", "IssueDate", d.tarih)
        _e(belge, "cbc", "DocumentTypeCode", tip)

    # 🔴 GÖRÜNÜM ŞABLONU — belgesiz gönderim reddedilir (ölçüldü 2026-08-22).
    #    Hesapta tanımlı tasarım yoksa tek yol şablonu belgeye GÖMMEKTİR.
    #    UBL sıralaması duyarlıdır: BillingReference'tan SONRA, taraflardan ÖNCE.
    if xslt:
        ek = _e(kok, "cac", "AdditionalDocumentReference")
        _e(ek, "cbc", "ID", f.fatura_no or "XSLT")
        _e(ek, "cbc", "IssueDate", f.tarih)
        _e(ek, "cbc", "DocumentType", "XSLT")
        iliskli = _e(ek, "cac", "Attachment")
        _e(iliskli, "cbc", "EmbeddedDocumentBinaryObject",
           base64.b64encode(xslt).decode("ascii"),
           mimeCode="application/xml", encodingCode="Base64",
           filename=f"{f.fatura_no or 'fatura'}.xslt")

    _taraf_yaz(kok, "AccountingSupplierParty", f.duzenleyen)
    _taraf_yaz(kok, "AccountingCustomerParty", f.muhatap)

    # 🔴 BELGE DÜZEYİ İSKONTO — konum ÖLÇÜLDÜ (2026-08-29, gerçek gelen fatura):
    #    kök sırası … AccountingCustomerParty · PaymentTerms · **AllowanceCharge** ·
    #    TaxTotal · LegalMonetaryTotal. Yani taraflardan SONRA, TaxTotal'dan ÖNCE.
    #    Belge düzeyinde `MultiplierFactorNumeric` **0**'dır (oran satırda yaşar);
    #    `Amount` satır iskontolarının TOPLAMIDIR.
    #    ⏸ [ANLATI] Ölçülen faturalar ayrıca `ChargeIndicator=true` + `Amount=0.00`
    #    (artırım) bloğu da yazıyor. ZORUNLU olup olmadığı ÖLÇÜLMEDİ; bizde artırım
    #    kavramı yok, o blok yazılmıyor. Reddedilirse sebebi ilk burada aranmalı.
    if f.iskonto_kurus():
        ind = _e(kok, "cac", "AllowanceCharge")
        _e(ind, "cbc", "ChargeIndicator", "false")
        _e(ind, "cbc", "MultiplierFactorNumeric", "0")
        _e(ind, "cbc", "Amount", _tl(f.iskonto_kurus()), currencyID=f.para_birimi)

    # 🔴 BELGE DÜZEYİ KDV ÖZETİ — yalnız toplam tutar YETMEZ (ölçüldü 2026-08-22):
    #    e-Logo şeması "TaxTotal has incomplete content … expected: TaxSubtotal" dedi.
    #    UBL, belge toplamının KDV ORANI BAZINDA dökümünü ister. Bu aynı zamanda
    #    muhasebenin doğru gösterimidir: %20 ve %10 kalemler tek torbada toplanmaz.
    vergi_toplam = _e(kok, "cac", "TaxTotal")
    _e(vergi_toplam, "cbc", "TaxAmount", _tl(f.kdv_kurus()), currencyID=f.para_birimi)

    gruplar: dict[int, list[int]] = {}          # oran → [matrah, kdv]
    for k in f.kalemler:
        g = gruplar.setdefault(int(k.kdv_orani or 0), [0, 0])
        g[0] += k.matrah_kurus()
        g[1] += k.kdv_kurus()
    for oran in sorted(gruplar):
        matrah, kdv = gruplar[oran]
        alt = _e(vergi_toplam, "cac", "TaxSubtotal")
        _e(alt, "cbc", "TaxableAmount", _tl(matrah), currencyID=f.para_birimi)
        _e(alt, "cbc", "TaxAmount", _tl(kdv), currencyID=f.para_birimi)
        _e(alt, "cbc", "Percent", str(oran))
        kategori = _e(alt, "cac", "TaxCategory")
        sema = _e(kategori, "cac", "TaxScheme")
        _e(sema, "cbc", "Name", KDV_ADI)
        _e(sema, "cbc", "TaxTypeCode", KDV_TUR_KODU)

    toplam = _e(kok, "cac", "LegalMonetaryTotal")
    _e(toplam, "cbc", "LineExtensionAmount", _tl(f.matrah_kurus()), currencyID=f.para_birimi)
    _e(toplam, "cbc", "TaxExclusiveAmount", _tl(f.matrah_kurus()), currencyID=f.para_birimi)
    _e(toplam, "cbc", "TaxInclusiveAmount", _tl(f.genel_toplam_kurus()), currencyID=f.para_birimi)
    # 🔴 Sıra ÖLÇÜLDÜ: LineExtension · TaxExclusive · TaxInclusive · **AllowanceTotal** · Payable
    if f.iskonto_kurus():
        _e(toplam, "cbc", "AllowanceTotalAmount", _tl(f.iskonto_kurus()),
           currencyID=f.para_birimi)
    _e(toplam, "cbc", "PayableAmount", _tl(f.genel_toplam_kurus()), currencyID=f.para_birimi)

    for i, k in enumerate(f.kalemler, 1):
        satir = _e(kok, "cac", "InvoiceLine")
        _e(satir, "cbc", "ID", str(i))
        _e(satir, "cbc", "InvoicedQuantity", f"{k.miktar:.2f}", unitCode=k.birim)
        _e(satir, "cbc", "LineExtensionAmount", _tl(k.matrah_kurus()), currencyID=f.para_birimi)

        # 🔴 SATIR İSKONTOSU — konum ÖLÇÜLDÜ: LineExtensionAmount'tan SONRA, TaxTotal'dan
        #    ÖNCE. Satırda `MultiplierFactorNumeric` GERÇEK ORANDIR (ölçülen: 30.00);
        #    oran verilmemişse 0 yazılır — ölçülen faturalarda da öyle.
        if k.iskonto_kurus:
            ind = _e(satir, "cac", "AllowanceCharge")
            _e(ind, "cbc", "ChargeIndicator", "false")
            # 🔴 ORAN KISALTILMAZ (MUHASİP ölçümü, 2026-09-30): eski kod `:.2f` ile iki haneye
            #    kırpıyordu. Gerçek tedarikçi faturasında oran 70,122 idi; "70.12" yazılınca
            #    okuyan 47.304,00 × %70,12 = 33.169,56 hesaplıyor, bizim yazdığımız tutar ise
            #    33.170,51 — 95 kuruşluk GÖRÜNÜR tutarsızlık. Tutar doğru olduğu için kuruş
            #    kapısı bunu GÖRMÜYORDU: tutarı sınıyor, oran METNİNİ sınamıyordu (sahte yeşil).
            #    Çare kapıyı onarmak değil, oranı olduğu gibi yazmaktır.
            _e(ind, "cbc", "MultiplierFactorNumeric", _oran_metni(k.iskonto_orani))
            _e(ind, "cbc", "Amount", _tl(k.iskonto_kurus), currencyID=f.para_birimi)

        kdv = _e(satir, "cac", "TaxTotal")
        _e(kdv, "cbc", "TaxAmount", _tl(k.kdv_kurus()), currencyID=f.para_birimi)
        alt = _e(kdv, "cac", "TaxSubtotal")
        _e(alt, "cbc", "TaxableAmount", _tl(k.matrah_kurus()), currencyID=f.para_birimi)
        _e(alt, "cbc", "TaxAmount", _tl(k.kdv_kurus()), currencyID=f.para_birimi)
        _e(alt, "cbc", "Percent", str(k.kdv_orani))
        # Vergi TÜRÜ (oran/tutar yetmez — üretici belgesi üçünü birden istiyor).
        kategori = _e(alt, "cac", "TaxCategory")
        sema = _e(kategori, "cac", "TaxScheme")
        _e(sema, "cbc", "Name", KDV_ADI)
        _e(sema, "cbc", "TaxTypeCode", KDV_TUR_KODU)

        urun = _e(satir, "cac", "Item")
        _e(urun, "cbc", "Name", k.ad)
        if k.aciklama:
            _e(urun, "cbc", "Description", k.aciklama)

        fiyat = _e(satir, "cac", "Price")
        _e(fiyat, "cbc", "PriceAmount", _tl(k.birim_fiyat_kurus), currencyID=f.para_birimi)

    ET.indent(kok, space="  ")
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(kok, encoding="unicode")
