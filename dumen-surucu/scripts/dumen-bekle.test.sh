#!/usr/bin/env bash
# dumen-bekle.test.sh — dumen-bekle.mjs sınavı + MUTANTLAR (kapı gevşerse sınav kırmızıya dönmeli). Chromium gerekmez; yalnız node.
# kabuk-testleri: sure=120
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
node "$HERE/dumen-bekle.test.mjs"; RC=$?
[ "$RC" -eq 0 ] || exit "$RC"
[ "${BEKLE_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; cp "$HERE/dumen-bekle.mjs" "$HERE/dumen-bekle.test.mjs" "$T/"
MK=0; MS=0
mut() { # mut <ad> <çapa> <yerine>
  cp "$HERE/dumen-bekle.mjs" "$T/dumen-bekle.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/dumen-bekle.mjs" "$2" "$3" || { echo "  ✗ $1: çapa bayat"; MK=$((MK+1)); MS=$((MS+1)); return; }
  MS=$((MS+1))
  if BEKLE_LIB="$T/dumen-bekle.mjs" node "$T/dumen-bekle.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1)); else echo "  ✓ $1: yakalandı ($(grep -c '  ✗' "$T/o.txt") kapı kırmızı)"; fi
}
mut "Sultan'dayken de çıkar (bekleme yok)" "if (mod === 'ajan') { yaz(ilk" "if (true) { yaz(ilk"
mut "cevapsız = ajan varsayılır" "if (cevapsiz >= CEVAPSIZ_TAVAN) { yaz(" "if (cevapsiz >= 1) { yaz('▶ Dümen geri verildi — devam edebilirsin'); return 0; yaz("
mut "cevapsız tavanı yok (sonsuz bekler)" "if (cevapsiz >= CEVAPSIZ_TAVAN) {" "if (false) {"
mut "azami süre yok" "if (simdi() - bas >= azamiMs) {" "if (false) {"
mut "süre dolunca devam der" "yaz(\`⏳ \${Math.round(azamiMs / 60000)} dk doldu, Dümen hâlâ Sultan'da — SERDAR'a haber ver ya da yeniden bekle\`); return 3;" "yaz('▶ devam edebilirsin'); return 0;"
mut "kesinti sayacı sıfırlanmaz" "      cevapsiz = 0;
" "
"
mut "jeton başlığı gönderir" "okuyucu(\`\${uc}/dumen/mod\`, { signal" "okuyucu(\`\${uc}/dumen/mod\`, { headers: { 'x-defter-jeton': 'x' }, signal"
mut "merkezsiz sessiz geçer" "if (!uc) { yaz('✗ merkez adresi yok (--merkez ya da DUMEN_MERKEZ)'); return 2; }" ""
find "$T" -mindepth 1 -delete; rmdir "$T"
[ "$MK" -eq 0 ] && echo "MUTANT: $MS/$MS yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
