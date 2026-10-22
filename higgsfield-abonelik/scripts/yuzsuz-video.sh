#!/usr/bin/env bash
# yuzsuz-video.sh — YÜZ GÖSTERMEYEN reklam videosu üreteci (ürün görseli + seslendirme + altyazı).
#
# NİÇİN VAR (2026-08-05, Sultan'ın firsthand geri bildirimi):
#   Sultan ilk gerçek videoyu izledi: *"adamın ağız hareketleri çok yapay, ses fena değil ama
#   yapay zekâ videosu yapaylığından tam kurtulamadık."* Bu, kör-puanlamayla BİREBİR tutarlı:
#   dudak-ses 3/5 · ağız-doğallık 3/5 · telaffuz 4/5 · vurgu 5/5.
#   Yani ölçüm şunu söylüyor: **güçlü yanımız ses, zayıf yanımız ağız.**
#   Bu araç o ölçümün sonucudur: ağzı hiç gösterme, sesi kullan. Taklit edilen bir insan
#   olmayınca "yapay duruyor" sorunu kaynağında ortadan kalkar.
#
# EK FAYDA: tamamen YEREL çalışır (ffmpeg) — kare başına para gitmez. Avatar videosu yerine
#   yalnız seslendirme üretmek gerekir, o da daha ucuzdur.
#
# UYUM: çıktıya zorunlu AI-etiketi `etiket-gom.sh` ile GÖMÜLÜR (kanon: uyum/UYUM-BLOK.md).
#   Etiketsiz çıktı üretilmez — bu araç uyum kapısını atlamanın yolu DEĞİLDİR.
#
# Kullanım:
#   yuzsuz-video.sh --ses <ses.aac|mp4> --gorsel <g1.jpg[,g2.jpg,...]> \
#                   --altyazi <altyazi.txt> --cikti <video.mp4> [--kirp <w,h,x,y>] [--punto 42]
#
#   --ses      : ses dosyası YA DA içinden ses ayrıştırılacak bir video (mp4)
#   --gorsel   : bir ya da daha çok görsel (virgülle). Çok görselde süre eşit bölünür.
#   --altyazi  : her satır  `baslangic|bitis|metin`  (saniye, ondalık serbest)
#   --kirp     : görsele kırpma (ffmpeg crop söz dizimi: w,h,x,y) — paket yazısı elemek için
#   --punto    : altyazı punto (varsayılan 42; sığmazsa OTOMATİK küçülür)
#
# Exit: 0 = video hazır (etiket gömülü) · 1 = üretilemedi/doğrulama · 2 = kullanım
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
GEN=720; YUK=1280                     # 9:16 dikey — teslimat standardı (satis/fiyat-kapsam.md)
FONT="${YUZSUZ_FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}"
ALTYAZI_Y="${YUZSUZ_ALTYAZI_Y:-170}"  # üstteki AI-etiketinin ALTINA düşmeli (etiket ~0-140px)

kirmizi() { printf '\033[31m[kirmizi]\033[0m %s\n' "$*" >&2; }
yesil()   { printf '\033[32m[yesil]\033[0m %s\n' "$*"; }

usage() { sed -n '28,42p' "$0" >&2; exit 2; }

SES=""; GORSEL=""; ALTYAZI=""; CIKTI=""; KIRP=""; PUNTO=42
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ses) shift; SES="${1:-}" ;;
    --gorsel) shift; GORSEL="${1:-}" ;;
    --altyazi) shift; ALTYAZI="${1:-}" ;;
    --cikti) shift; CIKTI="${1:-}" ;;
    --kirp) shift; KIRP="${1:-}" ;;
    --atif) shift; ATIF="${1:-}" ;;
    --punto) shift; PUNTO="${1:-42}" ;;
    *) kirmizi "bilinmeyen argüman: $1"; usage ;;
  esac
  shift 2>/dev/null || break
done

ATIF="${ATIF:-}"
[ -n "$SES" ] && [ -n "$GORSEL" ] && [ -n "$CIKTI" ] || { kirmizi "--ses, --gorsel, --cikti zorunlu"; usage; }
command -v ffmpeg >/dev/null 2>&1 || { kirmizi "ffmpeg yok"; exit 1; }
[ -f "$SES" ] || { kirmizi "ses dosyası yok: $SES"; exit 1; }
[ -f "$FONT" ] || { kirmizi "font yok: $FONT"; exit 1; }

IFS=',' read -r -a GORSELLER <<< "$GORSEL"
for g in "${GORSELLER[@]}"; do
  [ -f "$g" ] || { kirmizi "görsel yok: $g"; exit 1; }
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── 1. Ses: video verildiyse ayrıştır ────────────────────────────────────────
case "$SES" in
  *.mp4|*.mov|*.mkv|*.webm)
    ffmpeg -v error -i "$SES" -vn -acodec copy "$TMP/ses.aac" -y 2>/dev/null \
      || ffmpeg -v error -i "$SES" -vn -c:a aac "$TMP/ses.aac" -y \
      || { kirmizi "sesi ayrıştıramadım: $SES"; exit 1; }
    SESYOL="$TMP/ses.aac" ;;
  *) SESYOL="$SES" ;;
esac
SURE="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$SESYOL" 2>/dev/null)"
case "$SURE" in ''|*[!0-9.]*) kirmizi "ses süresi okunamadı: $SESYOL"; exit 1 ;; esac
awk -v s="$SURE" 'BEGIN{exit !(s>0.5)}' || { kirmizi "ses süresi anlamsız: ${SURE}s"; exit 1; }

# ── 2. Görselleri hazırla (kırp → 9:16 tuvale otur) ──────────────────────────
i=0
for g in "${GORSELLER[@]}"; do
  VF=""
  [ -n "$KIRP" ] && VF="crop=$(printf '%s' "$KIRP" | tr ',' ':'),"
  VF="${VF}scale=${GEN}:-1:force_original_aspect_ratio=decrease,pad=${GEN}:${YUK}:(ow-iw)/2:(oh-ih)/2:white"
  ffmpeg -v error -i "$g" -vf "$VF" "$TMP/g$i.png" -y || { kirmizi "görsel işlenemedi: $g"; exit 1; }
  i=$((i+1))
done
ADET=$i

# ── 3. Altyazı filtresini kur (taşma koruması: sığmazsa punto küçülür) ───────
# NOT: ffmpeg filtre zinciri KESME İŞARETİNİ ve virgülü kaldıramaz — filtre bir DOSYADAN
#   verilir (-filter_complex_script) ve metinler kaçırılır. Bu firsthand öğrenildi:
#   "Trendyol'da" yazısı zinciri kırdı ("No such filter: '16.5'").
TELLAL_ATIF="$ATIF" python3 - "$TMP" "$ADET" "$SURE" "$FONT" "$PUNTO" "$ALTYAZI_Y" "$GEN" "$YUK" "${ALTYAZI:-}" <<'PY' || exit 1
import sys, os
tmp, adet, sure, font, punto, ay, gen, yuk, altyazi = sys.argv[1:10]
adet = int(adet); sure = float(sure); punto = int(punto); ay = int(ay); gen = int(gen); yuk = int(yuk)

# ── ZORUNLU ATIF (F2 probu bulgusu, 2026-08-15) ───────────────────────────────
# 🔴 OLCULDU: Ken Burns yakinlasmasi (zoompan, 1.12x'e kadar) kadrajin KENARLARINI
# ilerledikce disari itiyor. Kaynak gorsele basilmis "© OpenStreetMap contributors"
# atfi teslim edilen videoda YOKTU — lisansen ZORUNLU bir metin sessizce kirpilmisti.
# KURAL: zorunlu hukuki metin, geometrik donusumden SONRA basilir. Kaynaga gomulen
# metin guvende degildir. (Ayni gerekce etiket-gom.sh'in en sonda calismasinin sebebi.)
atif = os.environ.get("TELLAL_ATIF", "").strip()

# Görsel zinciri: tek görselse yavaş yakınlaşma (Ken Burns), çoklu görselse eşit bölüşüm
kare = 25
parc = []
if adet == 1:
    d = int(sure * kare) + kare
    parc.append(f"[0:v]zoompan=z='min(zoom+0.0008,1.12)':d={d}:s={gen}x{yuk}:fps={kare}[bg]")
else:
    her = sure / adet
    for i in range(adet):
        parc.append(f"[{i}:v]zoompan=z='min(zoom+0.0010,1.10)':d={int(her*kare)+2}:s={gen}x{yuk}:fps={kare},"
                    f"setpts=PTS-STARTPTS[p{i}]")
    parc.append("".join(f"[p{i}]" for i in range(adet)) + f"concat=n={adet}:v=1:a=0[bg]")

def kacir(t):
    # ffmpeg drawtext: ters bölü, kesme, iki nokta, köşeli parantez, virgül kaçırılır
    for a, b in (("\\", "\\\\"), ("'", "’"), (":", "\\:"), ("%", "\\%")):
        t = t.replace(a, b)
    return t

satirlar = []
if altyazi and os.path.exists(altyazi):
    for ln in open(altyazi, encoding="utf-8"):
        ln = ln.strip()
        if not ln or ln.startswith("#"): continue
        p = ln.split("|", 2)
        if len(p) != 3:
            print(f"[kirmizi] altyazı satırı bozuk (baslangic|bitis|metin): {ln!r}", file=sys.stderr)
            sys.exit(1)
        try: a, b = float(p[0]), float(p[1])
        except ValueError:
            print(f"[kirmizi] altyazı zamanı sayı değil: {ln!r}", file=sys.stderr); sys.exit(1)
        if b <= a:
            print(f"[kirmizi] altyazı bitiş <= başlangıç: {ln!r}", file=sys.stderr); sys.exit(1)
        if a > sure + 0.5:
            print(f"[sari] altyazı ses süresini ({sure:.1f}s) aşıyor, atlandı: {ln!r}", file=sys.stderr)
            continue
        satirlar.append((a, min(b, sure), p[2].strip()))

zinc = "[bg]"
for i, (a, b, metin) in enumerate(satirlar):
    # TAŞMA KORUMASI: kaba genişlik tahmini; sığmazsa punto küçülür, tabanın altına inmez
    p = punto
    while p > 26 and len(metin) * p * 0.55 > gen - 60:
        p -= 2
    if len(metin) * p * 0.55 > gen - 60:
        print(f"[sari] altyazı {p}px'te bile taşıyor, kısalt: {metin[:40]!r}", file=sys.stderr)
    son = "[v]" if i == len(satirlar) - 1 else f"[t{i}]"
    parc.append(f"{zinc}drawtext=fontfile={font}:text='{kacir(metin)}':fontcolor=black:"
                f"fontsize={p}:box=1:boxcolor=white@0.72:boxborderw=14:"
                f"x=(w-text_w)/2:y={ay}:enable='between(t\\,{a}\\,{b})'{son}")
    zinc = son
if not satirlar:
    parc.append("[bg]null[v]")

# Atif EN SONDA, zoompan'dan SONRA: artik kirpilamaz.
if atif:
    parc.append(f"[v]drawtext=fontfile={font}:text='{kacir(atif)}':fontcolor=white:"
                f"fontsize={max(20, int(gen * 0.030))}:box=1:boxcolor=black@0.80:boxborderw=10:"
                f"x=(w-text_w)/2:y=h-text_h-{max(14, int(yuk * 0.020))}[vatf]")

son_etiket = "[vatf]" if atif else "[v]"
open(os.path.join(tmp, "cikis-etiketi.txt"), "w", encoding="utf-8").write(son_etiket)
open(os.path.join(tmp, "filtre.txt"), "w", encoding="utf-8").write(";".join(parc))
print(f"[bilgi] {adet} görsel · {len(satirlar)} altyazı · {sure:.1f}s", file=sys.stderr)
PY

# ── 4. Videoyu kur ───────────────────────────────────────────────────────────
GIRDI=()
for ((j=0; j<ADET; j++)); do GIRDI+=(-loop 1 -i "$TMP/g$j.png"); done
# 🔴 SECENEK ADI SURUME GORE DEGISIR (2026-09-06, ffmpeg yukseltirken kirildi):
# `-filter_complex_script` ffmpeg 7.1'de KALDIRILDI; yerine `-/filter_complex`
# geldi. Kalici ffmpeg'i yeni bir surumle degistirince bu satir sessizce
# "Unrecognized option" verdi ve 11 kapi iddiasi birden kirildi.
# 🔴 Ders: "daha yeni surum daha iyidir" bir VARSAYIMDIR. Yeni surum bazen
# BIR SEY GOTURUR — ve gotordugu sey senin bagli oldugun seyse, yukseltme
# bir iyilestirme degil BIR ARIZADIR. Kapi bunu yakaladi; kapisiz olsaydik
# reklam hatti bir sabah "video kurulamadi" demeye baslardi.
# Cozum: hangisi varsa onu kullan — iki surumde de calisir.
# 🔴 TAHMIN ETME, DENE (2026-09-06): once `ffmpeg -h full` ciktisini grep'leyip
# hangi secenegin destekLENdigini ANLAMAYA calistim — YANLIS sonuc verdi ve
# video yine kurulamadi. Yardim metnini ayristirmak bir TAHMINDIR; secenegi
# GERCEKTEN denemek bir OLCUMDUR. Once eskisini dene, "Unrecognized option"
# gelirse yenisiyle tekrarla. Iki surumde de calisir ve hangisinde oldugumuzu
# BILMEK zorunda degiliz.
_kur() { ffmpeg -v error "${GIRDI[@]}" -i "$SESYOL" "$1" "$TMP/filtre.txt" \
  -map "$(cat "$TMP/cikis-etiketi.txt")" -map "${ADET}:a" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest -t "$SURE" \
  "$TMP/ham.mp4" -y 2>"$TMP/kur.err"; }
if ! _kur -filter_complex_script; then
  if grep -q 'Unrecognized option' "$TMP/kur.err" 2>/dev/null; then
    _kur -/filter_complex || { cat "$TMP/kur.err" >&2; kirmizi "ffmpeg video kuramadı"; exit 1; }
  else
    cat "$TMP/kur.err" >&2; kirmizi "ffmpeg video kuramadı"; exit 1
  fi
fi

[ -s "$TMP/ham.mp4" ] || { kirmizi "çıktı boş — yazılmadı (fail-closed)"; exit 1; }

# ── 5. ZORUNLU AI-ETİKETİ (atlanamaz) ────────────────────────────────────────
mkdir -p "$(dirname "$CIKTI")"
bash "$SCRIPT_DIR/etiket-gom.sh" "$TMP/ham.mp4" "$CIKTI" >/dev/null || {
  kirmizi "etiket gömülemedi — çıktı YAZILMADI (uyum kapısı, kill-kriteri (c))"
  rm -f "$CIKTI"; exit 1
}

# ── 6. Doğrula: damga gerçekten var mı (iddia etme, ÖLÇ) ─────────────────────
if ! ffprobe -v error -show_entries format_tags=comment -of default=nw=1:nk=1 "$CIKTI" 2>/dev/null \
     | grep -q "TELLAL-AI-ETIKET=1"; then
  kirmizi "damga doğrulanamadı — çıktı siliniyor (sahte-yeşil yasak)"; rm -f "$CIKTI"; exit 1
fi

CSURE="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$CIKTI" 2>/dev/null)"
CBOYUT="$(ffprobe -v error -show_entries stream=width,height -of csv=p=0:s=x "$CIKTI" 2>/dev/null | head -1)"
yesil "yüzsüz video hazır: $CIKTI"
printf '  süre : %.1fs (ses %.1fs)\n  boyut: %s\n  damga: TELLAL-AI-ETIKET=1 (ölçüldü)\n' \
  "$CSURE" "$SURE" "$CBOYUT"
printf '  sha256: %s\n' "$(sha256sum "$CIKTI" | cut -c1-16)…"
