#!/bin/sh
# e2e-env.sh — kesif E2E için root-suz Chromium çalışma-ortamını kurar (LD_LIBRARY_PATH + PW_RUNTIME_DIR),
# sonra verilen node-komutunu koşar. Kütüphane-env bootstrap.sh'ın kurduğu conda-forge pw-libs.
# Kullanım: sh e2e-env.sh node <script> <args...>   (ör: sh e2e-env.sh node e2e-run.mjs --panel-url ...)
set -eu
MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX:-"$HOME/.local/micromamba"}
PW_LIBS_ENV=${PW_LIBS_ENV:-pw-libs}
LIBDIR="$MAMBA_ROOT_PREFIX/envs/$PW_LIBS_ENV/lib"
[ -e "$LIBDIR/libgbm.so.1" ] || { echo "e2e-env: pw-libs yok ($LIBDIR) — önce bootstrap.sh" >&2; exit 1; }

# repo-kökü (git-common-dir → ana-depo) → PW_RUNTIME_DIR default
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
export PW_RUNTIME_DIR=${PW_RUNTIME_DIR:-"$REPO_ROOT/tooling/pw-runtime"}
export LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$@"
