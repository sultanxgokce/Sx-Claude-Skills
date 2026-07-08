#!/usr/bin/env bash
# ekip-notify.sh — ekip tmux-tetik + sinyal-defteri (iki-yön koordinasyon primitifi)
# Kaynak-desen: ekip-kur master-skill (koordinasyon substratı; canlı-kanıtlanmış ekip-notify deseni).
#
# OMURGA-DOKTRİN: ÖNCE sinyal-defteri (kaynak-gerçek), SONRA tmux-ping (best-effort hızlandırıcı).
#   Ping bloklansa da sinyal kaybolmaz → yönetici ekip-durum.sh ile toplar.
#
# Davranış: registry'den hedef tmux-oturum çözer (python3 line-based; yq gerekmez) · self-loop atlar
#   ($TMUX_PANE) · send-öncesi preflight+ghost-vs-draft guard (ekip-preflight.lib.sh varsa) ·
#   gönderim-sonrası iletim-doğrular (dürüst-3-durum; 'okundu' İDDİA ETMEZ).
# Değişmez: sır-değer TAŞIMAZ · kardeş dosyalarına DOKUNMAZ (yalnız tmux-tetik + sinyal-defteri append).
# Exit: 0=tamam · 1=runtime(eksik/bloklu/hiç-gönderilemedi/bilinmeyen-ajan) · 2=usage ·
#       3=done: defter-yazıldı ama ping-ulaşmadı (yönetici meşgul/oturum-yok) · 4=strict-ack: iletim-doğrulanamadı.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"   # env-override yalnız test/scratch içindir
SINYAL_LOG="${EKIP_SINYAL_LOG:-$REPO_ROOT/_agents/handoff/ekip-sinyal.log}"
PREFLIGHT_LIB="$SCRIPT_DIR/ekip-preflight.lib.sh"
# shellcheck source=/dev/null
[ -f "$PREFLIGHT_LIB" ] && . "$PREFLIGHT_LIB"

usage() {
  cat >&2 <<'EOF'
Kullanım:
  ekip-notify.sh <ajan|all> "<mesaj>"        # ping (klasik pozisyonel-kontrat — KORUNUR)
  ekip-notify.sh --done "<tek-satır özet>"   # üye→yönetici: iş-bitti (önce-defter-sonra-ping)
  ekip-notify.sh --waiting "<kapı-nedeni>"   # üye→yönetici: yumuşak-kapıda yön-bekliyor (FIX-1 kör-nokta)
  ekip-notify.sh --ack <SID>                 # yönetici: sinyali tüketildi-işaretle
  ekip-notify.sh --check <ajan|all>          # dry-run: pane-durum/composer teşhisi (göndermez)
  ekip-notify.sh --force <ajan> "<mesaj>"    # preflight/draft-guard'ı bilinçli-aş
  ekip-notify.sh --strict-ack ...            # iletim-doğrulanamayan varsa exit 4
    <ajan> ∈ ekip-registry.yaml'deki bir üye-id (case-insensitive) veya "all"
EOF
  exit 2
}

# sinyal-defteri: append-only tek-satır (O_APPEND, satır<~300B → pratik-atomik; SIR-DEĞER YAZILMAZ)
sinyal_yaz() {  # $1=TYPE $2=FROM $3=TO $4=DURUM $5=OZET → stdout: SID
  local ts sid ozet
  ts="$(date -Is)"; sid="$(date +%s)-$2-$$"
  ozet="$(printf '%s' "$5" | tr '\n|' '  ' | cut -c1-200)"
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$sid" "$ts" "$1" "$2" "$3" "$4" "$ozet" >> "$SINYAL_LOG" || return 1
  printf '%s' "$sid"
}

# --- bayrak-tarama → MODE/FORCE/STRICT_ACK/POS ---
FORCE="${FORCE:-0}"; MODE=ping; STRICT_ACK="${STRICT_ACK:-0}"; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --force)      FORCE=1 ;;
    --done)       MODE=done ;;
    --waiting)    MODE=waiting ;;
    --ack)        MODE=ack ;;
    --check)      MODE=check ;;
    --strict-ack) STRICT_ACK=1 ;;
    --*)          echo "HATA: bilinmeyen bayrak: $1" >&2; usage ;;
    *)            POS+=("$1") ;;
  esac
  shift
done
case "$MODE" in
  ping)  [ "${#POS[@]}" -ge 2 ] || usage; HEDEF="${POS[0]}"; MESAJ="${POS[1]}" ;;
  check) [ "${#POS[@]}" -ge 1 ] || usage; HEDEF="${POS[0]}"; MESAJ="" ;;
  done)    [ "${#POS[@]}" -ge 1 ] || usage; DONE_OZET="${POS[0]}" ;;
  waiting) [ "${#POS[@]}" -ge 1 ] || usage; WAIT_NEDEN="${POS[0]}" ;;   # FIX-1: üye kapı-nedeni
  ack)     [ "${#POS[@]}" -ge 1 ] || usage; ACK_SID="${POS[0]}" ;;
esac

[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "HATA: tmux kurulu değil (command -v tmux boş)" >&2; exit 1; }
# set-e-crash önlemi: python3 yoksa aşağıdaki MEMBERS="$(python3 …)" komut-ikamesi
# set -e altında sessiz-127 ile scripti öldürür ([ -n "$MEMBERS" ] guard'ı hiç çalışmaz). Önce preflight.
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil (registry-parse için gerekir)" >&2; exit 1; }

# --- registry parse: 'ID<TAB>tmux<TAB>inbox' (python3 line-based; inbox opsiyonel→boş) ---
PARSE_PY='
import re, sys
cur = None; tmux = None; inbox = ""
def flush():
    global cur, tmux, inbox
    if cur and tmux is not None:
        print(cur + "\t" + tmux + "\t" + inbox)
    cur = None; tmux = None; inbox = ""
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m:
        flush(); cur = m.group(1); continue
    m = re.match(r"\s*tmux:\s*\"?([^\"\s]+)\"?", line)
    if m and cur:
        tmux = m.group(1); continue
    m = re.match(r"\s*inbox:\s*\"?([^\"#\s]*)\"?", line)
    if m and cur:
        inbox = m.group(1); continue
flush()
'
MEMBERS="$(python3 -c "$PARSE_PY" "$REGISTRY")"
[ -n "$MEMBERS" ] || { echo "HATA: registry parse boş — biçim bozuk olabilir: $REGISTRY" >&2; exit 1; }

# --- yönetici (--done hedefi): meta.yonetici'den oku; boşsa fallback = registry'de İLK-listelenen üye + uyarı ---
YONETICI="$(awk '/^meta:/{m=1;next} /^[^[:space:]#]/{m=0} m && $1=="yonetici:"{print toupper($2); exit}' "$REGISTRY")"
if [ -z "$YONETICI" ]; then
  YONETICI="$(printf '%s\n' "$MEMBERS" | awk -F'\t' 'NR==1{print toupper($1); exit}')"
  echo "⚠️ meta.yonetici tanımsız → ilk-üye $YONETICI varsayıldı; ekip-registry.yaml meta.yonetici alanına ekle" >&2
fi

# --- self-loop + FROM: çağıran tmux-oturumunu $TMUX_PANE'den çöz (varsa) ---
CALLER_SESSION=""
if [ -n "${TMUX_PANE:-}" ]; then
  CALLER_SESSION="$(tmux list-panes -a -F '#{pane_id} #{session_name}' 2>/dev/null \
    | awk -v p="$TMUX_PANE" '$1==p {print $2; exit}')"
fi
FROM_ID=""
if [ -n "$CALLER_SESSION" ]; then
  FROM_ID="$(printf '%s\n' "$MEMBERS" | awk -F'\t' -v s="$CALLER_SESSION" \
    '{split($2,a,":"); if(a[1]==s){print toupper($1); exit}}')"
fi

# --- MODE: ack (erken-çıkış) ---
if [ "$MODE" = "ack" ]; then
  [ -f "$SINYAL_LOG" ] || { echo "HATA: sinyal-defteri yok: $SINYAL_LOG" >&2; exit 1; }
  # SID'i BRE-desen olarak değil, alan-tam-eşleşmesiyle ara (SID metachar taşımaz ama exact-match kanonik).
  awk -F'|' -v s="$ACK_SID" '$1==s{f=1} END{exit !f}' "$SINYAL_LOG" || { echo "HATA: SID bulunamadı: $ACK_SID" >&2; exit 1; }
  sinyal_yaz ack "${FROM_ID:-$YONETICI}" "-" tuketildi "ref=$ACK_SID" >/dev/null
  echo "ack: $ACK_SID tüketildi-işaretlendi"; exit 0
fi

# --- MODE: done (önce-defter; sonra ping'e düşer) ---
if [ "$MODE" = "done" ]; then
  FROM="${FROM_ID:-BILINMEYEN}"
  [ "$FROM" = "BILINMEYEN" ] && echo "UYARI: gönderen çözülemedi (tmux-dışı ya da registry-bayat/churn) — sinyal yine de deftere düşer" >&2
  FROM_KANAL="$(printf '%s\n' "$MEMBERS" | awk -F'\t' -v f="$FROM" 'toupper($1)==f{print $3; exit}')"
  [ -n "$FROM_KANAL" ] || FROM_KANAL="_agents/handoff/ekip-brief.md"
  SID="$(sinyal_yaz done "$FROM" "$YONETICI" yeni "$DONE_OZET")" \
    || { echo "HATA: sinyal-defterine yazılamadı: $SINYAL_LOG" >&2; exit 1; }
  echo "sinyal: $SID deftere yazıldı (önce-defter-sonra-ping)"
  HEDEF="$YONETICI"
  MESAJ="✅ ${FROM} iş-bitti: ${DONE_OZET} → ${FROM_KANAL} oku (sinyal: ${SID})"
fi

# --- MODE: waiting (FIX-1 üye-kapı-sinyali; --done kardeşi: önce-defter-sonra-ping yöneticiye) ---
if [ "$MODE" = "waiting" ]; then
  FROM="${FROM_ID:-BILINMEYEN}"
  [ "$FROM" = "BILINMEYEN" ] && echo "UYARI: gönderen çözülemedi — waiting-sinyali yine de deftere düşer" >&2
  SID="$(sinyal_yaz waiting "$FROM" "$YONETICI" bekliyor "$WAIT_NEDEN")" \
    || { echo "HATA: sinyal-defterine yazılamadı: $SINYAL_LOG" >&2; exit 1; }
  echo "waiting: $SID deftere (kapı-sinyali → yönetici)"
  HEDEF="$YONETICI"
  MESAJ="⏳ ${FROM} kapıda-bekliyor: ${WAIT_NEDEN} (sinyal: ${SID})"
fi

# --- MODE: ping — kazara-kısa-mesaj guard'ı (kazara-'1' vakası sınıfı) ---
if [ "$MODE" = "ping" ]; then
  [ -n "$(printf '%s' "$MESAJ" | tr -d '[:space:]')" ] || { echo "HATA: boş mesaj" >&2; exit 2; }
  # NOT: ${KISA_RE:-...} default-expansion KULLANMA — default içindeki {1,2}'nin '}' ı
  # ${...} parametre-genişlemesini erken kapatır (brace-collision) → regex bozulur, guard ateşlemez.
  # Düz if-guard + tek-tırnak: override korunur, {1,2} güvenli.
  [ -n "${KISA_RE:-}" ] || KISA_RE='^[[:space:]]*[0-9yYnNqQ]{1,2}[[:space:]]*$'
  if [ "$FORCE" -eq 0 ] && printf '%s' "$MESAJ" | grep -qE "$KISA_RE"; then
    echo "HATA: mesaj çıplak menü-yanıtı görünümlü ('$MESAJ') — kazara-'1' koruması; bilinçliysen --force" >&2
    exit 1
  fi
fi

# --- hedef listesi seç (all → tüm üyeler; tek → id case-insensitive) ---
HEDEF_UPPER="$(printf '%s' "$HEDEF" | tr '[:lower:]' '[:upper:]')"
SECILEN=""
if [ "$HEDEF_UPPER" = "ALL" ]; then
  SECILEN="$MEMBERS"
else
  SECILEN="$(printf '%s\n' "$MEMBERS" | awk -F'\t' -v h="$HEDEF_UPPER" 'toupper($1)==h')"
  if [ -z "$SECILEN" ]; then
    IDLIST="$(printf '%s\n' "$MEMBERS" | awk -F'\t' '{printf "%s|",toupper($1)} END{print "all"}')"
    echo "HATA: bilinmeyen ajan '$HEDEF' — registry-id kullan ($IDLIST)" >&2; exit 1
  fi
fi

# --- MODE: check (dry-run teşhis; hiçbir pane'e YAZMAZ) ---
if [ "$MODE" = "check" ]; then
  while IFS=$'\t' read -r ID TARGET INBOX; do
    [ -n "$ID" ] || continue
    if ! tmux has-session -t "${TARGET%%:*}" 2>/dev/null; then printf '%s: oturum-YOK\n' "$ID"; continue; fi
    printf '%s: preflight=%s composer=%s\n' "$ID" \
      "$(declare -F preflight_state >/dev/null && preflight_state "$TARGET" || echo lib-yok)" \
      "$(declare -F composer_kind >/dev/null && composer_kind "$TARGET" || echo lib-yok)"
  done <<< "$SECILEN"
  exit 0
fi

# --- gönder (guard'lı: önce-oku-sonra-gönder; otomatik-interrupt ASLA) ---
SENT=0; MISSING=0; SELF=0; BLOCKED=0; VERIFIED=0; UNVERIFIED=0
while IFS=$'\t' read -r ID TARGET INBOX; do
  [ -n "$ID" ] || continue
  SESSION="${TARGET%%:*}"
  if [ -n "$CALLER_SESSION" ] && [ "$SESSION" = "$CALLER_SESSION" ]; then
    echo "atla(self): $ID ($TARGET) — çağıran-oturum, self-loop koruması" >&2
    SELF=$((SELF+1)); continue
  fi
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "UYARI: $ID oturumu YOK ($SESSION) — ping atlandı (Claude o kimlikte açık değil?)" >&2
    MISSING=$((MISSING+1))
    sinyal_yaz ping "${FROM_ID:-HARICI}" "$ID" oturum-yok "$MESAJ" >/dev/null 2>&1 || true
    continue
  fi
  # --- P2 preflight + R2 ghost-vs-draft (send'den ÖNCE oku; belirsiz→DUR; otomatik-interrupt ASLA) ---
  if [ "$FORCE" -eq 0 ] && declare -F preflight_state >/dev/null; then
    PF="$(preflight_state "$TARGET")"
    # FIX-0 (akış-fix): 'compact' = quiescent-composer (compact ÖNERİSİ/tartışması görünür pane ≠ aktif-compaction;
    # keystroke düşer) → TESLİM ET. Yalnız gerçek-meşgul (busy/menu) VE aktif-compaction (Compacting|Summarizing
    # görünür) blokla — yoksa 'compact yapayım' metni yüzünden meşru ping'ler yanlışlıkla bloklanır.
    BLOK=""
    case "$PF" in
      busy|menu) BLOK="$PF" ;;
      compact)   tmux capture-pane -p -t "$TARGET" 2>/dev/null | tail -25 | grep -qE "${COMPACTING_RE:-Compacting|Summarizing conversation}" && BLOK="aktif-compaction" ;;
    esac
    if [ -n "$BLOK" ]; then
      echo "ENGEL: $ID pane-durumu='$BLOK' — göndermiyorum; bilinçliysen --force" >&2
      BLOCKED=$((BLOCKED+1))
      sinyal_yaz ping "${FROM_ID:-HARICI}" "$ID" engellendi "$MESAJ" >/dev/null 2>&1 || true
      continue
    fi
    if declare -F composer_kind >/dev/null; then
      CK="$(composer_kind "$TARGET")"
      case "$CK" in
        draft:*)
          echo "ENGEL: $ID composer'ında GERÇEK-TASLAK: '${CK#draft:}…' — C-u bunu SİLERDİ." >&2
          echo "       çözüm: üye taslağı göndersin/bıraksın YA DA --force (taslak silinir, bilinçli)." >&2
          BLOCKED=$((BLOCKED+1))
          sinyal_yaz ping "${FROM_ID:-HARICI}" "$ID" engellendi "draft-guard: $MESAJ" >/dev/null 2>&1 || true
          continue ;;
        ghost|empty) : ;;   # ghost = silik-öneri (yeni-yazımda gider) → GÖNDER
      esac
    fi
  fi
  # --- 3-adım send (gömülü-Enter TUI'de submit ETMEZ → C-u ayrı · metin ayrı · 0.4s · Enter ayrı) ---
  tmux send-keys -t "$TARGET" C-u 2>/dev/null || true
  if ! tmux send-keys -t "$TARGET" -- "$MESAJ" 2>/dev/null; then
    echo "UYARI: $ID send-keys başarısız ($TARGET) — hedef ölmüş olabilir; batch sürüyor" >&2
    MISSING=$((MISSING+1))
    sinyal_yaz ping "${FROM_ID:-HARICI}" "$ID" oturum-yok "$MESAJ" >/dev/null 2>&1 || true
    continue
  fi
  sleep 0.4
  tmux send-keys -t "$TARGET" Enter 2>/dev/null || true   # Enter-fail → doğrulama 'dogrulanamadi' yakalar
  SENT=$((SENT+1))
  # --- R4b iletim-doğrulama (dürüst-3-durum; 'okundu' İDDİA ETMEZ; default-exit'i etkilemez) ---
  VERIFY_WAIT="${VERIFY_WAIT:-1.5}"
  PROBE="$(printf '%s' "$MESAJ" | cut -c1-24)"
  sleep "$VERIFY_WAIT"
  SNAP_RC=0; SNAP="$(tmux capture-pane -p -t "$TARGET" -S -120 2>/dev/null)" || SNAP_RC=$?
  COMP_LINE="$(printf '%s' "$SNAP" | grep -E "${COMPOSER_RE:-^│ >}" | tail -1)" || true
  if [ "$SNAP_RC" -ne 0 ]; then DURUM_ILETIM="dogrulanamadi"                              # capture-fail → İDDİA ETME
  elif printf '%s' "$COMP_LINE" | grep -qF -- "$PROBE"; then DURUM_ILETIM="dogrulanamadi" # metin composer'da KALDI
  elif printf '%s' "$SNAP" | grep -qF -- "$PROBE"; then DURUM_ILETIM="iletildi"           # scrollback'te + composer'da değil
  else DURUM_ILETIM="dogrulanamadi"; fi                                                    # render-gecikmesi olabilir
  if [ "$DURUM_ILETIM" = iletildi ]; then
    VERIFIED=$((VERIFIED+1)); echo "gönderildi: $ID → $TARGET (iletildi✓)"
  else
    UNVERIFIED=$((UNVERIFIED+1)); echo "gönderildi: $ID → $TARGET (iletim-DOĞRULANAMADI — pane'e bak)" >&2
  fi
  sinyal_yaz ping "${FROM_ID:-HARICI}" "$ID" "$DURUM_ILETIM" "$MESAJ" >/dev/null 2>&1 || true
done <<< "$SECILEN"

# --- özet + exit (6-alan; eski 3-alan adı/sırası korunur) ---
echo "ozet: gonderildi=$SENT atlandi_self=$SELF eksik_oturum=$MISSING engellendi=$BLOCKED dogrulandi=$VERIFIED dogrulanamadi=$UNVERIFIED"

if [ "$MODE" = "done" ]; then
  if [ "$SENT" -ge 1 ]; then echo "done: sinyal deftere + ping yöneticiye tamam"; exit 0
  else echo "done: sinyal DEFTERDE ama ping ulaşmadı (yönetici meşgul/oturum-yok) — ekip-durum.sh yüzeye çıkarır" >&2; exit 3; fi
fi
if [ "$MISSING" -gt 0 ] || [ "$BLOCKED" -gt 0 ] || [ "$SENT" -eq 0 ]; then exit 1; fi
if [ "$STRICT_ACK" -eq 1 ] && [ "$UNVERIFIED" -gt 0 ]; then exit 4; fi
exit 0
