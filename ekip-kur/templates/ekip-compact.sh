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

usage() { echo "kullanım: ekip-compact.sh <üye-id> [\"devam-mesajı\"] [--force] [--timeout N]
       ekip-compact.sh --hepsi [\"devam-mesajı\"] [--uygula] [--force]   (gözetimli-idle-pilot: idle-adayları sırayla compact)" >&2; exit 2; }

# --- bayrak-tarama ---
FORCE=0; HEPSI=0; UYGULA=0; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=1 ;;
    --hepsi)   HEPSI=1 ;;   # gözetimli-idle-pilot: registry'deki tüm idle-adayları sırayla compact
    --uygula)  UYGULA=1 ;;  # --hepsi ile: kuru-çalışmayı gerçek-compact'e çevir (gözetim = varsayılan kuru)
    --timeout) shift; VERIFY_TIMEOUT="${1:-$VERIFY_TIMEOUT}" ;;
    --*)       echo "HATA: bilinmeyen bayrak: $1" >&2; usage ;;
    *)         POS+=("$1") ;;
  esac
  shift
done
DEVAM_VARSAYILAN="compact tamam — kanalındaki son-KONUM/checkpoint dosyanı oku, kimliğinle kaldığın-işe devam et."
if [ "$HEPSI" -eq 1 ]; then
  DEVAM="${POS[0]:-$DEVAM_VARSAYILAN}"   # --hepsi'de pozisyonel = ortak devam-mesajı (üye-id YOK)
else
  [ "${#POS[@]}" -ge 1 ] || usage
  HEDEF="${POS[0]}"
  DEVAM="${POS[1]:-$DEVAM_VARSAYILAN}"
fi

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

# CALLER_SESSION (self-loop guard — kendini-compact = öz-servis ekip-selfcompact.sh ayrı-yol; hem tekli hem --hepsi kullanır)
CALLER_SESSION=""
if [ -n "${TMUX_PANE:-}" ]; then
  CALLER_SESSION="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null | awk -v p="$TMUX_PANE" '$1==p{print $2; exit}')"
fi

# compact_one <ID> <TARGET> <DEVAM> — TEK üyeyi preflight-gate'le + drive et; kendi mesajını basar, rc döndürür.
# Önkoşul (çağıran garanti eder): has-session ✓ + self-loop-değil ✓.  (DRY: tekli-yol + --hepsi ortak-çekirdek.)
compact_one() {
  local MID="$1" TARGET="$2" DEVAM="$3" SESSION="${2%%:*}" PF rc=0
  local RE="$REBOOTSTRAP_RE"; [ -n "$RE" ] || RE="${MID} geri-yüklendi|CORTEX BOOTSTRAP"  # üyeye-özel (precise) + jenerik fallback; emoji-suz (awk-ERE güvenli)
  # PREFLIGHT: busy/menu → DUR (mid-work compact'leme); compact/idle → GO
  if [ "$FORCE" -eq 0 ] && declare -F preflight_state >/dev/null; then
    PF="$(preflight_state "$TARGET")"
    case "$PF" in
      busy|menu) echo "ENGEL: $MID pane-durumu='$PF' — mid-work compact'lemem; bilinçliysen --force" >&2; return 1 ;;
      compact)   echo "→ $MID durumu='compact' (üye zaten compact istiyor) — GO" ;;
      idle)      echo "→ $MID durumu='idle' — proaktif compact GO" ;;
    esac
  else
    echo "→ preflight atlandı (--force veya lib-yok)"
  fi
  # DRIVE (send /compact → settle → devam+nonce → marker-verify) = çekirdek-lib (DRY, tek-kaynak)
  _compact_drive "$TARGET" "$MID" "$DEVAM" "$RE" || rc=$?
  [ "$rc" -eq 5 ] && echo "  → pane'e bak: tmux attach -t $SESSION" >&2
  return "$rc"
}

# ═══ --hepsi · GÖZETİMLİ-İDLE-PİLOT (Sultan Q1=A) ═══════════════════════════════════════════
#   idle-adayları topla (busy/menu/draft = mid-work → ATLA · self → ATLA · oturum-yok → ATLA)
#   → varsayılan KURU-ÇALIŞMA (gözetim yüzeyi = aday-listesi) · --uygula ile sırayla compact.
#   ⚠️ context-% ÖLÇÜMÜ YOK (ölçüm-kaynağı kurulu-değil) → preflight-IDLE temeli; SAHTE-% YAZMA.
if [ "$HEPSI" -eq 1 ]; then
  CAND=()
  while IFS=$'\t' read -r ID TARGET; do
    [ -n "$ID" ] || continue
    SESSION="${TARGET%%:*}"
    tmux has-session -t "$SESSION" 2>/dev/null || { echo "  = atla $ID (oturum yok: $SESSION)"; continue; }
    if [ -n "$CALLER_SESSION" ] && [ "$SESSION" = "$CALLER_SESSION" ]; then
      echo "  = atla $ID (kendisi — öz-servis = ekip-selfcompact.sh)"; continue
    fi
    PF=idle
    if [ "$FORCE" -eq 0 ] && declare -F preflight_state >/dev/null; then
      PF="$(preflight_state "$TARGET")"
      if [ "$PF" = idle ] && declare -F composer_kind >/dev/null; then
        case "$(composer_kind "$TARGET")" in draft:*) PF=draft ;; esac
      fi
    fi
    case "$PF" in
      idle|compact) CAND+=("$ID"$'\t'"$TARGET") ;;
      *)            echo "  = atla $ID (durum='$PF' — mid-work, compact'lemem)" ;;
    esac
  done <<< "$MEMBERS"

  [ "${#CAND[@]}" -gt 0 ] || { echo "aday-yok: compact edilecek idle-üye bulunamadı."; exit 0; }
  echo
  printf 'idle-aday (%s): ' "${#CAND[@]}"; for r in "${CAND[@]}"; do printf '%s ' "${r%%$'\t'*}"; done; echo
  if [ "$UYGULA" -eq 0 ]; then
    echo "KURU-ÇALIŞMA (gözetimli-pilot): yukarıdakileri compact ederdim — hiçbiri tetiklenmedi."
    echo "Uygulamak için: ekip-compact.sh --hepsi --uygula"
    exit 0
  fi
  OK=0; UNVER=0; FAIL=0
  for r in "${CAND[@]}"; do
    IFS=$'\t' read -r ID TARGET <<< "$r"
    echo; echo "── $ID compact ediliyor ──"
    rc=0; compact_one "$ID" "$TARGET" "$DEVAM" || rc=$?
    case "$rc" in
      0) OK=$((OK+1)) ;;
      5) UNVER=$((UNVER+1)); echo "  ⚠ $ID: tetiklendi ama re-bootstrap DOĞRULANAMADI (başarı iddia etme)" >&2 ;;
      *) FAIL=$((FAIL+1));  echo "  ✗ $ID: rc=$rc" >&2 ;;
    esac
  done
  echo; echo "ozet: dogrulandi=$OK dogrulanamadi=$UNVER basarisiz=$FAIL / aday=${#CAND[@]}"
  [ "$FAIL"  -gt 0 ] && exit 1
  [ "$UNVER" -gt 0 ] && exit 5
  exit 0
fi

# ═══ TEKLİ ÜYE-COMPACT (registry-id ile) ═══════════════════════════════════════════════════
# --- 1 · RESOLVE (id → tmux-hedef; has-session; self-loop guard) ---
HEDEF_UPPER="$(printf '%s' "$HEDEF" | tr '[:lower:]' '[:upper:]')"
read -r MID TARGET < <(printf '%s\n' "$MEMBERS" | awk -F'\t' -v h="$HEDEF_UPPER" 'toupper($1)==h{print $1"\t"$2; exit}') || true  # eşleşme-yok=EOF→read non-zero; set -e'yi tetikleme, guard mesaj-bassın
[ -n "${TARGET:-}" ] || { echo "HATA: bilinmeyen üye '$HEDEF' — registry-id kullan" >&2; exit 1; }
SESSION="${TARGET%%:*}"
tmux has-session -t "$SESSION" 2>/dev/null || { echo "HATA: $MID oturumu YOK ($SESSION) — o kimlik açık değil" >&2; exit 1; }
if [ -n "$CALLER_SESSION" ] && [ "$SESSION" = "$CALLER_SESSION" ]; then
  echo "HATA: kendini-compact bu araçla yapılmaz (öz-servis = ekip-selfcompact.sh ayrı-yol). İptal." >&2; exit 1
fi

rc=0; compact_one "$MID" "$TARGET" "$DEVAM" || rc=$?
exit "$rc"
