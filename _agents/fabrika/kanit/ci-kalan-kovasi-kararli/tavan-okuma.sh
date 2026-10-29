#!/usr/bin/env bash
# tavan-okuma.sh <kabuk-sinamalari.sh> — ağır sınavların BEYAN ettiği süre tavanı ile koşucunun UYGULADIĞI tavan aynı mı?
# Çıkış 0 = dördü de aynı · 1 = en az biri farklı (beyan sessizce varsayılana düşüyor).
set -u; K="$1"; export KABUK_SURE_VARSAYILAN=300 KABUK_SURE_TAVAN=900; rc=0
eval "$(sed -n '/^sure_sec() {/,/^}/p' "$K")"
for t in ./tescil/scripts/sicil.test.sh ./yazilim-fabrikasi/scripts/agir-sira-sarma.test.sh ./oda-kur/scripts/oda.test.sh ./tescil/scripts/muhurdar.test.sh; do
  b="$(head -15 "$t" | grep -o 'kabuk-testleri: sure=[0-9]*' | head -1 | grep -o '[0-9]*$')"; [ -n "$b" ] || b=300
  u="$(sure_sec "$t" 2>/dev/null)"
  if [ "$b" = "$u" ]; then echo "✓ $t beyan=$b uygulanan=$u"; else echo "✗ $t beyan=$b uygulanan=$u (beyan sessizce düştü)"; rc=1; fi
done; exit $rc
