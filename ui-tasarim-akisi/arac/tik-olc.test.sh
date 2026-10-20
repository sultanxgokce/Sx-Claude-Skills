#!/usr/bin/env bash
# tik-olc.test.sh — tarayıcıda yol yürüyen tık ölçeri (BERİD W42 Ö5) gerçek bir sayfada sınar + mutasyon.
# Tarayıcı VARSA (yerel kutu) yollar gerçekten yürünür; YOKSA (CI) araç ÖLÇÜLEMEDİ (rc 3) demeli ve sayı YAZMAMALI —
# iki dal da iddia edilir, hiçbiri sessizce atlanmaz.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A="${MUTANT_ARAC:-$HERE}"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
mkdir -p "$T/s"
cat > "$T/s/E1.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;font:16px sans-serif} .kap .gizli{display:none} .kap:hover .gizli{display:inline-block}
#menu{display:none} #asagi{margin-top:2000px} #ortu{position:fixed;inset:0;background:transparent;z-index:9;pointer-events:auto}
#ortulu-kap{position:relative;height:40px}
</style></head><body>
<button id="gorunur">Ara</button>
<button id="menu-dugme" onclick="document.getElementById('menu').style.display='block'">Menü</button>
<div id="menu"><button id="menu-oge">Ayarlar</button></div>
<span class="kap">üzerine gel <button class="gizli" id="gizli">Gizli</button></span>
<div id="ortulu-kap"><button id="ortulu">Örtülü</button><div id="ortu" style="position:absolute"></div></div>
<button id="asagi">Aşağıda</button>
</body></html>
HTML
cat > "$T/yol.json" <<'JSON'
{"G1": {"hedef": 1, "adimlar": ["#gorunur"]},
 "G2": {"hedef": 1, "adimlar": ["#asagi"]},
 "G3": {"hedef": 2, "adimlar": ["#menu-dugme", "#menu-oge"]},
 "G4": {"hedef": 1, "adimlar": ["#menu-oge"]},
 "G5": {"hedef": 2, "adimlar": ["#gizli"]},
 "G6": {"hedef": 3, "adimlar": ["#yok"]},
 "G7": {"hedef": 1, "adimlar": ["#ortulu"]},
 "G8": {"hedef": 12, "adimlar": ["#yok-uzun"]}}
JSON
J="$T/s/olcum/E1.html.tik.json"
oku() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))' "$J" "$1" 2>/dev/null; }

echo "── T1 · tarayıcı YOKSA: ÖLÇÜLEMEDİ, sayı yazılmaz (elle sayı ölçüm değildir) ──"
KANIT_PLAYWRIGHT_DIR="$T/yok" bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/yol.json" >"$T/o1" 2>&1; rc=$?
[ "$rc" -eq 3 ] && grep -q "ÖLÇÜLEMEDİ" "$T/o1" && [ ! -e "$J" ]; g $? "playwright yok → rc 3 · ÖLÇÜLEMEDİ · artefakt YOK (rc=$rc)"

echo "── T2 · bozuk girdi ──"
printf '{"G1": {"hedef": "iki", "adimlar": []}}' > "$T/bozuk.json"
printf '{"G1": {"hedef": 100, "adimlar": ["#gorunur"]}}' > "$T/bozuk2.json"
bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/bozuk2.json" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "hedef 99'u aşarsa rc 2 (kaydedicinin biçimine sığmaz)"
bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/bozuk.json" >/dev/null 2>&1; [ $? -eq 2 ] && [ ! -e "$J" ]; g $? "bozuk yol tanımı → rc 2, artefakt yok"
bash "$A/tik-kaydet.sh" "$T/s/E1.html" G1=1:1 --yontem goz >/dev/null 2>&1; [ $? -eq 2 ]; g $? "tik-kaydet bilinmeyen yöntem → rc 2"
bash "$A/tik-kaydet.sh" "$T/s/E1.html" G1=1:1 >/dev/null 2>&1; [ "$(oku 'd["yontem"]')" = elle ]; g $? "elle kayıt (eski çağrı) yontem=elle yazar — geriye uyumlu"
rm -f "$J"

PW="${KANIT_PLAYWRIGHT_DIR:-/config/projects/Nexus/ui/node_modules}"
if ! NODE_PATH="$PW" node -e "require('playwright').chromium.launch().then(b=>b.close()).catch(()=>process.exit(3))" >/dev/null 2>&1; then
  echo "  · tarayıcı bu ortamda yok — T3-T5 (gerçek yol yürüme) ve mutasyon bu koşumda ÖLÇÜLEMEDİ; T1 'yok' dalını iddia etti"
  echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı (tarayıcı dalı ölçülmedi) ──"; [ "$kalan" -eq 0 ]; exit $?
fi

echo "── T3 · tarayıcıda yol YÜRÜNÜR: her durum doğru sayılır ──"
bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/yol.json" --genislik 800 --yukseklik 600 >"$T/o3" 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ -s "$J" ]; g $? "ölçüldü ve kaydedildi (rc=$rc)"
[ "$(oku 'd["gorevler"]["G1"]["olculen"]')" = 1 ]; g $? "G1 görünür düğme → 1"
[ "$(oku 'd["gorevler"]["G2"]["olculen"]')" = 2 ]; g $? "G2 ekran dışı düğme → 2 (kaydırma)"
[ "$(oku 'd["gorevler"]["G3"]["olculen"]')" = 2 ]; g $? "G3 menü aç + öğe → 2 (adımlar gerçekten tıklandı: menü açıldı)"
[ "$(oku 'd["gorevler"]["G4"]["olculen"]')" = 9 ]; g $? "G4 menü açılmadan öğe → 9 (her görev TEMİZ sayfayla başlar; G3'ün açtığı menü sayılmaz)"
[ "$(oku 'd["gorevler"]["G5"]["olculen"]')" = 2 ]; g $? "G5 üzerine gelince görünen → 2"
[ "$(oku 'd["gorevler"]["G6"]["olculen"]')" = 9 ] && grep -q "G6 adım 1 (#yok): öğe YOK" "$T/o3"; g $? "G6 olmayan öğe → 9 + sebep"
[ "$(oku 'd["gorevler"]["G7"]["olculen"]')" = 9 ] && grep -q "G7 adım 1 (#ortulu): tıklanamıyor" "$T/o3"; g $? "G7 üstü örtülü öğe → 9 + sebep (tıklanamayan yol yürünemez)"

echo "── T4 · artefakt yöntemi ve yolu taşır, kapı aşımı görür ──"
[ "$(oku 'd["yontem"]')" = tarayici ]; g $? "yontem=tarayici"
[ "$(oku 'd["yol_sha256"]')" = "$(sha256sum "$T/yol.json" | cut -d' ' -f1)" ]; g $? "yol tanımının sha'sı artefaktta (yol değişirse ölçüm bayat)"
[ "$(oku 'd["gorevler"]["G8"]["olculen"]')" = 13 ]; g $? "G8 hedef 12 + yürünemeyen yol → 13 (sabit 9 değil: göz #394 tur 1)"
[ "$(oku '",".join(d["asim"])')" = "G2,G4,G6,G7,G8" ]; g $? "bütçeyi aşanlar kapıya gider: G2,G4,G6,G7,G8 (yürünemeyen yol hedef ne olursa olsun aşar)"

echo "── T5 · ölçüm ayırt ediyor: sayfa düzelince sayı düşer ──"
sed -i 's/#asagi{margin-top:2000px}/#asagi{margin-top:0}/' "$T/s/E1.html"
bash "$A/tik-olc.sh" "$T/s/E1.html" "$T/yol.json" --genislik 800 --yukseklik 600 >/dev/null 2>&1
[ "$(oku 'd["gorevler"]["G2"]["olculen"]')" = 1 ]; g $? "düğme ekrana alınınca G2 → 1 (sayı sayfadan geliyor, sabit değil)"
sed -i 's/#asagi{margin-top:0}/#asagi{margin-top:2000px}/' "$T/s/E1.html"

if [ -n "${IC_KOSUM:-}" ]; then [ "$kalan" -eq 0 ]; exit $?; fi
echo "── T6 · MUTASYON (tam kopya; kontrol önce) ──"
IC_KOSUM=1 bash "$0" >/dev/null 2>&1; g $? "kontrol: bozulmamış araçla iç koşum yeşil"
mut() {   # mut <ad> <dosya> <eski> <yeni>
  local D="$T/m-$1"; mkdir -p "$D"; cp "$HERE"/tik-olc.sh "$HERE"/tik-olc.mjs "$HERE"/tik-kaydet.sh "$D/"
  python3 - "$D/$2" "$3" "$4" <<'PYM' || { g 1 "mutant '$1' kurulamadı (çapa bayat)"; return; }
import sys; f, a, b = sys.argv[1:]; s = open(f, encoding="utf-8").read(); assert s.count(a) == 1; open(f, "w", encoding="utf-8").write(s.replace(a, b, 1))
PYM
  if IC_KOSUM=1 MUTANT_ARAC="$D" bash "$0" >/dev/null 2>&1; then g 1 "mutant '$1' sağ kaldı"; else g 0 "mutant '$1' sınavı KIRMIZI yapıyor"; fi
}
mut ekran-disi-sayilmaz tik-olc.mjs 'kutu.x + kutu.width > W)) ek += 1;' 'kutu.x + kutu.width > W)) ek += 0;'
mut gizli-sayilmaz tik-olc.mjs '      ek += 1; await oge.locator' '      ek += 0; await oge.locator'
mut yok-sifir tik-olc.mjs 'öğe YOK — yol yürünemedi, ölçülen ${YURUNEMEDI}`); tik = YURUNEMEDI;' 'öğe YOK — yol yürünemedi, ölçülen ${YURUNEMEDI}`); tik = 0;'
mut yurunemedi-sabit-9 tik-olc.mjs 'const YURUNEMEDI = Math.max(9, yol[g].hedef + 1);' 'const YURUNEMEDI = 9;'
mut temiz-sayfa-yok tik-olc.mjs "  await sayfa.goto(url, { waitUntil: 'load' });" "  if (!sonuc.length) await sayfa.goto(url, { waitUntil: 'load' });"
mut yontem-yazilmaz tik-olc.sh '--yontem tarayici --yol "$YOL"' '--yol "$YOL"'
mut elle-sayi-yazar tik-olc.sh 'exit "$rc"; }' 'bash "$HERE/tik-kaydet.sh" "$SAYFA" G1=1:1 --yontem tarayici; exit "$rc"; }'
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
