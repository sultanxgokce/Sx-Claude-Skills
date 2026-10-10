#!/usr/bin/env python3
"""
elogo_gonder.py — paketlenmiş belgeyi e-Logo'ya GÖNDERİR (`SendDocument`).

🔴 BU DOSYA GERİ ALINAMAZ İŞ YAPAR.
   GİB'e giden bir e-Fatura geri çağrılamaz. e-Faturada "sil" yoktur; olan
   şey karşı tarafın red/itiraz sürecidir ve o da bizim elimizde değildir.
   Bu yüzden buradaki her kapı fail-CLOSED'dır: emin olmadığımız her durumda
   gönderim YAPILMAZ, hata basılır.

DÖRT KAPI (hepsi geçilmeden tek bayt gitmez)
────────────────────────────────────────────
  K1 · ORTAM açıkça seçilir      — varsayılan DEMO. Canlıya gitmek niyet ister.
  K2 · KURU KOŞUM varsayılandır  — `--gercekten-gonder` yoksa zarf kurulur,
                                   ekrana özeti basılır, AĞA ÇIKILMAZ.
  K3 · SULTAN ONAYI beyanı şart  — boş/yer-tutucu kabul edilmez.
  K4 · PAKET BÜTÜNLÜĞÜ           — dört alan da dolu, özet 32 hane MD5.

K3 üzerine dürüst not (A06): bu bir *kayıt* kapısıdır, kriptografik bir kilit
değil. Onay metnini yazan taraf teknik olarak ajandır. Yaptığı iş, gönderimi
imzasız bırakmamak ve "kim izin verdi" sorusunu sonradan cevaplanabilir
kılmaktır. Sultan'ın sözünü ÜRETMEK bu kapının kullanımı değil, istismarıdır.

ÖLÇÜLEN SÖZLEŞME (Uygulama Arabirim Dokümanı, 21.08.2026 · s.5)
───────────────────────────────────────────────────────────────
`ResultType SendDocument(sessionID, string[] paramList, DocumentDataType document, out refId)`

paramList (Key=Value):
  DOCUMENTTYPE=EINVOICE     → e-Fatura (GİB'e kayıtlı mükellefe)
  ALIAS=urn:mail:...        → 🔴 ZORUNLU DEĞİL. Belge s.5:
                               "Etiket gönderilmezse; alıcının TEK etiketi varsa
                                belge bu etikete gönderilir. BİRDEN FAZLA etiketi
                                varsa HATA üretilir."
                               → etiketi bilmiyorsak göndermemek meşru bir seçimdir;
                                 hata alırsak sebebi bu olur ve mesaj bize söyler.

🔴 e-Arşiv `EARCHIVETYPE2` bilerek DESTEKLENMİYOR: o tip her gönderimde
   Sultan'ın telefonuna 180 saniyelik `2FACODE` düşürür (s.24) ve insansız
   akışa uymaz. Karar 2026-08-21, Sultan: hat e-Fatura üstüne kurulacak.
   Destek eklenecekse ayrı bir iş olarak, kod değil karar meselesidir.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import elogo_soap as S                                    # noqa: E402

YER_TUTUCULAR = {"", "-", "yok", "n/a", "na", "tbd", "test", "onay", "evet"}


class GonderimHatasi(RuntimeError):
    pass


def _paketi_dogrula(paket: dict[str, str]) -> None:
    """K4 — yarım paket ağa çıkmaz."""
    gerekli = ("fileName", "binaryData", "contentType", "hash", "currentDate")
    eksik = [a for a in gerekli if not str(paket.get(a, "")).strip()]
    if eksik:
        raise GonderimHatasi(f"paket eksik: {', '.join(eksik)}")
    h = paket["hash"]
    if len(h) != 32 or any(c not in "0123456789abcdefABCDEF" for c in h):
        raise GonderimHatasi(f"özet MD5 görünmüyor (32 hane hex bekleniyor): {len(h)} hane")


ARR_NS = "http://schemas.microsoft.com/2003/10/Serialization/Arrays"


def zarf_kur(sid: str, paket: dict[str, str], alias: str | None = None,
             tasarim: str = "varsayilan", belge_tipi: str = "EINVOICE") -> str:
    """SendDocument SOAP gövdesini kurar. Ağa çıkmaz — kuru koşum da bunu kullanır.

    Ön-ekler taşıyıcıdan (`elogo_soap._cagir`) gelir: `t` = tempuri,
    `d` = eFaturaWebService. Dizi ad-alanı orada tanımlı DEĞİL, burada
    yerinde bildirilir — taşıyıcının zarfını değiştirmemek için.
    """
    _paketi_dogrula(paket)
    if alias and ("<" in alias or ">" in alias or "&" in alias):
        raise GonderimHatasi(f"etikette XML'i bozacak karakter var: {alias}")

    if belge_tipi not in ("EINVOICE", "EARCHIVE"):
        raise GonderimHatasi(f"belge tipi '{belge_tipi}' tanınmıyor (EINVOICE | EARCHIVE)")
    params = [f"DOCUMENTTYPE={belge_tipi}"]
    # 🔴 e-ARŞİVDE ETİKET YOKTUR — alıcı e-Fatura mükellefi DEĞİLDİR, posta kutusu da
    #    yoktur. e-Fatura yolunda ise etiket ZORUNLUDUR (alias_dogrula).
    if alias and belge_tipi == "EINVOICE":
        params.append(f"ALIAS={alias}")

    # 🔴 GÖRSEL TASARIM — belgesiz gönderim REDDEDİLİR (ölçüldü 2026-08-22, demo):
    #    e-Logo `resultCode=-1` + "e-Belge görsel tasarım içermelidir." döndürdü.
    #    UBL-TR faturası belgenin nasıl görüneceğini tarif eden bir XSLT ister.
    #    Kendi şablonumuzu uydurmak yerine üreticinin sunduğu iki yol kullanılır (s.8):
    #      varsayilan → `UseDefaultXSLT=1`  (hesabın ön tanımlı tasarımı)
    #      <uuid>     → `XSLTUUID=<uuid>`   (portalden yüklenmiş belirli tasarım)
    #      gomulu     → hiçbiri; tasarım belgenin İÇİNDE taşınır (bugün üretmiyoruz)
    if tasarim == "varsayilan":
        params.append("UseDefaultXSLT=1")
    elif tasarim == "gomulu":
        pass
    elif tasarim:
        if any(c in tasarim for c in "<>&= "):
            raise GonderimHatasi(f"geçersiz tasarım kimliği: {tasarim}")
        params.append(f"XSLTUUID={tasarim}")
    satirlar = "".join(f"<a:string>{p}</a:string>" for p in params)
    return (
        f"<t:SendDocument>"
        f"<t:sessionID>{sid}</t:sessionID>"
        f'<t:paramList xmlns:a="{ARR_NS}">{satirlar}</t:paramList>'
        f"<t:document>"
        f"<d:binaryData>"
        f'<d:Value>{paket["binaryData"]}</d:Value>'
        f'<d:contentType>{paket["contentType"]}</d:contentType>'
        f"</d:binaryData>"
        f'<d:currentDate>{paket["currentDate"]}</d:currentDate>'
        f'<d:fileName>{paket["fileName"]}</d:fileName>'
        f'<d:hash>{paket["hash"]}</d:hash>'
        f"</t:document>"
        f"</t:SendDocument>"
    )


#: 🔴 ORTAM KİLİDİNİN TANIDIĞI DEĞERLER — pozitif liste. Bunun DIŞINDAKİ her şey
#: (yok · boş · "demoo" · "prod" · okunamaz) "bilmiyorum"dur ve "izin" DEĞİLDİR.
TANINAN_KILIT = ("demo", "canli")


def alias_dogrula(alias, gercekten_gonder: bool, belge_tipi: str = "EINVOICE") -> int:
    """Alıcı posta kutusu etiketi kapısı. 0 = yol açık · 7 = RET.

    🔴 Üretici arabirim dokümanı: *"Etiket gönderilmezse; alıcının TEK etiketi varsa belge
    bu etikete gönderilir, BİRDEN FAZLA etiketi varsa hata üretilir."*
    Yani **aynı ihmal ALICIYA GÖRE bazen görünür bazen GÖRÜNMEZ** — en kötü hata sınıfı:
    tek kutulu alıcıda belge SESSİZCE (ve belki yanlış kutuya) gider, hiç uyarı çıkmaz.
    "Bir kere çalıştı" diye güven üretir. Bu yüzden "unutmayalım" yetmez; araca bağlıdır.

    🔴 İRSALİYE kutusu ayrıca reddedilir: adres defterinde AYNI ünvanla yan yana durur;
    yanlış seçilirse portal "başarılı" der ama fatura ULAŞMAZ.

    Kuru koşumda gerekmez — orada ağa çıkılmaz, yalnız zarf yapısı sınanır.
    ⚠️ Bu kapı ONAY kapısından ÖNCE koşar; sıra bir SÖZLEŞMEDİR ve sınavda kilitlidir
    (`elogo_gonder.test.sh` · "SIRA SÖZLEŞMESİ"). Araya kapı eklerken o satır kırılır.
    """
    if not gercekten_gonder:
        return 0
    # 🔴 e-Arşivde etiket ARANMAZ: alıcının posta kutusu yoktur. Etiket kapısını e-Arşive
    #    de uygulamak meşru bir gönderimi OLMAYAN bir alanı isteyerek engellerdi —
    #    kapı doğru yerde durmalı, her yerde değil.
    if belge_tipi == "EARCHIVE":
        if alias:
            print("⛔ e-ARŞİVDE ETİKET OLMAZ — alıcı e-Fatura mükellefi değildir.\n"
                  "   Etiket verilmişse ya belge tipi ya alıcı yanlış seçilmiştir.",
                  file=sys.stderr)
            return 7
        return 0
    if not alias:
        print("⛔ ALIAS YOK — gerçek gönderim REDDEDİLDİ.\n"
              "   Etiket verilmezse tek kutulu alıcıda belge SESSİZCE gider (uyarı çıkmaz),\n"
              "   çok kutulu alıcıda hata verir. Aynı ihmalin bazen görünmez olması kabul edilemez.\n"
              "   Kullan: --alias urn:mail:<kutu>@<firma>", file=sys.stderr)
        return 7
    if not alias.lower().startswith("urn:mail:"):
        print(f"⛔ ALIAS biçimi geçersiz: {alias!r}\n"
              "   Beklenen: urn:mail:<kutu>@<firma>", file=sys.stderr)
        return 7
    if "irsaliye" in alias.lower():
        print(f"⛔ İRSALİYE kutusu seçilmiş: {alias}\n"
              "   Fatura irsaliye kutusuna gönderilmez; portal 'başarılı' der ama ULAŞMAZ.\n"
              "   Fatura kutusu için 'defaultpk' benzeri etiketi kullan.", file=sys.stderr)
        return 7
    return 0


#: 🔴 Uygulama yanıtı — YALNIZ TİCARİ senaryoda mümkündür (belge s.1):
#:   "UYGULAMA YANITI: Ticari Fatura senaryosundaki e-faturalar için gönderilebilen
#:    belgelerdir… Temel Fatura senaryosundaki faturalar için uygulama yanıtı oluşturulamaz."
#: Bu yüzden senaryo kapısı burada, GÖNDERİM ÖNCESİ koşar: temel faturaya red denemesi
#: e-Logo'da hata üretirdi ve o hata "süre doldu" ile karışabilirdi.
YANIT_TURLERI = frozenset({"KABUL", "RED"})


def yanit_zarf_kur(sid: str, hedef_uuid: str, tur: str, aciklama: str,
                   alias: str) -> str:
    """`CREATEAPPLICATIONRESPONSE` zarfı — belge verisi YOK, datayı e-Logo üretir (belge s.7).

    🔴 Niçin `CREATEAPPLICATIONRESPONSE`, `APPLICATIONRESPONSE` değil: ikincisi UBL
    `ApplicationResponse` belgesini BİZİM kurmamızı ister. Kendi elimizle kurmadığımız
    bir belgeyi göndermek, kuruş kapısı olmayan bir yol açmak olurdu; sistemin ürettiği
    veri ise şematron uyumunu üreticinin sorumluluğunda tutar.
    """
    if tur not in YANIT_TURLERI:
        raise GonderimHatasi(f"yanıt türü '{tur}' tanınmıyor (izinli: {' · '.join(sorted(YANIT_TURLERI))})")
    if not re.fullmatch(r"[0-9A-Fa-f-]{36}", hedef_uuid or ""):
        raise GonderimHatasi(f"hedef fatura ETTN'i 36 haneli UUID olmalı: {hedef_uuid!r}")
    if not (aciklama or "").strip():
        raise GonderimHatasi("RED/KABUL açıklaması boş olamaz — gerekçesiz yanıt kayıt bırakmaz")
    for parca in (aciklama, alias, tur):
        if any(c in (parca or "") for c in "<>&"):
            raise GonderimHatasi(f"XML'i bozacak karakter var: {parca!r}")
    params = ["DOCUMENTTYPE=CREATEAPPLICATIONRESPONSE", f"UUID={hedef_uuid}",
              f"APPLICATIONRESPONSE={tur}", f"DESCRIPTION={aciklama}", f"ALIAS={alias}"]
    satirlar = "".join(f"<a:string>{x}</a:string>" for x in params)
    return (f"<t:SendDocument><t:sessionID>{sid}</t:sessionID>"
            f'<t:paramList xmlns:a="{ARR_NS}">{satirlar}</t:paramList></t:SendDocument>')


def ortam_kilidi_dogrula(canli: bool, kilit_yolu=None) -> int:
    """Ortam kilidini sınar. 0 = yol açık · 6 = RET. Ekrana gerekçe basar.

    🔴 FAIL-CLOSED (2026-08-23'te düzeltildi). Eski hâli FAIL-OPEN'dı ve ölçüldü: kontrol
    `if kilit == "demo"` idi — NEGATİF bir kontrol. Kilit dosyası yok · boş · okunamaz ·
    yazım hatalı ("demoo") · tanınmayan ("prod") olduğu HER durumda `--canli` gönderimi ağ
    katmanına ULAŞIYORDU. Yedi değerle firsthand ölçüldü, DÖRDÜ sızdırdı.

    Portal tarafı (`elogo-portal-otomasyon/scripts/kilit.py: portal_sec`) aynı işi POZİTİF
    listeyle yapıyor ve yedi değerin yedisinde de duruyordu. İki kapı aynı hattı koruyor
    ama farklı dillerde konuşuyordu. Belgelenmiş "geriye-uyum" gerekçesi `elogo.sh` içindi —
    oysa `elogo.sh`'ta `gonder` altkomutu YOK: fatura doğrudan buradan gidiyor. Yani gerekçe,
    hattın EN GERİ ALINAMAZ yoluna sessizce miras kalmıştı.

    🔴 BU, KİLİT SÖZLEŞMESİNİN TEK EVİDİR (MUAVİN kararı 2026-08-23).
    Bir zamanlar ikinci bir kopya `elogo-portal-otomasyon/scripts/kilit.py: portal_sec`
    içindeydi. O beceri EMEKLİ edildi (portal yolu kuruş kuralını sağlayamıyor) ve o kopya
    beceriyle birlikte ölüyor. Önceki plan "elogo_gonder kilit.py'yi çağırsın" idi; MUAVİN
    o öneriyi geri aldı ve gerekçesi doğru: **canlı bir beceriyi emekli bir beceriye
    bağlamak, canlı bir sözleşmenin kopyasını ölü bir evde bırakırdı** — ikisi bir gün
    ayrışır ve kimse fark etmez.
    ⚠️ Portal yolu bir gün dirilirse kilidi BURADAN çağırsın; orada yeniden yazılmasın.

    Sessizce demoya DÜŞÜRMEZ: canlı sandığın faturayı demoya gönderip gönderdiğini sanmak
    da bir kayıptır — ret, insanı bilinçli karara zorlar.
    """
    # 🔴 ÖLÇÜLDÜ 2026-08-27: burada `Path(os.environ.get(...,"")) or <varsayılan>` yazıyordu.
    #    `Path("")` boş DEĞİLDİR — `PosixPath('.')`'tır ve TRUTHY'dir. Yani `or` varsayılana
    #    ASLA düşmüyor, kilit yolu her zaman "." oluyor, kilit dosyası HİÇ OKUNMUYORDU.
    #    Sonuç: varsayılan çağrıda canlı gönderim HER ZAMAN rc=6 ("kilit okunamadı") —
    #    kilit sapasağlam yerinde dururken. Yön güvenliydi (yanlış gönderim üretmez) ama
    #    kapı, ölçtüğünü sandığı şeyi ÖLÇMÜYORDU: "okunamadı" diyen bir kapı, okumayı
    #    hiç denememişti. Bu, becerinin kendi kuralının ihlaliydi: ölçemediğine "yok" deme.
    #    ⚠️ Bunu bir kez daha görmüştüm ve KENDİ SINAVIMIN hatası sanmıştım (`kilit_yolu=None`
    #    geçince "okunamadı" dalına düşüyordu). None VARSAYILANIN TA KENDİSİYDİ — yani o gün
    #    ürünün kusuruna bakıp kendi elimi suçladım. Kayıt buraya düşüyor ki tekrarlanmasın.
    ozel = os.environ.get("ELOGO_ORTAM_KILIDI", "").strip()
    kilit_yolu = kilit_yolu or (Path(ozel) if ozel else Path.home() / ".config" / "elogo-ortam")
    kilit = ""
    try:
        kilit = kilit_yolu.read_text(encoding="utf-8").strip().lower()
    except OSError:
        pass
    if not canli:
        return 0
    if kilit not in TANINAN_KILIT:
        nasil = "okunamadı" if not kilit else f"tanınmayan bir değer taşıyor ({kilit!r})"
        print(f"⛔ FAIL-CLOSED · ortam kilidi {nasil} ({kilit_yolu}) — canlı gönderim YAPILMADI.",
              file=sys.stderr)
        print("   Burada 'bilmiyorum', 'izin var' DEĞİLDİR: gönderimin geri dönüşü yoktur.",
              file=sys.stderr)
        print(f"   Çözüm: kilidi bilinçli yaz →  echo canli > {kilit_yolu}", file=sys.stderr)
        return 6
    if kilit == "demo":
        print(f"⛔ Bu kutu DEMO ortamına kilitli ({kilit_yolu}) — canlı gönderim REDDEDİLDİ.",
              file=sys.stderr)
        print("   Canlıya geçmek bilinçli bir adımdır: kilit dosyasını Sultan değiştirir.",
              file=sys.stderr)
        return 6
    return 0


def onayi_dogrula(beyan: str) -> str:
    """K3 — beyan var mı, bir şey söylüyor mu."""
    b = (beyan or "").strip()
    RECETE = (
        "   Beklenen: TARİH + Sultan'ın kendi sözünden kırpık\n"
        '   (ör. 21.08.2026 Sultan: "bu faturayı gönder").'
    )
    if b.lower() in YER_TUTUCULAR or len(b) < 12:
        raise GonderimHatasi(
            "Sultan onayı beyanı boş ya da yer-tutucu — gönderim YAPILMADI.\n" + RECETE
        )
    # 🔴 Uzunluk zayıf bir ölçüdür: "tamam gönder" tam 12 karakterdir ve hiçbir şey
    #    kanıtlamaz. Beyanın işe yaraması için SONRADAN bulunabilir olması gerekir —
    #    onu da tarih sağlar. Bu kapı sınavda düştüğü için eklendi, tahminle değil.
    if not re.search(r"\d{1,4}[./-]\d{1,2}[./-]\d{2,4}", b):
        raise GonderimHatasi(
            "Onay beyanında TARİH yok — gönderim YAPILMADI.\n"
            "   Tarihsiz onay sonradan hangi konuşmaya ait olduğu bulunamaz.\n" + RECETE
        )
    return b


def gonder(sid: str, url: str, paket: dict[str, str], onay: str,
           alias: str | None = None, tasarim: str = "varsayilan",
           belge_tipi: str = "EINVOICE") -> dict[str, str]:
    """🔴 GERİ ALINAMAZ. Yalnız dört kapı da geçildikten sonra çağrılır."""
    onayi_dogrula(onay)
    xml = S._cagir(url, "SendDocument", zarf_kur(sid, paket, alias, tasarim, belge_tipi))
    return {
        "resultCode": S._alan(xml, "resultCode") or "?",
        "resultMsg": S._alan(xml, "resultMsg") or "",
        "errorCode": S._alan(xml, "errorCode") or "",
        "refId": S._alan(xml, "refId") or "",
    }


def _main(argv: list[str]) -> int:
    import argparse

    a = argparse.ArgumentParser(description="e-Logo'ya e-Fatura gönderir (varsayılan: KURU KOŞUM)")
    a.add_argument("xml", help="gönderilecek UBL XML dosyası")
    a.add_argument("--belge-adi", help="zip/belge adı (varsayılan: dosya adı)")
    a.add_argument("--alias", help="alıcı etiketi · GERÇEK GÖNDERİMDE ZORUNLU "
                                   "(örn. urn:mail:defaultpk@ornekfirma)")
    a.add_argument("--tasarim", default="varsayilan",
                   help="görsel tasarım: varsayilan | <uuid> | gomulu (varsayılan: varsayilan)")
    a.add_argument("--belge-tipi", default="EINVOICE", choices=["EINVOICE", "EARCHIVE"],
                   help="EARCHIVE = e-Fatura mükellefi OLMAYAN alıcıya")
    a.add_argument("--canli", action="store_true", help="🔴 CANLI ortam (varsayılan: demo)")
    a.add_argument("--gercekten-gonder", action="store_true",
                   help="🔴 K2'yi açar — bu bayrak olmadan AĞA ÇIKILMAZ")
    a.add_argument("--sultan-onayi", default="", help="K3 — onay beyanı (gönderim için şart)")
    n = a.parse_args(argv)

    from elogo_paket import paketle, PaketHatasi

    yol = Path(n.xml)
    ad = n.belge_adi or yol.stem
    try:
        paket = paketle(yol.read_bytes(), ad)
    except (PaketHatasi, OSError) as e:
        print(f"⛔ paketlenemedi: {e}", file=sys.stderr)
        return 1

    rc_kilit = ortam_kilidi_dogrula(n.canli)
    if rc_kilit:
        return rc_kilit
    ortam = "ELOGO" if n.canli else "ELOGO_DEMO"
    print(f"ortam : {'🔴 CANLI' if n.canli else 'demo'}")
    print(f"belge : {paket['fileName']} · özet {paket['hash']}")
    print(f"etiket: {n.alias or '(verilmedi — alıcının tek etiketi varsa oraya gider,'
                                ' birden fazlaysa e-Logo hata döndürür)'}")

    rc_alias = alias_dogrula(n.alias, n.gercekten_gonder, n.belge_tipi)
    if rc_alias:
        return rc_alias

    if not n.gercekten_gonder:
        try:
            zarf_kur("KURU-KOSUM", paket, n.alias, n.tasarim, n.belge_tipi)
        except GonderimHatasi as e:
            print(f"⛔ zarf kurulamadı: {e}", file=sys.stderr)
            return 1
        print("\n✓ KURU KOŞUM — zarf kuruldu, ağa çıkılmadı, hiçbir fatura gönderilmedi.")
        print("  Gerçekten göndermek için: --gercekten-gonder --sultan-onayi \"…\"")
        return 0

    try:
        onayi_dogrula(n.sultan_onayi)
    except GonderimHatasi as e:
        print(f"⛔ {e}", file=sys.stderr)
        return 3

    kullanici, parola, url = S.kimlik_env(ortam)
    sid = S.login(kullanici, parola, url)
    try:
        s = gonder(sid, url, paket, n.sultan_onayi, n.alias, n.tasarim, n.belge_tipi)
    finally:
        S.logout(sid, url)

    print(f"\nsonuç : resultCode={s['resultCode']} · refId={s['refId']}")
    if s["resultMsg"]:
        print(f"mesaj : {s['resultMsg']}")
    if s["resultCode"] != "1":
        print(f"⛔ GÖNDERİLMEDİ (errorCode={s['errorCode']})", file=sys.stderr)
        return 4
    print("✓ gönderildi.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
