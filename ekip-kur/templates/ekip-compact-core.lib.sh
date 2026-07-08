#!/usr/bin/env bash
# ekip-compact-core.lib.sh — compact-sürücü ÇEKİRDEĞİ (öz-servis ekip-selfcompact.sh + uzaktan ORTAK).
#   DRY: drive-mantığı tek-kaynak. TUI-jenerik; herhangi bir tmux-tabanlı Claude-oturumunu compact eder.
# Sağlar:
#   _snap TARGET            — scrollback yakalama (marker-arama)
#   _vis  TARGET            — görünür-tail (CANLI-durum)
#   _wait_idle TARGET TMO   — pane görünür-durumu idle olana dek bekle (0=idle · 1=timeout)
#   _wait_quiescent TARGET TMO — tetik-turu bitti mi (SAKİN=idle YA DA compact; busy/menu reddet)
#   _compact_drive TARGET MID DEVAM RE — /compact-gönder→settle→devam+nonce→marker-verify
#     Exit: 0=doğrulandı · 1=send-fail · 5=tetiklendi-ama-doğrulanmadı · 6=settle-takıldı(hard-stop)
#
# BAKED-IN DERSLER (firsthand, go-live'da doğrulandı):
#   • /compact tmux-scrollback'i TEMİZLEMEZ → settle=GÖRÜNÜR-tail idle · verify=NONCE-çapa sonrası satırlar.
#   • bare-word 'compact' COMPACTING_RE'de YASAK (gönderilen /compact + iş-metni false-match → hard-stop).
#   • gerçek büyük-ctx compaction >2dk (ölçüm 2m25s@80%) → SETTLE_TIMEOUT=300.
#   • /compact TEK-başına asistan-turu ÜRETMEZ → devam-nudge re-bootstrap turunu tetikler; marker ONDAN SONRA.
# Değişmez: salt tmux-tetik + capture-poll (salt-oku) · sır-değer TAŞIMAZ · insan-onay-alanı YAZMAZ.
#
# NOT: bu lib source edilir — `set -e` KOYMA (çağıranı etkiler); açık return ile akış.

# Tunable defaults — çağıran env/pre-set ile override edebilir (: ile yalnız-boşsa ata).
: "${COMPACTING_RE:=Compacting|Summarizing conversation}"
: "${SETTLE_TIMEOUT:=300}"
: "${VERIFY_TIMEOUT:=90}"
: "${POLL:=3}"
: "${SCROLLBACK:=-200}"

_snap() { tmux capture-pane -p -t "$1" -S "$SCROLLBACK" 2>/dev/null || true; }
_vis()  { tmux capture-pane -p -t "$1" 2>/dev/null | tail -25 || true; }

# _wait_idle TARGET TIMEOUT — görünür-durum idle VE compaction-status yok olana dek bekle (settle-fazı: KATı idle).
_wait_idle() {
  local target="$1" timeout="${2:-$SETTLE_TIMEOUT}" waited=0 st
  while :; do
    st=idle
    if declare -F preflight_state >/dev/null; then st="$(preflight_state "$target")"; fi
    if [ "$st" = idle ] && ! _vis "$target" | grep -qE "$COMPACTING_RE"; then return 0; fi
    [ "$waited" -ge "$timeout" ] && return 1
    sleep "$POLL"; waited=$((waited+POLL))
  done
}

# _wait_quiescent TARGET TIMEOUT — tetik-turu bitti mi (SAKİN=idle YA DA compact, yalnız busy/menu reddet).
#   ⚠️ init-idle-wait NEDEN gevşek: self-compact tetik-mesajı 'compact' kelimeleri içerir → preflight pane'i
#   'compact' sınıflar (asla 'idle' değil) → KATı _wait_idle sonsuza bekleyip abort eder (firsthand: bir üye
#   06:18→06:23 init-idle-timeout deadlock). idle+compact ikisi de 'tur-bitti/güvenli-devam' demek.
_wait_quiescent() {
  local target="$1" timeout="${2:-$SETTLE_TIMEOUT}" waited=0 st
  while :; do
    st=idle
    if declare -F preflight_state >/dev/null; then st="$(preflight_state "$target")"; fi
    if { [ "$st" = idle ] || [ "$st" = compact ]; } && ! _vis "$target" | grep -qE "$COMPACTING_RE"; then return 0; fi
    [ "$waited" -ge "$timeout" ] && return 1
    sleep "$POLL"; waited=$((waited+POLL))
  done
}

# _compact_drive TARGET MID DEVAM REBOOTSTRAP_RE
#   Önkoşul: TARGET pane şu an /compact-alabilir durumda (çağıran preflight/idle-bekle ile garanti eder).
_compact_drive() {
  local target="$1" mid="$2" devam="$3" re="$4"

  # --- 3 · /compact gönder (3-adım: C-u / metin / 0.4s / Enter — gömülü-Enter TUI'de submit ETMEZ) ---
  echo "→ /compact gönderiliyor: $mid ($target)"
  tmux send-keys -t "$target" C-u 2>/dev/null || true
  tmux send-keys -t "$target" -- "/compact" 2>/dev/null || { echo "HATA: send-keys başarısız ($target)" >&2; return 1; }
  sleep 0.4
  tmux send-keys -t "$target" Enter 2>/dev/null || true

  # --- 4 · SETTLE (ilk-nefes → görünür-tail idle-bekle; timeout→hard-stop) ---
  echo "→ compaction bekleniyor (settle ≤${SETTLE_TIMEOUT}sn)…"
  sleep "$POLL"   # ilk-nefes: compaction başlasın (pre-compaction idle'ı yanlış-settle etme)
  if ! _wait_idle "$target" "$SETTLE_TIMEOUT"; then
    echo "HARD-STOP: $mid ${SETTLE_TIMEOUT}sn'de idle'a dönmedi — devam GÖNDERMİYORUM (mid-work metin-kaybı riski)." >&2
    return 6
  fi
  echo "→ compaction bitti (durum=idle)"

  # --- 5 · DEVAM + benzersiz-çapa (turu-tetikler → SessionStart-identity enjekte-olmuş üye marker'ı basar) ---
  local nonce="[[rb$$]]"
  echo "→ devam-nudge gönderiliyor (çapa=$nonce; re-bootstrap turunu tetikler)"
  tmux send-keys -t "$target" C-u 2>/dev/null || true
  tmux send-keys -t "$target" -- "$devam $nonce" 2>/dev/null || { echo "HATA: devam send-keys başarısız" >&2; return 5; }
  sleep 0.4
  tmux send-keys -t "$target" Enter 2>/dev/null || true

  # --- 6 · MARKER-DOĞRULA (nonce-çapasından SONRA marker; timeout-DÜRÜST: yoksa başarı İDDİA ETME) ---
  echo "→ re-bootstrap doğrulanıyor (marker ≤${VERIFY_TIMEOUT}sn, çapa-sonrası)…"
  local found=0 waited=0
  while :; do
    if _snap "$target" | awk -v a="$nonce" -v re="$re" '
         index($0,a){seen=1; next}
         seen && $0 ~ re {f=1; exit}
         END{exit !f}'; then found=1; break; fi
    [ "$waited" -ge "$VERIFY_TIMEOUT" ] && break
    sleep "$POLL"; waited=$((waited+POLL))
  done

  if [ "$found" -eq 1 ]; then
    echo "✓ $mid compact + re-bootstrap DOĞRULANDI (marker görüldü, ${waited}sn) — kimlik-korunmuş devam etti."
    return 0
  else
    echo "✗ $mid: /compact tetiklendi + devam gönderildi AMA re-bootstrap marker'ı ${VERIFY_TIMEOUT}sn'de GÖRÜLMEDİ." >&2
    echo "  → başarı İDDİA ETMİYORUM; pane'e bak / marker'ı REBOOTSTRAP_RE ile kalibre et." >&2
    return 5
  fi
}
