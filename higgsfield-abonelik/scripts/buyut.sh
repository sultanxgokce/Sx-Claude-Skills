#!/usr/bin/env bash
# buyut.sh — A3: gorseli 2K/4K'ya buyutur (Higgsfield abonelik yolu).
#
# ── 🔴 NEDEN AYRI ADIM, PROMPT ADIMI DEGIL ──────────────────────────────────
# Buyutme bir TARIF degil, bir ISLEM: promptu yok, modeli farkli
# (bytedance_image_upscale), ve zincirin SONUNDA bir kez kosar. Tadilat
# adimlarinin arasina sokmak hem gereksiz pahali olurdu (her adimda buyut/kucult)
# hem de flux_kontext ciktiyi zaten 1184x880'e dusurdugu icin ANLAMSIZ olurdu.
#
# ── 🔴 SIRA: BUYUTME EN SONA ───────────────────────────────────────────────
# "Once buyut sonra tadilat yap" YANLIS olurdu: flux_kontext girdisi ne olursa
# olsun ciktiyi 1184x880'e dusuruyor, yani onceden buyutulmus her piksel bir
# sonraki adimda cope gider. Buyutme, uzerine baska model kosulmayacak SON
# goruntude yapilir.
#
# ── 🔴 BUYUTME KUSURU DUZELTMEZ, GORUNUR KILAR (2026-08-31, olculdu) ────────
# 4K'da kirli supurgelik ve egri radyator borusu DAHA NET goruluyor. Once yuzey
# adimlarini kos, sonra buyut — tersi, kusuru buyuterek teslim etmektir.
#
# Kullanim: buyut.sh <girdi> <cikti> [--coz 2k|4k]
set -uo pipefail
export HOME="${HOME:-/config}"
GIR="${1:-}"; CIK="${2:-}"; COZ="4k"
shift 2 2>/dev/null || { echo "kullanim: buyut.sh <girdi> <cikti> [--coz 2k|4k]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --coz) COZ="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
case "$COZ" in 2k|4k) : ;; *) echo "[kirmizi] --coz 2k|4k olmalı: $COZ" >&2; exit 2 ;; esac
[ -f "$GIR" ] || { echo "[kirmizi] girdi yok: $GIR" >&2; exit 1; }
command -v higgsfield >/dev/null 2>&1 || { echo "[kirmizi] higgsfield CLI yok" >&2; exit 1; }

ONCE="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$GIR" | tr ',' 'x')"
mkdir -p "$(dirname "$CIK")"
T="$(mktemp -d -p "$(dirname "$CIK")" .buy-XXXXXX)"
higgsfield generate create bytedance_image_upscale --image "$GIR" --resolution "$COZ" \
  --wait >"$T/cli.log" 2>&1
U="$(grep -oE 'https://[^[:space:]"]+\.(png|jpg|jpeg|webp)' "$T/cli.log" | head -1)"
[ -n "$U" ] || { echo "[kirmizi] büyütme üretmedi:" >&2; tail -3 "$T/cli.log" >&2; exit 1; }
curl -fsSL --max-time 300 "$U" -o "$CIK" || exit 1
# 🔴 KANIT: dosya var olmak yetmez, GERCEKTEN buyumus olmali.
[ -s "$CIK" ] || { echo "[kirmizi] çıktı boş" >&2; exit 1; }
SONRA="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$CIK" | tr ',' 'x')"
G1="${ONCE%x*}"; G2="${SONRA%x*}"
case "$G2" in ''|*[!0-9]*) echo "[kirmizi] çıktı ölçülemedi" >&2; exit 1 ;; esac
[ "$G2" -gt "$G1" ] || { echo "[kirmizi] çıktı BÜYÜMEDİ ($ONCE → $SONRA) — kabul edilmedi" >&2; rm -f "$CIK"; exit 1; }
echo "[yesil] büyütüldü: $ONCE → $SONRA · 2 kredi · $CIK"
