#!/usr/bin/env bash
# guvenli-sil.sh — ince sarmalayici; butun mantik guvenli-sil.py de.
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/guvenli-sil.py" "$@"
