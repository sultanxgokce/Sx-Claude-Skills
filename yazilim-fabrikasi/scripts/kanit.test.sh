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

echo "════ T18 · CANLI sınıfı: gerçek ateşleme kaydı (saat damgalı + desenli log satırı, türlü kaynak) yoksa SARI ════"
# Niçin (retro 17 Eki): 10-16 Eki 119 işte en büyük bulgu kümesi "git'te düzeltildi ≠ canlıda çalışıyor". cron/servis/sunucu işinde
# kanıt İLK GERÇEK ATEŞLEME kaydıdır: log satırı + saat + kaynak. Göz tur 1-3: serbest komut (echo · python -c …) sahte log üretebilir →
# serbest komut YOK; kaynak türlü (dosya: · journal: · ssh: · docker:), okuyan komutu ARAÇ kurar (tail/journalctl, sabit argv).
CZ="$T/_agents/fabrika/kanit/is-canli"; LG="$T/log"; mkdir -p "$LG"
_c() { python3 -c "import json,sys;m=json.load(open('$CZ/KANIT.json'));k=[x for x in m['kayitlar'] if x['etiket']==sys.argv[1]][-1];print(json.dumps(k.get(sys.argv[2]),ensure_ascii=False))" "$1" "$2"; }
ISO1="$(date -u -d '-2 min' +%FT%TZ)"; ISO2="$(date -u -d '-1 min' +%FT%TZ)"
printf '%s muhakkik-zil: çaldı\n%s muhakkik-zil: çaldı\n' "$ISO1" "$ISO2" > "$LG/zil.log"
printf 'servis dosyası var\ncron satırı var\n' > "$LG/saatsiz.log"
: > "$LG/bos.log"
printf '%s cloudtop CRON[1]: (abc) CMD (bash baska.sh)\n' "$(LC_ALL=C date -d '-1 min' '+%b %e %H:%M:%S' | tr -s ' ')" > "$LG/cron-baska.log"
printf '%s cloudtop CRON[1]: (abc) CMD (bash donus-zili.sh)\n' "$(LC_ALL=C date -d '-1 min' '+%b %e %H:%M:%S' | tr -s ' ')" > "$LG/cron-zil.log"
printf '%s tek\n' "$(date -d '-1 min' '+%d.%m.%Y %H:%M:%S')" > "$LG/tek.log"
bash "$K" canli is-canli zil --desen muhakkik-zil --kaynak "dosya:$LG/zil.log" >/dev/null 2>&1; g $? "T18a dosya kaynağı, saat damgalı + desenli log → rc=0"
[ "$(_c zil renk)" = '"yesil"' ] && [ "$(_c zil tur)" = '"canli"' ] && [ "$(_c zil kaynak_turu)" = '"dosya"' ]; g $? "T18b manifestte tur=canli renk=yesil kaynak_turu=dosya"
[ "$(_c zil atesleme_sayisi)" = "2" ]; g $? "T18c ateşleme sayısı 2"
python3 -c "
import json,datetime;m=json.load(open('$CZ/KANIT.json'));k=[x for x in m['kayitlar'] if x['etiket']=='zil'][-1];a=k['ilk_atesleme'];s=k['son_atesleme']
assert a['saat']=='$ISO1' and 'çaldı' in a['satir'] and k['kaynak']=='dosya:$LG/zil.log', a
assert datetime.datetime.fromisoformat(a['saat_iso'])<datetime.datetime.fromisoformat(s['saat_iso']), (a,s)
assert k['komut'][0]=='tail' and k['komut'][-1]=='$LG/zil.log', k['komut']"; g $? "T18d ilk + son ateşleme · çözülmüş saat · kaynak · ARACIN kurduğu okuma komutu kayıtta"
[ -f "$CZ/canli-zil.txt" ] && [ "$(grep -c 'çaldı' "$CZ/canli-zil.txt")" = "2" ]; g $? "T18e log çıktısı kırpılmadan dosyada"
bash "$K" dogrula is-canli >/dev/null 2>&1; g $? "T18f imza ve sha sağlam"
bash "$K" canli is-canli saatsiz --desen servis --kaynak "dosya:$LG/saatsiz.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18g saat damgasız satırlar ateşleme sayılmaz → rc=3 (yazılmış ≠ çalışıyor)"
[ "$(_c saatsiz renk)" = '"sari"' ] && [ "$(_c saatsiz atesleme_sayisi)" = "0" ]; g $? "T18h renk=sari, ateşleme 0"
bash "$K" canli is-canli bos --desen x --kaynak "dosya:$LG/bos.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18i boş log → rc=3"
bash "$K" canli is-canli kopuk --desen zil --kaynak "dosya:$LG/yok-boyle-dosya.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18j kaynağa ulaşılamadı (dosya yok, tail rc≠0) → rc=3"
grep -q "ulaşılamadı" <<<"$(_c kopuk not)"; g $? "T18k sebebi kayıtta"
bash "$K" canli is-canli desen1 --desen 'donus-zili' --kaynak "dosya:$LG/cron-baska.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18l --desen tutmayan saatli satır ateşleme değil → rc=3"
bash "$K" canli is-canli desen2 --desen 'donus-zili' --kaynak "dosya:$LG/cron-zil.log" >/dev/null 2>&1; g $? "T18m syslog biçimi + desen tutuyor → rc=0"
[ "$(_c desen2 renk)" = '"yesil"' ] && [ "$(_c desen2 desen)" = '"donus-zili"' ] && [ "$(_c desen2 ilk_atesleme | python3 -c 'import json,sys;a=json.load(sys.stdin);print(a["saat_iso"][:4])')" = "$(date +%Y)" ]; g $? "T18n renk=yesil, desen kayıtta, yılsız syslog saati bu yıla çözüldü"
bash "$K" canli is-canli enaz --desen tek --en-az 2 --kaynak "dosya:$LG/tek.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18o --en-az 2 tek ateşlemeyle rc=3 (gg.aa.yyyy biçimi tanındı)"
[ "$(_c enaz atesleme_sayisi)" = "1" ]; g $? "T18o2 ateşleme 1 sayıldı"
bash "$K" canli is-canli kaynaksiz --desen zil >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T18p --kaynak verilmeden kayıt yazılmaz"
[ ! -f "$CZ/canli-kaynaksiz.txt" ]; g $? "T18q kaynaksız dosya oluşmadı"
bash "$K" canli is-canli desensiz --kaynak "dosya:$LG/zil.log" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T18p2 --desen verilmeden kayıt yazılmaz (genel saat ateşleme değildir)"
[ ! -f "$CZ/canli-desensiz.txt" ]; g $? "T18q2 desensiz dosya oluşmadı"
printf '%s muhakkik-zil: çaldı\n' "$(date -u -d '+2 hours' +%FT%TZ)" > "$LG/gelecek.log"
bash "$K" canli is-canli gelecek --desen muhakkik-zil --kaynak "dosya:$LG/gelecek.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18f2 geleceğe tarihli ateşleme → SARI rc=3"
grep -q "GELECEKTE" <<<"$(_c gelecek not)" && [ "$(_c gelecek renk)" = '"sari"' ]; g $? "T18f3 sebebi kayıtta"
# --son: okunan kuyruk uzunluğu araca ait; eski ateşleme kuyruğun dışında kalırsa sayılmaz (tail -n)
bash "$K" canli is-canli son1 --desen muhakkik-zil --son 1 --kaynak "dosya:$LG/zil.log" >/dev/null 2>&1; g $? "T18s --son 1 ile yalnız son satır okunur → rc=0"
[ "$(_c son1 atesleme_sayisi)" = "1" ] && [ "$(_c son1 komut | python3 -c 'import json,sys;k=json.load(sys.stdin);print(k[k.index("-n")+1])')" = "1" ]; g $? "T18s2 ateşleme 1, komutta -n 1"
bash "$K" canli is-canli yok-komut --desen x --kaynak "journal:yok-birim" >/dev/null 2>&1; RC=$?; [ "$RC" -eq 3 ]; g $? "T18v journal kaynağı: journalctl yoksa ya da birim yoksa traceback değil SARI rc=3"
# iki ortam meşru: journalctl yok/erişilemez → "ulaşılamadı" (konteyner) · journalctl var, birim yok → rc 0, "ateşleme kaydı YOK" (CI runner); ikisi de SARI
grep -qE "ulaşılamadı|ateşleme kaydı YOK" <<<"$(_c yok-komut not)" && [ "$(_c yok-komut renk)" = '"sari"' ] && [ "$(_c yok-komut komut | python3 -c 'import json,sys;print(json.load(sys.stdin)[0])')" = "journalctl" ]; g $? "T18w sebep kayıtta (ulaşılamadı | ateşleme YOK), renk sarı, komut journalctl sabit argv"
# 🔴 göz tur 1-3: ateşleme kaydı ÜRETİLMEZ, OKUNUR — serbest komut yolu YOK, kaynak türü dışı red
bash "$K" canli is-canli sahte1 --desen sahte --kaynak "komut:echo $ISO1 sahte" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18x tanınmayan kaynak türü (komut:) reddedilir, rc=1"
[ ! -f "$CZ/canli-sahte1.txt" ] && [ "$(python3 -c "import json;print(sum(1 for x in json.load(open('$CZ/KANIT.json'))['kayitlar'] if x['etiket']=='sahte1'))")" = "0" ]; g $? "T18x2 manifeste de yazılmadı"
bash "$K" canli is-canli sahte2 --desen sahte --kaynak "dosya:$LG/zil.log" -- python3 -c "print('$ISO1 sahte')" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18y '--' sonrası serbest komut kabul edilmez (python/awk üretici kapısı kapalı)"
bash "$K" canli is-canli sahte3 --desen sahte --kaynak "ssh:kutu:/var/log/x;echo $ISO1 sahte" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18y2 ssh yolunda kabuk metakarakteri reddedilir (uzak kabuk enjeksiyonu yok)"
bash "$K" canli is-canli sahte4 --desen sahte --kaynak "ssh:kutu\$(id):/var/log/x" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18y3 ssh hedefinde metakarakter reddedilir"
bash "$K" canli is-canli sahte5 --desen sahte --kaynak "ssh:-F/tmp/cfg:/var/log/x" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18y4 ssh hedefi '-' ile başlayamaz (seçenek enjeksiyonu: -F cfg) — yedek göz #354"
bash "$K" canli is-canli sahte6 --desen sahte --kaynak "docker:kutu:-rf" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T18y5 docker yolu '-' ile başlayamaz"
# ssh/docker: araç SABİT argv kurar (ssh <hedef> tail -n N -- <yol>); sınavda ssh yerine PATH'te sahte ssh: argümanları kaydeder, yerel dosyayı basar
SHIM="$T/shim"; mkdir -p "$SHIM"; cat > "$SHIM/ssh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${SSH_SHIM_ARGS:?}"
# son argüman yol: yerel kopyasını bas
tail -n "${6}" -- "${!#}"; exit "${SSH_SHIM_RC:-0}"
SH
chmod +x "$SHIM/ssh"
SSH_SHIM_ARGS="$T/ssh-args.txt" PATH="$SHIM:$PATH" bash "$K" canli is-canli uzak --desen muhakkik-zil --kaynak "ssh:abc@kutu:$LG/zil.log" >/dev/null 2>&1; g $? "T18z ssh kaynağı: araç sabit argv kurar, uzaktan okunan satırlar ateşleme → rc=0"
[ "$(sed -n 1p "$T/ssh-args.txt")" = "-o" ] && grep -qx "abc@kutu" "$T/ssh-args.txt" && grep -qx "tail" "$T/ssh-args.txt" && [ "$(_c uzak kaynak_turu)" = '"ssh"' ]; g $? "T18z2 ssh argv: BatchMode · hedef · tail · yol (kabuk dizgesi yok)"
CIKTI="$(bash "$K" dogrula is-canli 2>&1)"; grep -q "canlı" <<<"$CIKTI"; g $? "T18t dogrula özeti canlı kayıtlarını söylüyor"
CIKTI="$(bash "$K" ozet is-canli 2>&1)"; grep -q "canli" <<<"$CIKTI"; g $? "T18u ozet tablosunda tür canli görünüyor"

echo "════ T19 · MUTASYON: saat şartı · kopuk kaynak · yol doğrulaması — her biri kaldırılınca sınav kırmızı ════"
MC="$T/pkg-canli"; mkdir -p "$MC"; cp "$HERE/kanit.sh" "$MC/"
_mut() { python3 - "$HERE/kanit.py" "$MC/kanit.py" "$1" "$2" <<'PY'
import sys; src,dst,eski,yeni=sys.argv[1:]; s=open(src,encoding='utf-8').read(); o=s
s=s.replace(eski,yeni); assert s!=o, "mutasyon deseni tutmadı: "+eski; open(dst,'w',encoding='utf-8').write(s)
PY
}
_mut "if not m: continue" "if False: continue"
python3 - "$MC/kanit.py" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read(); o=s; s=s.replace('ates.append((satir, m.group(0)))','ates.append((satir, m.group(0) if m else ""))'); assert s!=o; open(p,'w',encoding='utf-8').write(s)
PY
KANIT_DEPO="$T" python3 "$MC/kanit.py" canli is-canli-m saatsiz --desen servis --kaynak "dosya:$LG/saatsiz.log" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T19a mutant saatsiz satırı ateşleme sayıyor → T18g bu mutantta düşerdi"
bash "$K" canli is-canli-m saatsiz2 --desen servis --kaynak "dosya:$LG/saatsiz.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T19b gerçek araç aynı girdiyle hâlâ sarı (mutasyon kaynağı bozdu, düzeneği değil)"
_mut 'renk = "sari" if (p.returncode != 0' 'renk = "sari" if (False'
SSH_SHIM_ARGS="$T/ssh-args3.txt" SSH_SHIM_RC=255 PATH="$SHIM:$PATH" bash "$K" canli is-canli-m kopuk0 --desen muhakkik-zil --kaynak "ssh:kutu:$LG/zil.log" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "T18j2 uzak okuma satır bastı ama rc=255 (bağlantı koptu) → gerçek araç SARI"
SSH_SHIM_ARGS="$T/ssh-args3.txt" SSH_SHIM_RC=255 PATH="$SHIM:$PATH" KANIT_DEPO="$T" python3 "$MC/kanit.py" canli is-canli-m kopuk --desen muhakkik-zil --kaynak "ssh:kutu:$LG/zil.log" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T19c mutant (kopuk kaynak sarı değil) kopuk bağlantıyı yeşil sayıyor → T18j2 bu mutantta düşerdi"
_mut 'if not GUVENLI_RE.match(parca):' 'if False:'
SSH_SHIM_ARGS="$T/ssh-args2.txt" PATH="$SHIM:$PATH" KANIT_DEPO="$T" python3 "$MC/kanit.py" canli is-canli-m sahte --desen sahte --kaynak "ssh:kutu:/var/log/x;echo" >/dev/null 2>&1; [ $? -ne 1 ]; g $? "T19d mutant (yol doğrulaması kaldırıldı) metakarakterli yolu reddetmiyor → T18y2 bu mutantta düşerdi"

echo "════ T20 · BORU REDDİ (görev PTHAQ): kabuk -c betiğinde çıkış kodunu maskeleyen desen kayıt ÜRETMEZ ════"
BD="$T/_agents/fabrika/kanit/is-boru"
_yok() { python3 - "$BD/KANIT.json" "$1" <<'PY'
import json,os,sys; p,et=sys.argv[1:]
m=json.load(open(p)) if os.path.exists(p) else {"kayitlar":[]}
sys.exit(1 if any(k.get("etiket")==et for k in m["kayitlar"]) else 0)
PY
}
_alan() { python3 - "$BD/KANIT.json" "$1" "$2" <<'PY'
import json,sys; p,et,bekle=sys.argv[1:]
k=[x for x in json.load(open(p))["kayitlar"] if x["etiket"]==et][-1]
sys.exit(0 if k.get("boru_denetimi","").startswith(bekle) else 1)
PY
}
bash "$K" olcum is-boru kuyruk --asama tek -- bash -c 'false | tail -1' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20a pipefail'siz boruyla biten betik REDDEDİLDİ (rc=1)"
_yok kuyruk; g $? "T20a2 reddedilen betik için kayıt YOK"
bash "$K" olcum is-boru yut --asama tek -- bash -c 'false || true' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20b '|| true' reddedildi"
bash "$K" olcum is-boru yutara --asama tek -- bash -c 'false || true; ls /' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20b2 betiğin ORTASINDAKİ '|| true' da reddedildi (son komut temiz olsa bile)"
bash "$K" olcum is-boru yanki --asama tek -- bash -c 'false; echo bitti' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20c başka komuttan sonra gelen son 'echo' reddedildi"
bash "$K" olcum is-boru pf --asama tek -- bash -c 'set -o pipefail; false | tail -1' >/dev/null 2>&1; g $? "T20d 'set -o pipefail' ile boru kabul edildi"
python3 -c "import json;k=[x for x in json.load(open('$BD/KANIT.json'))['kayitlar'] if x['etiket']=='pf'][-1];assert k['renk']=='kirmizi' and k['boru_denetimi']=='temiz'"; g $? "T20d2 pipefail'li boru gerçek rc'yi taşıdı: renk=kirmizi, boru_denetimi=temiz"
bash "$K" olcum is-boru pfarg --asama tek -- bash -o pipefail -c 'false | cat' >/dev/null 2>&1; g $? "T20e kabuk argümanındaki '-o pipefail' de sayıldı"
bash "$K" olcum is-boru kisa --asama tek --boru-izin "kisa" -- bash -c 'false | tail -1' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20f 15 karakterden kısa --boru-izin gerekçesi reddedildi"
bash "$K" olcum is-boru izin --asama tek --boru-izin "sayım için grep, rc anlamsız" -- bash -c 'false | tail -1' >/dev/null 2>&1; g $? "T20g gerekçeli --boru-izin ile kayıt alındı"
python3 -c "import json;k=[x for x in json.load(open('$BD/KANIT.json'))['kayitlar'] if x['etiket']=='izin'][-1];assert k['boru_denetimi'].startswith('izinli:') and 'sayım için grep' in k['boru_denetimi']"; g $? "T20g2 izin ve gerekçe manifeste yazıldı (denetçi görür)"
bash "$K" olcum is-boru argv --asama tek -- true >/dev/null 2>&1; _alan argv "kapsam-dışı"; g $? "T20h kabuk -c olmayan komut: boru_denetimi=kapsam-dışı (sınır beyan edildi)"
bash "$K" olcum is-boru hd --asama tek -- bash -c 'cat <<EOF
x
EOF' >/dev/null 2>&1; _alan hd "ayrıştırılamadı"; g $? "T20i heredoc: reddedilmedi, boru_denetimi=ayrıştırılamadı"
bash "$K" olcum is-boru tek --asama tek -- bash -c 'echo TEK' >/dev/null 2>&1; _alan tek "temiz"; g $? "T20j betiğin TEK komutu echo: temiz (maskelenen iş yok)"
bash "$K" olcum is-boru tirnak --asama tek -- bash -c "echo 'a | b'; exit 0" >/dev/null 2>&1; _alan tirnak "temiz"; g $? "T20k tırnak içindeki '|' boru sayılmadı"
bash "$K" olcum is-boru pfkelime --asama tek -- bash -c 'echo pipefail; false | cat' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20l 'pipefail' KELİMESİ geçmesi yetmez (göz tur 1): echo pipefail; false | cat reddedildi"
bash "$K" olcum is-boru pfkapat --asama tek -- bash -c 'set -o pipefail; set +o pipefail; false | cat' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20m 'set +o pipefail' ile kapatılan boru reddedildi (durum sırayla izlenir)"
bash "$K" olcum is-boru pfargkapat --asama tek -- bash +o pipefail -c 'false | cat' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20n kabuk argümanında '+o pipefail' reddedildi"
bash "$K" olcum is-boru sonset --asama tek -- bash -c 'false | cat; set -o pipefail' >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T20o son komut 'set' (öncekinin rc'sini yutar) reddedildi"

echo "════ T21 · MUTASYON: boru denetiminin her kolu kaldırılınca T20 kırmızıya döner ════"
_mutkos() { KANIT_DEPO="$T" python3 "$MC/kanit.py" olcum is-boru-mut "$1" --asama tek -- bash -c "$2" >/dev/null 2>&1; }
_mut 'durum, neden = boru_denetimi(a.komut)' 'durum, neden = "temiz", None'
_mutkos m1 'false | tail -1'; [ $? -eq 0 ]; g $? "T21a mutant (denetim hiç çağrılmıyor) maskeli betiği kabul ediyor → T20a bu mutantta düşerdi"
_mut 'if "|" in son and not pipefail:' 'if False:'
_mutkos m2 'false | tail -1'; [ $? -eq 0 ]; g $? "T21b mutant (boru kuralı yok) → T20a bu mutantta düşerdi"
_mut 'if jet[k] == "||" and' 'if False and'
_mutkos m3 'false || true; ls /'; [ $? -eq 0 ]; g $? "T21c mutant ('|| true' kuralı yok) ortadaki maskeyi kabul ediyor → T20b2 bu mutantta düşerdi"
_mut 'if son[0] in MASKE_SON and oncesi:' 'if False:'
_mutkos m4 'false; echo bitti'; [ $? -eq 0 ]; g $? "T21d mutant (son-echo kuralı yok) → T20c bu mutantta düşerdi"
_mut 'durum = a[0] == "-"' 'durum = True'
_mutkos m5 'set -o pipefail; set +o pipefail; false | cat'; [ $? -eq 0 ]; g $? "T21e mutant (pipefail kapatma yok sayılıyor) → T20m bu mutantta düşerdi"
_mut 'pipefail = _pipefail_etkisi(komut[1:i], False)' 'pipefail = any("pipefail" in t for t in jet)'
_mutkos m6 'echo pipefail; false | cat'; [ $? -eq 0 ]; g $? "T21f mutant (eski kelime araması) → T20l bu mutantta düşerdi"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
