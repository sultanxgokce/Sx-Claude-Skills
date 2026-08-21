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
from decimal import Decimal
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
TARIH_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class EksikAlan(ValueError):
    """Zorunlu alan eksik/geçersiz — belge ÜRETİLMEZ (fail-closed)."""


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
class FaturaGovdesi:
    """İki türün de paylaştığı alanlar. Türe özel alanlar (dayanak gibi) alt sınıfta."""

    duzenleyen: Taraf             # belgeyi kesen  → UBL AccountingSupplierParty
    muhatap: Taraf                # karşı taraf    → UBL AccountingCustomerParty
    tarih: str                    # YYYY-MM-DD (düzenleme tarihi)
    kalemler: list[Kalem]
    para_birimi: str = "TRY"
    numara_modu: str = "elogo"    # "elogo" → cbc:ID boş; "verilen" → fatura_no kullanılır
    fatura_no: str = ""
    notlar: list[str] = field(default_factory=list)
    #: 🔴 ETTN — faturanın EVRENSEL kimliği. Numaradan AYRI bir şeydir:
    #: numarayı e-Logo atar (taslak→sıra numarası), ETTN'yi DÜZENLEYEN üretir ve
    #: belge boyunca değişmez. Boş bırakılırsa `kur()` anında üretilir.
    #: Ölçüldü 2026-08-22: UUID'siz belge e-Logo şema doğrulamasından GEÇMEZ.
    uuid: str = ""

    # ── toplamlar ────────────────────────────────────────────────────────────
    def matrah_kurus(self) -> int:
        return sum(k.matrah_kurus() for k in self.kalemler)

    def kdv_kurus(self) -> int:
        return sum(k.kdv_kurus() for k in self.kalemler)

    def genel_toplam_kurus(self) -> int:
        return self.matrah_kurus() + self.kdv_kurus()

    def ortak_eksikler(self) -> list[str]:
        """Her iki türde de geçerli eksikler. Türe özel olanları alt sınıf ekler."""
        eksik: list[str] = []

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
    _e(kok, "cbc", "ProfileID", "TEMELFATURA")

    # Numara: "elogo" modunda BOŞ bırakılır — e-Logo taslağa numarayı kendisi atar.
    _e(kok, "cbc", "ID", f.fatura_no if f.numara_modu == "verilen" else "")

    # 🔴 UBL 2.1 ELEMAN SIRASI KATIDIR — ID'den sonra CopyIndicator, sonra UUID gelir.
    #    Bu ikisi eksikken e-Logo şema hatası verdi (ölçüldü 2026-08-22):
    #    "invalid child element 'IssueDate' … expected: 'CopyIndicator'".
    #    Sıra bozulursa hata İÇERİKTE aranır; oysa sebep buradadır.
    _e(kok, "cbc", "CopyIndicator", "false")
    _e(kok, "cbc", "UUID", f.uuid or str(uuid_mod.uuid4()))

    _e(kok, "cbc", "IssueDate", f.tarih)
    _e(kok, "cbc", "InvoiceTypeCode", tip)
    for satir in [*(on_notlar or []), *f.notlar]:
        _e(kok, "cbc", "Note", satir)
    _e(kok, "cbc", "DocumentCurrencyCode", f.para_birimi)
    _e(kok, "cbc", "LineCountNumeric", str(len(f.kalemler)))

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
