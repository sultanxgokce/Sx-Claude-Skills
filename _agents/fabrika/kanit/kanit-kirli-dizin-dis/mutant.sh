#!/usr/bin/env bash
# mutant.sh <ad>: kanit.py kopyasını bozar, sınavı kopyayla koşar. rc 1 yalnız beklenen kapı kırmızıysa.
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"; M="$(mktemp -d)"; trap 'find "$M" -delete' EXIT
cp "$KOK"/yazilim-fabrikasi/scripts/kanit.py "$KOK"/yazilim-fabrikasi/scripts/kanit.sh "$KOK"/yazilim-fabrikasi/scripts/kanit-olculen-commit.test.sh "$M/"
case "$1" in
  dislama-yok) kapi='ikinci kayıt da False'; a=', "--", ":/", ":(top,exclude)_agents/fabrika/kanit"]'; b=']' ;;
  her-seyi-disla) kapi='kanıt dışı değişiklik True'; a=':(top,exclude)_agents/fabrika/kanit'; b=':(top,exclude)*' ;;
  *) echo "bilinmeyen mutant"; exit 2 ;;
esac
python3 - "$M/kanit.py" "$a" "$b" <<'ESAS'
import sys
p,a,b=sys.argv[1:4]; s=open(p,encoding='utf-8').read(); assert a in s,'çapa yok'; open(p,'w',encoding='utf-8').write(s.replace(a,b,1))
ESAS
[ $? = 0 ] || { echo "mutant uygulanamadı"; exit 2; }
KANIT="$M/kanit.sh" bash "$M/kanit-olculen-commit.test.sh" > "$M/out" 2>&1
grep -E '✗|SONUÇ' "$M/out"
if grep -q "✗ .*$kapi" "$M/out"; then echo "YAKALANDI: $kapi"; exit 1; fi
echo "KAÇTI: $kapi"; exit 0
