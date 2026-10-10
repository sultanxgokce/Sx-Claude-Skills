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

import sys
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any

# 🔴 GÖVDE ORTAK (2026-08-22): SATIŞ ve İADE faturası aynı UBL gövdesini paylaşır; ayrıştıkları
#    yer üç satırdır (tür kodu · zorunlu şerh · dayanak referansı). Gövdeyi ikinci kez yazmak,
#    bir gün birinde düzeltilip ötekinde unutulacak bir çatal üretirdi. Bu paket zaten bir
#    çatalın bedelini ödüyor (elogo_ws.py ⟂ elogo_soap.py) — üçüncüsü açılmadı.
#    Aşağıdaki yeniden-dışa-verme BİLEREKtir: `from ubl_iade import Taraf, Kalem` diye çağıran
#    mevcut kod (ve 55 kapılık sınav) hiç değişmeden çalışmaya devam etsin diye.
from ubl_xslt import sablon_baytlari
from ubl_ortak import (  # noqa: F401  (yeniden dışa verilir — geriye uyum)
    NS,
    KDV_ADI,
    KDV_TUR_KODU,
    TARIH_RE,
    TCKN_RE,
    VKN_RE,
    Dayanak,
    EksikAlan,
    FaturaGovdesi,
    Kalem,
    Taraf,
    _e,
    _taraf_yaz,
    _tl,
    belge_kur,
)

#: İade faturasında `cbc:InvoiceTypeCode`. Ayrı bir "iade gönder" çağrısı YOKTUR —
#: iade normal gönderim + bu tip kodu + zorunlu `BillingReference` demektir.
IADE_TIPI = "IADE"

#: VUK 229 gereği iade faturası bu şerhi taşır (mali müşavir teyidi bekleyen madde).
IADE_SERHI = "İADE FATURASIDIR"

#: 🔴 İADE tipinde İZİN VERİLEN senaryolar (cbc:ProfileID) — KAPALI KÜME.
#: Kaynak ÖLÇÜM, tahmin değil: canlı `SendDocument` 2026-08-27'de `resultCode=-1` ile
#: reddetti ve izin verilen kümeyi kendi mesajında saydı:
#:   "Fatura tipi (cbc:InvoiceTypeCode) IADE iken fatura senaryosu sadece TEMELFATURA,
#:    ILAC_TIBBICIHAZ, YATIRIMTESVIK veya IDIS olabilir."
#: ⚠️ `GetDocumentPreView` bu belgeye `resultCode=1` VERDİ ve görselini üretti.
#:    Yani ÖNİZLEME BİR DOĞRULAMA KAPISI DEĞİLDİR: senaryo–tip uyumunu sınamıyor.
#:    "Önizleme geçti" cümlesi "gönderim geçer" anlamına GELMEZ; ikisi ayrı kapıdır.
#: 🔴 Bunun bir de İŞ sonucu var: satışta TICARIFATURA kullanıyoruz, iadede kullanamayız.
#:    TEMEL faturada alıcı ticari uygulama yanıtı (kabul/red) VEREMEZ — itiraz yolu değişir.
#:    Bu bizim tercihimiz değil, GİB/e-Logo şartı; ama sessiz geçilmemesi gereken bir farktır.
IADE_SENARYOLARI = frozenset({"TEMELFATURA", "ILAC_TIBBICIHAZ", "YATIRIMTESVIK", "IDIS"})


@dataclass
class IadeFaturasi(FaturaGovdesi):
    """İADE faturası. Ortak gövdeye TEK ekleme yapar: dayanak (orijinal fatura referansı).

    `duzenleyen` = iade eden (biz) → UBL AccountingSupplierParty
    `muhatap`    = malı satan taraf → UBL AccountingCustomerParty
    """

    dayanaklar: list[Dayanak] = field(default_factory=list)
    #: 🔴 Gövdenin varsayılanı TICARIFATURA'dır; iadede o senaryo REDDEDİLİR (yukarı bak).
    senaryo: str = "TEMELFATURA"

    # ── ölçüm: neyi kuramıyoruz ve NİÇİN ─────────────────────────────────────
    def eksikleri_bul(self) -> list[str]:
        """Belgeyi kurmaya YETMEYEN her alanı adıyla döndürür (boş liste = kurulabilir).

        Ortak alanları gövde denetler; burada YALNIZ iadeye özel kapı vardır.
        """
        eksik = self.ortak_eksikler()

        # 🔴 Senaryo kapısı: iade + yanlış senaryo, e-Logo'da rc=-1 ile döner. Kapıyı
        #    BURAYA koyuyoruz ki hata AĞA ÇIKMADAN, belge kurulurken görünsün.
        if self.senaryo not in IADE_SENARYOLARI:
            eksik.append(f"senaryo '{self.senaryo}' İADE tipinde kullanılamaz "
                         f"(izinli: {' · '.join(sorted(IADE_SENARYOLARI))})")

        # Şematron kapısı: iade faturası dayanaksız olmaz.
        if not self.dayanaklar:
            eksik.append("dayanaklar (iade faturası orijinal fatura referansı ZORUNLU — GİB 1150)")
        for i, d in enumerate(self.dayanaklar, 1):
            if not d.fatura_no.strip():
                eksik.append(f"dayanaklar[{i}].fatura_no")
            if not TARIH_RE.match(d.tarih or ""):
                eksik.append(f"dayanaklar[{i}].tarih (YYYY-MM-DD)")

        return eksik


def kur(f: IadeFaturasi) -> str:
    """İade faturasının UBL-TR XML'ini üretir.

    🔴 Eksik alan varsa `EksikAlan` fırlatır ve HİÇBİR ŞEY üretmez — yarım belge
       döndürmek, çağıranın onu geçerli sanmasına yol açardı.
    """
    eksik = f.eksikleri_bul()
    if eksik:
        raise EksikAlan("belge kurulamaz — eksik alanlar: " + " · ".join(eksik))

    return belge_kur(f, tip=IADE_TIPI, on_notlar=[IADE_SERHI], dayanaklar=f.dayanaklar, xslt=sablon_baytlari())


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
        # 🔴 Ölçüldü 2026-08-23: bu iki alan JSON'da verilse bile SESSİZCE yok sayılıyordu.
        #    Senaryo düzeltmesi (TEMELFATURA→TICARIFATURA) bu yüzden yalnız Python'dan
        #    çağıran hatta ulaşmıştı; JSON'dan kuran her türev varsayılana mahkûmdu.
        # 🔴 Iadede varsayilan TEMELFATURA (IADE_SENARYOLARI). Burada "TICARIFATURA"
        #    yaziliydi ve dataclass varsayilanini EZIYORDU — sinav bunu yakaladi.
        senaryo=str(veri.get("senaryo", "TEMELFATURA")),
        uuid=str(veri.get("uuid", "")),
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
