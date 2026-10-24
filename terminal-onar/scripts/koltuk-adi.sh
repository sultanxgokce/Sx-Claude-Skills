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
  # Sayım KARAKTER (kod noktası) olmalı — kapı JS'te /u ile aynısını yapar. Yerel ayar C ise bash BAYT sayar ('ş😀' = 6, ölçüldü)
  # ve iki dil ayrışır (bağımsız göz tur 2) → eşleme her zaman UTF-8 yerel ayarında yapılır.
  local LC_ALL=C.UTF-8
  [[ "$1" =~ $KOLTUK_AD_DESEN ]] || return 1
  case "${1:0:1}" in [[:space:]]|'$'|'@'|'%'|'=') return 1 ;; esac
  case "${1: -1}" in [[:space:]]) return 1 ;; esac
  return 0
}

# ── AD DIŞI KİMLİK (2.24.0 · P4GT2W): adreste ad yerine taşınan kimlik. Mahrem kutuda oturum adı müvekkil adıdır;
#    'Aç' adresine (?arg=) giderse fareyle üstüne gelince, geçmişte ve kayıtlarda görünür. Kimlik = 'k' + sha256(tuz \n ad)'ın
#    ilk 16 onaltılığı; TUZ kutuya özel ve gizlidir (yoksa ad listesi olan biri kimliği deneyerek adı bulurdu).
#    Kapı (kapi/koltuk-kimlik.mjs) aynı formülü taşır — eşdeğerliği koltuk-kimlik.test.sh ölçer.
KOLTUK_KIMLIK_DESEN='^k[0-9a-f]{16}$'
koltuk_tuz_yolu() { printf '%s' "${KOLTUK_TUZ:-$HOME/.koltuk-tuz}"; }
koltuk_tuz() {  # tuzu basar; yoksa ATOMİK yaratır (ln: iki süreç aynı anda yaratırsa ikisi de AYNI dosyayı okur) · rc 1 = yaratılamadı
  local y g; y="$(koltuk_tuz_yolu)"
  if [ ! -s "$y" ]; then
    g="$(umask 077; mktemp "$y.XXXXXX")" || return 1
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$g" && ln "$g" "$y" 2>/dev/null; rm -f "$g"
  fi
  [ -s "$y" ] || return 1
  head -c 64 "$y"
}
koltuk_kimlik() {  # <ad> → kimlik · rc 1 = tuz yok (kimlik UYDURULMAZ)
  local t; t="$(koltuk_tuz)" || return 1
  printf 'k%s' "$(printf '%s\n%s' "$t" "$1" | sha256sum | cut -c1-16)"
}
