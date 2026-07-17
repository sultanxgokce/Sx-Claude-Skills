#!/usr/bin/env bash
# kayit-damgasi — merge-anı kayıt kapanış-damgası orkestratörü (AHÎ · kalfa)
#
# CLAUDE.md §9 "Kayıt-Damgası"nı refleks-hıza indirir: bir iş/PR bir kaydı
# (defter-kartı · gap/bulgu-defteri · SULTAN-KAPISI gate'i · plan-satırı) fiilen
# kapatıyorsa, merge anında o kayda kapanış-damgasını işle. Mevcut
# `scripts/defter-mailbox.sh durum` primitifini orkestra eder — yeniden icat etmez.
#
# DEĞİŞMEZLER:
#   • DRY-varsayılan: `tara` ve `merge` (--apply'sız) HİÇBİR yazma yapmaz.
#   • İnsan-onay-alanına ASLA yazmaz: yalnız kart-durumu (bitti/teslim/yeniden)
#     flip'ler; sultan_response/onay gibi alanlara dokunmaz (defter-mailbox durum
#     zaten bu kümeyle sınırlı, burada ek-guard ile pekiştirilir).
set -euo pipefail

VERSION="0.1.0"
# defter-mailbox.sh 'durum' alt-komutunun kabul-kümesi (hepsi ajan-yetkili; onay-alanı YOK).
GECERLI_DURUMLAR="bitti teslim yeniden"
# Damga aranacak kayıt-dosyaları (proje-köküne göre; yoksa sessiz-atlanır).
RECORD_GLOBS=(
  "_agents/handoff/bulgu-havuzu.jsonl"
  "_agents/handoff/dongu-defteri.jsonl"
  "_agents/SULTAN-KAPISI.md"
  "_agents/CONTEXT.md"
  ".claude/plans"
  "_agents/vizyon"
)

c_red()  { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }

_kok() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

_defter() {
  local kok; kok="$(_kok)"
  if [[ -x "$kok/scripts/defter-mailbox.sh" ]]; then
    printf '%s\n' "$kok/scripts/defter-mailbox.sh"; return 0
  fi
  return 1
}

# Bir git-ref (tek-commit ya da aralık) → içindeki commit mesajları + gövdeleri.
_ref_mesajlari() {
  local kok ref="$1"; kok="$(_kok)"
  if git -C "$kok" rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
    git -C "$kok" show -s --format='%H %s%n%b' "$ref"
  else
    git -C "$kok" log --format='%H %s%n%b' "$ref" 2>/dev/null || true
  fi
}

# k####/b#### token'larını (kayıt-id'leri) mesajlardan çıkar.
_tokenlar() {
  grep -oE '\b[kb][0-9]{4}\b' | sort -u || true
}

usage() {
  cat <<'EOF'
kayit-damgasi — merge-anı kayıt kapanış-damgası orkestratörü (AHÎ · kalfa)

KULLANIM:
  kayit-damgasi tara  <git-ref|range>              # SALT-OKU: ref'in kapattığı kayıtları + önerilen damgaları bas
  kayit-damgasi isle  <k####> <durum> --kanit <ref>  # tek kart-damgası uygula (durum ∈ bitti|teslim|yeniden)
  kayit-damgasi merge <git-ref|range> [--apply]    # tara + (--apply ise) k#### kartlarını 'bitti' damgala
  kayit-damgasi --version | -h|--help

DEĞİŞMEZ: tara/merge (--apply'sız) yazmaz · yalnız kart-durumu flip'lenir · onay-alanına dokunulmaz.
EOF
}

cmd_tara() {
  local ref="${1:-}"
  [[ -n "$ref" ]] || { c_red "kullanım: kayit-damgasi tara <git-ref|range>"; return 2; }
  local kok; kok="$(_kok)"
  local mesajlar tokenlar
  mesajlar="$(_ref_mesajlari "$ref")"
  [[ -n "$mesajlar" ]] || { c_red "ref çözümlenemedi ya da boş: $ref"; return 1; }
  tokenlar="$(printf '%s\n' "$mesajlar" | _tokenlar)"

  c_ylw "🔎 Kayıt-taraması (SALT-OKU): $ref"
  if [[ -z "$tokenlar" ]]; then
    echo "  ℹ️  Bu ref'in commit-mesajlarında kayıt-id'si (k####/b####) yok — otomatik damga adayı yok."
    echo "     (Yine de gap/kapı/plan kaydı elle kapanıyor olabilir; SKILL.md §9-listesine bak.)"
    return 0
  fi

  echo "  📌 Bulunan kayıt-id'leri: $(printf '%s ' $tokenlar)"
  echo
  local t
  for t in $tokenlar; do
    echo "  ── $t ──"
    # kart mı (k####) → defter-mailbox ile öneri
    if [[ "$t" == k* ]] && _defter >/dev/null 2>&1; then
      echo "     • kart-damgası önerisi:  kayit-damgasi isle $t bitti --kanit $ref"
    fi
    # kayıt-dosyalarında token geçiyor mu → elle-damga adayı
    local g hits
    for g in "${RECORD_GLOBS[@]}"; do
      [[ -e "$kok/$g" ]] || continue
      hits="$(grep -rns --binary-files=without-match "$t" "$kok/$g" 2>/dev/null | head -5 || true)"
      [[ -n "$hits" ]] && printf '     • elle-damga adayı (%s):\n%s\n' "$g" "$(sed 's/^/         /' <<<"$hits")"
    done
  done
  echo
  c_ylw "  ⓘ Hiçbir yazma yapılmadı (SALT-OKU). Uygulamak için: isle <k####> <durum> --kanit <ref>"
}

cmd_isle() {
  local kid="${1:-}" durum="${2:-}"; shift $(( $# >= 2 ? 2 : $# )) || true
  local kanit=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kanit) kanit="${2:-}"; shift 2 ;;
      *) c_red "bilinmeyen argüman: $1"; return 2 ;;
    esac
  done
  [[ -n "$kid" && -n "$durum" ]] || { c_red "kullanım: kayit-damgasi isle <k####> <durum> --kanit <ref>"; return 2; }
  [[ "$kid" =~ ^k[0-9]{4}$ ]] || { c_red "geçersiz kart-id: '$kid' (biçim: k####)"; return 2; }
  # GUARD: durum yalnız ajan-yetkili kümede olabilir (onay-alanı sızması yasak).
  if ! grep -qw "$durum" <<<"$GECERLI_DURUMLAR"; then
    c_red "reddedildi: '$durum' geçerli/ajan-yetkili durum değil (yalnız: $GECERLI_DURUMLAR)."
    c_red "  (insan-onay-alanı flip'i bu araçla YAPILAMAZ — Yetki-Sınırı Protokolü.)"
    return 2
  fi
  local mb; mb="$(_defter)" || { c_red "bu projede scripts/defter-mailbox.sh yok — kart-damgası uygulanamaz."; return 1; }
  c_grn "🔖 damga uygulanıyor: $kid → $durum${kanit:+ (kanıt: $kanit)}"
  if [[ -n "$kanit" ]]; then
    bash "$mb" durum "$kid" "$durum" --kanit "$kanit"
  else
    bash "$mb" durum "$kid" "$durum"
  fi
}

cmd_merge() {
  local ref="" apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      *) ref="$1"; shift ;;
    esac
  done
  [[ -n "$ref" ]] || { c_red "kullanım: kayit-damgasi merge <git-ref|range> [--apply]"; return 2; }
  cmd_tara "$ref"
  echo
  local tokenlar; tokenlar="$(_ref_mesajlari "$ref" | _tokenlar | grep '^k' || true)"
  [[ -n "$tokenlar" ]] || { c_ylw "  otomatik-damga edilebilir kart-id yok."; return 0; }
  local t
  for t in $tokenlar; do
    if [[ "$apply" -eq 1 ]]; then
      cmd_isle "$t" bitti --kanit "$ref" || c_red "  ⚠️  $t damgalanamadı (üstteki hataya bak)"
    else
      c_ylw "  DRY: kayit-damgasi isle $t bitti --kanit $ref   (uygulamak için --apply)"
    fi
  done
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    tara)   cmd_tara "$@" ;;
    isle)   cmd_isle "$@" ;;
    merge)  cmd_merge "$@" ;;
    --version|version) echo "kayit-damgasi $VERSION" ;;
    ""|-h|--help|help) usage ;;
    *) c_red "bilinmeyen komut: $cmd"; echo; usage; return 2 ;;
  esac
}

main "$@"
