#!/usr/bin/env bash
# bulgu-dugum-mutasyon.sh — --dugum kurallarını tek tek öldürür; bulgu.test.sh KIRMIZI olmalı.
#   Kopya üstünde koşar (betiğin kendisine dokunmaz). Önce pozitif kontrol: dokunulmamış kopya YEŞİL olmalı.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; E="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'sil "$E"' EXIT
gecti=0; dusen=0
kopya() { sil "$E/m"; mkdir -p "$E/m"; cp "$D/bulgu.sh" "$D/bulgu.test.sh" "$E/m/"; }
kopya; if bash "$E/m/bulgu.test.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <eski> <yeni>
  kopya
  if ! python3 - "$E/m/bulgu.sh" "$2" "$3" <<'PY'
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  then echo "  ✗ $1 — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1)); return; fi
  if bash "$E/m/bulgu.test.sh" >/dev/null 2>&1; then echo "  ✗ $1 — kural ÖLDÜ ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $1 — kural ölünce sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
dene "MD1 düğüm gövdeye yazılmaz" 'if dg: d["dugum_acar"]=dg' 'pass'
dene "MD2 jetonsuz kutuda --dugum sessizce düşer" 'if [ -n "$dugum" ] && [ ! -r "$JY" ]; then' 'if false; then'
dene "MD3 çıplak kimlik çözülmeden gider" "case \"\$dugum\" in ''|*:*) ;; *)" "case \"\$dugum\" in *) ;; xx)"
dene "MD4 çıplak kimlik biçimi denetlenmez (yol kaçışı)" '[[ "$dugum" =~ ^gorev_[A-Za-z0-9]+$ ]] ||' 'true ||'
dene "MD5 kutu canlı değerden değil ekleyenden okunur" 'k["canli"].get("kutu") or k.get("ekleyen_kutu"), k["id"]), end="")' 'k.get("ekleyen_kutu"), k["id"]), end="")'
dene "MD6 bekleyen sonucu söylenmez" 'if b: print("  ⛓ bekleyen' 'if False: print("  ⛓ bekleyen'
dene "MD7 düğüm boş dize kabul edilir" '[ $# -ge 2 ] && [ -n "$2" ] || { echo "--dugum değersiz"' '[ $# -ge 2 ] || { echo "--dugum değersiz"'
dene "MD8 görünmeyen düğümde yine de yazar" '"$dugum")" || exit 1 ;;' '"$dugum")" ;;'
dene "MD9 bekleyen notu yazılamadığında rc 0 döner" 'if b and not b.get("yazildi"): sys.exit(4)' 'pass'
echo "─────────────"; echo "MUTASYON: gecti=$gecti dusen=$dusen"; [ $dusen -eq 0 ]
