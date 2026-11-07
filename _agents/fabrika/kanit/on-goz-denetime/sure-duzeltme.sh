#!/usr/bin/env bash
# sure-duzeltme.sh — denetci-duzeltme-farki.test.sh'i HEAD kopyasında koşar ve süresini yazar (göz tur 1 sonrası: CI'da 481 sn / tavan 531 idi).
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi/scripts | tar -x -C "$T" || exit 3
b=$SECONDS; o="$(cd "$T/yazilim-fabrikasi/scripts" && bash denetci-duzeltme-farki.test.sh < /dev/null 2>&1)"; rc=$?
echo "$(grep -E 'SONUÇ' <<<"$o" | tail -1)"; echo "süre: $((SECONDS-b)) sn · yük $(cut -d' ' -f1 /proc/loadavg) · yerel $(nproc) çekirdek · tavan 531 (CI)"; exit $rc
