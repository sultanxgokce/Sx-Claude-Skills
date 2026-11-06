#!/usr/bin/env bash
# mut-catal.sh — HEAD'i geçici dizine çıkarır, denetci.sh'tan çatal PR korumasını (isCrossRepository satırı) siler, fark sınavını koşar. F5o düşmeli.
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"
python3 - "$S/denetci.sh" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p=sys.argv[1]; s=open(p).read()
a=' \\\n     && [ "$(cd "$DEPO" && gh pr view "$PR" --json isCrossRepository --jq .isCrossRepository 2>/dev/null)" = false ]; then'
assert s.count(a)==1, s.count(a); open(p,'w').write(s.replace(a,'; then'))
PY
bash -n "$S/denetci.sh" || exit 3; echo "mutant: çatal koruması silindi"
bash "$S/denetci-fark-kendisi.test.sh" 2>&1; exit $?
