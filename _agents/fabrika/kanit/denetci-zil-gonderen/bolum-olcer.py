#!/usr/bin/env python3
"""bolum-olcer.py <bölüm deseni> [<ek desen>...] -- <komut...>
Komutu koşar; çıktının YALNIZ verilen bölümünü (desenle başlayan satırdan bir sonraki bölüm başlığına kadar), ek desenleri
taşıyan satırları ve SON satırı basar; komutun çıkış koduyla çıkar. NİÇİN: denetçi (kurulu fabrika ≤0.10.5) her ölçümün
ilk 60 satırını görüyor; uzun bir sınavda yeni bölüm ve sonuç satırı göze hiç gitmiyor. Bu ölçüm, sınavın tamamını
koşturup göze gereken parçayı kısa bir kayıtta verir — sınav kendisi kırpılmaz, ayrı kaydı tam duruyor.
"""
import re, subprocess, sys
a = sys.argv[1:]; i = a.index("--"); desenler, komut = a[:i], a[i + 1:]
p = subprocess.run(komut, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
L = p.stdout.splitlines()
bas = next((k for k, x in enumerate(L) if desenler[0] in x), None)
print(f"$ {' '.join(komut)}  → rc={p.returncode} · {len(L)} satır")
if bas is None:
    print(f"✗ bölüm bulunamadı: {desenler[0]!r}"); sys.exit(p.returncode or 1)
son = next((k for k in range(bas + 1, len(L)) if re.match(r"^(════|──|[A-Z][A-Za-zÇĞİÖŞÜ]* · )", L[k]) and desenler[0] not in L[k]
            and not any(d in L[k] for d in desenler[1:])), len(L))
print("\n".join(L[bas:son]))
ek = [x for k, x in enumerate(L) if (k < bas or k >= son) and any(d in x for d in desenler[1:])]
if ek: print("…"); print("\n".join(ek))
print("…"); print(next((x for x in reversed(L) if x.strip()), ""))
sys.exit(p.returncode)
