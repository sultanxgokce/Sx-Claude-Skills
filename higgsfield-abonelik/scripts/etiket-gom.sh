#!/usr/bin/env bash
# etiket-gom.sh — zorunlu görünür AI-etiketini videoya GÖMER (G8 · kill-kriteri (c)).
#
# NEDEN: 1.8.2026 yönetmeliği (RG 33297) videonun görünür yerinde AI-etiketi ve "Reklam"
#   ibaresi zorunlu kılıyor. UYUM-BLOK §B: "Etiket, izleyicinin KAÇIRMASININ MÜMKÜN OLMADIĞI
#   yerde olur. Küçük punto, saydam, 1 saniye görünen, yalnız açıklamanın 5. satırında geçen
#   etiket → ETİKET SAYILMAZ." Bu script o kuralı mekanik olarak uygular.
#
# TASARIM KARARLARI (ve neden):
#   • Etiket VİDEO BOYUNCA durur. "Kaçırılması imkânsız" ölçütünün en güvenli okuması
#     kalıcı etikettir. --sure ile daraltılabilir AMA asgarinin altına inilemez.
#   🔴 ASGARİ SÜRE SABİT DEĞİL, HESAPLANIR (md. 20/1): kelime×0,25 sn + ≤9 kelimede +3 sn.
#     Bu dosyanın v1'i "yönetmelik minimumu 3 saniye" diyordu — YANLIŞTI (8 kelimelik
#     etiketimiz için asgari 5 sn). Hesap scripts/etiket-sure.py'de, TEK KAYNAK.
#   • ÜSTTE durur: alt şerit platform arayüzüyle (beğeni/açıklama) örtülür, etiket kaybolur.
#   • Arkasında opak şerit var: saydam yazı okunaksız arka planda "görünür" sayılmaz.
#   • Punto video genişliğine oranlıdır (%4.5), sabit piksel değil — her çözünürlükte okunur kalır.
#   • Çıktıya METADATA damgası basılır; uyum-lint bunu ffprobe ile OKUR. Elle hazırlanmış bir
#     dosyada bu damga olmaz → "etiket gömdüm" iddiası mekanik olarak doğrulanabilir hale gelir.
#
# Kullanım: etiket-gom.sh <girdi.mp4> <cikti.mp4> [--sure <saniye>]
# Exit: 0=tamam · 1=hata · 2=kullanım
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
KANON="$REPO/uyum/UYUM-BLOK.md"
FONT="${TELLAL_FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}"
DAMGA_ANAHTAR="TELLAL-AI-ETIKET"

GIRDI="${1:-}"; CIKTI="${2:-}"; shift 2 2>/dev/null || true
SURE=""; EKLER=()
while [ $# -gt 0 ]; do
  case "$1" in
    --sure) shift; SURE="${1:-}" ;;
    --ek) shift; [ -n "${1:-}" ] || { echo "--ek bos olamaz" >&2; exit 2; }; EKLER+=("$1") ;;
    *) echo "bilinmeyen secenek: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "$GIRDI" ] || [ -z "$CIKTI" ]; then
  echo "kullanim: etiket-gom.sh <girdi.mp4> <cikti.mp4> [--sure <saniye>] [--ek \"<satir>\"]..." >&2
  echo "  etiket varsayilan olarak VIDEO BOYUNCA durur (yonetmelik minimumu 3sn; kalici en guvenlisi)" >&2
  exit 2
fi
command -v ffmpeg  >/dev/null 2>&1 || { echo "[kirmizi] ffmpeg yok"  >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "[kirmizi] ffprobe yok" >&2; exit 1; }
[ -f "$GIRDI" ] || { echo "[kirmizi] girdi yok: $GIRDI" >&2; exit 1; }
[ -f "$FONT" ]  || { echo "[kirmizi] font yok: $FONT (TELLAL_FONT ile degistir)" >&2; exit 1; }
[ -f "$KANON" ] || { echo "[kirmizi] kanon yok: $KANON" >&2; exit 1; }

# ── Etiket metni KANONDAN türetilir, burada yazilmaz (tek-kaynak) ─────────────
# UYUM-BLOK §A'daki AI-ETIKET ve REKLAM-IBARESI markorlerinin insan-metni birlestirilir.
AI_METIN="$(grep -m1 '^\[AI-ETIKET\]' "$KANON" | sed 's/^\[AI-ETIKET\][[:space:]]*//; s/[[:space:]]*$//')"
REK_METIN="$(grep -m1 '^\[REKLAM-IBARESI\]' "$KANON" | sed 's/^\[REKLAM-IBARESI\][[:space:]]*//; s/[[:space:]]*$//')"
[ -n "$AI_METIN" ] && [ -n "$REK_METIN" ] || { echo "[kirmizi] kanondan etiket metni okunamadi" >&2; exit 1; }
# Videoda IKI SATIR: uzun tek satir 720px'e sigmiyor ve KESILIYOR (firsthand: ilk deneme
# "Reklam / Tanitim - Bu video yapay zeka ile ureti..." diye kirpildi). Kesik etiket,
# yonetmeligin "kacirilmasi imkansiz" olcutunu karsilamaz -> gecerli etiket DEGILDIR.
# 🔴 SATIR SAYISI ARTIK SABIT DEGIL (2026-08-23). Eskiden tam iki satirdi ve bu,
# [SENTETIK-AVATAR] ibaresini basmayi IMKANSIZ kiliyordu — yani anayasa §5'in
# "videodaki kisi gercek degildir" sartini tasiyamiyorduk ve sentetik kisi videosu
# teslim edilemiyordu. Ucuncu satir yalnizca gorunumu degil ASGARI SUREYI de degistirir
# (md. 20/1 kelime basina 0,25 sn), o yuzden sure hesabi da diziden turetilir.
SATIRLAR=("$REK_METIN" "$AI_METIN")
[ ${#EKLER[@]} -gt 0 ] && SATIRLAR+=("${EKLER[@]}")
ETIKET="$(IFS='|'; echo "${SATIRLAR[*]}")"

# ── Video olculeri ────────────────────────────────────────────────────────────
GEN="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$GIRDI" | tr -d '\r,')"
[ -n "$GEN" ] || { echo "[kirmizi] video genisligi okunamadi (bozuk dosya?)" >&2; exit 1; }
KENAR=$(( GEN * 25 / 1000 ))
KULLANILIR=$(( GEN - 2 * KENAR ))

# Punto: once arzu edilen (%4.5), sonra EN UZUN SATIRA gore kucult ki tasmasin.
# DejaVu Sans Bold ortalama karakter genisligi ~= 0.62 * punto (olculdu, muhafazakar).
UZUN=0
for _s in "${SATIRLAR[@]}"; do [ ${#_s} -gt $UZUN ] && UZUN=${#_s}; done
PUNTO=$(( GEN * 45 / 1000 ))
SIGAN=$(python3 -c "print(int($KULLANILIR / (0.62 * $UZUN)))")
[ "$SIGAN" -lt "$PUNTO" ] && PUNTO="$SIGAN"
if [ "$PUNTO" -lt 14 ]; then
  echo "[kirmizi] etiket bu genislige (${GEN}px) okunabilir puntoyla SIGMIYOR (hesaplanan ${PUNTO}px < 14px)." >&2
  echo "           Kucuk punto = etiket sayilmaz (UYUM-BLOK B). Daha genis video ya da kisa metin gerekir." >&2
  exit 1
fi
SATIR_YUK=$(( PUNTO * 13 / 10 ))

# drawtext kacisi: ' : \ % karakterleri filtre sozdizimini bozar
kacir() { printf '%s' "$1" | sed "s/\\\\/\\\\\\\\\\\\\\\\/g; s/:/\\\\:/g; s/'/\\\\\\\\'/g; s/%/\\\\%/g"; }
# (kacis suzgec kurulurken satir satir yapilir)
# ── SÜRE KAPISI (md. 20/1) ────────────────────────────────────────────────────
# Hem daraltılmış etiket süresi hem de videonun kendi uzunluğu asgariyi taşımalı:
# 2 saniyelik bir videoya 5 saniyelik etiket sığmaz — "video boyunca" demek onu kurtarmaz.
SUREHESAP="$SCRIPT_DIR/etiket-sure.py"
[ -f "$SUREHESAP" ] || { echo "[kirmizi] etiket-sure.py yok: $SUREHESAP" >&2; exit 1; }
ASGARI="$(python3 "$SUREHESAP" hesapla "${SATIRLAR[@]}")" \
  || { echo "[kirmizi] asgari sure hesaplanamadi" >&2; exit 1; }

VSURE="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$GIRDI" 2>/dev/null | tr -d '\r,')"
if [ -n "$VSURE" ]; then
  python3 "$SUREHESAP" yeter "$VSURE" "${SATIRLAR[@]}" >/dev/null || {
    echo "[kirmizi] VIDEO asgari etiket suresinden KISA: ${VSURE}sn < ${ASGARI}sn (md. 20/1)." >&2
    echo "           Etiket video boyunca dursa bile yonetmelik suresi dolmuyor." >&2
    exit 1; }
fi

ZAMAN=""
if [ -n "$SURE" ]; then
  python3 "$SUREHESAP" yeter "$SURE" "${SATIRLAR[@]}" >/dev/null || {
    echo "[kirmizi] --sure ${SURE}sn, asgari ${ASGARI}sn'nin ALTINDA (md. 20/1) — reddedildi." >&2
    exit 1; }
  ZAMAN=":enable='lte(t\\,${SURE})'"
fi
KUTU=$(( KENAR / 2 ))
# Satir araligi KUTU DOLGUSUNU da saymali — gorsel kardesinde bu bir kez kusur olarak
# yasandi: alttaki seridin ustu, ustteki satirin p/y/g kuyruklarini ORTUYORDU.
SATIR_ADIM=$(( SATIR_YUK + 2 * KUTU ))
SUZGEC=""
for _i in "${!SATIRLAR[@]}"; do
  _y=$(( KENAR + _i * SATIR_ADIM ))
  [ -n "$SUZGEC" ] && SUZGEC+=","
  SUZGEC+="drawtext=fontfile='${FONT}':text='$(kacir "${SATIRLAR[$_i]}")':fontcolor=white:fontsize=${PUNTO}:box=1:boxcolor=black@0.78:boxborderw=${KUTU}:x=(w-text_w)/2:y=${_y}${ZAMAN}"
done

echo "→ etiket gomuluyor: \"$ETIKET\""
echo "  video=${GEN}px  punto=${PUNTO}px (${#SATIRLAR[@]} satir)  konum=UST  sure=${SURE:-tum video}  asgari=${ASGARI}sn"

ffmpeg -hide_banner -loglevel error -y -i "$GIRDI" -vf "$SUZGEC" \
  -codec:a copy \
  -metadata "comment=${DAMGA_ANAHTAR}=1; kanon=uyum/UYUM-BLOK.md; etiket=${ETIKET}" \
  "$CIKTI" || { echo "[kirmizi] ffmpeg basarisiz" >&2; exit 1; }

[ -s "$CIKTI" ] || { echo "[kirmizi] cikti bos" >&2; exit 1; }

# ── Kendi isini DOGRULA (iddia etme, olc) ────────────────────────────────────
DAMGA="$(ffprobe -v error -show_entries format_tags=comment -of default=nw=1:nk=1 "$CIKTI" 2>/dev/null)"
printf '%s' "$DAMGA" | grep -q "$DAMGA_ANAHTAR=1" \
  || { echo "[kirmizi] damga yazilamadi — cikti dogrulanamadi" >&2; exit 1; }

echo "[yesil] etiket gomuldu: $CIKTI"
echo "  sha256: $(sha256sum "$CIKTI" | cut -d' ' -f1)"
echo "  damga : $DAMGA_ANAHTAR=1 (uyum-lint bunu ffprobe ile dogrular)"
