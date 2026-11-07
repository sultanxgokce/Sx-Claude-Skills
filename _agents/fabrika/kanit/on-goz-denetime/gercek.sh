#!/usr/bin/env bash
# gercek.sh — HEAD'in denetci.sh'ini bu işin kendi itilmiş alanında --on-goz (yalnız ön göz) kipinde koşar: gerçek kanıt, gerçek kart, gerçek uzak.
#   Denetim açmaz, tur yakmaz, DENETIM yazmaz. Beklenen: mekanik kapılar uyumlu, DALGIÇ koşar; rc 0.
set -u; R="$(git rev-parse --show-toplevel)"
bash "$R/yazilim-fabrikasi/scripts/denetci.sh" on-goz-denetime --on-goz < /dev/null; r=$?
ls "$R/_agents/fabrika/kanit/on-goz-denetime/"DENETIM-*.json >/dev/null 2>&1 && { echo "✗ DENETIM yazıldı — yalnız ön göz kipi denetim açmamalıydı"; exit 1; }
echo "DENETIM yazılmadı (beklenen) · rc=$r"; exit $r
