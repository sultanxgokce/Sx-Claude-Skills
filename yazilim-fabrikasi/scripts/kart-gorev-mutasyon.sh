#!/usr/bin/env bash
# kart-gorev-mutasyon.sh — kart.sh görev durumu kurallarını (Y7J3Q) tek tek öldürür; kart.test.sh KIRMIZI olmalı.
#   Kopya üstünde koşar (betiğin kendisine dokunmaz). Önce pozitif kontrol: dokunulmamış kopya YEŞİL olmalı.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; E="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'sil "$E"' EXIT
gecti=0; dusen=0
kopya() { sil "$E/m"; cp -r "$D" "$E/m"; }
kopya; if bash "$E/m/kart.test.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <eski> <yeni>
  kopya
  if ! python3 - "$E/m/kart.sh" "$2" "$3" <<'PY'
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  then echo "  ✗ $1 — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1)); return; fi
  if bash "$E/m/kart.test.sh" >/dev/null 2>&1; then echo "  ✗ $1 — kural ÖLDÜ ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $1 — kural ölünce sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
dene "KG1 --gorev tahminsiz kabul edilir" '[[ "$TAHMIN" =~ ^[1-9][0-9]{0,4}$ ]] ||' 'true ||'
dene "KG2 görev kimliği biçimi sınanmaz" '[[ "$GOREV" =~ ^gorev_[A-Za-z0-9]{10,40}$ ]] ||' 'true ||'
dene "KG3 açılışta atanan yazılmaz" 'y={"atanan":kim,"tahmin_dk"' 'y={"tahmin_dk"'
dene "KG4 bitti insanın tikini (bitti) yazar — A06" 'y={"gorev_durumu":"onay-bekliyor","kanit":kn}' 'y={"gorev_durumu":"bitti","kanit":kn}'
dene "KG5 tıkandı notsuz bekliyor yazar" 'y={"gorev_durumu":"bekliyor","not":"kart %s tıkandı: %s" % (is_,nd[:300])}' 'y={"gorev_durumu":"bekliyor"}'
dene "KG6 açılışta yazılamayınca rc 0 (sessiz)" 'GRC=0; [ -n "$GOREV" ] && { gorev_yaz "$KD/$IS.json" ac || GRC=4; }' 'GRC=0; [ -n "$GOREV" ] && { gorev_yaz "$KD/$IS.json" ac || GRC=0; }'
dene "KG7 bitti/tıkandı'da yazılamayınca rc 0 (sessiz)" '{ gorev_yaz "$KD/$IS.json" "$CMD" || GRC=4; }' '{ gorev_yaz "$KD/$IS.json" "$CMD" || GRC=0; }'
dene "KG8 yazım sonucu karta işlenmez" 'k.setdefault("gorev_yazimlari",[]).append(' 'list().append('
dene "KG9 jetonsuz kutuda da deftere gidilir" 'if [ ! -r "$DEFTER_JY" ]; then sonuc=' 'if false; then sonuc='
dene "KG10 bağsız kartta 'görünüme düşmez' uyarısı yok" 'if not gorev: print("  · görev bağı yok' 'if False: print("  · görev bağı yok'
dene "KG11 hedef türü korunmaz (E4ZYG4)" 'HEDEF=os.environ.get("MEVCUT_HEDEF")=="evet"; ATANAN' 'HEDEF=False; ATANAN'
dene "KG12 hedef türü hiç okunmaz (E4ZYG4)" 'tek("hedef_turu")' '"-"'
dene "KG13 başkasının ataması korunmaz (E4ZYG4)" 'BASKASI=os.environ.get("MEVCUT_BASKASI")=="1"' 'BASKASI=False'
dene "KG14 ad karşılaştırması harf farkına takılır (E4ZYG4)" 'if m.norm(atn)!=m.norm(json.load(open(p))["aldi"]): print(1)' 'if atn!=json.load(open(p))["aldi"]: print(1)'
dene "KG15 boşluklu atanan kırpılır (E4ZYG4)" '[ "${MATANAN:-}" = "-" ] && MATANAN="";' 'MATANAN="${MATANAN%% *}"; [ "${MATANAN:-}" = "-" ] && MATANAN="";'
echo "─────────────"; echo "MUTASYON: gecti=$gecti dusen=$dusen"; [ $dusen -eq 0 ]
