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

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
