#!/usr/bin/env bash
# isik-duzelt.sh — A2b: pozlama · patlamis parlak alan kurtarma · netlik. YEREL, BEDAVA.
#
# ── 🔴 NEDEN VAR (Sultan 2026-09-06: "bu haliyle olmaz") ────────────────────
# Zorunlu kalite listemin 2. maddesi ISIK ve ben onu hic yapmamistim. Sonuc:
# salonun tavani PATLAMIS (sol ust saf beyaz, detay yok), alt taraf ise cokmus.
# Profesyonel ic mekan fotografinin ayirt edici ozelligi tam budur: tavan da
# zemin de OKUNUR kalir. "Parlak = iyi aydinlatilmis" degildir; parlak, bilgi
# kaybidir ve geri gelmez.
#
# ── 🔴 IKINCI DERT: KUSAK KAYBI ─────────────────────────────────────────────
# Salon su ana kadar kadraj → 3 AI gecisi → keystone'dan gecti. Her gecis
# yeniden olcekleme ve yeniden sikistirma demek; netlik her turda biraz daha
# gider. Bu arac SONDA bir kez kosar ve kaybin bir kismini geri alir — ama
# ASIL COZUM duzeltmeleri UST USTE YIGMAK degil, parametreleri toplayip
# KAYNAKTAN TEK SEFERDE kosmaktir.
#
# Kullanim: isik-duzelt.sh <girdi> <cikti> [--parlak 0.06] [--gama 0.96] [--netlik 0.8]
set -uo pipefail
export PATH="$PATH:/config/bin"
GIR="${1:-}"; CIK="${2:-}"; PARLAK="0.0"; GAMA="0.98"; NETLIK="0.8"; DOYGUN="1.02"
shift 2 2>/dev/null || { echo "kullanim: isik-duzelt.sh <girdi> <cikti> [--parlak N] [--gama N] [--netlik N] [--doygun N]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --parlak) PARLAK="${2:-}"; shift 2 ;;
    --gama) GAMA="${2:-}"; shift 2 ;;
    --netlik) NETLIK="${2:-}"; shift 2 ;;
    --doygun) DOYGUN="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
[ -f "$GIR" ] || { echo "[kirmizi] girdi yok: $GIR" >&2; exit 1; }

# Patlamis piksel orani ONCE olculur — korlemesine parlaklik oynamak yerine
# NE KADAR bilgi kaybi oldugunu bilerek mudahale et.
patlak() { ffmpeg -hide_banner -loglevel error -i "$1" -vf "format=gray,scale=300:-1" -f rawvideo - 2>/dev/null \
  | python3 -c "
import sys
d=sys.stdin.buffer.read(); n=len(d) or 1
print('%.2f' % (100.0*sum(1 for v in d if v>=250)/n))"; }
P0="$(patlak "$GIR")"

# curves: parlak ucu geri cek (highlight recovery), golgeyi hafif ac.
mkdir -p "$(dirname "$CIK")"
ffmpeg -hide_banner -loglevel error -y -i "$GIR" \
  -vf "curves=all='0/0 0.25/0.27 0.75/0.73 1/0.94',eq=brightness=${PARLAK}:gamma=${GAMA}:saturation=${DOYGUN},unsharp=5:5:${NETLIK}:5:5:0.0" \
  -q:v 2 "$CIK" || exit 1
[ -s "$CIK" ] || { echo "[kirmizi] çıktı üretilemedi" >&2; exit 1; }
P1="$(patlak "$CIK")"
echo "[yesil] ışık düzeltildi · patlamış piksel %${P0} → %${P1} · netlik +${NETLIK} · 0 kredi (yerel, AI yok)"
