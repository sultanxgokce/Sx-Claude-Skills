#!/usr/bin/env bash
# canli-dinle <adres> [--kaynak groq|yerel] [--not] [--sure SN] [--cikti DIR] [--kuru]
# Tek komut: yakala (streamlink > yt-dlp > ffmpeg) -> 30 sn parça (+5 sn örtüşme) -> yazıya dök -> 10 dk pencerede özet.
# streamlink yoksa ve CANLI_DINLE_KUR=1 ise kullanıcı venv'ine pip ile kurulur (ağ gerekir).
set -u
D="$(cd "$(dirname "$0")" && pwd)"
if [ "${CANLI_DINLE_KUR:-0}" = "1" ] && ! command -v streamlink >/dev/null 2>&1; then
  V="${HOME}/.cache/canli-dinle/venv"
  python3 -m venv "$V" && "$V/bin/pip" install -q streamlink || { echo "✗ streamlink kurulamadı" >&2; exit 3; }
  export PATH="$V/bin:$PATH"
fi
exec python3 "$D/canli_dinle.py" "$@"
