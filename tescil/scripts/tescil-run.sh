#!/usr/bin/env bash
# tescil-run.sh — Katman-1 mekanik-oracle koşusu (tescil skill'i; DİVAN K5, k0054).
# GEREKLILIK.md'yi parse eder, her G'yi TAZE koşar (sert-teslim trust_boundary kompozisyonu,
# redaction yazım-öncesi), kanit/G<i>.json + MUHUR.md üretir. Pipe-maskeleme YOK; RC her zaman kayıtlı.
# Kör-protokol: girdi = GEREKLILIK.md + worktree. Motor-raporu/transkript OKUNMAZ.
# Yazma-yetkisi yalnız --out dizini (ürün-koduna Edit/Write yok — tester≠fixer).
#
# Kullanım:
#   tescil-run.sh <k####> --gereklilik <yol> --worktree <yol> --out <dizin>
#                 [--head-sha <sha>] [--deneme <n>] [--katman2 "G3=GECTI|KALDI|EMIN-DEGILIM[:not]"]... [--tatbikat]
# RC: 0=GECTI · 1=KALDI · 2=harness/kullanım · 3=KATMAN2-BEKLIYOR|ESKALASYON · 4=İSİMLİ-RED
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
SKILL_KOKU="$(cd "$LIB/../.." && pwd)"

kullanim() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

KART="${1:-}"; [ -n "$KART" ] || kullanim
case "$KART" in --*) kullanim ;; esac
shift

GEREKLILIK="" WORKTREE="" OUT="" HEAD_SHA="" DENEME=1 TATBIKAT=0
KATMAN2=()
while [ $# -gt 0 ]; do
  case "$1" in
    --gereklilik) GEREKLILIK="${2:-}"; shift 2 ;;
    --worktree)   WORKTREE="${2:-}"; shift 2 ;;
    --out)        OUT="${2:-}"; shift 2 ;;
    --head-sha)   HEAD_SHA="${2:-}"; shift 2 ;;
    --deneme)     DENEME="${2:-1}"; shift 2 ;;
    --katman2)    KATMAN2+=("${2:-}"); shift 2 ;;
    --tatbikat)   TATBIKAT=1; shift ;;
    *) echo "tescil-run: bilinmeyen argüman: $1" >&2; kullanim ;;
  esac
done
[ -n "$GEREKLILIK" ] && [ -n "$WORKTREE" ] && [ -n "$OUT" ] || kullanim

command -v python3 >/dev/null 2>&1 || { echo "tescil-run: python3 yok (harness)" >&2; exit 2; }
command -v node    >/dev/null 2>&1 || { echo "tescil-run: node yok (harness)" >&2; exit 2; }

SKILL_VERSION="$(awk -F': *' '/^version:/{print $2; exit}' "$SKILL_KOKU/SKILL.md" 2>/dev/null)"
: "${SKILL_VERSION:=0.0.0}"
mkdir -p "$OUT"

# ── İSİMLİ-RED: gereklilik-eksik (dosya yok) ─────────────────────────────────
if [ ! -f "$GEREKLILIK" ]; then
  python3 "$LIB/muhur.py" red --out "$OUT" --kart "$KART" --deneme "$DENEME" \
    --ad "gereklilik-eksik" --sebep "GEREKLILIK.md bulunamadı: $GEREKLILIK (sevk-anında SERDAR/MİMSERDAR yazmalı)"
  exit 4
fi
cp -f "$GEREKLILIK" "$OUT/GEREKLILIK.md"   # anlık-görüntü (kanıt-bütünlüğü)

# ── Parse + politika ─────────────────────────────────────────────────────────
if ! python3 "$LIB/gereklilik.py" parse "$GEREKLILIK" > "$OUT/gereklilik.json"; then
  echo "tescil-run: gereklilik-parse harness-hatası" >&2; exit 2
fi
RED_ADI="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["red"]["ad"] if d["red"] else "")' "$OUT/gereklilik.json")"
if [ -n "$RED_ADI" ]; then
  echo "tescil-run: İSİMLİ-RED → $RED_ADI"
  while IFS= read -r sebep; do SEBEPLER+=(--sebep "$sebep"); done \
    < <(python3 -c 'import json,sys; [print(s) for s in json.load(open(sys.argv[1]))["red"]["sebepler"]]' "$OUT/gereklilik.json")
  python3 "$LIB/muhur.py" red --out "$OUT" --kart "$KART" --deneme "$DENEME" \
    --ad "$RED_ADI" "${SEBEPLER[@]}" ${HEAD_SHA:+--head-sha "$HEAD_SHA"}
  exit 4
fi

# ── Worktree + HEAD-SHA doğrulaması ──────────────────────────────────────────
[ -d "$WORKTREE" ] || { echo "tescil-run: worktree dizini yok: $WORKTREE" >&2; exit 2; }
GERCEK_SHA="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null)" || {
  echo "tescil-run: worktree git-HEAD okunamadı: $WORKTREE" >&2; exit 2; }
if [ -n "$HEAD_SHA" ] && [ "$GERCEK_SHA" != "$HEAD_SHA" ]; then
  python3 "$LIB/muhur.py" red --out "$OUT" --kart "$KART" --deneme "$DENEME" \
    --ad "worktree-sha-uyusmazligi" --head-sha "$GERCEK_SHA" \
    --sebep "beklenen HEAD=$HEAD_SHA · worktree HEAD=$GERCEK_SHA (sevk edilen iş bu ağaçta değil)"
  exit 4
fi

# ── Katman-1: her mekanik G'yi TAZE koş (eski kanıt devralınmaz) ─────────────
echo "tescil-run: $KART deneme-$DENEME · worktree HEAD=$GERCEK_SHA"
rm -f "$OUT"/kanit/G*.json 2>/dev/null || true
while IFS= read -r g_b64; do
  [ -n "$g_b64" ] || continue
  node "$LIB/g-kosucu.mjs" --g-b64 "$g_b64" --out "$OUT" --worktree "$WORKTREE" \
    --kart "$KART" --deneme "$DENEME" --head-sha "$GERCEK_SHA" --skill-version "$SKILL_VERSION"
  g_rc=$?
  if [ "$g_rc" -ge 2 ]; then echo "tescil-run: G-koşucu harness-hatası (rc=$g_rc)" >&2; exit 2; fi
done < <(python3 -c '
import base64, json, sys
d = json.load(open(sys.argv[1]))
for g in d["g"]:
    if g["tur"] != "llm-yargi":
        print(base64.b64encode(json.dumps(g).encode()).decode())
' "$OUT/gereklilik.json")

# ── MUHUR.md + verdikt (RC = verdikt-haritası) ───────────────────────────────
K2_ARGS=()
for k in ${KATMAN2[@]+"${KATMAN2[@]}"}; do K2_ARGS+=(--katman2 "$k"); done
python3 "$LIB/muhur.py" uret --out "$OUT" --kart "$KART" --deneme "$DENEME" \
  --head-sha "$GERCEK_SHA" ${K2_ARGS[@]+"${K2_ARGS[@]}"} $([ "$TATBIKAT" -eq 1 ] && echo --tatbikat)
VERDIKT_RC=$?
echo "tescil-run: bitti — verdikt-RC=$VERDIKT_RC (0=GECTI 1=KALDI 3=K2/ESKALASYON 4=RED)"
exit "$VERDIKT_RC"
