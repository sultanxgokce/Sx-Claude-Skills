#!/usr/bin/env bash
# ekip-selfcompact.sh — ÖZ-SERVİS compact TETİĞİ (ajan KENDİNİ compact + re-bootstrap).
#   Hedef: ajan yüksek-context'te AskUserQuestion evet/hayır sorar → "evet"te BU scripti koşar → turu bitirir.
# Kullanım: ekip-selfcompact.sh --self ["devam-mesajı"]
# Akış: RESOLVE-SELF (TMUX_PANE→registry) → DETACHED watcher-spawn (setsid) → çık.
#   ⚠️ AJAN bu script'ten SONRA turu DERHAL bitirmeli (başka tool-call YOK) → pane idle → watcher taze /compact yollar.
#   Watcher (ekip-selfcompact-watcher.sh) ajan-compaction'ından bağımsız yaşar → devam-nudge'u compact-sonrası enjekte eder.
# Kaynak-desen: uzaktan-compact çekirdeği (ekip-compact-core.lib.sh REUSE) · detached-watcher deseni.
# Değişmez: literal /compact HARD-CODE · /clear ASLA (context-kaybı) · send-keys script-içi (hook-clean) ·
#           self-loop-guard TERS (caller==target ZORUNLU — uzaktan-compact'in reddettiği durumu bu araç GEREKTİRİR).
# Exit: 0=watcher-spawn edildi (turu bitir) · 1=runtime(resolve/oturum) · 2=usage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
SINYAL="${EKIP_SINYAL:-$REPO_ROOT/_agents/handoff/ekip-sinyal.log}"
PREFLIGHT_LIB="$SCRIPT_DIR/ekip-preflight.lib.sh"
CORE_LIB="$SCRIPT_DIR/ekip-compact-core.lib.sh"
WATCHER="$SCRIPT_DIR/ekip-selfcompact-watcher.sh"

usage() { echo "kullanım: ekip-selfcompact.sh --self [\"devam-mesajı\"]" >&2; exit 2; }

MODE=""; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --self) MODE=self ;;
    --*)    echo "HATA: bilinmeyen bayrak: $1" >&2; usage ;;
    *)      POS+=("$1") ;;
  esac
  shift
done
[ "$MODE" = self ] || usage   # bu araç YALNIZ --self (kazara-uzaktan koruması; uzaktan = ekip-compact.sh benzeri)

DEVAM_VARSAYILAN="compact tamam — kanalındaki son-KONUM/checkpoint dosyanı oku, kimliğinle kaldığın-işe devam et."
DEVAM="${POS[0]:-$DEVAM_VARSAYILAN}"

[ -f "$CORE_LIB" ] || { echo "HATA: core-lib yok: $CORE_LIB" >&2; exit 1; }
[ -f "$WATCHER" ]  || { echo "HATA: watcher yok: $WATCHER" >&2; exit 1; }
command -v tmux    >/dev/null 2>&1 || { echo "HATA: tmux kurulu değil" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil (registry-parse)" >&2; exit 1; }
command -v setsid  >/dev/null 2>&1 || { echo "HATA: setsid yok — detached-watcher spawn edilemez" >&2; exit 1; }
[ -n "${TMUX_PANE:-}" ] || { echo "HATA: TMUX_PANE yok — tmux-oturumu içinde koşmalı (self-resolve gerekir)" >&2; exit 1; }

# --- RESOLVE-SELF: TMUX_PANE → session_name → registry ters-lookup → kendi MID/TARGET ---
CALLER_SESSION="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null | awk -v p="$TMUX_PANE" '$1==p{print $2; exit}')"
[ -n "$CALLER_SESSION" ] || { echo "HATA: kendi session'ım çözülemedi (TMUX_PANE=$TMUX_PANE)" >&2; exit 1; }

PARSE_PY='
import re, sys
cur=None; tmux=None
def flush():
    global cur,tmux
    if cur and tmux is not None: print(cur+"\t"+tmux)
    cur=None; tmux=None
for line in open(sys.argv[1], encoding="utf-8"):
    m=re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m: flush(); cur=m.group(1); continue
    m=re.match(r"\s*tmux:\s*\"?([^\"\s]+)\"?", line)
    if m and cur: tmux=m.group(1); continue
flush()
'
# self-loop-guard TERS: session_name'i registry tmux-hedefiyle eşleştir (caller==target). Registry opsiyonel.
MID=""; TARGET=""
if [ -f "$REGISTRY" ]; then
  MEMBERS="$(python3 -c "$PARSE_PY" "$REGISTRY" 2>/dev/null || true)"
  read -r MID TARGET < <(printf '%s\n' "$MEMBERS" | awk -F'\t' -v s="$CALLER_SESSION" '{ sess=$2; sub(/:.*/,"",sess); if (sess==s){print $1"\t"$2; exit} }') || true
fi
# GENERIC-FALLBACK: ekip-üyesi DEĞİLSE (herhangi bir tmux-oturumu) yine self-compact et — hedef=kendi pane'im
# (caller==target doğası gereği güvenli). Kimlik geri-yükleme jenerik SessionStart-bootstrap'tan gelir.
REBOOTSTRAP_MARKER="${EKIP_REBOOTSTRAP_MARKER:-geri-yüklendi}"
if [ -z "${TARGET:-}" ]; then
  MID="$CALLER_SESSION"
  TARGET="${CALLER_SESSION}:0"
  echo "→ (ekip-dışı oturum: jenerik self-compact modu · marker=${REBOOTSTRAP_MARKER})" >&2
fi

# Re-bootstrap marker: ekip-üyesi → SessionStart handshake '<ID> geri-yüklendi' · jenerik → EKIP_REBOOTSTRAP_MARKER.
REBOOTSTRAP_RE="${MID} geri-yüklendi|${REBOOTSTRAP_MARKER}"   # emoji-suz (awk-ERE güvenli)

# --- DETACHED WATCHER SPAWN (setsid → ajan-compaction'ından bağımsız; SC_* env ile besle, sır-değer YOK) ---
setsid env \
  SC_SCRIPT_DIR="$SCRIPT_DIR" \
  SC_CORE_LIB="$CORE_LIB" \
  SC_PREFLIGHT_LIB="$PREFLIGHT_LIB" \
  SC_SINYAL="$SINYAL" \
  SC_TARGET="$TARGET" \
  SC_MID="$MID" \
  SC_DEVAM="$DEVAM" \
  SC_RE="$REBOOTSTRAP_RE" \
  SC_INIT_IDLE="${INITIAL_IDLE_TIMEOUT:-300}" \
  bash "$WATCHER" </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

cat >&2 <<EOF
✓ self-compact watcher spawn edildi ($MID · $TARGET).
  → ŞİMDİ TURU DERHAL BİTİR (başka tool-call YOK). Pane idle olunca watcher /compact'i yollayacak,
    compaction bitince devam-nudge ile kimliğini geri-yükleyip kaldığın-işe döndürecek.
  → sonuç: ekip-sinyal.log 'SELFCOMPACT $MID …' satırında.
EOF
exit 0
