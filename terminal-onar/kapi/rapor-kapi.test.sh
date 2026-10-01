#!/usr/bin/env bash
# ÇAĞIRAN KAPI — rapor yolunun sınavı ve mutasyon turu.
#
# Niçin bu sarmalayıcı var (ölçüldü 2026-10-01): deponun CI koşucusu YALNIZ
# `*.test.sh` keşfediyor; `*.test.mjs` uzantılı 13 sınav hiçbir kapıda koşmuyor.
# Sınav yazmak onu koşturmaz. Sarmalayıcı, rapor yolunun iki ölçümünü
# koşucunun gördüğü biçime bağlar. Depo genelindeki boşluk ayrı bir iştir.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"
command -v node >/dev/null || { echo "ÖLÇÜLEMEDİ: node yok"; exit 3; }
echo "── rapor sınavı"
node rapor.test.mjs
echo "── rapor mutasyon turu"
bash rapor.mutasyon.sh
echo "SONUÇ: rapor yolu — sınav ve mutasyon turu geçti"
