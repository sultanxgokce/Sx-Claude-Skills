#!/usr/bin/env bash
# Mutasyon: geçici kopyada iki here-string düzeltmesi TEK TEK eski boruya döndürülür; T5b / T5c kırmızıya dönmeli.
W="$1"; K=$(mktemp -d "$(dirname "$0")/sgm.XXXX"); cp -r "$W/gun-ortasi" "$W/gunluk-plan" "$K/"
B="$K/gun-ortasi/scripts/kalan.sh"; cp "$B" "$K/temiz"
kos(){ bash "$K/gun-ortasi/scripts/kalan.test.sh" > "$K/out" 2>&1; echo "$1: $(grep SONUÇ "$K/out") · düşen: $(grep -oE '🔴 T[0-9a-z]+' "$K/out" | tr '\n' ' ')"; }
kos temiz
sed -i 's/    grep -qxF -- "\$a" <<<"\$okunan" \&\& continue/    printf "%s\\n" "$okunan" | grep -qxF -- "$a" \&\& continue/' "$B"; cmp -s "$B" "$K/temiz" && echo "M1 UYGULANAMADI" || kos "M1 gelen kutusu boruya döndü"
cp "$K/temiz" "$B"; sed -i 's/  elif ! grep -q "GÜNÜN PLANI ÇIPASI · \$BUGUN" <<<"\$c"; then/  elif ! printf "%s\\n" "$c" | grep -q "GÜNÜN PLANI ÇIPASI · $BUGUN"; then/' "$B"; cmp -s "$B" "$K/temiz" && echo "M2 UYGULANAMADI" || kos "M2 çıpa kapısı boruya döndü"
