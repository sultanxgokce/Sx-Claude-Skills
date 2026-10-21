#!/usr/bin/env bash
# Göz tur 1 bulgusu (eşzamanlı dolum yarışı) ölçümü: $1 retro.py ile aynı dosyaya 5 tur × 8 eşzamanlı `doldur`.
# rc 0 = 40 dolumun hepsi geçti ve geçici dosya kalmadı · rc 1 = en az biri düştü (yarış). Kullanım: esz.sh <retro.py>
set -u
R="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
cd "$T" && mkdir -p bos/_agents/x && printf '# X\n' > bos/_agents/x/NOTES.md
export RETRO_BUGUN=2026-10-17
python3 "$R" kutu X --kok bos --koltuk x:0 >/dev/null || { echo "kutu düştü"; exit 2; }
cat > iyi.md <<'EOF'
## 1 · Ne bitti
- B1) tmux bekçisi Sx #388 kapıda
## 2 · Nerede zaman kaybettim (ölçüyle)
- Z1) sembolik bağ döngüsüne takılan tarama · ölçü: 5 dk
## 3 · Hangi araç/kural beni yavaşlattı
- A1) ana dal kapısı retro iskeletini düzenletmiyordu
## 4 · Ne öğrendim
- D1) kapıyı gevşetme, yazmayı araca ver
## 5 · Merkeze önerim
- Ö1) retro dolumu yalnız retro.py doldur ile yapılsın
EOF
dus=0
for tur in 1 2 3 4 5; do
  for n in 1 2 3 4 5 6 7 8; do python3 "$R" doldur X --kok bos --metin iyi.md > "o-$tur-$n" 2>&1 & done; wait
done
dus=$(grep -L '✓ dolduruldu' o-* | wc -l); kalan=$(find bos -name '*.yeni' | wc -l)
echo "40 eşzamanlı dolum: düşen=$dus · geride kalan geçici dosya=$kalan"
grep -h -m1 -E 'Error|rror:' o-* 2>/dev/null | head -2
[ "$dus" = 0 ] && [ "$kalan" = 0 ]
