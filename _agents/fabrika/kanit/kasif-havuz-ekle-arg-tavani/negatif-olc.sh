#!/usr/bin/env bash
# negatif-olc.sh — yeni sınav, ESKİ (ana daldaki) aracı kırmızıya düşürüyor mu? Sınavın tavanı gerçekten ölçtüğünün kanıtı.
# Bütün beceri dizini kopyalanır (sınav kardeş betiklere muhtaç), yalnız araç eski hâliyle değiştirilir.
# rc: 0 eski araç yalnız T-ARG kapılarında kırmızı · 1 eski araç da yeşil · 3 ölçülemedi
set -uo pipefail
# Araç kardeş paketi `../layiha` yolundan ister → kopya depo kökünde, kardeşlerin yanında açılır (geçici ad, iş bitince silinir).
KOK="$(git rev-parse --show-toplevel)"; T="$KOK/.negatif-kasif-tara.$$"; trap 'find "$T" -delete 2>/dev/null' EXIT
cp -r "$KOK/kasif-tara" "$T" || exit 3
git -C "$KOK" show origin/main:kasif-tara/scripts/kasif-havuz-ekle.sh > "$T/scripts/kasif-havuz-ekle.sh" || exit 3
c="$(bash "$T/scripts/kasif-havuz-ekle.test.sh" 2>&1)"; rc=$?
printf '%s\n' "$c" | grep -E '^  ✗|SONUÇ'
k="$(printf '%s\n' "$c" | grep -c '^  ✗')"; t="$(printf '%s\n' "$c" | grep -c '^  ✗ 🔴 \(tavan üstü\|büyük\)')"
if [ "$rc" -ne 0 ] && [ "$t" -ge 1 ] && [ "$k" -eq "$t" ]; then echo "✓ eski araç yalnız tavan kapılarında kırmızı ($t) — sınav ayırt ediyor, başka kapı bozulmadı"; exit 0; fi
echo "✗ beklenmedik: rc=$rc kırmızı=$k tavan=$t"; exit 1
