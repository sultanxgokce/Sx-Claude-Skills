#!/usr/bin/env bash
# prompt-yap.sh — yuvalı prompt şablonunu yapıştırılabilir hâle getirir.
#
# Niçin bir araç var: sözleşme ve estetik yön promptlara elle kopyalansaydı, onlar değiştiğinde
# kopyalar bayatlar ve hangisinin güncel olduğu bilinmezdi. Yuva bayatlamaz.
#
# Kullanım:
#   prompt-yap.sh <sablon.md> [--onceki <önceki-sayfa>] [--dil <dosya>] [--estetik <dosya>]
#
# Yuvalar:
#   {{TASARIM_DILI}}  → --dil ile verilen dosya      (varsayılan: <kök>/tasarim/tasarim-dili.md)
#   {{ESTETIK_YON}}   → --estetik ile verilen dosya  (varsayılan: <kök>/tasarim/estetik-yon.md)
#   {{ONCEKI_HTML}}   → --onceki ile verilen dosya   (devam promptlarında zorunlu)
#   diğer {{...}}     → şablon kopyası çıkarılırken ELLE doldurulur; dolmamışsa üretim DURUR
#
# Çıkış: 0 üretildi · 2 eksik/geçersiz girdi (sessizce yarım prompt üretmez)
set -euo pipefail

KOK="${UI_AKIS_KOK:-$PWD}"
SOZLESME="${UI_AKIS_DIL:-$KOK/tasarim/tasarim-dili.md}"
ESTETIK="${UI_AKIS_ESTETIK:-$KOK/tasarim/estetik-yon.md}"

SABLON="${1:-}"
[ -n "$SABLON" ] || { echo "kullanım: prompt-yap.sh <sablon.md> [--onceki <sayfa>] [--dil <d>] [--estetik <d>]" >&2; exit 2; }
[ -f "$SABLON" ] || { echo "HATA: şablon yok: $SABLON" >&2; exit 2; }
shift

ONCEKI=""
while [ $# -gt 0 ]; do
  case "$1" in
    --onceki)  ONCEKI="${2:-}";   shift 2 ;;
    --dil)     SOZLESME="${2:-}"; shift 2 ;;
    --estetik) ESTETIK="${2:-}";  shift 2 ;;
    *) echo "HATA: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done

[ -f "$SOZLESME" ] || { echo "HATA: tasarım dili dosyası yok: $SOZLESME" >&2; exit 2; }
[ -f "$ESTETIK" ]  || { echo "HATA: estetik yön dosyası yok: $ESTETIK" >&2; exit 2; }

# Şablonun kendi kullanım başlığı (üstteki '>' bloğu) çıktıya girmez: o bize yazılmış,
# tasarım platformuna değil. Ayraç: ilk '---' satırı.
GOVDE="$(awk 'basildi==1 {print} /^---$/ && basildi==0 {basildi=1}' "$SABLON")"
[ -n "$GOVDE" ] || { echo "HATA: şablonda '---' ayracından sonra gövde yok: $SABLON" >&2; exit 2; }

SABLON="$SABLON" GOVDE="$GOVDE" SOZLESME="$SOZLESME" ESTETIK="$ESTETIK" ONCEKI="$ONCEKI" python3 - <<'PY'
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
