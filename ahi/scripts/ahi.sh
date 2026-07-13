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

cmd_new() {
  local tier="${1:-}" name="${2:-}" apply=0
  [ "${3:-}" = "--apply" ] && apply=1
  case "$tier" in cirak|kalfa|usta|pir) ;; *) red "geçersiz kademe: '$tier' (cirak|kalfa|usta|pir)"; return 2 ;; esac
  [ -n "$name" ] || { red "ad gerekli: ahi new <kademe> <ad> [--apply]"; return 2; }
  echo "$name" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' || { red "geçersiz slug: '$name' (kebab-case a-z0-9; ör. ornek-skill)"; return 2; }
  local gg
  case "$tier" in
    cirak) gg="işi yapıyor" ;;
    kalfa) gg="planlı + paketli + her-projede güvenilir tekrarlanabilir" ;;
    usta)  gg="standarttan-türetilmiş bileşik iş-sistemi" ;;
    pir)   gg="ölçülen + kendini-geliştiren yaşayan-sistem" ;;
  esac
  if [ "$tier" = "pir" ]; then
    ylw "Pîr (S4 · yaşayan-sistem) = KENDİ-REPO (skill-dizini değil)."
    echo "  Rehber: 'ahi tiers pir' — kendi-repo iskeleti (DOCTRINE/CONTRACT/ROADMAP/ADR) + remote+CI zorunlu (Lonca emsali)."
    return 0
  fi
  local tdir="$AHI_DIR/templates/$tier"
  [ -d "$tdir" ] || { red "şablon yok: $tdir"; return 1; }
  local dest="$AHI_DIR/../$name" rel
  if [ "$apply" -ne 1 ]; then
    ylw "DRY-RUN (yazma-öncesi DURAK) — onaylarsan --apply ekle:"
    echo "  kademe : $tier   ad: $name"
    echo "  hedef  : $dest/"
    echo "  generic-goal (default): \"$gg\""
    echo "  üretilecek:"
    while IFS= read -r rel; do echo "    $name/${rel#./}"; done < <(cd "$tdir" && find . -type f)
    echo "  → onay: ahi new $tier $name --apply"
    return 0
  fi
  [ -e "$dest" ] && { red "hedef zaten var: $dest (üzerine yazılmaz)"; return 2; }
  while IFS= read -r rel; do
    rel="${rel#./}"; mkdir -p "$dest/$(dirname "$rel")"
    sed -e "s|{{NAME}}|$name|g" -e "s|{{TIER}}|$tier|g" -e "s|{{GENERIC_GOAL}}|$gg|g" "$tdir/$rel" > "$dest/$rel"
  done < <(cd "$tdir" && find . -type f)
  if grep -rq '{{' "$dest" 2>/dev/null; then
    red "dolmamış placeholder kaldı — sevk-RED:"; grep -rn '{{' "$dest" >&2; return 1
  fi
  grn "✓ üretildi: $dest/"
  echo "--- ahi check $name ---"; cmd_check "$name"
}

stub() { ylw "[$1] FAZ-$2'de gelir (şu an kabuk). Kanon hazır: ahi doctrine"; }

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    doctrine)        cmd_doctrine ;;
    tiers)           cmd_tiers "${1:-}" ;;
    new)             cmd_new "$@" ;;
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
