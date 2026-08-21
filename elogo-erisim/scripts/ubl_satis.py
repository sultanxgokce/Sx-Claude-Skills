#!/usr/bin/env python3
"""
elogo-erisim · UBL-TR **SATIŞ FATURASI** kurucusu — ağsız, kontörsüz, şirketsiz.

Olağan fatura: mal/hizmet satan taraf, alan tarafa keser.
Gövde `ubl_ortak.py`'de yaşar; burada YALNIZ satışa özel olan üç şey var:

  1. `cbc:InvoiceTypeCode` = **SATIS**
  2. Zorunlu şerh **YOK** (iade faturasındaki "İADE FATURASIDIR" karşılığı yok)
  3. `cac:BillingReference` **YOK** — satış faturası bir önceki belgeye dayanmaz

🔴 İADE İLE KARIŞTIRMA — ölçülmüş fark, tercih değil:
   İade faturasında dayanak referansı ZORUNLUDUR; eksikse GİB **1150** verir.
   Satış faturasında ise dayanak GÖNDERİLMEZ. İkisi ayrı sınıflar olarak duruyor ki
   biri ötekinin kapısını miras almasın — "iade sanıp dayanak isteme" ya da
   "satış sanıp dayanağı atlama" hataları yapısal olarak imkânsız olsun.

🔴 ŞİRKETSİZ: firma adı, VKN, cari, iş adı GEÇMEZ; hepsi çağrı parametresidir.
🔴 FAIL-CLOSED: eksik alanla belge ÜRETİLMEZ.

NUMARA — bilerek üretilmiyor
----------------------------
Sultan'ın portal gözlemi (2026-08-21): fatura önce **taslak** doğar, "sıra numarası ver"
denince numarayı **e-Logo atar**, sonra gönderilir. Varsayılan `numara_modu="elogo"`
→ `cbc:ID` boş bırakılır. Lokal sayaç tutmak bilinçli REDDEDİLDİ: portalden elle kesilen
faturalarla çakışma üretir (mükerrer numara = mali müşavir düzeyinde sorun).

Tutarlar **kuruş (int)** — para float'a hiç düşmez.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from ubl_xslt import sablon_baytlari
from ubl_ortak import (  # noqa: F401  (yeniden dışa verilir — çağıran tek yerden alsın)
    KDV_ADI,
    KDV_TUR_KODU,
    TARIH_RE,
    TCKN_RE,
    VKN_RE,
    EksikAlan,
    FaturaGovdesi,
    Kalem,
    Taraf,
    belge_kur,
)

#: Satış faturasında `cbc:InvoiceTypeCode`.
SATIS_TIPI = "SATIS"


@dataclass
class SatisFaturasi(FaturaGovdesi):
    """Olağan satış faturası. Ortak gövdeye HİÇBİR alan eklemez.

    `duzenleyen` = satıcı (biz) → UBL AccountingSupplierParty
    `muhatap`    = alıcı        → UBL AccountingCustomerParty
    """

    def eksikleri_bul(self) -> list[str]:
        """Satış faturasının eksikleri = ortak eksikler.

        🔴 Burada iadedeki dayanak kapısı BİLEREK yok. Satış faturasına dayanak
           eklemek GİB tarafında belgeyi iade gibi göstermeye çalışmak olurdu.
        """
        return self.ortak_eksikler()


def kur(f: SatisFaturasi) -> str:
    """Satış faturasının UBL-TR XML'ini üretir.

    🔴 Eksik alan varsa `EksikAlan` fırlatır ve HİÇBİR ŞEY üretmez — yarım belge
       döndürmek, çağıranın onu geçerli sanmasına yol açardı.
    """
    eksik = f.eksikleri_bul()
    if eksik:
        raise EksikAlan("belge kurulamaz — eksik alanlar: " + " · ".join(eksik))

    # on_notlar boş, dayanaklar boş — satışın iadeden ayrıldığı tam yer burası.
    return belge_kur(f, tip=SATIS_TIPI, xslt=sablon_baytlari())


def sozlukten(veri: dict[str, Any]) -> SatisFaturasi:
    """JSON/sözlük → `SatisFaturasi`. Türev paketler (`fatura-<kutu>`) bunu kullanır;
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

    return SatisFaturasi(
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
        para_birimi=str(veri.get("para_birimi", "TRY")),
        numara_modu=str(veri.get("numara_modu", "elogo")),
        fatura_no=str(veri.get("fatura_no", "")),
        notlar=[str(n) for n in veri.get("notlar", [])],
    )


def _main(argv: list[str]) -> int:
    """Kuru koşum: JSON dosyasından satış faturası kurar, XML'i basar.

    Eksik varsa XML ÜRETMEZ; eksikleri adıyla listeler ve rc=1 verir.
    """
    import json
    from pathlib import Path

    if not argv:
        print("kullanım: ubl_satis.py <fatura.json> [--eksikleri-goster]", file=sys.stderr)
        return 2
    try:
        veri = json.loads(Path(argv[0]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"⛔ okunamadı: {e}", file=sys.stderr)
        return 2

    f = sozlukten(veri)
    eksik = f.eksikleri_bul()
    if "--eksikleri-goster" in argv:
        if eksik:
            print("eksikler:")
            for a in eksik:
                print(f"  • {a}")
        else:
            print("eksik YOK — belge kurulabilir")
        return 1 if eksik else 0

    try:
        print(kur(f))
    except EksikAlan as e:
        print(f"⛔ {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
