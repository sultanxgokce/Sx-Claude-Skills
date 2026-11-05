#!/usr/bin/env bash
# ÖNCE ölçümü: yeni sınav (HEAD'deki denetci-kutu-disi.test.sh) ESKİ denetci.sh ile (bu dalın ana dalla ortak atası) GEÇİCİ KOPYADA koşar.
# Beklenen: eski 54 kapı yeşil; başka sözle gelen tekrarı ölçen K kapıları (K2, K3, K4, K9, K9b) kırmızı. Çıkış: sınavın rc'si · kopya kurulamazsa 9.
set -u
kok="$(git rev-parse --show-toplevel)" || exit 9
ata="$(git -C "$kok" merge-base HEAD origin/main)" || exit 9
T="$(mktemp -d)"; trap 'find "$T" -mindepth 0 -delete 2>/dev/null' EXIT
git -C "$kok" archive "$ata" yazilim-fabrikasi | tar -x -C "$T" || exit 9
git -C "$kok" show HEAD:yazilim-fabrikasi/scripts/denetci-kutu-disi.test.sh > "$T/yazilim-fabrikasi/scripts/denetci-kutu-disi.test.sh" || exit 9
echo "ESKİ KOD: $ata · sınav: HEAD"
bash "$T/yazilim-fabrikasi/scripts/denetci-kutu-disi.test.sh"
