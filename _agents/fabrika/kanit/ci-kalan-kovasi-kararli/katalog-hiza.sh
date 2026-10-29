#!/usr/bin/env bash
# katalog-hiza.sh <kök> — bu işte dokunulan üç becerinin SKILL.md version'ı ile catalog.json sürümü aynı mı? (0 = üçü aynı · 1 = fark var)
set -u; cd "$1" || exit 2; rc=0
for s in tescil oda-kur yazilim-fabrikasi; do
  a="$(grep -m1 '^version:' "$s/SKILL.md" | awk '{print $2}')"
  b="$(python3 -c "import json,sys;c=json.load(open('catalog.json'));print(next((e.get('version') for e in c['skills'] if e.get('id')==sys.argv[1]),'?'))" "$s")"
  if [ "$a" = "$b" ]; then echo "✓ $s SKILL.md=$a catalog=$b"; else echo "✗ $s SKILL.md=$a catalog=$b (DRİFT)"; rc=1; fi
done; exit $rc
