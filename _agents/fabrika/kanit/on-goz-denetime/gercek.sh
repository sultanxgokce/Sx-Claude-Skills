#!/usr/bin/env bash
# gercek.sh — HEAD'in denetci.sh'ini bu işin kendi itilmiş alanında --on-goz (yalnız ön göz) kipinde koşar: gerçek kanıt, gerçek kart, gerçek uzak.
#   Denetim açmaz, tur yakmaz, DENETIM yazmaz (koşu ÖNCESİ ve SONRASI DENETIM sayısı aynı kalmalı — göz turlarının kayıtları zaten durur).
set -u; R="$(git rev-parse --show-toplevel)"; DZ="$R/_agents/fabrika/kanit/on-goz-denetime"
once=$(ls "$DZ"/DENETIM-*.json 2>/dev/null | wc -l)
bash "$R/yazilim-fabrikasi/scripts/denetci.sh" on-goz-denetime --on-goz < /dev/null; r=$?
sonra=$(ls "$DZ"/DENETIM-*.json 2>/dev/null | wc -l)
[ "$once" = "$sonra" ] || { echo "✗ DENETIM sayısı $once → $sonra — yalnız ön göz kipi denetim açmamalıydı"; exit 1; }
echo "DENETIM sayısı değişmedi ($once) · rc=$r"; exit $r
