#!/usr/bin/env bash
# frontend-boost araç sınavı — AĞSIZ. Taşınabilirlik ve "ölçemediğine temiz deme" kapıları.
# Niçin: araç AKAR kutusunda doğdu, tarayıcı yolu oraya SABİT yazılmıştı; başka kutuda
# "Cannot find module" ile ölüyordu. Ayrıca seçiciler tutmayınca "0 metin" basıp temiz görünüyordu.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT

rc(){ "$@" >/dev/null 2>&1; printf '%s' $?; }
cikti(){ "$@" 2>&1; }

# T1-T2 kontrast aracı: kullanım ve çalışma-zamanı yokluğu
kapi "T1 adres verilmezse kullanım hatası (rc=2)" "2" "$(rc node "$KOK/kontrast-olc.mjs")"
kapi "T2 tarayıcı yoksa rc=3 ÖLÇÜLEMEDİ (rc=0 DEĞİL)" "3" \
  "$(FRONTEND_BOOST_PW=/yok/x.js FRONTEND_BOOST_PW_LIBS=/yok rc node "$KOK/kontrast-olc.mjs" 'file:///yok.html')"
kapi "T2b ileti 'temiz DEĞİL' der ve çözümü gösterir" "1" \
  "$(FRONTEND_BOOST_PW=/yok/x.js cikti node "$KOK/kontrast-olc.mjs" 'file:///yok.html' | grep -c 'ÖLÇÜLEMEDİ.*ÖLÇÜLMEDİ, "temiz" DEĞİL')"

# T3 🔴 taşınabilirlik: kutuya sabitlenmiş yol KALMAMALI (env'siz sabit import yasak)
kapi "T3 env ezmesi kodda var (FRONTEND_BOOST_PW ≥1 kez)" "evet" \
  "$([ "$(grep -c FRONTEND_BOOST_PW "$KOK/kontrast-olc.mjs")" -ge 1 ] && echo evet || echo hayir)"
kapi "T3b sabit yol artık doğrudan import edilmiyor" "0" \
  "$(grep -c "await import('/config" "$KOK/kontrast-olc.mjs")"

# T4 sıfır-metin kapısı kodda var mı (tarayıcısız doğrulanabilen tek biçim)
kapi "T4 sıfır metin → rc=3 kapısı kodda" "1" "$(grep -c 'toplamMetin === 0' "$KOK/kontrast-olc.mjs")"
kapi "T4b eşik aşımı rc=1 olarak ayrılmış" "1" "$(grep -c 'ihlal > 0 ? 1 : 0' "$KOK/kontrast-olc.mjs")"

# T5-T6 yazı tipi aracı: kullanım ≠ kaynak hatası
kapi "T5 argümansız → rc=2 (yığın izi DEĞİL)" "2" "$(rc python3 "$KOK/font-altkume.py")"
kapi "T5b argümansız çıktıda yığın izi yok" "0" "$(cikti python3 "$KOK/font-altkume.py" | grep -c Traceback)"
kapi "T6 sözdizimi temiz (py)" "0" "$(rc python3 -c "import ast;ast.parse(open('$KOK/font-altkume.py').read())")"
kapi "T6b sözdizimi temiz (mjs)" "0" "$(rc node --check "$KOK/kontrast-olc.mjs")"

# T7-T9 🔴 ÖZEL SEÇİCİ GİZLENMİYORDU (MUAVİN, 2026-09-19): gizleme stili sabit seçicilerle
# yazılıydı; FRONTEND_BOOST_SECICILER ile verilen metin saydam yapılmıyor, zemin yerine yazının
# KENDİ pikseli okunuyor, oran 1,00 çıkıyordu (eşik ihlali gibi görünen sahte ölçüm).
kapi "T7 gizleme listesi SECICILER'i de kapsar (kodda)" "1" "$(grep -c '^const GIZLE = .*SECICILER' "$KOK/kontrast-olc.mjs")"
kapi "T7b oran 1,00 → ölçülemedi kapısı kodda" "1" "$(grep -c 'olculemeyen.length > 0' "$KOK/kontrast-olc.mjs")"

# Tarayıcılı kapılar: bu kutuda tarayıcı yoksa KOŞMAZ ve "geçti" SAYILMAZ — ölçülemedi diye ayrı sayılır.
U=0
olcul(){ U=$((U+1)); printf '  ⊘ %s — ÖLÇÜLEMEDİ (tarayıcı yok/başlamadı; FRONTEND_BOOST_PW ver)\n' "$1"; }
cat > "$TMP/ozel.html" <<'H'
<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#fff}.sahne{background:#120e0a;height:600px;padding:40px}p{margin:0;font:700 48px sans-serif}.ozel{color:#f4ede2}.ayni{color:#120e0a}</style>
<div class="sahne"><p class="ozel">Özel seçicili metin</p></div>
H
cat > "$TMP/ayni.html" <<'H'
<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#fff}.sahne{background:#120e0a;height:600px;padding:40px}p{margin:0;font:700 48px sans-serif}.ayni{color:#120e0a}</style>
<div class="sahne"><p class="ayni">Zeminle aynı renkte metin</p></div>
H
calistir(){ FRONTEND_BOOST_SECICILER="$1" node "$KOK/kontrast-olc.mjs" "file://$2" >"$TMP/cikti" 2>&1; printf '%s' $?; }
tarayicisiz(){ [ "$1" = 3 ] && grep -qE 'çalışma-zamanı|başlatılamadı' "$TMP/cikti"; }
r="$(calistir .ozel "$TMP/ozel.html")"
if tarayicisiz "$r"; then olcul "T8 yalnız SECICILER ile verilen metin zeminden ölçülür (rc=0)"
else kapi "T8 yalnız SECICILER ile verilen metin zeminden ölçülür (rc=0; eskiden 1,00 → rc=1)" "0" "$r"
     kapi "T8b ölçülen oran 1,00 DEĞİL" "0" "$(grep -c '=1 (en açık' "$TMP/cikti")"; fi
r="$(calistir .ayni "$TMP/ayni.html")"
if tarayicisiz "$r"; then olcul "T9 oranı 1,00 çıkan kutu ölçülemedi sayılır (rc=3)"
else kapi "T9 oranı 1,00 çıkan kutu ölçülemedi sayılır (rc=3, rc=1 DEĞİL)" "3" "$r"
     kapi "T9b stderr nedeni söyler" "1" "$(grep -c 'ÖLÇÜLEMEDİ: .* kutuda oran 1,00' "$TMP/cikti")"; fi

printf '\ngeçti=%s · kaldı=%s · ölçülemedi=%s\n' "$G" "$K" "$U"
[ "$K" -eq 0 ] || exit 1
if [ "$U" -gt 0 ]; then
  echo "⚠️  $U tarayıcılı kapı KOŞMADI — bu kutuda kontrast düzeltmesi ÖLÇÜLMEDİ, yalnız kaynak kapıları geçti."
  [ "${FRONTEND_BOOST_TEST_KATI:-0}" = 1 ] && exit 3
fi
exit 0
