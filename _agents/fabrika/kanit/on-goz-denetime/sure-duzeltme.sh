#!/usr/bin/env bash
# sure-duzeltme.sh — denetci-duzeltme-farki.test.sh süresi: ana dal (origin/main) ile HEAD art arda, becerinin TAMAMI kopyalanarak (şablon dahil).
#   Göz tur 1 sonrası CI: dişsiz sürüm 358 → 481 sn (tavan 531). 7 Kas 05:3x iki turlu aralıklı ölçüm (dişli): eski 294/294 · yeni 305/331 sn.
#   Not: önceki tek başına ölçümler (322/331 sn) yalnız scripts/ kopyasıyla alınmıştı — şablonsuz; bu kayıt onların yerine geçer.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
mkdir "$T/eski" "$T/yeni"
git -C "$R" archive origin/main yazilim-fabrikasi | tar -x -C "$T/eski" || exit 3
git -C "$R" archive HEAD yazilim-fabrikasi | tar -x -C "$T/yeni" || exit 3
rc=0
for k in eski yeni; do
  y=$(cut -d' ' -f1 /proc/loadavg); b=$SECONDS; o="$(cd "$T/$k/yazilim-fabrikasi/scripts" && bash denetci-duzeltme-farki.test.sh < /dev/null 2>&1)" || rc=1
  echo "$k ($([ $k = eski ] && git -C "$R" rev-parse --short origin/main || git -C "$R" rev-parse --short HEAD)): $((SECONDS-b)) sn · yük $y · $(grep SONUÇ <<<"$o" | tail -1)"
done
echo "yerel $(nproc) çekirdek · CI tavanı 531 sn"; exit $rc
