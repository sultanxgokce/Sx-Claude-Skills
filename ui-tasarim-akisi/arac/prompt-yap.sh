#!/usr/bin/env bash
# prompt-yap.sh — yuvalı prompt şablonunu yapıştırılabilir hâle getirir.
#
# Niçin bir araç var: sözleşme ve estetik yön promptlara elle kopyalansaydı, onlar değiştiğinde
# kopyalar bayatlar ve hangisinin güncel olduğu bilinmezdi. Yuva bayatlamaz.
#
# Kullanım:
#   prompt-yap.sh <sablon.md> [--onceki <önceki-sayfa>] [--dil <dosya>] [--estetik <dosya>]
#                             [--niyet <dosya>] [--olcum-dizini <dizin>]
#
# Yuvalar:
#   {{TASARIM_DILI}}  → --dil ile verilen dosya      (varsayılan: <kök>/tasarim/tasarim-dili.md)
#   {{ESTETIK_YON}}   → --estetik ile verilen dosya  (varsayılan: <kök>/tasarim/estetik-yon.md)
#   {{URUN_NIYETI}}   → --niyet ile verilen dosya    (Durak 0; varsayılan: <kök>/tasarim/urun-niyeti.md)
#   {{ONCEKI_HTML}}   → --onceki ile verilen dosya   (devam promptlarında zorunlu)
#   diğer {{...}}     → şablon kopyası çıkarılırken ELLE doldurulur; dolmamışsa üretim DURUR
#
# İKİ KAPI (ikisi de ölçülmüş bir hüsranın panzehiri):
#   · Durak 0 — niyet dosyasındaki her "Kendi cümlem:" satırı DOLU olmalı. Şık seçmek yetmez;
#     asıl bağlam cümlede. (Bir tam tur bu konuşma yapılmadığı için çöpe gitti.)
#   · Ölçüm — devam promptu (--onceki) üretilmeden ÖNCE önceki sayfa yoğunluk kapısından
#     geçirilir. Kırmızıysa prompt ÜRETİLMEZ: ölçülmemiş sayfanın üstüne sonraki sayfa
#     çizilirse hata bütün diziye yayılır.
#
# Çıkış: 0 üretildi · 1 önceki sayfa kapıdan geçmedi · 2 eksik/geçersiz girdi
#        3 ÖLÇÜLEMEDİ (kapı profili yok / araç yok) — "temiz" DEĞİL, "bakılamadı"
set -euo pipefail

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOK="${UI_AKIS_KOK:-$PWD}"
SOZLESME="${UI_AKIS_DIL:-$KOK/tasarim/tasarim-dili.md}"
ESTETIK="${UI_AKIS_ESTETIK:-$KOK/tasarim/estetik-yon.md}"
NIYET="${UI_AKIS_NIYET:-$KOK/tasarim/urun-niyeti.md}"

SABLON="${1:-}"
[ -n "$SABLON" ] || { echo "kullanım: prompt-yap.sh <sablon.md> [--onceki <sayfa>] [--dil <d>] [--estetik <d>] [--niyet <d>]" >&2; exit 2; }
[ -f "$SABLON" ] || { echo "HATA: şablon yok: $SABLON" >&2; exit 2; }
shift

ONCEKI=""; OLCUM_DIZINI=""
while [ $# -gt 0 ]; do
  case "$1" in
    --onceki)       ONCEKI="${2:-}";        shift 2 ;;
    --dil)          SOZLESME="${2:-}";      shift 2 ;;
    --estetik)      ESTETIK="${2:-}";       shift 2 ;;
    --niyet)        NIYET="${2:-}";         shift 2 ;;
    --olcum-dizini) OLCUM_DIZINI="${2:-}";  shift 2 ;;
    *) echo "HATA: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done

[ -f "$SOZLESME" ] || { echo "HATA: tasarım dili dosyası yok: $SOZLESME" >&2; exit 2; }
[ -f "$ESTETIK" ]  || { echo "HATA: estetik yön dosyası yok: $ESTETIK" >&2; exit 2; }

# ── KAPI 1: Durak 0 — niyet dosyası (şablon istiyorsa) ────────────────────────
if grep -q '{{URUN_NIYETI}}' "$SABLON"; then
  if [ ! -f "$NIYET" ]; then
    echo "HATA: Durak 0 dosyası yok: $NIYET" >&2
    echo "  Çözüm: cp <skill>/sablonlar/urun-niyeti.md \"$NIYET\" ve doldur (5 soru + iskelet)." >&2
    exit 2
  fi
  EKSIK="$(awk -F: '/^Kendi cümlem:/ { n++; sub(/^Kendi cümlem:[[:space:]]*/, "", $0);
                                       if ($0 == "") bos = bos " #" n }
           END { print bos }' "$NIYET")"
  if [ -n "$EKSIK" ]; then
    echo "HATA: Durak 0 yarım — boş 'Kendi cümlem:' satırı var:$EKSIK ($NIYET)" >&2
    echo "  Şık seçmek yetmez: şık senin için, cümle tasarımcı için. Bağlam cümlede taşınır." >&2
    exit 2
  fi
fi

# ── KAPI 2: önceki sayfa ölçülmeden devam promptu üretilmez ───────────────────
if [ -n "$ONCEKI" ] && [ -f "$ONCEKI" ]; then
  DIZIN="${OLCUM_DIZINI:-$(dirname "$ONCEKI")}"
  if [ ! -x "$ARAC/yogunluk-denetle.py" ] && [ ! -f "$ARAC/yogunluk-denetle.py" ]; then
    echo "RC=3 ÖLÇÜLEMEDİ — yoğunluk kapısı aracı yok: $ARAC/yogunluk-denetle.py" >&2; exit 3
  fi
  set +e
  OLCUM="$(python3 "$ARAC/yogunluk-denetle.py" "$DIZIN" 2>&1)"; OLCUM_RC=$?
  set -e
  case "$OLCUM_RC" in
    0) : ;;
    1) echo "$OLCUM" >&2
       echo "" >&2
       echo "HATA: önceki sayfa yoğunluk kapısından GEÇMEDİ — devam promptu üretilmedi." >&2
       echo "  Ölçülmemiş/kırmızı sayfanın üstüne sonraki sayfa çizilirse hata diziye yayılır." >&2
       echo "  Ya sayfayı düzelt ya profildeki sayıyı gerekçesiyle güncelle (sözleşmeyle birlikte)." >&2
       exit 1 ;;
    *) echo "$OLCUM" >&2
       echo "" >&2
       echo "RC=3 ÖLÇÜLEMEDİ — kapı koşamadı (yukarıdaki sebep). Bu 'temiz' DEĞİL, 'bakılamadı'." >&2
       exit 3 ;;
  esac
fi

# Şablonun kendi kullanım başlığı (üstteki '>' bloğu) çıktıya girmez: o bize yazılmış,
# tasarım platformuna değil. Ayraç: ilk '---' satırı.
GOVDE="$(awk 'basildi==1 {print} /^---$/ && basildi==0 {basildi=1}' "$SABLON")"
[ -n "$GOVDE" ] || { echo "HATA: şablonda '---' ayracından sonra gövde yok: $SABLON" >&2; exit 2; }

SABLON="$SABLON" GOVDE="$GOVDE" SOZLESME="$SOZLESME" ESTETIK="$ESTETIK" NIYET="$NIYET" \
ONCEKI="$ONCEKI" python3 - <<'PY'
import os, re, sys

govde  = os.environ["GOVDE"]
sablon = os.environ["SABLON"]

def oku(yol):
    with open(yol, encoding="utf-8") as f:
        return f.read().rstrip("\n")

for yuva, env in (("{{TASARIM_DILI}}", "SOZLESME"), ("{{ESTETIK_YON}}", "ESTETIK")):
    if yuva not in govde:
        sys.stderr.write("HATA: şablonda %s yuvası yok: %s\n" % (yuva, sablon)); sys.exit(2)
    govde = govde.replace(yuva, oku(os.environ[env]))

# Durak 0 yuvası: varlığı şablona bağlı (eski şablonlar kırılmasın), dosyası kabuk tarafında
# doğrulandı — buraya yalnız DOLU niyet dosyasıyla gelinir.
if "{{URUN_NIYETI}}" in govde:
    govde = govde.replace("{{URUN_NIYETI}}", oku(os.environ["NIYET"]))

# ADSIZ/boş yuvalar ({{ }} gibi) alttaki sıkı desene yakalanmaz — sözleşme gövdesi
# gömülürken kaçarlar (ölçüldü: tasarim-dili.md'de 21 yuvanın 20'si kaçıyordu, boş
# sözleşme platforma gidiyordu). Gevşek tarama BURADA koşar — {{ONCEKI_HTML}} henüz
# gömülmeden — ki önceki sayfanın HTML'i içindeki masum {{…}} dizileri yanlış-kırmızı
# yakmasın. {{ONCEKI_HTML}}'in kendisi bu aşamada meşru-bekleyen tek yuvadır, ayıklanır.
bos = sorted(set(re.findall(r"\{\{[^}\n]{0,80}\}\}", govde)) - {"{{ONCEKI_HTML}}"})
if bos:
    sys.stderr.write("HATA: doldurulmamış/adsız yuva var (sözleşme boş kalmış olabilir): %s\n"
                     % ", ".join(repr(b) for b in bos)); sys.exit(2)

onceki = os.environ.get("ONCEKI") or ""
if "{{ONCEKI_HTML}}" in govde:
    if not onceki:
        sys.stderr.write("HATA: bu şablon {{ONCEKI_HTML}} istiyor — --onceki <sayfa> ver\n"); sys.exit(2)
    if not os.path.isfile(onceki):
        sys.stderr.write("HATA: önceki sayfa yok: %s\n" % onceki); sys.exit(2)
    govde = govde.replace("{{ONCEKI_HTML}}", oku(onceki))
elif onceki:
    sys.stderr.write("HATA: --onceki verildi ama şablonda {{ONCEKI_HTML}} yuvası yok\n"); sys.exit(2)

# Dolmamış yuva sessizce platforma gitmesin.
kalan = sorted(set(re.findall(r"\{\{[A-Z_0-9]+\}\}", govde)))
if kalan:
    sys.stderr.write("HATA: doldurulmamış yuva kaldı: %s\n" % ", ".join(kalan)); sys.exit(2)

sys.stdout.write(govde + "\n")
PY
