#!/usr/bin/env bash
# karne-olcer.sh <depo kökü> — verilen ağacın .gitignore'uyla geçici bir klonda: karne defteri (_agents/fabrika/karne.jsonl) var iken
#   (1) yok sayılıyor mu (check-ignore) (2) git status'ta kayıtsız görünüyor mu (3) 'git add -A' onu commit'e alıyor mu.
#   Çıkış 0 = yok sayılıyor, status'ta yok, add -A almıyor · 1 = defter git'e sızabiliyor.
set -uo pipefail
R="$(cd "$1" && pwd)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
git init -q -b main "$T/d"; cp "$R/.gitignore" "$T/d/.gitignore"; mkdir -p "$T/d/_agents/fabrika"
echo '{"olay":"denetim","is":"x"}' > "$T/d/_agents/fabrika/karne.jsonl"
cd "$T/d" && git add -A
ig=0; git check-ignore -q _agents/fabrika/karne.jsonl && ig=1
st="$(git status --porcelain --ignored=no -- _agents/fabrika/karne.jsonl | wc -l)"; ad="$(git diff --cached --name-only | grep -c 'karne.jsonl')"
echo "yok sayılıyor: $([ $ig = 1 ] && echo evet || echo HAYIR) · status'ta görünüyor: $st · git add -A aldı: $ad"
[ $ig = 1 ] && [ "$st" = 0 ] && [ "$ad" = 0 ]
