#!/usr/bin/env bash
# ahi — AHÎ 4-Kademe Yetenek Fabrikası · CLI (FAZ-0a kabuk)
# Değişmez: value-safe (sır-değer basmaz) · owner-domain-dokunma (sync-skills.mjs'e yazmaz) · INERT/additive.
set -uo pipefail

AHI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # ahi/ kökü
VERSION="0.1.0"

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

usage() {
  cat <<'EOF'
ahi — AHÎ 4-Kademe Yetenek Fabrikası

KULLANIM: ahi <komut> [argümanlar]

  doctrine            Değişmezler Kitabı'nı (kanon) göster
  tiers [<kademe>]    Kademe-kart(lar)ını göster (cirak|kalfa|usta|pir)
  new <kademe> <ad>   Kademe-seç → standart-iskelet scaffold        [FAZ-1]
  check [<skill>]     Deterministik drift-lint (parity + manifest)  [FAZ-2]
  promote <skill>     Terfi-appraisal → yeşilse Sultan-törenine öner [FAZ-3]
  deprecate <s> "<m>" Soft-emeklilik (deprecated+sunset+successor)   [FAZ-3]
  classify            Yeni-işi anlat → hangi-kademe önerici          [FAZ-4]
  health              Sağlık-panosu                                  [FAZ-4]
  version             Sürüm
  --help | -h         Bu yardım

KADEMELER: Çırak(S1) → Kalfa(S2) → Usta(S3) → Pîr/Lonca(S4). Kademe atlanamaz.
KANON: ahi doctrine  ·  Detay: DOCTRINE.md + tiers/
EOF
}

cmd_doctrine() {
  local f="$AHI_DIR/DOCTRINE.md"
  [ -f "$f" ] || { red "DOCTRINE.md bulunamadı: $f"; return 1; }
  cat "$f"
}

cmd_tiers() {
  local k="${1:-}"
  if [ -n "$k" ]; then
    local f="$AHI_DIR/tiers/$k.md"
    [ -f "$f" ] || { red "Bilinmeyen kademe: $k (cirak|kalfa|usta|pir)"; return 1; }
    cat "$f"
  else
    grn "Kademeler (zanaat-rütbesi — tertipli, atlanamaz):"
    echo "  Çırak (S1) → Kalfa (S2) → Usta (S3) → Pîr/Lonca (S4)"
    echo "Detay: ahi tiers <kademe>   ·   Kart dosyaları:"
    ls "$AHI_DIR/tiers/" 2>/dev/null | sed 's/^/  - /'
  fi
}

cmd_check() {
  local target="${1:-}"
  command -v node >/dev/null 2>&1 || { red "node bulunamadı (validate.mjs gerektirir)"; return 2; }
  local mani
  if [ -z "$target" ] || [ "$target" = "ahi" ]; then
    mani="$AHI_DIR/ahi.manifest.yaml"
  else
    mani="$AHI_DIR/../$target/ahi.manifest.yaml"
    [ -f "$mani" ] || mani="$target/ahi.manifest.yaml"
  fi
  [ -f "$mani" ] || { red "manifest bulunamadı: $mani"; return 1; }
  node "$AHI_DIR/schema/validate.mjs" "$mani"
  # NOT: FAZ-0b = yalnız manifest-şema-valid. catalog/sync-targets/README parity + drift = FAZ-2 (ADR-001).
}

stub() { ylw "[$1] FAZ-$2'de gelir (şu an kabuk). Kanon hazır: ahi doctrine"; }

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    doctrine)        cmd_doctrine ;;
    tiers)           cmd_tiers "${1:-}" ;;
    new)             stub new 1 ;;
    check)           cmd_check "${1:-}" ;;
    promote)         stub promote 3 ;;
    deprecate)       stub deprecate 3 ;;
    classify)        stub classify 4 ;;
    health)          stub health 4 ;;
    version|--version) echo "ahi $VERSION" ;;
    ""|-h|--help|help) usage ;;
    *)               red "Bilinmeyen komut: $cmd"; echo; usage; return 2 ;;
  esac
}

main "$@"
