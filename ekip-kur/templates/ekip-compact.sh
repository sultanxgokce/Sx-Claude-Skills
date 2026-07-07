#!/usr/bin/env bash
# ekip-compact.sh — COMPACT-ORKESTRA primitifi: bir üyeyi uzaktan compact ettir → kimliği-korunmuş devam ettir.
# Spec: _agents/handoff/ekip-registry.yaml · Kaynak-desen: ekip-kur master-skill (aile-compact.sh emsali).
#
# Kullanım:
#   scripts/ekip-compact.sh <üye> ["devam-mesajı"]
#     <üye>          registry-id (case-insensitive). Kendini compact edemezsin (self-loop guard).
#     [devam-mesajı] compact SONRASI gönderilecek yönerge; verilmezse KONUM-devri-varsayılanı kullanılır.
#
# Uçtan-uca (bağımlılık 1→2→3): (1) self-recognition-hook CANLI olmalı — compact sonrası kimliği o kurar.
#   Bu araç yalnız TETİKLER + re-bootstrap-MARKER satırını bekler; kimliği-basan hook yapar. Hook yoksa → araç
#   "compact tetiklendi ama re-bootstrap DOĞRULANAMADI" der (başarı-İDDİA ETMEZ = dürüst-degrade).
# Değişmez: sır-değer TAŞIMAZ · başarı yalnız MARKER görülünce · timeout-DÜRÜST.
# Exit: 0=compact+devam gönderildi & re-bootstrap-marker görüldü · 1=hata/DUR/timeout (marker doğrulanamadı) · 2=usage.
set -euo pipefail

[ $# -ge 1 ] || { echo "kullanım: ekip-compact.sh <üye> [\"devam-mesajı\"]" >&2; exit 2; }
HEDEF="$1"
DEVAM="${2:-compact tamamlandı — KİMLİĞİNİ KORU. Kanalındaki son KONUM/checkpoint dosyasını oku, kaldığın işe kimliğinle devam et.}"

# ── tunables (live-kalibrasyon; env-override) ──
POLL_INTERVAL="${EKIP_POLL_INTERVAL:-3}"
SETTLE_TIMEOUT="${EKIP_SETTLE_TIMEOUT:-120}"   # /compact sonrası "Compacting" geçmesi beklenir
MARKER_TIMEOUT="${EKIP_MARKER_TIMEOUT:-90}"    # devam sonrası re-bootstrap-marker beklenir
REBOOTSTRAP_RE="${EKIP_REBOOTSTRAP_RE:-geri-yüklendi|SELF-RECOGNITION|CORTEX BOOTSTRAP}"
# 🔁 ekip-notify.sh ile SENKRON marker-regexleri (birini kalibre edince digerini de):
BUSY_RE="${EKIP_BUSY_RE:-esc to interrupt|esc to cancel|Thinking…|Compacting|Compacting conversation}"
MENU_RE="${EKIP_MENU_RE:-❯[[:space:]]*[0-9]\.|Do you want|Would you like|\(y/n\)|❯[[:space:]]*(Yes|No)}"
COMPACT_RE="${EKIP_COMPACT_RE:-auto-compact|context left until|context low|/compact|compact yap|oturumu böl|compact yapayım}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "HATA: tmux yok" >&2; exit 1; }

# --- <üye> için tmux-hedefi çöz (case-insensitive; -c "$VAR" formu — heredoc-in-$() parse-tuzağından kaçınır) ---
RESOLVE_PY='
import re, sys
reg, hedef = sys.argv[1], sys.argv[2].upper()
cur = None
for line in open(reg, encoding="utf-8"):
    m = re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m:
        cur = m.group(1); continue
    m = re.match(r"\s*tmux:\s*\"?([^\"\s]+)\"?", line)
    if m and cur:
        if cur.upper() == hedef:
            print(m.group(1)); break
        cur = None
'
TARGET="$(python3 -c "$RESOLVE_PY" "$REGISTRY" "$HEDEF")"
[ -n "$TARGET" ] || { echo "HATA: bilinmeyen üye '$HEDEF' — registry-id kullan" >&2; exit 1; }
SESSION="${TARGET%%:*}"

tmux has-session -t "$SESSION" 2>/dev/null || { echo "HATA: oturum YOK: $SESSION (tmux casing?)" >&2; exit 1; }

# self-loop guard — kendini compact'leme
if [ -n "${TMUX_PANE:-}" ]; then
  CALLER="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null | awk -v p="$TMUX_PANE" '$1==p{print $2; exit}')"
  [ "$CALLER" = "$SESSION" ] && { echo "HATA: kendini compact edemezsin ($SESSION = çağıran-oturum)" >&2; exit 1; }
fi

# capture helpers: _snap = görünür-ekran tail (footer/durum-marker'ları); _snap_wide = scrollback (tek-satır chat-marker uzun-yanıtta kaymasın)
_snap()      { tmux capture-pane -pt "$TARGET" 2>/dev/null | sed 's/[[:space:]]*$//' | tail -n 25 || true; }
_snap_wide() { tmux capture-pane -p -S -200 -t "$TARGET" 2>/dev/null | sed 's/[[:space:]]*$//' | tail -n 200 || true; }

# preflight_state → idle|busy|menu|compact  (capture-FAİL = bilinmeyen → busy/block; capture-OK-boş = idle)
preflight_state() {
  local snap rc=0
  snap="$(tmux capture-pane -pt "$TARGET" 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ]; then echo busy; return; fi
  snap="$(printf '%s\n' "$snap" | sed 's/[[:space:]]*$//' | tail -n 25)"
  if [ -z "${snap//[[:space:]]/}" ]; then echo idle; return; fi
  if printf '%s\n' "$snap" | grep -qiE "$BUSY_RE";    then echo busy;    return; fi
  if printf '%s\n' "$snap" | grep -qiE "$MENU_RE";    then echo menu;    return; fi
  if printf '%s\n' "$snap" | grep -qiE "$COMPACT_RE"; then echo compact; return; fi
  echo idle
}

# 1 · ÖN-UÇUŞ: busy/menü ise DUR (mid-work compact YAPMA). compact-önerisi/idle → GO.
STATE="$(preflight_state)"
case "$STATE" in
  busy|menu) echo "DUR: $HEDEF durum=$STATE — mid-work compact GÜVENLİ-DEĞİL. Üye boşalınca tekrar dene." >&2; exit 1 ;;
  compact)   echo "1/4 · $HEDEF compact-önerisi/context-uyarısı durumunda → GO." ;;
  idle)      echo "1/4 · $HEDEF boşta → proaktif compact GO." ;;
esac

# send helper (3-adım-Enter fix — aile-notify.sh ile aynı; DEĞİŞTİRME)
send_line() {
  tmux send-keys -t "$TARGET" C-u 2>/dev/null || true
  tmux send-keys -t "$TARGET" -- "$1"
  sleep 0.4
  tmux send-keys -t "$TARGET" Enter
}

# 2 · /compact gönder
echo "2/4 · /compact → $TARGET"
send_line "/compact"

# 3 · compact-tamamlanmasını bekle ("Compacting" görünüp KAYBOLmalı → settle). Dürüst-timeout.
COMPACTING_RE="${EKIP_COMPACTING_RE:-Compacting}"   # settle-sinyali (BUSY_RE'den AYRI tunable; hardcode-etme)
echo "3/4 · compact-tamamlanması bekleniyor (max ${SETTLE_TIMEOUT}s)…"
saw_compacting=0; settled=0
# ilk-snapshot (sleep-ÖNCESİ) → ilk-interval'de gelip-geçen hızlı-compaction'ı kaçırma
if printf '%s\n' "$(_snap)" | grep -qiE "$COMPACTING_RE"; then saw_compacting=1; fi
elapsed=0
while [ "$elapsed" -lt "$SETTLE_TIMEOUT" ]; do
  sleep "$POLL_INTERVAL"; elapsed=$(( elapsed + POLL_INTERVAL ))
  if printf '%s\n' "$(_snap)" | grep -qiE "$COMPACTING_RE"; then
    saw_compacting=1
  elif [ "$saw_compacting" -eq 1 ]; then
    settled=1; break            # Compacting görüldü sonra kayboldu = compaction bitti
  fi
done
# hâlâ compacting görünüyorsa (timeout) → HARD-STOP: devam-mesajı GÖNDERME (mid-compaction text kaybolur)
if [ "$settled" -ne 1 ] && printf '%s\n' "$(_snap)" | grep -qiE "$COMPACTING_RE"; then
  echo "DUR: $HEDEF hâlâ 'Compacting' (${elapsed}s timeout) — devam-mesajı GÖNDERİLMEDİ (mid-compaction kayıp-riski). Elle-teyit et." >&2
  exit 1
fi
if [ "$settled" -ne 1 ]; then
  echo "⚠️ compact-settle net-görülmedi (${elapsed}s; ne 'Compacting'-geçişi ne aktif-compacting) — devam yine de gönderilecek; sonucu capture-pane ile teyit et." >&2
fi

# 4 · devam-mesajı gönder → re-bootstrap-marker'ı bekle (scrollback ile: uzun-yanıtta tek-satır marker kaymasın)
echo "4/4 · devam-mesajı gönderiliyor + re-bootstrap-marker bekleniyor (max ${MARKER_TIMEOUT}s)…"
send_line "$DEVAM"
elapsed=0; got_marker=0
while [ "$elapsed" -lt "$MARKER_TIMEOUT" ]; do
  sleep "$POLL_INTERVAL"; elapsed=$(( elapsed + POLL_INTERVAL ))
  if printf '%s\n' "$(_snap_wide)" | grep -qiE "$REBOOTSTRAP_RE"; then got_marker=1; break; fi
done

if [ "$got_marker" -eq 1 ]; then
  echo "✅ $HEDEF: compact + kimlik-re-bootstrap DOĞRULANDI (marker görüldü) + devam tetiklendi."
  exit 0
else
  echo "⚠️ $HEDEF: compact tetiklendi + devam gönderildi AMA re-bootstrap-marker DOĞRULANAMADI (${elapsed}s timeout)." >&2
  echo "   Olası neden: self-recognition-hook canlı-değil / marker-regex kalibresiz / üye henüz yanıtlamadı. capture-pane ile elle-teyit et." >&2
  exit 1
fi
