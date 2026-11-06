#!/usr/bin/env bash
# canli-bak.sh <sirada-bak yolu> — gerçek defterde YALNIZ BAKAR (--bak: üstlenme yok) ve karar satırlarını basar; rc sirada-bak'ın rc'sidir.
set -u; SB="$1"; cd /config/projects/Nexus || exit 3
echo "betik: $SB"
O="$(bash "$SB" --bak --kim BÂNİ 2>&1)"; rc=$?
printf '%s\n' "$O" | grep -E '^(SIRADA|HAVUZDA|ESIK|KARAR|NEDEN|BASLAMADI|ONERI|HASAT|ZORUNLU)=' || true
echo "rc=$rc"; exit "$rc"
