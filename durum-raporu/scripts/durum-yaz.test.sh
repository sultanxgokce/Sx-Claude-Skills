#!/usr/bin/env bash
# durum-yaz.test.sh — durum-yaz.sh --kaynak öneki ve "biten iş şimdiki işi temizler" kuralı (Sx #594 göz tur 1).
# Hermetik: geçici proje kökü (CLAUDE_PROJECT_DIR + ekip-registry.yaml); gerçek hiçbir _agents/durum dosyasına dokunulmaz.
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="${DURUM_YAZ_SUT:-$BURASI/durum-yaz.sh}"
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
mkdir -p "$T/kok/_agents/handoff"; : > "$T/kok/_agents/handoff/ekip-registry.yaml"
gecen=0; kalan=0
g() { if [ "$1" = 0 ]; then echo "  ✓ $2"; gecen=$((gecen+1)); else echo "  ✗ $2"; kalan=$((kalan+1)); fi; }
yaz() { CLAUDE_PROJECT_DIR="$T/kok" bash "$S" --ad DENEK "$@" >"$T/o" 2>"$T/e" </dev/null; }
alan() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$T/kok/_agents/durum/DENEK.json" "$1"; }

yaz --kaynak sultan --simdi "rapor yazılıyor"; g $? "D1 yazım rc 0"
[ "$(alan "d['simdi']['is']")" = "Sizin isteğiniz: rapor yazılıyor" ]; g $? "D2 --kaynak sultan öneki eklenir"
yaz --bitti "rapor yazılıyor"
[ "$(alan "d['simdi']")" = "None" ]; g $? "D3 öneksiz --bitti, önekli şimdiki işi temizler (göz bulgusu)"
grep -q 'UYARI: --kaynak verilmedi' "$T/e"; g $? "D4 --kaynak yoksa uyarı basılır"
yaz --simdi "kanıt toplanıyor"
yaz --kaynak eksik --bitti "kanıt toplanıyor"
[ "$(alan "d['simdi']")" = "None" ]; g $? "D5 önekli --bitti, öneksiz şimdiki işi temizler"
[ "$(alan "d['bitirdi'][0]['is']")" = "Gördüğüm eksik: kanıt toplanıyor" ]; g $? "D6 biten iş önekiyle kaydedilir"
yaz --kaynak oneri --simdi "A işi"; yaz --kaynak oneri --bitti "B işi"
[ "$(alan "d['simdi']['is']")" = "Kendi önerim: A işi" ]; g $? "D7 başka iş bitince şimdiki iş KALIR"
yaz --kaynak bilinmez --simdi "C işi"
grep -q 'taninmadi' "$T/e" && [ "$(alan "d['simdi']['is']")" = "C işi" ]; g $? "D8 tanınmayan kaynak uyarır, önek eklemez"
for i in $(seq 1 32); do yaz --kaynak oneri --bitti "iş $i"; done
[ "$(alan "len(d['bitirdi'])")" = 30 ]; g $? "D9 geçmiş 30 işle sınırlı"

echo "durum-yaz: geçen=$gecen kalan=$kalan"
[ "$kalan" -eq 0 ]
