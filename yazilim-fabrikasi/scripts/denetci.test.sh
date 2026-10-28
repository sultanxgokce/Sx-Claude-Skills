#!/usr/bin/env bash
# denetci.test.sh — bağımsız göz betiğini SAHTE denetçiyle (DENETCI_KOMUT) sahte depoda koşturur.
# Ölçtüğü: kanıt kapısı · yazan≠denetleyen · puan/karar · tavan 3(+1)/4 · geçersiz çıktı=ölçemedi · istem içeriği.
# kabuk-testleri: sure=900
#   (#404, 21 Eki ölçümü: süit yerelde 778 sn, CI'da 700 sn tavanında Terminated — 44 mutant. Zil mutantları yalnız T-ZIL'i,
#   zil dışı mutantlar T-ZIL'siz koşar; sure kabuk tavanına (900) çekildi. Ana dal CI'da 472 sn idi.)
#   (T11'de 15 mutant var, her biri TÜM süiti IC_KOSUM ile yeniden koşuyor — mutant sayısı büyüdükçe
#   toplam süre büyüyor; CI'da varsayılan 300 sn'de üst üste Terminated oldu, 2026-10-15.)
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI (gerçek koltuklara çalmasın); zil kapısı kendi sahtesini verir
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"; KT="$HERE/kart.sh"
# Sınıflı kart Sultan'a ulaşım yolu ister (--oda + tetik betiği; göz 23 Eki tur 2) — sınav gerçek odaya mektup BIRAKMAZ: sahte tetik.
# 🧹 GEÇİCİ DİZİN SIZINTISI (SERDAR disk önceliği, gorev …DSSE): her koşu 4 dizin (içinde git deposu) + sahte tetik dosyası bırakıyordu;
#    mutasyon koşumları bu betiği yeniden çağırdığından (mut_kos) bir sınav onlarca dizin sızdırıyordu. Hepsi ÇIKIŞTA silinir (erken çıkış dahil).
TEMIZ=(); temizle() { local x; for x in "${TEMIZ[@]:-}"; do [ -n "$x" ] && find "$x" -delete 2>/dev/null; done; return 0; }
trap temizle EXIT
TETIK_SAHTE="$(mktemp)"; printf '#!/usr/bin/env bash\nexit 0\n' > "$TETIK_SAHTE"; TEMIZ+=("$TETIK_SAHTE"); chmod +x "$TETIK_SAHTE"; export FABRIKA_TETIK="$TETIK_SAHTE"
kartac() { bash "$KT" ac "$1" --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e --oda sinav-oda >/dev/null 2>&1; }
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

T="$(mktemp -d)"; TEMIZ+=("$T"); ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
# 🔴 ZİL SIZINTI KİLİDİ (SERDAR 21:18 · #404): sınavdan SERDAR'a üç gerçek zil kaçtı ('BILINMEYEN iş-bitti is-zb') — Z3e sınav kipini
#    ölçmek için FABRIKA_AILE_NOTIFY'ı boşaltıyor, 'sinav-kipi-gercek-zil' mutantı korumayı kapatınca denetçi gerçek aile-notify'ı buldu.
#    Varsayılan zil aracı artık SAHTE: denetçinin keşfi önce PATH'e bakar, PATH başında bu sahte durur — hangi kapı aracı ezerse ezsin
#    gerçek koltuğa yol yok. Sahteye düşen her çağrı sizinti.log'a yazılır; Z12 bunun boş kaldığını ölçer.
ZB="$T/.zil-kilidi"; mkdir -p "$ZB"; printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/sizinti.log"\n' "$ZB" > "$ZB/aile-notify.sh"; chmod +x "$ZB/aile-notify.sh"
export PATH="$ZB:$PATH" AILE_SINYAL_LOG="$ZB/sinyal.log"
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

# ⏱️ IC_BOLUM=zil (#404 CI: süit 748 sn ölçüldü, kabuk tavanı 700 — zil mutantları TÜM süiti yeniden koşuyordu): zil mutantlarının
#    iç koşumu yalnız T-ZIL'i koşar; T-ZIL kendi işlerini, sahtelerini ve patch'ini kurar, aşağıdaki bölümlere dayanmaz.
if [ "${IC_BOLUM:-}" != zil ]; then
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

echo "════ T3b · göz adımı göreve (0.24.0 · Y7J3Q): kartlı iş 5/E ve 3/H turunda kart.sh goz-adim tek satırla çağrılır; kartsız iş çağırmaz; yazılamasa tur sonucu değişmez ════"
KS="$T/kart-sahte.sh"; printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/goz-cagri.log"\n' "$T" > "$KS"; chmod +x "$KS"; export DENETCI_KART_SH="$KS"
kartac is-g; bash "$K" olcum is-g olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B")" bash "$D" is-g --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && [ "$(grep -c . "$T/goz-cagri.log")" -eq 1 ] && grep -qxF -- 'goz-adim is-g --not [🔎 göz] kart is-g · tur 1 · kod 3/5 · doğru şey H · bulgu 1' "$T/goz-cagri.log"; g $? "G-a 3/H turu: kart.sh goz-adim is-g --not '[🔎 göz] kart is-g · tur 1 · kod 3/5 · doğru şey H · bulgu 1' (rc 1 değişmedi)"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-g --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && [ "$(grep -c . "$T/goz-cagri.log")" -eq 2 ] && tail -1 "$T/goz-cagri.log" | grep -qF 'tur 2 · kod 5/5 · doğru şey E · bulgu 0'; g $? "G-b 5/E turu: ikinci satır tur 2 · 5/5 · E · bulgu 0 (rc 0 değişmedi)"
N0=$(grep -c . "$T/goz-cagri.log"); bash "$K" olcum is-h olc --asama tek -- echo 1 >/dev/null 2>&1; SAHTE_JSON="$(J 5 E "")" bash "$D" is-h --diff "$T/d.patch" >/dev/null 2>&1
[ "$(grep -c . "$T/goz-cagri.log")" -eq "$N0" ]; g $? "G-c kartsız iş (kart.json yok): göz adımı çağrılmaz"
printf '#!/usr/bin/env bash\nexit 9\n' > "$KS"; bash "$K" olcum is-g olc2 --asama tek -- echo 1 >/dev/null 2>&1
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-g --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "göz adımı göreve yazılamadı" <<<"$CIKTI"; g $? "G-d kart aracı düşerse turun sonucu DEĞİŞMEZ (rc 0) ama uyarı söylenir"
unset DENETCI_KART_SH

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
echo "════ T7c · 🚪 REİS KAPISI: sınıfsız işte sahip kararı KARTTAN; sınıflı kartta da (araçla yazılmış kayıtla) ════"
# NİÇİN (8 Eki 2026 · A268): tıkandı raporu "karar iş sahibinin/reisin, sınıf işiyse Sultan'ın" diyordu ama araç
# yalnız Sultan'ın kararını okuyordu. Sınıfsız işin sahibi kendi yetkisindeki kararı yazdıramıyor; kapı ya kapalı
# kalıyor ya da A06'ya özendiriyordu (aynı gün iki vaka: DEVRİYE doğrulayıcısı · kokpit A2).
# (a) SINIFLI kart: reis yolu ancak araçla yazılmış (sinifli:true) kayıtla açılır
kartac is-r1; bash "$K" olcum is-r1 olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r1 --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "sınıflı iş tur3 tıkandı (rc=4)"
bash "$KT" reis-dedi is-r1 --karar devam --reis MUAVIN --oturum ref-r1 --gerekce "bulgular farkliydi ve hepsi kapandi, dorduncu tur ilerlemeyi olcer" >/dev/null 2>&1; g $? "0.21.0: SINIFLI karta reis kararı kart.sh ile YAZILDI (denetçinin bunu okuması ikinci kartta: fabrika-merge-reise-parca2)"
python3 -c "import json;k=json.load(open('$T/_agents/fabrika/kartlar/is-r1.json'));r=k['reis_kararlari'][-1];assert r['sinifli'] is True and not k.get('sultan_kararlari')"; g $? "kayıt reis_kararlari'nda sinifli:true; sultan_kararlari YOK (A06)"
# rapor (karar YOKKEN değil, kayıt VARKEN de tur ilerlemezse): tıkandı raporu SINIFLI kartta Sultan yolunu gösterir
CIKTI="$(SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r1 --diff "$T/d.patch" 2>&1)"
grep -qF "kart.sh sultan-dedi is-r1 --karar devam" <<<"$CIKTI" && ! grep -qF "reis-dedi is-r1" <<<"$CIKTI"; g $? "🔴 7KKSJK: SINIFLI kartta tıkandı raporu sultan-dedi komutunu basıyor, reis-dedi'yi DEĞİL"
grep -q "sultan-dedi" <<<"$CIKTI"; g $? "doğru yol gösterildi (sultan-dedi)"
[ ! -f "$T/_agents/fabrika/kanit/is-r1/DENETIM-4.json" ]; g $? "denetim KOŞULMADI"
! grep -q "is=is-r1" "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null; g $? "deftere de yazılmadı"
# 28 Eki (Sultan 22 Eki kararı, parça2): sınıflı kartta reis kararı tavanı AÇAR — ama yalnız araçla yazılmış (sinifli:true) kayıtla
KJ="$T/_agents/fabrika/kartlar/is-r1.json"; cp "$KJ" "$T/is-r1.yedek"
python3 -c "import json;p='$KJ';k=json.load(open(p));k['reis_kararlari'][-1].pop('sinifli',None);json.dump(k,open(p,'w'),ensure_ascii=False)"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r1 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "🔴 sınıflı kartta sinifli:true İŞARETSİZ (elle düzenlenmiş) reis kaydı karar sayılmaz (rc=1)"
! grep -q "is=is-r1" "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null; g $? "o durumda deftere yazılmadı"
cp "$T/is-r1.yedek" "$KJ"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r1 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "🔴 sınıflı kartta araçla yazılmış reis kararı tavanı AÇAR (rc=0)"
grep -q "TAVAN AÇILDI" <<<"$CIKTI"; g $? "açılış ekrana yazıldı"
grep -q "is=is-r1" "$T/_agents/fabrika/tavan-defteri.log" 2>/dev/null; g $? "açılış tavan defterine yazıldı"
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
CIKTI="$(SAHTE_JSON="$(J 5 E "")" DENETCI_EK=--reis-devam bash "$D" is-r2 --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "KARTTA gerekçeli reis" <<<"$CIKTI"; g $? "🔴 7KKSJK: DENETCI_EK=--reis-devam bayrakla AYNI işler (kartta karar yokken rc=1, aynı sebep; yok sayılsaydı rc=4)"
# 7KKSJK: TIKANDI raporu devam yolunun TAM komutunu basar (gerçek iş adı + kartın sahibi + sıra); rc4 + "karar yok" tekrarı biter
CIKTI="$(SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-r2 --diff "$T/d.patch" 2>&1)"
grep -qF "kart.sh reis-dedi is-r2 --karar devam --reis MUAVIN --oturum <ref> --gerekce" <<<"$CIKTI"; g $? "🔴 7KKSJK: tıkandı raporu reis-dedi komutunu GERÇEK iş adı + kartın sahibiyle basıyor"
grep -qF "DENETCI_EK=--reis-devam bash" <<<"$CIKTI" && grep -qF "denetci.sh is-r2" <<<"$CIKTI"; g $? "🔴 7KKSJK: ikinci adım DENETCI_EK=--reis-devam biçiminde, sırayla yazılı"
grep -q "4\. tur ÖNCE bu komutu ister" <<<"$CIKTI"; g $? "🔴 7KKSJK: 'tur 3 tıkandı' → raporda '4. tur' (sıradaki tur) sebebiyle yazılı"

grep -q "ÖNCE bu komutu ister: --reis-devam kapıyı AÇMAZ" <<<"$CIKTI"; g $? "🔴 7KKSJK: karar yokken rc 1 + önce-komut sebebi yazılı"
! grep -q "sultan-dedi" <<<"$CIKTI"; g $? "7KKSJK: sınıfsız iş raporunda Sultan yolu dayatılmıyor"

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
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-r2 --diff "$T/d.patch" --reis-devam 2>&1)"; RC=$?
[ "$RC" -eq 4 ]; g $? "reis kararı MUTLAK tavanı (4) AÇMIYOR → tur5 rc=4"
! grep -qF "kart.sh reis-dedi is-r2" <<<"$CIKTI"; g $? "🔴 7KKSJK: mutlak tavanda reis-dedi komutu BASILMIYOR (açmayacak yolu göstermek yanıltır)"

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
# (PCP7J, 18 Eki) büyük ÜRETİM farkı kırpılmaz, "İŞİ BÖL" der (T-BOL); (BÂNİ 21:59) istemin TAMAMI da öyle (T-ISTEM).
# (göz #436 tur 1, SYV3F) kırpma yolu ayıklama KAPALIYKEN de kalktı: kart "istem tavanı aşınca gönderim durur" diyor, istisna yok.
# Burada fark küçük (d.patch), istem büyük kanıt ölçüm çıktısıyla şişiyor, ayıklama kapalı → yine İŞİ BÖL, tur yanmaz.
bash "$K" olcum is-kirp buyuk-olcum --asama tek -- python3 -c 'print("x"*6000)' >/dev/null 2>&1   # eski `head | tr` boru reddine (0.10.1) takılıp kayda girmiyordu; istem yalnız şablonla şişiyordu
rm -f "$T/istem-buyuk.md"
CIKTI="$(SAHTE_ISTEM_KOPYA="$T/istem-buyuk.md" SAHTE_JSON="$(J 3 H "$B")" DENETCI_KIRP_ESIK=2200 DENETCI_KANIT_AYIKLA=0 bash "$D" is-kirp --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "İŞİ BÖL — göze giden istem [0-9]* bayt > 2400" <<<"$CIKTI"; g $? "🔴 ayıklama kapalıyken de istem tavanı aşılınca İŞİ BÖL (rc 1) — kırpık istem gönderilmez"
[ ! -e "$T/istem-buyuk.md" ] && [ ! -e "$T/_agents/fabrika/kanit/is-kirp/DENETIM-2.json" ]; g $? "denetçiye istem gitmedi, tur yakılmadı (DENETIM-2 yok)"
! grep -q "KIRPILDI" <<<"$CIKTI"; g $? "kırpma uyarısı hiçbir yerde yok (kırpma yolu kalktı)"

echo "════ T9d · GEÇERSİZ ilan (4K938) göze söylenir: kanıt durumu satırında, istemde ve DENETIM kaydında ════"
bash "$K" olcum is-gec olc --asama tek -- echo 1 >/dev/null 2>&1
bash "$K" olcum is-gec olc2 --asama tek -- echo 2 >/dev/null 2>&1
bash "$K" gecersiz is-gec olc --neden "boru çıkış kodunu maskeledi, yanlış ölçüm" --kim T >/dev/null 2>&1
CIKTI="$(SAHTE_ISTEM_KOPYA="$T/istem-gec.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-gec --diff "$T/d.patch" 2>&1)"
grep -q "kanıt: sağlam.*1 kayıt GEÇERSİZ ilan edildi, kanıt sayılmaz: olcum-olc-tek.txt (yesil → gecersiz) — boru çıkış kodunu" <<<"$CIKTI"; g $? "puan satırındaki kanıt durumu geçersiz ilanı nedeniyle söylüyor"
grep -q "durum: sağlam.*GEÇERSİZ ilan edildi" "$T/istem-gec.md"; g $? "istemdeki manifest başlığında da var (göz okur)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-gec/DENETIM-1.json'));assert 'GEÇERSİZ' in json.dumps(d,ensure_ascii=False)"; g $? "DENETIM kaydına da işlendi"

echo "════ T9e · 7KKSJK-EK: GEÇERSİZ ilanlı kaydın GÖVDESİ isteme girmez (istem baytı düşer), geçerli kayıt tam girer ════"
bash "$K" olcum is-gec2 yanlis --asama tek -- bash -c 'for i in $(seq 1 40); do echo "GOVDE_GECERSIZ_ISARETI_$((i+0)) $(head -c 180 /dev/zero | tr "\\0" x)"; done' >/dev/null 2>&1
bash "$K" olcum is-gec2 dogru --asama tek -- bash -c 'for i in $(seq 1 40); do echo "GOVDE_GECERLI_ISARETI_$((i+0)) $(head -c 180 /dev/zero | tr "\\0" x)"; done' >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-g2a.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-gec2 --diff "$T/d.patch" >/dev/null 2>&1
grep -q "GOVDE_GECERSIZ_ISARETI_40" "$T/istem-g2a.md" && grep -q "GOVDE_GECERLI_ISARETI_40" "$T/istem-g2a.md"; g $? "ilandan ÖNCE iki kaydın gövdesi de istemde (taban)"
bash "$K" gecersiz is-gec2 yanlis --neden "boru çıkış kodunu maskeledi, yanlış ölçüm" --kim T >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-g2b.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-gec2 --diff "$T/d.patch" >/dev/null 2>&1
! grep -q "GOVDE_GECERSIZ_ISARETI_[0-9]" "$T/istem-g2b.md"; g $? "🔴 7KKSJK-EK: GEÇERSİZ ilanlı kaydın gövdesi istemde YOK"
grep -q "GOVDE_GECERLI_ISARETI_40" "$T/istem-g2b.md"; g $? "🔴 7KKSJK-EK: GEÇERLİ kaydın gövdesi hâlâ TAM istemde"
grep -q "olcum-yanlis-tek.txt · ⛔ GEÇERSİZ ilan edildi: gövde isteme KONMADI" "$T/istem-g2b.md"; g $? "manifest tarafı: geçersiz kaydın adı ve ilan notu istemde kalıyor"
[ "$(wc -c < "$T/istem-g2b.md")" -lt "$(wc -c < "$T/istem-g2a.md")" ]; g $? "🔴 7KKSJK-EK: istem baytı düştü"

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

# ════ K · KARE (--kare, 15 Eki: göz "kabul karesi sunulmadı" — kare codex'e GÖRSEL ek olarak gider) ════
# Yalnız ANA koşumda (mutant iç koşumlarında tekrarlanırsa CI'nın 300 sn tavanı aşılır — Y8 emsali).
if [ -z "${IC_KOSUM:-}" ]; then
  echo "════ K · KARE ════"
  # önceki bölümler $T'yi temizliyor (sahte.sh de gidiyor) → K kendi sahte denetçisini kurar
  printf '#!/usr/bin/env bash\ncp "$1" "${SAHTE_ISTEM_KOPYA:-/dev/null}"; printf "%%s" "$SAHTE_JSON"\n' > "$T/sahte-k.sh"; chmod +x "$T/sahte-k.sh"; export DENETCI_KOMUT="$T/sahte-k.sh"
  # GERÇEK küçük görseller (yalnız standart kütüphane): 2x2 PNG zlib ile üretilir; 2x2 JPEG gömülü (632 bayt, PIL ile bir kez üretildi)
  python3 - "$T/k1.png" <<'PYP'
import sys,struct,zlib
def y(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
ham=b''.join(b'\x00'+b'\xc8\x1e\x1e'*2 for _ in range(2))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+y(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+y(b'IDAT',zlib.compress(ham))+y(b'IEND',b''))
PYP
  printf '%s' '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDCooorzj7E/9k=' | base64 -d > "$T/k2.jpg"
  printf 'duz metin' > "$T/k3.png"
  head -c 40 "$T/k1.png" > "$T/k4-kesik.png"; printf '\xff\xd8\xff\xe0%s' "sahte-kare-2" > "$T/k5-sahte.jpg"
  # göz #331 tur 2: işaretleri TAŞIYAN ama görüntü olmayan dosyalar (yapı ölçülür, işaret araması değil)
  printf '\xff\xd8duz veri \xff\xc0 serpistirilmis \xff\xd9' > "$T/k6-isaretli.jpg"
  python3 - "$T/k7-idatsiz.png" "$T/k8-boy.png" "$T/k9-adam7.png" "$T/k10-adam7-kisa.png" <<'PYP'
import sys,struct,zlib
def y(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
ih=y(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+ih+y(b'IEND',b''))
open(sys.argv[2],'wb').write(b'\x89PNG\r\n\x1a\n'+ih+y(b'IDAT',zlib.compress(b'\x00\x01\x02'))+y(b'IEND',b''))
# göz #331 tur 3: Adam7 geçişli 3x3 gri — doğru akış (ALTIN, geçmeli) ve 1 bayt eksik akış (KIRMIZI)
ia=y(b'IHDR',struct.pack('>IIBBBBB',3,3,8,0,0,0,1))
dogru=b''.join(b'\x00'+b'\x80'*pw for pw,ph in ((1,1),(1,1),(2,1),(1,2),(3,1)) for _ in range(ph))   # 3x3: geçiş 1,4,5,6,7 dolu (2 ve 3 boş) — 1+1+2+2+3 = 9 piksel
open(sys.argv[3],'wb').write(b'\x89PNG\r\n\x1a\n'+ia+y(b'IDAT',zlib.compress(dogru))+y(b'IEND',b''))
open(sys.argv[4],'wb').write(b'\x89PNG\r\n\x1a\n'+ia+y(b'IDAT',zlib.compress(dogru[:-1]))+y(b'IEND',b''))
PYP
  # SOS'tan hemen sonra EOI: gerçek JPEG'in (k2) SOS bölümünü alıp entropi verisini sil
  python3 - "$T/k2.jpg" "$T/k11-bostarama.jpg" <<'PYJ'
import sys
b=open(sys.argv[1],'rb').read(); i=b.index(b'\xff\xda'); L=(b[i+2]<<8)|b[i+3]
open(sys.argv[2],'wb').write(b[:i+2+L]+b'\xff\xd9')
PYJ
  bash "$K" olcum is-k olc --asama tek -- echo 1 >/dev/null 2>&1
  SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/yok.png" >"$T/k0.out" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && grep -q "dosyası yok" "$T/k0.out" && [ ! -e "$T/_agents/fabrika/kanit/is-k/DENETIM-1.json" ]; g $? "K1 --kare dosyası yoksa rc=2, denetim AÇILMAZ (sessiz atlama yok)"
  SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k3.png" >"$T/k0b.out" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && grep -q "geçerli görsel değil" "$T/k0b.out"; g $? "K2 uzantısı .png ama içi görsel değil → rc=2 (imza ölçülür, ad değil)"
  SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k4-kesik.png" >"$T/k0d.out" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && grep -q "kesik" "$T/k0d.out"; g $? "K2b 🔴 imzası doğru ama KESİK PNG → rc=2 (yapı ölçülür, ilk baytlar değil — göz #331 tur 1)"
  SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k5-sahte.jpg" >"$T/k0e.out" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && grep -q "geçerli görsel değil" "$T/k0e.out"; g $? "K2c 🔴 JPEG başlığı + düz metin (EOI/SOF yok) → rc=2"
  for _s in "k6-isaretli.jpg:K2d 🔴 SOI + serpiştirilmiş SOF işareti + EOI ama bölüm yapısı yok → rc=2 (göz #331 tur 2)" "k7-idatsiz.png:K2e 🔴 CRC'leri doğru IHDR+IEND, piksel verisi (IDAT) yok → rc=2" "k8-boy.png:K2f 🔴 IDAT açılıyor ama boyutu 2×2 RGB'ye tutmuyor → rc=2" "k10-adam7-kisa.png:K2g 🔴 Adam7 geçişli PNG, akış 1 bayt kısa → rc=2 (göz #331 tur 3)" "k11-bostarama.jpg:K2h 🔴 JPEG SOS'tan hemen sonra EOI (piksel verisi yok) → rc=2 (göz #331 tur 3)"; do
    SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/${_s%%:*}" >"$T/k0f.out" 2>&1; RC=$?
    [ "$RC" -eq 2 ] && grep -q "geçerli görsel değil" "$T/k0f.out"; g $? "${_s#*:}"
  done
  # kendi iş adıyla (is-k2i): tam denetim koşar ve DENETIM-1 yazar — is-k'nin tur sayacına dokunmasın (K4/K5/K7 tur 1'i okur)
  bash "$K" olcum is-k2i olc --asama tek -- echo 1 >/dev/null 2>&1
  SAHTE_JSON="$(J 5 E "")" bash "$D" is-k2i --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k9-adam7.png" >"$T/k0g.out" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && ! grep -q "geçerli görsel değil" "$T/k0g.out" && [ -f "$T/_agents/fabrika/kanit/is-k2i/DENETIM-1.json" ]; g $? "K2i ALTIN: doğru Adam7 geçişli PNG kapıdan GEÇER ve denetim tamamlanır (kapı katılaşıp gerçek görseli reddetmesin)"
  ( K9=(); for i in 1 2 3 4 5 6 7 8 9; do K9+=(--kare "$T/k1.png"); done; SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" "${K9[@]}" >"$T/k0c.out" 2>&1; echo $? > "$T/k0c.rc" )
  [ "$(cat "$T/k0c.rc")" -eq 2 ] && grep -q "en çok 8" "$T/k0c.out"; g $? "K3 9 kare → rc=2 (tavan 8)"
  SAHTE_ISTEM_KOPYA="$T/k-istem.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k1.png" --kare "$T/k2.jpg" >"$T/k4.out" 2>&1; RC=$?
  [ "$RC" -eq 0 ] || { echo "   (K4 rc=$RC: $(grep -E '✗|rc|AÇIL|kart' "$T/k4.out" | head -3 | tr '\n' ' '))"; }
  [ "$RC" -eq 0 ] && grep -q "KARELER (2 adet" "$T/k-istem.md" && grep -q "k1.png · sha256" "$T/k-istem.md"; g $? "K4 istemde 'KARELER (2 adet …)' + ad + sha (göz neye bakacağını bilir)"
  python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-k/DENETIM-1.json'));k=d['kareler'];assert k['adet']==2 and k['gorsel_verildi'] is True and [x['ad'] for x in k['liste']]==['k1.png','k2.jpg'] and len(k['liste'][0]['sha256'])==64"; g $? "K5 DENETIM kaydı kareleri taşır: adet · ad · sha256 · görsel verildi"
  cp "$FAKE/codex.sahte" "$FAKE/codex"; printf '%s\n' 'printf "%s\n" "ARGV: $*" >> "${CODEX_ARGV_LOG:-/dev/null}"' >> "$FAKE/codex"; : > "$T/csay"; : > "$T/k-argv.log"
  ( unset DENETCI_KOMUT; PATH="$YP" CODEX_SAYAC="$T/csay" CODEX_ARGV_LOG="$T/k-argv.log" SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k1.png" --kare "$T/k2.jpg" >/dev/null 2>&1 ); RC=$?
  grep -q -- "-i $T/k1.png -i $T/k2.jpg" "$T/k-argv.log"; g $? "K6 🔴 kareler codex'e GÖRSEL ek olarak gider (argv'de -i <kare> ×2)"
  rm -f "$FAKE/codex"
  ( unset DENETCI_KOMUT CLAUDE_PID; PATH="$YP" DENETCI_YAZAN_MODEL=fable SAHTE_JSON="$(J 5 E "")" bash "$D" is-k --diff "$T/y.patch" --kart "$T/kart.md" --kare "$T/k1.png" >/dev/null 2>&1 ); RC=$?
  N="$(ls "$T/_agents/fabrika/kanit/is-k/" | grep -c '^DENETIM-[0-9]*.json$')"
  python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-k/DENETIM-$N.json'));assert d['yedek'] and d['kareler']['gorsel_verildi'] is False"; g $? "K7 yedek göz (claude -p) kareyi GÖREMEZ → kayıtta gorsel_verildi=false (görmüş sanılmaz)"
fi
# T-ISTEM iç koşum çıkışından ÖNCE durur: mutantlar süiti yalnız buraya kadar koşar (aşağıdaki T-BOL/T-DARALT mutant görmez).
export KANIT_DEPO="$T"
echo "════ T-ISTEM · kapı istemin TAMAMINI ölçer: fark küçük ama istem eşiği aşarsa yine 'İŞİ BÖL', tur yakmaz (BÂNİ 21:59, #712 tur 4) ════"
# kendi dizini: önceki bloklar $T içinden sahte denetçiyi ve d.patch'i silebiliyor (iç koşumda ölçüldü)
TI="$(mktemp -d)"; TEMIZ+=("$TI"); ( cd "$TI" && git init -q -b main ) >/dev/null 2>&1
printf '#!/usr/bin/env bash\ncp "$1" "${SAHTE_ISTEM_KOPYA:-/dev/null}"; printf "%%s" "$SAHTE_JSON"\n' > "$TI/sahte.sh"; chmod +x "$TI/sahte.sh"
_T_ONCE="$T"; _DK_ONCE="${DENETCI_KOMUT:-}"; T="$TI"; export KANIT_DEPO="$TI" DENETCI_KOMUT="$TI/sahte.sh"
# (a) fark minik, istemi ölçüm çıktısı şişiriyor (eski kapı burada kırpıp turu yakıyordu)
bash "$K" olcum is-ist buyuk-olcum --asama tek -- python3 -c '[print(i, "x"*150) for i in range(100)]' >/dev/null 2>&1   # boru yok: boru reddi (0.10.1) maskesiz boruyu kayda almaz; 100 kısa satır: özet kuralı (60 satır/3 KB) sonrası da 5 KB üstü kalır (tek 6000 karakterlik satır artık 200'e kesilir)
rm -f "$T/istem-ist.md"; printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n' > "$T/ist1.patch"   # kendi farkı: d.patch önceki sınavlarda silinebiliyor
CIKTI="$(SAHTE_ISTEM_KOPYA="$T/istem-ist.md" SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=2200 bash "$D" is-ist --diff "$T/ist1.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "fark küçük, istem > eşik → rc=1"
grep -q "İŞİ BÖL — göze giden istem [0-9]* bayt > 2400" <<<"$CIKTI"; g $? "'İŞİ BÖL' istemin TAMAMINI ve gerçek eşiği söylüyor"
grep -q "parçalar (bayt):.*iş kartı [0-9]*.*kanıt manifesti [0-9]*.*ölçüm çıktıları [0-9]*.*üretim farkı [0-9]*" <<<"$CIKTI"; g $? "parça parça bayt dökümü basıldı"
grep -q "en büyük parça: ölçüm çıktıları" <<<"$CIKTI" && grep -q "kanit.sh gecersiz" <<<"$CIKTI"; g $? "şişen parça (ölçüm) ve ona uygun yol söylendi"
[ ! -f "$T/_agents/fabrika/kanit/is-ist/DENETIM-1.json" ] && [ ! -f "$T/istem-ist.md" ]; g $? "tur yakılmadı, denetçi hiç çağrılmadı"
# (b) BÂNİ'nin vakası: fark TEK BAŞINA eşiğin altında, ama fark + diğer parçalar eşiği aşıyor
bash "$K" olcum is-ist2 olc --asama tek -- echo 1 >/dev/null 2>&1
python3 -c '
import sys
with open(sys.argv[1],"w") as f:
    f.write("diff --git a/y.ts b/y.ts\n--- a/y.ts\n+++ b/y.ts\n@@ -1 +1,50 @@\n")
    for i in range(50): f.write("+"+("y"*55)+" %d\n" % i)
' "$T/ist2.patch"
SAHTE_ISTEM_KOPYA="$T/istem-ist2.md" SAHTE_JSON="$(J 3 H "$B")" DENETCI_KIRP_ESIK=900000 bash "$D" is-ist2 --diff "$T/ist2.patch" >/dev/null 2>&1
S0=$(wc -c < "$T/istem-ist2.md"); DZ=$(wc -c < "$T/ist2.patch")
E=$(( (S0 - 200) * 11 / 12 ))   # tetik = E + E/11 ≈ S0-200 < istem; fark DZ << E
[ "$DZ" -lt "$E" ]; g $? "kurulum: fark ($DZ) tek başına eşiğin ($E) ALTINDA"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=$E bash "$D" is-ist2 --diff "$T/ist2.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "İŞİ BÖL" <<<"$CIKTI"; g $? "fark eşik altında ama istem eşik üstünde → İŞİ BÖL (rc=1)"
[ ! -f "$T/_agents/fabrika/kanit/is-ist2/DENETIM-2.json" ]; g $? "tur yakılmadı (DENETIM-2 yok)"
# (c) sınır: istem tetiğe sığıyorsa normal denetlenir, kırpılmaz
E2=$(( (S0 + 2000) * 11 / 12 ))   # tur 2 istemi önceki tur kaydını da taşır (~750 bayt) → tetik ≈ S0+2000
CIKTI="$(SAHTE_ISTEM_KOPYA="$T/istem-ist2b.md" SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=$E2 bash "$D" is-ist2 --diff "$T/ist2.patch" 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "istem tetiğe sığıyor → denetim koştu (rc=0)"
python3 -c "import json;d=json.load(open('$T/_agents/fabrika/kanit/is-ist2/DENETIM-2.json'));assert d['kirpildi']['oldu'] is False"; g $? "sığan istem kırpılmadı (kirpildi.oldu=false)"
# (d) parçalı kurulum istemin içeriğini ve sırasını korur
python3 -c '
import sys
s=open(sys.argv[1],encoding="utf-8").read()
b=["===== İŞ KARTI","===== KANIT MANİFESTİ","===== ÖLÇÜM ÇIKTILARI","===== DEĞİŞİKLİK (diff)","+"+"y"*55+" 49","===== ÖNCEKİ TUR"]
i=[s.find(x) for x in b]; assert all(v>=0 for v in i) and i==sorted(i), i
' "$T/istem-ist2b.md"; g $? "istemde bütün başlıklar eski sırasıyla var (iş kartı · manifest · ölçüm · fark · önceki tur)"
# (e) ÖLÇÜM ÇIKTISININ SONU (gorev_01M5890SCNMSR4DFTGHVWEJEC3): 60 satırı aşan ölçümde sonuç satırı göze gider
echo "════ T-OLCUM · uzun ölçümde baş + atlanan + SON gider; kısa ölçüm aynen; uzun stderr sonucu itmez ════"
bash "$K" olcum is-son uzun --asama tek -- python3 -c 'for i in range(184): print("kapi %d" % i)
print("── SONUÇ: %d geçti · 0 kaldı ──" % 156)' >/dev/null 2>&1   # sonuç metni komutta DÜZ geçmesin: dosyanın 1. satırı komuttur
bash "$K" olcum is-son kisa --asama tek -- python3 -c 'for i in range(5): print("kisa-satir-%d" % i)' >/dev/null 2>&1
bash "$K" olcum is-son hata --asama tek -- python3 -c 'import sys
for i in range(100): print("cikti %d" % i)
print("SONUC-SATIRI-" + "X")
for i in range(50): print("hata %d" % i, file=sys.stderr)' >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-son.md" SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=900000 bash "$D" is-son --diff "$T/ist1.patch" >/dev/null 2>&1
bolum() { python3 -c '
import sys
s=open(sys.argv[1],encoding="utf-8").read().split("\n"); b=s.index("--- %s ---" % sys.argv[2])
e=next((i for i in range(b+1,len(s)) if s[i].startswith("--- olcum-") or s[i].startswith("=====")), len(s))
print("\n".join(s[b+1:e]))' "$T/istem-son.md" "$1"; }
U="$(bolum olcum-uzun-tek.txt)"; H="$(bolum olcum-hata-tek.txt)"; KS="$(bolum olcum-kisa-tek.txt)"
grep -qx "── SONUÇ: 156 geçti · 0 kaldı ──" <<<"$U"; g $? "O1 🔴 188 satırlık ölçümün SONUÇ satırı istemde (eskiden ilk 60 satırda kalıyordu)"
grep -q "satır atlandı (dosya [0-9]* satır)" <<<"$U"; g $? "O2 kaç satırın atlandığı ve dosya boyu söylendi"
grep -qx "kapi 0" <<<"$U" && ! grep -qx "kapi 100" <<<"$U" && grep -qx "kapi 183" <<<"$U"; g $? "O3 baş korunur, orta atlanır, son gelir"
[ "$(wc -l <<<"$U")" -le 60 ]; g $? "O4 tavan aynı: dosya başı ≤ 60 satır ($(wc -l <<<"$U"))"
[ "$(grep -c '^kisa-satir-' <<<"$KS")" -eq 5 ] && ! grep -q "atlandı" <<<"$KS"; g $? "O5 kısa ölçüm aynen, işaretsiz"
grep -qx "SONUC-SATIRI-X" <<<"$H" && grep -q "stderr'den [0-9]* satır atlandı" <<<"$H" && grep -qx "hata 49" <<<"$H"; g $? "O6 uzun stderr stdout'un sonucunu dışarı itmez; stderr'in de sonu gelir"
# göz #392 tur 2: sonuç en sonda olmayabilir · ortadaki kırmızı kapı kırpmada saklanmamalı
bash "$K" olcum is-son2 orta --asama tek -- python3 -c 'for i in range(80): print("  ✓ kapi %d" % i)
print("  ✗ kapi " + "kirmizi-orta")
for i in range(40): print("  ✓ kapi2 %d" % i)
print("── SONUÇ: %d geçti · 1 kaldı ──" % 120)
for i in range(30): print("temizlik %d" % i)' >/dev/null 2>&1
SAHTE_ISTEM_KOPYA="$T/istem-son2.md" SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=900000 bash "$D" is-son2 --diff "$T/ist1.patch" >/dev/null 2>&1
U2="$(python3 -c '
import sys
s=open(sys.argv[1],encoding="utf-8").read().split("\n"); b=s.index("--- olcum-orta-tek.txt ---")
e=next((i for i in range(b+1,len(s)) if s[i].startswith("--- olcum-") or s[i].startswith("=====")), len(s))
print("\n".join(s[b+1:e]))' "$T/istem-son2.md")"
grep -qx "  ✗ kapi kirmizi-orta" <<<"$U2"; g $? "O7 🔴 ortadaki KIRMIZI kapı kırpmada saklanmaz (göze gider)"
grep -qx "── SONUÇ: 120 geçti · 1 kaldı ──" <<<"$U2" && ! grep -qx "temizlik 0" <<<"$U2"; g $? "O8 sonuç satırının ardından 12'den çok satır gelse de sonuç gider (orta atlanırken seçilir)"
[ "$(wc -l <<<"$U2")" -le 60 ]; g $? "O9 seçmeyle de tavan aşılmaz ($(wc -l <<<"$U2") ≤ 60)"
# göz #392 tur 3: sayı ve bayt eşitliği — işlev doğrudan sınanır (denetçinin kendi tanımı, mutant kopyası dahil)
OZ="$(sed -n '/^olcum_ozeti()/,/^}/p' "$D")"
printf 'satir-%s\n' $(seq 1 100) > "$T/oz-100.txt"
o10="$(bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-100.txt")"
gor=$(grep -c '^satir-' <<<"$o10"); say=$(grep -o '\[… [0-9]* satır atlandı' <<<"$o10" | grep -o '[0-9]*')
[ "$say" -eq $((100 - gor)) ]; g $? "O10 atlandı sayısı GERÇEK atlanan: bildirilen $say = 100 − gösterilen $gor"
printf 'satir-1\n✓ a\n── SONUÇ: %s ──\n' x > "$T/oz-sec.txt"; for i in $(seq 1 80); do echo "dolgu $i"; done >> "$T/oz-sec.txt"; printf '  ✗ orta-kirmizi\n' >> "$T/oz-sec.txt"; for i in $(seq 1 30); do echo "kuyruk $i"; done >> "$T/oz-sec.txt"
o11="$(bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-sec.txt")"
gor=$(grep -vc '^\[…' <<<"$o11"); say=$(grep -o '\[… [0-9]* satır atlandı' <<<"$o11" | grep -o '[0-9]*'); top=$(wc -l < "$T/oz-sec.txt")
[ "$say" -eq $((top - gor)) ] && grep -qx '  ✗ orta-kirmizi' <<<"$o11"; g $? "O11 seçme varken de sayı doğru: $say = $top − $gor (seçilen satır atlanmış sayılmaz)"
printf 'a\nb\nson-satir-sonu-yok' > "$T/oz-kisa.txt"
bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-kisa.txt" > "$T/oz-kisa.out"
printf 'a\nb\nc\n' > "$T/oz-kisa2.txt"; bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-kisa2.txt" > "$T/oz-kisa2.out"
cmp -s "$T/oz-kisa.txt" "$T/oz-kisa.out" && cmp -s "$T/oz-kisa2.txt" "$T/oz-kisa2.out"; g $? "O12 kısa dosya bayt bayt AYNEN (satır sonuyla biten de bitmeyen de; göz #392 tur 5)"
printf 'satir-sonu-yok-olcum' > "$T/_agents/fabrika/kanit/is-son2/olcum-aa-yoksonu.txt"   # alfabede BAŞTA: ardından gerçek başlık gelsin (sonda kalınca sonraki blok zaten satır başıyla açılıyor → sahte yeşil)
SAHTE_ISTEM_KOPYA="$T/istem-son3.md" SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=900000 bash "$D" is-son2 --diff "$T/ist1.patch" >/dev/null 2>&1
grep -qx "satir-sonu-yok-olcum" "$T/istem-son3.md" && grep -A1 -x "satir-sonu-yok-olcum" "$T/istem-son3.md" | grep -qx -- "--- olcum-orta-tek.txt ---"; g $? "O13 satır sonuyla bitmeyen ölçümden sonra istemde sonraki başlık AYRI satırda (ayırıcıyı çağıran ekler)"
# BÂNİ #506/teslim A: az satırlı ama çok BAYTLI ölçüm (26 KB'lık 60 satır) istemin dörtte birini yiyordu
python3 -c "
open('$T/oz-agir.txt','w').write('\n'.join(('  ✓ kapi %d ' % i) + 'x' * 900 for i in range(30)) + '\n  ✗ kirmizi-kapi\n── SONUÇ: 30 geçti · 1 kaldı ──\n')"
printf 'a\nb\nc\n' > "$T/oz-hafif.txt"; python3 -c "open('$T/oz-hafif60.txt','w').write(''.join('kisa %d\n' % i for i in range(60)))"
o14="$(bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-agir.txt")"
[ "$(wc -c <<<"$o14")" -lt $(( $(wc -c < "$T/oz-agir.txt") / 3 )) ] && grep -qx '  ✗ kirmizi-kapi' <<<"$o14" && grep -qx '── SONUÇ: 30 geçti · 1 kaldı ──' <<<"$o14"; g $? "O14 🔴 az satırlı çok baytlı ölçüm kısalır ($(wc -c < "$T/oz-agir.txt") → $(wc -c <<<"$o14") bayt); ✗ ve SONUÇ satırı kalır"
grep -q 'tam metin kanıt dizininde: oz-agir.txt' <<<"$o14" && grep -q 'uzun satır 200 karakterde kesildi' <<<"$o14"; g $? "O15 kesilen ölçümde 'tam metin kanıt dizininde: <dosya>' notu ve kesilen satır sayısı göze söylenir"
python3 -c "open('$T/oz-stderr.txt','w').write(''.join('s %d\n' % i for i in range(70)) + '--- stderr ---\n' + 'E' * 6000 + '\nson-stderr\n')"
o17="$(bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-stderr.txt")"
[ "$(awk '{ if (length($0) > m) m = length($0) } END { print m }' <<<"$o17")" -lt 400 ] && grep -qx 'son-stderr' <<<"$o17" && grep -q 'uzun satır 200 karakterde kesildi' <<<"$o17"; g $? "O17 stderr'deki uzun satır da 200 karaktere kesilir (6000 karakterlik tek stderr satırı istemi şişirmez), sondaki satır korunur"
bash -c "$OZ"$'\n''olcum_ozeti "$1"' _ "$T/oz-hafif60.txt" > "$T/oz-hafif60.out"; cmp -s "$T/oz-hafif60.txt" "$T/oz-hafif60.out"; g $? "O16 60 satır ve 3 KB altı ölçüm bayt bayt AYNEN (kısalma yalnız ağır kayıtta)"
T="$_T_ONCE"; export KANIT_DEPO="$T" DENETCI_KOMUT="$_DK_ONCE"
fi   # IC_BOLUM=zil atlaması sonu
if [ "${IC_BOLUM:-}" != zil ]; then
echo "════ T-MUT · mutasyon kaydı göze 'beklenen kırmızı' diye gider (FR7M76 · #1136 tur 3) ════"
kartac is-mutk; bash "$K" olcum is-mutk gercek --asama tek -- bash -c 'echo "  ✓ K5 kilit tutuyor"; exit 0' >/dev/null 2>&1
bash "$K" olcum is-mutk mut-k5 --asama tek --mutasyon gercek -- bash -c 'echo "  ✗ K5 kilit tutuyor"; exit 1' >/dev/null 2>&1
printf 'diff --git a/x b/x\n+mut\n' > "$T/mut.patch"   # ortak d.patch ve sahte.sh önceki bölümlerde silinir → kendi patch'i ve sahtesi
MS="$T/mut-sahte.sh"; printf '#!/usr/bin/env bash\ncp "$1" "%s"; printf "%%s" "$SAHTE_JSON"\n' "$T/istem-mut.md" > "$MS"; chmod +x "$MS"
SAHTE_JSON="$(J 5 E "")" DENETCI_KOMUT="$MS" bash "$D" is-mutk --diff "$T/mut.patch" >/dev/null 2>&1
grep -qx -- "--- olcum-mut-k5-tek.txt · 🧬 MUTASYON KANITI (kod bilerek bozuldu; ✗ satırları BEKLENEN, bulgu değil) ---" "$T/istem-mut.md" && grep -qx -- "--- olcum-gercek-tek.txt ---" "$T/istem-mut.md"; g $? "M1 istemde mutasyon ölçümünün başlığı MUTASYON KANITI der, gerçek ölçümünki demez"
grep -q '^=== MUTASYON KANITI: kod BİLEREK bozuldu' "$T/istem-mut.md" && grep -q '"MUTASYON KANITI" başlıklı ölçüm' "$T/istem-mut.md"; g $? "M2 dosya başı satırı ve şablon kuralı istemde (✗ satırları bulgu değildir)"
fi
# zil dışı mutantların iç koşumu T-ZIL'i atlar (onlar T-ZIL'den önce de ölüyordu; iç koşum 50 → 39 sn) — yalnız zil mutantları ve dış koşum girer
if [ -z "${IC_KOSUM:-}" ] || [ "${IC_BOLUM:-}" = zil ]; then
echo "════ T-ZIL · denetçi sessiz bitmez: koşuyor izi · zaman aşımı · her çıkışta zil · tıkanınca reise (SERDAR ACİL 21 Eki) ════"
ZL="$T/zil.log"; ZS="$T/sahte-zil.sh"; printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nprintf "tmux=%%s pane=%%s\\n" "${TMUX:-yok}" "${TMUX_PANE:-yok}" >> "%s"\nprintf "kimden=%%s\\n" "${AILE_KIMDEN:-yok}" >> "%s"\n[ -n "${SAHTE_ZIL_ERR:-}" ] && printf "%%s\\n" "$SAHTE_ZIL_ERR" >&2\nexit "${SAHTE_ZIL_RC:-0}"\n' "$ZL" "$ZL" "$ZL" > "$ZS"; chmod +x "$ZS"
printf "diff --git a/x b/x\n+zil\n" > "$T/zd.patch"; ZK="$T/zil-sahte.sh"; printf '#!/usr/bin/env bash\nprintf "%%s" "$SAHTE_JSON"\n' > "$ZK"; chmod +x "$ZK"; _DK_ZIL="$DENETCI_KOMUT"; export DENETCI_KOMUT="$ZK";   # önceki bölümler ortak sahteyi silebiliyor — bu bölüm kendi sahtesiyle
 kartac is-z; bash "$K" olcum is-z olc --asama tek -- true >/dev/null 2>&1
DZZ="$T/_agents/fabrika/kanit/is-z"
# Z1 koşuyor izi: denetçi KOŞARKEN izi görür, bitince iz yok
ZD="$T/zil-denetci.sh"; printf '#!/usr/bin/env bash\nls "%s" > "%s"; cat "%s"/DENETIM-*.kosuyor > "%s" 2>/dev/null; printf "%%s" "$SAHTE_JSON"\n' "$DZZ" "$T/z-ls" "$DZZ" "$T/z-izi" > "$ZD"; chmod +x "$ZD"
: > "$ZL"; SAHTE_JSON="$(J 3 H "$B")" DENETCI_KOMUT="$ZD" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-z --diff "$T/zd.patch" >/dev/null 2>&1; RC=$?
grep -qx 'DENETIM-1.kosuyor' "$T/z-ls" && grep -q "^pid=[0-9]" "$T/z-izi" && grep -q "^baslangic=20" "$T/z-izi"; g $? "Z1a koşarken DENETIM-1.kosuyor izi var (pid + başlangıç)"
! ls "$DZZ"/DENETIM-*.kosuyor >/dev/null 2>&1; g $? "Z1b bitince iz silindi"
# Z3 her çıkışta zil: rc 1 (3/H) · rc 0 (5/E) · rc 2 (kanıt yok) · rc 1 (kullanım: iş adı yok)
[ $RC -eq 1 ] && grep -q -- "MUAVIN denetçi: is-z tur 1: 3/H · bulgu 1 · rc 1" "$ZL"; g $? "Z3a rc 1 → yazana zil (puan · bulgu · rc; yazan = kartın aldı'sı)"
: > "$ZL"; SAHTE_JSON="$(J 5 E "")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-z --diff "$T/zd.patch" >/dev/null 2>&1
grep -q -- "MUAVIN denetçi: is-z tur 2: 5/E · bulgu 0 · rc 0 · GEÇTİ" "$ZL" && ! grep -q -- "--waiting" "$ZL"; g $? "Z3b rc 0 → yazana zil, reise yok"
: > "$ZL"; SAHTE_JSON="$(J 5 E "")" FABRIKA_AILE_NOTIFY="$ZS" AGENT_NAME=HENDESE bash "$D" is-yok --diff "$T/zd.patch" >/dev/null 2>&1
grep -q -- "HENDESE denetçi: is-yok: denetim açılmadı (tur yok) · rc 2" "$ZL" && ! grep -q -- "tur ?: —/—" "$ZL"; g $? "Z3c rc 2 (kanıt yok, DENETIM yazılmadı) → yine zil; AGENT_NAME yazandır; '? tur ?: —/—' dolgusu YOK (0C915N)"
: > "$ZL"; FABRIKA_AILE_NOTIFY="$ZS" bash "$D" >/dev/null 2>"$T/z3d-err"; [ ! -s "$ZL" ]; g $? "Z3d iş adı yokken (en erken çıkış) reise zil ÇALMAZ: bilgi taşımayan '? tur ?' zili yok (0C915N)"
grep -q "denetçi zili atlandı: iş adı verilmedi" "$T/z3d-err"; g $? "Z3d2 atlama sessiz değil: sebep stderr'e yazıldı"
# Z3f (0C915N göz tur 1): iş adı var, tur YOK ve yazan bilinmiyor → zil reise giderdi, bilgi taşımazdı: atlanır, sebep stderr'e
: > "$ZL"; env -u AGENT_NAME KART_DEPO="$T/kartsiz-depo" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-yok-z3f >/dev/null 2>"$T/z3f-err"
[ ! -s "$ZL" ] && grep -q "tur çözülemedi ve yazan bilinmiyor" "$T/z3f-err"; g $? "Z3f tur yok + yazan yok: reise bilgisiz zil ÇALMAZ, sebep stderr'e yazıldı"
# M-Z3d / M-Z3f mutantları: iş-adı korkuluğu ya da tur-yok+yazan-yok korkuluğu kalkarsa bilgisiz zil geri gelir (Z3d/Z3f bunu yakalar)
_mz() { local DM; DM="$(dirname "$D")/.denetci-mz.sh"; python3 -I -c "
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3], sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)" "$D" "$DM" "$1" "$2" || return 9
  : > "$ZL"; env "${@:3}" FABRIKA_AILE_NOTIFY="$ZS" bash "$DM" $MZ_ARG >/dev/null 2>&1; rm -f "$DM"; [ -s "$ZL" ]; }
MZ_ARG=""; _mz 'if [ -z "${IS:-}" ]; then printf' 'if false; then printf' AGENT_NAME=HENDESE; g $? "M-Z3d iş-adı korkuluğu kalkarsa bilgisiz zil çalar (Z3d bunu yakalar; mutant yakalandı)"
MZ_ARG="is-yok-z3f"; _mz 'if [ -z "${TUR:-}" ] && [ "$yazansiz" = 1 ]; then printf' 'if false; then printf' -u AGENT_NAME KART_DEPO="$T/kartsiz-depo"; g $? "M-Z3f tur-yok+yazan-yok korkuluğu kalkarsa reise bilgisiz zil çalar (Z3f bunu yakalar; mutant yakalandı)"; MZ_ARG=""
kartac is-zb; bash "$K" olcum is-zb olc --asama tek -- true >/dev/null 2>&1
: > "$ZL"; SAHTE_JSON="$(J 5 E "")" FABRIKA_AILE_NOTIFY= bash "$D" is-zb --diff "$T/zd.patch" > /dev/null 2> "$T/z-err"; [ ! -s "$ZL" ] && grep -q "sınav kipi" "$T/z-err"; g $? "Z3e sınav kipinde (DENETCI_KOMUT) gerçek zil ARANMAZ; söylenir"
# Z2 zaman aşımı: rc 3 · HAM'da ZAMAN AŞIMI · beklemeden biter · zil + reis (kendi işi: önceki turlar tavanı doldurmasın)
kartac is-za; bash "$K" olcum is-za olc --asama tek -- true >/dev/null 2>&1; DZA="$T/_agents/fabrika/kanit/is-za"
ZY="$T/yavas.sh"; printf '#!/usr/bin/env bash\nsleep 8; printf "%%s" "$SAHTE_JSON"\n' > "$ZY"; chmod +x "$ZY"
: > "$ZL"; bas=$(date +%s); SAHTE_JSON="$(J 5 E "")" DENETCI_KOMUT="$ZY" DENETCI_ZAMAN_ASIMI=1 FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-za --diff "$T/zd.patch" >/dev/null 2>&1; RC=$?; sure=$(( $(date +%s) - bas ))
[ $RC -eq 3 ] && [ "$sure" -lt 6 ]; g $? "Z2a zaman aşımı → rc 3, beklemedi (${sure} sn < 6)"
grep -q "ZAMAN AŞIMI" "$DZA/DENETIM-1-HAM.txt" 2>/dev/null; g $? "Z2b DENETIM-1-HAM.txt'e ZAMAN AŞIMI yazıldı"
grep -q -- "MUAVIN denetçi: is-za tur 1: —/— · bulgu — · rc 3 · ZAMAN AŞIMI" "$ZL" && grep -q -- "--waiting --amir SERDAR" "$ZL"; g $? "Z2c aşımda yazana zil + reise --waiting (kart istedi=SULTAN → SERDAR)"
! ls "$DZA"/DENETIM-*.kosuyor >/dev/null 2>&1; g $? "Z2d aşımda da koşuyor izi silindi"
# Z4 tıkanınca (rc 4) reise: sahibi yazandan farklı kartta reis kartın istedi'sidir
bash "$KT" ac is-t --is x --istedi BANI --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; bash "$K" olcum is-t olc --asama tek -- true >/dev/null 2>&1
for i in 1 2 3; do : > "$ZL"; SAHTE_JSON="$(J 2 H "$B")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-t --diff "$T/zd.patch" >/dev/null 2>&1; RC=$?; done
[ $RC -eq 4 ] && grep -q -- "rc 4 · TIKANDI" "$ZL" && grep -q -- "--waiting --amir BANI denetçi (MUAVIN): is-t tur 3" "$ZL"; g $? "Z4 rc 4 (tıkandı) → yazana zil + kart sahibine (istedi=BANI) --waiting"
: > "$ZL"; SAHTE_JSON="$(J 3 H "$B")" FABRIKA_AILE_NOTIFY="$T/olmayan-zil.sh" bash "$D" is-zb --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"; [ $? -eq 1 ] && grep -q "zili ATLANDI" "$T/z-err"; g $? "Z5 zil aracı yoksa iş durmaz (rc korunur) ama stderr'e yazılır"
# göz tur 1 (#404) — Z6 TERM'i yutan denetçi de kesilir (-k) · Z7 geçersiz süre varsayılana döner · Z8 bayat iz silinir · Z9 canlı iz korunur
kartac is-zk; bash "$K" olcum is-zk olc --asama tek -- true >/dev/null 2>&1
ZI="$T/inatci.sh"; printf '#!/usr/bin/env bash\ntrap "" TERM; sleep 8; printf "%%s" "$SAHTE_JSON"\n' > "$ZI"; chmod +x "$ZI"
bas=$(date +%s); SAHTE_JSON="$(J 5 E "")" DENETCI_KOMUT="$ZI" DENETCI_ZAMAN_ASIMI=1 DENETCI_ZAMAN_ASIMI_K=1 bash "$D" is-zk --diff "$T/zd.patch" >/dev/null 2>&1; RC=$?; sure=$(( $(date +%s) - bas ))
[ $RC -eq 3 ] && [ "$sure" -lt 6 ] && grep -q "ZAMAN AŞIMI" "$T/_agents/fabrika/kanit/is-zk/DENETIM-1-HAM.txt" 2>/dev/null; g $? "Z6 TERM'i yutan denetçi KILL ile kesilir → rc 3 + ZAMAN AŞIMI (${sure} sn < 6)"
kartac is-zv; bash "$K" olcum is-zv olc --asama tek -- true >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B")" DENETCI_ZAMAN_ASIMI=abc bash "$D" is-zv --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"; RC=$?
[ $RC -eq 1 ] && grep -q "DENETCI_ZAMAN_ASIMI=abc geçersiz" "$T/z-err"; g $? "Z7 geçersiz DENETCI_ZAMAN_ASIMI → söylenir, 900'e döner, denetim koşar (rc 1, 125 değil)"
kartac is-zs; bash "$K" olcum is-zs olc --asama tek -- true >/dev/null 2>&1; DZS="$T/_agents/fabrika/kanit/is-zs"
( exit 0 ) & olu=$!; wait "$olu"; printf 'pid=%s\nbaslangic=2026-01-01T00:00:00\n' "$olu" > "$DZS/DENETIM-1.kosuyor"
SAHTE_JSON="$(J 3 H "$B")" bash "$D" is-zs --diff "$T/zd.patch" >"$T/z-out" 2>&1; RC=$?
[ $RC -eq 1 ] && grep -q "bayat koşuyor izi silindi" "$T/z-out" && ! ls "$DZS"/DENETIM-*.kosuyor >/dev/null 2>&1; g $? "Z8 ölü pid'li (SIGKILL artığı) iz bayat sayılır: söylenir, silinir, denetim koşar"
kartac is-zc; bash "$K" olcum is-zc olc --asama tek -- true >/dev/null 2>&1; DZC="$T/_agents/fabrika/kanit/is-zc"
sleep 30 & canli=$!; printf 'pid=%s\npid_kimlik=%s\nbaslangic=2026-01-01T00:00:00\n' "$canli" "$(ps -o lstart= -p "$canli" | sed 's/^ *//')" > "$DZC/DENETIM-1.kosuyor"
SAHTE_JSON="$(J 5 E "")" bash "$D" is-zc --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"; RC=$?
[ $RC -eq 3 ] && grep -q "başka denetçi koşuyor" "$T/z-err" && grep -q "pid=$canli" "$DZC/DENETIM-1.kosuyor" && ! ls "$DZC"/DENETIM-*.json >/dev/null 2>&1; g $? "Z9 aynı işte canlı denetçi varken ikincisi rc 3 ile durur, öbürünün izine dokunmaz"
# Z9b (28 Eki, bugün 5 kez rc 3): reddedilen ikinci koşum 'ÖLÇÜLEMEDİ' zili ÇALMAZ (yazana da reise de) — öteki koşum kendi zilini çalar
: > "$ZL"; SAHTE_JSON="$(J 5 E "")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zc --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"; RC=$?
[ $RC -eq 3 ] && [ ! -s "$ZL" ] && grep -q "denetçi zili çalınmadı: başka koşum sürüyor" "$T/z-err"; g $? "Z9b kilit reddi rc 3 verir ama zil ÇALMAZ (yazana ve reise), sebep stderr'de"
# Z12: gerçek ölçülemedi zili sebebi taşır (yalnız 'ÖLÇÜLEMEDİ' teşhis değildi)
: > "$ZL"; SAHTE_JSON="$(J 5 E "")" DENETCI_KOMUT="$ZY" DENETCI_ZAMAN_ASIMI=1 FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-za --diff "$T/zd.patch" >/dev/null 2>&1; RC=$?
[ $RC -eq 3 ] && grep -q -- "rc 3 · ZAMAN AŞIMI.* · sebep: .*ZAMAN AŞIMI" "$ZL"; g $? "Z9c rc 3 zili sebep satırını taşır (· sebep: …)"
kartac is-zr; bash "$K" olcum is-zr olc --asama tek -- true >/dev/null 2>&1; DZR="$T/_agents/fabrika/kanit/is-zr"
printf 'pid=%s\npid_kimlik=Thu Jan  1 00:00:00 2026\nbaslangic=2026-01-01T00:00:00\n' "$canli" > "$DZR/DENETIM-1.kosuyor"
SAHTE_JSON="$(J 3 H "$B")" bash "$D" is-zr --diff "$T/zd.patch" >"$T/z-out" 2>&1; RC=$?
[ $RC -eq 1 ] && grep -q "başka sürece geçmiş" "$T/z-out" && ! ls "$DZR"/DENETIM-*.kosuyor >/dev/null 2>&1; g $? "Z11 pid canlı ama başka sürece verilmiş (başlangıç anı tutmuyor) → bayat sayılır, denetim koşar"
kill "$canli" 2>/dev/null; wait "$canli" 2>/dev/null
: > "$ZL"; SAHTE_JSON="$(J 3 H "$B")" TMUX=/tmp/tmux-1000/default,1,0 TMUX_PANE=%9 FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zv --diff "$T/zd.patch" >/dev/null 2>&1
grep -q -- "^MUAVIN denetçi:" "$ZL" && grep -qx "tmux=yok pane=yok" "$ZL" && ! grep -q "pane=%9" "$ZL"; g $? "Z10 yazanın zili TMUX kimliği soyularak çağrılır (kendi penceresine giden zil self-loop'ta atlanmaz — HEZARFEN ölçümü)"
# Z13 (B843Q, 22 Eki): yazana DÜZ PING — gönderen adı yok (Nexus #1235 'alıcı = gönderen kuyruğa girmez' korumasında meşgul
#     yazanın zili düşüyordu), '--done' yok (sahte 'YAZAN iş-bitti' kaydı); ping meşgulde rc 1 döner → 'kuyrukta' KUYRUK satırından
kartac is-zg; bash "$K" olcum is-zg olc --asama tek -- true >/dev/null 2>&1
: > "$ZL"; SAHTE_JSON="$(J 3 H "$B")" AGENT_NAME=HENDESE FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zg --diff "$T/zd.patch" >/dev/null 2>&1
grep -A2 -- "^HENDESE denetçi:" "$ZL" | grep -qx "kimden=yok"; g $? "Z13a yazanın zili gönderen adı TAŞIMAZ (kuyrukta 'kendine' sayılıp düşmesin)"
: > "$ZL"; SAHTE_JSON="$(J 3 H "$B")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zg --diff "$T/zd.patch" >/dev/null 2>&1
grep -A2 -- "^MUAVIN denetçi:" "$ZL" | grep -qx "kimden=yok" && ! grep -q -- "--done" "$ZL"; g $? "Z13b yazana --done (sahte iş-bitti) gitmez; düz ping kartın aldı'sına (MUAVIN)"
: > "$ZL"; mkdir -p "$T/kartsiz-depo"; SAHTE_JSON="$(J 3 H "$B")" KART_DEPO="$T/kartsiz-depo" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zg --diff "$T/zd.patch" >/dev/null 2>&1; grep -A2 -- "^SERDAR denetçi:" "$ZL" | grep -qx "kimden=yok"; g $? "Z13c yazan bilinmiyorsa AILE_KIMDEN verilmez (reisin adı gönderen gibi görünmesin)"
bas_kuyruk="KUYRUK: MUAVIN koltuğu boşalınca teslim edilecek (aile-notify --bosalt · ömür 6 sa)"
: > "$ZL"; SAHTE_ZIL_RC=1 SAHTE_ZIL_ERR="$bas_kuyruk" SAHTE_JSON="$(J 3 H "$B")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zg --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"
grep -q "deftere yazıldı, MUAVIN koltuğu meşgul → kuyrukta" "$T/z-err" && ! grep -q "gönderilemedi" "$T/z-err"; g $? "Z13d ping meşgulde rc 1 + KUYRUK satırı → 'kuyrukta' denir, 'gönderilemedi' denmez"
: > "$ZL"; SAHTE_ZIL_RC=1 SAHTE_ZIL_ERR="KUYRUK: alıcı gönderenin kendisi (MUAVIN) — kuyruğa alınmadı (izi deftere: kendine)" SAHTE_JSON="$(J 3 H "$B")" FABRIKA_AILE_NOTIFY="$ZS" bash "$D" is-zg --diff "$T/zd.patch" >/dev/null 2>"$T/z-err"
grep -q "gönderilemedi" "$T/z-err" && ! grep -q "→ kuyrukta" "$T/z-err"; g $? "Z13e kuyruğa ALINMAYAN zil (kendine) 'kuyrukta' sayılmaz — düştüğü söylenir"
[ ! -s "$ZB/sizinti.log" ]; g $? "Z12 sızıntı kilidi: T-ZIL boyunca hiçbir çağrı varsayılan zil aracına düşmedi (gerçek koltuğa yol yok)"
export DENETCI_KOMUT="$_DK_ZIL"
fi   # T-ZIL sonu

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
MUT_ADLAR=(); MUT_DOSYALAR=(); MUT_BOLUMLER=(); MUT_RC_DIZ="$(mktemp -d)"; TEMIZ+=("$MUT_RC_DIZ")
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
  chmod +x "$M"; MUT_ADLAR+=("$1"); MUT_DOSYALAR+=("$M"); MUT_BOLUMLER+=("${MUT_BOLUM:-}")
}
mut_kos() { # sıradaki mutantları en çok MUT_PARALEL koşumla birlikte koşturur; raporu kayıt sırasıyla basar
  local i=0 n=${#MUT_ADLAR[@]} basladi=$(date +%s)
  while [ "$i" -lt "$n" ]; do
    local j=0
    while [ "$j" -lt "$MUT_PARALEL" ] && [ "$i" -lt "$n" ]; do
      ( IC_KOSUM=1 IC_BOLUM="${MUT_BOLUMLER[$i]}" MUTANT_D="${MUT_DOSYALAR[$i]}" bash "$0" >/dev/null 2>&1; echo $? > "$MUT_RC_DIZ/${MUT_ADLAR[$i]}.rc" ) &
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
mut "reis-sinifli-isaret-kontrolunu-kaldir" 's@^if SINIFLI and x.get("sinifli") is not True: raise SystemExit(1)@pass@'
# 🔴 ÇAPA TAZELENDİ (görev WC3VBZAA): mutlak tavan artık HAM tura değil SAYILI tura bakıyor
# (bulgularının hepsi kutu-dışı olan tur tavandan düşmez). Eski çapa `$TUR -gt $MUTLAK` idi ve
# değişiklikten sonra hiçbir şey eşleşmiyordu — süitin "çapa bayatlamış" bekçisi bunu yakaladı.
mut "mutlak-tavani-kaldir" 's@^if \[ "$SAYILI" -ge "$MUTLAK" \]; then@if false; then@'
mut "yedek-gozu-kaldir" 's@if yedek_olur_mu; then YEDEK="codex yok";@if false; then YEDEK="codex yok";@'
mut "kart-tek-kaynagi-kaldir" 's@^\[ -n "$KART_DEPO" \] || KART_DEPO="$DEPO"@KART_DEPO="$DEPO"@'
mut "codex-stdin-acik" 's@"$TMP/istem.md")" </dev/null >"$TMP/log"@"$TMP/istem.md")" >"$TMP/log"@'
mut "kart-yolu-harici-kalir" 's@then KART="$BIRINCIL"; _bilgi@then _bilgi@'
mut "kart-secenegi-tek-kaynagi-asar" 's@&& ! cmp -s "$KART" "$BIRINCIL"; then@\&\& false; then@'
mut "kapi-kart-hatasini-bastirir" 's@KARTYOL="$(kart_yolu)" || exit 3;@KARTYOL="$(kart_yolu 2>/dev/null)";@'
mut "bayat-kopya-geri-donusu" 's@OKUNMAZ — kart.sh ile birincile yaz, sonra denetçiyi koştur"; return 3@"; printf "%s" "$DEPO/_agents/fabrika/kartlar/$IS.json"@'
mut "kart-json-hatasi-yutulur" 's@denetim açılmaz"; exit 3; }@denetim açılmaz"; true; }@'
mut "gecersiz-goze-soylenmez" 's@\[ "\$NGEC" -gt 0 \] && KANIT_DURUM=@false \&\& KANIT_DURUM=@'
# T-ISTEM mutantları (BÂNİ 21:59): her biri istem kapısının bir parçasını söker
mut "istem-yerine-fark-olculur" 's@^if \[ "$ISTEM_BAYT" -gt "$BOL_SINIR" \]; then@if [ "$(wc -c < "$TMP/diff.patch")" -gt "$KIRP_ESIK" ]; then@'
mut "istem-bol-tur-yakar" 's@^  exit 1   # İŞİ BÖL@  :@'
mut "istem-en-buyuk-ilk-parca" 's@\[ "$_b" -gt "$_EN_B" \] && {@[ -z "$_EN" ] \&\& {@'
mut "istem-parca-dokumu-yok" 's@_DOKUM="$_DOKUM · ${_AD\[$_p\]} $_b"@:@'
mut "istem-karti-dusurur" 's@^ISTEM_PARCALARI=(sablon kart kanit@ISTEM_PARCALARI=(sablon kanit@'
mut "tavan-ayiklamaya-bagli" 's@^if \[ "$ISTEM_BAYT" -gt "$BOL_SINIR" \]; then@if [ "${DENETCI_KANIT_AYIKLA:-1}" != "0" ] \&\& [ "$ISTEM_BAYT" -gt "$BOL_SINIR" ]; then@'
mut "mutasyon-basligi-yok" 's@head -1 "$f" | grep -q .^=== MUTASYON KANITI. \&\& _mt=@false \&\& _mt=@'
MUT_BOLUM=zil   # aşağıdaki 18 zil mutantı yalnız T-ZIL'le ölçülür (iç koşum IC_BOLUM=zil)
mut "zil-tmux-soyulmaz" 's@env -u TMUX -u TMUX_PANE bash "$an" "$yazan"@env bash "$an" "$yazan"@'
mut "pid-kimligi-bakilmaz" 's@ \&\& { \[ -z "$_kim_iz" \] || \[ "$_kim_iz" = "$(_pid_kimlik "$_pid")" \]; }; then@; then@'
mut "yazansiz-zil-hedefsiz" 's@^  if \[ -z "$yazan" \]; then yazansiz=1; yazan="$reis";@  if false; then :;@'
mut "zil-kimden-geri" 's@env -u TMUX -u TMUX_PANE bash "$an" "$yazan"@env -u TMUX -u TMUX_PANE AILE_KIMDEN="$yazan" bash "$an" "$yazan"@'
mut "zil-done-geri" 's@bash "$an" "$yazan" "denetçi: $m"@bash "$an" --done --amir "$yazan" "denetçi: $m"@'
mut "zil-kuyruk-okunmaz" 's@ \&\& r=3$@@'
mut "kuyruk-hata-sanilir" 's@^  case "$1" in 0) ;; 3) printf@  case "$1" in 0) ;; 33) printf@'
mut "zil-yok" 's@^  _zil "$rc"$@  :@'
mut "reis-zili-yok" 's@^  if { \[ "$rc" = 3 \] || \[ "$rc" = 4 \]; } \&\& \[ "$yazansiz" = 0 \]; then@  if false; then@'
mut "zaman-asimi-yok" 's@_sinirli $DENETCI_KOMUT@$DENETCI_KOMUT@'
mut "kill-yok" 's@timeout -k "$ZA_K" "$ZA"@timeout "$ZA"@'
mut "asim-137-cevrilmez" 's@ \&\& r=124$@@'
mut "sure-dogrulanmaz" 's@ZA=900 ;; esac@: ;; esac@'
mut "bayat-iz-silinmez" 's@; rm -f "$_iz"$@@'
mut "canli-iz-ezilir" '/başka denetçi koşuyor/s@; exit 3$@@'
mut "kilit-red-zil-calar" 's@KILIT_RED=1; exit 3@exit 3@'
mut "sebep-zile-girmez" 's@^  case "$rc" in 2|3|4) \[ -n "$SON_HATA" \]@  case "$rc" in 9) [ -n "$SON_HATA" ]@'
mut "asim-ham-yazilmaz" 's@^if \[ "$DRC" -eq 124 \]; then$@if false; then@'
mut "kosuyor-silinmez" 's@^  \[ -n "$KOSUYOR" \] \&\& rm -f "$KOSUYOR"$@  :@'
mut "kosuyor-yazilmaz" 's@^KOSUYOR="$DZ/DENETIM-$TUR.kosuyor"$@KOSUYOR=""@'
mut "sinav-kipi-gercek-zil" 's@^  if \[ -z "$an" \] \&\& { \[ -n "${DENETCI_KOMUT:-}" \] || \[ -n "${SAHTE_JSON:-}" \] || \[ -n "${SAHTE_ISTEM_KOPYA:-}" \]; }; then@  if false; then@'
MUT_BOLUM=
mut "olcum-sonu-yok" 's@olcum_ozeti "$f"; \[ -z@head -60 "$f"; [ -z@'
mut "olcum-stderr-ayrilmaz" 's@^e = L.index("--- stderr ---") if "--- stderr ---" in L else len(L)$@e = len(L)@'
mut "olcum-tavan-asilir" 's@^SINIR, BAS, SON, HSON, SECME, BAYT_ESIK, SATIR_GEN = 60, 20, 20, 10, 10, 3000, 200$@SINIR, BAS, SON, HSON, SECME, BAYT_ESIK, SATIR_GEN = 60, 300, 300, 10, 10, 3000, 200@'
mut "olcum-atlanan-sayisiz" 's@^    not_ = "\[… %d satır atlandı (dosya %d satır) — ölçümün SONU aşağıda; tam metin kanıt dizininde: %s …\]" % (atlanan, len(L), AD)$@    not_ = "[…]"@'
mut "olcum-bayt-kapisi-yok" 's@^if len(L) <= SINIR and len(HAM.encode("utf-8")) <= BAYT_ESIK: sys.stdout.write(HAM); sys.exit()@if len(L) <= SINIR: sys.stdout.write(HAM); sys.exit()@'
mut "olcum-stderr-satiri-kesilmez" 's@^err = \[x if x.startswith(("\[…", "--- stderr")) else kis(x) for x in err\].*$@err = err@'
mut "olcum-uzun-satir-kesilmez" 's@^    if len(x) <= SATIR_GEN: return x$@    return x@'
mut "olcum-ortadan-secmez" 's@^    orta = cik\[BAS:-SON\]; sec = \[x for x in orta if any(k in x for k in SECILIR)\]$@    orta = cik[BAS:-SON]; sec = []@'
mut "olcum-secilen-de-sayilir" 's@^    atlanan = len(orta) - min(len(sec), SECME) .*$@    atlanan = len(orta)@'
mut "olcum-ayirici-eklenmez" 's@ \[ -z "$(tail -c1 "$f")" \] || echo; }; done@ }; done@'
mut_kos

# ── KANIT-AYIKLAMA KAPILARI (gorev_01M4ZSKHD1Y1FFT8P6Z5YMPTF9)
# Gövde AYRI dosyadadır (denetci-fark-ayikla.test.sh) çünkü bu dosya o sırada açık PR #327'nin
# elindeydi; 30 kapıyı buraya yazmak onun değişikliğini ezerdi. Ama "test yazmak onu koşturmaz":
# asıl sınav o dosyayı ÇAĞIRIR, böylece denetci.test.sh kırmızıysa ayıklama kapıları da kırmızıdır.
# #327 indikten sonra gövde buraya taşınır ve bu çağrı düşer.
echo ""; echo "── KANIT-AYIKLAMA (ayrı dosya, buradan çağrılır) ──"
if bash "$(dirname "$0")/denetci-fark-ayikla.test.sh"; then
  gecen=$((gecen+1)); echo "  ✓ kanıt-ayıklama kapıları (denetci-fark-ayikla.test.sh) GEÇTİ"
else
  kalan=$((kalan+1)); echo "  ✗ kanıt-ayıklama kapıları (denetci-fark-ayikla.test.sh) DÜŞTÜ"
fi

# ── KUTU-DIŞI SINIF KAPILARI (gorev WC3VBZAA)
# Gövde AYRI dosyadadır (denetci-kutu-disi.test.sh) çünkü bu dosya o sırada açık PR #331'in
# (--kare, 0.6.5) elindeydi. "Test yazmak onu koşturmaz": asıl sınav o dosyayı ÇAĞIRIR, böylece
# denetci.test.sh kırmızıysa kutu-dışı kapıları da kırmızıdır. #331 inince gövde buraya taşınır.
echo ""; echo "── KUTU-DIŞI SINIF (ayrı dosya, buradan çağrılır) ──"
if bash "$(dirname "$0")/denetci-kutu-disi.test.sh"; then
  gecen=$((gecen+1)); echo "  ✓ kutu-dışı sınıf kapıları (denetci-kutu-disi.test.sh) GEÇTİ"
else
  kalan=$((kalan+1)); echo "  ✗ kutu-dışı sınıf kapıları (denetci-kutu-disi.test.sh) DÜŞTÜ"
fi

# ── FARKI DENETÇİ KENDİSİ ALIR (gorev_01M54B2Y4QT7VWTJX10AFR7M76)
# Gövde AYRI dosyadadır (denetci-fark-kendisi.test.sh): kurulum origin'li iki klon ister, bu dosyanınki origin'siz tek depo.
echo ""; echo "── FARK-KENDİSİ (ayrı dosya, buradan çağrılır) ──"
if bash "$(dirname "$0")/denetci-fark-kendisi.test.sh"; then
  gecen=$((gecen+1)); echo "  ✓ fark-kendisi kapıları (denetci-fark-kendisi.test.sh) GEÇTİ"
else
  kalan=$((kalan+1)); echo "  ✗ fark-kendisi kapıları (denetci-fark-kendisi.test.sh) DÜŞTÜ"
fi


echo "════ T-DARALT · tıkanan iş kart.sh daralt ile yeni cümleyle sıfırdan sayılır (PCP7J) ════"
export KANIT_DEPO="$T"
mkdir -p "$T"; cd "$T" 2>/dev/null; printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n' > "$T/d.patch"   # önceki sınav farkı/dizini kaldırmış olabilir
bash "$HERE/kart.sh" ac is-dar --is "iki yarım iş tek kartta bu yüzden üç tur boyunca tıkandı" --istedi Sultan --aldi SERDAR --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; g $? "kart açıldı (sınıfsız)"
bash "$K" olcum is-dar olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-dar --diff "$T/d.patch" >/dev/null 2>&1; done
SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-dar --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "3 tur ilerlemeyince rc=4 (tıkandı)"
CIKTI="$(bash "$HERE/kart.sh" daralt is-dar --kalan "ikinci yarım iş: raporu da üretsin, bu kartta değil" --cumle "yalnız birinci yarım iş: ölçümü yazsın ve kaydetsin" --oturum ref-dar 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "daralt rc=0: $(head -n1 <<<"$CIKTI")"
python3 -c "import json;k=json.load(open('$T/_agents/fabrika/kartlar/is-dar.json'));d=k['daraltmalar'][-1];assert d['tur_sifir']==3 and d['kalan_kart']=='is-dar-kalan' and k['reis_kararlari'][-1]['karar']=='daralt' and k['cumle_gecmisi'][0]['cumle'].startswith('iki yarım') and k['cumle'].startswith('yalnız')"; g $? "karta daraltma kaydı (tur_sifir=3), reis kararı, cümle geçmişi yazıldı"
python3 -c "import json;y=json.load(open('$T/_agents/fabrika/kartlar/is-dar-kalan.json'));assert y['koken']=='is-dar' and y['aldi']=='SERDAR' and y['cumle'].startswith('ikinci') and y['sultan']==False"; g $? "kalan bulgu yeni kartta (aynı sahip, sınıfsız, köken yazılı)"
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-dar --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "daraltmadan sonraki ilk tur KOŞTU ve 5/E geçti (rc=0, tavan sıfırlandı)"; [ "$RC" -eq 0 ] || { echo "    ↳ rc=$RC"; tail -n 6 <<<"$CIKTI" | sed "s/^/    ↳ /"; }
grep -q "DARALTILMIŞ: ilk 3 tur" <<<"$CIKTI"; g $? "denetçi daraltmayı söyledi (ilk 3 tur sayılmıyor)"
[ -f "$T/_agents/fabrika/kanit/is-dar/DENETIM-4.json" ]; g $? "DENETIM-4 yazıldı (tur numarası sürdü, sayım sıfırlandı)"
# daraltmadan sonra da üç düşük tur → yine tıkanır (sıfırlama sınırsız tur değildir)
bash "$HERE/kart.sh" ac is-dar2 --is "daraltma sonrası da tıkanabilen iş cümlesi burada" --istedi Sultan --aldi SERDAR --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-dar2 olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-dar2 --diff "$T/d.patch" >/dev/null 2>&1; done
bash "$HERE/kart.sh" daralt is-dar2 --kalan "kalan yarı burada yirmi karakterden uzun" --cumle "daraltılmış cümle burada yirmi karakterden uzun" --oturum ref-dar2 >/dev/null 2>&1
for i in 1 2; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-dar2 --diff "$T/d.patch" >/dev/null 2>&1; done
SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-dar2 --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "daraltma sonrası 3 düşük tur → yine rc=4 (sıfırlama tavanı kaldırmaz)"
unset KANIT_DEPO; export KANIT_DEPO="$T"

echo "════ T-SULTAN · Sultan turu kaydı (kart.sh sultan-turu) göz tur sayımını sıfırlar; daralt gibi (beğeni döngüsü, 2BXA6J) ════"
bash "$HERE/kart.sh" ac is-stur --is "beğeni döngüsünde Sultan turları sonrası göz sayacı sıfırlanır" --istedi Sultan --aldi SERDAR --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; g $? "kart açıldı (sınıfsız)"
bash "$K" olcum is-stur olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-stur --diff "$T/d.patch" >/dev/null 2>&1; done
python3 - "$T/_agents/fabrika/kartlar/is-stur.json" <<'PYK'
import json,sys
k=json.load(open(sys.argv[1])); k["sultan_turlari"]=[{"zaman":"2026-10-26T10:00:00+03:00","tur":1,"tur_sifir":2,"gorev":"gorev_X","reis":"SERDAR","satir":'[tur 1] kare: k.png · Sultan: "başlık küçük"'}]
json.dump(k,open(sys.argv[1],"w"),ensure_ascii=False)
PYK
# Sultan turu YOKKEN üçüncü düşük tur tıkanırdı; kayıtlı olunca sayım 2'den sonra başlar: 3., 4., 5. tur koşar, altıncı (sıfırdan 4.) tıkanmadan önce ilerleme sorulur
for i in 3 4; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-stur --diff "$T/d.patch" >/dev/null 2>&1; RC=$?; [ "$RC" -ne 4 ]; g $? "Sultan turu sonrası $((i-2)). göz turu tıkanmaz (rc=$RC)"; done
CIKTI="$(SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-stur --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 4 ]; g $? "Sultan turundan sonra 3 düşük göz turu → yine rc=4 (sıfırlama tavanı kaldırmaz)"
grep -q "DARALTILMIŞ: ilk 2 tur" <<<"$CIKTI"; g $? "denetçi sıfırı söyledi (ilk 2 tur sayılmıyor)"
unset KANIT_DEPO; export KANIT_DEPO="$T"

echo "════ T-ONGOZ · DALGIÇ ön-göz gönder akışında kendiliğinden koşar, YALNIZ bilgidir (ZP640T) ════"
bash "$HERE/kart.sh" ac is-on --is "ön-göz sınavı için küçük bir iş cümlesi burada" --istedi Sultan --aldi SERDAR --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; g $? "kart açıldı (sınıfsız)"
bash "$K" olcum is-on olc --asama tek -- echo 1 >/dev/null 2>&1
for sonuc in 0 1 3; do printf '#!/usr/bin/env bash\necho "sahte dalgic rapor rc=%s"; exit %s\n' "$sonuc" "$sonuc" > "$T/dalgic-$sonuc.sh"; done
on() { DALGIC_KAPALI= DALGIC_BIN="$1" SAHTE_JSON="$(J 5 E "")" bash "$D" is-on --diff "$T/d.patch" 2>&1; }
CIKTI="$(on "$T/dalgic-0.sh")"; RC=$?; [ "$RC" -eq 0 ] && grep -q "ön-göz (DALGIÇ): UYUMLU" <<<"$CIKTI"; g $? "ön-göz UYUMLU: bilgi satırı basıldı, denetim aynen geçti (rc 0)"
grep -q '"dalgic": "uyumlu"' "$T/_agents/fabrika/kanit/is-on/DENETIM-1.json"; g $? "W42-E1: ön-göz UYUMLU → denetim kaydında dalgic=uyumlu"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(on "$T/dalgic-1.sh")"; RC=$?; [ "$RC" -eq 0 ] && grep -q "ÖN-GÖZ (DALGIÇ): UYUMSUZ" <<<"$CIKTI" && grep -q "sahte dalgic rapor rc=1" <<<"$CIKTI"; g $? "🔴 ön-göz UYUMSUZ: büyük uyarı + rapor basıldı AMA denetim sürdü ve geçti (rc 0; göz bağımsız kalır)"
grep -q '"dalgic": "uyumsuz"' "$T/_agents/fabrika/kanit/is-on/DENETIM-1.json"; g $? "W42-E1: ön-göz UYUMSUZ → denetim kaydında dalgic=uyumsuz (puan/rc değişmez, yukarıda rc 0)"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(on "$T/dalgic-3.sh")"; RC=$?; [ "$RC" -eq 0 ] && grep -q "ÖLÇÜLEMEDİ (rc=3) — UYUMLU sayılmaz" <<<"$CIKTI"; g $? "ön-göz ÖLÇÜLEMEDİ: UYUMLU sayılmaz uyarısı, denetim sürer (rc 0)"
grep -q '"dalgic": "olculemedi"' "$T/_agents/fabrika/kanit/is-on/DENETIM-1.json"; g $? "W42-E1: ön-göz ÖLÇÜLEMEDİ → denetim kaydında dalgic=olculemedi (uyumlu sayılmaz)"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(on "$T/yok-dalgic.sh")"; RC=$?; [ "$RC" -eq 0 ] && grep -q "dalgic.sh yok — ATLANDI" <<<"$CIKTI"; g $? "dalgic.sh yoksa 'ATLANDI' yazılır, denetim yine koşar (rc 0)"
grep -q '"dalgic": "atlandi"' "$T/_agents/fabrika/kanit/is-on/DENETIM-1.json"; g $? "W42-E1: dalgic.sh yok → dalgic=atlandi"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(DALGIC_KAPALI=1 DALGIC_BIN="$T/dalgic-1.sh" SAHTE_JSON="$(J 5 E "")" bash "$D" is-on --diff "$T/d.patch" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] && ! grep -q "ön-göz\|ÖN-GÖZ" <<<"$CIKTI"; g $? "DALGIC_KAPALI=1: ön-göz hiç koşmaz"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(on "$T/dalgic-0.sh")"; grep -q "sahte dalgic rapor rc=0" <<<"$CIKTI"; g $? "rapor her durumda ekrana yazılır (UYUMLU'da da)"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(on "$T/dalgic-3.sh")"; grep -q "sahte dalgic rapor rc=3" <<<"$CIKTI"; g $? "ÖLÇÜLEMEDİ'de de rapor (neden) görünür"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
printf '#!/usr/bin/env bash\nprintf "kacis:\\033[2J\\033]0;hile\\007 bitti\\n"; head -c 9000 /dev/zero | tr "\\0" "x"; exit 0\n' > "$T/dalgic-kirli.sh"
CIKTI="$(on "$T/dalgic-kirli.sh")"; ! grep -q $'\033' <<<"$CIKTI" && [ "$(grep -c . <<<"$CIKTI")" -lt 60 ] && [ "$(wc -c <<<"$CIKTI")" -lt 6500 ]; g $? "ön-göz çıktısında kontrol karakteri süzülür, çıktı 4000 bayta kırpılır"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
CIKTI="$(DALGIC_KAPALI=0 DALGIC_BIN="$T/dalgic-0.sh" SAHTE_JSON="$(J 5 E "")" bash "$D" is-on --diff "$T/d.patch" 2>&1)"; grep -q "ön-göz (DALGIÇ): UYUMLU" <<<"$CIKTI"; g $? "DALGIC_KAPALI=0 ön-gözü KAPATMAZ (yalnız =1 kapatır)"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
# 🔴 göz bağımsızlığı: ön-göz açıkken ve kapalıyken göze giden istem BAYT BAYT aynı olmalı
DALGIC_KAPALI=1 SAHTE_ISTEM_KOPYA="$T/istem-kapali.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-on --diff "$T/d.patch" >/dev/null 2>&1; rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
DALGIC_KAPALI= DALGIC_BIN="$T/dalgic-1.sh" SAHTE_ISTEM_KOPYA="$T/istem-acik.md" SAHTE_JSON="$(J 5 E "")" bash "$D" is-on --diff "$T/d.patch" >/dev/null 2>&1; rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json
[ -s "$T/istem-kapali.md" ] && cmp -s "$T/istem-kapali.md" "$T/istem-acik.md"; g $? "🔴 göze giden istem ön-göz açıkken ve kapalıyken BAYT BAYT aynı (ön-göz bağımsızlığı bozmaz)"
# MUTASYON: UYUMSUZ kolu kaldırılırsa uyarı kaybolur → yukarıdaki 🔴 kapı düşerdi
MO="$T/pkg-on"; mkdir -p "$MO"; cp "$HERE"/*.py "$HERE"/*.sh "$MO/" 2>/dev/null
python3 - "$MO/denetci.sh" <<'PYM'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='1) DALGIC_DURUM=uyumsuz; _bilgi ""; _bilgi "⚠⚠ ÖN-GÖZ'; assert s.count(a)==1; open(sys.argv[1],"w",encoding="utf-8").write(s.replace(a,'1) : ; _bilgi "ÖN-GÖZ-KAPALI',1))
PYM
CIKTI="$(DALGIC_KAPALI= DALGIC_BIN="$T/dalgic-1.sh" SAHTE_JSON="$(J 5 E "")" bash "$MO/denetci.sh" is-on --diff "$T/d.patch" 2>&1)"; ! grep -q "ÖN-GÖZ (DALGIÇ): UYUMSUZ" <<<"$CIKTI"; g $? "mutant (UYUMSUZ kolu söküldü): uyarı BASILMAZ → üstteki 🔴 kapı düşerdi"
rm -f "$T/_agents/fabrika/kanit/is-on/DENETIM-"*.json

echo "════ T-BOL · üretim farkı eşiği aşarsa denetçi 'İŞİ BÖL' der, tur yakmaz (PCP7J) ════"
bash "$K" olcum is-bol olc --asama tek -- echo 1 >/dev/null 2>&1
python3 - "$T/bol.patch" <<'PY'
import sys
p=sys.argv[1]
with open(p,"w") as f:
    f.write("diff --git a/x.ts b/x.ts\n--- a/x.ts\n+++ b/x.ts\n@@ -1 +1,400 @@\n")
    for i in range(400): f.write("+"+("k"*60)+f" {i}\n")
PY
CIKTI="$(SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=5000 bash "$D" is-bol --diff "$T/bol.patch" 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "fark 24 KB > eşik 5 KB → rc=1"
grep -q "İŞİ BÖL" <<<"$CIKTI" && grep -q "kart.sh daralt" <<<"$CIKTI"; g $? "'İŞİ BÖL' + daralt yolu yazılı"
[ ! -f "$T/_agents/fabrika/kanit/is-bol/DENETIM-1.json" ]; g $? "tur yakılmadı (DENETIM yok)"
SAHTE_JSON="$(J 5 E "")" DENETCI_KIRP_ESIK=50000 bash "$D" is-bol --diff "$T/bol.patch" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "eşik altındaki fark normal denetlenir (rc=0)"


echo "════ TP · BİRİNCİL KOPYADA DENETİM REDDİ (0.22.0 · gorev_01M5F03K79B5B19A2XQ54V8NMK): alan varken birincilden koşum kayıt bırakmaz ════"
# NİÇİN: denetçi DENETIM-N.json + KART.json'u çağrıldığı ağacın köküne yazar; iş alanı açıkken BİRİNCİL kopyadan `--pr N` ile koşulan son tur
#        orada takipsiz kalıyordu (HENDESE 22 Eki: Nexus 9 + cloudtop 13 işte). Alan = IS_ALANI_KOK/<depo-adı>-<iş>; birincil = git-dir == git-common-dir.
TP="$(mktemp -d)"; TEMIZ+=("$TP"); ( cd "$TP" && git init -q -b main && git -c user.email=t@t -c user.name=T commit -q --allow-empty -m "ilk" ) >/dev/null 2>&1
AKP="$TP/alanlar"; mkdir -p "$AKP"; WP="$AKP/$(basename "$TP")-is-p"; git -C "$TP" worktree add -q -b is-p "$WP" >/dev/null 2>&1; [ -d "$WP" ]; g $? "TP0 fikstür: birincil kopya + iş alanı"
( cd "$TP" && bash "$KT" ac is-p --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h ) >/dev/null 2>&1
IS_ALANI_KOK="$AKP" KANIT_DEPO="$WP" bash "$K" olcum is-p olc --asama tek -- echo 1 >/dev/null 2>&1
CIKTI="$(SAHTE_JSON="$(J 5 E "")" IS_ALANI_KOK="$AKP" KANIT_DEPO="$TP" bash "$D" is-p --diff "$T/d.patch" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && grep -q "BİRİNCİL kopyadasın" <<<"$CIKTI" && grep -q "$WP" <<<"$CIKTI"; g $? "TP1 birincilden, alan varken: rc 2 + 'BİRİNCİL kopyadasın' + alan yolu söylenir"
[ ! -e "$TP/_agents/fabrika/kanit/is-p/DENETIM-1.json" ] && [ ! -e "$TP/_agents/fabrika/kanit/is-p/KART.json" ]; g $? "TP1b birincile DENETIM / KART.json yazılmadı"
SAHTE_JSON="$(J 5 E "")" IS_ALANI_KOK="$AKP" KANIT_DEPO="$WP" bash "$D" is-p --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && python3 -c "import json;d=json.load(open('$WP/_agents/fabrika/kanit/is-p/DENETIM-1.json'));assert d['depo']=='$WP' and d['dal']=='is-p' and d['birincil_mi'] is False, d" 2>/dev/null; g $? "TP2 alandan koşum yazar (rc 0); DENETIM'de depo=alan, dal=is-p, birincil_mi=false"
( cd "$TP" && bash "$KT" ac is-q --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h ) >/dev/null 2>&1
IS_ALANI_KOK="$AKP" KANIT_DEPO="$TP" bash "$K" olcum is-q olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 5 E "")" IS_ALANI_KOK="$AKP" KANIT_DEPO="$TP" bash "$D" is-q --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && python3 -c "import json;d=json.load(open('$TP/_agents/fabrika/kanit/is-q/DENETIM-1.json'));assert d['birincil_mi'] is True and d['dal']=='main', d" 2>/dev/null; g $? "TP3 alanı OLMAYAN iş birincilden eskisi gibi denetlenir; DENETIM birincil_mi=true, dal=main"
# MUTASYON: betiğin bütün dizini kopyalanır (denetci.sh kardeşlerini \$HERE'den bulur), kopyada birincil tespiti sökülür → TP1 senaryosu birincile yazar
MPD="$TP/scripts"; cp -r "$HERE" "$MPD"; sed -i 's/^\[ -n "\$_gd" \] && \[ "\$_gd" = "\$_gc" \] && DENETCI_BIRINCIL=1$/DENETCI_BIRINCIL=0/' "$MPD/denetci.sh"; ! cmp -s "$MPD/denetci.sh" "$HERE/denetci.sh"; g $? "TP4 mutant üretildi (desen tuttu)"
# Mutantın yazabilmesi için birincilde de kanıt olmalı (denetçi kanıtı KANIT_DEPO'dan okur; kanıtsız rc 2 kapıdan ÖNCE düşer ve mutantı
#   yanlışlıkla "yakalanmış" gösterirdi — tur 1 ölçümü: TP4b eski araçta da yeni araçta da aynı sebeple kırmızıydı). Kanıt alan tespiti
#   kapalıyken (IS_ALANI_KOK boş dizin) birincile yazılır; sonra GERÇEK betik aynı kanıtla yine rc 2 vermeli (kapıyı kanıt değil tespit kapatıyor).
IS_ALANI_KOK="$TP/alan-yok" KANIT_DEPO="$TP" bash "$K" olcum is-p olc --asama tek -- echo 1 >/dev/null 2>&1; [ -f "$TP/_agents/fabrika/kanit/is-p/KANIT.json" ]; g $? "TP4a fikstür: birincilde de kanıt var (alan tespiti kapalıyken yazıldı)"
SAHTE_JSON="$(J 5 E "")" IS_ALANI_KOK="$AKP" KANIT_DEPO="$TP" bash "$D" is-p --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && [ ! -e "$TP/_agents/fabrika/kanit/is-p/DENETIM-1.json" ]; g $? "TP4c kanıt birincilde VARKEN gerçek betik yine rc 2, DENETIM yok (kapıyı kanıt değil birincil tespiti kapatıyor)"
SAHTE_JSON="$(J 5 E "")" IS_ALANI_KOK="$AKP" KANIT_DEPO="$TP" bash "$MPD/denetci.sh" is-p --diff "$T/d.patch" >/dev/null 2>&1; RC=$?
[ "$RC" -ne 2 ] && [ -f "$TP/_agents/fabrika/kanit/is-p/DENETIM-1.json" ]; g $? "TP4b MUTASYON: kapı sökülünce birincile DENETIM yazılır (kapı gerçekten kabloda)"
git -C "$TP" worktree remove --force "$WP" >/dev/null 2>&1; find "$TP" -mindepth 1 -delete 2>/dev/null; rmdir "$TP" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]   # (göz tur 2) rc kalan sayısına bağlı: kırmızı sınav yeşil çıkış kodu veremez
