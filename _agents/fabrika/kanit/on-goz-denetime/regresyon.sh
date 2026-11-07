#!/usr/bin/env bash
# regresyon.sh — değişen üç betiğe (denetci.sh · kart.sh · karne.sh) dokunan var olan sınavlar, HEAD kopyasında. Biri düşerse rc 1.
#   denetci.test.sh ve denetci-duzeltme-farki.test.sh burada YOK: bu kutuda ana dal sürümü de denetci.test.sh'te O14 sonrasında takılıyor
#   (7 Kas 03:2x ölçümü, 1200 sn) — süreleri CI kovalarından okunur (PR gövdesi).
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi/scripts | tar -x -C "$T" || exit 3
cd "$T/yazilim-fabrikasi/scripts" || exit 3
d=0
for t in denetci-karne denetci-ongoz-tam-fark denetci-tavan denetci-kutu-disi denetci-kayit-commit denetci-klon-kart denetci-daralt-tam-fark denetci-manifest-istem karne kart on-goz golge; do
  b=$SECONDS; o="$(timeout 600 bash "$t.test.sh" < /dev/null 2>&1)"; rc=$?
  s="$(grep -E 'SONUÇ|TOPLAM' <<<"$o" | tail -1)"
  [ "$rc" -eq 0 ] && echo "  ✓ $t.test.sh $((SECONDS-b)) sn · $s" || { d=$((d+1)); echo "  ✗ $t.test.sh rc=$rc · $s"; }
done
echo "── regresyon: $d düştü"; [ "$d" -eq 0 ]
