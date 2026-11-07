#!/usr/bin/env bash
# parca.sh — denetci.test.sh'in GERÇEK koşusunu (mutantların ~1/60'ı ile) HEAD kopyasında koşar: DENETCI_PARCA=1/60.
#   Niçin: tam süit bu kutuda mutant bölümünde takılıyor (ana dal sürümüyle de; bulgu …2ST9AM); T-ONGOZ ve öteki bölümler gerçek koşuda.
#   7 Kas ölçümü aynı parça: ana dal 284/284 · 269 sn, dilim 3 284/284 · 282 sn.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi/scripts | tar -x -C "$T" || exit 3
b=$SECONDS; o="$(cd "$T/yazilim-fabrikasi/scripts" && DENETCI_PARCA=1/60 timeout 900 bash denetci.test.sh < /dev/null 2>&1)"; rc=$?
grep -E '^  ✗' <<<"$o" | head -10; grep -A14 "T-ONGOZ" <<<"$o" | grep -E "✓|✗"
echo "$(grep -E '^(── )?SONUÇ' <<<"$o" | tail -1) · $((SECONDS-b)) sn · rc=$rc"; exit $rc
