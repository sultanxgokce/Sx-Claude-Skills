#!/usr/bin/env bash
# cyd — credential-yasam-dongusu CLI (v0.1 İSKELET; SİNAN-spec v1.1)
# Değişmezler: sır=pointer-only (değer basmaz) · fail-closed (emin-değilsen dış-istek YOK) ·
# insan-tetik (cron'dan çağrılmaz). RC: 0=başarı+kanıt · 1=dürüst-fail · 3=gate-bekliyor · 4=ön-koşul-eksik.
set -uo pipefail

CYD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # skill kökü
SIBLING_ROOT="$(cd "$CYD_DIR/.." && pwd)"                     # kardeş-skill kökü (.claude/skills veya Sx-repo)
REQUIRES="vault-cek sunucu-kur erisim"

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

not_impl(){ # <akış> — v0.1 iskelet: dürüst-fail, sıfır dış-istek (fail-closed)
  red "✗ '$1' v0.1'de HENÜZ-UYGULANMADI (iskelet) — T1/T8 tatbikat-dalgasında yazılır."
  red "  Bu çağrı hiçbir dış-istek yapmadı (fail-closed). Sözleşme: SKILL.md §Üç bestelenen-akış."
  return 1
}

cmd_doctor(){
  local rc=0 s
  # 1 · requires-üçlüsü (kardeş-yol çözümü; vendoring-YOK)
  for s in $REQUIRES; do
    if [ -f "$SIBLING_ROOT/$s/SKILL.md" ]; then grn "✓ bileşen: $s"
    else red "✗ bileşen EKSİK: $s (aranan: $SIBLING_ROOT/$s/SKILL.md)"; rc=4; fi
  done
  # 2 · force-bayrak-bekçisi (v1.1 şerh-2: yok-bayrağı mekanik; self-match-safe desen)
  if grep -rEn -- '--forc[e]|--zorl[a]|--skip-gat[e]|--evet-hepsin[e]' "$CYD_DIR/scripts" "$CYD_DIR/SKILL.md" 2>/dev/null | grep -v 'force-bayrak-bekcisi-deseni'; then
    red "✗ HARD-FAIL: force-benzeri bayrak tespit edildi (yok-bayrağı ihlali — spec v1.1 şerh-2)."; rc=1
  else grn "✓ force-bayrak-bekçisi temiz (yok-bayrağı korunuyor)"; fi
  # 3 · özet
  if [ "$rc" -eq 0 ]; then grn "✓ doctor YEŞİL (requires-üçlüsü + bekçi)"; else red "✗ doctor rc=$rc"; fi
  return $rc
}

case "${1:-doctor}" in
  tazele) shift; not_impl "tazele" ;;
  tasi)   shift; not_impl "tasi" ;;
  teshis) shift; not_impl "teshis" ;;
  doctor) cmd_doctor ;;
  *) red "bilinmeyen komut: $1  (tazele <kaynak>|tasi [--dry-run]|teshis [<kaynak>]|doctor)"; exit 2 ;;
esac
