#!/usr/bin/env bash
# ekip-durum.sh — ekip tek-bakış durum tablosu (SALT-OKUR: hiçbir pane'e/dosyaya YAZMAZ)
# Kullanım: scripts/ekip-durum.sh [--watch N | --nudge | --porcelain]
# Exit: 0=sakin · 1=bekleyen-var · 2=usage · 3=oturum/registry-sorunu
# Kaynak-desen: ekip-kur master-skill (koordinasyon substratı).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
SINYAL_LOG="${EKIP_SINYAL_LOG:-$REPO_ROOT/_agents/handoff/ekip-sinyal.log}"
BRIEF="$REPO_ROOT/_agents/handoff/ekip-brief.md"
LIB="$SCRIPT_DIR/ekip-preflight.lib.sh"
[ -f "$LIB" ] && . "$LIB" || true            # lib yoksa DURUM sütunu 'lib-yok' (zarif-bozulma)

WATCH=0; MODE=tablo
case "${1:-}" in
  --watch) WATCH="${2:-5}"; [[ "$WATCH" =~ ^[0-9]+$ ]] || { echo "usage: ekip-durum.sh [--watch N|--nudge|--porcelain]" >&2; exit 2; } ;;
  --nudge) MODE=nudge ;;   # yönetici Stop-hook PULL→PUSH — bekleyen ACK'sız sinyali idle-anında yüzeye çıkar
  --porcelain) MODE=porcelain ;;   # durum-skill: makine-okunur çıkış (/durum skill bunu tüketir → Sultan-dili çevirir)
  "") : ;;
  *) echo "usage: ekip-durum.sh [--watch N|--nudge|--porcelain]" >&2; exit 2 ;;
esac
[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 3; }

# PARSE_PY — ekip-notify.sh ile BİRE-BİR AYNI 3-alan parse (senkron tut; tek kasıtlı-kopya).
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
# set-e-crash önlemi: python3 yoksa komut-ikamesi set -e altında scripti öldürür → önce preflight.
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil (registry-parse için gerekir)" >&2; exit 3; }
MEMBERS="$(python3 -c "$PARSE_PY" "$REGISTRY")"
[ -n "$MEMBERS" ] || { echo "HATA: registry parse boş — biçim bozuk olabilir: $REGISTRY" >&2; exit 3; }

# yönetici çözümleyici: meta.yonetici'den oku; boşsa fallback = registry'de İLK-listelenen üye + uyarı (yönetici-hardcode YOK)
UYE_ILK="$(printf '%s\n' "$MEMBERS" | awk -F'\t' 'NR==1{print toupper($1); exit}')"
coz_yonetici() {
  local y
  y="$(grep -E '^[[:space:]]*yonetici:' "$REGISTRY" 2>/dev/null | head -1 | sed 's/.*yonetici:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')"
  if [ -z "$y" ]; then
    y="$UYE_ILK"
    echo "⚠️ meta.yonetici tanımsız → ilk-üye $y varsayıldı; ekip-registry.yaml meta.yonetici alanına ekle" >&2
  fi
  printf '%s' "$y"
}

tek_tur() {
  local BEKLEYEN=() BEKLEYEN_DETAY=() SORUN=0 CANLI REGSESS="" ID TARGET INBOX SESSION VAR DURUM SC SO BS DELTA
  local DSINIF GATE GSIG NEDEN YONETICI CALISAN=0 SERBEST=0 BSFULL
  # durum-skill: ham-sınıfı Sultan-nötr etikete indir (ham 'idle'/emoji sızmaz; skill sözlükle çevirir)
  porc_sinif() { case "$1" in
      busy) echo calisir ;; 🟢serbest|idle) echo serbest ;; 🟡bekliyor) echo bekliyor ;;
      draft!) echo draft ;; menu) echo menu ;; compact) echo compact ;; -) echo yok ;; *) echo "$1" ;;
    esac; }
  # akış-fix: yönetici (BEKLEYEN'den muaf) + yumuşak-kapı imleri (idle-bekliyor tespiti)
  YONETICI="$(coz_yonetici)"
  # 🟡=gerçek-kapı (yönetici-kararı/onayı bekleyen). NOT: 'stand-ready/bekliyorum/beklemedey' = işi-bitmiş-SERBEST
  # (yeni-iş-bekler) → 🟢; onları 🟡 sayma (yoksa BEKLEYEN listesi kirlenir). Güvenilir-yol = FIX-1 --waiting sinyali.
  local WAITING_RE="${WAITING_RE:-devam mı|onay bekli|needs_serdar|dalga.?kapı|/compact öner|yön bekli|karar bekli|onay bekle|sende bekle|land bekli|soru.{0,6}bekli}"
  CANLI="$(tmux ls -F '#{session_name}' 2>/dev/null || true)"
  [ "$MODE" = porcelain ] || printf '%-13s %-16s %-12s %-7s %-9s\n' UYE OTURUM DURUM SINYAL BRIEF-SON
  while IFS=$'\t' read -r ID TARGET INBOX; do
    [ -n "$ID" ] || continue
    SESSION="${TARGET%%:*}"; REGSESS="$REGSESS $SESSION"
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then VAR="YOK"; DURUM="-"; SORUN=$((SORUN+1))
    else
      VAR="✓"
      if declare -F preflight_state >/dev/null; then
        DURUM="$(preflight_state "$TARGET")"
        if [ "$DURUM" = idle ] && declare -F composer_kind >/dev/null; then
          case "$(composer_kind "$TARGET")" in draft:*) DURUM="draft!";; esac
        fi
      else DURUM="lib-yok"; fi
    fi
    SC=0; SO=""
    if [ -f "$SINYAL_LOG" ]; then
      read -r SC SO < <(awk -F'|' -v id="$ID" '
        # NOT: TYPE "blocked" ŞU AN ÖLÜ-DAL — ekip-notify.sh yalnız done/ack/ping/waiting yazar. İleriye-dönük
        # rezerve (gelecek `--blocked` self-report modu için): üye kendini-bloklu bildirince done ile aynı
        # pending-kanalı kullanacak. Kaldırma; --blocked eklenince tek-satır aktifleşir.
        $3 ~ /^(done|blocked|waiting)$/ && $4==id { pend[$1]=$7 }
        $3=="ack" { r=$7; sub(/^ref=/,"",r); delete pend[r] }
        END { n=0; last=""; for (s in pend) { n++; last=pend[s] } print n "\t" last }' "$SINYAL_LOG") || true
    fi
    BS="$(grep -E "^### ${ID} ·" "$BRIEF" 2>/dev/null | tail -1 | awk -F' · ' '{print $2}')" || true
    # akış-fix: idle/compact'i serbest(🟢) vs bekliyor(🟡) ayır — 'idle=işim-yok' ile
    # 'idle=kapıda-yön-bekliyorum' kör-noktasını kapat. Bekliyor = ACK'sız-sinyal (SC>0) YA DA pane-kapı-imi.
    DSINIF="$DURUM"; GATE=""
    if [ "$ID" != "$YONETICI" ] && { [ "$DURUM" = idle ] || [ "$DURUM" = compact ]; }; then
      GSIG="$(tmux capture-pane -p -t "$TARGET" 2>/dev/null | tail -12 | grep -ioE "$WAITING_RE" | tail -1 || true)"
      [ -n "$GSIG" ] && GATE="$GSIG"
      if [ "${SC:-0}" -gt 0 ] || [ -n "$GATE" ]; then DSINIF="🟡bekliyor"; else DSINIF="🟢serbest"; fi
    fi
    NEDEN="-"
    if [ "$ID" != "$YONETICI" ] && [ "$DSINIF" = "🟡bekliyor" ]; then
      NEDEN="${GATE:-${SO:-$( [ "${SC:-0}" -gt 0 ] && echo "${SC}-ACK'sız-sinyal" )}}"   # kapı-imi > sinyal-özeti > sayı
      BEKLEYEN+=("$ID")
      BEKLEYEN_DETAY+=("⏳ $ID bekliyor: ${NEDEN:-?} · son-KONUM: ${BS:-—}")
    fi
    case "$DSINIF" in busy) CALISAN=$((CALISAN+1)) ;; 🟢serbest|idle) SERBEST=$((SERBEST+1)) ;; esac
    if [ "$MODE" = porcelain ]; then
      # 6-alan TAB kontratı: ID⇥oturum(1/0)⇥sınıf⇥sinyal⇥neden⇥son-KONUM(TAM brief-satırı, kırpılmamış → skill çevirir)
      BSFULL="$(grep -E "^### ${ID} ·" "$BRIEF" 2>/dev/null | tail -1 | sed 's/^### //; s/\t/ /g')" || true
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ID" "$([ "$VAR" = ✓ ] && echo 1 || echo 0)" \
        "$(porc_sinif "$DSINIF")" "${SC:-0}" "${NEDEN:--}" "${BSFULL:--}"
    else
      printf '%-13s %-16s %-12s %-7s %-9s\n' "$ID" "$SESSION $VAR" "$DSINIF" "$( [ "${SC:-0}" -gt 0 ] && echo "${SC}!" || echo - )" "${BS:--}"
    fi
  done <<< "$MEMBERS"
  if [ "$MODE" = porcelain ]; then
    printf '#OZET\tcalisan=%s\tserbest=%s\tbekliyor=%s\tbekleyenler=%s\n' \
      "$CALISAN" "$SERBEST" "${#BEKLEYEN[@]}" "$(IFS=,; echo "${BEKLEYEN[*]}")"
    return $([ "${#BEKLEYEN[@]}" -gt 0 ] && echo 1 || echo 0)
  fi
  if [ "${#BEKLEYEN[@]}" -gt 0 ]; then
    echo "⏳ BEKLİYOR (${#BEKLEYEN[@]}): ${BEKLEYEN[*]}"
    # akış-fix: her bekleyen için neden + son-KONUM tek-satır → yönetici bekletmeden yön-versin
    for d in "${BEKLEYEN_DETAY[@]}"; do echo "   $d"; done
  fi
  # churn-algısı: registry-dışı cc-* oturumları + eksik oturumlar birlikte = bayat-registry işareti
  DELTA="$(printf '%s\n' $CANLI | grep -E '^cc-' | grep -vFf <(printf '%s\n' $REGSESS) || true)"
  if [ "$SORUN" -gt 0 ]; then
    echo "⚠ registry-bayat-olabilir: $SORUN oturum eksik${DELTA:+ · tmux-tarafı registry-dışı cc-*: $(echo $DELTA)} → reconcile: tmux ls ↔ ekip-registry.yaml" >&2
  fi
  if [ -f "$SINYAL_LOG" ]; then
    local L B; L="$(wc -l < "$SINYAL_LOG")"; B="$(wc -c < "$SINYAL_LOG")"
    [ "$L" -gt 500 ] || [ "$B" -gt 102400 ] && echo "⚠ sinyal-defteri büyüdü ($L satır) → rotasyon: mv ekip-sinyal.log ekip-sinyal-$(date +%Y%m%d).log" >&2
  fi
  [ "${#BEKLEYEN[@]}" -gt 0 ] && return 1
  [ "$SORUN" -gt 0 ] && return 3
  return 0
}

# ── nudge modu (yönetici Stop-hook PULL→PUSH) ───────────────────────────────
# Yalnız YÖNETİCİ (registry meta.yonetici) oturumunda + bekleyen ACK'sız sinyal VARSA
# additionalContext JSON basar (Claude Code Stop-hook şeması; turu BLOKLAMAZ). Aksi=sessiz exit 0.
# Çağıran-kimlik: EKIP_NUDGE_SESSION env (test) > stdin session_id → cc-<id8> > tmux. Debounce=aynı-sinyal-seti iki-kez basılmaz.
nudge_mode() {
  local YONETICI CALLER CALLER_ID SID N REFS SUMM SIG CACHE
  YONETICI="$(coz_yonetici)"
  # çağıran tmux-session adı
  CALLER="${EKIP_NUDGE_SESSION:-}"
  if [ -z "$CALLER" ] && [ ! -t 0 ]; then
    SID="$(cat 2>/dev/null | python3 -c 'import sys,json;
try: print(json.load(sys.stdin).get("session_id",""))
except: print("")' 2>/dev/null || true)"
    [ -n "$SID" ] && CALLER="cc-${SID:0:8}"
  fi
  [ -z "$CALLER" ] && CALLER="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
  [ -n "$CALLER" ] || exit 0   # kimlik yok → sessiz (regresyon-yok)
  # çağıran-session → registry üye-id (tmux session-parçası eşleşir)
  CALLER_ID="$(awk -F'\t' -v s="$CALLER" '{split($2,a,":"); if(a[1]==s){print $1; exit}}' <<< "$MEMBERS")"
  # akış-fix: ÜYE Stop-hook oto-backstop — üye yumuşak-kapıya gelip turu-bitirince (--waiting emit etmeyi
  # unutursa) pane-imini tespit edip yönetici'ye OTOMATİK waiting-sinyali at. Üyenin sessiz-kapıda-bekleme
  # başarısızlık-modunu kapatır. Sıfır-disiplin gerektirir.
  if [ -n "$CALLER_ID" ] && [ "$CALLER_ID" != "$YONETICI" ]; then
    local WRE TAIL SIG DBKEY
    WRE="${WAITING_RE:-devam mı|onay bekli|needs_serdar|dalga.?kapı|/compact öner|yön bekli|karar bekli|onay bekle|sende bekle|land bekli|soru.{0,6}bekli}"
    TAIL="$(tmux capture-pane -p 2>/dev/null | tail -15)"
    DBKEY="${XDG_CACHE_HOME:-$HOME/.cache}/ekip-waiting-$CALLER_ID"
    if printf '%s' "$TAIL" | grep -qiE "$WRE"; then
      SIG="$(printf '%s' "$TAIL" | grep -ioE "$WRE" | tail -1)"
      if [ "$(cat "$DBKEY" 2>/dev/null || true)" != "$SIG" ]; then   # debounce: aynı kapı tekrar-emit etme
        bash "$SCRIPT_DIR/ekip-notify.sh" --waiting "kapı: $SIG (Stop-hook oto-tespit)" >/dev/null 2>&1 || true
        mkdir -p "$(dirname "$DBKEY")" 2>/dev/null || true; printf '%s' "$SIG" > "$DBKEY" 2>/dev/null || true
      fi
    else rm -f "$DBKEY" 2>/dev/null || true; fi   # kapıdan çıktı → debounce sıfırla
    exit 0
  fi
  [ "$CALLER_ID" = "$YONETICI" ] || exit 0   # yalnız yönetici nudge'lanır
  [ -f "$SINYAL_LOG" ] || exit 0
  # global bekleyen (ACK'sız done/blocked/waiting, tüm üyeler): sayı + ref-listesi + özet
  read -r N REFS SUMM < <(awk -F'|' '
    $3 ~ /^(done|blocked|waiting)$/ { pend[$1]=$4"("$7")"; ref[$1]=$1 }
    $3=="ack" { r=$7; sub(/^ref=/,"",r); delete pend[r]; delete ref[r] }
    END { n=0; rr=""; ss=""; for (s in pend){ n++; rr=rr s ","; ss=ss pend[s]"; " } print n "\t" rr "\t" ss }' "$SINYAL_LOG") || true
  [ "${N:-0}" -gt 0 ] || exit 0   # bekleyen yok → sessiz
  # debounce: aynı sinyal-seti daha önce nudge'landıysa tekrar basma
  SIG="$(printf '%s' "$REFS" | tr ',' '\n' | sort | tr '\n' ',')"
  CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ekip-nudged-sids"
  if [ -f "$CACHE" ] && [ "$(cat "$CACHE" 2>/dev/null)" = "$SIG" ]; then exit 0; fi
  mkdir -p "$(dirname "$CACHE")" 2>/dev/null || true
  printf '%s' "$SIG" > "$CACHE" 2>/dev/null || true
  # additionalContext enjekte (Stop-hook; turu bloklamaz) — sır-yok, kısa
  python3 - "$N" "$SUMM" <<'PY'
import json,sys
n=sys.argv[1]; summ=(sys.argv[2] or "").strip().rstrip(";").strip()
msg=(f"📟 {n} bekleyen ekip-sinyali (ACK'sız): {summ}. "
     f"`bash scripts/ekip-durum.sh` ile bak, ilgili kanalları oku, iş bitince `ekip-notify.sh --ack <SID>`.")
print(json.dumps({"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":msg}}))
PY
  exit 0
}

if [ "$MODE" = nudge ]; then nudge_mode; exit 0; fi

if [ "$WATCH" -gt 0 ]; then
  while true; do clear; date -Is; tek_tur || true; sleep "$WATCH"; done
else
  tek_tur
fi
