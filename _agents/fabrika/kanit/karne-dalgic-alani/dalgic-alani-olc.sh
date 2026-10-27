#!/usr/bin/env bash
# dalgic-alani-olc.sh <betik-dizini> — karne.test.sh'ın T6 (dalgic alanı) iki kontrolünden kaçı geçiyor
D="${1:?betik dizini}"; M="$(mktemp -d)"; cp "$D"/*.sh "$M/"; cp "$(dirname "$0")/../../../../yazilim-fabrikasi/scripts/karne.test.sh" "$M/karne.test.sh"
C="$(bash "$M/karne.test.sh" 2>&1)"
g=$(grep -c "^  ✓ .*\(dalgic\)" <<<"$C"); t=2
echo "dalgic-alani=$g/$t"; find "$M" -delete; [ "$g" -eq "$t" ]
