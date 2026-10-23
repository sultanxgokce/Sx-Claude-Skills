#!/usr/bin/env bash
# karne-olcer.sh <yazilim-fabrikasi/scripts dizini> — NPTHAQ 2. yarı ölçümü: verilen betiklerin KOPYASINDA bu dalın
#   denetci-karne.test.sh'ını koşar. Önce = origin/main betikleri (denetçi karneyi çağırmaz, kırıldı adayı yok → kırmızı), sonra = dal (yeşil).
set -uo pipefail
KAYNAK="$(cd "$1" && pwd)"; SINAV="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/yazilim-fabrikasi/scripts/denetci-karne.test.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
cp -r "$KAYNAK/." "$T/"; cp "$SINAV" "$T/denetci-karne.test.sh"
bash "$T/denetci-karne.test.sh" < /dev/null
