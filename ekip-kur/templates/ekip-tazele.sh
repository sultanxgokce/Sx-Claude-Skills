#!/usr/bin/env bash
# ekip-tazele.sh — /ekibi-tazele'nin TEK-KOMUT motoru: ekipteki hantallığı sırayla TESPİT (+ güvenli-olanı DÜZELT).
#   (a) registry↔tmux reconcile — GÜVENLİ olan otomatik-düzelt (ekip-reconcile.sh)
#   (b) context-ağır üye — best-effort tespit, ASLA otomatik-compact'lemez (ekip-context-scan.sh)
#   (c) kapıda-bekleyen üye — yüzeye-çıkar (ekip-durum.sh --porcelain, 🟡bekliyor satırları)
#   (d) ölü/eksik oturum — bayrakla (ekip-durum.sh --porcelain, oturum=0 satırları + reconcile'ın olu-oturum flag'i)
# Riskli aksiyon (compact tetikleme, bekleyen-üyeye ping) BU SCRIPT'TE YOK — yalnız TESPİT/RAPOR eder;
#   onay-kapılı aksiyonlar `/ekibi-tazele` SKILL.md akışında (AskUserQuestion ile) yürütülür.
# Kullanım: ekip-tazele.sh [--dry-run] [--pct N] [--max-age-min N]
#   --dry-run          registry-reconcile'ı ÖNİZLEME modunda çalıştırır (dosyaya yazmaz)
#   --pct N            context-ağır eşik-yüzdesi (context-scan'e geçer, default 75)
#   --max-age-min N    context-taramasında yalnız son-N-dk değişen transcript (default 30)
# Çıktı: bölüm-başlıklı insan-okur rapor + en sonda TAB `SUMMARY` satırı (script/otomasyon tüketebilir).
# Exit: 0=tamamen-temiz · 1=en-az-bir-madde insan-bakışı bekliyor (fix/flag/heavy/waiting/dead herhangi-biri) · 2=usage
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"

DRYFLAG=(); PCT=75; MAXAGE=30
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)      DRYFLAG=(--dry-run) ;;
    --pct)          shift; PCT="${1:-75}" ;;
    --max-age-min)  shift; MAXAGE="${1:-30}" ;;
    *) echo "usage: ekip-tazele.sh [--dry-run] [--pct N] [--max-age-min N]" >&2; exit 2 ;;
  esac
  shift
done

RECONCILE="$SCRIPT_DIR/ekip-reconcile.sh"
CTXSCAN="$SCRIPT_DIR/ekip-context-scan.sh"
DURUM="$SCRIPT_DIR/ekip-durum.sh"
TS="$(date -Is 2>/dev/null || date)"

echo "═══ EKİBİ-TAZELE RAPORU · $TS · proje=$REPO_ROOT ═══"
echo

# --- (a) registry reconcile ---
echo "── [A] REGİSTRY-RECONCILE ──${DRYFLAG:+ (önizleme/--dry-run)}"
A_OUT=""; A_RC=0
if [ -x "$RECONCILE" ]; then
  A_OUT="$("$RECONCILE" "${DRYFLAG[@]}")" || A_RC=$?
  [ -n "$A_OUT" ] && echo "$A_OUT" || echo "  (fix/flag yok — registry↔tmux tutarlı)"
else
  echo "  ATLANDI: $RECONCILE yok/çalıştırılabilir-değil" >&2
  A_RC=9
fi
echo

# --- (b) context-ağır tarama ---
echo "── [B] CONTEXT-AĞIR ÜYE TARAMASI (best-effort, eşik=%$PCT) ──"
B_OUT=""; B_RC=0
if [ -x "$CTXSCAN" ]; then
  B_OUT="$("$CTXSCAN" --pct "$PCT" --max-age-min "$MAXAGE")" || B_RC=$?
  [ -n "$B_OUT" ] && echo "$B_OUT" || echo "  (canlı/taze transcript bulunamadı)"
else
  echo "  ATLANDI: $CTXSCAN yok/çalıştırılabilir-değil" >&2
  B_RC=9
fi
echo

# --- (c)+(d) kapıda-bekleyen + ölü/eksik oturum (ekip-durum.sh --porcelain reuse) ---
echo "── [C+D] KAPIDA-BEKLEYEN + ÖLÜ/EKSİK OTURUM ──"
WAIT_N=0; DEAD_N=0
if [ -x "$DURUM" ]; then
  set +e
  PORC="$("$DURUM" --porcelain)"   # stderr bilinçli-redirect-edilmedi: durum.sh'in kendi ⚠uyarıları düz-geçsin (görünür kalsın)
  CD_RC=$?
  set -e
  if [ -n "$PORC" ]; then
    while IFS=$'\t' read -r ID SESS SINIF SINYAL NEDEN SONKONUM; do
      [ -n "$ID" ] || continue
      if [ "$ID" = "#OZET" ]; then continue; fi
      if [ "$SESS" = "0" ]; then
        DEAD_N=$((DEAD_N+1))
        echo "  💀 $ID — oturum kapalı/eksik"
      elif [ "$SINIF" = "bekliyor" ]; then
        WAIT_N=$((WAIT_N+1))
        echo "  ⚠️  $ID — kapıda bekliyor: ${NEDEN:-?} (son-KONUM: ${SONKONUM:-—})"
      fi
    done <<< "$PORC"
  fi
  [ "$WAIT_N" -eq 0 ] && [ "$DEAD_N" -eq 0 ] && echo "  (bekleyen/kapalı-oturum yok)"
else
  echo "  ATLANDI: $DURUM yok/çalıştırılabilir-değil" >&2
  CD_RC=9
fi
echo

FIXED_N="$(printf '%s\n' "$A_OUT" | grep -c '^FIX' || true)"
FLAG_N="$(printf '%s\n' "$A_OUT" | grep -c '^FLAG' || true)"
HEAVY_N="$(printf '%s\n' "$B_OUT" | grep -c '^HEAVY' || true)"

echo "═══ ÖZET ═══"
printf 'SUMMARY\tfixed=%s\tflags=%s\theavy=%s\twaiting=%s\tdead=%s\n' "$FIXED_N" "$FLAG_N" "$HEAVY_N" "$WAIT_N" "$DEAD_N"

NEEDS_EYES=$((FLAG_N>0 ? 1 : 0))
[ "$HEAVY_N" -gt 0 ] && NEEDS_EYES=1
[ "$WAIT_N"  -gt 0 ] && NEEDS_EYES=1
[ "$DEAD_N"  -gt 0 ] && NEEDS_EYES=1
[ "$NEEDS_EYES" -eq 1 ] && exit 1
exit 0
