#!/bin/bash
# Kural 10 (beklerken iş al) standarda ve her temele iner; bir temel düşerse sınav kırmızı olur.
set -u
kok="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
hata=0
s="$kok/cekirdek/durma-standardi.md"
for k in 'Beklerken sıradan iş al' 'Küçük:' 'Ayrı:' 'Geri dönüş önce:' 'Bağlam ve kota:'; do
  grep -qF "$k" "$s" || { echo "KIRMIZI standart: $k yok"; hata=1; }
done
for t in manuel-claude-base otonom-ajan-base mudur-base; do
  grep -qF 'kural 10' "$kok/cekirdek/$t.md" || { echo "KIRMIZI temel: $t"; hata=1; }
done
grep -qF '## BEKLERKEN' "$kok/cekirdek/izole-kutu-base.md" || { echo "KIRMIZI temel: izole-kutu-base"; hata=1; }
[ "$hata" -eq 0 ] && echo "YESIL: standart + 4 temel"
exit "$hata"
