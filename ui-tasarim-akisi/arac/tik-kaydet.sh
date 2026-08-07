#!/usr/bin/env bash
# tik-kaydet.sh — elle yapılan tık sayımını makine-okur ölçüm artefaktına çevirir.
#
# NİÇİN VAR
#   Durak 2 "tık bütçesi ZORUNLU" diyordu ama aşağı akışta hiçbir kapı onu istemiyordu:
#   `prompt-yap.sh` içinde geçen "tık" kelimelerinin hepsi "esTİKk"in içiydi, gerçek
#   referans SIFIRDI. Yani sistemin başkasında yakaladığı "ölçmediğine temiz der" hatası
#   tam da çekirdeğinde duruyordu (bulan: MÜTEVELLİ/AKAR, 2026-08-07).
#   Kapıyı verip kayıt aracını vermemek "kural var, araç yok" hatası olurdu — bu o araç.
#
# KULLANIM
#   tik-kaydet.sh <sayfa.html> G1=<hedef>:<olculen> [G2=<hedef>:<olculen> ...]
#     ör:  tik-kaydet.sh tasarim/ciktilar/E1.html G1=3:2 G2=1:1 G5=4:6
#   Artefakt: <sayfa-dizini>/olcum/<sayfa>.tik.json  (--dizin ile değiştirilebilir)
#
# TAZELİK
#   Artefakt sayfanın sha256'sını taşır. Sayfa değişince ölçüm BAYAT sayılır ve kapı
#   yine "ölçülmedi" der — asıl saldırı yüzeyi eksik artefakt değil, bayat artefakttır.
#
# ÇIKIŞ: 0 yazıldı · 2 geçersiz girdi
set -euo pipefail

SAYFA="${1:-}"
[ -n "$SAYFA" ] && [ -f "$SAYFA" ] || {
  echo "kullanım: tik-kaydet.sh <sayfa.html> G1=<hedef>:<olculen> [...]" >&2
  echo "  ör: tik-kaydet.sh tasarim/ciktilar/E1.html G1=3:2 G2=1:1" >&2
  exit 2; }
shift

DIZIN=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dizin) DIZIN="${2:-}"; shift 2 ;;
    *)       ARGS+=("$1");   shift ;;
  esac
done
[ "${#ARGS[@]}" -gt 0 ] || { echo "HATA: en az bir G<id>=<hedef>:<olculen> ver" >&2; exit 2; }

DIZIN="${DIZIN:-$(dirname "$SAYFA")/olcum}"
mkdir -p "$DIZIN"
OLCUM="$DIZIN/$(basename "$SAYFA").tik.json"

SAYFA="$SAYFA" OLCUM="$OLCUM" python3 - "${ARGS[@]}" <<'PY'
import hashlib, json, os, re, sys, time

sayfa = os.environ["SAYFA"]
gorevler, asim = {}, []
for arg in sys.argv[1:]:
    m = re.match(r"^([A-Za-zÇĞİÖŞÜçğıöşü0-9_-]{1,20})=(\d{1,3}):(\d{1,3})$", arg)
    if not m:
        sys.stderr.write("HATA: biçim <gorev>=<hedef>:<olculen> değil: %s\n" % arg)
        sys.exit(2)
    ad, hedef, olculen = m.group(1), int(m.group(2)), int(m.group(3))
    gorevler[ad] = {"hedef": hedef, "olculen": olculen}
    if olculen > hedef:
        asim.append(ad)

kayit = {
    "sayfa": os.path.basename(sayfa),
    "sayfa_sha256": hashlib.sha256(open(sayfa, "rb").read()).hexdigest(),
    "gorevler": gorevler,
    "asim": sorted(asim),          # bütçeyi aşan görevler — kapı bunu KIRMIZI sayar
    "zaman_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
with open(os.environ["OLCUM"], "w", encoding="utf-8") as f:
    json.dump(kayit, f, ensure_ascii=False, indent=1, sort_keys=True)

print("tık ölçümü yazıldı: %s" % os.environ["OLCUM"])
if asim:
    print("⚠ bütçe aşımı: %s — kapı bunu KIRMIZI sayar (ya tasarımı ya hedefi düzelt)"
          % ", ".join(sorted(asim)))
PY
