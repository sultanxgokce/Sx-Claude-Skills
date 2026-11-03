#!/usr/bin/env bash
# mesaj.test.sh — pazaryeri-mesaj sınavı + MUTANTLAR (onay/karar/giriş/KVKK kapıları gevşerse sınav KIRMIZIYA dönmeli). Chromium yoksa ÖLÇÜLEMEDİ (rc 3).
# kabuk-testleri: sure=900   (13 mutant, üçer paralel; yerelde ~4 dk)
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
N=0; PIDS=(); ADLAR=()
mut() { # mut <ad> <dosya> <çapa> <bozuk> : kendi kopya dizininde kopyayı bozar, sınavı ARKA PLANDA koşar (üçer paralel), KIRMIZI beklenir
  N=$((N+1)); local D="$T/m$N"; mkdir -p "$D"; cp "$HERE/pazar.mjs" "$HERE/mesaj.mjs" "$HERE/mesaj.test.mjs" "$D/"
  if ! python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$D/$2" "$3" "$4" 2>"$D/capa.txt"; then echo "capa-yok" >"$D/sonuc.txt"; return; fi
  ( if PAZARYERI_MUTANT=0 MESAJ_LIB="$D/mesaj.mjs" PAZAR_LIB="$D/pazar.mjs" DUMEN_LIB="${DUMEN_LIB:-$HERE/../../dumen-surucu/scripts/dumen.mjs}" node "$D/mesaj.test.mjs" >"$D/o.txt" 2>&1; then echo "yesil" >"$D/sonuc.txt"; else echo "kirmizi" >"$D/sonuc.txt"; fi ) &
  PIDS+=($!); ADLAR+=("$1")
  [ $(( N % 3 )) -eq 0 ] && wait
}
MK=0
mut "onaysız gönderme serbest" mesaj.mjs "const dmg = damgaDogrula(onay, sohbet, metin);" "const dmg = { tarih: '', kaynak: '', ref: '', beyan: '' };"
mut "başka sohbetin damgası geçer" pazar.mjs "if (!sohbet || !metin.includes(sohbet))" "if (false)"
mut "dünkü damga geçer" pazar.mjs "if (m[1] !== gun)" "if (false)"
mut "Amazon kararsız gönderir" mesaj.mjs "if (!k.acik) throw new MesajHata('karar'" "if (false) throw new MesajHata('karar'"
mut "giriş sayfası tespiti kapalı" pazar.mjs "if (new RegExp(harita[pazar].giris_deseni).test(adres))" "if (false)"
mut "KVKK kırpma kapalı (telefon/e-posta çıplak)" pazar.mjs "return m.length > enCok ? m.slice(0, enCok - 1) + '…' : m;" "return String(metin || '').replace(/\\\\s+/g, ' ').trim();"
mut "harita tutmayınca tahmin eder" pazar.mjs "if (kimlikler.length !== onizlemeler.length)" "if (false)"
mut "onay cevap metnine bağlı değil (parmak izi kontrolü yok)" pazar.mjs "if (!metin.includes(iz)) throw new MesajHata('damga-metin'" "if (false) throw new MesajHata('damga-metin'"
mut "gönderim kilidi yok (aynı sohbete ikinci gönderim)" mesaj.mjs "if (kilit && kilit.durum === 'gonderildi')" "if (false)"
mut "belirsiz gönderim sonrası yeniden deneme serbest" mesaj.mjs "if (kilit && kilit.durum === 'belirsiz' && yeniden.length < 10)" "if (false)"
mut "Amazon kararı süresiz geçerli" pazar.mjs "if (!(yas >= 0 && yas <= gecerliGun))" "if (false)"
mut "gönderim izi düğmeden ÖNCE de aranmıyor (zaten var kontrolü yok)" pazar.mjs "if (once.includes(iz)) throw new MesajHata('iz-zaten-var'" "if (false) throw new MesajHata('iz-zaten-var'"
mut "Dümen Sultan'dayken rc 0" mesaj.mjs "if (e.neden === 'sultanda') { hata(\"⏸ Dümen Sultan'da · bekliyorum (mesaj komutu eylem yapmadı)\"); return 20; }" "if (e.neden === 'sultanda') { return 0; }"
wait
for i in $(seq 1 $N); do D="$T/m$i"; S=$(cat "$D/sonuc.txt" 2>/dev/null); AD="${ADLAR[$((i-1))]}"
  case "$S" in kirmizi) echo "  ✓ $AD: yakalandı ($(grep -c '  ✗' "$D/o.txt") kapı düştü)";; yesil) echo "  ✗ $AD: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1));; *) echo "  ✗ $AD: çapa bulunamadı ($(cat "$D/capa.txt" 2>/dev/null | tail -1))"; MK=$((MK+1));; esac; done
[ "$MK" -eq 0 ] && { echo "SONUÇ: sınav yeşil · mutant $N/$N yakalandı"; exit 0; } || { echo "SONUÇ: $MK mutant YAKALANMADI"; exit 1; }
