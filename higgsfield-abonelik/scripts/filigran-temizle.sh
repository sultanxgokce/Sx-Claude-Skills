#!/usr/bin/env bash
# filigran-temizle.sh — bir ilan fotografindan filigrani ve ajans logosunu
# kaldirir; dokunulmayan her pikseli BIREBIR korur ve bunu OLCER.
#
# ── ZINCIR (2026-08-30, hepsi olculerek bulundu) ────────────────────────────
#   0) GIRDI KAPISI  — ekran goruntusu zincire GIREMEZ (girdi-kapisi.sh).
#      Kapi olmayinca model "temizlerken" olmayan bir oda UYDURDU.
#   1) ORTA BOLGE    — filigran bandi KENDI cozunurlugunde kirpilir (1600x1200).
#      Tum goruntuyu vermek cozunurlugu yariya dusuruyordu (1,97x geri buyutme);
#      bolge vermek bunu 1,18x'e indirdi VE model filigrani goreli olarak daha
#      buyuk gordugu icin tamamen sildi.
#   2) LOGO KOSESI   — sol alt (900x675), ayri gecis.
#   Her gecis `filigran-yama.sh --bolge` ile geri yapisir: parlaklik esitlenir
#   (dikis olmasin), maske farktan turer, maske DISI birebir kalir ve SINANIR.
#
# 🔴 BOLGELER SABIT DEGIL, VARSAYILAN: filigran kadraja gore ORTALI basiliyor,
# ama her ilanda ayni yerde OLMAYABILIR. Ilk kez gorulen bir kaynakta ciktiya
# GOZLE bakilmali. Bunu bir kez "sabit" sanip 07'yi temizlenmemis halde
# "tamam" diye rapor ettim; olctugum sey BIR SEYIN degistigiydi, DOGRU seyin
# degistigi degil. Sayi yesil yandi, cikti yanlisti.
#
# Kullanim: filigran-temizle.sh <girdi> <cikti> [--orta x:y:g:y] [--logo x:y:g:y]
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HOME="${HOME:-/config}"
GIR="${1:-}"; CIK="${2:-}"; shift 2 2>/dev/null || { echo "kullanim: filigran-temizle.sh <girdi> <cikti> [--orta x:y:g:y] [--logo x:y:g:y]" >&2; exit 2; }
ORTA="365:226:1600:1200"; LOGO="0:977:900:675"
while [ $# -gt 0 ]; do
  case "$1" in
    --orta) ORTA="${2:-}"; shift 2 ;;
    --logo) LOGO="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
[ -f "$GIR" ] || { echo "[kirmizi] girdi yok: $GIR" >&2; exit 1; }

# 0) GIRDI KAPISI — fail-closed
bash "$KOK/scripts/girdi-kapisi.sh" "$GIR" || { echo "[kirmizi] zincire alinmadi: $GIR" >&2; exit 1; }

P="$(bash "$KOK/scripts/staging-saglayici/flux-kontext-fal.sh" --prompt-yaz salon filigran filigran)"
[ -n "$P" ] || { echo "[kirmizi] prompt bos" >&2; exit 1; }
mkdir -p "$(dirname "$CIK")"
IS="$(mktemp -d -p "$(dirname "$CIK")" .ftz-XXXXXX)"
ARA="$IS/ara.png"; GIRDI="$GIR"; HEDEF="$ARA"

n=0
for BOL in "$ORTA" "$LOGO"; do
  n=$((n+1)); [ "$n" -eq 2 ] && { GIRDI="$ARA"; HEDEF="$CIK"; }
  IFS=: read -r x y g h <<<"$BOL"
  case "$x:$y:$g:$h" in *[!0-9:]*) echo "[kirmizi] bölge biçimi x:y:g:y olmalı: $BOL" >&2; exit 2 ;; esac
  D="$IS/g$n"; mkdir -p "$D"
  ffmpeg -hide_banner -loglevel error -y -i "$GIRDI" -vf "crop=$g:$h:$x:$y" "$D/bolge.png" || exit 1
  # 🔴 GECICI HATALARDA YENIDEN DENE (2026-09-03, toplu kosuda yasandi):
  # 63 karelik kosuda BIR kare tek bir "HTTP 503 Service Unavailable" yuzunden
  # dustu. Servis bir an cevap vermemis, o kadar. Videoda ayni dersi 2 Eylul'de
  # ogrenip seedance adaptorune yeniden deneme eklemistim — AMA GORSEL YOLUNA
  # EKLEMEMISTIM. Bir dersi bir yerde uygulayip kardesini atlamak, dersi yarim
  # ogrenmektir; toplu kosuda o yarim, bir kareye mal oldu.
  # Yalniz GECICI sinifta tekrarla; kalici hatalar (gecersiz alan, kota, yasakli
  # icerik) HEMEN dussun ki tekrarla ORTULMESIN.
  DENE=0
  while :; do
    DENE=$((DENE+1))
    higgsfield generate create flux_kontext --prompt "$P" --image "$D/bolge.png" \
      --aspect_ratio 4:3 --wait >"$D/cli.log" 2>&1
    U="$(grep -oE 'https://[^[:space:]"]+\.(png|jpg|jpeg|webp)' "$D/cli.log" | head -1)"
    [ -n "$U" ] && break
    grep -qE '50[0-9]|429|not_enough_boost_credits|timeout|temporarily' "$D/cli.log" || break
    [ "$DENE" -ge 3 ] && break
    echo "  [sari] geçici hata — ${DENE}. deneme, 20 sn sonra tekrar" >&2
    sleep 20
  done
  # 🔴 KANIT DURUM KODU DEGIL CIKTININ VARLIGIDIR
  [ -n "$U" ] || { echo "[kirmizi] geçiş $n üretmedi:" >&2; tail -3 "$D/cli.log" >&2; exit 1; }
  curl -fsSL --max-time 180 "$U" -o "$D/temiz.png" || exit 1
  [ -s "$D/temiz.png" ] || { echo "[kirmizi] geçiş $n indirilemedi" >&2; exit 1; }
  bash "$KOK/scripts/filigran-yama.sh" "$GIRDI" "$D/temiz.png" "$HEDEF" \
    --bolge "$BOL" --esik 14 --genislet 25 --dogrula >"$D/yama.log" 2>&1 || {
      echo "[kirmizi] geçiş $n yamalanamadı:" >&2; tail -2 "$D/yama.log" >&2; exit 1; }
  printf "  geçiş %d (%s): %s\n" "$n" "${g}x${h}" "$(grep -o 'maske alani: %[0-9.]*' "$D/yama.log")"
done

DOK="$(ffmpeg -hide_banner -loglevel error -i "$GIR" -i "$CIK" \
  -filter_complex "[0][1]blend=all_mode=difference,format=gray" -frames:v 1 -f rawvideo - 2>/dev/null \
  | python3 -c "
import sys
d=sys.stdin.buffer.read(); n=len(d) or 1
print('%.1f' % (100.0*sum(1 for x in d if x>2)/n))")"
echo "[yesil] temiz — dokunulan %${DOK} · gerisi BİREBİR orijinal · 3 kredi · $CIK"
