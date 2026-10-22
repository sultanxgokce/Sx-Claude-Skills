#!/usr/bin/env bash
# dalga-olcer.sh <tescil/scripts dizini> [K=3] — GERÇEK yargıçla diploma sınavını K kez koşar (kart muhurdar-diploma-kume-gucu:
#   "gerçek yargıçla çoklu koşu dalgalanma ölçümü"). Her koşu geçici defter + geçici sicil kullanır — gerçek diploma defterine
#   ve sicile YAZMAZ. Çıktı: örnek × koşu isabet tablosu + koşular arasında hükmü değişen örnek sayısı (dalgalanma).
#   Bu bir ÖLÇÜMDÜR, kapı değil: çıkış 0 = K koşunun hepsi sonuç üretti (dalgalanma sayısı tabloda) · 3 = bir koşu sonuçsuz.
set -uo pipefail
S="$(cd "$1" && pwd)"; K="${2:-3}"; KUME="$(cd "$S/../sinav" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/defter" "$T/sicil"; printf 'persona: DALGA-OLCUM\npersonel_no: 99.001\n' > "$T/sicil/99.001.yaml"
for i in $(seq 1 "$K"); do
  t0=$(date +%s)
  DIPLOMA_DEFTERI="$T/defter/d.jsonl" SICIL_DIZIN="$T/sicil" bash "$S/diploma.sh" sina DALGA-OLCUM --kanit "$T/kanit-$i" --kume "$KUME" \
    < /dev/null > "$T/kosu-$i.log" 2>&1; rc=$?
  echo "koşu $i: rc $rc · $(( $(date +%s) - t0 )) sn · $(grep -m1 -E '^(✓|✗|·|⚠).*(GEÇTİ|KALDI|ÖLÇÜLEMEDİ)' "$T/kosu-$i.log" || tail -1 "$T/kosu-$i.log")"
done
# ıskalanan örneklerin mühür kâğıdı (yargıç + öznel notlar: EMIN-DEGILIM'in sebebi) kalıcı kanıta — geçici kökle birlikte silinmesin
IZ="$(dirname "$(readlink -f "$0")")/dalga-iz${MUHURDAR_MODEL:+-$MUHURDAR_MODEL}"; mkdir -p "$IZ"
python3 - "$T" "$K" "$IZ" <<'PYIZ'
import json, os, shutil, sys
T, K, IZ = sys.argv[1], int(sys.argv[2]), sys.argv[3]
for i in range(1, K + 1):
    try: o = json.load(open(os.path.join(T, f"kanit-{i}", "sonuc.json")))["ornekler"]
    except Exception: continue
    for ad, v in o.items():
        if v.get("isabet"): continue
        for son in ("MUHUR.md", "yeniden.MUHUR.md"):
            k = os.path.join(T, f"kanit-{i}", f"{ad}.{son}")
            if os.path.isfile(k): shutil.copy(k, os.path.join(IZ, f"k{i}-{ad}.{son}"))
        print(f"iz: koşu {i} · {ad} ıska → {IZ}/k{i}-{ad}.*")
PYIZ
python3 - "$T" "$K" <<'PY'
import json, os, sys
T, K = sys.argv[1], int(sys.argv[2])
kosular = []
for i in range(1, K + 1):
    p = os.path.join(T, f"kanit-{i}", "sonuc.json")
    try: kosular.append(json.load(open(p))["ornekler"])
    except Exception: print(f"ÖLÇÜLEMEDİ: koşu {i} sonuç üretmedi ({p})"); sys.exit(3)
adlar = sorted(set().union(*kosular))
print(f"\n{'örnek':42} " + " ".join(f"k{i}" for i in range(1, K + 1)) + "  yargıç")
dalga = 0
for a in adlar:
    h = []
    for k in kosular:
        v = k.get(a) or {}
        h.append("✓" if v.get("isabet") else ("↻" if "yeniden" in v else "✗"))
    ayni = len({(k.get(a) or {}).get("isabet") for k in kosular}) == 1
    dalga += not ayni
    yg = sorted({(k.get(a) or {}).get("yargic") or "-" for k in kosular})
    print(f"{a:42} " + "  ".join(h) + f"   {','.join(yg)}{'' if ayni else '   ← DALGALANDI'}")
toplam = [sum(1 for v in k.values() if v.get("isabet")) for k in kosular]
print(f"\nDALGALANMA: {dalga}/{len(adlar)} örnekte koşular arası isabet değişti · koşu başına isabet: {toplam} / {len(adlar)}")
PY
