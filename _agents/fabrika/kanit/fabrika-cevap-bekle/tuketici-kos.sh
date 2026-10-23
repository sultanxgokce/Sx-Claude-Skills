#!/usr/bin/env bash
# tuketici-kos.sh — kart.sh'ı çağıran bütün sınavlar + fabrikanın bütün sınavları, CI koşucusunun kuralıyla (timeout 300, sure= başlığı)
set -uo pipefail
cd "${1:?depo kökü}"
mapfile -t T < <( { ls yazilim-fabrikasi/scripts/*.test.sh; echo bileyi/scripts/bileyi.test.sh; echo retro/scripts/retro.test.sh; } | sort -u)
dusen=0
for t in "${T[@]}"; do
  n="$(head -15 "$t" | sed -n 's/^# *kabuk-testleri: *sure=\([0-9]\{1,5\}\) *$/\1/p' | head -1)"; sure="${n:-300}"; [ "$sure" -gt 900 ] && sure=900
  if timeout "$sure" bash "$t" >/tmp/tuketici-$$.log 2>&1; then echo "✓ $t"; else echo "✗ $t (rc $?)"; tail -5 /tmp/tuketici-$$.log; dusen=$((dusen+1)); fi
done
rm -f /tmp/tuketici-$$.log
echo "SONUÇ: ${#T[@]} sınav · düşen $dusen"
[ "$dusen" -eq 0 ]
