#!/usr/bin/env bash
# dumen.test.sh — dumen.mjs sınavı + MUTANTLAR (kapı gevşerse sınav kırmızıya dönmeli). Chromium yoksa ÖLÇÜLEMEDİ (rc 3), yeşil değil.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CH="${DUMEN_CHROME:-$(ls -d /config/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)}"
[ -x "$CH" ] || { echo "ÖLÇÜLEMEDİ: headless Chromium yok (DUMEN_CHROME=<yol>)"; exit 3; }
export DUMEN_CHROME="$CH"
node "$HERE/dumen.test.mjs"; RC=$?
[ "$RC" -eq 0 ] || exit "$RC"
[ "${DUMEN_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; cp "$HERE/dumen.mjs" "$HERE/dumen.test.mjs" "$T/"
mut() { # mut <ad> <python-düzeltmesi> : kopyayı bozar, sınavı koşar, KIRMIZI beklenir
  cp "$HERE/dumen.mjs" "$T/dumen.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/dumen.mjs" "$2" "$3" || { echo "  ✗ $1: MUTASYON ÜRETİLEMEDİ"; MK=$((MK+1)); return; }
  if DUMEN_LIB="$T/dumen.mjs" node "$T/dumen.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1)); else echo "  ✓ $1: yakalandı ($(grep -c '  ✗' "$T/o.txt") kapı kırmızı)"; fi
}
MK=0
mut "fail-open (mod ajan değilse devam)" "if (mod !== 'ajan') {" "if (false) {"
mut "merkez cevapsız → devam" "throw new KapiHata('merkez-cevapsiz', String(e.message || e));" "return 'ajan';"
mut "durma noktası kapalı" "const neden = await this.durmaNoktasi(eylemAdi, hedef);" "const neden = null;"
mut "parola gizleme yok" "deger:gizli(t)?'<gizli>':String(t.value??t.checked)" "deger:String(t.value??t.checked)"
find "$T" -mindepth 1 -delete; rmdir "$T"
[ "$MK" -eq 0 ] && echo "MUTANT: 4/4 yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
