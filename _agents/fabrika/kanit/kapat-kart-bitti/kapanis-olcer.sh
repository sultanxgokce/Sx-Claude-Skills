#!/usr/bin/env bash
# kapanis-olcer.sh <kod kaynağı: git ref | "agac"> — CBBQEE: PR'ı birleşmiş bir işin alanı kapatılınca kart ne durumda kalıyor?
#   Verilen kaynaktaki yazilim-fabrikasi/scripts geçici dizine alınır; geçici depoda kart (açık) + alan (kanıt YALNIZ alanda) kurulur,
#   sahte gh "PR #42 birleşmiş" der, `is-alani.sh kapat` koşar. Çıkış 0 = kart 'bitti' (pr 42, kanıt alanın içinden görüldü) · 1 = açık kaldı.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s" "$T/uzak" "$T/depo" "$T/bin"
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts | tar -x -C "$T/s" --strip-components=2; fi
( cd "$T/uzak" && git init -q --bare ) && ( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T &&
  echo ilk > d.txt && git add -A && git commit -qm "chore: ilk" && git remote add origin "$T/uzak" && git push -q -u origin main ) >/dev/null 2>&1
printf '#!/usr/bin/env bash\necho 42\n' > "$T/bin/gh"; chmod +x "$T/bin/gh"
mkdir -p "$T/depo/_agents/fabrika/kartlar"; printf '{"is":"olc","cumle":"c","istedi":"S","aldi":"H","durum":"acik","gecmis":[]}\n' > "$T/depo/_agents/fabrika/kartlar/olc.json"
export IS_ALANI_DEPO="$T/depo" IS_ALANI_KOK="$T/alan"
( cd "$T/depo" && bash "$T/s/is-alani.sh" ac olc --kartsiz >/dev/null 2>&1 )
mkdir -p "$T/alan/depo-olc/_agents/fabrika/kanit/olc"; echo '{}' > "$T/alan/depo-olc/_agents/fabrika/kanit/olc/KANIT.json"
git -C "$T/alan/depo-olc" add -A >/dev/null 2>&1; git -C "$T/alan/depo-olc" -c user.email=t@t -c user.name=t commit -q -m kanit >/dev/null 2>&1
O="$( cd "$T/depo" && PATH="$T/bin:$PATH" bash "$T/s/is-alani.sh" kapat olc < /dev/null 2>&1 )"; rc=$?
D="$(python3 -c 'import json,sys;k=json.load(open(sys.argv[1]));print(k["durum"],k.get("pr","-"),k.get("kanit_var","-"))' "$T/depo/_agents/fabrika/kartlar/olc.json")"
echo "kod kaynağı: $1 · kapat rc=$rc · alan: $([ -d "$T/alan/depo-olc" ] && echo duruyor || echo kaldırıldı) · kart (durum pr kanıt): $D"
printf '%s\n' "$O" | grep -E "kart|alan" | sed 's/^/   /'
[ "$D" = "bitti 42 True" ]
