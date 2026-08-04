#!/usr/bin/env bash
# resume-banner — oturum-açılış / post-compact KONUM-toparlayıcı (AHÎ · kalfa)
#
# CLAUDE.md "post-compact 4-zorunlu"yu tek-komuta indirir:
#   (1) env-fingerprint (pwd/hostname/git status) — Mac→container churn'ünü ilk-fail'den ÖNCE yakala
#   (2) KONUM ham-maddesi — son CONTEXT ⚓-çıpası + son defter-çıpası (+ cortex STATE varsa)
#   (3) hatırlatmalar — harness-durumu tazele · dil-koru · 3-satır KONUM-banner'ı YAZ
# doctor.sh'ı TAMAMLAR (yeteneği değil, KONUM'u toparlar). SALT-OKU: hiçbir dosya yazmaz.
# Token-güvenli: büyük dosyaları (CONTEXT.md ~85k token) ASLA tam-dökmez — yalnız son-çıpa satırları.
set -uo pipefail

VERSION="0.1.0"

# Nexus-varsayılanları (proje-köküne göre; yoksa sessiz-atlanır → taşınabilir).
CONTEXT_FILE="_agents/CONTEXT.md"
DEFTER_FILE="_agents/handoff/serdar-defter.md"
CORTEX_STATE="cortex/loop/STATE.json"

c_cyan() { printf '\033[36m%s\033[0m\n' "$*"; }
c_ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
c_dim()  { printf '\033[2m%s\033[0m\n' "$*"; }

_kok() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

usage() {
  cat <<'EOF'
resume-banner — oturum-açılış / post-compact KONUM-toparlayıcı (AHÎ · kalfa)

KULLANIM:
  resume-banner            # tam refleks: env-fingerprint + KONUM ham-maddesi + hatırlatmalar (SALT-OKU)
  resume-banner env        # yalnız env-fingerprint satırı (pwd/hostname/git status)
  resume-banner --version | -h|--help

SALT-OKU: hiçbir dosya yazılmaz · büyük dosyalar tam-dökülmez (yalnız son-çıpa).
Not: 3-satır KONUM-banner'ını (neredeyiz/ne-bitti/sıradaki) ajan bu ham-maddeden YAZAR.
EOF
}

cmd_env() {
  c_cyan "🖥️  env-fingerprint"
  echo "   pwd      : $(pwd)"
  echo "   hostname : $(hostname 2>/dev/null || echo '?')"
  local kok; kok="$(_kok)"
  echo "   git      : $(git -C "$kok" status -sb 2>/dev/null | head -1 || echo '(git yok)')"
  local dirty; dirty="$(git -C "$kok" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "   kirli    : ${dirty} dosya · HEAD: $(git -C "$kok" log --oneline -1 2>/dev/null | cut -c1-72 || echo '?')"
}

cmd_full() {
  local kok; kok="$(_kok)"
  cmd_env
  echo
  # 2) KONUM ham-maddesi — SON çıpalar (büyük dosyalar dökülmez)
  c_cyan "📍 KONUM ham-maddesi (son-çıpalar)"
  if [[ -f "$kok/$CONTEXT_FILE" ]]; then
    local ctx; ctx="$(grep -nE '⚓' "$kok/$CONTEXT_FILE" 2>/dev/null | tail -2 || true)"
    if [[ -n "$ctx" ]]; then
      echo "   • CONTEXT ⚓ (son):"; sed 's/^/       /' <<<"$ctx" | cut -c1-160
    else
      c_dim "   • CONTEXT: ⚓-çıpası bulunamadı ($CONTEXT_FILE)"
    fi
  else
    c_dim "   • CONTEXT yok ($CONTEXT_FILE) — bu proje için atlandı"
  fi
  if [[ -f "$kok/$DEFTER_FILE" ]]; then
    local dft; dft="$(grep -E '⚓' "$kok/$DEFTER_FILE" 2>/dev/null | tail -1 || true)"
    [[ -n "$dft" ]] && { echo "   • Defter ⚓ (son):"; echo "       $(cut -c1-200 <<<"$dft")"; }
  fi
  if [[ -f "$kok/$CORTEX_STATE" ]]; then
    echo "   • cortex STATE: $(head -c 200 "$kok/$CORTEX_STATE" 2>/dev/null | tr -d '\n')"
  fi
  echo
  # 3) hatırlatmalar (post-compact 4-zorunlu)
  c_ylw "✅ post-compact refleks (CLAUDE.md 4-zorunlu):"
  echo "   1. Harness-durumunu VARSAYMA — plan-modu/task-id/tool-şemaları sıfırlanmış olabilir (gerekiyorsa tazele)."
  echo "   2. Kullanıcı-dilini KORU (Sultan'la Türkçe)."
  echo "   3. Yukarıdaki ham-maddeden 3-satır KONUM-banner'ı YAZ: neredeyiz (cycle/faz) · ne bitti · sıradaki adım."
  echo "   4. Ortam-değişimi (Mac→container) şüphesi varsa ilk-komut-fail'inden ÖNCE env-fingerprint'e bak (yukarıda)."
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    ""|full) cmd_full ;;
    env)     cmd_env ;;
    --version|version) echo "resume-banner $VERSION" ;;
    -h|--help|help) usage ;;
    *) c_ylw "bilinmeyen komut: $cmd"; echo; usage; return 2 ;;
  esac
}

main "$@"
