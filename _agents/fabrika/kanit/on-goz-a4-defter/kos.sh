#!/usr/bin/env bash
# kos.sh [once|defter-haric-yok] — on-goz.test.sh ve denetci-on-goz.test.sh'i (uçtan uca Z1-Z2) HEAD kopyasıyla (becerinin tamamı) koşar.
#   once : sınavlar HEAD'den, ürün (on-goz.py) origin/main'den → S9c/S9d/S9e ve Z1/Z2 kırmızı olmalı.
#   defter-haric-yok : A4 yalnız kanıt dizinini hariç tutar (eski davranış) → S9c ve Z1 düşmeli.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"
case "${1:-}" in
  once) git -C "$R" show origin/main:yazilim-fabrikasi/scripts/on-goz.py > "$S/on-goz.py" || exit 3; echo "önce: on-goz.py origin/main ($(git -C "$R" rev-parse --short origin/main))" ;;
  defter-haric-yok) python3 - "$S/on-goz.py" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a='*(f":(top,exclude){y}" for y in DEFTER_HARIC)'; assert s.count(a)==1
open(p,"w",encoding="utf-8").write(s.replace(a,'":(top,exclude)_agents/fabrika/kanit"')); print("mutant: defter-haric-yok")
PY
  ;;
  "") ;;
  *) echo "bilinmeyen kip: $1"; exit 3 ;;
esac
r=0; bash "$S/on-goz.test.sh" || r=1
ON_GOZ_SINAV=1 MUTANT_D="$S/denetci.sh" bash "$S/denetci-on-goz.test.sh" || r=1
exit $r
