#!/usr/bin/env bash
# Göz aracının öteki sınavları (denetci*.test.sh; denetci-kutu-disi ayrıca ölçülür ve asıl sınav denetci.test.sh onu da çağırır) — sırayla, her birinin son satırı basılır.
# Çıkış: hepsi rc 0 ise 0, biri bile düşerse 1.
set -u
cd "$(git rev-parse --show-toplevel)/yazilim-fabrikasi/scripts" || exit 2
dusen=0
for f in denetci*.test.sh; do
  [ "$f" = denetci-kutu-disi.test.sh ] && continue
  cikti=$(timeout 900 bash "$f" 2>&1); rc=$?
  echo "$f rc=$rc kirmizi=$(printf '%s\n' "$cikti" | grep -c '✗') · $(printf '%s\n' "$cikti" | tail -1 | cut -c1-120)"
  if [ "$rc" -ne 0 ]; then dusen=$((dusen+1)); printf '%s\n' "$cikti" | grep '✗' | head -5; fi
done
echo "DÜŞEN SINAV: $dusen"
[ "$dusen" -eq 0 ]
