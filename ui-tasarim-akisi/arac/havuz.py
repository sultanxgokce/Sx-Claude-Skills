#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""havuz.py — tasarım havuzu: ölçüm sonuçlarının merkezde biriktiği yer.

NİÇİN VAR
    Bir tasarım turunda öğrenilen şey bugüne kadar hiçbir yere düşmüyordu: kapı kırmızı
    yanıyor, düzeltiliyor, sonraki tur aynı hatayı yeniden keşfediyordu. Havuz o kaybı
    kapatır — hangi kutu, hangi ekran, hangi kapı, ne düştü.

ŞEMA KAPALIDIR — SERBEST METİN ALANI YOKTUR (bu bir güvenlik kararıdır)
    Havuz dosyası 13 kutunun ORTAK gördüğü bir dizindedir; izole bir kutu başkasının
    satırlarını okuyabilir. Bu yüzden şemada içerik taşıyacak hiçbir alan YOKTUR:
    alıntı yok, HTML yok, gerekçe metni yok, kişi/müşteri adı yok. Yalnız KOD ve SAYI.
    Bilinmeyen anahtar, uzun değer ya da desene uymayan değer → satır REDDEDİLİR
    (fail-closed). "Şuraya bir not düşeyim" diye alan eklenmez; eklenirse mahremiyet
    sınırı sessizce delinir.

KULLANIM
    havuz.py yaz --kutu akar --urun akar --ekran e4-bugun --kapi yogunluk \
                 --hukum kirmizi --dusen S2,X1 [--tur 3] [--arac 0.1.5]
    havuz.py oku  [--kutu akar] [--son 20]
    havuz.py ozet [--kutu akar]        # NAKKAŞ'ın okuduğu görünüm

    Havuz yolu: --havuz, yoksa $UI_AKIS_HAVUZ, yoksa ~/.claude/tasarim-havuz.jsonl

ÇIKIŞ: 0 tamam · 1 geçersiz kayıt (yazılmadı) · 2 çalıştırılamadı
"""
import json, os, re, sys, datetime

ANAHTARLAR = {
    "ts":     r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",
    "kutu":   r"^[a-z0-9][a-z0-9-]{0,23}$",
    "urun":   r"^[a-z0-9][a-z0-9-]{0,23}$",
    "ekran":  r"^[a-z0-9][a-z0-9._-]{0,39}$",
    "kapi":   r"^(yogunluk|yargi|tik)$",
    "hukum":  r"^(temiz|kirmizi|olcemedi|emin-degilim)$",
    "arac":   r"^[0-9]+\.[0-9]+\.[0-9]+$",
}
ZORUNLU = set(ANAHTARLAR) | {"dusen", "tur"}
DUSEN_DESENI = r"^[A-ZÇĞİÖŞÜ]{1,2}[0-9]{1,2}$"


def havuz_yolu(argv):
    if "--havuz" in argv:
        return argv[argv.index("--havuz") + 1]
    if os.environ.get("UI_AKIS_HAVUZ"):
        return os.environ["UI_AKIS_HAVUZ"]
    return os.path.join(os.path.expanduser("~"), ".claude", "tasarim-havuz.jsonl")


def dogrula(kayit):
    """Kapalı şema denetimi. Dönen liste boşsa kayıt geçerlidir."""
    hata = []
    fazla = set(kayit) - ZORUNLU
    if fazla:
        hata.append("şemada olmayan anahtar: %s (serbest metin alanı YOK)"
                    % ", ".join(sorted(fazla)))
    for a in sorted(ZORUNLU - set(kayit)):
        hata.append("eksik anahtar: %s" % a)
    for a, desen in ANAHTARLAR.items():
        if a not in kayit:
            continue
        d = kayit[a]
        if not isinstance(d, str):
            hata.append("%s metin olmalı" % a); continue
        if not re.match(desen, d):
            hata.append("%s desene uymuyor: %r (beklenen: %s)" % (a, d[:40], desen))
    if "tur" in kayit:
        if not isinstance(kayit["tur"], int) or not (0 <= kayit["tur"] <= 999):
            hata.append("tur 0-999 arası tam sayı olmalı")
    if "dusen" in kayit:
        d = kayit["dusen"]
        if not isinstance(d, list) or len(d) > 40:
            hata.append("dusen en çok 40 elemanlı liste olmalı")
        else:
            for k in d:
                if not isinstance(k, str) or not re.match(DUSEN_DESENI, k):
                    hata.append("dusen yalnız KOD alır (ör. S2, M4, X1) — gelen: %r" % (k,))
    return hata


def yaz(argv, yol):
    def al(ad, varsayilan=None):
        return argv[argv.index("--" + ad) + 1] if "--" + ad in argv else varsayilan

    dusen = [p.strip() for p in (al("dusen") or "").split(",") if p.strip()]
    kayit = {
        "ts":    al("ts") or datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kutu":  al("kutu") or "",
        "urun":  al("urun") or "",
        "ekran": al("ekran") or "",
        "kapi":  al("kapi") or "",
        "hukum": al("hukum") or "",
        "arac":  al("arac") or "0.0.0",
        "tur":   int(al("tur") or 0),
        "dusen": dusen,
    }
    hata = dogrula(kayit)
    if hata:
        sys.stderr.write("HAVUZ REDDETTİ — kayıt yazılmadı:\n")
        for h in hata:
            sys.stderr.write("  · %s\n" % h)
        return 1
    try:
        os.makedirs(os.path.dirname(yol) or ".", exist_ok=True)
        with open(yol, "a", encoding="utf-8") as f:
            f.write(json.dumps(kayit, ensure_ascii=False, sort_keys=True) + "\n")
    except OSError as e:
        sys.stderr.write("HAVUZA YAZILAMADI: %s\n" % e)
        return 2
    print("havuz +1 · %s/%s %s=%s%s" % (kayit["kutu"], kayit["ekran"], kayit["kapi"],
          kayit["hukum"], (" düşen:" + ",".join(dusen)) if dusen else ""))
    return 0


def satirlar(yol):
    if not os.path.isfile(yol):
        return []
    cikan = []
    with open(yol, encoding="utf-8") as f:
        for ham in f:
            ham = ham.strip()
            if not ham:
                continue
            try:
                k = json.loads(ham)
            except ValueError:
                continue
            if not dogrula(k):          # bozuk/şema-dışı satır okumada da sayılmaz
                cikan.append(k)
    return cikan


def oku(argv, yol):
    kayitlar = satirlar(yol)
    kutu = argv[argv.index("--kutu") + 1] if "--kutu" in argv else None
    if kutu:
        kayitlar = [k for k in kayitlar if k["kutu"] == kutu]
    son = int(argv[argv.index("--son") + 1]) if "--son" in argv else 20
    for k in kayitlar[-son:]:
        print("%s  %-6s %-16s %-8s %-12s %s" % (k["ts"], k["kutu"], k["ekran"],
              k["kapi"], k["hukum"], ",".join(k["dusen"])))
    print("— %d kayıt (havuz: %s)" % (len(kayitlar), yol))
    return 0


def ozet(argv, yol):
    """NAKKAŞ'ın görünümü: hangi kural en çok düşüyor, hangi kutu ne durumda."""
    kayitlar = satirlar(yol)
    kutu = argv[argv.index("--kutu") + 1] if "--kutu" in argv else None
    if kutu:
        kayitlar = [k for k in kayitlar if k["kutu"] == kutu]
    if not kayitlar:
        print("Havuz boş — ölçüm yapılmamış ya da havuz yolu yanlış: %s" % yol)
        print("Bu 'her şey temiz' DEĞİL, 'hiç bakılmamış' demektir.")
        return 0
    sayac, kutular, hukumler = {}, {}, {}
    for k in kayitlar:
        for d in k["dusen"]:
            sayac[d] = sayac.get(d, 0) + 1
        kutular[k["kutu"]] = kutular.get(k["kutu"], 0) + 1
        hukumler[k["hukum"]] = hukumler.get(k["hukum"], 0) + 1
    print("TASARIM HAVUZU · %d ölçüm · %d kutu" % (len(kayitlar), len(kutular)))
    print("hüküm: " + " · ".join("%s=%d" % (h, n) for h, n in sorted(hukumler.items())))
    print("kutu:  " + " · ".join("%s=%d" % (h, n) for h, n in sorted(kutular.items())))
    if sayac:
        print("\nEN ÇOK DÜŞEN KURALLAR (kural mı zor, tasarım mı zayıf — NAKKAŞ'ın sorusu):")
        for kod, n in sorted(sayac.items(), key=lambda x: (-x[1], x[0]))[:10]:
            print("  %-4s %d" % (kod, n))
    else:
        print("\nHiçbir kural düşmemiş.")
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stderr.write(__doc__); return 2
    yol = havuz_yolu(argv)
    komut = argv[1]
    if komut == "yaz":
        return yaz(argv, yol)
    if komut == "oku":
        return oku(argv, yol)
    if komut == "ozet":
        return ozet(argv, yol)
    sys.stderr.write("bilinmeyen komut: %s (yaz|oku|ozet)\n" % komut)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
