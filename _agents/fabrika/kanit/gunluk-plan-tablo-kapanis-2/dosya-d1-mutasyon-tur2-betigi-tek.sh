#!/usr/bin/env bash
# D1 karar kapısı mutasyonu: geçici kopyada (a) temiz, (b) cipa.sh tam eşleşme → alt dizge (eski zayıf kural), (c) tablo.py fullmatch → search.
W="$1"; K=$(mktemp -d "$(dirname "$0")/mut.XXXX"); cp -r "$W/gunluk-plan" "$W/gun-ortasi" "$K/" 2>/dev/null; [ -d "$W/terminal-onar" ] && cp -r "$W/terminal-onar" "$K/"
kos(){ bash "$K/gunluk-plan/scripts/cipa.test.sh" >"$K/out" 2>&1; echo "$1: rc=$? $(tail -1 "$K/out") · düşen: $(grep '✗' "$K/out" | sed 's/ — .*//; s/^ *✗ //' | cut -c1-40 | tr '\n' ';')"; }
kos "temiz"
cp "$K/gunluk-plan/scripts/cipa.sh" "$K/c.bak"; sed -i "s/grep -qixE '(yarına )?ertele(nsin|ndi|yelim|yin)?'/grep -qiE 'ertele'/" "$K/gunluk-plan/scripts/cipa.sh"
grep -q "grep -qiE 'ertele' " "$K/gunluk-plan/scripts/cipa.sh" || echo "UYARI: cipa mutasyonu uygulanamadı"
kos "mutasyon-cipa"; cp "$K/c.bak" "$K/gunluk-plan/scripts/cipa.sh"
sed -i "s/KARAR.fullmatch(m.group(1).strip())/KARAR.search(m.group(1))/" "$K/gunluk-plan/scripts/tablo.py"
grep -q "KARAR.search" "$K/gunluk-plan/scripts/tablo.py" || echo "UYARI: tablo mutasyonu uygulanamadı"
kos "mutasyon-tablo"
