#!/usr/bin/env python3
"""Bir birleşik-diff metninden, verilen YOLA ait bölümü kesip basar.

Niçin awk değil python (bağımsız göz bulgusu, tur 3): git, `core.quotePath` açıkken (varsayılan)
ASCII dışı ve özel karakterli yolları diff başlığında TIRNAKLAR **ve C biçiminde KAÇIŞLAR**:

    diff --git "a/\\303\\266l\\303\\247\\303\\274m dosyas\\304\\261.sh" "b/..."

Bu, `ölçüm dosyası.sh` yolunun sekizlik kaçışlı UTF-8 hâlidir (gerçek git çıktısıyla ölçüldü).
Ham yolu arayan bir eşleştirici bunu bulamaz ve geçerli bir yalnız-kip dosyası rc=3'e düşer.
Bu dosyada sadece doğru ayrıştırma var; karar çağıranın.

Çıkış: 0 bölüm bulundu (stdout'a basıldı) · 1 bulunamadı.
"""
import re
import sys


def coz(jeton: str) -> str:
    """Git'in diff başlığındaki bir yol jetonunu çözer (tırnaklı/kaçışlı olabilir)."""
    if len(jeton) >= 2 and jeton[0] == '"' and jeton[-1] == '"':
        ic = jeton[1:-1]
        # C-kaçışları: \\ \" \t \n ve \NNN (sekizlik, UTF-8 baytı)
        try:
            ham = ic.encode("latin-1", "backslashreplace").decode("unicode_escape")
            return ham.encode("latin-1").decode("utf-8")
        except (UnicodeDecodeError, UnicodeEncodeError):
            return ic
    return jeton


def basliktan_yollar(satir: str):
    """`diff --git <a> <b>` satırından iki yolu çıkarır; tırnaklı biçimi doğru böler."""
    kalan = satir[len("diff --git "):].strip()
    jetonlar = re.findall(r'"(?:\\.|[^"\\])*"|\S+', kalan)
    if len(jetonlar) != 2:
        # Tırnaksız ve boşluklu ad: `a/X b/X` — ortadaki " b/" ayracından böl.
        i = kalan.find(" b/")
        if i == -1:
            return []
        jetonlar = [kalan[:i], kalan[i + 1:]]
    out = []
    for j in jetonlar:
        y = coz(j)
        if y.startswith(("a/", "b/")):
            y = y[2:]
        out.append(y)
    return out


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("kullanım: bolum-ayikla.py <fark-dosyasi> <yol>\n")
        return 2
    fark_yolu, hedef = argv
    with open(fark_yolu, encoding="utf-8", errors="surrogateescape") as f:
        satirlar = f.read().splitlines()

    bas, cikti = False, []
    for s in satirlar:
        if s.startswith("diff --git "):
            bas = hedef in basliktan_yollar(s)
        if bas:
            cikti.append(s)
    if not cikti:
        return 1
    sys.stdout.write("\n".join(cikti) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
