#!/usr/bin/env bash
# koltuk-bagla.sh — kutunun KOLTUKLARI (tmux oturumları) için tek kaynak.
#
#   koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk]   ttyd'nin çalıştırdığı komut (ttyd -a: adresteki
#                                                          ?arg=<koltuk> buraya SON argüman olarak eklenir)
#   koltuk-bagla.sh --liste                                görünür koltuklar, sekmeyle: ad · son-etkinlik(epoch) · claude(1|0)
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

koltuklar() {  # görünür oturum adları, satır satır
  tmux list-sessions -F '#{session_name}' 2>/dev/null | while IFS= read -r s; do
    [ -n "$s" ] && ! gizli "$s" && printf '%s\n' "$s"
  done
}

claude_var_mi() {  # $1 = oturum → 0 ise koltukta Claude çalışıyor
  local pid kom
  while read -r pid kom; do
    case "$kom" in claude|claude-*) return 0 ;; esac
    pgrep -P "$pid" -f '(^|/)claude( |$)' >/dev/null 2>&1 && return 0
  done < <(tmux list-panes -s -t "=$1" -F '#{pane_pid} #{pane_current_command}' 2>/dev/null)
  return 1
}

if [ "${1:-}" = "--liste" ]; then
  koltuklar | while IFS= read -r s; do
    son=$(tmux display-message -p -t "=$s" '#{session_activity}' 2>/dev/null || echo 0)
    if claude_var_mi "$s"; then c=1; else c=0; fi
    printf '%s\t%s\t%s\n' "$s" "${son:-0}" "$c"
  done
  exit 0
fi

ANA="${1:?kullanım: koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk] | --liste}"
PROJE="${2:?proje dizini eksik}"
ISTEK="${3:-}"

red() {
  printf '\r\n  \033[1;31m⛔ %s\033[0m\r\n' "$1"
  printf '  Görünür koltuklar: %s\r\n\r\n' "$(koltuklar | tr '\n' ' ')"
  exit 3
}

if [ -z "$ISTEK" ] || [ "$ISTEK" = "$ANA" ]; then
  # Bugünkü davranış BAYT BAYT aynı: ana oturuma bağlan, yoksa aç.
  exec tmux new-session -A -s "$ANA" -c "$PROJE"
fi
gecerli_ad "$ISTEK" || red "Geçersiz koltuk adı."
gizli "$ISTEK" && red "Bu oturum bir koltuk değil (altyapı)."
# 🔴 Liste ÖNCE alınır: `koltuklar | grep -q` biçiminde grep erken çıkınca üretici SIGPIPE alır ve
#    pipefail altında var olan koltuk da "yok" sayılırdı (sınav A2 yakaladı).
LISTE="$(koltuklar)"
grep -qxF -- "$ISTEK" <<< "$LISTE" || red "Bu kutuda '$ISTEK' adlı bir koltuk yok."
# Telefon bağlanınca masaüstü kalıcı daralmasın (onar.sh'taki ana oturum ayarının aynısı).
for w in $(tmux list-windows -t "=$ISTEK" -F '#{window_id}' 2>/dev/null); do
  tmux set-option -w -t "$w" window-size latest 2>/dev/null || true
done
exec tmux attach-session -t "=$ISTEK"
