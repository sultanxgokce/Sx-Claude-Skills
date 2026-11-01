#!/usr/bin/env python3
"""sinav-boru-kapi.py — sınav dosyalarında boru arkası sessiz grep kapısı.
pipefail açıkken `komut | grep -q x` grep erken çıkınca yazan komutu 141 ile düşürür; sınav doğru sonucu "yanlış" sayar, CI rastgele kırmızı olur (Sx 09781b28).
  python3 scripts/sinav-boru-kapi.py            → denetler, kalıp varsa satırları basar, rc 1
  python3 scripts/sinav-boru-kapi.py --yaz      → kalıbı `| grep x >/dev/null` biçimine çevirir (çıktının tamamı okunur, davranış aynı)
Yalnız `git ls-files '*.test.sh'` içinde ve pipefail açan dosyalara bakar.
"""
import re, subprocess, sys

BAS = re.compile(r"\|&?[ \t]*([ef]?grep)\b")
SON = ("&&", "||", ";", ")", "|", "\n", "}", "`")


def kelimeler(s, i):
    """i'den başlayarak grep'in argümanlarını (başlangıç, bitiş) olarak verir; kabuk işlecinde durur."""
    k = []
    n = len(s)
    while True:
        while i < n and s[i] in " \t":
            i += 1
        if i >= n or any(s.startswith(x, i) for x in SON):
            return k, i
        if re.match(r"\d*[<>]", s[i:]) or s[i:].rstrip() == "\\":
            return k, i
        b = i
        while i < n and s[i] not in " \t\n;|&)}`":
            c = s[i]
            if c == "\\":
                i += 2
            elif c == "'":
                j = s.find("'", i + 1)
                if j < 0:
                    return None, i
                i = j + 1
            elif c == '"':
                j = i + 1
                while j < n and s[j] != '"':
                    j += 2 if s[j] == "\\" else 1
                if j >= n:   # kapanmayan tırnak: bu, dıştaki `bash -c "..."` dizgesinin sonu; argümanlar burada biter
                    if i == b:
                        return k, i
                    break
                i = j + 1
            else:
                i += 1
        k.append((b, i))


def sessiz(t):
    return t in ("--quiet", "--silent") or re.fullmatch(r"-[a-zA-Z]*q[a-zA-Z]*", t) is not None


def tara(metin):
    """(satır, kelime başı, kelime sonu, argüman sonu) listesi; heredoc gövdeleri atlanır."""
    sonuc = []
    konum = 0
    bitis = None
    for no, satir in enumerate(metin.split("\n"), 1):
        if bitis is not None:
            if satir.strip() == bitis:
                bitis = None
            konum += len(satir) + 1
            continue
        for m in BAS.finditer(satir):
            k, son = kelimeler(satir, m.end())
            for b, e in k or []:
                if sessiz(satir[b:e]):
                    sonuc.append((no, konum + b, konum + e, konum + son))
                    break
        h = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", satir)
        if h:
            bitis = h.group(1)
        konum += len(satir) + 1
    return sonuc


def cevir(metin):
    for _, b, e, son in reversed(tara(metin)):
        t = metin[b:e]
        if t.startswith("--"):
            yeni = ""
        else:
            yeni = t.replace("q", "")
            yeni = "" if yeni == "-" else yeni
        ek = " >/dev/null"
        parca = metin[e:son].rstrip(" \t")
        bas = metin[:b] + yeni
        if not yeni:
            bas = bas.rstrip(" \t")
        metin = bas + parca + ek + metin[e + len(parca):]
    return metin


def main():
    yaz = "--yaz" in sys.argv
    kalan = 0
    for f in subprocess.check_output(["git", "ls-files", "*.test.sh"], text=True).split():
        s = open(f, encoding="utf-8").read()
        if "pipefail" not in s:
            continue
        if yaz:
            y = cevir(s)
            if y != s:
                open(f, "w", encoding="utf-8").write(y)
            s = y
        for no, *_ in tara(s):
            kalan += 1
            print(f"{f}:{no}: boru arkasında sessiz grep")
    print(f"sınav boru kapısı: {kalan} satır")
    return 1 if kalan else 0


if __name__ == "__main__":
    sys.exit(main())
