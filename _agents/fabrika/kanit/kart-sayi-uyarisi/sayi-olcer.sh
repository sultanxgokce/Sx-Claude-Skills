#!/usr/bin/env bash
# sayi-olcer.sh <kod kaynağı: git ref | "agac"> — WNMSQ: Nexus #1213'te iki tur yakan kart cümlesi ("yöneticinin 13 görev
#   listesi") verilen kaynaktaki kart.sh ile geçici bir depoda açılır. Ölçülen: kart açıldı mı (red YOK olmalı) ve ölçümsüz
#   sayı için UYARI basılıp karta yazıldı mı. Çıkış 0 = açıldı + uyardı + karta yazdı · 1 = sessiz geçti ya da reddetti.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s" "$T/d"; git -C "$T/d" init -q
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts | tar -x -C "$T/s" --strip-components=2; fi
echo "kod kaynağı: $1"
C="yöneticinin 13 görev listesi panelde tek tek kapansın"
O="$(cd "$T/d" && KANIT_DEPO="$T/d" bash "$T/s/kart.sh" ac olc --is "$C" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h < /dev/null 2>&1)"; rc=$?
U="$(python3 -c "import json,sys;print(' | '.join(json.load(open(sys.argv[1])).get('sayi_uyarilari',['(alan yok)'])))" "$T/d/_agents/fabrika/kartlar/olc.json" 2>&1)"
echo "cümle: $C"; echo "kart.sh ac rc=$rc · ekrandaki SAYI uyarısı: $(grep -c '⚠ SAYI' <<<"$O") · karttaki sayi_uyarilari: $U"
[ "$rc" = 0 ] && grep -q "⚠ SAYI — .*'13 görev'" <<<"$O" && [ "$U" = "13 görev" ]
