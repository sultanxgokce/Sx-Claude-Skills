#!/usr/bin/env bash
# kanit.test.sh — kanıt aracını sahte depoda koşturur: manifesti araç yazar, elle yazım yakalanır, sarı yeşil sayılmaz.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$HERE/kanit.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
export KANIT_DEPO="$T"
DZ="$T/_agents/fabrika/kanit/is-1"

echo "════ T1 · ölçüm çifti: komutu araç koşar, kırpılmamış çıktı+rc ════"
bash "$K" olcum is-1 satir --asama once -- bash -c 'echo 12; exit 0' >/dev/null 2>&1; g $? "önce ölçümü rc=0"
bash "$K" olcum is-1 satir --asama sonra -- bash -c 'echo 7; echo uyari >&2; exit 0' >/dev/null 2>&1; g $? "sonra ölçümü rc=0"
[ -f "$DZ/KANIT.json" ]; g $? "KANIT.json araç tarafından yazıldı"
grep -q "^12" "$DZ/olcum-satir-once.txt" && grep -q "uyari" "$DZ/olcum-satir-sonra.txt"; g $? "stdout ve stderr kırpılmadan saklandı"
python3 -c "import json;m=json.load(open('$DZ/KANIT.json'));assert len(m['kayitlar'])==2 and m['kayitlar'][1]['renk']=='yesil' and m['imza']"; g $? "iki kayıt, yeşil, imzalı"

echo "════ T2 · rc=3 komut → SARI, aracın rc'si 3 (yeşil değil) ════"
bash "$K" olcum is-1 kor --asama tek -- bash -c 'echo olcemedim; exit 3' >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ]; g $? "araç rc=3 döndü"
python3 -c "import json;m=json.load(open('$DZ/KANIT.json'));assert m['kayitlar'][-1]['renk']=='sari'"; g $? "manifestte renk=sari"

echo "════ T3 · kırmızı komut → kirmizi, araç rc=0 (kayıt başarılı) ════"
bash "$K" olcum is-1 kirik --asama tek -- bash -c 'exit 1' >/dev/null 2>&1; g $? "kayıt alındı"
python3 -c "import json;m=json.load(open('$DZ/KANIT.json'));assert m['kayitlar'][-1]['renk']=='kirmizi' and m['kayitlar'][-1]['rc']==1"; g $? "renk=kirmizi rc=1"

echo "════ T4 · dosya ekleme + dogrula sağlam ════"
echo "video-yerine" > "$T/kayit.webm"
bash "$K" dosya is-1 akis "$T/kayit.webm" >/dev/null 2>&1; g $? "dosya eklendi"
CIKTI="$(bash "$K" dogrula is-1 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "dogrula rc=0"
grep -q "1 SARI" <<<"$CIKTI"; g $? "sarı kayıt sayısı özetle söyleniyor"

echo "════ T5 · elle yazım yakalanır ════"
python3 - <<PY
import json;p='$DZ/KANIT.json';m=json.load(open(p));m['kayitlar'][2]['renk']='yesil';json.dump(m,open(p,'w'))
PY
bash "$K" dogrula is-1 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "renk elle yeşile boyanınca imza tutmuyor → rc=1"
bash "$K" olcum is-1 ek --asama tek -- true >/dev/null 2>&1; [ $? -eq 1 ]; g $? "bozuk manifeste yeni kayıt EKLENMİYOR"
python3 - <<PY
import json;p='$DZ/KANIT.json';m=json.load(open(p));m['kayitlar'][2]['renk']='sari';json.dump(m,open(p,'w'))
PY
bash "$K" dogrula is-1 >/dev/null 2>&1; [ $? -eq 0 ]; g $? "içerik aslına dönünce imza yine tutar (imza İÇERİĞE aittir, dosya baytlarına değil)"

echo "════ T6 · dosya sha bozulursa yakalanır ════"
rm -f "$DZ/KANIT.json"
bash "$K" olcum is-2 a --asama tek -- echo x >/dev/null 2>&1
echo "değişti" >> "$T/_agents/fabrika/kanit/is-2/olcum-a-tek.txt"
bash "$K" dogrula is-2 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kanıt dosyası sonradan değişince rc=1"

echo "════ T7 · kanıt yok → rc=3 ════"
bash "$K" dogrula yok-is >/dev/null 2>&1; [ $? -eq 3 ]; g $? "manifest yokken rc=3 (ölçülemedi)"

echo "════ T8 · ekran: playwright YOKSA sarı+rc=3; VARSA yerel sayfadan kare + ürün imi ════"
CIKTI="$(KANIT_PLAYWRIGHT_DIR=/nonexistent PATH=/usr/bin:/bin bash "$K" ekran is-3 ana --url file:///dev/null 2>&1)"; RC=$?
if command -v node >/dev/null 2>&1 && [ -d /config/projects/Nexus/ui/node_modules/playwright ]; then
  # node PATH'te var ama KANIT_PLAYWRIGHT_DIR bozuk; aday dizinler yine bulur → gerçek playwright koşar. Ayrı test:
  printf '<html><title>Urun</title><body><div id="hesap-iste">x</div></body></html>' > "$T/sayfa.html"
  bash "$K" ekran is-3 gercek --url "file://$T/sayfa.html" --urun-imi '#hesap-iste' >/dev/null 2>&1; RC2=$?
  [ "$RC2" -eq 0 ] && [ -s "$T/_agents/fabrika/kanit/is-3/ekran-gercek-sonra.png" ]; g $? "gerçek kare alındı (playwright var)"
  bash "$K" ekran is-3 imsiz --url "file://$T/sayfa.html" --urun-imi '#yok-boyle' >/dev/null 2>&1; RC3=$?
  [ "$RC3" -eq 2 ]; g $? "ürün imi yoksa rc=2 (ölçer ürünü görmedi — 6. kanun)"
  python3 -c "import json;m=json.load(open('$T/_agents/fabrika/kanit/is-3/KANIT.json'));assert m['kayitlar'][-1]['renk']=='kirmizi'"; g $? "imsiz kare manifestte kırmızı"
else
  [ "$RC" -eq 3 ]; g $? "playwright yokken rc=3"
  grep -q "SARI" <<<"$CIKTI"; g $? "sarı olduğunu söylüyor"
fi

echo "════ T9 · ozet tablo ════"
CIKTI="$(bash "$K" ozet is-2 2>&1)"; grep -q "^| 1 | olcum | a" <<<"$CIKTI"; g $? "markdown tablo üretildi"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
