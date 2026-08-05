#!/bin/sh
# pw/bootstrap.sh — Playwright'ı ROOT-SUZ canlandıran TEK-BOĞAZ (kesif güvenlik-omurgası, MOTOR-parçası).
# Kanıtlı-yol (SADIK 2026-07-08, canlı-doğrulandı): micromamba + conda-forge kullanıcı-alanı kütüphane
# zinciri + playwright-chromium indirimi + LD_LIBRARY_PATH ile headless-shell launch. apt/root GEREKMEZ.
# İdempotent: kurulu-katmanları atlar. Çıplak chromium.launch YASAK — launch DAİMA launch_check.mjs
# üzerinden (origin-allowlist deny-all zorlanımı orada).
#
# Kullanım:
#   KESIF_ALLOWLIST="<origin1,origin2>" sh bootstrap.sh [--skip-selftest]
# Parametreler (env, hepsi generic — proje-değeri CONFIG'ten geçirilir, buraya GÖMÜLMEZ):
#   MAMBA_BIN        micromamba ikilisi (default: $HOME/.local/micromamba/bin/micromamba)
#   PW_LIBS_ENV      conda-env adı (default: pw-libs)
#   PW_RUNTIME_DIR   playwright npm-paketinin yaşadığı dizin (default: <repo>/tooling/pw-runtime)
#   KESIF_ALLOWLIST  virgüllü origin-allowlist (selftest deny-zorlanımı için ZORUNLU; boş = FAIL)
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(git -C "$SELF_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##') || REPO_ROOT=$(pwd)

MAMBA_BIN=${MAMBA_BIN:-"$HOME/.local/micromamba/bin/micromamba"}
PW_LIBS_ENV=${PW_LIBS_ENV:-pw-libs}
PW_RUNTIME_DIR=${PW_RUNTIME_DIR:-"$REPO_ROOT/tooling/pw-runtime"}
SKIP_SELFTEST=0
[ "${1:-}" = "--skip-selftest" ] && SKIP_SELFTEST=1

export MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX:-"$(dirname "$(dirname "$MAMBA_BIN")")"}

# KANITLI kütüphane-zinciri (2026-07-08 canlı-testi: bu liste headless-shell'in TÜM eksik-so'larını kapattı;
# libgbm+libcups son-halkaydı). Sıra önemsiz; tek-transaction.
PW_CONDA_PKGS="glib nspr nss dbus libdrm mesa atk at-spi2-atk libxkbcommon \
xorg-libxcomposite xorg-libxdamage xorg-libxfixes xorg-libxrandr xorg-libxext \
xorg-libxi xorg-libxtst xorg-libxcursor xorg-libxrender alsa-lib expat cairo pango libgbm libcups"

log() { printf '[pw-bootstrap] %s\n' "$*"; }
die() { printf '[pw-bootstrap] HATA: %s\n' "$*" >&2; exit 1; }

# ── 1) micromamba var mı ─────────────────────────────────────────────
[ -x "$MAMBA_BIN" ] || die "micromamba yok: $MAMBA_BIN (runtime-bootstrap gerekli; root İSTEMEZ)"

# ── 2) kütüphane-env (idempotent: kilit-dosya libgbm varlığıyla) ─────
LIBDIR="$MAMBA_ROOT_PREFIX/envs/$PW_LIBS_ENV/lib"
if [ -e "$LIBDIR/libgbm.so.1" ] && [ -e "$LIBDIR/libcups.so.2" ] && [ -e "$LIBDIR/libglib-2.0.so.0" ]; then
  log "kütüphane-env hazır: $LIBDIR (atlandı)"
else
  log "kütüphane-env kuruluyor: $PW_LIBS_ENV ← conda-forge ($(echo "$PW_CONDA_PKGS" | wc -w) paket)"
  # env yoksa create, varsa install — ikisi de idempotent-güvenli
  if "$MAMBA_BIN" env list 2>/dev/null | grep -q "envs/$PW_LIBS_ENV"; then
    "$MAMBA_BIN" install -y -n "$PW_LIBS_ENV" -c conda-forge $PW_CONDA_PKGS >/dev/null
  else
    "$MAMBA_BIN" create -y -n "$PW_LIBS_ENV" -c conda-forge $PW_CONDA_PKGS >/dev/null
  fi
  [ -e "$LIBDIR/libgbm.so.1" ] || die "kurulum-sonrası libgbm.so.1 hâlâ yok: $LIBDIR"
  log "kütüphane-env kuruldu"
fi

# ── 3) playwright npm-paketi (runtime-dizininde, repo-bağımlılıklarını kirletmez) ──
command -v node >/dev/null 2>&1 || die "node yok (motor-önkoşulu node>=18; DEGRADE=kurulum-reddi)"
mkdir -p "$PW_RUNTIME_DIR"
if [ -d "$PW_RUNTIME_DIR/node_modules/playwright" ]; then
  log "playwright npm-paketi hazır (atlandı)"
else
  log "playwright npm-paketi kuruluyor → $PW_RUNTIME_DIR"
  ( cd "$PW_RUNTIME_DIR" && { [ -f package.json ] || npm init -y >/dev/null; } \
      && npm install --no-audit --no-fund playwright >/dev/null )
fi

# ── 4) chromium binary (playwright-cache'e; idempotent) ──────────────
if ls "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell >/dev/null 2>&1; then
  log "chromium binary hazır (atlandı)"
else
  log "chromium indiriliyor (root-suz, ~300MB)"
  ( cd "$PW_RUNTIME_DIR" && npx playwright install chromium >/dev/null 2>&1 ) || die "chromium indirimi başarısız"
fi

# ── 5) SELFTEST: launch + render + origin-allowlist deny-zorlanımı ───
if [ "$SKIP_SELFTEST" = "1" ]; then
  log "selftest atlandı (--skip-selftest)"; exit 0
fi
[ -n "${KESIF_ALLOWLIST:-}" ] || die "KESIF_ALLOWLIST boş — allowlist'siz selftest YOK (güvenlik-omurgası; değer CONFIG'ten geçir)"
log "selftest: launch_check.mjs (allowlist=$KESIF_ALLOWLIST)"
LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
PW_RUNTIME_DIR="$PW_RUNTIME_DIR" KESIF_ALLOWLIST="$KESIF_ALLOWLIST" \
  node "$SELF_DIR/launch_check.mjs"
log "SELFTEST GEÇTİ — chromium root-suz canlı + allowlist-zorlanımı kanıtlı"
