#!/usr/bin/env python3
"""ilk-tur-olc.py <depo>... — depoların origin/main ağacındaki DENETIM-1.json kayıtlarından İLK TURDA 5/E oranını ve
ilk turda kalanların bulgu sınıflarını ölçer. Yalnız okur (git ls-tree + git show); yerel değişikliklere bakmaz."""
import json, re, subprocess, sys, collections

SINIF = [   # (ad, desen) — bulgunun "ne"+"kanit" metninde; ilk eşleşen sınıf
    ("kanit-bayat/eksik", r"kanıt.*(bayat|eski|eksik|yok|ölçmüyor|göstermiyor)|ölçüm.*(yok|eksik|bayat)|kanıtlanmamış|kayıt yok"),
    ("kapsam/kart", r"kapsam|kart(ın)? (cümle|iste)|talep|daralt|kart dışı|istenen"),
    ("kenar-durum", r"kenar|boş|eksik veri|sınır durum|null|hata kodu|zaman aşımı|rc=|çökme|yanlış pozitif|kaçış|atla"),
    ("sinav-yetersiz", r"sınav|test|mutant|mutasyon|kapı ölçmüyor|vaka"),
    ("belge/rotus", r"belge|yorum|SKILL|README|metin|sürüm|açıklama"),
]

def git(d, *a):
    return subprocess.run(["git", "-C", d, *a], capture_output=True, text=True).stdout

toplam = gecen = 0; siniflar = collections.Counter(); ornek = collections.defaultdict(list); depo_say = {}
for d in sys.argv[1:]:
    yollar = [y for y in git(d, "ls-tree", "-r", "--name-only", "origin/main").splitlines()
              if re.search(r"_agents/fabrika/kanit/[^/]+/DENETIM-1\.json$", y)]
    t = g = 0
    for y in yollar:
        try: k = json.loads(git(d, "show", f"origin/main:{y}"))
        except Exception: continue
        s = k.get("sonuc") or {}
        t += 1
        if s.get("kod_puani") == 5 and s.get("dogru_sey") == "E":
            g += 1; continue
        for b in s.get("bulgular") or []:
            m = f"{b.get('ne','')} {b.get('kanit','')}"
            ad = next((a for a, p in SINIF if re.search(p, m, re.I)), "diğer")
            siniflar[ad] += 1
            if len(ornek[ad]) < 2: ornek[ad].append(f"{k.get('is')}: {b.get('ne','')[:90]}")
    depo_say[d.rstrip("/").split("/")[-1]] = (g, t); toplam += t; gecen += g
print("İLK TUR 5/E (origin/main, DENETIM-1.json):")
for a, (g, t) in depo_say.items(): print(f"  {a:22s} {g:3d}/{t:<3d} = %{100*g/max(t,1):.0f}")
print(f"  {'TOPLAM':22s} {gecen:3d}/{toplam:<3d} = %{100*gecen/max(toplam,1):.0f}")
b = sum(siniflar.values())
print(f"\nİlk turda kalan işlerin bulguları ({b}) — sınıf:")
for a, n in siniflar.most_common(): print(f"  {a:18s} {n:3d} (%{100*n/max(b,1):.0f})   örn: {' | '.join(ornek[a])}")
