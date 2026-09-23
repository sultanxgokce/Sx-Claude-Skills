#!/usr/bin/env bash
# denetci.test.sh — bağımsız göz betiğini SAHTE denetçiyle (DENETCI_KOMUT) sahte depoda koşturur.
# Ölçtüğü: kanıt kapısı · yazan≠denetleyen · puan/karar · tavan 3(+1)/4 · geçersiz çıktı=ölçemedi · istem içeriği.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"; KT="$HERE/kart.sh"
kartac() { bash "$KT" ac "$1" --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e >/dev/null 2>&1; }
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
export KANIT_DEPO="$T"
printf 'diff --git a/x b/x\n+satir\n' > "$T/d.patch"
printf 'İŞ: buton ekle\nKİM İSTEDİ: Sultan\nSINIF: yok\n' > "$T/kart.md"
# sahte denetçi: SAHTE_JSON env'ini basar, istem dosyasını kopyalar (içerik sınavı için)
SAHTE="$T/sahte.sh"; cat > "$SAHTE" <<'SH'
#!/usr/bin/env bash
cp "$1" "${SAHTE_ISTEM_KOPYA:-/dev/null}"; printf '%s' "$SAHTE_JSON"
SH
chmod +x "$SAHTE"; export DENETCI_KOMUT="$SAHTE"
J() { printf '{"kod_puani":%s,"dogru_sey":"%s","ozet":"o","bulgular":[%s],"kanit_gorusu":"k"}' "$1" "$2" "$3"; }
B='{"ne":"n","kanit":"k","konum":"x:1","agirlik":"uygulama"}'

echo "════ T1 · kanıt yok → rc=2, denetim dosyası yok ════"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-a --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "kanıtsız adım 4 açılmadı (rc=2)"
[ ! -f "$T/_agents/fabrika/kanit/is-a/DENETIM-1.json" ]; g $? "DENETIM yazılmadı"

echo "════ T2 · kanıt var, 3/H → rc=1, tur 1 ════"
bash "$K" olcum is-a olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B")" bash "$D" is-a --diff "$T/d.patch" --kart "$T/kart.md" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "rc=1 (adım 2'ye dön)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-a/DENETIM-1.json'));assert d['tur']==1 and d['sonuc']['kod_puani']==3 and d['yazan']=='claude' and d['sonuc']['dogru_sey']=='H'"; g $? "DENETIM-1.json araç yazdı, tur=1, alanlar doğru"

echo "════ T3 · 5/E → rc=0 GEÇTİ, tur 2 ════"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-a --diff "$T/d.patch" --kart "$T/kart.md" 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "rc=0"
grep -q "GEÇTİ" <<<"$CIKTI" && grep -q "tur 2" <<<"$CIKTI"; g $? "GEÇTİ ve tur 2 yazılı"

echo "════ T4 · 5 ama H → geçmez (doğru şey sütunu puanı ezer) ════"
bash "$K" olcum is-b olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 5 H "")" bash "$D" is-b --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "5/H → rc=1"

echo "════ T5 · yazan=denetleyen reddedilir (K1) ════"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-b --diff "$T/d.patch" --yazan codex --denetci codex >/dev/null 2>&1; [ $? -eq 1 ]; g $? "aynı model → rc=1"
[ ! -f "$T/_agents/fabrika/kanit/is-b/DENETIM-2.json" ]; g $? "denetim koşulmadı"

echo "════ T6 · tavan: üç düşük tur ilerlemeden → 3. turda tıkandı (rc=4), 4. çağrı reddedilir ════"
bash "$K" olcum is-c olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-c --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "tur1 rc=1"
SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-c --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "tur2 rc=1"
CIKTI="$(SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-c --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 4 ]; g $? "tur3 ilerlemeyince rc=4"
grep -q "Üç yol" <<<"$CIKTI" && grep -q "KAPSAMI DARALT" <<<"$CIKTI"; g $? "tıkandı + üç yol raporu"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-c --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "4. çağrı koşulmadı (rc=4)"
[ ! -f "$T/_agents/fabrika/kanit/is-c/DENETIM-4.json" ]; g $? "DENETIM-4 yazılmadı"

echo "════ T7 · ilerleyen iş +1 tur alır; 4 mutlak ════"
bash "$K" olcum is-d olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B,$B,$B")" bash "$D" is-d --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-d --diff "$T/d.patch" >/dev/null 2>&1
CIKTI="$(SAHTE_JSON="$(J 4 H "$B")" bash "$D" is-d --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "tur3 ilerliyor → rc=1 (tıkandı değil)"
grep -q "+1 tur payı" <<<"$CIKTI"; g $? "+1 tur payı yazılı"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-d --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "tur4 (pay) 5/E → GEÇTİ"
grep -q "İLERLİYOR" <<<"$CIKTI"; g $? "payın gerekçesi yazılı"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-d --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "tur5 mutlak tavan → rc=4"

echo "════ T7b · 🚪 SULTAN KAPISI: karar KARTTAN okunur, serbest metinle açılmaz ════"
# NİÇİN (23 Eyl canlı vaka): tıkandı raporu "karar sınıf işiyse Sultan'ın" diyordu ama araçta
# o kararı kabul edecek kapı YOKTU. Kapı onarımında puanlar 3·3·2 gitti; düşüşün sebebi işin
# kötüleşmesi değil, denetçinin her turda DAHA CİDDİ kusur bulmasıydı — "ilerliyor_mu" bu ikisini
# ayırt edemez. Kural insana havale ediyor, araç insanı dinlemiyordu.
# 🔴 İLK TASARIMIM YANLIŞTI (bağımsız göz tur 1, ciddi): kapıyı komut satırındaki serbest metinle
#    açıyordum — yani komutu çalıştıran herkes 20 karakterlik herhangi bir şeyle yetki kapısını
#    açabiliyordu. Artık karar KARTA işlenir (kart.sh sultan-dedi, D1: oturum-ref · kırpık · beyan)
#    ve kapı oradan okur. Uydurmayı imkânsız kılmaz; uydurmayı KAYITLI ve denetlenebilir yapar.
kartac is-s; bash "$K" olcum is-s olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "puan düşünce tur3 tıkandı (rc=4)"
# kartta kayıt YOKKEN bayrak işe yaramaz
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-s --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "🔴 kartta karar yokken bayrak kapıyı AÇMIYOR (rc=1)"
grep -q "KARTTA gerekçeli" <<<"$CIKTI"; g $? "sebebi yazılı"
grep -q "sultan-dedi" <<<"$CIKTI"; g $? "ne yapılacağı komutla yazılı"
[ ! -f "$T/_agents/fabrika/kanit/is-s/DENETIM-4.json" ]; g $? "denetim KOŞULMADI"
[ ! -f "$T/_agents/fabrika/tavan-defteri.log" ]; g $? "deftere de yazılmadı"
# eksik parçalı D1 kaydı REDDEDİLİR
bash "$KT" sultan-dedi is-s --karar devam --oturum ref1 --soz "devam" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "--beyan eksikken kart kaydı REDDEDİLDİ"
bash "$KT" sultan-dedi is-s --karar devam --soz "devam" --beyan MUAVIN >/dev/null 2>&1; [ $? -ne 0 ]; g $? "--oturum eksikken REDDEDİLDİ"
# tam D1 kaydı → kapı açılır
# gerekçesiz kayıt da REDDEDİLİR — "devam" sözcüğü gerekçe değildir (bağımsız göz tur 2)
bash "$KT" sultan-dedi is-s --karar devam --oturum ref0 --soz "devam" --beyan MUAVIN >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 --gerekce eksikken REDDEDİLDİ"
bash "$KT" sultan-dedi is-s --karar devam --oturum ref0 --soz "devam" --beyan MUAVIN --gerekce "kisa" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "20 karakterden kısa gerekçe REDDEDİLDİ"
bash "$KT" sultan-dedi is-s --karar devam --oturum "muavin/4390ad1f" --soz "olur bir tur daha devam" --beyan MUAVIN --gerekce "acik bulgu kucuk ve anlasilir, birakmak kapinin amacini curutur" >/dev/null 2>&1; g $? "tam D1 kaydı (gerekçeli) karta işlendi"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-s --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "karttaki kararla tur4 koştu ve GEÇTİ"
grep -q "TAVAN AÇILDI" <<<"$CIKTI"; g $? "tavanın açıldığını SÖYLÜYOR (sessiz değil)"
grep -q "muavin/4390ad1f" <<<"$CIKTI"; g $? "oturum referansı çıktıda görünüyor"
grep -q "kapinin amacini curutur" <<<"$CIKTI"; g $? "GEREKÇE de çıktıda görünüyor (niçin bir tur daha)"
[ -s "$T/_agents/fabrika/tavan-defteri.log" ]; g $? "tavan defteri GERÇEKTEN yazıldı"
grep -q "olur bir tur daha devam" "$T/_agents/fabrika/tavan-defteri.log"; g $? "Sultan'ın kırpık sözü defterde"
grep -q "beyan=MUAVIN" "$T/_agents/fabrika/tavan-defteri.log"; g $? "beyan eden ajan defterde (kim aktardı)"
grep -q "kapinin amacini curutur" "$T/_agents/fabrika/tavan-defteri.log"; g $? "gerekçe defterde (Sultan gün sonunda niçin'i görür)"
# 🔴 Deftere YAZILAMIYORSA kapı açılmaz — kaydedilemeyen istisna delikTİR
kartac is-u; bash "$K" olcum is-u olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-u --diff "$T/d.patch" >/dev/null 2>&1; done
bash "$KT" sultan-dedi is-u --gerekce "acik bulgu kucuk ve anlasilir, birakmak kapinin amacini curutur" --karar devam --oturum ref9 --soz "devam et" --beyan MUAVIN >/dev/null 2>&1
# 🔴 Dizini kilitlemek YETMEZ: var olan bir dosyaya eklemek dizin izni değil DOSYA izni
#    ister. İlk denememde bunu kaçırdım ve sınav yanlış sebepten yeşil verecekti.
touch "$T/_agents/fabrika/tavan-defteri.log"; chmod a-w "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-u --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
chmod u+w "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null
[ "$RC" -eq 1 ]; g $? "🔴 deftere yazılamıyorsa kapı AÇILMIYOR"
grep -q "geri OKUNAMADI" <<<"$CIKTI"; g $? "sebebi yazılı"
# 🔴 İKİNCİ YÜZEY: yazma BAŞARILI görünüp içerik kaybolursa da kapı açılmamalı (defter /dev/null'a
#    bağlıysa append rc=0 döner ama satır yoktur). Geri-okuma kontrolünü ölçen tek vaka budur.
kartac is-v; bash "$K" olcum is-v olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-v --diff "$T/d.patch" >/dev/null 2>&1; done
bash "$KT" sultan-dedi is-v --gerekce "acik bulgu kucuk ve anlasilir, birakmak kapinin amacini curutur" --karar devam --oturum ref7 --soz "devam" --beyan MUAVIN >/dev/null 2>&1
rm -f "$T/_agents/fabrika/tavan-defteri.log"; ln -s /dev/null "$T/_agents/fabrika/tavan-defteri.log"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-v --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
rm -f "$T/_agents/fabrika/tavan-defteri.log"
[ "$RC" -eq 1 ]; g $? "🔴 yazma başarılı ama satır kaybolduysa kapı AÇILMIYOR"
grep -q "geri OKUNAMADI" <<<"$CIKTI"; g $? "kaybolduğunu söylüyor"

# 🔴 ELLE YAZILMIŞ KART: kart.sh gerekçesiz kaydı reddediyor, ama kartı elle düzenleyen ya da
#    eski sürümle damgalanmış bir kart gerekçesiz olabilir. Kapı KENDİ kontrolünü yapmalı —
#    "yazan araç doğrulamıştır" varsayımı, aracın atlatılabildiği her yerde çöker.
kartac is-y; bash "$K" olcum is-y olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-y --diff "$T/d.patch" >/dev/null 2>&1; done
python3 - "$T/_agents/fabrika/kartlar/is-y.json" <<'PYX'
import json,sys
y=sys.argv[1]; k=json.load(open(y,encoding="utf-8"))
k["sultan_kararlari"]=[{"karar":"devam","oturum":"ref-elle","soz":"devam","beyan":"MUAVIN","zaman":"2026-09-23T00:00:00+03:00"}]
json.dump(k,open(y,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PYX
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "🔴 elle yazılmış GEREKÇESİZ kart kapıyı AÇMIYOR"
grep -q "KARTTA gerekçeli" <<<"$CIKTI"; g $? "sebebi yazılı"
python3 - "$T/_agents/fabrika/kartlar/is-y.json" <<'PYX'
import json,sys
y=sys.argv[1]; k=json.load(open(y,encoding="utf-8"))
k["sultan_kararlari"][0]["gerekce"]="kisa"
json.dump(k,open(y,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PYX
SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/d.patch" --sultan-devam >/dev/null 2>&1; [ $? -eq 1 ]; g $? "elle yazılmış KISA gerekçe de AÇMIYOR"
# 🔴 MUTLAK tavanı AÇMAZ — dört tur hâlâ mutlaktır
kartac is-t; bash "$K" olcum is-t olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-t --diff "$T/d.patch" >/dev/null 2>&1; done
bash "$KT" sultan-dedi is-t --gerekce "acik bulgu kucuk ve anlasilir, birakmak kapinin amacini curutur" --karar devam --oturum ref2 --soz "devam edelim" --beyan MUAVIN >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-t --diff "$T/d.patch" --sultan-devam >/dev/null 2>&1
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-t --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
[ "$RC" -eq 4 ]; g $? "🔴 5. tur: Sultan kapısı MUTLAK tavanı açmıyor (rc=4)"
grep -q "mutlak tavan" <<<"$CIKTI"; g $? "mutlak olduğunu söylüyor"

echo "════ T8 · geçersiz çıktı → rc=3 ölçemedi, ham saklanır ════"
bash "$K" olcum is-e olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON='ben denetçiyim, her şey harika' bash "$D" is-e --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "JSON değil → rc=3"
[ -f "$T/_agents/fabrika/kanit/is-e/DENETIM-1-HAM.txt" ]; g $? "ham çıktı saklandı"
SAHTE_JSON='{"kod_puani":9,"dogru_sey":"E","ozet":"","bulgular":[],"kanit_gorusu":""}' bash "$D" is-e --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "puan 9 → rc=3 (şema dışı)"

echo "════ T9 · istem: kart + manifest + diff + rubrik içeriyor ════"
bash "$K" olcum is-f olc --asama tek -- echo 42 >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-kopya.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-f --diff "$T/d.patch" --kart "$T/kart.md" >/dev/null 2>&1
grep -q "buton ekle" "$T/istem-kopya.md" && grep -q '"imza"' "$T/istem-kopya.md" && grep -q "+satir" "$T/istem-kopya.md" && grep -q "BAĞIMSIZ GÖZ" "$T/istem-kopya.md" && grep -q "^42" "$T/istem-kopya.md"; g $? "kart · manifest · diff · rubrik · ölçüm çıktısı istemde"

echo "════ T9b · Türkçe metin + KESME İŞARETİ çıktıyı kırmıyor (23 Eyl canlı hatası) ════"
bash "$K" olcum is-tirnak olc --asama tek -- echo 1 >/dev/null 2>&1
TIRNAKLI='{"kod_puani":3,"dogru_sey":"H","ozet":"Ajanın kendi işi; kapının kaçışı kapatılmamış.","bulgular":[{"ne":"Kapının açığı var, ajanın yolu boş","kanit":"betiğin 31. satırı","konum":"a.sh:31","agirlik":"uygulama"}],"kanit_gorusu":"Manifest sağlam; ölçümün çifti yok."}'
CIKTI="$(SAHTE_JSON="$TIRNAKLI" bash "$D" is-tirnak --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "rc=1 (3/H) — kesme işaretli metinde de karar verildi"
grep -q "KOD İYİ Mİ: 3/5 · DOĞRU ŞEY Mİ: H" <<<"$CIKTI"; g $? "puan satırı basıldı"
grep -q "Ajanın kendi işi" <<<"$CIKTI"; g $? "özet kesme işaretiyle birlikte basıldı"
grep -q "Kapının açığı var" <<<"$CIKTI"; g $? "bulgu satırı basıldı"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-tirnak/DENETIM-1.json'));assert d['sonuc']['kod_puani']==3 and 'Ajanın' in d['sonuc']['ozet']"; g $? "kayıt dosyası doğru yazıldı"

echo "════ T10 · bozuk manifest → rc=2 ════"
python3 - <<PY
import json;p='$T/_agents/fabrika/kanit/is-f/KANIT.json';m=json.load(open(p));m['kayitlar'][0]['renk']='yesil-boyali';json.dump(m,open(p,'w'))
PY
SAHTE_JSON="$(J 5 E "")" bash "$D" is-f --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "elle boyanmış manifestle denetim açılmaz"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
if [ -n "${IC_KOSUM:-}" ]; then echo "(ic)"; [ "$kalan" -eq 0 ]; exit $?; fi
echo "════ T11 · MUTASYON: Sultan kapısını bozunca sınav kırmızı veriyor mu ════"
mut() { # mut <ad> <sed-ifadesi> [hedef]
  local hedef="${3:-$HERE/denetci.sh}" M="$HERE/.mutant-$1.sh"
  # 🔴 GEÇERSİZ MUTANT TUZAĞI (bağımsız göz 23 Eyl): sed ifadem hatalıydı, mutant üretilmedi ve
  #    sınav "kırmızı" verdi — ama kırmızının sebebi davranış değişikliği değil, bozuk sed'di.
  #    Artık sed'in başarısını VE mutantın orijinalden FARKLI olduğunu ölçüyoruz.
  if ! sed "$2" "$hedef" > "$M" 2>"$M.err"; then
    kalan=$((kalan+1)); echo "  ✗ mutant '$1': sed BAŞARISIZ → $(head -1 "$M.err")"; rm -f "$M" "$M.err"; return
  fi
  if cmp -s "$M" "$hedef"; then
    kalan=$((kalan+1)); echo "  ✗ mutant '$1': orijinalden FARKSIZ (çapa bayatlamış) — ölçtüğü şey yok"; rm -f "$M" "$M.err"; return
  fi
  chmod +x "$M"
  IC_KOSUM=1 MUTANT_D="$M" bash "$0" >/dev/null 2>&1
  [ $? -ne 0 ]; g $? "mutant '$1' sınavı KIRMIZI yapıyor"
  rm -f "$M" "$M.err"
}
mut "gerekce-zorunlulugunu-kaldir" 's@^if len(x.get("gerekce") or "") < 20: raise SystemExit(1)@pass@'
mut "karti-okumayi-kaldir" 's@^  if \[ -z "$GEREKCE" \]; then@  if false; then@'
mut "defter-dogrulamasini-kaldir" 's@^  grep -qF "$SATIR" "$DEF"@  true@'
mut "mutlak-tavani-kaldir" 's@^if \[ "$TUR" -gt "$MUTLAK" \]; then@if false; then@'

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
