#!/usr/bin/env bash
# mut-catal-uzak.sh — HEAD'i geçici dizine çıkarır; çatal PR'da uzak arama dalı silinir (çatal hep itilmez). F5r düşmeli.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD | tar -x -C "$T" || exit 3
python3 - "$T/yazilim-fabrikasi/scripts/denetci.sh" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p=sys.argv[1]; s=open(p).read()
a='elif [ "${_CAPRAZ:-}" = true ] && [ -n "${_BSAHIP:-}" ] && [ -n "${_BDEPO:-}" ]; then'
assert s.count(a)==1; open(p,'w').write(s.replace(a,'elif false; then'))
PY
bash -n "$T/yazilim-fabrikasi/scripts/denetci.sh" || exit 3; echo "mutant: çatal uzak araması kapalı"
bash "$T/yazilim-fabrikasi/scripts/denetci-fark-kendisi.test.sh" 2>&1; exit $?
