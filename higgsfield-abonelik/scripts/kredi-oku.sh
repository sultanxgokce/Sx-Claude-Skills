#!/usr/bin/env bash
# kredi-oku.sh — krediyi GOSTERGEDEN degil DEFTERDEN oku; celisirse SOYLE.
#
# 🔴 DEFTERI KENDISI OKUMAZ: `hf-defter.sh` tek kaynaktir (K02). Sebep aci:
# bu arac defteri kendi okurken UC kez yuttu —
#   (1) "Seedance 2.5" bosluklu model adi -> satir atlandi (7,50 dedi, gercek 40,00)
#   (2) defter UTC, betik yerel (+03) -> 3 saat korluk
#   (3) `account transactions` VARSAYILAN 20 SATIR -> kesik evren uzerinde hukum
# Ucu de AZ gosterdi. Ayristirma ve sayfalama tek yerde toplanip JSON'a gecirildi;
# ikinci bir kopya ayni hatalari yeniden ogrenmesin.
#
# 🔴 FAIL-CLOSED: kaynak okunamiyorsa TAHMIN ETMEZ, REDDEDER — okunamayan
# defterin yerine gostergeyi koymak, onlemeye calistigimiz arizanin ta kendisidir.
#
# Kullanim: kredi-oku.sh [--saat N]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAAT=24
while [ $# -gt 0 ]; do
  case "$1" in
    --saat) shift; SAAT="${1:-24}" ;;
    *) echo "kullanim: kredi-oku.sh [--saat N]" >&2; exit 2 ;;
  esac; shift
done
case "$SAAT" in ''|*[!0-9]*) echo "[kirmizi] --saat tamsayi olmali" >&2; exit 2 ;; esac

TSV="$(bash "$SCRIPT_DIR/hf-defter.sh" --saat "$SAAT" 2>/dev/null)" || {
  echo "[kirmizi] defter okunamadi — kredi hukmü YOK (tahmin etmiyorum)" >&2; exit 1; }

GOSTERGE="$(higgsfield account status 2>/dev/null || true)"
[ -n "$GOSTERGE" ] || { echo "[kirmizi] gosterge okunamadi" >&2; exit 1; }

# 🔴 BORU + HEREDOC CAKISIR — ve bunu BIR SAAT ONCE kredi-mutabakat.sh'te
# duzeltip yazdiktan sonra BURADA TEKRAR YAPTIM. `python3 - <<PYK` programi
# STDIN'den okur; ayni stdin'e veriyi borulayinca VERI YUTULUR ve arac
# "0 islem" der. Yine rahatlatici yon.
# Bu, kendi adlandirdigim tekrar eden desenim: BIR DERSI BIR YERDE UYGULAYIP
# KARDESINI ATLAMAK. Care: veri gecici DOSYAYA yazilir, yolu env ile verilir.
TSVDOSYA="$(mktemp)"; printf '%s\n' "$TSV" > "$TSVDOSYA"
trap 'rm -f "$TSVDOSYA"' EXIT
TELLAL_SAAT="$SAAT" TELLAL_GOSTERGE="$GOSTERGE" TELLAL_TSV="$TSVDOSYA" python3 - <<'PYK'
import sys, os, re
saat = os.environ["TELLAL_SAAT"]; gos = os.environ["TELLAL_GOSTERGE"]
h = 0.0; n = 0
for l in open(os.environ["TELLAL_TSV"], encoding="utf-8"):
    p = l.rstrip("\n").split("\t")
    if len(p) < 4 or p[2] != "spend": continue
    try: c = float(p[1])
    except ValueError: continue
    if c < 0: h += -c; n += 1
m = re.search(r"([\d.]+)\s*credits", gos)
bak = float(m.group(1)) if m else None
print("  defter  : son %s saatte %d islem · %.2f kredi harcandi" % (saat, n, h))
print("  gosterge: " + (("%.2f" % bak) if bak is not None else "okunamadi") + " kredi")
if bak is not None and h > 0 and bak in (3000.0, 2000.0, 1000.0):
    print("  🔴 CELISKI: %.2f kredi harcanmis ama gosterge tam plan degeri (%.0f) — BAYAT olabilir." % (h, bak))
else:
    print("  ✓ celiski isareti yok (kritik kararda defter esastir)")
PYK
