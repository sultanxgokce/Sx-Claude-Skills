#!/usr/bin/env bash
# kadraj-duzelt.sh — A2: balik gozu / perspektif / yatay duzeltme. YEREL, BEDAVA, AI YOK.
#
# ── 🔴 NEDEN AYRI VE NEDEN ONCE BU (Sultan direktifi 2026-09-06) ────────────
# Sultan: "kamera yuksekligi acisi ve acikligi kotu, balik gozu gibi durmus,
# profesyonel bir kameraci cekmis gibi degil — bu cok onemli".
# Hakli ve bu, uc turdur gozden kacirdigim en buyuk kalem: dagi̇nikligi
# kaldirmak fotografi TEMIZ yapar, kadraji duzeltmek PROFESYONEL yapar.
# Ikisi ayri istir ve ikincisi daha cok fark yaratir.
#
# 🔴 AI DEGIL, OPTIK: bu duzeltme fotografin ICERIGINE dokunmaz — yalniz
# merceğin bozdugu geometriyi geri alir. Dolayisiyla BEYAN GEREKTIRMEZ ve
# hicbir kredi harcamaz. Once bunu kos, sonra AI dusun.
#
# Kullanim: kadraj-duzelt.sh <girdi> <cikti> [--k1 0.12] [--yatay 0] [--kirp 0.92]
set -uo pipefail
export PATH="/config/bin:$PATH"
GIR="${1:-}"; CIK="${2:-}"; K1="0.12"; YATAY="0"; KIRP="0.94"; DIKEY="0"
shift 2 2>/dev/null || { echo "kullanim: kadraj-duzelt.sh <girdi> <cikti> [--k1 N] [--yatay derece] [--kirp oran]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --k1) K1="${2:-}"; shift 2 ;;
    --yatay) YATAY="${2:-}"; shift 2 ;;
    # 🔴 --dikey: KEYSTONE (perspektif) duzeltmesi — ve bu, araci ilk yazdigimda
    # EKSIK biraktigim kalemdi. lenscorrection MERCEGIN egriligini duzeltir
    # (duz cizgi yay gibi cikar); keystone ise KAMERANIN EGIKLIGINDEN dogar
    # (dusey cizgiler paralel kalmaz, yukari dogru yakinsar). Ikisi AYRI
    # kusurdur ve biri otekini duzeltmez.
    # Sultan uc kez "kamera yuksekligi acisi kotu, kontrolsuz cekilmis gibi"
    # dedi; ben her seferinde lenscorrection'i ayarladim ve ASIL KUSURA HIC
    # DOKUNMADIM. Ic mekan fotografciliginda duseyin dusey olmasi, netlikten
    # de isiktan da once gelir — goz once ONU fark eder.
    # Deger: pozitif = kamera YUKARI bakiyordu (ust yakinsak) → ustu genislet.
    --dikey) DIKEY="${2:-}"; shift 2 ;;
    --kirp) KIRP="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
[ -f "$GIR" ] || { echo "[kirmizi] girdi yok: $GIR" >&2; exit 1; }
ONCE="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$GIR" | tr ',' 'x')"

# lenscorrection kenarlarda bosluk birakir → kirp. Yatay egiklik varsa once dondur.
VF=""
if [ "$DIKEY" != "0" ]; then
  # perspective: kaynak dortgeninin ust kenarini ice alarak duseyleri paralelle.
  VF="perspective=x0=W*${DIKEY}:y0=0:x1=W*(1-${DIKEY}):y1=0:x2=0:y2=H:x3=W:y3=H:interpolation=linear,"
fi
VF="${VF}lenscorrection=k1=-${K1}:k2=0"
[ "$YATAY" != "0" ] && VF="rotate=${YATAY}*PI/180:ow=rotw(${YATAY}*PI/180):oh=roth(${YATAY}*PI/180),$VF"
VF="$VF,crop=iw*${KIRP}:ih*${KIRP}:iw*(1-${KIRP})/2:ih*(1-${KIRP})/2"
mkdir -p "$(dirname "$CIK")"
ffmpeg -hide_banner -loglevel error -y -i "$GIR" -vf "$VF" -q:v 2 "$CIK" || exit 1
[ -s "$CIK" ] || { echo "[kirmizi] çıktı üretilemedi" >&2; exit 1; }
SONRA="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$CIK" | tr ',' 'x')"
echo "[yesil] kadraj düzeltildi: $ONCE → $SONRA · k1=-$K1 · dikey=$DIKEY · 0 kredi (yerel, AI yok)"
