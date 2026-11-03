#!/usr/bin/env bash
# mesaj.test.sh — pazaryeri-mesaj sınavı + MUTANTLAR (onay/karar/giriş/KVKK kapıları gevşerse sınav KIRMIZIYA dönmeli). Chromium yoksa ÖLÇÜLEMEDİ (rc 3).
# kabuk-testleri: sure=600
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CH="${DUMEN_CHROME:-$(ls -d /config/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)}"
[ -x "$CH" ] || { echo "ÖLÇÜLEMEDİ: headless Chromium yok (DUMEN_CHROME=<yol>)"; exit 3; }
export DUMEN_CHROME="$CH"
node "$HERE/mesaj.test.mjs"; RC=$?
[ "$RC" -eq 0 ] || exit "$RC"
[ "${PAZARYERI_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; cp "$HERE/pazar.mjs" "$HERE/mesaj.mjs" "$HERE/mesaj.test.mjs" "$T/"
mut() { # mut <ad> <dosya> <çapa> <bozuk> : kopyayı bozar, sınavı koşar, KIRMIZI beklenir
  cp "$HERE/pazar.mjs" "$T/pazar.mjs"; cp "$HERE/mesaj.mjs" "$T/mesaj.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/$2" "$3" "$4" || { echo "  ✗ $1: çapa bulunamadı"; MK=$((MK+1)); return; }
  if PAZARYERI_MUTANT=0 MESAJ_LIB="$T/mesaj.mjs" PAZAR_LIB="$T/pazar.mjs" DUMEN_LIB="${DUMEN_LIB:-$HERE/../../dumen-surucu/scripts/dumen.mjs}" node "$T/mesaj.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1)); else echo "  ✓ $1: yakalandı ($(grep -c '  ✗' "$T/o.txt") kapı düştü)"; fi
}
MK=0
mut "onaysız gönderme serbest" mesaj.mjs "const dmg = damgaDogrula(onay, sohbet);" "const dmg = { tarih: '', kaynak: '', ref: '', beyan: '' };"
mut "başka sohbetin damgası geçer" pazar.mjs "if (!sohbet || !metin.includes(sohbet))" "if (false)"
mut "dünkü damga geçer" pazar.mjs "if (m[1] !== gun)" "if (false)"
mut "Amazon kararsız gönderir" mesaj.mjs "if (!k.acik) throw new MesajHata('karar'" "if (false) throw new MesajHata('karar'"
mut "giriş sayfası tespiti kapalı" pazar.mjs "if (new RegExp(harita[pazar].giris_deseni).test(adres))" "if (false)"
mut "KVKK kırpma kapalı (telefon/e-posta çıplak)" pazar.mjs "return m.length > enCok ? m.slice(0, enCok - 1) + '…' : m;" "return String(metin || '').replace(/\\\\s+/g, ' ').trim();"
mut "harita tutmayınca tahmin eder" pazar.mjs "if (kimlikler.length !== onizlemeler.length)" "if (false)"
mut "Dümen Sultan'dayken rc 0" mesaj.mjs "if (e.neden === 'sultanda') { hata(\"⏸ Dümen Sultan'da · bekliyorum (mesaj komutu eylem yapmadı)\"); return 20; }" "if (e.neden === 'sultanda') { return 0; }"
[ "$MK" -eq 0 ] && { echo "SONUÇ: sınav yeşil · mutant 8/8 yakalandı"; exit 0; } || { echo "SONUÇ: $MK mutant YAKALANMADI"; exit 1; }
