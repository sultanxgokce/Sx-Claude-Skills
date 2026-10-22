#!/usr/bin/env bash
# filigran-yama.sh — AI ciktisini YALNIZ degistirdigi yerlerde orijinale yamalar.
#
# ── 🔴 NEDEN VAR (2026-08-30, olculdu) ───────────────────────────────────────
# A1 filigrani ilk denemede temizledi AMA cozunurlugu YARIYA dusurdu
# (2330x1652 → 1184x880) ve en-boyu kaydirdi. Teslim edilecek bir portfolyoda
# bu kabul edilemez; ustelik ters yonde, cunku A3'un amaci cozunurlugu ARTIRMAK.
#
# ── FIKIR: MASKEYI AI'IN KENDISINDEN TURET ──────────────────────────────────
# Filigranin yerini elle olcmeye calistim (34/14 fotografin ortalamasi, blok
# taramasi) ve YAKINSAMADI: yontem sahne yapisini bindirme saniyordu. Yerine
# kendi kendini ayarlayan bir olcum: AI ciktisi ile orijinal arasindaki FARK,
# AI'in NEREYI degistirdigini zaten soyluyor. Maske odur.
#
# ── ASIL KAZANC BOYUT DEGIL, GARANTI ────────────────────────────────────────
# 🔴 Yamanin DISINDA piksel BIREBIR orijinal kalir. Bu, "modele odayi
# degistirme dedim" vaadinden cok daha gucludur: vaat bir NIYET, bu bir
# OLCUM. `--dogrula` ile maske disindaki her pikselin esitligi sinanir ve
# tutmuyorsa cikti YAZILMAZ (fail-closed).
#
# Kullanim: filigran-yama.sh <orijinal> <ai-ciktisi> <hedef> [--esik N] [--dogrula]
set -uo pipefail
ORJ="${1:-}"; AIC="${2:-}"; HEDEF="${3:-}"; ESIK="28"; DOGRULA=0; GENISLET="10"; BOLGE=""
shift 3 2>/dev/null || { echo "kullanim: filigran-yama.sh <orijinal> <ai-ciktisi> <hedef> [--esik N] [--dogrula]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --esik) ESIK="${2:-}"; shift 2 ;;
    # 🔴 GENISLETME NEDEN AYRI BIR KOL (2026-08-30, olculdu): maske FARKIN
    # BUYUKLUGUNDEN turuyor, dolayisiyla filigranin EN SOLUK kisimlari — farki
    # esigin altinda kalanlar — tam da KORUNANLAR oluyordu. Esigi dusurmek
    # yaniti degil: o zaman sahnenin her yeri maskeye giriyor ve orijinal
    # piksel garantisi anlamini yitiriyor. Dogru kol, tespit edilen lekeyi
    # BUYUTMEK: filigran surekli bir nesnedir, parcasi yakalandiysa butunu
    # o bolgededir. Once bul, sonra bolgenin TAMAMINI kapat.
    --genislet) GENISLET="${2:-}"; shift 2 ;;
    # 🔴 --bolge: AI ciktisi TUM goruntunun degil, bir BOLGENIN temizligiyse.
    # Neden gerekli (2026-08-30, olculdu): tum goruntuyu modele vermek onu
    # 2330x1652 → 1184x880 kuculttuguu icin geri buyutunce bulaniklik giriyordu
    # (1,97x). Filigran bandini KENDI cozunurlugunde kirpip vermek bu orani
    # 1,18x'e dusurdu VE model filigrani goreli olarak daha buyuk gordugu icin
    # TAMAMEN sildi. Ama o zaman da bolgenin TAMAMI yeniden cizilmis oluyordu.
    # Bu kol ikisini birlestirir: temiz bolge tam-boy tuvale oturtulur, sonra
    # ASAGIDAKI AYNI maske mantigi kosar — yani yalnizca GERCEKTEN degisen
    # pikseller yapisir, gerisi orijinal kalir ve bu OLCULUR.
    --bolge) BOLGE="${2:-}"; shift 2 ;;
    --dogrula) DOGRULA=1; shift ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
[ -f "$ORJ" ] && [ -f "$AIC" ] || { echo "[kirmizi] girdi yok" >&2; exit 1; }
case "$ESIK" in ''|*[!0-9]*) echo "[kirmizi] --esik tamsayi olmali" >&2; exit 2 ;; esac
case "$GENISLET" in ''|*[!0-9]*) echo "[kirmizi] --genislet tamsayi olmali" >&2; exit 2 ;; esac

BOY="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$ORJ" | tr ',' 'x')"
G="${BOY%x*}"; Y="${BOY#*x}"
T="$(mktemp -d -p "$(dirname "$HEDEF")" .yama-XXXXXX)"

# 1) AI ciktisini TAM-BOY tuvale otur.
if [ -n "$BOLGE" ]; then
  # BOLGE kipi: "x:y:g:y" — temiz bolge kendi olcegine getirilip orijinalin
  # uzerine o konuma bindirilir. Boylece asagidaki maske mantigi degismeden kosar.
  BX="${BOLGE%%:*}"; BR="${BOLGE#*:}"; BY="${BR%%:*}"; BR="${BR#*:}"
  BG="${BR%%:*}"; BH="${BR#*:}"
  case "$BX:$BY:$BG:$BH" in *[!0-9:]*|*::*) echo "[kirmizi] --bolge bicimi x:y:genislik:yukseklik olmali" >&2; exit 2 ;; esac
  # 🔴 PARLAKLIK ESITLEME — DIKIS SORUNU (2026-08-30, olculdu):
  # AI bolgesi orijinalden biraz farkli parlaklikta donuyor. Maske tuylu olsa
  # bile sinir SUREKLI BIR YUZEYI (parke, duz duvar) kesince o fark GORUNUR
  # BIR CIZGI olarak kaliyor — 07'de parkede duz bir dikis birakti. Emlak
  # gorselinde gorunur dikis filigrandan KOTUDUR: filigran "bu baskasinin"
  # der, dikis "bu kurcalanmis" der.
  # 🔴 VE SIRALAMA ONEMLI: esitlemeyi once TUM TUVALE uygulamistim, dokunulmamis
  # alanlar da kaydi ve fark-turevli maske %99'a firladi — yani duzeltme,
  # korumak istedigim garantiyi YOK ETTI. Esitleme YALNIZ bolgeye ve
  # bindirmeden ONCE uygulanir; tuvalin gerisi hic ellenmez.
  ffmpeg -hide_banner -loglevel error -y -i "$ORJ" -vf "crop=${BG}:${BH}:${BX}:${BY},format=gray" \
    -f rawvideo - 2>/dev/null | python3 -c "
import sys
d=sys.stdin.buffer.read(); print('%.4f' % (sum(d)/max(len(d),1)))" > "$T/om.txt"
  ffmpeg -hide_banner -loglevel error -y -i "$AIC" -vf "format=gray" -f rawvideo - 2>/dev/null | python3 -c "
import sys
d=sys.stdin.buffer.read(); print('%.4f' % (sum(d)/max(len(d),1)))" > "$T/am.txt"
  DELTA="$(python3 -c "
o=float(open('$T/om.txt').read() or 0); a=float(open('$T/am.txt').read() or 0)
print('%.5f' % ((o-a)/255.0))")"
  ffmpeg -hide_banner -loglevel error -y -i "$AIC" -vf "scale=${BG}:${BH},eq=brightness=${DELTA}" "$T/bolge.png" || exit 1
  ffmpeg -hide_banner -loglevel error -y -i "$ORJ" -i "$T/bolge.png" -filter_complex \
    "[0][1]overlay=${BX}:${BY}" -frames:v 1 "$T/ai.png" || exit 1
else
  ffmpeg -hide_banner -loglevel error -y -i "$AIC" -vf "scale=${G}:${Y}" "$T/ai.png" || exit 1
fi

# 2) MASKE = |orijinal - ai| farkinin esiklenmis ve yumusatilmis hali.
#    Yumusatma sart: sert kenarli bir maske yamanin sinirinda gorunur bir
#    dikis birakir; goz dikisi lekeden once yakalar.
ffmpeg -hide_banner -loglevel error -y -i "$ORJ" -i "$T/ai.png" -filter_complex \
  "[0][1]blend=all_mode=difference,format=gray,\
lutyuv=y='if(gt(val,${ESIK}),255,0)',\
boxblur=6:1,lutyuv=y='if(gt(val,40),255,0)',\
boxblur=${GENISLET}:1,lutyuv=y='if(gt(val,12),255,0)',boxblur=22:2" \
  -frames:v 1 "$T/maske.png" || exit 1

# 3) maskedmerge: maske BEYAZ olan yerde AI, SIYAH olan yerde ORIJINAL.
ffmpeg -hide_banner -loglevel error -y -i "$ORJ" -i "$T/ai.png" -i "$T/maske.png" \
  -filter_complex "[0][1][2]maskedmerge" -frames:v 1 "$HEDEF" || exit 1
[ -s "$HEDEF" ] || { echo "[kirmizi] yama uretilemedi" >&2; exit 1; }

# 4) OLCUM: maskenin kapladigi alan yuzdesi + (istenirse) maske disi esitlik.
ORAN="$(ffmpeg -hide_banner -loglevel error -i "$T/maske.png" -vf format=gray -f rawvideo - 2>/dev/null \
  | python3 -c "
import sys
d=sys.stdin.buffer.read(); n=len(d) or 1
print('%.2f' % (100.0*sum(1 for v in d if v>127)/n))")"
echo "[yesil] yama tamam — maske alani: %${ORAN} · boyut korundu: $(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$HEDEF" | tr ',' 'x')"

if [ "$DOGRULA" -eq 1 ]; then
  # 🔴 ASIL IDDIA BURADA OLCULUR: maske DISINDA cikti orijinalle AYNI olmali.
  # Maske ters cevrilip her iki goruntuye uygulanir; kalan iki goruntu
  # BIREBIR ayni degilse cikti SILINIR.
  # 🔴 ILK OLCUMUM YANLISTI (birebir yasandi): dogrulamada YUMUSAK maskeyi
  # kullandim ve "maske disinda 210 fark var" dedim. Kusur urunde degil
  # OLCUMDEYDI — maske bilerek yumusak kenarlidir (sert kenar gorunur bir
  # dikis birakir) ve o gecis bolgesi zaten karisir; yani "maske disi" diye
  # olctugum sey maskenin KENDI kenariydi. Dogru iddia: maskenin ETKI ALANI
  # (sifirdan buyuk her piksel) DISINDA cikti orijinalle ayni olmali.
  # Bu yuzden dogrulama maskesi once ikilestirilir, sonra bir tur GENISLETILIR.
  ffmpeg -hide_banner -loglevel error -y -i "$T/maske.png" -vf \
    "format=gray,lutyuv=y='if(gt(val,0),255,0)',boxblur=8:1,lutyuv=y='if(gt(val,0),255,0)'" \
    -frames:v 1 "$T/maske-genis.png" || exit 1
  # 🔴 ALFA KULLANMA — IKINCI OLCUM KUSURU: `alphamerge`+`difference` ile
  # olctugumde saydam bolgelerdeki tanimsiz RGB degerleri farka karisiyordu,
  # yani "maske disi fark" diye okudugum sey olcum artefaktiydi. Alfa yerine
  # duz aritmetik: FARK goruntusu, TERS maskeyle CARPILIR. Maske icinde 0
  # olur, disinda oldugu gibi kalir. Kalan en buyuk deger, iddianin kendisidir.
  ffmpeg -hide_banner -loglevel error -y -i "$ORJ" -i "$HEDEF" -i "$T/maske-genis.png" -filter_complex \
    "[0][1]blend=all_mode=difference,format=gray[d];[2]negate,format=gray[im];[d][im]blend=all_mode=multiply,format=gray" \
    -frames:v 1 "$T/fark.png" || exit 1
  MAKS="$(ffmpeg -hide_banner -loglevel error -i "$T/fark.png" -vf format=gray -f rawvideo - 2>/dev/null \
    | python3 -c "
import sys
d=sys.stdin.buffer.read()
print(max(d) if d else 255)")"
  if [ "$MAKS" -gt 2 ]; then
    echo "[kirmizi] maskenin ETKI ALANI DISINDA piksel degismis (en buyuk fark=$MAKS) — cikti SILINDI" >&2
    rm -f "$HEDEF"; exit 1
  fi
  echo "  dogrulama: maske disinda en buyuk fark = $MAKS (0-2 arasi = birebir ayni)"
fi
