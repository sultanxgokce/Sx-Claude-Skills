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

echo "════ T10 · EKRAN: kitaplık yolu ortamdan · eksik kitaplığın ADI yüzeye çıkar (MEDDAH) ════"
# Sahte tarayıcı ortamı: playwright dizini VAR gibi görünsün, `node` yerine güdük betik koşsun.
# 🔴 Niçin güdük: gerçek tarayıcıyı kitaplıksız bırakmak için kutuyu bozmak gerekirdi. Ölçülen
#    şey aracın ÇOCUK SÜRECE verdiği ortam ve çocuğun hatasını nasıl RAPORLADIĞI — ikisi de
#    güdükle sadakatle ölçülür. (Gerçek tarayıcı yolu T8'de ayrıca koşuyor.)
PWD_DIR="$T/pw"; mkdir -p "$PWD_DIR/playwright"
mkdir -p "$T/bin"
EKR="$T/_agents/fabrika/kanit/is-ekran"
_node_kur() { printf '%s\n' '#!/usr/bin/env bash' "$1" > "$T/bin/node"; chmod +x "$T/bin/node"; }
_ekran() { PATH="$T/bin:$PATH" KANIT_PLAYWRIGHT_DIR="$PWD_DIR" bash "$K" ekran "$@" 2>&1; }
_alan() { python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));k=m["kayitlar"][-1];v=k.get(sys.argv[2]);print(json.dumps(v,ensure_ascii=False))' "$EKR/KANIT.json" "$1"; }

# E1 · eksik kitaplık satırı GÜRÜLTÜNÜN ARKASINDA: önce 400+ karakter başka hata, sonra asıl sebep
_node_kur 'printf "Target page, context or browser has been closed\n" >&2; printf "%.0sX" $(seq 1 420) >&2; printf "\nError: libnspr4.so: cannot open shared object file: No such file or directory\n" >&2; exit 1'
O="$(_ekran is-ekran kitapliksiz --url https://ornek.test --asama tek)"; RC=$?
[ "$RC" -eq 3 ]; g $? "E1a kare alınamadı → rc=3 (SARI, yeşil değil)"
grep -q "EKSİK KİTAPLIK: libnspr4.so" <<<"$O"; g $? "E1b eksik kitaplığın ADI yüzeyde (300 karakter kırpmasının arkasında kalmıyor)"
grep -q "kitaplık görünmüyor" <<<"$O"; g $? "E1c sebep doğru söylenir: ayağa kalkmama DEĞİL, görünmeme"
[ "$(_alan renk)" = '"sari"' ]; g $? "E1d manifestte renk=sari"
[ "$(_alan eksik_kitaplik)" = '["libnspr4.so"]' ]; g $? "E1e manifestte eksik_kitaplik adıyla"
HG="$EKR/ekran-kitapliksiz-tek.hata.txt"
[ -f "$HG" ] && grep -q "libnspr4.so" "$HG" && grep -q "LD_LIBRARY_PATH=" "$HG"; g $? "E1f tam çıktı KIRPILMADAN diske yazıldı (kullanılan yol bilgisiyle)"

# E2 · KANIT_PW_LIBS çocuğa geçer VE odanın mevcut ayarı EZİLMEZ
_node_kur 'printf "LDP=[%s]\n" "${LD_LIBRARY_PATH:-}" >&2; exit 1'
LD_LIBRARY_PATH=/onceki/yol KANIT_PW_LIBS=/oda/kitaplik _ekran is-ekran yol --url https://ornek.test --asama tek >/dev/null
HG2="$EKR/ekran-yol-tek.hata.txt"
grep -q 'LDP=\[/oda/kitaplik:/onceki/yol\]' "$HG2"; g $? "E2a KANIT_PW_LIBS ÖNE eklenir, odanın kendi ayarı KORUNUR"
[ "$(_alan ld_library_path)" = '"/oda/kitaplik:/onceki/yol"' ]; g $? "E2b kullanılan yol manifeste yazılır (teşhis edilebilir sarı)"

# E3 · kitaplıkla İLGİSİZ hata: eski davranış korunur → E1 tautoloji değil
_node_kur 'echo "zaman asimi" >&2; exit 1'
O="$(_ekran is-ekran ilgisiz --url https://ornek.test --asama tek)"
if grep -q "EKSİK KİTAPLIK" <<<"$O"; then g 1 "E3a ilgisiz hatada kitaplık iddiası YOK"; else g 0 "E3a ilgisiz hatada kitaplık iddiası YOK"; fi
[ "$(_alan eksik_kitaplik)" = '[]' ]; g $? "E3b manifestte eksik_kitaplik BOŞ (uydurma yok)"

# E4 · MUTASYON: KANIT_PW_LIBS kablosu koparılınca E2 kırmızıya döner
M="$T/kanit-mutant.py"
python3 -c 'import sys;s=open(sys.argv[1],encoding="utf-8").read();s=s.replace("    libs = kitaplik_yolu()","    libs = \"\"",1);open(sys.argv[2],"w",encoding="utf-8").write(s)' "$HERE/kanit.py" "$M"
_node_kur 'printf "LDP=[%s]\n" "${LD_LIBRARY_PATH:-}" >&2; exit 1'
PATH="$T/bin:$PATH" KANIT_PLAYWRIGHT_DIR="$PWD_DIR" LD_LIBRARY_PATH=/onceki/yol KANIT_PW_LIBS=/oda/kitaplik \
  KANIT_DEPO="$T" python3 "$M" ekran is-ekran mutasyon --url https://ornek.test --asama tek >/dev/null 2>&1
grep -q 'LDP=\[/onceki/yol\]' "$EKR/ekran-mutasyon-tek.hata.txt"; g $? "E4 MUTASYON: kablo koparılınca oda ayarı çocuğa GİTMEZ (kablo süs değil)"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
