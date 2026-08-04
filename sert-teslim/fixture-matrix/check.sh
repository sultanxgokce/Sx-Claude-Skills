#!/bin/sh
# Generic fixture-check: marker-dosya varsa PASS (rc=0), yoksa FAIL (rc=1). Aynı-komut kırmızı-üretebilir.
set -eu
[ -f "${1:?kullanım: check.sh <marker>}" ] && echo "fixture OK" || { echo "fixture FAIL: marker yok" >&2; exit 1; }
