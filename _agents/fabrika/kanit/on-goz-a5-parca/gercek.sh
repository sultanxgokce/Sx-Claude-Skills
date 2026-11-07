#!/usr/bin/env bash
# gercek.sh — A5'in kapsam-dışı yol çıkarımını GERÇEK kart cümleleri üzerinde eski (origin/main) ve yeni (HEAD) on-goz.py ile karşılaştırır.
#   Kaynak: Nexus ve Sx birincil depolarının _agents/fabrika/kartlar/*.json'u (salt okuma). Fark eden her kart cümlesiyle basılır.
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$K" show origin/main:yazilim-fabrikasi/scripts/on-goz.py > "$T/eski.py"
python3 - "$T/eski.py" "$K/yazilim-fabrikasi/scripts/on-goz.py" /config/projects/Nexus /config/projects/Sx-Claude-Skills <<'PY'
import importlib.util, json, glob, os, re, sys
def yukle(p, ad):
    s = importlib.util.spec_from_file_location(ad, p); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
eski, yeni = yukle(sys.argv[1], "eski"), yukle(sys.argv[2], "yeni")
def eski_yasak(c):
    y = set()
    for parca in re.split(r"[;·()\[\]]|, ", c):
        if eski.KAPSAM_SOZ.search(parca): y.update(m.group(0).strip(".-") for m in eski.YOL_DESEN.finditer(parca))
    y.discard(""); return y
n = sozlu = fark = dar = 0
for depo in sys.argv[3:]:
    for p in sorted(glob.glob(os.path.join(depo, "_agents/fabrika/kartlar/*.json"))):
        try: c = json.load(open(p, encoding="utf-8")).get("cumle") or ""
        except Exception: continue
        n += 1
        if not eski.KAPSAM_SOZ.search(c): continue
        sozlu += 1; e, y = eski_yasak(c), yeni.kapsam_disi_yollar(c)
        if not e <= y: dar += 1; print(f"DARALDI {os.path.basename(p)}: kaybolan {sorted(e - y)}")
        if e != y: fark += 1; print(f"FARK {os.path.basename(depo)}/{os.path.basename(p)}: eklenen {sorted(y - e)}\n     cümle: {c[:300]}")
print(f"kart: {n} · kapsam sözcüklü: {sozlu} · yasak kümesi değişen: {fark} · eski yasağı kaybeden: {dar}")
sys.exit(1 if dar else 0)
PY
