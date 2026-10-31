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
node koltuk-onbellek.test.mjs || exit 1   # 2.36.9: koltuk listesi önbelleği
node soru.test.mjs || exit 1   # 2.23.0 K1: koltuk sorusu (tür · metin · şıklar · beri) + sır süzgeci
echo "── kadro E2 kayıt yazıcısı (kadro-yaz.test.mjs)"
node kadro-yaz.test.mjs || exit 1
echo "── kadro E2 ucu uçtan uca (kadro-hal.test.mjs)"
node kadro-hal.test.mjs || exit 1
echo "── kadro etiketi: yazıcı (kadro-etiket.test.mjs) + uç uçtan uca (kadro-etiket-uc.test.mjs)"
node kadro-etiket.test.mjs || exit 1
node kadro-etiket-uc.test.mjs || exit 1
echo "── kişi↔oturum kimlik eşleşmesi (kimlik.test.mjs)"
node kimlik.test.mjs || exit 1
echo "── kapı-yenile: SIGHUP ile pano.js bağlantı düşürmeden tazelenir (kapi-yenile.test.mjs)"
node kapi-yenile.test.mjs || exit 1
echo "── tarayıcı bulucu (tarayici-bul.test.mjs — hermetik kapılar; G1 gerçek kutu: ikili yoksa rc 4 ÖLÇÜLEMEDİ = sarı, kırmızı değil)"
node tarayici-bul.test.mjs && rc=0 || rc=$?   # set -e: rc burada yakalanır
if [ $rc = 4 ]; then echo "ÖLÇÜLEMEDİ (sarı): bu koşucuda Playwright ikilisi yok — hermetik kapılar geçti, gerçek kutu kapısı ölçülmedi"; elif [ $rc != 0 ]; then exit 1; fi
echo "── kapı birim sınavı (sunucu.test.mjs)"
node sunucu.test.mjs
echo "SONUÇ: kapı birim sınavı geçti"
