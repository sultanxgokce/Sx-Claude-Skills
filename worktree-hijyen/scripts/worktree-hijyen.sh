#!/usr/bin/env bash
# worktree-hijyen — git-worktree yaşam-döngüsü zorlayıcı (AHÎ · kalfa)
#
# En pahalı tekil-hata sınıfını önler: bayat-base üstüne dallanma (split-brain,
# duplicate-roster, ölü-PR, "N-behind" yanlış-alarmı) + kapanışta temizlenmeyen
# worktree/artefakt birikimi. Mevcut `scripts/branch-preflight.sh` (varsa) sarılır;
# yoksa taşınabilir inline-eşdeğeri koşulur — yeniden-icat yok.
#
# DEĞİŞMEZLER:
#   • Taze-off-origin/main: `ac` her worktree'yi TAZE fetch'lenmiş base'den açar.
#   • DRY-varsayılan: `kapat` (--apply'sız) ve `denetle` HİÇBİR yıkıcı-işlem yapmaz.
#   • Veri-koruma: kirli/merge-olmamış worktree --force olmadan SİLİNMEZ.
set -euo pipefail

VERSION="0.1.0"

c_red() { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn() { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw() { printf '\033[33m%s\033[0m\n' "$*"; }

_kok() { git rev-parse --show-toplevel 2>/dev/null || { c_red "git deposu değil"; exit 1; }; }

usage() {
  cat <<'EOF'
worktree-hijyen — git-worktree yaşam-döngüsü zorlayıcı (AHÎ · kalfa)

KULLANIM:
  worktree-hijyen preflight [base]          # dallanma/fan-out ÖNCESİ tazelik-kapısı (default base: origin/main)
  worktree-hijyen ac <dal> [base]           # TAZE base'den yeni worktree aç (default: origin/main); bayat-base reddi
  worktree-hijyen kapat <yol> [--apply]     # worktree'yi güvenli kapat (DRY: ne yapılacağını bas; --apply: uygula)
  worktree-hijyen denetle                   # SALT-OKU: tüm worktree'leri + bayat-branch + artık-artefakt tara
  worktree-hijyen --version | -h|--help

DEĞİŞMEZ: ac taze-base zorlar · kapat/denetle DRY-varsayılan · kirli/merge-olmamış worktree --force'suz silinmez.
EOF
}

# Dallanma/fan-out öncesi tazelik-kapısı — mevcut branch-preflight.sh varsa onu sar.
cmd_preflight() {
  local base="${1:-origin/main}" kok; kok="$(_kok)"
  if [[ -x "$kok/scripts/branch-preflight.sh" ]]; then
    bash "$kok/scripts/branch-preflight.sh" "$base"; return $?
  fi
  # Taşınabilir inline-eşdeğeri (branch-preflight.sh yoksa).
  git -C "$kok" fetch origin --quiet 2>/dev/null || c_ylw "⚠️ git fetch başarısız — sayılar LOCAL ref'e göre, bayat olabilir"
  local cur behind dirty
  cur="$(git -C "$kok" branch --show-current 2>/dev/null || echo '?')"
  behind="$(git -C "$kok" rev-list --count "HEAD..$base" 2>/dev/null || echo '?')"
  dirty="$(git -C "$kok" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "branş=$cur · ${base}'e göre: ${behind} geride · kirli-dosya: ${dirty}"
  if [[ "$behind" == "0" && "$dirty" == "0" ]]; then
    c_grn "✅ taze+temiz — dallanma/fan-out güvenli"; return 0
  fi
  [[ "$behind" != "0" ]] && c_red "❌ BAYAT: HEAD ${base}'in ${behind} commit gerisinde — yeni dal DAİMA taze base'den açılır."
  [[ "$dirty" != "0" ]] && c_ylw "⚠️ working-tree kirli (${dirty}) — worktree/fan-out öncesi commit'le ya da stash'le."
  return 1
}

# Taze base'den yeni worktree aç (bayat-base reddi = split-brain önleme).
cmd_ac() {
  local dal="${1:-}" base="${2:-origin/main}"
  [[ -n "$dal" ]] || { c_red "kullanım: worktree-hijyen ac <dal> [base]"; return 2; }
  echo "$dal" | grep -qE '^[a-z0-9][a-z0-9._/-]*$' || { c_red "geçersiz dal-adı: '$dal'"; return 2; }
  local kok; kok="$(_kok)"
  git -C "$kok" fetch origin --quiet 2>/dev/null || c_ylw "⚠️ fetch başarısız — base bayat olabilir"
  # base gerçekten var mı + (origin/* ise) taze mi?
  git -C "$kok" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { c_red "base çözümlenemedi: $base"; return 1; }
  local wtdir; wtdir="$(dirname "$kok")/_wt/${dal//\//-}"
  [[ -e "$wtdir" ]] && { c_red "hedef zaten var: $wtdir (üzerine açılmaz)"; return 2; }
  if git -C "$kok" worktree add -b "$dal" "$wtdir" "$base" >/dev/null 2>&1; then
    c_grn "✓ taze worktree: $wtdir"
    echo "   dal=$dal · base=$base ($(git -C "$kok" rev-parse --short "$base"))"
    echo "   → bittiğinde: worktree-hijyen kapat $wtdir --apply"
  else
    c_red "worktree açılamadı (dal zaten var olabilir: $dal)"; return 1
  fi
}

# Worktree'yi güvenli kapat — kirli/merge-olmamış uyarısı + DRY-varsayılan.
cmd_kapat() {
  local yol="" apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --apply) apply=1; shift ;; *) yol="$1"; shift ;; esac
  done
  [[ -n "$yol" && -d "$yol" ]] || { c_red "kullanım: worktree-hijyen kapat <yol> [--apply]  (dizin yok: '$yol')"; return 2; }
  local dirty cur merged="?"
  dirty="$(git -C "$yol" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  cur="$(git -C "$yol" branch --show-current 2>/dev/null || echo '(detached)')"
  # dal origin/main'e merge edilmiş mi (push+merge kanıtı)?
  if git -C "$yol" rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
    if [[ -z "$(git -C "$yol" rev-list --count "origin/main..HEAD" 2>/dev/null || echo 1)" || "$(git -C "$yol" rev-list --count origin/main..HEAD 2>/dev/null)" == "0" ]]; then
      merged="EVET (origin/main HEAD'i içeriyor)"
    else
      merged="HAYIR (origin/main'de olmayan commit var)"
    fi
  fi
  echo "🔎 worktree: $yol"
  echo "   dal=$cur · kirli-dosya=$dirty · merge-durumu=$merged"
  if [[ "$apply" -ne 1 ]]; then
    c_ylw "   DRY: kaldırmak için --apply ekle. (kirli/merge-olmamışsa git worktree remove --force gerektirir)"
    return 0
  fi
  # apply
  if [[ "$dirty" != "0" ]]; then
    c_red "   ⛔ kirli worktree ($dirty dosya) — veri-koruma: elle 'git worktree remove --force $yol' iste (bilinçli)."
    return 1
  fi
  local kok; kok="$(_kok)"
  if git -C "$kok" worktree remove "$yol" 2>/dev/null; then
    c_grn "   ✓ worktree kaldırıldı: $yol"
    if [[ "$merged" == HAYIR* ]]; then
      c_ylw "   ⚠️ NOT: dal merge-edilmemişti — commit'lerin origin/main'de değil (dal-ref durabilir)."
    fi
    return 0
  else
    c_red "   worktree kaldırılamadı (kilitli/kirli?) — 'git worktree remove --force' iste."; return 1
  fi
}

# SALT-OKU denetim: worktree envanteri + bayat-branch + artık-artefakt.
cmd_denetle() {
  local kok; kok="$(_kok)"
  c_ylw "🔎 worktree denetimi (SALT-OKU) — repo: $kok"
  git -C "$kok" fetch origin --quiet 2>/dev/null || true
  echo
  # 1) worktree listesi + her biri için kirli/behind
  local line wt br
  while IFS= read -r line; do
    wt="$(awk '{print $1}' <<<"$line")"
    [[ -d "$wt" ]] || continue
    br="$(git -C "$wt" branch --show-current 2>/dev/null || echo '(detached)')"
    local d bh
    d="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    bh="$(git -C "$wt" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"
    local bayrak=""
    [[ "$d" != "0" ]] && bayrak+=" ⚠️kirli($d)"
    [[ "$bh" != "0" && "$bh" != "?" ]] && bayrak+=" ⚠️bayat(${bh}-behind)"
    # dal origin'de yok mu (silinmiş/öksüz)?
    if [[ "$br" != "(detached)" ]] && ! git -C "$wt" rev-parse --verify --quiet "origin/$br" >/dev/null 2>&1; then
      bayrak+=" ⚠️origin'de-yok"
    fi
    printf '   • %s  [%s]%s\n' "$wt" "$br" "${bayrak:-  ✓temiz+taze}"
  done < <(git -C "$kok" worktree list 2>/dev/null | tail -n +2)
  echo
  # 2) artık-artefakt: tescil altında commit-edilmiş ama untracked kalan GEREKLILIK/MUHUR kopyaları
  if [[ -d "$kok/_agents/tescil" ]]; then
    local artik
    artik="$(git -C "$kok" status --porcelain _agents/tescil 2>/dev/null | grep -E 'GEREKLILIK\.md|MUHUR.*\.md|gereklilik\.json|muhur.*\.json' || true)"
    if [[ -n "$artik" ]]; then
      c_ylw "   artık-tescil-artefaktı (pull-çakışma riski — damga-push sonrası temizlenmeli):"
      sed 's/^/      /' <<<"$artik"
    else
      echo "   ✓ tescil altında artık-artefakt yok"
    fi
  fi
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    ac)        cmd_ac "$@" ;;
    kapat)     cmd_kapat "$@" ;;
    denetle)   cmd_denetle "$@" ;;
    --version|version) echo "worktree-hijyen $VERSION" ;;
    ""|-h|--help|help) usage ;;
    *) c_red "bilinmeyen komut: $cmd"; echo; usage; return 2 ;;
  esac
}

main "$@"
