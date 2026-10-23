#!/usr/bin/env bash
# genislik-olcer.sh <kod kaynağı: git ref | "agac"> — #433 rötuşu: `kanit.sh ekran --uc-boy --genislik 800` ne yapıyor?
#   Verilen kaynaktaki yazilim-fabrikasi/scripts geçici dizine alınır; sahte node (yalnız istenen genişliği deftere yazar ve
#   sahte PNG bırakır) ile komut koşulur. Ölçülen: çıkış kodu · tarayıcıya giden genişlikler · yazılan kayıt sayısı.
#   Çıkış 0 = çatışma reddedildi (rc 2, tarayıcı açılmadı, kayıt yok) · 1 = değil (--genislik sessizce yok sayıldı).
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s" "$T/bin" "$T/pw/playwright" "$T/d"; git -C "$T/d" init -q
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts | tar -x -C "$T/s" --strip-components=2; fi
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$6" >> "%s/boy-log"; printf "PNG%%s" "$6" > "$3"\n' "$T" > "$T/bin/node"; chmod +x "$T/bin/node"; : > "$T/boy-log"
O="$(cd "$T/d" && PATH="$T/bin:$PATH" KANIT_PLAYWRIGHT_DIR="$T/pw" KANIT_DEPO="$T/d" KANIT_GELEN_DIZ="$T/gelen-yok" bash "$T/s/kanit.sh" ekran olc c --url https://ornek.test --asama tek --uc-boy --genislik 800 < /dev/null 2>&1)"; rc=$?
N="$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['kayitlar']))" "$T/d/_agents/fabrika/kanit/olc/KANIT.json" 2>/dev/null || echo 0)"
echo "kod kaynağı: $1 · kanit.sh ekran --uc-boy --genislik 800 → rc=$rc · tarayıcıya giden genişlikler: $(tr '\n' ' ' < "$T/boy-log")· kayıt: $N"
printf '%s\n' "$O" | grep -E "birlikte|özeti" | sed 's/^/   /'
[ "$rc" = 2 ] && [ ! -s "$T/boy-log" ] && [ "$N" = 0 ]
