#!/usr/bin/env python3
"""Uygulama yanıtı (KABUL/RED) TASLAĞI kurar ve DURUR. GÖNDERMEZ.

🔴 Bu betiğin içinde ağa çıkan tek şey ÖLÇÜMDÜR (senaryo · mevcut yanıt), gönderim DEĞİL.
   Gönderim ayrı bir fiildir ve Sultan'ın elidir.

Kullanım:
  yanit_hazirla.py <ETTN> RED|KABUL --aciklama "…" [--alias urn:mail:…] [--canli]
"""
import argparse, base64, io, os, re, sys, zipfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import elogo_soap as S
from elogo_gonder import (yanit_zarf_kur, GonderimHatasi, alias_dogrula,
                          ortam_kilidi_dogrula, onayi_dogrula)


def _coz(b):
    try:
        z = zipfile.ZipFile(io.BytesIO(b)); return z.read(z.namelist()[0]).decode("utf-8", "replace")
    except Exception:
        return b.decode("utf-8", "replace")


def olc(sid, url, ettn):
    """Faturayı ÖLÇER: senaryo · taraflar · tutar · daha önce yanıt verilmiş mi."""
    y = S._cagir(url, "getInvoice",
                 f'<getInvoice xmlns="http://tempuri.org/"><invoiceID>{ettn}</invoiceID>'
                 f'<sessionID>{sid}</sessionID></getInvoice>')
    m = re.search(r"<a:Value>([^<]+)</a:Value>", y)
    if not m:
        raise GonderimHatasi(f"fatura bulunamadı ya da verisi gelmedi: {ettn}")
    x = _coz(base64.b64decode(m.group(1)))
    al = lambda t: (re.findall(rf"<cbc:{t}[^>]*>([^<]*)</", x) or ["?"])[0]
    sat = re.search(r"<cac:AccountingSupplierParty>(.*?)</cac:AccountingSupplierParty>", x, re.S)
    alc = re.search(r"<cac:AccountingCustomerParty>(.*?)</cac:AccountingCustomerParty>", x, re.S)
    vkn = lambda blok: (re.findall(r"<cbc:ID[^>]*>(\d{10,11})</", blok.group(1)) or ["?"])[0]
    unv = lambda blok: (re.findall(r"<cbc:Name>([^<]*)</", blok.group(1)) or ["?"])[0]
    # daha önce yanıt verilmiş mi — 🔴 üç durum, "yok" ile "ölçemedim" ayrı.
    #
    # 🔴 KUSUR VE ONARIMI (ölçüldü 2026-08-29): burada YALNIZ `getAppRespStatus` vardı ve o
    #    metot, yanıt FİİLEN KAYDEDİLDİKTEN SONRA BİLE "Uygulama yanıtı sistemde bulunamadı"
    #    demeye devam ediyor (firsthand: RED gönderildi, kayıt oluştu, metot hâlâ "bulunamadı").
    #    Yani kapı, yanıt verilmiş bir faturayı "yanıtsız" sanardı → MÜKERRER YANIT riski.
    #    Asıl ölçüm `getInvoiceApplicationResponse`'tur; dönüş değerleri kontrol gruplu
    #    ölçümle çözüldü (24-29 Ağustos, 53 gelen fatura):
    #      4 → TEMELFATURA · uygulama yanıtı verilemez   (51 fatura)
    #      0 → TİCARİ, yanıt VERİLMEMİŞ                  (1 fatura, kontrol grubu)
    #      2 → TİCARİ, yanıt VAR                         (1 fatura — RED'imizi gönderdiğimiz)
    #    Kanıtın gücü kontrol grubundan gelir: aynı sınıftaki iki faturadan YALNIZ yanıt
    #    gönderdiğimiz 0'dan 2'ye geçti, öteki 0'da kaldı.
    #    ⏸ ÖLÇÜLMEDİ: 2'nin RED mi KABUL mü olduğunu ayırt edip etmediği (elimizde kabul yok).
    try:
        y = S._cagir(url, "getInvoiceApplicationResponse",
                     f'<getInvoiceApplicationResponse xmlns="http://tempuri.org/">'
                     f'<sessionID>{sid}</sessionID><uuid>{ettn}</uuid></getInvoiceApplicationResponse>')
        kod = (re.findall(r"<getInvoiceApplicationResponseResult>([^<]*)</", y) or ["?"])[0]
        yanit = {"0": "yok", "2": "VAR", "4": "verilemez (temel fatura)"}.get(
            kod, f"ÖLÇÜLEMEDİ (tanınmayan kod {kod!r})")
    except Exception as e:
        yanit = f"ÖLÇÜLEMEDİ ({str(e)[:40]})"
    return {"no": al("ID"), "senaryo": al("ProfileID"), "tip": al("InvoiceTypeCode"),
            "satici_vkn": vkn(sat), "alici_vkn": vkn(alc),
            "tarih": al("IssueDate"), "odenecek": (re.findall(r"<cbc:PayableAmount[^>]*>([^<]*)</", x) or ["?"])[0],
            "satici": f"{unv(sat)} · {vkn(sat)}", "alici": f"{unv(alc)} · {vkn(alc)}",
            "onceki_yanit": yanit}


def main(argv):
    a = argparse.ArgumentParser(description="Uygulama yanıtı TASLAĞI (göndermez)")
    a.add_argument("ettn"); a.add_argument("tur", choices=["RED", "KABUL"])
    a.add_argument("--aciklama", required=True)
    a.add_argument("--alias", default="")
    a.add_argument("--canli", action="store_true")
    a.add_argument("--gercekten-gonder", action="store_true",
                   help="🔴 GERİ ALINAMAZ. Yoksa yalnız taslak basılır.")
    a.add_argument("--sultan-onayi", default="", help="K3 — onay beyanı (gönderim için şart)")
    n = a.parse_args(argv)

    # 🔴 Kilit, ölçümden ÖNCE. Niçin: canlıya gitmeyecek bir işte canlı oturum açmak
    #    gereksiz bir yetki kullanımıdır; ret erken gelsin.
    if n.gercekten_gonder:
        rc = ortam_kilidi_dogrula(n.canli)
        if rc:
            return rc

    k, p, u = S.kimlik_env("ELOGO" if n.canli else "ELOGO_DEMO")
    sid = S.login(k, p, u)
    try:
        f = olc(sid, u, n.ettn)
    finally:
        S.logout(sid, u)

    print("── ÖLÇÜM (e-Logo'daki belgeden) ──")
    for etiket, deger in (("fatura no", f["no"]), ("senaryo", f["senaryo"]), ("tip", f["tip"]),
                          ("tarih", f["tarih"]), ("ödenecek", f["odenecek"]),
                          ("satıcı", f["satici"]), ("alıcı", f["alici"]),
                          ("yön", "BİZE GELEN" if f["alici_vkn"] == (os.environ.get("MMEX_BIZ_VKN") or "").strip()
                                  else "🔴 BİZE GELMEMİŞ"),
                          ("önceki yanıt", f["onceki_yanit"])):
        print(f"  {etiket:14}: {deger}")

    # 🔴 KAPI 0 — YÖN. Yanıt, BİZE GELEN bir faturaya verilir.
    #
    #    ÖLÇÜLMÜŞ AÇIK (2026-08-29, hata avı): burada hiçbir kontrol YOKTU. Kendi
    #    kestiğimiz `FGW2026000000994`'ün ETTN'i verildiğinde — satıcısı BİZ, alıcısı
    #    ana alıcı — taslak sorunsuz kuruldu ve senaryo kapısı da geçirdi (o fatura da
    #    TİCARİ). `--gercekten-gonder` eklenseydi KENDİ FATURAMIZA red gönderilecekti.
    #    Senaryo kapısı bunu yakalayamaz: yön ile senaryo bağımsız iki şeydir.
    #
    #    🔴 Fail-closed: kimliğimiz bilinmiyorsa GEÇMEZ. "Bilmiyorum", "izin var" değildir.
    biz = (os.environ.get("MMEX_BIZ_VKN") or "").strip()
    if not biz:
        print("\n⛔ YÖN KAPISI · kendi VKN'miz bilinmiyor (MMEX_BIZ_VKN yok).\n"
              "   Yanıtın BİZE GELEN bir faturaya verildiği doğrulanamaz — DURULDU.",
              file=sys.stderr)
        return 5
    if f["alici_vkn"] != biz:
        print(f"\n⛔ YÖN KAPISI · bu fatura BİZE GELMEMİŞ.\n"
              f"   faturanın alıcısı : {f['alici_vkn']}\n"
              f"   biz               : {biz}\n"
              f"   satıcı            : {f['satici_vkn']}\n"
              "   Uygulama yanıtı, ALDIĞIMIZ faturaya verilir. Kendi kestiğimiz faturaya\n"
              "   yanıt göndermek anlamsızdır ve geri alınamaz. DURULDU.", file=sys.stderr)
        return 5

    # 🔴 KAPI 1 — senaryo. Temel faturaya uygulama yanıtı OLUŞTURULAMAZ (belge s.1).
    if f["senaryo"] != "TICARIFATURA":
        print(f"\n⛔ SENARYO KAPISI · '{f['senaryo']}' — uygulama yanıtı YALNIZ TİCARİ faturada\n"
              "   mümkündür. Red yolu KAPALI; bu belge için iade faturası yolu değerlendirilir.",
              file=sys.stderr)
        return 3
    # 🔴 KAPI 2 — zaten yanıt verilmişse ikincisi mükerrerdir.
    if f["onceki_yanit"] != "yok":
        print(f"\n⛔ ÖNCEKİ YANIT KAPISI · durum: {f['onceki_yanit']}\n"
              "   'ÖLÇÜLEMEDİ' de bir geçiş sebebi DEĞİLDİR — mükerrer yanıt riski açıktır.",
              file=sys.stderr)
        return 4

    rc = alias_dogrula(n.alias, True)
    if rc:
        return rc

    print("\n── TASLAK ──")
    for satir in re.findall(r"<a:string>([^<]*)</a:string>",
                            yanit_zarf_kur("KURU-KOSUM", n.ettn, n.tur, n.aciklama, n.alias)):
        print("  " + satir)

    if not n.gercekten_gonder:
        print("\n🔴 DURULDU — gönderilmedi. Göndermek için: --gercekten-gonder --sultan-onayi \"…\"")
        return 0

    try:
        onayi_dogrula(n.sultan_onayi)
    except GonderimHatasi as e:
        print(f"⛔ {e}", file=sys.stderr); return 3

    sid = S.login(k, p, u)
    try:
        y = S._cagir(u, "SendDocument", yanit_zarf_kur(sid, n.ettn, n.tur, n.aciklama, n.alias))
    finally:
        S.logout(sid, u)
    rc = (re.findall(r"<[a-z]*:?resultCode>([^<]*)</", y) or ["?"])[0]
    ms = (re.findall(r"<[a-z]*:?resultMsg>([^<]*)</", y) or [""])[0]
    ref = (re.findall(r"<[a-z]*:?refId>([^<]*)</", y) or ["?"])[0]
    print(f"\nsonuç : resultCode={rc} · refId={ref}")
    print(f"mesaj : {ms[:200]}")
    if rc != "1":
        print("⛔ GÖNDERİLMEDİ.", file=sys.stderr); return 4
    print("✓ gönderildi. 🔴 'gönderildi' ≠ 'ulaştı': doğrulama ayrı adımdır (getAppRespStatus).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
