#!/usr/bin/env bash
# cipa-bul sınavı — var olan çıpaları listeler, olmayanı uydurmaz.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT
mkdir -p "$TMP/akar/tanitim" "$TMP/akar/_agents/durum" "$TMP/bos"
: > "$TMP/akar/DURUM.md"; : > "$TMP/akar/tanitim/ANA-AKS.md"; : > "$TMP/akar/_agents/durum/MUTEVELLI.json"
kapi "C1 AKAR düzeni: üç çıpa bulunur, sıra sabit" "$TMP/akar/DURUM.md $TMP/akar/tanitim/ANA-AKS.md $TMP/akar/_agents/durum/MUTEVELLI.json rc=0" \
  "$(bash "$KOK/cipa-bul.sh" "$TMP/akar" 2>/dev/null | tr '\n' ' '; printf 'rc=%s' "${PIPESTATUS[0]}")"
kapi "C2 çıpasız kutu: rc=1 + tek öneri (uydurma yok)" "rc=1 ÇIPA YOK" "$(bash "$KOK/cipa-bul.sh" "$TMP/bos" 2>&1 >/dev/null | grep -o '^ÇIPA YOK' | sed "s/^/rc=1 /")"
kapi "C2b çıpasız kutuda stdout boş" "" "$(bash "$KOK/cipa-bul.sh" "$TMP/bos" 2>/dev/null)"
kapi "C3 CLAUDE_PROJECT_DIR kök olarak kullanılır" "$TMP/akar/DURUM.md" "$(cd "$TMP/bos" && CLAUDE_PROJECT_DIR="$TMP/akar" bash "$KOK/cipa-bul.sh" 2>/dev/null | head -1)"
printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
