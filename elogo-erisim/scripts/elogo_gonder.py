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
             tasarim: str = "varsayilan") -> str:
    """SendDocument SOAP gövdesini kurar. Ağa çıkmaz — kuru koşum da bunu kullanır.

    Ön-ekler taşıyıcıdan (`elogo_soap._cagir`) gelir: `t` = tempuri,
    `d` = eFaturaWebService. Dizi ad-alanı orada tanımlı DEĞİL, burada
    yerinde bildirilir — taşıyıcının zarfını değiştirmemek için.
    """
    _paketi_dogrula(paket)
    if alias and ("<" in alias or ">" in alias or "&" in alias):
        raise GonderimHatasi(f"etikette XML'i bozacak karakter var: {alias}")

    params = ["DOCUMENTTYPE=EINVOICE"]
    if alias:
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
           alias: str | None = None, tasarim: str = "varsayilan") -> dict[str, str]:
    """🔴 GERİ ALINAMAZ. Yalnız dört kapı da geçildikten sonra çağrılır."""
    onayi_dogrula(onay)
    xml = S._cagir(url, "SendDocument", zarf_kur(sid, paket, alias, tasarim))
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
    a.add_argument("--alias", help="alıcı etiketi (opsiyonel — tek etiketliyse gerekmez)")
    a.add_argument("--tasarim", default="varsayilan",
                   help="görsel tasarım: varsayilan | <uuid> | gomulu (varsayılan: varsayilan)")
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

    # 🔴 ORTAM KİLİDİ — kutu demoya kilitliyse --canli REDDEDİLİR (Sultan kararı 2026-08-22).
    #    Gönderim geri alınamaz; bu yüzden kilit ASIL burada işler.
    kilit_yolu = Path(os.environ.get("ELOGO_ORTAM_KILIDI", "")) or Path.home() / ".config" / "elogo-ortam"
    kilit = ""
    try:
        kilit = kilit_yolu.read_text(encoding="utf-8").strip().lower()
    except OSError:
        pass
    if kilit == "demo" and n.canli:
        print(f"⛔ Bu kutu DEMO ortamına kilitli ({kilit_yolu}) — canlı gönderim REDDEDİLDİ.",
              file=sys.stderr)
        print("   Canlıya geçmek bilinçli bir adımdır: kilit dosyasını Sultan değiştirir.",
              file=sys.stderr)
        return 6
    ortam = "ELOGO" if (n.canli and kilit != "demo") else "ELOGO_DEMO"
    print(f"ortam : {'🔴 CANLI' if n.canli else 'demo'}")
    print(f"belge : {paket['fileName']} · özet {paket['hash']}")
    print(f"etiket: {n.alias or '(verilmedi — alıcının tek etiketi varsa oraya gider,'
                                ' birden fazlaysa e-Logo hata döndürür)'}")

    if not n.gercekten_gonder:
        try:
            zarf_kur("KURU-KOSUM", paket, n.alias, n.tasarim)
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
        s = gonder(sid, url, paket, n.sultan_onayi, n.alias, n.tasarim)
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
