#!/usr/bin/env bash
# kos.sh <kip> — on-goz.test.sh'ı becerinin TAM arşivlenmiş bir kopyasında koşar (kart on-goz-a5-parca).
#   once: HEAD becerisi + origin/main'deki on-goz.py (yeni sınav eski koda karşı) · sonra: HEAD · mut-<ad>: HEAD kopyasında on-goz.py'nin geçici bozulmuş hâli (ağaç değişmez)
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; kip="${1:?kip}"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$K" archive HEAD yazilim-fabrikasi | tar -x -C "$T"
S="$T/yazilim-fabrikasi/scripts"
case "$kip" in
  once) git -C "$K" show origin/main:yazilim-fabrikasi/scripts/on-goz.py > "$S/on-goz.py" ;;   # yeni sınav, eski kod
  sonra) ;;
  mut-*) python3 - "$S/on-goz.py" "${kip#mut-}" <<'PY'
import sys
p, ad = sys.argv[1:]; s = open(p, encoding="utf-8").read()
M = {
  "parantez-yok": ('        if not kendi and i >= 2 and p[i - 1] in "([" and YALNIZ_SOZ.match(p[i]):', '        if False:'),
  "liste-yok": ('        while j >= 2 and p[j - 1] == ", " and _yalin_liste(p[j - 2]):', '        while False:'),
  "her-parantez": ('p[i - 1] in "([" and YALNIZ_SOZ.match(p[i]):', 'p[i - 1] in "([":'),
  "fiil-kesmez": ('    return bool(_yollar(parca)) and not re.sub(r"[\\s`\'\\"]", "", kalan)', '    return bool(_yollar(parca))'),
}
a, b = M[ad]; assert s.count(a) == 1, (ad, s.count(a)); open(p, "w", encoding="utf-8").write(s.replace(a, b))
PY
  ;;
  *) echo "bilinmeyen kip: $kip" >&2; exit 2 ;;
esac
bash "$S/on-goz.test.sh"
