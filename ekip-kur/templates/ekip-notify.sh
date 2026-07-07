#!/usr/bin/env bash
# ekip-notify.sh — çok-ajan ekip tmux-tetik primitifi (bir üye→diğerlerine "kanalı oku" ping'i)
# Spec: _agents/handoff/ekip-registry.yaml  (ekip-kur master-skill'i tarafından scaffold edildi)
# Kaynak-desen: Nexus SERDAR-ailesi aile-notify.sh (4 kritik-fix aynen korunmuştur — aşağıda).
#
# Kullanım:
#   scripts/ekip-notify.sh <ajan|all> "<mesaj>" [--force]
#     <ajan> ∈ registry-id (case-insensitive; bkz _agents/handoff/ekip-registry.yaml) veya "all"
#     <mesaj> hedef Claude'a kullanıcı-mesajı olarak düşer (tmux send-keys … Enter).
#     --force  ön-uçuş-kapısını (READ-BEFORE-TRIGGER) yoksay: busy/menü/compact olsa da gönder.
#
# Davranış: registry'den hedef tmux-oturum(lar)ı çözer (python3 line-based) · çağıran-oturumu SELF-LOOP
#   koruması ile atlar ($TMUX_PANE) · her hedef için `has-session` doğrular (yoksa dürüst-uyar+non-zero) ·
#   ÖN-UÇUŞ: hedef busy/menü-bekliyor/compact-önerisi ise DUR (--force ile bypass) → kör-tetik önlenir.
# Değişmez: sır-değer TAŞIMAZ · kardeş dosyalarına DOKUNMAZ · idempotent-değil (her çağrı yeni-ping).
# Exit: 0=en-az-bir-gönderildi & eksik/engel yok · 1=runtime (eksik-oturum/engellendi/hiç-gönderilemedi/bilinmeyen-ajan) · 2=usage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"   # env-override yalnız test/scratch içindir

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '6,10p'; exit 2; }

# --- argümanlar: --force herhangi bir konumda olabilir ---
FORCE=0; POS=()
for a in "$@"; do
  if [ "$a" = "--force" ]; then FORCE=1; else POS+=("$a"); fi
done
set -- "${POS[@]:-}"
[ $# -ge 2 ] || usage
HEDEF="$1"; MESAJ="$2"

[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "HATA: tmux kurulu değil (command -v tmux boş)" >&2; exit 1; }

# ── ÖN-UÇUŞ marker'ları (READ-BEFORE-TRIGGER · PARÇA-2) ──────────────────────
# ⚠️ TUNABLE + LIVE-KALİBRASYON: Claude-Code TUI-string'lerini eşler. Hedef-ortamda capture-pane
#    çıktısına göre bir kez kalibre et (env-override ile de değiştirilebilir).
#    🔁 ekip-compact.sh AYNI marker'ları taşır — birini kalibre edince DİĞERİNİ DE senkronla (drift-riski).
BUSY_RE="${EKIP_BUSY_RE:-esc to interrupt|esc to cancel|Thinking…|Compacting|Compacting conversation}"
MENU_RE="${EKIP_MENU_RE:-❯[[:space:]]*[0-9]\.|Do you want|Would you like|\(y/n\)|❯[[:space:]]*(Yes|No)}"
COMPACT_RE="${EKIP_COMPACT_RE:-auto-compact|context left until|context low|/compact|compact yap|oturumu böl|compact yapayım}"

# preflight_state <tmux-target> → stdout: idle|busy|menu|compact
#   capture BAŞARISIZ (tmux hiccup/pane-race) = BİLİNMEYEN durum → güvenli-taraf: busy (block).
#   capture OK ama boş = gerçekten idle. (Bilinmeyen≠güvenli — safety-gate'in doğru-tarafı.)
preflight_state() {
  local target="$1" snap rc=0
  snap="$(tmux capture-pane -pt "$target" 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ]; then echo busy; return; fi
  snap="$(printf '%s\n' "$snap" | sed 's/[[:space:]]*$//' | tail -n 25)"
  if [ -z "${snap//[[:space:]]/}" ]; then echo idle; return; fi
  if printf '%s\n' "$snap" | grep -qiE "$BUSY_RE";    then echo busy;    return; fi
  if printf '%s\n' "$snap" | grep -qiE "$MENU_RE";    then echo menu;    return; fi
  if printf '%s\n' "$snap" | grep -qiE "$COMPACT_RE"; then echo compact; return; fi
  echo idle
}

# --- registry parse: 'ID<TAB>tmux-hedef' satırları (python3 line-based; PyYAML gerekmez) ---
PARSE_PY='
import re, sys
cur = None
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m:
        cur = m.group(1); continue
    m = re.match(r"\s*tmux:\s*\"?([^\"\s]+)\"?", line)
    if m and cur:
        print(cur + "\t" + m.group(1)); cur = None
'
MEMBERS="$(python3 -c "$PARSE_PY" "$REGISTRY")"
[ -n "$MEMBERS" ] || { echo "HATA: registry parse boş — biçim bozuk ya da roster boş olabilir: $REGISTRY" >&2; exit 1; }

# registry'deki bilinen id'ler (bilinmeyen-ajan hatasında dinamik listelenir — jenerik-doğru) ---
KNOWN_IDS="$(printf '%s\n' "$MEMBERS" | awk -F'\t' '{print $1}' | paste -sd'|' -)"

# --- self-loop: çağıran tmux-oturumunu $TMUX_PANE'den çöz (varsa) ---
CALLER_SESSION=""
if [ -n "${TMUX_PANE:-}" ]; then
  CALLER_SESSION="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null \
    | awk -v p="$TMUX_PANE" '$1==p {print $2; exit}')"
fi

# --- hedef listesi seç (all → tüm üyeler; tek → id case-insensitive eşleşme) ---
HEDEF_UPPER="$(printf '%s' "$HEDEF" | tr '[:lower:]' '[:upper:]')"
SECILEN=""
if [ "$HEDEF_UPPER" = "ALL" ]; then
  SECILEN="$MEMBERS"
else
  SECILEN="$(printf '%s\n' "$MEMBERS" | awk -F'\t' -v h="$HEDEF_UPPER" 'toupper($1)==h')"
  [ -n "$SECILEN" ] || { echo "HATA: bilinmeyen ajan '$HEDEF' — registry-id kullan ($KNOWN_IDS) ya da all" >&2; exit 1; }
fi

# --- gönder ---
SENT=0; MISSING=0; SELF=0; BLOCKED=0
while IFS=$'\t' read -r ID TARGET; do
  [ -n "$ID" ] || continue
  SESSION="${TARGET%%:*}"
  if [ -n "$CALLER_SESSION" ] && [ "$SESSION" = "$CALLER_SESSION" ]; then
    echo "atla(self): $ID ($TARGET) — çağıran-oturum, self-loop koruması" >&2
    SELF=$((SELF+1)); continue
  fi
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "UYARI: $ID oturumu YOK ($SESSION) — ping atlandı (Claude o kimlikte açık değil?)" >&2
    MISSING=$((MISSING+1)); continue
  fi
  # ÖN-UÇUŞ (PARÇA-2): hedef boşta değilse DUR — kör-tetik önlenir (--force ile bypass).
  if [ "$FORCE" -ne 1 ]; then
    STATE="$(preflight_state "$TARGET")"
    if [ "$STATE" != "idle" ]; then
      echo "DUR: $ID ($TARGET) durum=$STATE — tetik güvenli-değil; çağıran karar-versin (--force ile bypass)" >&2
      BLOCKED=$((BLOCKED+1)); continue
    fi
  fi
  # KRİTİK-FİX (Nexus canlı-test 2026-07-06): gömülü-Enter (metin+Enter tek çağrıda)
  # Claude-Code TUI'de submit ETMİYOR — metin composer'a düşüyor ama gönderilmiyor. Fix = 3-adım:
  # (a) C-u ile olası-leftover'ı temizle · (b) metni yaz · (c) bracketed-paste otursun diye kısa-bekle ·
  # (d) AYRI çağrıda Enter → bu kez submit ateşler. Bu 4 satırı DEĞİŞTİRME (birleştirme = regresyon).
  # (3-adım-ayrı-Enter mekaniği KORUNUR — yalnız hata-guard'ı eklendi; adımlar BİRLEŞTİRİLMEDİ.)
  tmux send-keys -t "$TARGET" C-u 2>/dev/null || true
  if ! tmux send-keys -t "$TARGET" -- "$MESAJ" 2>/dev/null; then
    echo "UYARI: $ID send-keys başarısız ($TARGET) — oturum kayboldu/yeniden-adlandı? atlandı (batch sürüyor)" >&2
    MISSING=$((MISSING+1)); continue
  fi
  sleep 0.4
  tmux send-keys -t "$TARGET" Enter 2>/dev/null || true
  echo "gönderildi: $ID → $TARGET"
  SENT=$((SENT+1))
done <<< "$SECILEN"

echo "ozet: gonderildi=$SENT atlandi_self=$SELF eksik_oturum=$MISSING engellendi=$BLOCKED"
if [ "$MISSING" -gt 0 ] || [ "$BLOCKED" -gt 0 ] || [ "$SENT" -eq 0 ]; then exit 1; fi
exit 0
