#!/usr/bin/env bash
# bileyi.sh — ince sarmalayici; butun mantik bileyi.py de.
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bileyi.py" "$@"
