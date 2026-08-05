#!/usr/bin/env bash
# ekip-selfcompact-watcher.sh — ÖZ-SERVİS compact'in DETACHED sürücüsü (ekip-selfcompact.sh spawn eder).
#   Ajanın compaction'ından BAĞIMSIZ yaşar (setsid child). Girdi = SC_* env-var'ları (sır-değer YOK).
#   Akış: (1) tetik-turu idle olana dek bekle → (2) TAZE /compact-drive (queue-survival gambit YOK).
#   Neden ayrı-süreç: /compact ajanın Claude-context'ini compact'ler; watcher sibling-proses olduğundan sağ-kalır
#     ve compaction bitince devam-nudge'u enjekte eder (aksi halde /compact tek-başına asistan-turu üretmez).
# Değişmez: send-keys script-içi (hook-clean) · salt tmux-tetik+poll · sonuç ekip-sinyal.log'a AUDIT.
set -uo pipefail

: "${SC_SCRIPT_DIR:?SC_SCRIPT_DIR gerekli}"
: "${SC_CORE_LIB:?SC_CORE_LIB gerekli}"
: "${SC_TARGET:?SC_TARGET gerekli}"
: "${SC_MID:?SC_MID gerekli}"
SC_PREFLIGHT_LIB="${SC_PREFLIGHT_LIB:-}"
SC_SINYAL="${SC_SINYAL:-}"
SC_DEVAM="${SC_DEVAM:-compact tamam — son-KONUM/checkpoint dosyanı oku, kimliğinle kaldığın-işe devam et.}"
SC_RE="${SC_RE:-${SC_MID} geri-yüklendi|${EKIP_REBOOTSTRAP_MARKER:-geri-yüklendi}}"
SC_INIT_IDLE="${SC_INIT_IDLE:-300}"

# shellcheck source=/dev/null
[ -n "$SC_PREFLIGHT_LIB" ] && [ -f "$SC_PREFLIGHT_LIB" ] && . "$SC_PREFLIGHT_LIB"
# shellcheck source=/dev/null
. "$SC_CORE_LIB"

audit() {
  [ -n "$SC_SINYAL" ] || return 0
  printf '%s SELFCOMPACT %s %s\n' "$(date -u +%FT%TZ 2>/dev/null || echo now)" "$SC_MID" "$1" >> "$SC_SINYAL" 2>/dev/null || true
}

audit "SPAWN watcher-basladi (init-idle-bekle ≤${SC_INIT_IDLE}s)"

# --- 1 · TETİK-TURU'nun bitmesini bekle (pane idle) — TAZE /compact için (çalışan-tura queue YOK) ---
#   Ajan `ekip-selfcompact.sh` koşup turu-bitirince pane idle olur → watcher devreye girer.
#   Ajan çalışmaya devam ederse watcher bekler (mid-work compact ETMEZ = güvenli).
if ! _wait_quiescent "$SC_TARGET" "$SC_INIT_IDLE"; then
  audit "ABORT init-idle-timeout(${SC_INIT_IDLE}s) — ajan turu bitmedi (busy/menu), compact ETMEDİM"
  exit 0
fi

# --- 2 · DRIVE-CORE: taze /compact → settle → devam+nonce → marker-verify (uzaktan-çekirdek REUSE) ---
if _compact_drive "$SC_TARGET" "$SC_MID" "$SC_DEVAM" "$SC_RE"; then
  audit "OK compact+rebootstrap-dogrulandi"
  exit 0
else
  rc=$?
  audit "UNVERIFIED rc=${rc} — pane elle-kontrol gerekebilir"
  exit "$rc"
fi
