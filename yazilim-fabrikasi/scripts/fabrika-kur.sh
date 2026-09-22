#!/usr/bin/env bash
# fabrika-kur.sh — hat dosyasını (FABRIKA.md) depoya koyar ve drift'i sha ile denetler.
#
# KURAL (Sultan K3, 21 Eyl 2026): hat dosyası her kutuda BİREBİR AYNI, tek kaynak (bu becerinin sablon/FABRIKA.md'si),
# kutu kendi satırını ekleyemez, dev CLAUDE.md'ye GÖMÜLMEZ — yanına konur, CLAUDE.md'ye tek satır işaretçi (@FABRIKA.md).
#
# Kullanım:
#   fabrika-kur.sh kur [depo] [--kanca] [--zorla]   → FABRIKA.md + CLAUDE.md işaretçisi (+ pre-commit kancası)
#   fabrika-kur.sh denetle [depo]                    → 0 eşit · 1 drift/işaretçi yok · 3 dosya yok (ölçülemedi)
#   fabrika-kur.sh sablon-sha                        → şablonun sha256'sı
# rc (kur): 0 kuruldu/zaten kurulu · 1 çakışma (elle değişmiş hat dosyası, --zorla yok) · 3 ölçülemedi
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SABLON="$HERE/../sablon/FABRIKA.md"
ISARET="@FABRIKA.md"
TAVAN=40

_hata() { printf '✗ %s\n' "$*" >&2; }
_bilgi() { printf '%s\n' "$*"; }
sha() { sha256sum "$1" 2>/dev/null | cut -c1-16; }

[ -f "$SABLON" ] || { _hata "şablon yok: $SABLON"; exit 3; }
SATIR="$(wc -l < "$SABLON")"
[ "$SATIR" -le "$TAVAN" ] || { _hata "şablon $SATIR satır — tavan $TAVAN (fazlalık var demektir, kes)"; exit 3; }

depo_bul() {
  local d="${1:-}"
  [ -n "$d" ] || d="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  [ -n "$d" ] && [ -d "$d" ] || { _hata "depo kökü bulunamadı (argüman ver ya da depo içinden çağır)"; exit 3; }
  printf '%s' "$d"
}

isaret_ekle() {
  local cl="$1"
  if [ ! -f "$cl" ]; then
    printf '%s\n' "$ISARET" > "$cl"; _bilgi "✓ CLAUDE.md yoktu, işaretçiyle oluşturuldu"; return 0
  fi
  if grep -qx "$ISARET" "$cl"; then _bilgi "· CLAUDE.md işaretçisi zaten var"; return 0; fi
  local tmp; tmp="$(mktemp)"
  if head -1 "$cl" | grep -q '^#'; then
    { head -1 "$cl"; printf '\n%s\n' "$ISARET"; tail -n +2 "$cl"; } > "$tmp"
  else
    { printf '%s\n\n' "$ISARET"; cat "$cl"; } > "$tmp"
  fi
  cat "$tmp" > "$cl" && rm -f "$tmp"
  _bilgi "✓ CLAUDE.md'ye tek satır işaretçi eklendi ($ISARET)"
}

kur() {
  local depo="" kanca=0 zorla=0 a
  for a in "$@"; do
    case "$a" in --kanca) kanca=1 ;; --zorla) zorla=1 ;; *) depo="$a" ;; esac
  done
  depo="$(depo_bul "$depo")" || exit 3
  local hedef="$depo/FABRIKA.md"
  if [ -f "$hedef" ] && [ "$(sha "$hedef")" != "$(sha "$SABLON")" ] && [ "$zorla" -eq 0 ]; then
    _hata "$hedef şablondan FARKLI (elle değişmiş ya da eski sürüm). Hat dosyası kutuda düzenlenmez;"
    _hata "  fark meşruysa kaynağa (Sx-Claude-Skills) taşı; şablonu yazmak için: --zorla"
    exit 1
  fi
  if [ -f "$hedef" ] && [ "$(sha "$hedef")" = "$(sha "$SABLON")" ]; then
    _bilgi "· FABRIKA.md zaten güncel (sha $(sha "$hedef"))"
  else
    cp "$SABLON" "$hedef" || { _hata "kopyalanamadı"; exit 3; }
    _bilgi "✓ FABRIKA.md kuruldu ($SATIR satır, sha $(sha "$hedef"))"
  fi
  isaret_ekle "$depo/CLAUDE.md"
  if [ "$kanca" -eq 1 ]; then
    IS_ALANI_DEPO="$depo" bash "$HERE/is-alani.sh" kanca-kur || { _hata "kanca kurulamadı"; exit 1; }
  fi
  _bilgi "→ doğrula: bash $HERE/fabrika-kur.sh denetle $depo; echo rc=\$?"
}

denetle() {
  local depo; depo="$(depo_bul "${1:-}")" || exit 3
  local hedef="$depo/FABRIKA.md" rc=0
  if [ ! -f "$hedef" ]; then _bilgi "◻ $hedef YOK — hat kurulmamış (ölçülemedi)"; return 3; fi
  if [ "$(sha "$hedef")" = "$(sha "$SABLON")" ]; then
    _bilgi "✓ FABRIKA.md şablonla birebir (sha $(sha "$hedef"))"
  else
    _bilgi "✗ DRIFT — depo sha $(sha "$hedef") ≠ şablon sha $(sha "$SABLON")"; rc=1
  fi
  if [ -f "$depo/CLAUDE.md" ] && grep -qx "$ISARET" "$depo/CLAUDE.md"; then
    _bilgi "✓ CLAUDE.md işaretçisi var"
  else
    _bilgi "✗ CLAUDE.md'de $ISARET işaretçisi YOK — hat okunmuyor"; rc=1
  fi
  return $rc
}

case "${1:-}" in
  kur)        shift; kur "$@" ;;
  denetle)    shift; denetle "$@" ;;
  sablon-sha) sha256sum "$SABLON" | cut -c1-16 ;;
  *)          sed -n '1,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
