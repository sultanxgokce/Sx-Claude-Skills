#!/usr/bin/env bash
# yol-olcer.sh <git ref> — verilen ref'teki ui-tasarim-akisi ile tık bütçesi NASIL ölçülüyor? Aynı fikstür sayfası, aynı yol.
# Tarayıcı ölçeri (arac/tik-olc.sh) yoksa tek yol elle sayı vermektir; artefaktın ölçüm yöntemini söyleyip söylemediği basılır.
# Fikstürde BİLEREK bırakılan düzen: menü display:none olduğu için üç düğme aynı satıra düşer ve #asagi'nin 2000px üst boşluğu
#   SATIRIN TAMAMINI ekran altına iter (ölçüldü: üçünün de y=2008). Elle "G1=1" diyen bunu görmez; yürüyücü görür (D4).
set -uo pipefail
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
git archive "$1" ui-tasarim-akisi/arac | tar -x -C "$T" || exit 3
A="$T/ui-tasarim-akisi/arac"; mkdir -p "$T/s"
printf '<!doctype html><meta charset="utf-8"><style>#asagi{margin-top:2000px}#menu{display:none}</style>
<button id="ara">Ara</button><button id="m" onclick="document.getElementById(%s).style.display=%s">Menü</button>
<div id="menu"><button id="ayar">Ayarlar</button></div><button id="asagi">Aşağıda</button>\n' "'menu'" "'block'" > "$T/s/E1.html"
printf '{"G1":{"hedef":1,"adimlar":["#ara"]},"G2":{"hedef":1,"adimlar":["#asagi"]},"G3":{"hedef":2,"adimlar":["#m","#ayar"]}}\n' > "$T/yol.json"
echo "ref $1 ($(git rev-parse --short "$1"))"
if [ -f "$A/tik-olc.sh" ]; then
  bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/yol.json" --genislik 800 --yukseklik 600 2>&1 | sed "s|$T|<geçici>|g"; echo "rc=${PIPESTATUS[0]}"
else
  echo "tarayıcı ölçeri YOK (arac/tik-olc.sh) — tık sayısı ancak ELLE verilir:"
  bash "$A/tik-kaydet.sh" "$T/s/E1.html" G1=1:1 G2=1:1 G3=2:2 2>&1 | sed "s|$T|<geçici>|g"
  echo "  (elle verilen sayılar sayfaya BAKILMADAN kabul edildi — kimse yürümedi)"
fi
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("artefakt: gorevler", {k:v["olculen"] for k,v in d["gorevler"].items()}, "· asim", d["asim"], "· yontem", d.get("yontem","(alan yok)"))' "$T/s/olcum/E1.html.tik.json"
