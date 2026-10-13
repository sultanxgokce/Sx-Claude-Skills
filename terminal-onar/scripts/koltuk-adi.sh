#!/usr/bin/env bash
# koltuk-adi.sh — koltuk (tmux oturumu) ADI süzgecinin TEK kabuk kopyası (dilim 5/7 · yedek göz tur 3). koltuk-bagla.sh ve
# koltuk-ac.sh bunu yükler; kapı (kapi/sunucu.mjs) aynı kuralı KOLTUK_AD_DESEN sabitinde taşır — iki dilin eşdeğerliğini
# koltuk-adi.test.sh ölçer (aynı derlem, aynı hüküm).
# KURAL (2.4.1, bağımsız göz tur 1: "tmux'un izin verdiği her ad"): 1-200 karakter · '.' ve ':' YOK (tmux bunları '_' yapar) ·
#   kontrol karakteri YOK (sekme/satır sonu — liste sekmeyle ayrılır) · BOŞLUK ARADA SERBEST (tmux 'a b' açar — ölçüldü), ama
#   başta/sonda YOK (kesilip başka ada dönüşür) · İLK karakter '$' '@' '%' '=' OLAMAZ: tmux hedefinde bunlar oturum/pencere/bölme
#   KİMLİĞİ ve tam-eşleşme önekidir — '$1' adlı koltuk '-t' ile başka oturuma çözülüyordu (ölçüldü).
#   Güvenlik yine tmux'un beyaz listesinden (var olan oturum) gelir; ad her yerde tırnaklı/kodlu taşınır.
KOLTUK_AD_DESEN='^[^[:cntrl:]:.]{1,200}$'
koltuk_adi_gecerli() {
  [[ "$1" =~ $KOLTUK_AD_DESEN ]] || return 1
  case "${1:0:1}" in [[:space:]]|'$'|'@'|'%'|'=') return 1 ;; esac
  case "${1: -1}" in [[:space:]]) return 1 ;; esac
  return 0
}
