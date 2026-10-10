#!/usr/bin/env python3
"""Fiş paketinden SATIŞ faturası UBL'i hazırlar — kuruş kapısıyla.

🔴 KURUŞ KURALI (Sultan, 2026-08-22 · TOLERANS YOK):
   fatura toplamı, dayanak fiş paketiyle **KURUŞU KURUŞUNA** aynı olacak.
   1 kuruş fark bile ana alıcı tarafından red sebebi olabilir; "ihmal edilebilir fark"
   diye bir kategori YOKTUR. Kapı gevşetilemez, tolerans parametresi EKLENMEZ.

🔴 Niçin servis yolu: portal KDV'yi TOPLAM matrah üzerinden hesaplıyor ve bizim satır
   KDV'mizi yok sayıyor → 1 kuruş sapma (ölçüldü, üç kombinasyon da denendi). Servis
   yolunda tutarın sahibi BİZ'iz: ne yazarsak o gider.
"""
import re
import sys
import xml.etree.ElementTree as ET
from decimal import Decimal as D, ROUND_HALF_UP, InvalidOperation
from typing import NamedTuple

sys.path.insert(0, "/config/.claude/skills/elogo-erisim/scripts")
from ubl_satis import SatisFaturasi, kur, Kalem, Taraf   # noqa: E402
from ubl_iade import IadeFaturasi, kur as kur_iade       # noqa: E402
from ubl_ortak import Dayanak, EARSIV_SENARYO            # noqa: E402


def q(x: D) -> D:
    return x.quantize(D("0.01"), ROUND_HALF_UP)


class KurusHatasi(RuntimeError):
    """Hesaplanan toplam dayanakla birebir eşit değil. DUR."""


NS = {"cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
      "cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"}


def para(x, ad: str = "değer") -> D:
    """Girdiyi PARA olarak alır: en fazla iki ondalık. Fazlası REDDEDİLİR.

    🔴 NİÇİN (ölçüldü 2026-08-23): kapı `D(net)` diyip geçiyordu ve `D("100.004")` gibi
    para OLMAYAN bir değeri kabul ediyordu. Sonra `topla()` matrahı hiç yuvarlamadığı için
    `D("240.000")` ile `D("240.00")` sayısal olarak EŞİT çıkıyor, kapı YEŞİL yanıyordu —
    ama gövde o kalemleri kuruşa yuvarlayarak yazdığı için **satır kırılımı sessizce
    değişiyordu**. Yani "kuruşu kuruşuna" iddiası satır düzeyinde ölçülmemişti.
    Ölçülen vaka: kalemler 100.004 + 99.996 (dayanak 240.00) → kapı GEÇTİ, gövdeye
    100.00 + 100.00 yazıldı.
    """
    try:
        d = D(str(x))
    except (InvalidOperation, ValueError):
        raise KurusHatasi(f"{ad} sayı değil: {x!r} — DURULDU")
    if -d.as_tuple().exponent > 2:
        raise KurusHatasi(
            f"{ad} PARA DEĞİL: {x!r} — kuruştan küçük basamak taşıyor. "
            "Yuvarlamayı kapı yapmaz; dayanak veriyi kuruşa indirip öyle ver. DURULDU")
    return d


class Satir(NamedTuple):
    """Çözülmüş kalem. 🔴 POZİSYONLA DEĞİL ADLA erişilir.

    Niçin namedtuple: liste 3 alandan 5'e çıktı (iskonto, 2026-08-29). Pozisyonla
    unpack eden beş çağrı yeri vardı; birinde sıra kaysa hata SESSİZ olurdu —
    `brut` ile `iskonto` de, `oran` ile `iskonto_orani` de sayıdır ve karışsalar
    kod patlamaz, yalnız YANLIŞ FATURA üretir.
    """
    ad: str
    brut: str          #: satırın İSKONTO ÖNCESİ tutarı (iskonto yoksa = net)
    oran: int          #: KDV yüzdesi
    iskonto: str       #: satır iskontosu (tutar); "0" = iskonto yok
    iskonto_orani: D | None  #: yalnız BEYAN — tutar bundan TÜRETİLMEZ, bununla SINANIR
    #: 🔴 MİKTAR/BİRİM (2026-09-02): hat bugüne dek her satırı "1 adet × satır tutarı"
    #: diye yazıyordu. Fiş paketinde bu doğruydu (kalem türü toplamı), ama ADET taşıyan
    #: bir faturada (örn. 228 adet × 300 TL) belge YANLIŞ GÖRÜNÜR: tutar tutar ama
    #: alıcı kaç adet aldığını göremez. Tuple biçimlerinde miktar 1 kalır (davranış
    #: DEĞİŞMEZ); sözlük biçiminde açıkça verilir.
    miktar: D = D("1")
    birim: str = "C62"       #: UN/ECE birim kodu · C62=adet, NIU=adet(sayı), KGM=kg…

    @property
    def net(self) -> D:
        """KDV matrahı: brütten iskonto düşülmüş tutar (UBL `LineExtensionAmount`)."""
        return para(self.brut, f"kalem '{self.ad}' brüt") - para(self.iskonto, f"kalem '{self.ad}' iskonto")


def kalemleri_coz(kalemler, varsayilan_oran: int):
    """Kalem listesini `Satir` kayıtlarına çevirir. Kabul edilen biçimler:

        ("Malzeme", "1000.00")                    → varsayılan oran, iskonto yok
        ("Malzeme", "1000.00", 10)                → kalemin KENDİ oranı
        ("Malzeme", "1250.00", 20, "250.00")      → + iskonto TUTARI (brüt 1250 → net 1000)
        ("Malzeme", "1250.00", 20, "250.00", 20)  → + iskonto ORANI (çapraz kontrol)
        {"ad": "Ürün", "miktar": 228, "birim_fiyat": "300.00", "oran": 20}
                                                  → SÖZLÜK: miktar × birim fiyat
          (opsiyonel: "birim" · "iskonto" · "iskonto_orani" · doğrudan "brut")

    🔴 İKİNCİ ELEMANIN ANLAMI HER BİÇİMDE AYNIDIR: **iskonto öncesi satır tutarı**.
       İskonto yoksa brüt = net olduğu için 2/3'lü çağrılar aynen çalışır.

    🔴 NİÇİN VAR (FAZ 3 envanteri, 2026-08-25): UBL katmanı kalem başına oranı ve
       `TaxSubtotal` gruplamasını ZATEN destekliyordu (`Kalem.kdv_orani`); üst katman
       tek oran alıyordu, yani yetenek vardı ama **çağrılmıyordu**. Aynı aile:
       "yazılmış ≠ bağlanmış" — bu kez kendi hattımızda, veri modelinin içinde.

    🔴 Karışık liste kabul edilir ama SESSİZ DEĞİL: bazı kalemlere oran verip
       bazılarına vermeyi unutmak gerçek bir hatadır ve varsayılan onu sessizce yutardı.
       Kaç kalemin varsayılana düştüğü stderr'e yazılır.
    """
    cozulmus, varsayilana_dusen = [], []
    for i, k in enumerate(kalemler, 1):
        isk, isk_oran = "0", None
        if isinstance(k, dict):
            # 🔴 SÖZLÜK BİÇİMİ — alan ADIYLA verilir, pozisyonla değil.
            ad = str(k.get("ad", ""))
            mik = D(str(k.get("miktar", 1)))
            if mik <= 0:
                raise KurusHatasi(f"kalem '{ad}': miktar {mik} — sıfır ya da negatif olamaz")
            if "brut" in k:
                brut = str(k["brut"])
                if "birim_fiyat" in k:
                    # 🔴 İKİ TANIK: ikisi de verildiyse BİRBİRİNİ AÇIKLAMALI.
                    bekle = q(D(str(k["birim_fiyat"])) * mik)
                    if bekle != para(brut, f"kalem '{ad}' brüt"):
                        raise KurusHatasi(
                            f"kalem '{ad}': miktar × birim fiyat = {bekle}, verilen brüt "
                            f"{brut} — ikisi birbirini AÇIKLAMIYOR. DURULDU")
            elif "birim_fiyat" in k:
                brut = str(q(D(str(k["birim_fiyat"])) * mik))
            else:
                raise KurusHatasi(f"kalem[{i}] sözlüğünde 'brut' ya da 'birim_fiyat' YOK: {k!r}")
            oran = k.get("oran", varsayilan_oran)
            if "oran" not in k:
                varsayilana_dusen.append(ad)
            isk = str(k.get("iskonto", "0"))
            isk_oran = k.get("iskonto_orani")
            o = int(oran)
            if not (0 <= o <= 100):
                raise KurusHatasi(f"kalem '{ad}': KDV oranı {o} makul aralıkta değil (0-100)")
            b_, i_ = para(brut, f"kalem '{ad}' brüt"), para(isk, f"kalem '{ad}' iskonto")
            if i_ < 0:
                raise KurusHatasi(f"kalem '{ad}': iskonto negatif ({i_}) — DURULDU")
            if i_ > b_:
                raise KurusHatasi(f"kalem '{ad}': iskonto {i_} brüt {b_} tutarından BÜYÜK — DURULDU")
            cozulmus.append(Satir(ad, brut, o, isk,
                                  None if isk_oran is None else D(str(isk_oran)),
                                  mik, str(k.get("birim", "C62"))))
            continue
        if len(k) == 5:
            ad, brut, oran, isk, isk_oran = k
        elif len(k) == 4:
            ad, brut, oran, isk = k
        elif len(k) == 3:
            ad, brut, oran = k
        elif len(k) == 2:
            ad, brut = k; oran = varsayilan_oran; varsayilana_dusen.append(ad)
        else:
            raise KurusHatasi(f"kalem[{i}] biçimi tanınmıyor: {k!r} — "
                              "(ad, brüt[, oran[, iskonto[, iskonto_oranı]]])")
        o = int(oran)
        if not (0 <= o <= 100):
            raise KurusHatasi(f"kalem '{ad}': KDV oranı {o} makul aralıkta değil (0-100)")
        # 🔴 İskonto brütten büyük olamaz — negatif matrah sessizce geçmesin.
        b_, i_ = para(brut, f"kalem '{ad}' brüt"), para(isk, f"kalem '{ad}' iskonto")
        if i_ < 0:
            raise KurusHatasi(f"kalem '{ad}': iskonto negatif ({i_}) — DURULDU")
        if i_ > b_:
            raise KurusHatasi(f"kalem '{ad}': iskonto {i_} brüt {b_} tutarından BÜYÜK — DURULDU")
        cozulmus.append(Satir(ad, brut, o, isk, None if isk_oran is None else D(str(isk_oran))))
    if varsayilana_dusen and len(varsayilana_dusen) != len(kalemler):
        print(f"\033[33m•\033[0m KARIŞIK ORAN: {len(varsayilana_dusen)} kalem kendi oranını "
              f"taşımıyor, varsayılan %{varsayilan_oran} uygulandı → "
              f"{', '.join(varsayilana_dusen[:5])}", file=sys.stderr)
    return cozulmus


def topla(kalemler, kdv_orani: int = 20):
    """Satır satır matrah/KDV — fiş paketiyle aynı yöntem. Her değer PARA olmalı.

    Kalem KENDİ oranını taşıyorsa o kullanılır; taşımıyorsa `kdv_orani` varsayılandır.
    KDV **kalem başına** yuvarlanır (fiş paketiyle aynı yöntem) — oran grupları ayrı
    hesaplanıp sonra toplanmaz; aradaki fark kuruş düzeyinde gerçektir.
    """
    mat = D("0"); kdv = D("0")
    for sa in kalemleri_coz(kalemler, kdv_orani):
        n = sa.net                      # 🔴 iskonto DÜŞÜLMÜŞ matrah
        mat += n
        kdv += q(n * D(sa.oran) / D(100))
    return q(mat), q(kdv), q(mat + kdv)


#: 🔴 İADE NİTELİĞİNDEKİ ana alıcı belgeleri — SATIŞ DEĞİL, iade işlemidir.
#: Sultan kuralı (2026-09-03, ölçülmüş hatadan sonra):
#:   "satış kalemlerini gireceksen İADE olarak kesmen lazım;
#:    SATIŞ olarak keseceksen TEK KALEM olarak girmen lazım."
#: Yani belge TÜRÜ ile KALEM YAPISI birbirine bağlıdır ve serbest değildir.
IADE_NITELIGI = frozenset({"malzeme_iade", "ek_garanti_iade", "iade_paketi"})
BELGE_TURLERI = frozenset({"fis_paketi", "satis", *IADE_NITELIGI})


def belge_turu_kapisi(belge_turu, kalemler, dayanaklar) -> None:
    """🔴 TÜR ⟂ KALEM YAPISI tutarlılığı.

    ÖLÇÜLMÜŞ HATA (2026-09-03): `FGW2026000000009` bir MALZEME İADE belgesi için
    `SATIS` tipinde ve belgedeki **11 malzeme kalemiyle** kesildi. O belge
    "ana alıcıya 11 kalem mal SATTIK" diye okunur — oysa iade işlemidir.
    Kanondaki kural belgenin TÜRÜNÜ söylüyordu ("düz fatura kesilir") ama
    KALEM YAPISINI söylemiyordu; boşluğu "belgedeki kalemleri aynen yaz" diye
    doldurdum ve bu bir VARSAYIMDI.

    > **Ders:** bir kural belgenin türünü söyleyip kalem yapısını söylemiyorsa
    > EKSİKTİR. Eksik kuralı doldurmak ölçüm değil, tahmindir.
    """
    if belge_turu is None:
        return
    if belge_turu not in BELGE_TURLERI:
        raise KurusHatasi(
            f"belge türü '{belge_turu}' tanınmıyor (izinli: {' · '.join(sorted(BELGE_TURLERI))}) — DURULDU")
    if belge_turu not in IADE_NITELIGI:
        return
    # İade niteliğinde: ya İADE tipi (dayanaklı) ya da SATIŞ tipi + TEK KALEM.
    if dayanaklar:
        return                                   # İADE tipi → kalem kalem serbest
    if len(kalemler) != 1:
        raise KurusHatasi(
            f"🔴 TÜR KAPISI KIRMIZI · '{belge_turu}' bir İADE işlemidir ve SATIŞ tipinde "
            f"kesiliyor, ama {len(kalemler)} kalem var.\n"
            "   İki meşru yol vardır, üçüncüsü YOKTUR:\n"
            "     (a) kalemleri tek tek yazacaksan → belge İADE tipinde kesilir "
            "(dayanak/referans fatura ZORUNLU)\n"
            "     (b) SATIŞ tipinde keseceksen → TEK KALEM olur (örn. 'Malzeme İade')\n"
            "   Şu anki hâli 'karşı tarafa N kalem MAL SATTIK' diye okunur. DURULDU")


#: Dayanağın KAYNAĞI — kapının kaç bağımsız tanığı olduğunu belirler.
#: 🔴 Bu beyan MECBURİDİR ve mekanik olarak ÖLÇÜLEMEZ (bkz. dayanak_gucu).
KAYNAKLAR = {
    "fis_paketi":            "Ana alıcı fiş paketinden okundu — BAĞIMSIZ tanık",
    "insan_beyani":          "insan başka bir belgeden okuyup yazdı — bağımsız sayılır",
    "kalemlerden_turetildi": "kalemlerden hesaplandı — 🔴 TANIK DEĞİL",
}


class DayanakBeyaniYok(KurusHatasi):
    """Dayanağın nereden geldiği beyan edilmemiş. Fail-closed: üretim yok.

    🔴 NİÇİN ZORUNLU (ölçüldü 2026-08-25): kapı üç tanıkla çalışıyor — `topla()`,
    `urun_kapisi()` ve **dayanak**. İlk ikisi aynı varsayımı paylaşır; kapıya gücünü
    veren ÜÇÜNCÜSÜDÜR ve o dışarıdan gelir. Dayanak kalemlerden türetilmişse üçüncü
    tanık YOKTUR ve kapı **kendi kendini doğrular** — birebir eşitlik görür, yeşil yakar,
    hiçbir şey kanıtlamaz.
    Ölçülmüş vaka: `TEST_FATURA` dayanağı 12,00 · tek kalemi 10,00 → 10 × 1,20 = 12.
    Gerçek faturaların dayanağı fiş paketinden geliyordu. **İkisi kodda aynı biçimdeydi**
    ve kapı ayırt edemiyordu; ikisine de aynı yeşili verdi.
    """


def dayanak_gucu(kaynak: str) -> bool:
    """Bu dayanak BAĞIMSIZ bir tanık mı? (kapının gerçekten doğrulama yapıp yapmadığı)

    🔴 DÜRÜSTLÜK KAYDI — bu SORU MEKANİK OLARAK ÖLÇÜLEMEZ, o yüzden beyan isteniyor.
       Denenebilecek tek mekanik sezgi *"dayanak, kalemlerin toplamına eşit mi"* olurdu ve
       İŞE YARAMAZ: fiş paketi durumunda kalemler DE fiş paketinden gelir, yani dayanak
       zaten kalemlerle tutarlıdır. Türetilmiş dayanak da tutarlıdır. **İki hâl birbirinden
       ayırt edilemez.** Ayrımı yalnız çağıran bilir; bu yüzden kapı onu sorar, ölçmez.
       Ölçemediğimiz şeyi ölçüyormuş gibi yapmak, tam da bu kapının kapattığı hatadır.
    """
    if kaynak not in KAYNAKLAR:
        raise DayanakBeyaniYok(
            f"dayanak kaynağı tanınmıyor: {kaynak!r} — geçerli: {sorted(KAYNAKLAR)}")
    return kaynak != "kalemlerden_turetildi"


def kurus_kapisi(kalemler, dayanak_toplam: str, kdv_orani: int = 20, *,
                 dayanak_kaynagi: str | None = None,
                 dayanak_kirilimi: tuple | None = None) -> dict:
    """🔴 BİREBİR eşitlik kapısı. Eşit değilse ÜRETİM YOK.

    `dayanak_kaynagi` ZORUNLUDUR (bkz. DayanakBeyaniYok). `kalemlerden_turetildi` ise
    kapı belgeyi REDDETMEZ — ama sonucu **doğrulanmadı** diye işaretler ve ekrana basar.
    Meşru bir kullanımdır (fiş paketi olmayan fatura); sessizce yeşil olması meşru değildir.

    `dayanak_kirilimi=(matrah, kdv)` verilirse üç değer birden sınanır. Bu, kapının
    ikinci kör noktasını kapatır: yalnız TOPLAM sınanırken `kdv_orani` ile oynayarak
    kapıyı geçirmek mümkündü (kapı sayıyı denetler, NİYETİ denetlemez). Kırılım da
    sınandığında oranı değiştirmek toplamı tutturmaz.
    """
    if dayanak_kaynagi is None:
        raise DayanakBeyaniYok(
            "🔴 dayanak_kaynagi BEYAN EDİLMEDİ — bu kapının kaç tanığı olduğu bilinmiyor. "
            f"Zorunlu, çünkü mekanik olarak ölçülemez. Geçerli: {sorted(KAYNAKLAR)}")
    bagimsiz = dayanak_gucu(dayanak_kaynagi)

    mat, kdv, ode = topla(kalemler, kdv_orani)
    hedef = para(dayanak_toplam, "dayanak toplam")
    if ode != hedef:
        fark = abs(ode - hedef)
        # 🔴 TEŞHİS: fark TEVKİFAT olabilir mi? (2026-08-30)
        #    Kapı zaten duruyordu ama "fark 40,00" diyordu ve bu YANLIŞ ONARIMA davet:
        #    insan bunu yuvarlama sanıp dayanağı 1.200'e çıkarır ve TEVKİFATSIZ yanlış
        #    fatura keser. Aynı desen ortam kilidinde de görüldü: doğru durur, yanlış
        #    sebep söyler. Fark, KDV'nin bilinen bir tevkifat oranına denk düşüyorsa
        #    kapı bunu AÇIKÇA söyler ve "hattımız tevkifatı desteklemiyor" der.
        #    ⏸ Bu bir TAHMİNDİR, hüküm değil — belge yine ÜRETİLMEZ, karar insana kalır.
        ipucu = ""
        if kdv > 0 and ode > hedef:
            for pay in (2, 3, 4, 5, 7, 9, 10):
                if q(kdv * D(pay) / D(10)) == fark:
                    ipucu = (f"\n   ⏸ TEŞHİS: fark, KDV'nin tam {pay}/10'u. Bu bir KDV TEVKİFATI "
                             f"olabilir.\n   🔴 Bu hat tevkifatı DESTEKLEMİYOR (gerçek örnek "
                             f"ölçülemedi: 1.146 gelen faturada tevkifat yapısı YOK).\n"
                             f"   ⚠️ Dayanağı {ode:,.2f}'ye ÇIKARMA — o, tevkifatı yok sayan "
                             f"YANLIŞ bir fatura üretir. Mali müşavire sor.")
                    break
        # 🔴 Farkı BİÇİMLENDİRME (ölçüldü): `:,.2f` kuruş-altı farkı "0.00" gösteriyordu.
        #    "REDDEDİLDİ, fark 0.00" cümlesi insanı kapıyı görsel hata sanıp aşmaya davet eder.
        raise KurusHatasi(
            f"KURUŞ KAPISI KIRMIZI · hesaplanan {ode:,.2f} ≠ dayanak {hedef:,.2f} "
            f"(fark {fark}) — belge ÜRETİLMEDİ, karar insana ait" + ipucu)

    # Kırılım sınaması — verilmişse ÜÇ değer birden (oranla-oynama panzehiri)
    if dayanak_kirilimi is not None:
        d_mat = para(str(dayanak_kirilimi[0]), "dayanak matrah")
        d_kdv = para(str(dayanak_kirilimi[1]), "dayanak KDV")
        if mat != d_mat or kdv != d_kdv:
            raise KurusHatasi(
                f"🔴 KIRILIM KAPISI KIRMIZI · toplam tuttu ama kırılım TUTMADI: "
                f"matrah {mat} vs {d_mat} · KDV {kdv} vs {d_kdv}. "
                f"Toplamı tutturan bir oran, doğru fatura demek DEĞİLDİR — DURULDU")

    # 🔴 UYARILAR stderr'E GİDER, stdout'a DEĞİL (ölçüldü 2026-08-25).
    #    İlk sürüm stdout'a basıyordu ve `kurus.test.sh`'i kırdı: o sınav çıktıyı
    #    AYRIŞTIRIYOR (`GEC`/`RET` ilk alan). Bir kapının insan-mesajı, veri kanalına
    #    karışırsa onu okuyan her aracı bozar — ve bozulma sessiz de olabilirdi
    #    (mesaj beklenen değere benzeseydi sınav yanlış yeşil verirdi).
    def _uyar(*parcalar):
        print(*parcalar, file=sys.stderr)

    if not bagimsiz:
        _uyar("\033[33m⏸ BU KAPI BU BELGEYİ DOĞRULAMADI.\033[0m")
        _uyar(f"   dayanak kaynağı: {dayanak_kaynagi} — {KAYNAKLAR[dayanak_kaynagi]}")
        _uyar("   Eşitlik sağlandı, ama dayanak kalemlerden türetildiği için kapı KENDİ")
        _uyar("   HESABINI kendi hesabıyla karşılaştırdı. Yeşil, burada bir kanıt değildir.")
    elif dayanak_kirilimi is None:
        _uyar(f"\033[33m•\033[0m tek-tanık: dayanak yalnız TOPLAM olarak sınandı "
              f"({dayanak_kaynagi}). Kırılım verilseydi oran-oynatması da kapanırdı.")

    return {"matrah": mat, "kdv": kdv, "odenecek": ode,
            "dayanak_kaynagi": dayanak_kaynagi,
            "dogrulandi": bagimsiz,
            "kirilim_sinandi": dayanak_kirilimi is not None}


def belge_kur(*, kalemler, dayanak_toplam: str, sap: str, fatura_no: str,
              tarih: str, duzenleyen: Taraf, muhatap: Taraf, kdv_orani: int = 20,
              not_metni: str | None = None, dayanak_kaynagi: str | None = None,
              dayanak_kirilimi: tuple | None = None,
              dayanaklar: list | None = None,
              belge_turu: str | None = None,
              senaryo: str | None = None,
              saat: str | None = None,
              gonderim_sekli: str = "KAGIT") -> tuple[str, dict]:
    """Kapıdan geçirir, sonra UBL üretir. Sıra bilinçli: kapı ÖNCE.

    `dayanak_kaynagi` buradan da ZORUNLU olarak geçer — beyanı isteğe bağlı bir üst
    parametre yapmak, kapıyı çağıranın unutabileceği bir kapı hâline getirirdi.

    🔴 `dayanaklar` VERİLİRSE belge İADE faturası olur (`InvoiceTypeCode=IADE` +
    `cac:BillingReference`). Niçin aynı fonksiyon: iki tür AYRI kod yolundan üretilseydi
    kuruş kapısı ve ürün kapısı yalnız birinde koşardı — ve koşmayan taraf, koştuğu
    sanılan taraf olurdu. Bu dosyanın kendi tarihi tam olarak bu hatanın kaydıdır
    (ürün kapısı, denetlenmeyen ikinci bir üretim yolu bulunduğu için doğdu).
    ⚠️ Boş liste `[]` iade DEĞİLDİR: iade dayanaksız olamaz, `ubl_iade` onu zaten
    reddeder. `None` = satış, dolu liste = iade; ikisi arasında üçüncü hâl yok.
    """
    # 🔴 TÜR KAPISI EN ÖNDE: yanlış yapıdaki belge hiç KURULMASIN.
    belge_turu_kapisi(belge_turu, kalemler, dayanaklar)
    ozet = kurus_kapisi(kalemler, dayanak_toplam, kdv_orani,
                        dayanak_kaynagi=dayanak_kaynagi, dayanak_kirilimi=dayanak_kirilimi)
    satirlar = [Kalem(ad=sa.ad, miktar=sa.miktar, birim=sa.birim,
                      # 🔴 BRÜT birim fiyat — ölçüldü: gerçek faturada `PriceAmount`
                      #    iskonto ÖNCESİ fiyattır, `LineExtensionAmount` sonrasıdır.
                      # 🔴 Kalem BİRİM fiyat ister; brüt SATIR tutarıdır → miktara böl.
                      birim_fiyat_kurus=int((para(sa.brut) / sa.miktar * 100).to_integral_value(
                          rounding=ROUND_HALF_UP)),
                      kdv_orani=sa.oran,
                      iskonto_kurus=int((para(sa.iskonto) * 100).to_integral_value(
                          rounding=ROUND_HALF_UP)),
                      iskonto_orani=sa.iskonto_orani)
                for sa in kalemleri_coz(kalemler, kdv_orani)]
    notlar = [not_metni if not_metni else f"Fiş paketi SAP Belge No: {sap}"]
    if dayanaklar is None:
        ek = {}
        if senaryo:
            ek["senaryo"] = senaryo
        # 🔴 e-Arşivde saat ve gönderim şekli belgenin PARÇASIDIR (ölçüldü) — geçirilmezse
        #    üretilir; ama gönderim şekli açıkça taşınır, sessiz varsayılan bırakılmaz.
        if senaryo == EARSIV_SENARYO:
            ek["gonderim_sekli"] = gonderim_sekli
            if saat:
                ek["saat"] = saat
        f = SatisFaturasi(duzenleyen=duzenleyen, muhatap=muhatap, tarih=tarih,
                          kalemler=satirlar, numara_modu="verilen",
                          fatura_no=fatura_no, notlar=notlar, **ek)
        xml = kur(f)
    else:
        f = IadeFaturasi(duzenleyen=duzenleyen, muhatap=muhatap, tarih=tarih,
                         kalemler=satirlar, numara_modu="verilen",
                         fatura_no=fatura_no, notlar=notlar,
                         dayanaklar=dayanaklar)
        xml = kur_iade(f)
    urun_kapisi(xml, kalemler, ozet, kdv_orani)      # 🔴 ikinci kapı: ÜRÜNÜ sına
    return xml, ozet


def _tut(kok, yol: str) -> D:
    e = kok.find(yol, NS)
    if e is None or not (e.text or "").strip():
        raise KurusHatasi(f"ÜRÜN KAPISI · belgede eksik alan: {yol} — DURULDU")
    return D(e.text.strip())


def urun_kapisi(xml: str, kalemler, ozet: dict, kdv_orani: int = 20) -> None:
    """🔴 İKİNCİ KAPI — üretilen BELGEYİ sınar, girdiyi değil.

    NİÇİN (derin kazı 2026-08-23 · üç mercek bağımsız gösterdi): `kurus_kapisi` yalnız
    kalem listesinin toplamını dayanakla karşılaştırıyordu. Sonra AYRI bir kod yolu UBL'i
    üretiyordu ve o yolu kimse denetlemiyordu. Aradaki her kusur — yuvarlama kipi farkı,
    kuruşa çevirim, alan eşlemesi — kapının ARKASINDAN geçerdi.

    Yanılgı defterinin kendi kuralı buydu ve kapıya uygulanmamıştı:
    **"Kaynaktan değil üründen doğrula."**

    Sınanan altı şey (hepsi BİREBİR, tolerans yok):
      1. `PayableAmount` == kapının hesabı
      2. `TaxInclusiveAmount` == `PayableAmount`
      3. `LineExtensionAmount` == `TaxExclusiveAmount` == satır tutarları toplamı
      4. belge `TaxAmount` == satır KDV'leri toplamı == kapının KDV'si
      5. HER satırın tutarı, girdideki kalem netiyle birebir (satır kırılımı SESSİZCE değişemez)
      6. bütün tutarlar AYNI para biriminde (kapı birim-kör kalmasın)
    """
    kok = ET.fromstring(xml)

    ode = _tut(kok, "cac:LegalMonetaryTotal/cbc:PayableAmount")
    if ode != ozet["odenecek"]:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI KIRMIZI · belgedeki ÖDENECEK {ode} ≠ kapının hesabı "
            f"{ozet['odenecek']} — kapı yeşil yandı ama BELGE BAŞKA ŞEY SÖYLÜYOR. DURULDU")

    dahil = _tut(kok, "cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount")
    if dahil != ode:
        raise KurusHatasi(f"🔴 ÜRÜN KAPISI · TaxInclusive {dahil} ≠ Payable {ode} — DURULDU")

    haric = _tut(kok, "cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount")
    satir_top = _tut(kok, "cac:LegalMonetaryTotal/cbc:LineExtensionAmount")
    if haric != satir_top or haric != ozet["matrah"]:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · matrah uyuşmuyor: TaxExclusive {haric} · "
            f"LineExtension {satir_top} · kapı {ozet['matrah']} — DURULDU")

    kdv_belge = _tut(kok, "cac:TaxTotal/cbc:TaxAmount")
    if kdv_belge != ozet["kdv"]:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · belge KDV {kdv_belge} ≠ kapı KDV {ozet['kdv']} — DURULDU")

    # 4b 🔴 BELGE DÜZEYİ VERGİ GRUPLARI — her grup KENDİ İÇİNDE tutarlı olmalı.
    #     Bu kapı, çoklu-KDV sınavı yazılırken KAZARA bulundu: sınav yanlış yeri bozdu
    #     (belge düzeyindeki `Percent`'i, satırdakini değil) ve kapı GEÇİRDİ. Yanlış
    #     mutasyon, gerçek bir açığı ortaya çıkardı — grup matrahı ve KDV'si doğru olsa
    #     bile `Percent` yanlış yazılabiliyordu ve hiçbir kapı itiraz etmiyordu.
    #     Belge o hâlde KENDİ İÇİNDE tutarsızdır: oran, tutarı açıklamıyor.
    #     🔴 BEKLENEN, GRUP MATRAHI × ORAN DEĞİLDİR — KALEM KDV'LERİNİN TOPLAMIDIR.
    #     Bu kapının ilk sürümü `matrah × oran` sanıyordu ve İLK GERÇEK FATURADA patladı:
    #       8297,57 + 1175,74 + 5036,22 = 14509,53
    #       kalem başına yuvarlanmış KDV toplamı = 2901,90   ← canlıda KESİLDİ ve KABUL EDİLDİ
    #       grup matrahı × %20                   = 2901,91   ← 1 kuruş fazla
    #     Yuvarlama kalem başına yapılır (fiş paketiyle aynı yöntem); toplayıp yuvarlamak
    #     BAŞKA sonuç verir. `topla()`'nın kendi notunda bu yazılıydı ve kapıyı yazarken
    #     ihlal ettim. Sınav fikstürüm yuvarlama farkı ÜRETMEYEN sayılar kullandığı için
    #     (1000,00 × %20 = 200,00 tam) yeşil kaldı; kusuru GERÇEK VERİYLE kuru prova buldu.
    #     Ders: fikstür, gerçeğin kolay hâlini seçerse sınav kolay soruyu sorar.
    cozulmus = kalemleri_coz(kalemler, kdv_orani)
    girdi_oranlari = {sa.oran for sa in cozulmus}
    beklenen_grup: dict[int, D] = {}
    for sa in cozulmus:
        beklenen_grup[sa.oran] = beklenen_grup.get(sa.oran, D("0")) + q(sa.net * D(sa.oran) / D(100))

    yazili_oranlar = set()
    for grup in kok.findall("cac:TaxTotal/cac:TaxSubtotal", NS):
        g_kdv = _tut(grup, "cbc:TaxAmount")
        g_oran_metin = (grup.findtext("cbc:Percent", default="", namespaces=NS) or "").strip()
        try:
            g_oran = int(D(g_oran_metin))
        except Exception:
            raise KurusHatasi(f"🔴 ÜRÜN KAPISI · vergi grubunda okunamayan oran: {g_oran_metin!r} — DURULDU")
        yazili_oranlar.add(g_oran)
        bekle = beklenen_grup.get(g_oran)
        if bekle is None:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · belgede %{g_oran} grubu var, girdide o oranda kalem YOK — DURULDU")
        if bekle != g_kdv:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · %{g_oran} grubunun KDV'si {g_kdv}, kalem KDV'lerinin toplamı "
                f"{bekle} — grup, kalemlerini açıklamıyor. DURULDU")
    if yazili_oranlar != girdi_oranlari:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · belgedeki vergi oranları {sorted(yazili_oranlar)} ≠ girdideki "
            f"{sorted(girdi_oranlari)} — DURULDU")

    # 4c 🔴 BELGE DÜZEYİ İSKONTO — `AllowanceTotalAmount`, satır iskontolarını AÇIKLAMALI.
    #     Niçin ayrı kapı: satır tutarları ve KDV doğru olsa bile belge düzeyi iskonto
    #     toplamı yanlış yazılabilir — o zaman belge kendi içinde tutarsızdır ve hiçbir
    #     tutar-eşitliği bunu yakalamaz (matrah zaten iskonto DÜŞÜLMÜŞ hâlde tutuyor).
    #     🔴 İskonto YOKSA eleman da OLMAMALI: `AllowanceTotalAmount=0.00` yazan bir belge,
    #     "iskonto uygulandı ama sıfır" der; bizim belgemizde iskonto kavramı hiç yoktur.
    girdi_iskonto = sum((sa_.iskonto and para(sa_.iskonto, "iskonto") or D("0"))
                        for sa_ in cozulmus) or D("0")
    yazili_iskonto = kok.find("cac:LegalMonetaryTotal/cbc:AllowanceTotalAmount", NS)
    if girdi_iskonto > 0:
        if yazili_iskonto is None:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · girdide {girdi_iskonto} iskonto var ama belgede "
                "`AllowanceTotalAmount` YOK — iskonto sessizce kayboldu. DURULDU")
        if D((yazili_iskonto.text or "0").strip()) != girdi_iskonto:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · belgedeki toplam iskonto {yazili_iskonto.text}, "
                f"kalem iskontolarının toplamı {girdi_iskonto} — DURULDU")
    elif yazili_iskonto is not None:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · girdide iskonto YOK ama belgede `AllowanceTotalAmount` "
            f"{yazili_iskonto.text} yazıyor — DURULDU")

    # 4d 🔴 KÖK `AllowanceCharge` bloğu — `AllowanceTotalAmount`'tan AYRI bir elemandır
    #     ve İKİSİ AYRIŞABİLİR. Bu boşluğu sınav buldu (2026-08-29): belge düzeyi bloğun
    #     `Amount`'u bozulduğunda hiçbir kapı itiraz etmiyordu, çünkü hepsi
    #     `AllowanceTotalAmount`'a bakıyordu. Belge o hâlde kendi içinde tutarsızdır:
    #     iki yerde iki farklı toplam iskonto yazar.
    kok_blok = kok.find("cac:AllowanceCharge", NS)
    if girdi_iskonto > 0:
        if kok_blok is None:
            raise KurusHatasi(
                "🔴 ÜRÜN KAPISI · belgede kök `AllowanceCharge` bloğu YOK — DURULDU")
        k_tutar = D((kok_blok.findtext("cbc:Amount", default="0", namespaces=NS) or "0").strip())
        if k_tutar != girdi_iskonto:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · belge düzeyi iskonto bloğu {k_tutar}, kalem iskontolarının "
                f"toplamı {girdi_iskonto} — belge KENDİ İÇİNDE tutarsız. DURULDU")
        if (kok_blok.findtext("cbc:ChargeIndicator", default="", namespaces=NS) or "").strip() != "false":
            raise KurusHatasi(
                "🔴 ÜRÜN KAPISI · belge düzeyi `ChargeIndicator` 'false' DEĞİL — "
                "iskonto ARTIRIM olarak okunur. DURULDU")
    elif kok_blok is not None:
        raise KurusHatasi(
            "🔴 ÜRÜN KAPISI · girdide iskonto YOK ama belgede kök `AllowanceCharge` VAR — DURULDU")

    # 5 · satır satır — toplam tutsa bile kırılım kaymış olabilir
    satirlar = kok.findall("cac:InvoiceLine", NS)
    if len(satirlar) != len(kalemler):
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · belgede {len(satirlar)} kalem var, girdide {len(kalemler)} — DURULDU")
    top_satir = D("0"); top_kdv = D("0")
    for i, (satir, sa) in enumerate(
            zip(satirlar, kalemleri_coz(kalemler, kdv_orani)), 1):
        ad, oran = sa.ad, sa.oran
        tutar = _tut(satir, "cbc:LineExtensionAmount")
        beklenen = sa.net
        if tutar != beklenen:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') belgede {tutar}, girdide {beklenen} — "
                "toplam tutsa bile SATIR KIRILIMI değişmiş. DURULDU")

        # 🔴 SATIRIN ORANI da sınanır (çoklu-KDV, 2026-08-25). Niçin: belgede satır tutarı
        #    ve KDV'si doğru olsa bile `Percent` yanlış yazılabilir — o zaman belge KENDİ
        #    İÇİNDE tutarsızdır (oran, tutarı açıklamıyor) ve reddi bize dönene kadar
        #    hiçbir kapımız itiraz etmezdi. Tutar-eşitliği, oran-doğruluğunu kanıtlamaz.
        yazili_oran = satir.findtext("cac:TaxTotal/cac:TaxSubtotal/cbc:Percent", default="", namespaces=NS)
        if yazili_oran.strip() not in (str(oran), f"{oran}.0"):
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') belgede %{yazili_oran or '?'} yazıyor, "
                f"girdide %{oran} — DURULDU")
        # 🔴 SATIR İSKONTOSU — blok VARLIĞI ve TUTARI birlikte sınanır.
        isk = para(sa.iskonto, f"kalem '{ad}' iskonto")
        blok = satir.find("cac:AllowanceCharge", NS)
        if isk > 0:
            if blok is None:
                raise KurusHatasi(
                    f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') girdide {isk} iskontolu ama belgede "
                    "`AllowanceCharge` YOK — iskonto satırdan düştü. DURULDU")
            y_tutar = D((blok.findtext("cbc:Amount", default="0", namespaces=NS) or "0").strip())
            if y_tutar != isk:
                raise KurusHatasi(
                    f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') belgede iskonto {y_tutar}, "
                    f"girdide {isk} — DURULDU")
            if (blok.findtext("cbc:ChargeIndicator", default="", namespaces=NS) or "").strip() != "false":
                raise KurusHatasi(
                    f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') `ChargeIndicator` 'false' DEĞİL — "
                    "bu bir iskonto değil ARTIRIM olarak okunur, tutar TERS yönde işler. DURULDU")
            # brüt tutarlılığı: PriceAmount × miktar − iskonto = LineExtensionAmount
            fiyat = _tut(satir, "cac:Price/cbc:PriceAmount")
            mik = D((satir.findtext("cbc:InvoicedQuantity", default="1", namespaces=NS) or "1").strip())
            if q(fiyat * mik) - isk != tutar:
                raise KurusHatasi(
                    f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') brüt {q(fiyat * mik)} − iskonto {isk} "
                    f"= {q(fiyat * mik) - isk}, ama satır tutarı {tutar} — DURULDU")
        elif blok is not None:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') girdide iskontosuz ama belgede "
                "`AllowanceCharge` VAR — DURULDU")

        satir_kdv = _tut(satir, "cac:TaxTotal/cbc:TaxAmount")
        oran_kdv = q(beklenen * D(oran) / D(100))
        if satir_kdv != oran_kdv:
            raise KurusHatasi(
                f"🔴 ÜRÜN KAPISI · {i}. kalem ('{ad}') KDV'si {satir_kdv}, oranın gerektirdiği "
                f"{oran_kdv} — satır KENDİ İÇİNDE tutarsız. DURULDU")

        top_satir += tutar
        top_kdv += satir_kdv
    if top_satir != haric:
        raise KurusHatasi(f"🔴 ÜRÜN KAPISI · satır toplamı {top_satir} ≠ matrah {haric} — DURULDU")
    if top_kdv != kdv_belge:
        raise KurusHatasi(
            f"🔴 ÜRÜN KAPISI · satır KDV toplamı {top_kdv} ≠ belge KDV {kdv_belge} — DURULDU")

    # 6 · para birimi tekliği — kapı birim-kör kalmasın
    birimler = {e.get("currencyID") for e in kok.iter()
                if e.get("currencyID") and re.search(r"Amount$", e.tag)}
    if len(birimler) > 1:
        raise KurusHatasi(f"🔴 ÜRÜN KAPISI · belgede birden çok para birimi: {sorted(birimler)} — DURULDU")
