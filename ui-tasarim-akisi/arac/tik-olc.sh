#!/usr/bin/env bash
# tik-olc.sh <sayfa.html> <yol.json> [--genislik N] [--yukseklik N] [--dizin D] — tık bütçesini TARAYICIDA ölçüp kaydeder.
#
# NİÇİN (retro W42 BERİD Ö5 · D4): tik-kaydet.sh hedef:ölçülen çiftini ELDEN alıyordu; "elle verilen tık sayısı ölçüm
#   değildir". Bu araç yolu tarayıcıda yürür (tik-olc.mjs) ve ÖLÇÜLEN sayıyı tik-kaydet.sh'e verir; artefakt
#   `yontem: tarayici` ve yol tanımının sha'sını taşır. tik-kaydet.sh'i elle çağırmak SEÇENEK olarak durur (yontem: elle).
# Sayfa, dizininden geçici bir yerel sunucuyla açılır (göreli kaynaklar çalışsın); dış ağa gidilmez.
# Ortam: KANIT_PLAYWRIGHT_DIR (playwright'lı node_modules; vars. /config/projects/Nexus/ui/node_modules)
# ÇIKIŞ: 0 ölçüldü ve kaydedildi · 2 geçersiz girdi · 3 ÖLÇÜLEMEDİ (tarayıcı yok) — sayı yazılmaz, kapı "ölçülmedi" der
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAYFA="${1:-}"; YOL="${2:-}"
[ -n "$SAYFA" ] && [ -f "$SAYFA" ] && [ -n "$YOL" ] && [ -f "$YOL" ] || {
  echo "kullanım: tik-olc.sh <sayfa.html> <yol.json> [--genislik N] [--yukseklik N] [--dizin D]" >&2; exit 2; }
shift 2; GEN=1280; YUK=800; DIZIN=()
while [ $# -gt 0 ]; do case "$1" in
  --genislik) GEN="${2:-}"; shift 2 ;; --yukseklik) YUK="${2:-}"; shift 2 ;; --dizin) DIZIN=(--dizin "${2:-}"); shift 2 ;;
  *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
PW="${KANIT_PLAYWRIGHT_DIR:-/config/projects/Nexus/ui/node_modules}"
T="$(mktemp -d)"; trap 'kill "${SP:-}" 2>/dev/null; find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$(cd "$(dirname "$SAYFA")" && pwd)" >/dev/null 2>&1 & SP=$!
for _ in $(seq 1 50); do python3 -c "import socket,sys; s=socket.socket(); sys.exit(s.connect_ex(('127.0.0.1',$PORT)))" && break; sleep 0.1; done
NODE_PATH="$PW" node "$HERE/tik-olc.mjs" "http://127.0.0.1:$PORT/$(basename "$SAYFA")" "$YOL" "$GEN" "$YUK" > "$T/o" 2> "$T/e"; rc=$?
cat "$T/e" >&2
[ "$rc" -eq 0 ] || { [ "$rc" -eq 3 ] && echo "ÖLÇÜLEMEDİ: tarayıcı yok — tık sayısı yazılmadı (elle sayı ölçüm değildir)" >&2; exit "$rc"; }
OLCULEN="$(tail -1 "$T/o")"; echo "ölçülen (tarayıcı): $OLCULEN"
# shellcheck disable=SC2086
bash "$HERE/tik-kaydet.sh" "$SAYFA" $OLCULEN --yontem tarayici --yol "$YOL" "${DIZIN[@]}"
