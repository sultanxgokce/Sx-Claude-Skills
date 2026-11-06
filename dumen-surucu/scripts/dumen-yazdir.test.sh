#!/usr/bin/env bash
# dumen-yazdir.test.sh — 0.10.0 yazdirYakala sınavı + MUTANTLAR (kapı gevşerse sınav kırmızıya dönmeli). Chromium yoksa ÖLÇÜLEMEDİ (rc 3), yeşil değil.
# kabuk-testleri: sure=300
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CH="${DUMEN_CHROME:-$(ls -d /config/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)}"
[ -x "$CH" ] || { echo "ÖLÇÜLEMEDİ: headless Chromium yok (DUMEN_CHROME=<yol>)"; exit 3; }
export DUMEN_CHROME="$CH"
# MUTANT_HAM=<n>: yalnız n. mutantı kur ve sınavın HAM çıktısını ve çıkış kodunu ver (kanıt kaydı için: kırmızı = yakalandı). Kurulamazsa rc 9.
if [ -z "${MUTANT_HAM:-}" ]; then
  node "$HERE/dumen-yazdir.test.mjs"; RC=$?
  [ "$RC" -eq 0 ] || exit "$RC"
  [ "${DUMEN_MUTANT:-1}" = 0 ] && exit 0
fi
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; trap 'python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"' EXIT; cp "$HERE/dumen.mjs" "$HERE/dumen-yazdir.test.mjs" "$HERE/sinav-cocuk.mjs" "$T/"
MK=0; MS=0
mut() { # mut <ad> <çapa> <yerine> : kopyayı bozar, sınavı koşar, KIRMIZI beklenir. Yalnız TEK=<n> verilirse o mutant koşar.
  MS=$((MS+1)); [ -n "${TEK:-}" ] && [ "$TEK" != "$MS" ] && return 0
  [ -n "${MUTANT_HAM:-}" ] && [ "$MUTANT_HAM" != "$MS" ] && return 0
  cp "$HERE/dumen.mjs" "$T/dumen.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/dumen.mjs" "$2" "$3" || { echo "  ✗ $MS $1: MUTASYON ÜRETİLEMEDİ (çapa kaydı)"; MK=$((MK+1)); [ -n "${MUTANT_HAM:-}" ] && exit 9; return; }
  node --check "$T/dumen.mjs" 2>/dev/null || { echo "  ✗ $MS $1: mutant SÖZDİZİMİ bozuk (yakalandı sayılmaz)"; MK=$((MK+1)); return; }
  if [ -n "${MUTANT_HAM:-}" ]; then echo "MUTANT $MS: $1"; DUMEN_ILK_KIRMIZI=1 DUMEN_LIB="$T/dumen.mjs" timeout 100 node "$T/dumen-yazdir.test.mjs"; R=$?; find "$T" -mindepth 1 -delete; rmdir "$T"; exit "$R"; fi
  if DUMEN_ILK_KIRMIZI=1 DUMEN_LIB="$T/dumen.mjs" timeout 100 node "$T/dumen-yazdir.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $MS $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1))
  elif grep -q 'SINAV ÇÖKTÜ' "$T/o.txt"; then echo "  ✗ $MS $1: sınav ÇÖKTÜ (yakalandı sayılmaz) — $(grep -m1 'ÇÖKTÜ' "$T/o.txt" | cut -c1-160)"; MK=$((MK+1))
  elif ! grep -q '  ✗' "$T/o.txt"; then echo "  ✗ $MS $1: sınav kırmızı ama DÜŞEN KAPI yok (yakalandı sayılmaz) — $(tail -2 "$T/o.txt" | tr '\n' ' ' | cut -c1-160)"; MK=$((MK+1))
  else echo "  ✓ $MS $1: yakalandı — $(grep -m1 '  ✗' "$T/o.txt" | cut -c1-110)"; fi
}
mut "window.print yamalanmaz (yazdırma sayılmaz)" "window.print=function(){window.__dumenYazdirSay=(window.__dumenYazdirSay||0)+1};" ""
mut "yama bitince geri konmaz" "if(window.__dumenPrint0){window.print=window.__dumenPrint0;delete window.__dumenPrint0}" ""
mut "yazdırma çağrılmasa da PDF yazılmaya çalışılır" "if (!cerceve) throw new KapiHata('yazdirma-yok'" "if (false) throw new KapiHata('yazdirma-yok'"
mut "alt belge yerine hep ana sayfa basılır" "if (cerceve !== page.mainFrame()) {" "if (false) {"
mut "alt belgeyi basınca ana sayfaya konan gizleme işaretleri silinmez" "await this.#page.evaluate(() => { document.getElementById('__dumenYz')?.remove(); for (const x of" "await this.#page.evaluate(() => { for (const x of"
mut "var olan dosya sormadan ezilir" "if (!ustuneYaz) throw new KapiHata('dosya-var'" "if (false) throw new KapiHata('dosya-var'"
mut "hedef izinli dizinde aranmaz" "if (!this.#icinde(g)) throw new KapiHata('dosya-izinsiz', 'hedef izinli dizinin dışında');" ""
mut "hedefin türü ölçülmez (.pdf dışı yazılır)" "const u = extname(g).toLowerCase(); if (!this.#turKumesi(turler).has(u)) throw new KapiHata('dosya-turu', \`izinli tür değil: \${u || '(uzantısız)'}\`);
    if (existsSync(g)) { if (lstatSync(g).isSymbolicLink()) throw new KapiHata('dosya-izinsiz', 'hedef bir bağ');" "if (existsSync(g)) { if (lstatSync(g).isSymbolicLink()) throw new KapiHata('dosya-izinsiz', 'hedef bir bağ');"
find "$T" -mindepth 1 -delete; rmdir "$T"
[ "$MK" -eq 0 ] && echo "MUTANT: $MS/$MS yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
