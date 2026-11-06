#!/usr/bin/env bash
# kos.sh [once|mut] — birlestirme-kapisi.test.sh'i HEAD'in geçici kopyasında koşar.
#   once: kart.sh origin/main'den (düzeltmeden ÖNCE) · mut: borclar 'odendi' bilgisini yok sayar. İkisinde de T14m2 düşmeli.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi | tar -x -C "$T" || exit 3
case "${1:-}" in
  once) git -C "$R" show origin/main:yazilim-fabrikasi/scripts/kart.sh > "$T/yazilim-fabrikasi/scripts/kart.sh" || exit 3; echo "önce: origin/main kart.sh";;
  mut) python3 - "$T/yazilim-fabrikasi/scripts/kart.sh" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read(); a='odendi=borc_durumu(k["is"])=="odendi"'
assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,'odendi=False'))
PY
       echo "mutant: borclar ödenmiş borcu yok sayıyor";;
esac
bash "$T/yazilim-fabrikasi/scripts/birlestirme-kapisi.test.sh" 2>&1; exit $?
