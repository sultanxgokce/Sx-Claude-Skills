#!/usr/bin/env bash
# kayit-korunumu-olc.sh — bu iş ortak kayıt dosyalarına YALNIZ kendi satırını mı ekledi?
# Ana daldaki her beceri kaydı ve her dağıtım hedefi çalışma kopyasında AYNEN durmalı; eklenen tek kayıt canli-sayfa olmalı.
# (Denetim tur 1: dosyalar eski bir kopyadan taşınınca ana dala yeni girmiş bir becerinin kaydı silinmişti.)
# rc: 0 yalnız kendi kaydı eklendi · 1 başka kayıt silindi/değişti ya da fazladan kayıt var · 3 ölçülemedi
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 3
git fetch -q origin main 2>/dev/null || { echo "ÖLÇÜLEMEDİ · ana dal çekilemedi"; exit 3; }
echo "ana dal: $(git rev-parse --short origin/main)"
python3 - <<'PY'
import json, subprocess, sys
def ana(f): return json.loads(subprocess.run(["git", "show", "origin/main:" + f], capture_output=True, check=True).stdout)
def simdi(f): return json.load(open(f, encoding="utf-8"))
k = 0
A, S = {x["id"]: x for x in ana("catalog.json")["skills"]}, {x["id"]: x for x in simdi("catalog.json")["skills"]}
silinen = sorted(set(A) - set(S)); eklenen = sorted(set(S) - set(A)); degisen = sorted(i for i in A if i in S and A[i] != S[i])
print(f"beceri kaydı: ana dalda {len(A)} · şimdi {len(S)} · silinen {silinen} · değişen {degisen} · eklenen {eklenen}")
if silinen or degisen or eklenen != ["canli-sayfa"]: k = 1
A, S = ana("sync-targets.json"), simdi("sync-targets.json")
if A["targets"] != S["targets"]: print("✗ hedef dizinleri değişmiş"); k = 1
a, s = A["install"], S["install"]
silinen = sorted(set(a) - set(s)); eklenen = sorted(set(s) - set(a)); degisen = sorted(i for i in a if i in s and a[i] != s[i])
print(f"dağıtım hedefi: ana dalda {len(a)} · şimdi {len(s)} · silinen {silinen} · değişen {degisen} · eklenen {eklenen}")
if silinen or degisen or eklenen != ["canli-sayfa"]: k = 1
print("✓ yalnız canli-sayfa eklendi; öbür kayıtlar aynen duruyor" if k == 0 else "✗ ortak kayıtta bu işe ait olmayan değişiklik var")
sys.exit(k)
PY
