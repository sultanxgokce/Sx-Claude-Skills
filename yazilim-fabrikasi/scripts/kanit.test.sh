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

echo "════ T11 · AYNI KANIT YENİDEN ÖLÇÜLÜNCE kayıt ÜSTÜNE yazılır (NÂZIR/MOTOR1) ════"
# VAKA: dosya üstüne yazılıyordu ama manifestte eski kayıt kalıyordu → eski sha tutmaz,
#   `dogrula` KALICI rc=1; silme komutu yok, tek çıkış kanıt dizinini komple silmek.
R="$T/_agents/fabrika/kanit/is-tekrar"
bash "$K" olcum is-tekrar et --asama once -- bash -c 'echo BIR' >/dev/null 2>&1; g $? "T11a ilk ölçüm alındı"
O="$(bash "$K" olcum is-tekrar et --asama once -- bash -c 'echo IKI' 2>&1 >/dev/null)"; g $? "T11b aynı etiket+aşama yeniden ölçüldü"
N="$(python3 -c "import json;print(len(json.load(open('$R/KANIT.json'))['kayitlar']))")"
[ "$N" = 1 ]; g $? "T11c manifestte TEK kayıt (bayat kayıt kalmadı; ölçülen=$N)"
bash "$K" dogrula is-tekrar >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T11d dogrula rc=0 (eskiden KALICI rc=1 idi)"
grep -q "BIR" "$R/olcum-et-once.txt"; [ $? -ne 0 ]; g $? "T11e kanıt dosyası gerçekten yenisi (eski çıktı yok)"
grep -q "aynı kanıt yeniden ölçüldü" <<<"$O"; g $? "T11f üstüne yazmak SESSİZ değil — yüzeye basılır"
# renk değişimi de görünür olmalı: yeşilden kırmızıya düşen bir yeniden-ölçüm
O2="$(bash "$K" olcum is-tekrar et --asama once -- bash -c 'exit 1' 2>&1 >/dev/null)"
grep -q "renk=yesil → kirmizi" <<<"$O2"; g $? "T11g renk değişimi söylenir (yeşili sessizce kırmızıya çevirmez)"
[ "$(python3 -c "import json;print(json.load(open('$R/KANIT.json'))['kayitlar'][-1]['renk'])")" = kirmizi ]; g $? "T11h son renk manifestte kirmizi"
# AYRI etiket/aşama BİRLEŞMEZ → T11c tautoloji değil
bash "$K" olcum is-tekrar et --asama sonra -- echo z >/dev/null 2>&1
bash "$K" olcum is-tekrar baska --asama once -- echo z >/dev/null 2>&1
[ "$(python3 -c "import json;print(len(json.load(open('$R/KANIT.json'))['kayitlar']))")" = 3 ]; g $? "T11i farklı aşama/etiket AYRI kayıt kalır (3 kayıt) — birleştirme körü körüne değil"

echo "════ T12 · GEÇERSİZ UTF-8 baytı aracı ÇÖKERTMEZ, kayıt yazılır (NÂZIR/MOTOR1) ════"
# VAKA: text=True + errors= yok → çocuk sürecin yarım-kesilmiş Türkçe karakteri
#   UnicodeDecodeError veriyordu; kayıt HİÇ yazılmıyordu ve sebebi görünmüyordu (sessiz).
U="$T/_agents/fabrika/kanit/is-bayt"
bash "$K" olcum is-bayt ham --asama tek -- bash -c 'printf "ba\xc5lam\n"' >/dev/null 2>&1; g $? "T12a geçersiz bayta rağmen rc=0"
[ -f "$U/KANIT.json" ]; g $? "T12b kayıt YAZILDI (eskiden hiç yazılmıyordu)"
[ -s "$U/olcum-ham-tek.txt" ]; g $? "T12c kanıt dosyası dolu"
grep -q "ba" "$U/olcum-ham-tek.txt"; g $? "T12d okunabilen kısım korunmuş"
bash "$K" dogrula is-bayt >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T12e dogrula rc=0"
# stderr tarafı da aynı kapıdan geçmeli
bash "$K" olcum is-bayt hamerr --asama tek -- bash -c 'printf "x\xffy\n" >&2' >/dev/null 2>&1; g $? "T12f geçersiz bayt stderr'de de çökertmez"

echo "════ T13 · MUTASYON: iki onarım da kablolu mu (süs değil mi) ════"
M2="$T/kanit-mutant-tekrar.py"
python3 -c 'import sys;s=open(sys.argv[1],encoding="utf-8").read();s=s.replace("    eski_sira = next((i for i, k in enumerate(kayitlar) if k.get(\"dosya\") == kayit.get(\"dosya\")), None)","    eski_sira = None",1);open(sys.argv[2],"w",encoding="utf-8").write(s)' "$HERE/kanit.py" "$M2"
MR="$T/_agents/fabrika/kanit/is-mut1"
KANIT_DEPO="$T" python3 "$M2" olcum is-mut1 e --asama once -- echo a >/dev/null 2>&1
KANIT_DEPO="$T" python3 "$M2" olcum is-mut1 e --asama once -- echo b >/dev/null 2>&1
KANIT_DEPO="$T" python3 "$M2" dogrula is-mut1 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T13a MUTASYON: üstüne-yazma kaldırılınca bayat kayıt geri gelir ve dogrula KIRMIZI olur"

M3="$T/kanit-mutant-bayt.py"
python3 -c 'import sys;s=open(sys.argv[1],encoding="utf-8").read();s=s.replace("capture_output=True, text=True, errors=\"replace\")","capture_output=True, text=True)",1);open(sys.argv[2],"w",encoding="utf-8").write(s)' "$HERE/kanit.py" "$M3"
KANIT_DEPO="$T" python3 "$M3" olcum is-mut2 e --asama tek -- bash -c 'printf "ba\xc5lam\n"' >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T13b MUTASYON: errors kaldırılınca geçersiz bayt yine çökertir (onarım gerçek)"
[ ! -f "$T/_agents/fabrika/kanit/is-mut2/KANIT.json" ]; g $? "T13c MUTASYON: çöküşte kayıt hiç yazılmaz (sessiz kaybın kendisi)"

echo "════ T14 · İMZA SÜRÜMDEN AYRI: eski araçla yazılan kanıt SUÇLANMAZ (NÂZIR+RASATÇI) ════"
# VAKA: imza gövdesi SURUM içeriyordu → aracı güncellemek, eski araçla yazılmış HER manifesti
#   "elle değişmiş" diye suçluyordu (ölçüldü: nazir kutusunda 31/31). Göç yanlış çare: eski
#   manifestleri yeniden imzalamak, aracın koşmadığı koşumlara imza atması demektir.
_eski_bicime_cevir() { # <KANIT.json yolu>
  python3 - "$1" "$HERE/kanit.py" <<'PYX'
import json,sys,importlib.util
p,arac=sys.argv[1],sys.argv[2]
sp=importlib.util.spec_from_file_location("k",arac); mod=importlib.util.module_from_spec(sp); sp.loader.exec_module(mod)
m=json.load(open(p,encoding="utf-8")); m["arac"]="kanit.py/0.1.0"
m["imza"]=mod.imza_eski(m["kayitlar"], m["arac"])
json.dump(m,open(p,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PYX
}
E="$T/_agents/fabrika/kanit/is-imza"
bash "$K" olcum is-imza a --asama once -- echo x >/dev/null 2>&1; g $? "T14a manifest yazıldı"
_eski_bicime_cevir "$E/KANIT.json"
CIKTI="$(bash "$K" dogrula is-imza 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T14b ESKİ biçimli imza SAĞLAM sayılıyor (rc=0, suçlanmıyor)"
grep -q 'sağlamlığı etkilemez' <<<"$CIKTI"; g $? "T14c sürüm farkı BİLGİ satırı — hüküm değil"
grep -q 'imza eski biçimde' <<<"$CIKTI"; g $? "T14d hangi biçimde imzalandığı söyleniyor (sessiz kabul yok)"
grep -q 'İMZA TUTMUYOR' <<<"$CIKTI"; [ $? -ne 0 ]; g $? "T14e sahtecilik suçlaması YOK"

echo "════ T15 · ama GERÇEKTEN bozulan hâlâ yakalanır (tautoloji panzehiri) ════"
python3 - "$E/KANIT.json" <<'PY15'
import json,sys
p=sys.argv[1]; m=json.load(open(p,encoding="utf-8"))
k=m["kayitlar"][0]; onceki=k.get("renk")
k["renk"]="kirmizi" if onceki!="kirmizi" else "yesil"
assert k["renk"]!=onceki, "bozma hiçbir şeyi değiştirmedi"
json.dump(m,open(p,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PY15
bash "$K" dogrula is-imza >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T15a eski biçimli manifest ELLE bozulunca rc=1"
bash "$K" olcum is-imza b --asama once -- echo y >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T15b bozuk manifeste yeni kayıt EKLENMİYOR"

echo "════ T16 · eski biçimli SAĞLAM manifest, yazım anında YENİ biçime geçer ════"
E2="$T/_agents/fabrika/kanit/is-imza2"
bash "$K" olcum is-imza2 a --asama once -- echo x >/dev/null 2>&1
_eski_bicime_cevir "$E2/KANIT.json"
ERR="$(bash "$K" olcum is-imza2 b --asama once -- echo y 2>&1 >/dev/null)"; g $? "T16a eski biçimli manifeste kayıt eklendi"
grep -q 'yeni biçime geçiyor' <<<"$ERR"; g $? "T16b geçiş SESSİZ değil — yüzeye basılıyor"
python3 -c "
import json,importlib.util
sp=importlib.util.spec_from_file_location('k','$HERE/kanit.py'); mod=importlib.util.module_from_spec(sp); sp.loader.exec_module(mod)
m=json.load(open('$E2/KANIT.json'));assert m['imza']==mod.imza(m['kayitlar']),'yeni bicimde degil'"; g $? "T16c yazımdan sonra imza YENİ biçimde"
bash "$K" dogrula is-imza2 >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T16d geçiş sonrası doğrulama temiz"

echo "════ T17 · MUTASYON: uyumluluk dalı koparılınca eski manifest yine suçlanır ════"
MI="$T/kanit-mutant-imza.py"
sed 's@^    if arac and mevcut == imza_eski(kayitlar, arac):@    if False:@' "$HERE/kanit.py" > "$MI"
if cmp -s "$MI" "$HERE/kanit.py"; then g 1 "T17 mutant FARKSIZ (çapa bayat)"; else
  E3="$T/_agents/fabrika/kanit/is-imza3"
  bash "$K" olcum is-imza3 a --asama once -- echo x >/dev/null 2>&1
  _eski_bicime_cevir "$E3/KANIT.json"
  KANIT_DEPO="$T" python3 "$MI" dogrula is-imza3 >/dev/null 2>&1
  [ $? -eq 1 ]; g $? "T17 MUTASYON: uyumluluk ölünce eski manifest YİNE kırmızı (kapı gerçek)"
fi

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
