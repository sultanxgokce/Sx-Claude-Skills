#!/usr/bin/env bash
# gercek.sh — bu iş alanında (gerçek depo, gerçek kart, gerçek kanıt) tavan defterine denetçinin --reis-devam satırı biçiminde GEÇİCİ bir satır
#   ekler; ana dal on-goz.py'si ile HEAD on-goz.py'sini aynı ağaçta koşar, A4 hükümlerini yazar, satırı geri alır (git checkout).
#   Beklenen: ana dal A4 uyumsuz (ölçülen kusur) · HEAD A4 uyumlu. rc 0 yalnız bu ikisi tutarsa.
set -u; R="$(git rev-parse --show-toplevel)"; F="$R/_agents/fabrika/tavan-defteri.log"; T="$(mktemp -d)"
trap 'git -C "$R" checkout -- _agents/fabrika/tavan-defteri.log; find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" show origin/main:yazilim-fabrikasi/scripts/on-goz.py > "$T/on-goz-eski.py" || exit 3
cp "$R"/yazilim-fabrikasi/scripts/*.py "$R"/yazilim-fabrikasi/scripts/kanit.sh "$T/" 2>/dev/null; cp "$T/on-goz-eski.py" "$T/on-goz.py"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | TAVAN-ACILDI-REIS | is=on-goz-a4-defter tur=3 | reis=BÂNİ oturum=gercek-sh gerekce=\"gerçek koşu: geçici satır\"" >> "$F"
a4() { python3 "$1" on-goz-a4-defter --depo "$R" --json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);k=[x for x in d["kapilar"] if x["ad"].startswith("A4")][0];print(k["durum"]+" · "+k["satirlar"][0])'; }
E="$(a4 "$T/on-goz.py")"; Y="$(a4 "$R/yazilim-fabrikasi/scripts/on-goz.py")"
echo "ana dal A4: $E"; echo "HEAD    A4: $Y"
case "$E/$Y" in uyumsuz*/uyumlu*) echo "✓ kusur ana dalda görünüyor, HEAD'de kapalı"; exit 0 ;; *) echo "✗ beklenen değil"; exit 1 ;; esac
