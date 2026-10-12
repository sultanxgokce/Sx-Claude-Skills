#!/usr/bin/env bash
# Prob: kur --dry-run zincir kapısı — boru (SIGPIPE) etkisi kaldırılınca 6/8 düşüyor mu? dal vs ana dal, 3'er koşu
set -u
T=/config/.claude/jobs/d69a1b07/tmp/kur-prob-$(date +%H%M)
mkdir -p "$T/dal" "$T/ana"
WT=/config/projects/_wt/Sx-Claude-Skills-iskan-dusme-varsayilan-ret
git -C "$WT" archive HEAD iskan | tar -x -C "$T/dal"
git -C "$WT" archive origin/main iskan | tar -x -C "$T/ana"
for k in dal ana; do
  f="$T/$k/iskan/scripts/iskan.test.sh"
  python3 - "$f" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
old="""  printf '%s' "$out" | grep -q "kur adım $a" || adim_eksik="$adim_eksik [$a]\""""
new="""  grep -q "kur adım $a" <<<"$out" || adim_eksik="$adim_eksik [$a]\""""
assert s.count(old)==1, "kalip bulunamadi"
open(p,'w',encoding='utf-8').write(s.replace(old,new))
PY
done
for k in dal ana; do
  for i in 1 2 3; do
    r=$(cd "$T/$k" && bash iskan/scripts/iskan.test.sh 2>&1 | grep -E "kur --dry-run: (8 adımın|zincir-planında)|geçti" | tr '\n' ' ')
    echo "$k#$i: $r"
  done
done
