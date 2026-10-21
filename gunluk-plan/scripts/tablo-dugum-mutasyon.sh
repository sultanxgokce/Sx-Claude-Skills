#!/usr/bin/env bash
# tablo-dugum-mutasyon.sh — tablo.py düğüm kurallarını tek tek öldürür; cipa.test.sh KIRMIZI olmalı.
#   Kopya üstünde koşar (betiğin kendisine dokunmaz). Önce pozitif kontrol: dokunulmamış kopya YEŞİL olmalı.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"; E="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'sil "$E"' EXIT
gecti=0; dusen=0
kopya() { sil "$E/m"; cp -r "$D" "$E/m"; }
kopya; if bash "$E/m/scripts/cipa.test.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <eski> <yeni>
  kopya
  if ! python3 - "$E/m/scripts/tablo.py" "$2" "$3" <<'PY'
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  then echo "  ✗ $1 — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1)); return; fi
  if bash "$E/m/scripts/cipa.test.sh" >/dev/null 2>&1; then echo "  ✗ $1 — kural ÖLDÜ ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $1 — kural ölünce sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
dene "TM1 bağ tabloya yazılmaz" "if g in bag else ''" "if False else ''"
dene "TM2 jetonsuz kutu sessiz kalır" "return {}, 'bu kutuda defter jetonu yok'" "return {}, ''"
dene "TM3 404 hata sayılır" "if e.code != 404:" "if True:"
dene "TM4 bozuk dugum_acar gösterilir" "if isinstance(d, str) and DUGUM.fullmatch(d):" "if d:"
dene "TM5 --json'a bağ sızar (kokpit fikstürü bozulur)" "print(json.dumps(c, ensure_ascii=False, indent=2)); return 0" "c['dugum'] = dugumler(c)[0]; print(json.dumps(c, ensure_ascii=False, indent=2)); return 0"
dene "TM6 okunamayınca söylenmez" "    if sebep:
        print(" "    if False:
        print("
dene "TM7 ⛓ anlamı söylenmez" "    if bag:
        print(" "    if False:
        print("
dene "TM8 görevsiz çıpada da deftere gider" "    if not ids:
        return {}, ''" "    if False:
        return {}, ''"
dene "TM9 değer desenle değil yalnız ':' ile sınanır" "if isinstance(d, str) and DUGUM.fullmatch(d):" "if isinstance(d, str) and ':' in d:"
dene "TM10 hata anında yarım bağlar basılır" "                return {}, 'defter http %d' % e.code" "                return bag, 'defter http %d' % e.code"
echo "─────────────"; echo "MUTASYON: gecti=$gecti dusen=$dusen"; [ $dusen -eq 0 ]
