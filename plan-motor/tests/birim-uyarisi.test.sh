#!/usr/bin/env bash
# birim-uyarisi.test.sh — BİRİM BEYANI uyarısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN VAR: gerçek bir market DWG'si "$INSUNITS = inç" beyan ediyordu, geometrisi cm idi
# (2026-09-16 ölçümü). Yanlış birim ölçü kapısını 2,54× saptırır ve hata SESSİZ kalır.
# Bu bir KAPI değil UYARIDIR (K01: ölçülmemiş eşik sert kural ilan edilemez) — ama okunur.
#
# DEĞİŞMEZ: fixture sentetik; müşteri dosyası kullanılmaz.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
. tests/bagimlilik.sh   # dxf-parser ister; CI paralel koşar → kurulumu kendisi (kilitle) yapar
bagimlilik_kur || { echo "✗ npm bağımlılıkları kurulamadı"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }
bek_metin() { local m="$1" ad="$2" d="$3"; grep -qF -- "$m" "$d" && ok || kir "$ad — '$m' yok"; }
bek_yok() { local m="$1" ad="$2" d="$3"; grep -qF -- "$m" "$d" && kir "$ad — '$m' BEKLENMEDİK yerde var" || ok; }

dxf() {  # $1 = INSUNITS kodu, $2 = çizgi uzunluğu
  printf '0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n%s\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nLINE\n8\n0\n10\n0.0\n20\n0.0\n11\n%s\n21\n0.0\n0\nENDSEC\n0\nEOF\n' "$1" "$2"
}
dxf 1 4000000.0 > "$T/inc-devasa.dxf"   # inç beyanı + 4 milyon birim = 101 km
dxf 5 1130.0    > "$T/cm-gercekci.dxf"  # cm beyanı + 11,3 m = gerçekçi
dxf 0 1130.0    > "$T/beyansiz.dxf"     # birim beyanı yok

node cli.mjs oku --dosya "$T/inc-devasa.dxf"  --metrik /dev/null > "$T/a.json" 2>/dev/null
node cli.mjs oku --dosya "$T/cm-gercekci.dxf" --metrik /dev/null > "$T/b.json" 2>/dev/null
node cli.mjs oku --dosya "$T/beyansiz.dxf"    --metrik /dev/null > "$T/c.json" 2>/dev/null

bek_metin "gerçekçi değil" "inç beyanı + devasa uzam UYARI üretir" "$T/a.json"
bek_metin "UYARIDIR, kapı değil" "uyarı kendini kapı sanmıyor" "$T/a.json"
bek_yok  "gerçekçi değil" "gerçekçi cm çiziminde uyarı YOK (yanlış-pozitif değil)" "$T/b.json"
bek_metin "birim beyanı YOK" "beyansız dosya uyarılır" "$T/c.json"
bek_metin '"uyarilar"' "rapor alanı her koşuda var" "$T/b.json"

printf 'birim-uyarisi: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
