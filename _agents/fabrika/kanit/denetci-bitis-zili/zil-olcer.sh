#!/usr/bin/env bash
# zil-olcer.sh <betik-dizini> — denetçi SESSİZ mi bitiyor? Aynı üç senaryo verilen yazilim-fabrikasi/scripts kopyasında koşar:
#   A · koşarken "başladı" izi var mı (DENETIM-<tur>.kosuyor)
#   B · 6 sn süren denetçi + DENETCI_ZAMAN_ASIMI=2: kaç sn bekletiyor, rc ne, HAM'da ZAMAN AŞIMI var mı
#   C · rc 0 · rc 1 · rc 2 (kanıt yok) çıkışlarında sahte zile kaç satır düştü
# Önce = origin/main'in TAM betik dizini kopyası, sonra = çalışma ağacı (yöntem, girdi, sahte zil aynı).
set -uo pipefail
S="$(cd "$1" && pwd)"   # mutlak yol: ölçer aşağıda geçici depoya geçer
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
D="$T/depo"; mkdir -p "$D"; git -C "$D" init -q -b main
export KANIT_DEPO="$D" FABRIKA_AILE_NOTIFY="$T/zil.sh" AGENT_NAME=OLCER
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/zil.log"\n' "$T" > "$T/zil.sh"; chmod +x "$T/zil.sh"
printf 'diff --git a/x b/x\n+s\n' > "$T/d.patch"
cd "$D"
for is in a b c; do bash "$S/kart.sh" ac "is-$is" --is x --istedi SERDAR --aldi OLCER --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
  bash "$S/kanit.sh" olcum "is-$is" olc --asama tek -- true >/dev/null 2>&1; done
J='{"kod_puani":%s,"dogru_sey":"%s","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
printf '#!/usr/bin/env bash\nls "%s/_agents/fabrika/kanit/is-a" > "%s/ls"; printf "%%s" "$SJ"\n' "$D" "$T" > "$T/izci.sh"
printf '#!/usr/bin/env bash\nsleep 6; printf "%%s" "$SJ"\n' > "$T/yavas.sh"; printf '#!/usr/bin/env bash\nprintf "%%s" "$SJ"\n' > "$T/hizli.sh"; chmod +x "$T"/*.sh
echo "── A · koşarken başladı izi"
SJ="$(printf "$J" 3 H)" DENETCI_KOMUT="$T/izci.sh" bash "$S/denetci.sh" is-a --diff "$T/d.patch" >/dev/null 2>&1
grep -q '\.kosuyor$' "$T/ls" && echo "  iz: VAR ($(grep '\.kosuyor$' "$T/ls"))" || echo "  iz: YOK — bekleyen denetçinin başlayıp başlamadığını göremez"
echo "── B · 6 sn süren denetçi, DENETCI_ZAMAN_ASIMI=2"
b=$(date +%s); SJ="$(printf "$J" 5 E)" DENETCI_KOMUT="$T/yavas.sh" DENETCI_ZAMAN_ASIMI=2 bash "$S/denetci.sh" is-b --diff "$T/d.patch" >/dev/null 2>&1; rc=$?
s=$(( $(date +%s) - b )); h="$(grep -l 'ZAMAN AŞIMI' "$D"/_agents/fabrika/kanit/is-b/DENETIM-*-HAM.txt 2>/dev/null | head -1)"
echo "  bekleme: ${s} sn · rc $rc · HAM'da ZAMAN AŞIMI: $([ -n "$h" ] && echo VAR || echo YOK)"
echo "── C · çıkışlarda zil (sahte aile-notify'a düşen satır)"
: > "$T/zil.log"; SJ="$(printf "$J" 5 E)" DENETCI_KOMUT="$T/hizli.sh" bash "$S/denetci.sh" is-c --diff "$T/d.patch" >/dev/null 2>&1; r0=$?; n0=$(wc -l < "$T/zil.log")
: > "$T/zil.log"; SJ="$(printf "$J" 3 H)" DENETCI_KOMUT="$T/hizli.sh" bash "$S/denetci.sh" is-a --diff "$T/d.patch" >/dev/null 2>&1; r1=$?; n1=$(wc -l < "$T/zil.log")
: > "$T/zil.log"; SJ="$(printf "$J" 5 E)" DENETCI_KOMUT="$T/hizli.sh" bash "$S/denetci.sh" is-yok --diff "$T/d.patch" >/dev/null 2>&1; r2=$?; n2=$(wc -l < "$T/zil.log")
echo "  rc $r0 → $n0 zil · rc $r1 → $n1 zil · rc $r2 (kanıt yok) → $n2 zil"
ses=$(( n0>0 && n1>0 && n2>0 )); iz=$(grep -qc '\.kosuyor$' "$T/ls" && echo 1 || echo 0); as=$([ -n "$h" ] && [ "$s" -lt 5 ] && echo 1 || echo 0)
echo "── SONUÇ: iz $([ "$iz" = 1 ] && echo ✓ || echo ✗) · zaman aşımı $([ "$as" = 1 ] && echo ✓ || echo ✗) · her çıkışta zil $([ "$ses" = 1 ] && echo ✓ || echo ✗)"
[ "$iz" = 1 ] && [ "$as" = 1 ] && [ "$ses" = 1 ]
