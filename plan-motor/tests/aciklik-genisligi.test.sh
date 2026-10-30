#!/usr/bin/env bash
# aciklik-genisligi.test.sh — AÇIKLIK GENİŞLİĞİ beyandan gelir, kırpma SESSİZ OLAMAZ.
#
# 🔴 NEDEN VAR (ölçüldü 2026-09-23, gerçek market planı): kapı genişliği köprüde duvar
# parçasının boyundan türetiliyordu (min(mühür_boyu, duvar-2)). Bölme beyanı duvarları
# parçalayınca 90 cm'lik kapı 68 cm'lik parçaya düştü ve modele 66 cm diye SESSİZCE yazıldı.
# Artık: çizimdeki kapı ölçü yazısı mühürle taşınır, açıklık genişliği ondan gelir; duvar
# kısa kalırsa kırpma yapılır ama RAPORLANIR (genislik_beyan alanı + uyarı satırı).
# DEĞİŞMEZ: fixture sentetik; müşteri dosyası kullanılmaz.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }
bek_metin() { local m="$1" ad="$2" d="$3"; grep -qF -- "$m" "$d" && ok || kir "$ad — '$m' yok"; }

cat <<JSON > "$T/g.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]], [[0,500],[1000,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250}, {"ad":"MUTFAK","m2":null,"x":500,"y":750} ],
  "otomatik_muhur": false,
  "ek_muhur": [ {"a":[420,500],"b":[510,500],"genislik":90,"gerekce":"kapi olcu yazisi 90/210"} ] }
JSON
python3 lib/lifting.py "$T/g.json" "$T/graf.json" >/dev/null 2>&1
bek_metin '"genislik": 90' "beyan edilen genişlik GRAFA taşınır" "$T/graf.json"
node cli.mjs model --graf "$T/graf.json" --cikti "$T/m.json" --metrik /dev/null >"$T/o" 2>"$T/e"
bek_metin '"genislik_beyan": 90' "açıklık genişliği BEYANDAN gelir" "$T/m.json"
# Kırpma: aynı kapıyı çok kısa bir duvar parçasına düşür → kırpılmalı ve RAPORLANMALI
sed 's/\[\[0,500\],\[1000,500\]\]/[[0,500],[430,500]], [[500,500],[1000,500]]/' "$T/g.json" > "$T/g2.json"
python3 lib/lifting.py "$T/g2.json" "$T/graf2.json" >/dev/null 2>&1
node cli.mjs model --graf "$T/graf2.json" --cikti "$T/m2.json" --metrik /dev/null >"$T/o2" 2>"$T/e2"
if grep -qF "BEYAN EDİLEN genişlikten dar kırpıldı" "$T/e2"; then ok; else
  grep -qF '"genislik_beyan": 90' "$T/m2.json" && ok || kir "kırpma ya da beyan izi yok: $(tail -2 "$T/e2" | tr '\n' ' ')"
fi
printf 'aciklik-genisligi: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
