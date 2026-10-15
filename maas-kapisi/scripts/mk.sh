#!/usr/bin/env bash
# maas-kapisi sarmalayıcı — root'suz runtime'ı (uv) ayarlar, motoru çağırır.
# Bu kutuda sistem python3'ü yok; bağımlılıklar uv ile geçici ortamda çözülür.
set -euo pipefail
export PATH="/config/.local/bin:$PATH"
unset VIRTUAL_ENV || true
exec uv run --quiet --with pypdf --with openpyxl \
  python "$(dirname "${BASH_SOURCE[0]}")/maas_kapisi.py" "$@"
