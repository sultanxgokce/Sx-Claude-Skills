#!/usr/bin/env bash
# iki-onarim-olcer.sh <kod kaynağı: git ref | "agac"> — iki görev tek ölçümde:
#   RN95G: 'cipa.sh tazele --help' çıkış kodu (yardım rc=0 olmalı) + tanınmayan argüman rc=2 kalmalı.
#   81D0W: ubl_satis sınavı, uuid4() 21 Eki'de CI'ı düşüren GERÇEK değeri ("de947859-…-a48e-0793542d7930", 'e-0' içerir)
#          döndürmeye ZORLANARAK koşar — %0,65'lik rastgele düşüş her koşuda yeniden üretilir (sahte uuid modülü, geçici dizinde).
#   Çıkış 0 = ikisi de onarılmış · 1 = en az biri bozuk.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/gp" "$T/el"
if [ "$1" = agac ]; then cp -a "$R/gunluk-plan/scripts/." "$T/gp/"; cp -a "$R/elogo-erisim/scripts/." "$T/el/"
else git -C "$R" archive "$1" gunluk-plan/scripts | tar -x -C "$T/gp" --strip-components=2
     git -C "$R" archive "$1" elogo-erisim/scripts | tar -x -C "$T/el" --strip-components=2; fi
echo "kod kaynağı: $1"
GUNLUK_PLAN_CIPA_DIZ="$T/cipa" bash "$T/gp/cipa.sh" tazele --help >/dev/null 2>&1; h=$?
GUNLUK_PLAN_CIPA_DIZ="$T/cipa" bash "$T/gp/cipa.sh" tazele --bilinmeyen >/dev/null 2>&1; b=$?
echo "RN95G · 'tazele --help' rc=$h (beklenen 0) · 'tazele --bilinmeyen' rc=$b (beklenen 2)"
printf 'def uuid4():\n    return "de947859-f685-4646-a48e-0793542d7930"\n' > "$T/el/uuid.py"
bash "$T/el/ubl_satis.test.sh" < /dev/null > "$T/u.log" 2>&1; u=$?
echo "81D0W · uuid4 = 21 Eki CI değeri (e-0 içerir) zorlanınca ubl_satis sınavı rc=$u"; grep -E "✗|toplam=" "$T/u.log"
[ "$h" = 0 ] && [ "$b" = 2 ] && [ "$u" = 0 ]
