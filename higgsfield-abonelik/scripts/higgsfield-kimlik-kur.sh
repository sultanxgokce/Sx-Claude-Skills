#!/usr/bin/env bash
# higgsfield-kimlik-kur.sh — kasadaki OAuth jetonunu CLI'nin bekledigi dosyaya kurar.
#
# ── 🔴 NEDEN AYRI BIR ARAC GEREKTI (2026-08-28, birebir yasandi) ─────────────
# `vault-cek get HIGGSFIELD_CLI_KIMLIK` jetonu cortex-access.env dosyasina
# `export HIGGSFIELD_CLI_KIMLIK='{ ... }'` diye yaziyor — AMA jeton COK SATIRLI
# bir JSON. Kayit dosyada SEKIZ satira yayiliyor.
# Bizim sir cozumleyicimiz (anahtar.lib.sh) satir-tabanli `grep -m1` kullaniyor
# ve YALNIZ ILK SATIRI aldi: deger "{" oldu, yani BIR KARAKTER. Arac "anahtar
# var" diyordu, elimizdeki sey bir sus parantezdi.
# Ders: bir tasiyicinin BICIMI tasidigi seyi sessizce kesebilir. "Anahtar var mi"
# sorusu YETMEZ; "tasidigi sey BUTUN MU" diye de sorulmali. Bu arac butunlugu
# PARMAK IZIYLE dogrular ve tutmuyorsa YAZMAZ (fail-closed).
#
# Kullanim: higgsfield-kimlik-kur.sh [--beklenen-uzunluk N] [--beklenen-sha12 XXXX]
set -uo pipefail
ENVDOSYA="${TELLAL_SIR_ENV:-/config/.config/cortex-access.env}"
BEKLENEN_UZUNLUK=""; BEKLENEN_SHA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --beklenen-uzunluk) BEKLENEN_UZUNLUK="${2:-}"; shift 2 ;;
    --beklenen-sha12)   BEKLENEN_SHA="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done

TELLAL_ENVDOSYA="$ENVDOSYA" TELLAL_BU="$BEKLENEN_UZUNLUK" TELLAL_BS="$BEKLENEN_SHA" \
python3 <<'PYK'
import hashlib, json, os, sys
env = os.environ["TELLAL_ENVDOSYA"]
if not os.path.exists(env):
    print("[kirmizi] sir dosyasi yok: %s" % env, file=sys.stderr); sys.exit(1)
sat = open(env, encoding="utf-8").read().split("\n")
bas = None
for i, l in enumerate(sat):
    if "HIGGSFIELD_CLI_KIMLIK=" in l:
        bas = i; break
if bas is None:
    print("[kirmizi] HIGGSFIELD_CLI_KIMLIK kaydi YOK — once vault-cek get calistir", file=sys.stderr)
    sys.exit(1)

# Cok satirli tek-tirnakli degeri topla: kapanis tirnagi gorulene kadar.
parcalar = [sat[bas].split("=", 1)[1]]
i = bas + 1
while i < len(sat) and not parcalar[-1].rstrip().endswith("}'"):
    parcalar.append(sat[i]); i += 1
metin = "\n".join(parcalar).strip()
if metin.startswith("'") and metin.endswith("'"):
    metin = metin[1:-1]

# 🔴 FAIL-CLOSED: gecerli JSON degilse YAZMA. Bozuk bir kimlik dosyasi, olmayan
# bir kimlik dosyasindan kotudur — ikincisi "kurulu degil" der, birincisi
# "kurulu ama neden calismiyor" diye saatler yaktirir.
try:
    z = json.loads(metin)
except Exception as e:
    print("[kirmizi] jeton gecerli JSON DEGIL (%s) — dosya YAZILMADI" % e, file=sys.stderr)
    sys.exit(1)
for alan in ("access_token", "refresh_token"):
    if alan not in z:
        print("[kirmizi] jetonda '%s' alani yok — dosya YAZILMADI" % alan, file=sys.stderr)
        sys.exit(1)

uz = len(metin); sha12 = hashlib.sha256(metin.encode()).hexdigest()[:12]
bu, bs = os.environ.get("TELLAL_BU", ""), os.environ.get("TELLAL_BS", "")
if bu and str(uz) != bu:
    print("[kirmizi] uzunluk tutmadi: %d != beklenen %s — dosya YAZILMADI" % (uz, bu), file=sys.stderr)
    sys.exit(1)
if bs and sha12 != bs:
    print("[kirmizi] parmak izi tutmadi: %s != beklenen %s — dosya YAZILMADI" % (sha12, bs), file=sys.stderr)
    sys.exit(1)

yol = os.path.expanduser("~/.config/higgsfield/credentials.json")
os.makedirs(os.path.dirname(yol), exist_ok=True)
with open(yol, "w", encoding="utf-8") as f:
    f.write(metin)
os.chmod(yol, 0o600)
# 🔴 DEGER BASILMAZ — yalniz olculebilir kimlik bilgisi.
print("[yesil] higgsfield kimligi kuruldu: %s (600)" % yol)
print("  uzunluk = %d · sha256 ilk-12 = %s · alanlar = %s" % (uz, sha12, ",".join(sorted(z.keys()))))
PYK
