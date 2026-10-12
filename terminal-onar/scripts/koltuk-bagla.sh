#!/usr/bin/env bash
# koltuk-bagla.sh — kutunun KOLTUKLARI (tmux oturumları) için tek kaynak.
#
#   koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk]   ttyd'nin çalıştırdığı komut (ttyd -a: adresteki
#                                                          ?arg=<koltuk> buraya SON argüman olarak eklenir)
#   koltuk-bagla.sh --liste                                görünür koltuklar, sekmeyle: ad · son-etkinlik(epoch) · claude(1|0) · tür(ajan|diger) · hâl
#                                                          (KOLTUK_ANA=<ana oturum> verilirse ana oturum 'ajan' sayılır)
#
# 🔴 NİÇİN TEK KAYNAK: "hangi oturum görünür" sorusunu hem ekran (ttyd) hem liste ucu (/api/koltuklar)
#    soruyor. İki ayrı liste yazılsaydı ilk değişiklikte ayrışırdı: listede görünmeyen bir oturuma adresle
#    girilebilir ya da listede görünen bir koltuk açılmazdı. Kapı bu betiğe SORAR, kendisi türetmez.
#
# 🔴 ADRES GÜVENİLMEZ GİRDİDİR. Bağlanılacak ad yalnız şu üç kapıdan geçerse kabul edilir:
#    (1) karakter kümesi dar (harf · rakam · _ -, en çok 64) — tmux hedef sözdizimi (: . = ^) giremez
#    (2) kutuda ŞU AN VAR olan bir oturum (beyaz liste = tmux'un kendi listesi; ad uydurulamaz)
#    (3) gizli değil (altyapı oturumları: ttyd · kapı · kurtarıcı · görsel dinleyici)
#    Kapıdan geçmeyen ad İÇİN YENİ OTURUM AÇILMAZ ve ana oturuma da sessizce düşülmez: kullanıcı yanlış
#    koltukta olduğunu sanmasın diye açık bir red basılır.
set -uo pipefail

gizli() { case "$1" in ttyd-*|kapi-*|*-kurtarici|imglistener*) return 0 ;; esac; return 1; }
gecerli_ad() { [[ "$1" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; }   # tmux oturum adında . ve : olamaz

# 🔴 ÖLÇEMEDİĞİNE "boş" DEMEZ (bağımsız göz, tur 3): tmux listesi ALINAMAZSA bu "0 koltuk" değil
#    "ölçülemedi"dir → rc=3. Tek istisna tmux sunucusunun hiç çalışmaması ("no server running"):
#    o kutuda gerçekten koltuk yoktur, boş liste doğrudur.
koltuklar() {  # görünür oturum adları, satır satır · rc 3 = ölçülemedi
  local ham hata
  if ! ham="$(tmux list-sessions -F '#{session_name}' 2>&1)"; then
    case "$ham" in *"no server running"*|*"No such file or directory"*) return 0 ;; esac
    printf 'koltuklar ölçülemedi: %s\n' "$ham" >&2; return 3
  fi
  printf '%s\n' "$ham" | while IFS= read -r s; do
    if [ -n "$s" ] && ! gizli "$s"; then printf '%s\n' "$s"; fi
  done
  return 0   # son satır gizliyse döngü 1 döner; o bir ölçüm hatası değil
}

claude_var_mi() {  # $1 = oturum → 0 ise koltukta Claude çalışıyor
  local pid kom
  while read -r pid kom; do
    case "$kom" in claude|claude-*) return 0 ;; esac
    pgrep -P "$pid" -f '(^|/)claude( |$)' >/dev/null 2>&1 && return 0
  done < <(tmux list-panes -s -t "=$1" -F '#{pane_pid} #{pane_current_command}' 2>/dev/null)
  return 1
}

# ── TÜR ve HÂL (2.2.0 · dilim 4, Sultan: "düzenli net sade"): ekran yalnız AJAN koltuklarını önde gösterir,
#    gerisi "diğer" altında katlanır; hâl noktası koltuk başına. İkisi de BURADA ölçülür (kapı sormakla yetinir).
#    tür  : ajan  = Claude çalışan oturum ya da ana oturum (<kutu>-ana) · diğer = geçici/arka plan (cc-* · dash* ·
#           imglistener* · *-kurtarici) ya da Claude'suz oturum
#    hâl  : son ekran satırlarından, filo yoklamasıyla AYNI desenler (Nexus scripts/filo.py hal()): sıra meşgul > soru >
#           sınır > girdi > boş; hiçbiri tutmazsa "bilinmiyor" (uydurulmaz). Claude'suz oturumun hâli "yok" (ölçülmez).
diger_mi() { case "$1" in cc-*|dash*|imglistener*|*-kurtarici) return 0 ;; esac; return 1; }
koltuk_turu() {  # $1 = oturum · $2 = claude(1|0) · $3 = ana(1|0)
  if diger_mi "$1"; then echo diger; elif [ "$2" = 1 ] || [ "$3" = 1 ]; then echo ajan; else echo diger; fi
}
koltuk_hali() {  # $1 = oturum → calisiyor|soru|sinirda|girdi|bos|bilinmiyor  (son 15 satır, boş satırlar atılır)
  local ekran
  ekran="$(tmux capture-pane -p -t "=$1" -S -15 2>/dev/null | sed '/^[[:space:]]*$/d')" || { echo bilinmiyor; return; }
  [ -n "$ekran" ] || { echo bilinmiyor; return; }
  if printf '%s' "$ekran" | grep -qiE 'esc to interrupt|esc to cancel\)|\([0-9]+s ·|Running…|Waiting…' && ! printf '%s' "$ekran" | grep -q 'Enter to select'; then echo calisiyor; return; fi
  if printf '%s' "$ekran" | grep -qE 'Enter to select|Do you want to|❯ [0-9]+\. '; then echo soru; return; fi
  if printf '%s' "$ekran" | grep -qiE 'usage limit|limit reached|5-hour limit'; then echo sinirda; return; fi
  local satir
  satir="$(printf '%s\n' "$ekran" | grep -E '^[[:space:]]*❯' | tail -1 | sed 's/^[[:space:]]*❯[[:space:]]*//')"
  if printf '%s\n' "$ekran" | grep -qE '^[[:space:]]*❯'; then
    if [ -n "$satir" ]; then echo girdi; else echo bos; fi; return
  fi
  echo bilinmiyor
}

if [ "${1:-}" = "--liste" ]; then
  LISTE="$(koltuklar)" || exit 3
  ANA_AD="${TO_ANA_TMUX:-${KOLTUK_ANA:-}}"
  printf '%s\n' "$LISTE" | while IFS= read -r s; do
    [ -n "$s" ] || continue
    son=$(tmux display-message -p -t "=$s" '#{session_activity}' 2>/dev/null || echo 0)
    if claude_var_mi "$s"; then c=1; else c=0; fi
    a=0; [ -n "$ANA_AD" ] && [ "$s" = "$ANA_AD" ] && a=1
    tur="$(koltuk_turu "$s" "$c" "$a")"
    if [ "$c" = 1 ]; then hal="$(koltuk_hali "$s")"; else hal=yok; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$s" "${son:-0}" "$c" "$tur" "$hal"
  done
  exit 0
fi

ANA="${1:?kullanım: koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk] | --liste}"
PROJE="${2:?proje dizini eksik}"
ISTEK="${3:-}"
# 🔴 Birden çok arg (?arg=X&arg=Y) ttyd'de birden çok argüman olur (canlı ölçüldü: ARGS=[X Y]).
#    Belirsiz adres SEÇİLMEZ, reddedilir — ilkini alıp gerisini yutmak sessiz bir karar olurdu.
COK_ARG=$(( $# > 3 ))

red() {
  printf '\r\n  \033[1;31m⛔ %s\033[0m\r\n' "$1"
  printf '  Görünür koltuklar: %s\r\n\r\n' "$(koltuklar | tr '\n' ' ')"
  exit 3
}

[ "$COK_ARG" = 1 ] && red "Adreste birden çok koltuk var; tek koltuk ver."
if [ -z "$ISTEK" ]; then
  # Argümansız: bugünkü davranış BAYT BAYT aynı — ana oturuma bağlan, yoksa aç.
  # 🔴 Yalnız ARGÜMANSIZ yol oturum YARATIR. Ana oturumun adı adresle açıkça verilirse o da
  #    öteki koltuklar gibi beyaz listeden geçer (bağımsız göz, tur 1: açık ad listeyi deliyordu).
  exec tmux new-session -A -s "$ANA" -c "$PROJE"
fi
gecerli_ad "$ISTEK" || red "Geçersiz koltuk adı."
gizli "$ISTEK" && red "Bu oturum bir koltuk değil (altyapı)."
# 🔴 Liste ÖNCE alınır: `koltuklar | grep -q` biçiminde grep erken çıkınca üretici SIGPIPE alır ve
#    pipefail altında var olan koltuk da "yok" sayılırdı (sınav A2 yakaladı).
LISTE="$(koltuklar)" || red "Koltuklar ölçülemedi (tmux listesi alınamadı) — bağlanmıyorum."
grep -qxF -- "$ISTEK" <<< "$LISTE" || red "Bu kutuda '$ISTEK' adlı bir koltuk yok."
# Telefon bağlanınca masaüstü kalıcı daralmasın (onar.sh'taki ana oturum ayarının aynısı).
for w in $(tmux list-windows -t "=$ISTEK" -F '#{window_id}' 2>/dev/null); do
  tmux set-option -w -t "$w" window-size latest 2>/dev/null || true
done
exec tmux attach-session -t "=$ISTEK"
