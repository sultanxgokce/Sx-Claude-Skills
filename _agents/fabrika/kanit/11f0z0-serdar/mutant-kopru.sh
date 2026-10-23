#!/usr/bin/env bash
# mutant-kopru.sh — kart 11f0z0-serdar MUTASYON: retro.py kopyasında köprü çağrısı (`bash bulgu.sh havuz-cek`) silinir,
# olc-havuz.sh merkez ölçümü o kopyayla koşar. Beklenen: havuz_satiri=2 ÇIKMAZ → rc 1 (sınav bozuk kodu YAKALADI).
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; R="$B/../../../../retro/scripts/retro.py"
MR="$(mktemp --suffix=.py)"; trap 'rm -f -- "$MR"' EXIT
sed -e 's/\["bash", bsh, "havuz-cek"\]/["true"]/' "$R" > "$MR"
cmp -s "$MR" "$R" && { echo "mutant üretilemedi: sed hiçbir şeyi değiştirmedi"; exit 3; }
out="$(RETRO_PY="$MR" bash "$B/olc-havuz.sh" merkez)"; echo "mutant koşusu: $out"
case "$out" in *havuz_satiri=2*) echo "mutant KAÇTI: köprüsüz kodda da 2 havuz satırı"; exit 0 ;; *) echo "mutant ISIRILDI: köprü çağrısı silinince havuz satırı 2 değil"; exit 1 ;; esac
