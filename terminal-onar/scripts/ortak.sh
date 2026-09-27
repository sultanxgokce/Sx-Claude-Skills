# terminal-onar — ortak ayarlar ve ölçüm fonksiyonları (source edilir, tek başına koşmaz)
#
# Düzen: tmux `sedir-ana` (Sultan'ın konuşması, Claude) ← hem code-server terminali hem web
# terminali (ttyd, :7681 → sedir-terminal.mmepanel.com) AYNI oturuma bağlanır → birebir senkron.
# `sedir-kurtarici` ayrı bir Claude oturumudur; onarımın son kademesi.
#
# 🔴 Sır değeri hiçbir dosyaya, günlüğe, argv'ye YAZILMAZ. Parola kasadan (SEDIR__TERMINAL_SIFRE)
#    ortam değişkenine çekilir; ttyd onu kendi sürecinde okur.

# ── KUTU KİMLİĞİ — her şey buradan türer ─────────────────────────────────────
# 🔴 NİÇİN BÖYLE: bu beceri SEDİR kutusunda doğdu ve adlar oraya çivilenmişti
#    (`sedir-ana`, `kapi-sedir`, `SEDIR__TERMINAL_SIFRE`). Genelleştirirken her adı
#    ayrı ayrı ezilebilir yapmak da mümkündü — ama o zaman bir kutuyu kurmak ON ayrı
#    değişken doğru yazmayı gerektirirdi ve biri unutulduğunda kurulum SESSİZCE başka
#    kutunun adına bakardı. Tek kaynak: KUTU. Gerisi türetilir; yine de tek tek
#    ezilebilir kalır (deneme kopyası için).
KUTU="${TO_KUTU:-$(
  # 1) açık beyan · 2) çalışma alanının adı · 3) makine adı → hiçbiri yoksa BOŞ
  d="${TO_PROJE:-}"; [ -n "$d" ] && basename "$d" && exit 0
  for c in /config/projects/*/; do :; done
  hostname 2>/dev/null | sed 's/^cloudtop-//'
)}"
# Kutu adı ÇÖZÜLEMEZSE kurulum yapılmaz: yanlış kutunun adına yazmaktansa durmak yeğdir.
[ -n "${KUTU:-}" ] || { echo "terminal-onar: KUTU adı çözülemedi — TO_KUTU ver" >&2; return 1 2>/dev/null || exit 1; }
KUTU_BUYUK="$(printf '%s' "$KUTU" | tr '[:lower:]-' '[:upper:]_')"

PROJE="${TO_PROJE:-/config/projects/$KUTU}"
DURUM_DIZ="${TO_DURUM_DIZ:-/config/.terminal-onar}"
GUNLUK="$DURUM_DIZ/gunluk.log"
ANA_TMUX="${TO_ANA_TMUX:-$KUTU-ana}"
KURT_TMUX="${TO_KURT_TMUX:-$KUTU-kurtarici}"
TTYD_TMUX="${TO_TTYD_TMUX:-ttyd-$KUTU}"
KAPI_TMUX="${TO_KAPI_TMUX:-kapi-$KUTU}"
KAPI_PORT="${TO_KAPI_PORT:-7681}"
TTYD_SOKET="${TO_TTYD_SOKET:-${TO_DURUM_DIZ:-/config/.terminal-onar}/ttyd.sock}"
# Beceri GLOBAL dizinde yaşar (tek kopya, 14 kutuda ortak); kutu-yerel kopya varsa o kazanır.
BECERI_KOK="${TO_BECERI_KOK:-$(
  for d in "$PROJE/.claude/skills/terminal-onar" "/config/.claude/skills/terminal-onar"; do
    [ -d "$d" ] && { echo "$d"; break; }
  done
)}"
KAPI_DIZ="$BECERI_KOK/kapi"
TTYD_BIN="${TO_TTYD_BIN:-/config/.local/bin/ttyd}"
ENV_DOSYA="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
SIFRE_ANAHTAR="${TO_SIFRE_ANAHTAR:-${KUTU_BUYUK}__TERMINAL_SIFRE}"
BETIK_DIZ="$BECERI_KOK/scripts"
ANA_AD="${TO_ANA_AD:-$KUTU-yon}"
KURT_AD="${TO_KURT_AD:-$KUTU-kurtarici}"

# ── TABAN YOLU — merkez sayfanın ön şartı ────────────────────────────────────
# Merkez (terminal.mmepanel.com) kutuları YOL ile ayırır: /sedir/ · /akar/ …
# Kapı ve ttyd bu tabanı bilmek zorunda, yoksa döndürdükleri mutlak yollar merkeze
# gider ve kutuya hiç ulaşmaz. Boş bırakılırsa bugünkü kök-yol davranışı aynen sürer.
TABAN="${TO_TABAN:-/$KUTU}"
case "$TABAN" in /) TABAN="" ;; */) TABAN="${TABAN%/}" ;; esac
BELLEK_ENV="NODE_OPTIONS=--max-old-space-size=3072 MALLOC_ARENA_MAX=2"

export TZ=Europe/Istanbul  # cron UTC koşar; günlük yerel saatle yazılsın
# cron'un çıplak PATH'i claude'u bulamaz
# 🔴 NODE YOLU DİNAMİK BULUNUR — sürüm elle yazılıydı ve SEDİR bunu kendi dersinde
#    "beceride dinamik bulunmalı" diye işaretlemişti. Elle yazılan sürüm, node
#    yükseltildiği gün cron'u SESSİZCE öldürür: bekçi koşar, claude bulunamaz, iş yapmaz.
_node_yolu() {
  local d; d="$(command -v node 2>/dev/null)" && { dirname "$d"; return 0; }
  for d in /config/.nvm/versions/node/*/bin; do [ -x "$d/node" ] && { echo "$d"; return 0; }; done
  return 1
}
export PATH="$(_node_yolu 2>/dev/null):/config/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
mkdir -p "$DURUM_DIZ" 2>/dev/null

gunluk() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$GUNLUK"; }

tmux_var() { tmux has-session -t "=$1" 2>/dev/null; }

# Bir tmux oturumunda CANLI Claude var mı → sessionId basar (yoksa RC=1).
# 🔴 Birincil kanıt SÜREÇ AĞACIDIR: oturumun bir panesinin altında `claude` süreci var mı.
#    Oturum kaydı (~/.claude/sessions/<pid>.json) yalnız KİMLİK için okunur — 26 Eylül'de canlı
#    konuşmanın kaydı diskte YOKTU; kayda güvenen eski sürüm konuşmayı "kapalı" sanıp yeniden-açma
#    komutunu canlı konuşmanın İÇİNE yazdı.
claude_pid() {  # $1 = tmux oturumu → ilk canlı claude sürecinin pid'i
  local pp c
  for pp in $(tmux list-panes -s -t "=$1" -F '#{pane_pid}' 2>/dev/null); do
    for c in $(pgrep -P "$pp" 2>/dev/null); do
      tr '\0' ' ' < "/proc/$c/cmdline" 2>/dev/null | grep -qE '(^|/)claude( |$)' && { echo "$c"; return 0; }
    done
    # pane doğrudan claude ise (tmux new-session "claude …")
    tr '\0' ' ' < "/proc/$pp/cmdline" 2>/dev/null | grep -qE '(^|/)claude( |$)' && { echo "$pp"; return 0; }
  done
  return 1
}
claude_oturumu() {  # canlıysa sessionId basar ("?" = canlı ama kimlik bilinmiyor), değilse RC=1
  local tm="$1" pid f id=""
  pid=$(claude_pid "$tm") || return 1
  f="$HOME/.claude/sessions/$pid.json"
  [ -f "$f" ] && id=$(jq -r '.sessionId // empty' "$f" 2>/dev/null)
  [ -z "$id" ] && id=$(tr '\0' ' ' < "/proc/$pid/cmdline" | grep -oE -- '--resume [0-9a-f-]{36}' | awk '{print $2}')
  echo "${id:-?}"; return 0
}

# sessionId başka bir yerde (başka tmux/pencere) canlı mı?
oturum_canli_mi() {
  local id="$1" f pid
  for f in "$HOME"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    [ "$(jq -r '.sessionId' "$f" 2>/dev/null)" = "$id" ] || continue
    pid=$(jq -r '.pid' "$f"); kill -0 "$pid" 2>/dev/null && return 0
  done
  # kayıt yoksa süreç satırına bak: `claude --resume <id>` çalışıyor mu
  pgrep -u "$(id -u)" -f -- "claude .*--resume $id" >/dev/null && return 0
  return 1
}

# ttyd yalnız UNIX soketinde (TCP portu yok); kapı :7681'de, girişi o yapar.
ttyd_kod() { curl -s -o /dev/null -m 4 -w '%{http_code}' --unix-socket "$TTYD_SOKET" "http://localhost$TABAN/tty/" 2>/dev/null; }
kapi_kod() { curl -s -o /dev/null -m 4 -w '%{http_code}' "http://127.0.0.1:$KAPI_PORT$TABAN/giris" 2>/dev/null; }
kapi_saglam() { [ "$(kapi_kod)" = "200" ] && [ "$(curl -s -o /dev/null -m 4 -w '%{http_code}' "http://127.0.0.1:$KAPI_PORT$TABAN/")" = "302" ]; }

ttyd_saglam() { [ "$(ttyd_kod)" = "200" ]; }

bekci_kurulu() { crontab -l 2>/dev/null | grep -q '# terminal-onar-bekci'; }
# Kapı ve ttyd TABAN'ı ortamdan okur; tek yerden verilir ki ikisi ayrışmasın.
export KAPI_TABAN="$TABAN"

# Parola kutu-bağımsız okunur: anahtar adı KUTU'dan türer (SEDIR__… · AKAR__…).
# 🔴 Değer hiçbir zaman argv'ye, günlüğe ya da tmux komutuna girmez — kasadan ortam
#    değişkenine çekilir, kapıyı başlatan kabuk onu dosyadan kendisi okur.
sifre_var_mi() { [ -n "$(eval "printf '%s' \"\${$SIFRE_ANAHTAR:-}\"")" ]; }
sifre_yukle() {
  sifre_var_mi && return 0
  if [ -f "$ENV_DOSYA" ]; then set -a; . "$ENV_DOSYA"; set +a; fi
  sifre_var_mi && return 0
  bash /config/.claude/skills/vault-cek/scripts/vault-cek.sh get "$SIFRE_ANAHTAR" >/dev/null 2>&1 || return 1
  set -a; . "$ENV_DOSYA"; set +a
  sifre_var_mi
}

haber() {  # Sultan'a WhatsApp — başarısızlık onarımı durdurmaz
  bash /config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh --kime Sultan "$*" >/dev/null 2>&1 \
    || gunluk "uyari: whatsapp haberi gitmedi"
}
