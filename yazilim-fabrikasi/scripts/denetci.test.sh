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
echo "════ T7c · 🚪 REİS KAPISI: sınıfsız işte sahip kararı KARTTAN; sınıflı kartta KAPALI ════"
# NİÇİN (8 Eki 2026 · A268): tıkandı raporu "karar iş sahibinin/reisin, sınıf işiyse Sultan'ın" diyordu ama araç
# yalnız Sultan'ın kararını okuyordu. Sınıfsız işin sahibi kendi yetkisindeki kararı yazdıramıyor; kapı ya kapalı
# kalıyor ya da A06'ya özendiriyordu (aynı gün iki vaka: DEVRİYE doğrulayıcısı · kokpit A2).
# (a) SINIFLI kart: reis yolu her adımda KAPALI
kartac is-r1; bash "$K" olcum is-r1 olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "sınıflı iş tur3 tıkandı (rc=4)"
bash "$KT" reis-dedi is-r1 --karar devam --reis MUAVIN --oturum ref-r1 --gerekce "bulgular farkliydi ve hepsi kapandi, dorduncu tur ilerlemeyi olcer" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 SINIFLI karta reis kararı YAZILAMADI (merci Sultan)"
python3 -c "import json;k=json.load(open('$T/_agents/fabrika/kartlar/is-r1.json'));assert not k.get('reis_kararlari')"; g $? "kartta reis_kararlari alanı oluşmadı"
python3 - "$T/_agents/fabrika/kartlar/is-r1.json" <<'PY'
import json,sys; k=json.load(open(sys.argv[1])); k["reis_kararlari"]=[{"karar":"devam","reis":"MUAVIN","oturum":"ref-elle","gerekce":"yirmi karakterden uzun elle yazilmis gerekce"}]; json.dump(k,open(sys.argv[1],"w"))
PY
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r1 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "🔴 sınıflı karta ELLE yazılmış reis kararı bile kapıyı AÇMIYOR (rc=1)"
grep -q "SINIFLI" <<<"$CIKTI"; g $? "sebebi yazılı: kart sınıflı, merci Sultan"
grep -q "sultan-dedi" <<<"$CIKTI"; g $? "doğru yol gösterildi (sultan-dedi)"
[ ! -f "$T/_agents/fabrika/kanit/is-r1/DENETIM-4.json" ]; g $? "denetim KOŞULMADI"
! grep -q "is=is-r1" "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null; g $? "deftere de yazılmadı"
# (b) SINIFSIZ kart: karar karttan okunur, serbest metinle açılmaz
bash "$KT" ac is-r2 --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-r2 olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r2 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r2 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r2 --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "sınıfsız iş tur3 tıkandı (rc=4)"
CIKTI="$(SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r2 --diff "$T/d.patch" 2>&1)"; grep -q "reis-dedi" <<<"$CIKTI"; g $? "tıkandı raporu sınıfsız iş için reis yolunu da söylüyor"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r2 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "🔴 kartta reis kararı yokken bayrak kapıyı AÇMIYOR (rc=1)"
grep -q "reis-dedi" <<<"$CIKTI"; g $? "ne yapılacağı komutla yazılı"

echo "════ TW · kart TEK kaynak (15 Eki): iş alanından (worktree) koşan denetçi kartı BİRİNCİL depodan okur ════"
# NİÇİN: kart.sh birincil depoya yazar; denetçi iş alanındaki BAYAT kopyayı okuyordu → reis-dedi işlenmişken kapı "karar YOK" dedi
#        (bir günde 4 koşum boşa, elle kopyalama gerekti). Kart artık birincilden okunur, PR'a kanıt dizinindeki KART.json ile gider.
( cd "$T" && git add -A >/dev/null 2>&1; git -c user.email=t@t -c user.name=T commit -qm "chore: defter" >/dev/null 2>&1 )
W="$T/alan-is-w"; git -C "$T" worktree add -q -b is-w "$W" >/dev/null 2>&1; [ -d "$W" ]; g $? "iş alanı (worktree) açıldı"
bash "$KT" ac is-w --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
mkdir -p "$W/_agents/fabrika/kartlar"; cp "$T/_agents/fabrika/kartlar/is-w.json" "$W/_agents/fabrika/kartlar/"   # eski aracın bıraktığı kopya
KANIT_DEPO="$W" bash "$K" olcum is-w olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B")" KANIT_DEPO="$W" bash "$D" is-w --diff "$T/d.patch" >/dev/null 2>&1; done
bash "$KT" reis-dedi is-w --karar devam --reis MUAVIN --oturum ref-w-birincil --gerekce "bulgular kapandi, dorduncu tur ilerlemeyi olcer" >/dev/null 2>&1; g $? "reis kararı BİRİNCİL karta işlendi (kart.sh)"
python3 -c "import json;assert not json.load(open('$W/_agents/fabrika/kartlar/is-w.json')).get('reis_kararlari')"; g $? "iş alanındaki kopya BAYAT (reis kararı yok) — eski araç bunu okur, kapıyı kapalı sanırdı"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" SAHTE_ISTEM_KOPYA="$T/istem-w.txt" KANIT_DEPO="$W" bash "$D" is-w --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "TAVAN AÇILDI" <<<"$CIKTI"; g $? "🔴 iş alanından koşan --reis-devam kapıyı BİRİNCİL karttan AÇTI (elle kopyalama yok, rc=0)"
grep -q "ref-w-birincil" "$T/istem-w.txt"; g $? "denetçi istemindeki iş kartı da BİRİNCİL kart (reis kararı görünüyor)"
python3 -c "import json;assert json.load(open('$W/_agents/fabrika/kanit/is-w/KART.json')).get('reis_kararlari')[0]['oturum']=='ref-w-birincil'"; g $? "kartın anlık kopyası kanıt dizinine düştü (KART.json) — PR'a kart bununla gider, kartlar/ kopyasıyla değil"
SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w --diff "$T/d.patch" >/dev/null 2>&1; [ $? -ne 2 ]; g $? "KART.json kanıt manifestini BOZMAZ (sonraki koşum kanıt kapısında düşmüyor)"
rm -f "$W/_agents/fabrika/kartlar/is-w.json"
SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w --diff "$T/d.patch" --reis-devam >/dev/null 2>&1; [ $? -ne 1 ]; g $? "iş alanında kart kopyası HİÇ yokken de birincil kart okunur (kapı 'karar YOK' demez)"
# 🔴 göz tur 1: birincilde kart yokken alandaki BAYAT kopyaya geri dönmek talebi çürütür ("bayat kopya okunmaz") → okunmaz, rc=3
#    (taze iş is-w2: is-w tavanını yemiş durumda; tavan kapısı kart okumadan ÖNCE koşar, rc=4 bu kapıyı maskelerdi)
bash "$KT" ac is-w2 --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
KANIT_DEPO="$W" bash "$K" olcum is-w2 olc --asama tek -- echo 1 >/dev/null 2>&1
mv "$T/_agents/fabrika/kartlar/is-w2.json" "$T/is-w2.kart.yedek"; mkdir -p "$W/_agents/fabrika/kartlar"; cp "$T/is-w2.kart.yedek" "$W/_agents/fabrika/kartlar/is-w2.json"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" SAHTE_ISTEM_KOPYA="$T/istem-w2.txt" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "OKUNMAZ" <<<"$CIKTI"; g $? "🔴 birincilde kart YOKKEN alandaki kopya OKUNMAZ: rc=3 + 'OKUNMAZ' (eski geri-dönüş kapandı)"
[ ! -f "$T/istem-w2.txt" ] && [ ! -f "$W/_agents/fabrika/kanit/is-w2/DENETIM-1.json" ]; g $? "denetçiye istem HİÇ gitmedi, kayıt yazılmadı (bayat kartla puanlama yok)"
mv "$T/is-w2.kart.yedek" "$T/_agents/fabrika/kartlar/is-w2.json"; rm -f "$W/_agents/fabrika/kartlar/is-w2.json"
# 🔴 göz tur 2: reis/Sultan kapısı da kart hatasını BASTIRMAZ — tavandaki işte bayat kopya varken --reis-devam "karar YOK" reddi değil, açık rc=3 'OKUNMAZ'
bash "$KT" ac is-w3 --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
KANIT_DEPO="$W" bash "$K" olcum is-w3 olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B")" KANIT_DEPO="$W" bash "$D" is-w3 --diff "$T/d.patch" >/dev/null 2>&1; done
mv "$T/_agents/fabrika/kartlar/is-w3.json" "$T/is-w3.kart.yedek"; cp "$T/is-w3.kart.yedek" "$W/_agents/fabrika/kartlar/is-w3.json"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w3 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "OKUNMAZ" <<<"$CIKTI" && ! grep -qi "karar YOK\|reis kararı yok" <<<"$CIKTI"; g $? "🔴 tavanda --reis-devam + bayat kopya: rc=3 'OKUNMAZ' (kapı reddi 'karar yok' DEĞİL — hata bastırılmıyor)"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w3 --diff "$T/d.patch" --sultan-devam 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "OKUNMAZ" <<<"$CIKTI"; g $? "aynı durumda --sultan-devam da rc=3 'OKUNMAZ'"
mv "$T/is-w3.kart.yedek" "$T/_agents/fabrika/kartlar/is-w3.json"; rm -f "$W/_agents/fabrika/kartlar/is-w3.json"
# 🔴 göz tur 1: KART.json anlık kopyası yazılamazsa hata YUTULMAZ — PR'a kart gitmezdi, denetim rc=3
chmod a-w "$W/_agents/fabrika/kanit/is-w2"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" 2>&1)"; RC=$?; chmod u+w "$W/_agents/fabrika/kanit/is-w2"
[ "$RC" -eq 3 ] && grep -q "YAZILAMADI" <<<"$CIKTI" && [ ! -f "$W/_agents/fabrika/kanit/is-w2/DENETIM-1.json" ]; g $? "🔴 KART.json yazılamayınca rc=3 + 'YAZILAMADI', kayıt yok (sahte başarı yok)"
SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 0 ] && [ -f "$W/_agents/fabrika/kanit/is-w2/KART.json" ]; g $? "dizin yazılabilir olunca KART.json düşer ve tur 1 geçer (rc=0)"
# verilen --kart dosyası yoksa denetim kartsız SÜRMEZ (eskiden cp hatası yutuluyor, denetçi kartsız puanlıyordu)
SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" --kart "$T/yok-boyle-kart.md" >"$T/kartyok.out" 2>&1; RC=$?   # kanıt W'de; kapı sırası kanıt→tavan→kart
[ "$RC" -eq 3 ] && grep -q "okunamadı" "$T/kartyok.out"; g $? "🔴 --kart dosyası yoksa rc=3 + 'okunamadı' (kartsız sessiz puanlama kapandı)"
# 🔴 göz tur 3: birincil kart VARKEN farklı --kart tek-kaynağı aşamaz
SAHTE_JSON="$(J 5 E "")" SAHTE_ISTEM_KOPYA="$T/istem-w2b.txt" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" --kart "$T/kart.md" >"$T/kartfarkli.out" 2>&1; RC=$?
[ "$RC" -eq 3 ] && grep -q "TEK kaynak" "$T/kartfarkli.out" && [ ! -f "$T/istem-w2b.txt" ]; g $? "🔴 birincil kart varken FARKLI --kart: rc=3 'TEK kaynak', istem gitmedi (atlama kapandı)"
SAHTE_JSON="$(J 5 E "")" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" --kart "$T/_agents/fabrika/kartlar/is-w2.json" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "--kart birincil kartın kendisiyse geçer (rc=0)"
# 🔴 göz tur 4: birebir KOPYA --kart kabul edilse de okunan yol BİRİNCİL kalır — harici kopya sonradan değişse de istem/KART.json birincilden gelir
cp "$T/_agents/fabrika/kartlar/is-w2.json" "$T/is-w2.kopya.json"
python3 - "$T/_agents/fabrika/kartlar/is-w2.json" <<'PY'
import json,sys;p=sys.argv[1];k=json.load(open(p));k['is']='BIRINCIL-DAMGA-w2';json.dump(k,open(p,'w'),ensure_ascii=False)
PY
SAHTE_JSON="$(J 5 E "")" SAHTE_ISTEM_KOPYA="$T/istem-w2c.txt" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" --kart "$T/is-w2.kopya.json" >"$T/kartkopya.out" 2>&1; RC=$?
[ "$RC" -eq 3 ] && grep -q "TEK kaynak" "$T/kartkopya.out"; g $? "kopya birincilden saptıysa (içerik farklı) yine rc=3"
cp "$T/_agents/fabrika/kartlar/is-w2.json" "$T/is-w2.kopya.json"   # kopyayı birincille eşitle (aynı içerik)
SAHTE_JSON="$(J 5 E "")" SAHTE_ISTEM_KOPYA="$T/istem-w2c.txt" KANIT_DEPO="$W" bash "$D" is-w2 --diff "$T/d.patch" --kart "$T/is-w2.kopya.json" >"$T/kartkopya.out" 2>&1; RC=$?
[ "$RC" -eq 0 ] && grep -qF "okunan yol birincil kart: $T/_agents/fabrika/kartlar/is-w2.json" "$T/kartkopya.out" && grep -q "BIRINCIL-DAMGA-w2" "$T/istem-w2c.txt"; g $? "🔴 aynı içerikli harici --kart: geçer ama OKUNAN YOL birincil kartın yolu (kullanılan değişken ekranda, istem birincilden)"
grep -q "BIRINCIL-DAMGA-w2" "$W/_agents/fabrika/kanit/is-w2/KART.json"; g $? "KART.json da birincil yoldan yazıldı"
rm -f "$T/is-w2.kopya.json"
bash "$KT" reis-dedi is-r2 --karar devam --oturum ref-r2 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "--reis eksikken REDDEDİLDİ"
bash "$KT" reis-dedi is-r2 --karar devam --reis MUAVIN --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "--oturum eksikken REDDEDİLDİ"
bash "$KT" reis-dedi is-r2 --karar devam --reis MUAVIN --oturum ref-r2 --gerekce "kisa" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "kısa gerekçe REDDEDİLDİ"
bash "$KT" reis-dedi is-r2 --karar devam --reis SERDAR --oturum ref-r2 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 kartın sahibi olmayan ad REDDEDİLDİ (aldi MUAVIN)"
bash "$KT" reis-dedi is-r2 --karar evet --reis MUAVIN --oturum ref-r2 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 küme dışı karar REDDEDİLDİ"
bash "$KT" reis-dedi is-r2 --karar devam --reis "SER|DAR" --oturum ref-r2 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "'|' içeren alan REDDEDİLDİ (defter ayracı)"
bash "$KT" reis-dedi is-r2 --karar devam --reis MUAVIN --oturum "muavin/d69a1b07" --gerekce "uc turun bulgulari farkliydi ve her biri kapandi; dorduncu tur ilerlemeyi olcer" >/dev/null 2>&1; g $? "tam reis kaydı karta işlendi"
python3 -c "import json;k=json.load(open('$T/_agents/fabrika/kartlar/is-r2.json'));assert k['reis_kararlari'][-1]['reis']=='MUAVIN' and not k.get('sultan_kararlari')"; g $? "🔴 kayıt reis_kararlari'nda; sultan_kararlari'na HİÇ dokunulmadı (A06)"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r2 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "karttaki reis kararıyla tur4 koştu ve GEÇTİ"
grep -q "REİS kararı" <<<"$CIKTI"; g $? "açılışın REİS kararıyla olduğu yazılı (Sultan kararı DEĞİL)"
grep -q "muavin/d69a1b07" <<<"$CIKTI"; g $? "oturum referansı çıktıda"
grep -q "TAVAN-ACILDI-REIS | is=is-r2 tur=4" "$T/_agents/fabrika/tavan-defteri.log"; g $? "defter satırı TAVAN-ACILDI-REIS (Sultan satırından ayırt edilir)"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-r2 --diff "$T/d.patch" --reis-devam >/dev/null 2>&1; [ $? -eq 4 ]; g $? "reis kararı MUTLAK tavanı (4) AÇMIYOR → tur5 rc=4"

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

# 🔴 DEFTER AYRAÇ ENJEKSİYONU (bağımsız göz tur 3): alanlar "|" ayrımlı bir kayıt satırına
#    yazılıyor. İçinde "|" ya da satır sonu olan bir değer sütunları kaydırır ya da SAHTE bir
#    ek kayıt gibi görünür. Kendi eliyle satır eklenebilen defter, denetim defteri değildir.
bash "$KT" sultan-dedi is-s --karar devam --oturum "ref|sahte" --soz "x" --beyan M --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 '|' içeren alan kartta REDDEDİLDİ"
bash "$KT" sultan-dedi is-s --karar devam --oturum ref --soz "$(printf 'a\nSAHTE | KAYIT')" --beyan M --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "satır sonu içeren alan REDDEDİLDİ"
# ikinci çit: kart elle yazılmış olsa bile deftere temizlenerek girer
kartac is-z; bash "$K" olcum is-z olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-z --diff "$T/d.patch" >/dev/null 2>&1; done
python3 - "$T/_agents/fabrika/kartlar/is-z.json" <<'PYX'
import json,sys
y=sys.argv[1]; k=json.load(open(y,encoding="utf-8"))
k["sultan_kararlari"]=[{"karar":"devam","oturum":"ref","soz":"a\nSAHTE-SATIR | TAVAN-ACILDI | is=baska",
  "beyan":"M","gerekce":"yirmi karakterden uzun bir gerekce metni","zaman":"2026-09-23T00:00:00+03:00"}]
json.dump(k,open(y,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PYX
SAHTE_JSON="$(J 5 E "")" bash "$D" is-z --diff "$T/d.patch" --sultan-devam >/dev/null 2>&1; g $? "elle yazılmış kirli kartla kapı açıldı (gerekçe tam)"
# Her meşru kayıt zaman damgasıyla BAŞLAR. Damgasız bir satır, enjekte edilmiş satırdır.
! grep -qvE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$T/_agents/fabrika/tavan-defteri.log"; g $? "🔴 defterde damgasız (enjekte) satır YOK"
! grep -qE '\| TAVAN-ACILDI \| is=baska' "$T/_agents/fabrika/tavan-defteri.log"; g $? "enjekte edilen ayraçlar temizlenmiş"
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

echo "════ T9c · KIRPMA KAYDI: kırpılan tur DENETIM json'da kirpildi.oldu=true + bayt + eşik; kırpılmayan tur false (NÂZIR/RASATÇI 8 Eki) ════"
# NİÇİN: kırpma yalnız ekrana ve istemin sonuna düşüyordu, ikisi de kayboluyordu → kırpılan denetim "diff'in tamamını gördü"
# sanılıyordu. İki yanlı: aynı araç, tek değişken (istem boyutu ↔ eşik).
bash "$K" olcum is-kirp olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-kucuk.md" SAHTE_JSON="$(J 3 H "$B")" DENETCI_KIRP_ESIK=200000 bash "$D" is-kirp --diff "$T/d.patch" >/dev/null 2>&1
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-kirp/DENETIM-1.json'));k=d['kirpildi'];assert k['oldu'] is False and k['istem_bayt']>0 and k['esik']==200000"; g $? "kırpılmayan tur: kirpildi.oldu=false, bayt ve eşik yazılı"
! grep -q "KIRPILDI" "$T/istem-kucuk.md"; g $? "küçük istemde kırpma uyarısı YOK"
head -c 6000 /dev/zero | tr '\0' 'x' | sed 's/^/+/' > "$T/buyuk.patch"; printf 'diff --git a/y b/y\n' | cat - "$T/buyuk.patch" > "$T/buyuk2.patch"
CIKTI="$(SAHTE_ISTEM_KOPYA="$T/istem-buyuk.md" SAHTE_JSON="$(J 3 H "$B")" DENETCI_KIRP_ESIK=2200 bash "$D" is-kirp --diff "$T/buyuk2.patch" 2>&1)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-kirp/DENETIM-2.json'));k=d['kirpildi'];assert k['oldu'] is True and k['istem_bayt']>2400 and k['esik']==2200"; g $? "🔴 kırpılan tur: kirpildi.oldu=true, gerçek bayt ve eşik KALICI kayıtta"
grep -q "KIRPILDI" "$T/istem-buyuk.md"; g $? "denetçiye kırpıldığı söylendi (istem sonunda uyarı)"
grep -q "KIRPILDI" <<<"$CIKTI"; g $? "ekranda da yazıldı"
[ "$(wc -c < "$T/istem-buyuk.md")" -lt 2600 ]; g $? "istem gerçekten eşiğe kırpıldı"

echo "════ T10 · bozuk manifest → rc=2 ════"
python3 - <<PY
import json;p='$T/_agents/fabrika/kanit/is-f/KANIT.json';m=json.load(open(p));m['kayitlar'][0]['renk']='yesil-boyali';json.dump(m,open(p,'w'))
PY
SAHTE_JSON="$(J 5 E "")" bash "$D" is-f --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "elle boyanmış manifestle denetim açılmaz"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo "════ Y · YEDEK GÖZ (Sultan Y0006): auto kipinde codex yoksa/düşerse yazandan farklı yeni Claude oturumu ════"
FAKE="$T/bin"; mkdir -p "$FAKE"
printf 'İŞ: buton ekle\nKİM İSTEDİ: Sultan\nSINIF: yok\n' > "$T/kart.md"   # T yukarıda temizlendi; Y koşumları kartsız koşmasın (denetçi artık --kart yoksa rc=3)
cat > "$FAKE/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "ARGV: $*" >> "${CLAUDE_ARGV_LOG:-/dev/null}"
printf '{"structured_output":%s}' "$SAHTE_JSON"
SH
cat > "$FAKE/codex.sahte" <<'SH'
#!/usr/bin/env bash
echo x >> "$CODEX_SAYAC"; n=$(wc -l < "$CODEX_SAYAC"); [ "$n" -le "${CODEX_DUSME:-0}" ] && exit 1
for ((i=1;i<=$#;i++)); do if [ "${!i}" = -o ]; then j=$((i+1)); printf '%s' "$SAHTE_JSON" > "${!j}"; fi; done
SH
chmod +x "$FAKE"/*
printf 'diff --git a/y b/y\n+satir\n' > "$T/y.patch"   # d.patch önceki bölümlerde kaldırılabiliyor; kendi diffimiz
YP="$FAKE:$(dirname "$(command -v python3)"):/usr/bin:/bin"   # codex YOK, sahte claude VAR; python3 bu kutuda ayrı dizinde olabilir
bash "$K" olcum is-y olc --asama tek -- echo 1 >/dev/null 2>&1
( unset DENETCI_KOMUT CLAUDE_PID; PATH="$YP" HOME="$T/evsiz" SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y0.out" 2>&1 ); RC=$?
[ "$RC" -eq 3 ] && grep -q "DENETCI_YAZAN_MODEL" "$T/y0.out" && [ ! -e "$T/_agents/fabrika/kanit/is-y/DENETIM-1.json" ]; g $? "Y0 🔴 yazanın modeli hiçbir yüzeyden ÖLÇÜLEMEZSE yedek KOŞMAZ: rc=3, yeniden koşma satırı basılır, kayıt yazılmaz (K1 ölçülemeden yeşil yok)"
# Y0b/Y0c: model BİLDİRİLMEDEN de ölçülür (iş durmaz) — oturum komut satırı ve ayar dosyası (tur 4 bulgusu)
bash "$K" olcum is-y0 olc --asama tek -- echo 1 >/dev/null 2>&1
mkdir -p "$T/ev/.claude"; printf '{"model":"opus"}' > "$T/ev/.claude/settings.json"
( unset DENETCI_KOMUT CLAUDE_PID; PATH="$YP" HOME="$T/ev" CLAUDE_ARGV_LOG="$T/cl0.log" SAHTE_JSON="$(J 5 E "")" bash "$D" is-y0 --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y0b.out" 2>&1 ); RC=$?
[ "$RC" -eq 0 ] && grep -q -- "--model sonnet" "$T/cl0.log" && python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y0/DENETIM-1.json'));assert d['yazan_model']=='opus' and d['yazan_model_kaynak']=='ayar-dosyasi' and d['yedek_model']=='sonnet'"; g $? "Y0b bildirim yokken AYAR DOSYASINDAKİ model yazanın modeli sayılır (opus) → yedek sonnet, kaynak kayıtta; iş DURMAZ"
bash -c 'sleep 20; :' claude --model sonnet & SP=$!; sleep 0.2   # ':' eklenmezse bash tek komutu exec eder, argv kaybolur
( unset DENETCI_KOMUT; PATH="$YP" HOME="$T/ev" CLAUDE_PID="$SP" CLAUDE_ARGV_LOG="$T/cl0c.log" SAHTE_JSON="$(J 5 E "")" bash "$D" is-y0 --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y0c.out" 2>&1 ); RC=$?; kill "$SP" 2>/dev/null
[ "$RC" -eq 0 ] && grep -q -- "--model haiku" "$T/cl0c.log" && python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y0/DENETIM-2.json'));assert d['yazan_model']=='sonnet' and d['yazan_model_kaynak']=='oturum-komutu'"; g $? "Y0c oturum sürecinin komut satırındaki --model (sonnet) ayar dosyasını EZER → yedek haiku, kaynak=oturum-komutu"
( unset DENETCI_KOMUT; PATH="$YP" DENETCI_YAZAN_MODEL=fable SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y1.out" 2>&1 ); RC=$?
[ "$RC" -eq 0 ]; g $? "Y1 codex yokken auto kipi DURMAZ: yazan modeli bildirilince yedek claude puanlar (5/E → rc=0)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y/DENETIM-1.json'));assert d['yedek']=='codex yok' and 'YEDEK' in d['denetci'] and d['sonuc']['kod_puani']==5"; g $? "Y1b kayıtta yedek='codex yok' ve denetçi adında YEDEK GÖZ (codex puanı sanılmaz)"
grep -q "YEDEK GÖZ" "$T/y1.out"; g $? "Y1c ekranda da söylenir (sessiz yedek yok)"
# Y6/Y6b kendi işinde (is-y6) koşar: is-y'nin üç turluk tavanını yemesin (ölçüldü: Y2/Y5 "tavan doldu" rc=4 alıyordu)
bash "$K" olcum is-y6 olc --asama tek -- echo 1 >/dev/null 2>&1
( unset DENETCI_KOMUT; PATH="$YP" CLAUDE_ARGV_LOG="$T/cl.log" DENETCI_YAZAN_MODEL=fable SAHTE_JSON="$(J 5 E "")" bash "$D" is-y6 --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 )
grep -q -- "--model sonnet" "$T/cl.log" && python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y6/DENETIM-1.json'));assert '(sonnet)' in d['denetci'] and 'farklı model kademesi' in d['denetci']"; g $? "Y6 🔴 yedek göz yazanla AYNI modelde koşmaz: farklı kademe (sonnet) + yeni oturum, kayda yazılı (K1 yeniden)"
( unset DENETCI_KOMUT; PATH="$YP" CLAUDE_ARGV_LOG="$T/cl2.log" DENETCI_YAZAN_MODEL=fable DENETCI_YEDEK_MODEL=haiku SAHTE_JSON="$(J 5 E "")" bash "$D" is-y6 --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 )
grep -q -- "--model haiku" "$T/cl2.log"; g $? "Y6b yedek kademesi DENETCI_YEDEK_MODEL ile seçilir"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y6/DENETIM-2.json'));assert d['yazan_model']=='fable' and d['yedek_model']=='haiku'"; g $? "Y6c kayıtta yazan_model ve yedek_model ikisi de dolu (yedek koşumunda boş olamaz)"
( unset DENETCI_KOMUT; PATH="$YP" DENETCI_YAZAN_MODEL=haiku DENETCI_YEDEK_MODEL=haiku SAHTE_JSON="$(J 5 E "")" bash "$D" is-y6 --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y6d.out" 2>&1 ); RC=$?
[ "$RC" -eq 0 ] && ! grep -q -- "--model haiku" "$T/y6d.out"; g $? "Y6d yazanla aynı yedek istenirse merdiven onu ATLAR (haiku→sonnet), aynı modelle koşmaz"
# Y7: yazanın modeli BİLDİRİLİNCE yedek ona EŞİT OLAMAZ (tur 2 bulgusu: varsayılan ad farkı örtmesin)
bash "$K" olcum is-y7 olc --asama tek -- echo 1 >/dev/null 2>&1
( unset DENETCI_KOMUT; PATH="$YP" CLAUDE_ARGV_LOG="$T/cl3.log" DENETCI_YAZAN_MODEL=sonnet SAHTE_JSON="$(J 5 E "")" bash "$D" is-y7 --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 )
grep -q -- "--model haiku" "$T/cl3.log" && python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y7/DENETIM-1.json'));assert d['yazan_model']=='sonnet' and d['yedek_model']=='haiku' and '[yazan: sonnet]' in d['denetci']"; g $? "Y7 yazan sonnet ise varsayılan yedek sonnet OLMAZ → merdivende haiku; ikisi de kayıtta"
( unset DENETCI_KOMUT; PATH="$YP" CLAUDE_ARGV_LOG="$T/cl4.log" DENETCI_YAZAN_MODEL=claude-haiku-4-5 DENETCI_YEDEK_MODEL=haiku SAHTE_JSON="$(J 5 E "")" bash "$D" is-y7 --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 )
grep -q -- "--model sonnet" "$T/cl4.log"; g $? "Y7b istenen yedek (haiku) yazanın modeline (claude-haiku-4-5) eşitse atlanır → sonnet (ad eşlemesi alt-dizgiyle)"
( unset DENETCI_KOMUT; PATH="$YP" CLAUDE_ARGV_LOG="$T/cl5.log" DENETCI_YAZAN_MODEL=opus DENETCI_YEDEK_MODEL=haiku SAHTE_JSON="$(J 5 E "")" bash "$D" is-y7 --diff "$T/y.patch" --kart "$T/kart.md" --model opus >/dev/null 2>&1 )
grep -q -- "--model haiku" "$T/cl5.log"; g $? "Y7c --model doluyken DENETCI_YEDEK_MODEL devre dışı kalmaz (yedek tercihi önce gelir)"
( unset DENETCI_KOMUT; PATH="$YP" SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" --denetci codex >/dev/null 2>&1 ); [ $? -eq 3 ]; g $? "Y2 açık --denetci codex isteğinde codex yoksa eski sert davranış: rc=3"
( unset DENETCI_KOMUT; PATH="$YP" DENETCI_YEDEK=0 SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 ); [ $? -eq 3 ]; g $? "Y5 DENETCI_YEDEK=0 ile yedek kapalı: rc=3"
cp "$FAKE/codex.sahte" "$FAKE/codex"; : > "$T/csay"
( unset DENETCI_KOMUT; PATH="$YP" CODEX_SAYAC="$T/csay" CODEX_DUSME=2 DENETCI_YAZAN_MODEL=fable SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" >"$T/y3.out" 2>&1 ); RC=$?
[ "$RC" -eq 0 ] && [ "$(wc -l < "$T/csay")" -eq 2 ]; g $? "Y3 codex iki denemede de düşerse (2 çağrı sayıldı) yedek claude devralır, rc=0"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y/DENETIM-2.json'));assert d['yedek'].startswith('codex düştü') and 'YEDEK' in d['denetci']"; g $? "Y3b kayıtta yedek='codex düştü…'"
: > "$T/csay"
( unset DENETCI_KOMUT; PATH="$YP" CODEX_SAYAC="$T/csay" CODEX_DUSME=1 SAHTE_JSON="$(J 5 E "")" bash "$D" is-y --diff "$T/y.patch" --kart "$T/kart.md" >/dev/null 2>&1 ); RC=$?
[ "$RC" -eq 0 ] && [ "$(wc -l < "$T/csay")" -eq 2 ]; g $? "Y4 codex bir kez düşüp toparlarsa yedek YOK: ikinci deneme codex (2 çağrı)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y/DENETIM-3.json'));assert d['yedek'] is None and d['denetci'].startswith('codex')"; g $? "Y4b kayıtta yedek=null, denetçi codex (Y1b tautoloji değil)"
rm -f "$FAKE/codex"
# Y8 yalnız ANA koşumda ve kendi mutantında (codex-stdin-acik) koşar: her mutant iç koşumunda tekrarlanınca CI'nın 300 sn tavanı aşıldı (ölçüldü: tam 300 sn'de Terminated)
if [ -z "${IC_KOSUM:-}" ] || [[ "${MUTANT_D:-}" == *codex-stdin-acik* ]]; then
echo "════ Y8 · codex STDIN KAPALI: çağıranın stdin'i hiç kapanmasa da denetçi biter (15 Eki, 68 dk asılı kaldı) ════"
cat > "$FAKE/codex" <<'SH'
#!/usr/bin/env bash
# sahte codex: gerçek codex gibi stdin'i EOF'a kadar okur (stdin açık kalırsa asılı kalır), sonra JSON yazar
cat >/dev/null
for ((i=1;i<=$#;i++)); do if [ "${!i}" = -o ]; then j=$((i+1)); printf '%s' "$SAHTE_JSON" > "${!j}"; fi; done
SH
chmod +x "$FAKE/codex"
bash "$K" olcum is-y8 olc --asama tek -- echo 1 >/dev/null 2>&1
( unset DENETCI_KOMUT; PATH="$YP" DENETCI_YAZAN_MODEL=fable SAHTE_JSON="$(J 5 E "")" timeout 10 bash "$D" is-y8 --diff "$T/y.patch" --kart "$T/kart.md" < <(sleep 30) >"$T/y8.out" 2>&1 ); RC=$?
[ "$RC" -eq 0 ] && python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-y8/DENETIM-1.json'));assert d['denetci'].startswith('codex')"; g $? "🔴 stdin 30 sn açık boruyken denetçi 10 sn içinde BİTTİ (rc=0), codex puanladı — stdin'e bağımlı değil"
rm -f "$FAKE/codex"
fi

if [ -n "${IC_KOSUM:-}" ]; then echo "(ic)"; [ "$kalan" -eq 0 ]; exit $?; fi
echo "════ T11 · MUTASYON: Sultan kapısını bozunca sınav kırmızı veriyor mu ════"
# 🔴 MUTANT KOŞUMU PARALEL (15 Eki, göz #323: CI 300 sn tavanı): her mutant sınav dosyasının TAMAMINI yeniden koşturur
#    (15 mutant × tam koşum — iş kartındaki "18" yanlış sayımdı, origin/main'de `^mut "` satırı 15); sırayla koşunca CI'da 264–300 sn, tavanda Terminated. Mutantlar birbirinden bağımsızdır (her iç
#    koşum kendi mktemp dizininde, kendi .mutant-<ad>.sh dosyasıyla) → nproc kadar (tavan MUT_PARALEL, varsayılan 4) birlikte
#    koşar; sonuçlar KAYIT SIRASIYLA rapor edilir (çıktı deterministik). Kapı sayısı ve mutant yakalama DEĞİŞMEZ.
#    MUT_PARALEL=1 eski sıralı davranış (karşılaştırma/ölçüm için).
MUT_PARALEL="${MUT_PARALEL:-$(nproc 2>/dev/null || echo 2)}"
# göz tur 1: sayı olmayan değer -gt/-lt'de düşer, iç döngü hiç dönmez, dış döngü SONSUZA dek sürerdi → sayı değilse 1 (sıralı, güvenli)
[[ "$MUT_PARALEL" =~ ^[0-9]+$ ]] || { echo "  (uyarı) MUT_PARALEL sayı değil ('$MUT_PARALEL') → 1 (sıralı)"; MUT_PARALEL=1; }
[ "$MUT_PARALEL" -gt 4 ] && MUT_PARALEL=4; [ "$MUT_PARALEL" -lt 1 ] && MUT_PARALEL=1
MUT_ADLAR=(); MUT_DOSYALAR=(); MUT_RC_DIZ="$(mktemp -d)"
mut() { # mut <ad> <sed-ifadesi> [hedef] — mutantı ÜRETİR ve sıraya koyar; koşum mut_kos'ta (paralel)
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
  chmod +x "$M"; MUT_ADLAR+=("$1"); MUT_DOSYALAR+=("$M")
}
mut_kos() { # sıradaki mutantları en çok MUT_PARALEL koşumla birlikte koşturur; raporu kayıt sırasıyla basar
  local i=0 n=${#MUT_ADLAR[@]} basladi=$(date +%s)
  while [ "$i" -lt "$n" ]; do
    local j=0
    while [ "$j" -lt "$MUT_PARALEL" ] && [ "$i" -lt "$n" ]; do
      ( IC_KOSUM=1 MUTANT_D="${MUT_DOSYALAR[$i]}" bash "$0" >/dev/null 2>&1; echo $? > "$MUT_RC_DIZ/${MUT_ADLAR[$i]}.rc" ) &
      i=$((i+1)); j=$((j+1))
    done
    wait
  done
  local k; for ((k=0;k<n;k++)); do
    local rc; rc="$(cat "$MUT_RC_DIZ/${MUT_ADLAR[$k]}.rc" 2>/dev/null || echo 0)"
    [ "$rc" -ne 0 ]; g $? "mutant '${MUT_ADLAR[$k]}' sınavı KIRMIZI yapıyor"
    rm -f "${MUT_DOSYALAR[$k]}" "${MUT_DOSYALAR[$k]}.err"
  done
  echo "  (bilgi) $n mutant · $MUT_PARALEL paralel · $(( $(date +%s) - basladi )) sn"
  rm -rf "$MUT_RC_DIZ"
}
mut "ayrac-temizligini-kaldir" 's@^def tmz(v): return " ".join(str(v).replace("|","/").split())@def tmz(v): return str(v)@'
mut "gerekce-zorunlulugunu-kaldir" 's@^if len(x.get("gerekce") or "") < 20: raise SystemExit(1)@pass@'

mut "karti-okumayi-kaldir" 's@^  if \[ -z "$GEREKCE" \]; then@  if false; then@'
mut "defter-dogrulamasini-kaldir" 's@^  grep -qF "$SATIR" "$DEF"@  true@'
mut "reis-sinif-citini-kaldir" 's@^if k.get("sultan") or k.get("siniflar"): raise SystemExit(3)@pass@'
mut "mutlak-tavani-kaldir" 's@^if \[ "$TUR" -gt "$MUTLAK" \]; then@if false; then@'
mut "yedek-gozu-kaldir" 's@if yedek_olur_mu; then YEDEK="codex yok";@if false; then YEDEK="codex yok";@'
mut "kart-tek-kaynagi-kaldir" 's@^\[ -n "$KART_DEPO" \] || KART_DEPO="$DEPO"@KART_DEPO="$DEPO"@'
mut "codex-stdin-acik" 's@"$TMP/istem.md")" </dev/null >"$TMP/log"@"$TMP/istem.md")" >"$TMP/log"@'
mut "kart-yolu-harici-kalir" 's@then KART="$BIRINCIL"; _bilgi@then _bilgi@'
mut "kart-secenegi-tek-kaynagi-asar" 's@&& ! cmp -s "$KART" "$BIRINCIL"; then@\&\& false; then@'
mut "kapi-kart-hatasini-bastirir" 's@KARTYOL="$(kart_yolu)" || exit 3;@KARTYOL="$(kart_yolu 2>/dev/null)";@'
mut "bayat-kopya-geri-donusu" 's@OKUNMAZ — kart.sh ile birincile yaz, sonra denetçiyi koştur"; return 3@"; printf "%s" "$DEPO/_agents/fabrika/kartlar/$IS.json"@'
mut "kart-json-hatasi-yutulur" 's@denetim açılmaz"; exit 3; }@denetim açılmaz"; true; }@'
mut "kirpma-kaydini-kaldir" 's@"kirpildi":{"oldu":kirp=="1","istem_bayt":int(bayt),"esik":int(esik)},@"kirpildi":{"oldu":False,"istem_bayt":int(bayt),"esik":int(esik)},@'
mut_kos

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
