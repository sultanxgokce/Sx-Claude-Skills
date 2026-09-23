#!/usr/bin/env bash
# kanit.sh — kanit.py'ye ince sarmalayıcı (hat dosyası bu adla çağırır). Bütün mantık kanit.py'de.
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kanit.py" "$@"
