#!/usr/bin/env bash
# CI'ın kendi sure_sec ayrıştırıcısıyla: denetci-duzeltme-farki.test.sh için okunan süre 620 olmalı, beyansız dosya 300 kalmalı.
KABUK_SURE_VARSAYILAN=300; KABUK_SURE_TAVAN=900
cd "$(git rev-parse --show-toplevel)" || exit 2
eval "$(sed -n '/^sure_sec() {/,/^}/p' .github/ci/kabuk-sinamalari.sh)"
a="$(sure_sec ./yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh)"; b="$(sure_sec ./yazilim-fabrikasi/scripts/manifest-ozet.test.sh)"
echo "denetci-duzeltme-farki okunan sure=$a (beklenen 620) · beyansız kontrol dosyası sure=$b (beklenen 300)"
[ "$a" = 620 ] && [ "$b" = 300 ]; rc=$?
exit $rc
