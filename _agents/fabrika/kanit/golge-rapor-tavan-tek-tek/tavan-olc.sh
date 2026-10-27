#!/usr/bin/env bash
# gölge raporu: tavan yüzünden ölçülemeyen kayıt sayısı (mod: eski = kurulu 0.27.x betik | yeni = bu alanın betiği | mutant = tavan yolunda Revert araması söküldü)
W="$(git rev-parse --show-toplevel)"; M="$1"; D="$(mktemp -d)"
case "$M" in
 eski) git -C "$W" show origin/main:yazilim-fabrikasi/scripts/golge-rapor.sh > "$D/r.sh" ;;
 yeni) cp "$W/yazilim-fabrikasi/scripts/golge-rapor.sh" "$D/r.sh" ;;
esac
CIKTI="$(bash "$D/r.sh" 2>&1)"; find "$D" -delete
head -2 <<<"$CIKTI"
N="$(grep -ac 'tavanda\|tek PR sorusu da alınamadı' <<<"$CIKTI")"
echo "kalan=$N (tavan yüzünden ölçülemeyen kayıt)"
[ "$N" -eq 0 ]
