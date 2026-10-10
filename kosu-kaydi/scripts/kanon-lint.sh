#!/usr/bin/env bash
# kanon-lint.sh — kutu kanonundaki (ya da canlı crontab'daki) SARILI satırları denetler. Şema K4b "kanon lint'i … kırmızı yapar"
# diyordu ama lint yoktu (A309). NÂZIR'ın nazir ölçümlerinden doğan kurallar (9-10 Eki 2026):
#   K1 KIRMIZI  --kilit <dosya> ile sarılı satırın komut kısmında hâlâ flock var → iç kilit ebeveynin kilidine çarpar,
#               HER koşu atlandi-kilit yazar, iş hiç koşmaz (sessiz; kokpitte "kilit dolu" sanılır) — SEYYAH fikstürü
#   K2 SARI     sarılı satırda flock -n var ama --kilit yok → kilit/hata ayrımı yok (şema K4b)
#   K3 KIRMIZI  sarılı satırda sahip etiketi yok: ne satır üstü '# sahip:' ne satır sonu 'sahip:<ROL>' (şema K3)
#   K4 KIRMIZI  aynı iş adı birden çok sarılı satırda → ikileme (elle kurulan satır kanona da yazılınca restart'ta iki kez koşar)
#   K5 SARI     crontab başına 'KOSU_KUTU=' / 'KOSU_KANON=' ortam satırı → oda kancası (36-oda-cron gecerli()) kabul etmiyor,
#               recreate'te kaybolur; değişkenler satır içinde verilir (A313)
#   K6 SARI     --gozlem "<komut>" verilmiş ama komutun ilk kelimesi bu kutuda yok (ss nazir'de yoktu) → her koşu olculemedi olur;
#               yalnız kutu içinde anlamlı: --kutu-ici verilmezse bakılmaz (başka kutunun kanonunu merkezden okurken yanlış sarı olmasın)
#   K7 SARI     (yalnız --kanon <dosya> ile; girdi = CANLI crontab) zamanlı satır canlıda var kanonda yok ("kanon dışı": elle
#               kurulmuş, recreate'te kaybolur) ya da kanonda var canlıda yok (kanca indirmemiş). nazir'de canlı 7 / kanon 5 farkını
#               0.5.1 görmüyordu: iki federe flock satırı hiç anılmadı (A320, NÂZIR). Karşılaştırma tam satırdır (sekme/çoklu boşluk tek boşluk).
#   K8 SARI     sarılmamış zamanlı satırda flock var → kilitli iş kayıt dışı: atlandı mı, koştu mu hiçbir yerde görünmez (A320);
#               kosu-sar --kilit ile sarılması önerilir. Sarılı satırdaki flock K1/K2'nin konusudur, K8 değil.
# Kullanım: kanon-lint.sh <kanon-dosyası|-> [--kutu-ici] [--kanon <dosya>]   ('-' = stdin, ör. crontab -l | kanon-lint.sh - --kanon <kanon>)
# rc: 0 temiz ya da yalnız sarı · 1 kırmızı var · 2 kullanım · 3 ölçülemedi (dosya yok/okunamadı)
set -uo pipefail
KUL="kullanım: kanon-lint.sh <dosya|-> [--kutu-ici] [--kanon <dosya>]"
G="${1:-}"; shift || true; KUTU_ICI=0; KARSI=""
while [ $# -gt 0 ]; do case "$1" in
  --kutu-ici) KUTU_ICI=1;;
  --kanon) KARSI="${2:-}"; [ -n "$KARSI" ] || { echo "$KUL (--kanon dosya ister)" >&2; exit 2; }; shift;;
  *) echo "$KUL" >&2; exit 2;; esac; shift; done
[ -n "$G" ] || { echo "$KUL" >&2; exit 2; }
if [ "$G" = "-" ]; then ICERIK="$(cat)" || { echo "olculemedi: stdin okunamadı"; exit 3; }
else [ -r "$G" ] || { echo "olculemedi: dosya yok ya da okunamıyor: $G"; exit 3; }; ICERIK="$(cat "$G")"; fi
KIRMIZI=0; SARI=0; SARILI=0
zamanli() { printf '%s' "$1" | grep -qE '^[[:space:]]*[0-9*@]'; }       # cron zaman ifadesiyle başlayan satır
duz() { printf '%s' "$1" | tr '\t' ' ' | sed -E 's/ +/ /g; s/^ //; s/ $//'; }   # karşılaştırma biçimi: sekme/çoklu boşluk tek boşluk
dogrudan_sarili() {  # <zamanlı satır> → rc 0: cron'un çalıştırdığı program SARMALAYICININ KENDİSİ (yapısal; alt dizge değil — bağımsız göz tur 2)
  # zaman alanları (5 ya da @ifade) atlanır, baştaki VAR=değer atamaları ve bash/sh yorumlayıcısı geçilir; ilk program kosu-sar.sh olmalı.
  # 'flock -n x bash kosu-sar.sh …' (kilit sarmalayıcının DIŞINDA) ya da 'bash -c "echo kosu-sar.sh; flock …"' sarılı SAYILMAZ.
  python3 -c 'import shlex,sys,re,os
s=sys.argv[1].split(" #")[0]
try: t=shlex.split(s)
except Exception: t=s.split()
t=t[1:] if t and t[0].startswith("@") else t[5:]
while t and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=",t[0]): t=t[1:]
if t and os.path.basename(t[0]) in ("bash","sh"): t=t[1:]
sys.exit(0 if t and os.path.basename(t[0])=="kosu-sar.sh" else 1)' "$1" 2>/dev/null
}
declare -A KANON_SATIR=() CANLI_SATIR=()
if [ -n "$KARSI" ]; then   # K7: karşı kanonun zamanlı satırları (kanon dosyası okunamıyorsa hüküm yok → rc 3, temiz denmez)
  [ -r "$KARSI" ] || { echo "olculemedi: kanon dosyası yok ya da okunamıyor: $KARSI"; exit 3; }
  kn=0; while IFS= read -r k || [ -n "$k" ]; do kn=$((kn+1)); zamanli "$k" && KANON_SATIR["$(duz "$k")"]="$kn"; done < "$KARSI"
fi
bul() { # bul <renk> <kural> <satır no> <mesaj>
  if [ "$1" = K ]; then KIRMIZI=$((KIRMIZI+1)); printf '✗ KIRMIZI %s satır %s: %s\n' "$2" "$3" "$4"
  else SARI=$((SARI+1)); printf '△ SARI    %s satır %s: %s\n' "$2" "$3" "$4"; fi
}
flock_nonblock() {  # <komut metni> → komut parçasındaki flock çağrısının KENDİ seçeneklerinde nonblock var mı (rc 0 var)
  local seg="$1" tok deger=0 tokens
  seg="${seg#*flock}"; [ "$seg" = "$1" ] && return 1              # flock yok
  case "$1" in *[[:space:]\;\&\|/]flock*|flock*) ;; *) return 1 ;; esac   # 'flock' bir belirteç başlangıcı olmalı
  # kabuk alıntıları korunur (flock -c 'grep -n …' /x.lock: alıntının içindeki -n flock seçeneği DEĞİL) — bağımsız göz -k2 tur 2;
  # python3 beceri ön koşuludur; alıntı bozuksa (shlex hata) boşluk bölmesine düşülür
  tokens="$(python3 -c 'import shlex,sys
try: print("\n".join(shlex.split(sys.argv[1])))
except Exception: print("\n".join(sys.argv[1].split()))' "$seg" 2>/dev/null)" || tokens="$(printf '%s\n' $seg)"
  while IFS= read -r tok; do [ -n "$tok" ] || continue
    if [ "$deger" -eq 1 ]; then deger=0; continue; fi               # önceki seçeneğin ayrı değeri
    case "$tok" in
      -n|--nonblock|--nb) return 0 ;;
      -E|-w|-c|--conflict-exit-code|--timeout|--command) deger=1 ;;   # değer alan seçenekler (ayrı belirteç)
      -E*|-w*|-c*|--conflict-exit-code=*|--timeout=*|--command=*) ;;  # bitişik değer
      -*) ;;                                                      # başka bayrak (-s, -x, -u, -o, -F, -e, --verbose…)
      *) return 1 ;;                                              # ilk seçenek-dışı belirteç = kilit dosyası → tarama biter
    esac
  done <<< "$tokens"; return 1
}
declare -A IS_SATIR=()
n=0; onceki=""; BLOK_SAHIP=0
while IFS= read -r ham || [ -n "$ham" ]; do
  n=$((n+1)); satir="$(printf '%s' "$ham" | tr '\t' ' ')"   # crontab alan ayracı sekme de olabilir: ayrıştırma boşlukla (bağımsız göz tur 1)
  case "$satir" in
    KOSU_KUTU=*|KOSU_KANON=*) bul S K5 "$n" "ortam satırı ($(printf '%s' "$satir" | cut -d= -f1)) — oda kancası bu satırı canlıya taşımaz, recreate'te kaybolur; değişkeni sarılı satırın içine taşı" ;;
  esac
  # bitişik yorum bloğu izi: '# sahip: <değer>' görüldü mü; yorum olmayan satır bloğu kapatır (satır işlendikten sonra sıfırlanır)
  if printf '%s' "$satir" | grep -qE '^[[:space:]]*#'; then printf '%s' "$satir" | grep -qE '^[[:space:]]*#[[:space:]]*sahip:[[:space:]]*[^[:space:]]' && BLOK_SAHIP=1; fi
  if zamanli "$satir"; then
    d="$(duz "$satir")"; CANLI_SATIR["$d"]="$n"
    [ -n "$KARSI" ] && [ -z "${KANON_SATIR[$d]:-}" ] && bul S K7 "$n" "kanon dışı: canlıda var, kanonda yok — elle kurulmuş, recreate'te kaybolur; ya kanona yaz ya kaldır"
    # satır sonu yorumu (' # …') K8'e girmez: '# flock burada kullanılmaz' sahte sarı üretmesin (bağımsız göz tur 1)
    if ! dogrudan_sarili "$satir" && printf '%s' "$satir" | sed -E 's/[[:space:]]#.*$//' | grep -qE '(^|[[:space:];&|])(/[^[:space:]]*/)?flock([[:space:]]|$)'; then
      bul S K8 "$n" "sarılmamış kilitli iş (flock) — atlandı mı koştu mu kayıtta görünmez; kosu-sar --kilit <dosya> ile sar"; fi
  fi
  if printf '%s' "$satir" | grep -qE '^[[:space:]]*[0-9*@]' && printf '%s' "$satir" | grep -qE 'kosu-sar\.sh[[:space:]]'; then   # boşluk YA DA sekme (crontab ikisini de ayraç sayar)
    SARILI=$((SARILI+1))
    is="$(printf '%s' "$satir" | sed -nE 's/.*kosu-sar\.sh[[:space:]]+([a-z0-9-]+).*/\1/p')"
    sarmal="${satir%% -- *}"; komut="${satir#* -- }"; [ "$komut" = "$satir" ] && komut=""
    # sahip: satır üstü '# sahip:' (hemen önceki yorum satırı) ya da satır sonu 'sahip:<ROL>'
    # iki biçimde de etiketin DEĞERİ olmalı: boş '# sahip:' etiket değildir (bağımsız göz tur 1). Satır üstü = hemen üstteki
    # BİTİŞİK yorum bloğunun herhangi bir satırı (sarmalayıcı _kanon_oku da bloğun tamamını okur; '# damga:' araya girebilir)
    if ! printf '%s' "$satir" | grep -qE '#.*sahip:[^[:space:]]+' && [ "$BLOK_SAHIP" -eq 0 ]; then
      bul K K3 "$n" "sahip etiketi yok (iş: ${is:-?}) — satır sonuna '# ${is:-<is>} sahip:<ROL>' ekle"; fi
    # flock çıplak ya da mutlak yollu (/usr/bin/flock) olabilir — ikisi de yakalanır (bağımsız göz tur 2)
    if printf '%s' "$sarmal" | grep -q -- '--kilit' && printf '%s' "$komut" | grep -qE '(^|[[:space:];&|])(/[^[:space:]]*/)?flock([[:space:]]|$)'; then
      bul K K1 "$n" "--kilit VE komut içinde flock (iş: ${is:-?}) — iç kilit ebeveynin kilidine çarpar, iş HİÇ koşmaz (iç flock -E 75 ise sahte atlandi-kilit, değilse her koşu hata); önce içteki flock kalkar"; fi
    # -n flock'tan hemen sonra olmayabilir (flock -E 75 -n …, flock -w 0 -n …, --nonblock): araya giren seçeneklere izin ver (bağımsız göz -son tur 3)
    # nonblock bayrağı flock'un KENDİ seçenekleri arasında aranır: flock'tan sonra belirteçler okunur, '-' ile başlayanlar seçenektir
    # (-E/-w/-c değer alır, ayrı belirteç ya da bitişik), ilk seçenek-dışı belirteç kilit dosyasıdır ve tarama orada biter —
    # çalıştırılan komutun kendi '-n'si (flock /x.lock grep -n …) K2 değildir (bağımsız göz -k2 tur 1)
    if ! printf '%s' "$sarmal" | grep -q -- '--kilit' && flock_nonblock "$komut"; then
      bul S K2 "$n" "flock -n sarmalayıcının İÇİNDE (iş: ${is:-?}) — kilit/hata ayrımı yok; --kilit <dosya>'ya taşı"; fi
    if [ -n "$is" ]; then
      if [ -n "${IS_SATIR[$is]:-}" ]; then bul K K4 "$n" "iş '$is' ikinci kez sarılı (ilk: satır ${IS_SATIR[$is]}) — ikileme; restart'ta iki kez koşar"
      else IS_SATIR[$is]="$n"; fi
    fi
    if [ "$KUTU_ICI" -eq 1 ] && printf '%s' "$sarmal" | grep -q -- '--gozlem'; then
      gk="$(printf '%s' "$sarmal" | sed -nE "s/.*--gozlem[[:space:]]+(\"([^\"]*)\"|'([^']*)'|([^[:space:]]+)).*/\2\3\4/p" | awk '{print $1}')"
      if [ -n "$gk" ] && ! command -v "$gk" >/dev/null 2>&1; then bul S K6 "$n" "gözlem komutu '$gk' bu kutuda yok (iş: ${is:-?}) — her koşu olculemedi olur"; fi
    fi
  fi
  onceki="$satir"; printf '%s' "$satir" | grep -qE '^[[:space:]]*#' || BLOK_SAHIP=0   # yorum dışı satır bloğu kapatır
done <<< "$ICERIK"
if [ -n "$KARSI" ]; then   # K7 öbür yön: kanonda olup canlıda olmayan zamanlı satır (satır no kanondaki)
  for k in "${!KANON_SATIR[@]}"; do [ -n "${CANLI_SATIR[$k]:-}" ] || bul S K7 "kanon:${KANON_SATIR[$k]}" "kanonda var, canlıda yok — kanca indirmemiş; oda kancasını koştur"; done
fi
printf '── sarılı satır: %s · kırmızı: %s · sarı: %s%s%s\n' "$SARILI" "$KIRMIZI" "$SARI" "$([ "$KUTU_ICI" -eq 1 ] || printf ' · (K6 gözlem komutu bakılmadı: --kutu-ici yok)')" "$([ -n "$KARSI" ] && printf ' · kanonla karşılaştırıldı' || printf ' · (K7 kanon farkı bakılmadı: --kanon yok)')"
[ "$KIRMIZI" -eq 0 ] || exit 1; exit 0
