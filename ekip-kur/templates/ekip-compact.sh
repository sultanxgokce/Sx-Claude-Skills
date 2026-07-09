#!/usr/bin/env bash
# ekip-compact.sh — COMPACT-ORKESTRA primitifi (yönetici → üye, uzaktan uçtan-uca)
#   "compact-gerektiğinde/üye-önerince: tetikle → kimliği-korunmuş-yeniden-yapılan → devam-ettir."
# Kullanım:  ekip-compact.sh <üye-id> ["devam-mesajı"]   [--force] [--timeout N]
#   <üye-id> ∈ registry-id (ekip-registry.yaml roster'ından; büyük/küçük-harf duyarsız).
# Kaynak-desen: ekip-kur master compact-orkestra (koordinasyon substratı).
#
# BAĞIMLILIK 1→2→3: self-recognition CANLI olmalı (SessionStart-hook kimlik-enjeksiyonu marker'ı üretir);
#   preflight-lib guard'ı için ekip-preflight.lib.sh source edilir.
#
# ⚠️ GROUND-TRUTH SIRASI (firsthand-ölçüm, büyük-context /compact'inde):
#   `/compact` TEK-BAŞINA asistan-turu ÜRETMEZ → SessionStart-identity enjekte olur ama üye
#   bir USER-TURU alana dek `🧑‍🚀 <ID> geri-yüklendi` marker'ını BASMAZ. Bu yüzden doğrulama-sırası
#   ground-truth'a göre: compact → SETTLE → DEVAM(turu-tetikler) → MARKER-DOĞRULA.
#   Devam-nudge = re-bootstrap turunu tetikleyen şey; ondan SONRA marker belirir.
#
# Değişmez: sır-değer TAŞIMAZ · insan-onay-alanı YAZMAZ · yalnız tmux-tetik + capture-pane-poll (salt-oku).
# Exit: 0=compact+re-bootstrap DOĞRULANDI · 1=runtime(çözülemedi/oturum-yok/preflight-block) ·
#       2=usage · 5=tetiklendi ama re-bootstrap DOĞRULANAMADI (başarı İDDİA ETME) · 6=compaction takıldı (hard-stop).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
PREFLIGHT_LIB="$SCRIPT_DIR/ekip-preflight.lib.sh"
CORE_LIB="$SCRIPT_DIR/ekip-compact-core.lib.sh"
# shellcheck source=/dev/null
[ -f "$PREFLIGHT_LIB" ] && . "$PREFLIGHT_LIB"

# --- tunable'lar (go-live kalibrasyonu = tek-satır düzenleme) — çekirdek-lib de aynı default'ları kullanır ---
COMPACTING_RE="${COMPACTING_RE:-Compacting|Summarizing conversation}"   # DAR compaction-status (bare 'compact' YASAK: scrollback'teki /compact+iş-metni false-match eder → hard-stop). Yalnız GÖRÜNÜR-tail'de tara.
REBOOTSTRAP_RE="${REBOOTSTRAP_RE:-}"    # boşsa Resolve'da '🧑‍🚀 <ID> geri-yüklendi|CORTEX BOOTSTRAP' kurulur
SETTLE_TIMEOUT="${SETTLE_TIMEOUT:-300}" # compaction bitme üst-sınırı (sn) — GERÇEK büyük-context compaction >2dk sürebilir (firsthand: 2m25s@80%); 120 çok-kısaydı
VERIFY_TIMEOUT="${VERIFY_TIMEOUT:-90}"  # devam-sonrası marker'ı bekleme üst-sınırı (sn)
POLL="${POLL:-3}"                       # poll aralığı (sn)
SCROLLBACK="${SCROLLBACK:--200}"        # marker uzun-yanıtta yukarı kayar → scrollback tara
export COMPACTING_RE SETTLE_TIMEOUT VERIFY_TIMEOUT POLL SCROLLBACK  # çekirdek-lib bu tunable'ları devralır
# shellcheck source=/dev/null
[ -f "$CORE_LIB" ] || { echo "HATA: core-lib yok: $CORE_LIB" >&2; exit 1; }
. "$CORE_LIB"                           # _snap/_vis/_wait_idle/_compact_drive (DRY: drive 3-6 tek-kaynak)

usage() { echo "kullanım: ekip-compact.sh <üye-id> [\"devam-mesajı\"] [--force] [--timeout N]" >&2; exit 2; }

# --- bayrak-tarama ---
FORCE=0; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=1 ;;
    --timeout) shift; VERIFY_TIMEOUT="${1:-$VERIFY_TIMEOUT}" ;;
    --*)       echo "HATA: bilinmeyen bayrak: $1" >&2; usage ;;
    *)         POS+=("$1") ;;
  esac
  shift
done
[ "${#POS[@]}" -ge 1 ] || usage
HEDEF="${POS[0]}"
DEVAM_VARSAYILAN="compact tamam — kanalındaki son-KONUM/checkpoint dosyanı oku, kimliğinle kaldığın-işe devam et."
DEVAM="${POS[1]:-$DEVAM_VARSAYILAN}"

[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }
command -v tmux    >/dev/null 2>&1 || { echo "HATA: tmux kurulu değil" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil (registry-parse)" >&2; exit 1; }

# --- registry parse: 'ID<TAB>tmux' (ekip-notify.sh ile aynı desen) ---
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
MEMBERS="$(python3 -c "$PARSE_PY" "$REGISTRY")"
[ -n "$MEMBERS" ] || { echo "HATA: registry parse boş — biçim bozuk: $REGISTRY" >&2; exit 1; }

# --- 1 · RESOLVE (id → tmux-hedef; has-session; self-loop guard) ---
HEDEF_UPPER="$(printf '%s' "$HEDEF" | tr '[:lower:]' '[:upper:]')"
read -r MID TARGET < <(printf '%s\n' "$MEMBERS" | awk -F'\t' -v h="$HEDEF_UPPER" 'toupper($1)==h{print $1"\t"$2; exit}') || true  # eşleşme-yok=EOF→read non-zero; set -e'yi tetikleme, guard mesaj-bassın
[ -n "${TARGET:-}" ] || { echo "HATA: bilinmeyen üye '$HEDEF' — registry-id kullan" >&2; exit 1; }
SESSION="${TARGET%%:*}"
tmux has-session -t "$SESSION" 2>/dev/null || { echo "HATA: $MID oturumu YOK ($SESSION) — o kimlik açık değil" >&2; exit 1; }

# self-loop: bu araç UZAKTAN üye-compact içindir; kendini-compact = öz-servis (ekip-selfcompact.sh) işi, ayrı-yol.
CALLER_SESSION=""
if [ -n "${TMUX_PANE:-}" ]; then
  CALLER_SESSION="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null | awk -v p="$TMUX_PANE" '$1==p{print $2; exit}')"
fi
if [ -n "$CALLER_SESSION" ] && [ "$SESSION" = "$CALLER_SESSION" ]; then
  echo "HATA: kendini-compact bu araçla yapılmaz (öz-servis = ekip-selfcompact.sh ayrı-yol). İptal." >&2; exit 1
fi

# marker default: üyeye-özel (precise) + jenerik fallback
[ -n "$REBOOTSTRAP_RE" ] || REBOOTSTRAP_RE="${MID} geri-yüklendi|CORTEX BOOTSTRAP"  # emoji-suz (awk-ERE güvenli); metin yeterince benzersiz + nonce-çapa eski-eşleşmeyi zaten eler

# --- 2 · PREFLIGHT (busy/menu → DUR: mid-work compact'leme; compact/idle → GO) ---
if [ "$FORCE" -eq 0 ] && declare -F preflight_state >/dev/null; then
  PF="$(preflight_state "$TARGET")"
  case "$PF" in
    busy|menu) echo "ENGEL: $MID pane-durumu='$PF' — mid-work compact'lemem; bilinçliysen --force" >&2; exit 1 ;;
    compact)   echo "→ $MID durumu='compact' (üye zaten compact istiyor) — GO" ;;
    idle)      echo "→ $MID durumu='idle' — proaktif compact GO" ;;
  esac
else
  echo "→ preflight atlandı (--force veya lib-yok)"
fi

# --- 3-6 · DRIVE (send /compact → settle → devam+nonce → marker-verify) = çekirdek-lib (DRY, tek-kaynak) ---
# Önkoşul yukarıda garanti edildi: preflight idle/compact (busy/menu → zaten exit 1 / --force).
rc=0; _compact_drive "$TARGET" "$MID" "$DEVAM" "$REBOOTSTRAP_RE" || rc=$?   # set -e: non-zero'yu yakala
[ "$rc" -eq 5 ] && echo "  → pane'e bak: tmux attach -t $SESSION" >&2
exit "$rc"
