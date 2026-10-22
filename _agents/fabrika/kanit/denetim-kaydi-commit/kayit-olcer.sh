#!/usr/bin/env bash
# kayit-olcer.sh <yazilim-fabrikasi/scripts dizini> — B2DBS6 ölçümü: verilen betiklerin KOPYASINDA bu dalın
#   denetci-kayit-commit.test.sh'ını koşar. Önce = origin/main betikleri (kayıt dala girmez → kırmızı), sonra = dal (yeşil).
set -uo pipefail
KAYNAK="$(cd "$1" && pwd)"; SINAV="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/yazilim-fabrikasi/scripts/denetci-kayit-commit.test.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
cp -r "$KAYNAK/." "$T/"; cp "$SINAV" "$T/denetci-kayit-commit.test.sh"
bash "$T/denetci-kayit-commit.test.sh" < /dev/null
