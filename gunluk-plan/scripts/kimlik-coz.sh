#!/usr/bin/env bash
# kimlik-coz.sh — koltuk adını DEFTERDEKİ ada çevirir (tablodan). Ortam değişkenine kalıcı ad yazmak çok kimlikli kutuda
# herkesi tek kişi adına yazdırır; eşleme KOLTUK başınadır.
#   kimlik-coz.sh <koltuk-adı>        → stdout: defter adı (tabloda yoksa verilen ad AYNEN) · rc 0
# Tablo: GUNLUK_PLAN_ESLEME (varsayılan: <beceri>/koltuk-esleme.tsv). Satır: <koltuk><TAB><defter adı>; # yorum. Karşılaştırma İ/I/ı/i ve şapka katlı.
# Bozuk satır (sekmesiz / boş alan) ATLANIR ve stderr'e söylenir; aynı koltuk iki farklı ada gidiyorsa rc 3 (tahmin yok).
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
TABLO="${GUNLUK_PLAN_ESLEME:-$KOK/../koltuk-esleme.tsv}"
AD="${1:-}"; [ -n "$AD" ] || { echo "kullanım: kimlik-coz.sh <koltuk-adı>" >&2; exit 2; }
[ -r "$TABLO" ] || { printf '%s\n' "$AD"; exit 0; }
python3 - "$TABLO" "$AD" <<'PY'
import sys,unicodedata
def n(t): return unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","i").replace("ı","i").lower().replace("â","a").replace("î","i").replace("û","u")
tablo,ad=sys.argv[1],sys.argv[2]; bul=set()
for i,s in enumerate(open(tablo,encoding="utf-8"),1):
    s=s.rstrip("\n")
    if not s.strip() or s.lstrip().startswith("#"): continue
    p=s.split("\t")
    if len(p)!=2 or not p[0].strip() or not p[1].strip():
        print(f"UYARI: koltuk-esleme satır {i} bozuk, atlandı",file=sys.stderr); continue
    if n(p[0].strip())==n(ad): bul.add(p[1].strip())
if len(bul)>1: print(f"ÖLÇÜLEMEDİ: '{ad}' koltuğu tabloda birden çok defter adına gidiyor: {sorted(bul)}",file=sys.stderr); sys.exit(3)
print(next(iter(bul)) if bul else ad)
PY
