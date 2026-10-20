#!/usr/bin/env bash
# koltuk-adi.sh — koltuk (tmux oturumu) ADI süzgecinin TEK kabuk kopyası (dilim 5/7 · yedek göz tur 3). koltuk-bagla.sh ve
# koltuk-ac.sh bunu yükler; kapı (kapi/sunucu.mjs) aynı kuralı KOLTUK_AD_DESEN sabitinde taşır — iki dilin eşdeğerliğini
# koltuk-adi.test.sh ölçer (aynı derlem, aynı hüküm).
# KURAL: 1-200 karakter · boşluk YOK (tercihimiz; tmux izin verir — ölçüldü) · '.' ve ':' YOK (tmux bunları '_' yapar) ·
#   İLK karakter '$' '@' '%' '=' OLAMAZ: tmux hedefinde bunlar oturum/pencere/bölme KİMLİĞİ ve tam-eşleşme önekidir —
#   '$1' adlı koltuk '-t' ile başka oturuma çözülüyordu (ölçüldü). Güvenlik yine tmux'un beyaz listesinden (var olan oturum) gelir.
KOLTUK_AD_DESEN='^[^[:space:]:.$@%=][^[:space:]:.]{0,199}$'
koltuk_adi_gecerli() { [[ "$1" =~ $KOLTUK_AD_DESEN ]]; }
