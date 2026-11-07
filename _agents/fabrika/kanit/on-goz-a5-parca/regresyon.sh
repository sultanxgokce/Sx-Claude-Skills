#!/usr/bin/env bash
# regresyon.sh — ön gözü kullanan uçtan uca sınav (denetci-on-goz.test.sh) HEAD becerisinin tam kopyasında
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$K" archive HEAD yazilim-fabrikasi | tar -x -C "$T"
bash "$T/yazilim-fabrikasi/scripts/denetci-on-goz.test.sh"
