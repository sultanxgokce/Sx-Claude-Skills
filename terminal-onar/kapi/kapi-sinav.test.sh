#!/usr/bin/env bash
# ÇAĞIRAN KAPI — kapı sunucusunun birim sınavı (taban yolu · parola · koltuk · rapor · PANO KÖPRÜSÜ).
#
# Niçin (ölçüldü 13 Ekim 2026, pano köprüsü işinde): deponun CI koşucusu YALNIZ `*.test.sh`
# keşfediyor; `sunucu.test.mjs` (67 kapı) hiçbir kapıda koşmuyordu — rapor yolu için 1 Ekim'de
# yapılan sarmalayıcı kapının kendisini kapsamıyordu. Sınav yazmak onu koşturmaz.
# Mutasyon turu (mutasyon.sh, ~3 dk) ve tarayıcı sınavı (pano-sinav.mjs: ttyd+tmux+Chromium ister)
# bilerek BURADA değil: ilki CI bütçesini aşar, ikincisi CI'da daima ÖLÇÜLEMEDİ olur — daima sarı
# yanan kapı tiyatrodur. İkisi yerelde ve kanıt manifestinde koşar.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"
command -v node >/dev/null || { echo "ÖLÇÜLEMEDİ: node yok"; exit 3; }
echo "── kadro birleşimi (kadro.test.mjs)"
node kadro.test.mjs || exit 1
echo "── kadro E2 kayıt yazıcısı (kadro-yaz.test.mjs)"
node kadro-yaz.test.mjs || exit 1
echo "── kadro E2 ucu uçtan uca (kadro-hal.test.mjs)"
node kadro-hal.test.mjs || exit 1
echo "── kapı birim sınavı (sunucu.test.mjs)"
node sunucu.test.mjs
echo "SONUÇ: kapı birim sınavı geçti"
