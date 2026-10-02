#!/usr/bin/env bash
# bekci.sh — dakikada bir (cron). Düzen sağlamsa hiçbir şey yapmaz; bozuksa merdiveni başlatır.
# Duraklatma: `bash komut.sh duraklat "<sebep>"` (ör. bilerek kapatırken) · `devam`.
set -u
. "$(dirname "$0")/ortak.sh"
[ -f "$DURUM_DIZ/duraklat" ] && exit 0
bash "$BETIK_DIZ/durum.sh" >/dev/null 2>&1 && exit 0
exec bash "$BETIK_DIZ/kademe.sh" --kaynak bekci
