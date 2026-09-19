#!/usr/bin/env bash
# kutuphane-katalog — Python sınamalarını depo kapısına bağlar.
# NİÇİN: depo CI'ı yalnız *.test.sh koşar; test_catalog.py tek başına hiçbir kapıda
# koşmuyordu ("test yazmak onu koşturmaz"). Bu sarmalayıcı onu her PR'da koşturur.
set -uo pipefail
cd "$(dirname "$0")" || exit 2
command -v python3 >/dev/null || { echo "python3 yok — ÖLÇÜLEMEDİ"; exit 3; }
python3 -m unittest -v test_catalog 2>&1
