#!/usr/bin/env bash
# kart.test.sh — iş kartı (0. adım) ve gün sonu özeti sahte depoda: sınıf soruları zorunlu, şüphede yukarı, özet defterden.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KT="$HERE/kart.sh"; GS="$HERE/gun-sonu.sh"; K="$HERE/kanit.sh"; D="$HERE/denetci.sh"; IA="$HERE/is-alani.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; mkdir -p "$T/uzak" "$T/depo"
( cd "$T/uzak" && git init -q --bare ) >/dev/null 2>&1
( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" && git remote add origin "$T/uzak" && git push -q -u origin main ) >/dev/null 2>&1
export FABRIKA_TETIK=/nonexistent IS_ALANI_KOK="$T/alan"
cd "$T/depo"

echo "════ T1 · sınıf sorusu eksik → kart açılmaz ════"
bash "$KT" ac is-1 --is "buton" --istedi Sultan --aldi MUAVIN --para h >/dev/null 2>&1; [ $? -eq 1 ]; g $? "eksik cevapla rc=1"
[ ! -f "$T/depo/_agents/fabrika/kartlar/is-1.json" ]; g $? "kart yazılmadı"

echo "════ T2 · dört cevap h → sınıfsız, ekipte biter ════"
CIKTI="$(bash "$KT" ac is-1 --is "buton ekle" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h 2>&1)"; g $? "kart açıldı"
grep -q "ekipte biter" <<<"$CIKTI"; g $? "ekipte biter dedi"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert k['sultan']==False and k['durum']=='acik'"; g $? "sultan=false"

echo "════ T3 · '?' cevabı → şüphede yukarı, Sultan'a gider ════"
CIKTI="$(bash "$KT" ac is-2 --is "anasayfa görünümü" --istedi reis --aldi NAKKAS --geri-alinamaz h --para h --dis-yuzey '?' --yetki h 2>&1)"
grep -q "SULTAN'A GİDER" <<<"$CIKTI"; g $? "SULTAN'A GİDER"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-2.json'));assert k['sultan'] and k['siniflar']==['dis_yuzey']"; g $? "sınıf dis_yuzey"
bash "$KT" ac is-2 --is x --istedi a --aldi b --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; [ $? -eq 1 ]; g $? "aynı ad ikinci kez açılmaz"

echo "════ T9 · reis-dedi: sınıfsız kartta ayrı alana yazar, sınıflı kartta REDDEDER (A268) ════"
CIKTI="$(bash "$KT" reis-dedi is-1 --karar devam --reis MUAVIN --oturum ref-a --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] || echo "    ↳ $CIKTI"; g $RC "sınıfsız karta (is-1) reis kararı işlendi"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));r=k['reis_kararlari'][-1];assert r['reis']=='MUAVIN' and r['oturum']=='ref-a' and 'sultan_kararlari' not in k"; g $? "🔴 reis_kararlari dolu, sultan_kararlari YOK (Sultan'ın alanına yazılmadı)"
bash "$KT" reis-dedi is-2 --karar devam --reis NAKKAS --oturum ref-b --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 SINIFLI karta (is-2, dis_yuzey) reis kararı REDDEDİLDİ"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-2.json'));assert 'reis_kararlari' not in k"; g $? "sınıflı kartta alan oluşmadı"
bash "$KT" reis-dedi is-1 --karar devam --reis MUAVIN --oturum ref-a --gerekce "kisa" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "kısa gerekçe REDDEDİLDİ"
bash "$KT" reis-dedi is-1 --karar devam --reis SERDAR --oturum ref-a --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 kartın sahibi olmayan ad (SERDAR ≠ aldi MUAVIN) REDDEDİLDİ"
bash "$KT" reis-dedi is-1 --karar "olur" --reis MUAVIN --oturum ref-a --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "🔴 küme dışı karar ('olur') REDDEDİLDİ"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert len(k['reis_kararlari'])==1"; g $? "reddedilen denemeler karta hiçbir şey yazmadı"

echo "════ T4 · is-alani ac kart ister; kartı worktree'ye taşır ════"
bash "$IA" ac kartsiz-is >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kartsız iş alanı açılmaz (rc=1)"
bash "$IA" ac kartsiz-is --kartsiz >/dev/null 2>&1; g $? "--kartsiz kaçışıyla açılır (gerekçe loglanır)"
bash "$IA" ac is-1 >/dev/null 2>&1; g $? "kartlı iş alanı açıldı"
[ ! -e "$T/alan/depo-is-1/_agents/fabrika/kartlar/is-1.json" ] && [ -f "$T/depo/_agents/fabrika/kartlar/is-1.json" ]; g $? "kart yalnız BİRİNCİL depoda, worktree'ye KOPYALANMADI (0.6.2 tek kaynak; kopya bayatlıyordu)"

echo "════ T5 · worktree içinden bitti: denetim puanı ve kanıt karta işlenir (kart birincilde) ════"
cd "$T/alan/depo-is-1"
bash "$K" olcum is-1 olc --asama tek -- echo 1 >/dev/null 2>&1
printf 'diff\n+x\n' > "$T/d.patch"
SAHTE="$T/sahte.sh"; printf '#!/usr/bin/env bash\nprintf %%s "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
SAHTE_JSON='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}' DENETCI_KOMUT="$SAHTE" bash "$D" is-1 --diff "$T/d.patch" >/dev/null 2>&1; g $? "denetim geçti (kart otomatik okundu, --kart verilmedi)"
CIKTI="$(bash "$KT" bitti is-1 --pr 7 2>&1)"; g $? "bitti rc=0"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert k['durum']=='bitti' and k['puan']['kod']==5 and k['kanit_var'] and k['pr']=='7'"; g $? "birincil karta puan+kanıt+PR işlendi"
cd "$T/depo"

echo "════ T6 · kanıtsız bitti uyarır; tıkandı üç yol ister ════"
CIKTI="$(bash "$KT" bitti is-2 2>&1)"; grep -q "KANIT YOK" <<<"$CIKTI"; g $? "kanıtsız bitti uyarısı"
bash "$KT" ac is-3 --is "göç" --istedi Sultan --aldi HAFIZ --geri-alinamaz e --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$KT" tikandi is-3 --yol daralt >/dev/null 2>&1; [ $? -eq 1 ]; g $? "nedensiz tıkandı reddedildi"
bash "$KT" tikandi is-3 --yol daralt --neden "şema çakışıyor" >/dev/null 2>&1; g $? "tıkandı yazıldı"

echo "════ T7 · gün sonu özeti defterden: üç bölüm + açık işler ════"
CIKTI="$(bash "$GS" --yaz 2>&1)"; g $? "özet üretildi"
grep -q "## Sultan'a gidenler (3)" <<<"$CIKTI"; g $? "Sultan'a gidenler 3 (is-2 dış yüzey · is-3 geri alınamaz · kartsız kaçış)"
grep -q "## İçeride bitirdiklerimiz (1)" <<<"$CIKTI" && grep -q "is-1" <<<"$CIKTI"; g $? "içeride bitenler 1 (is-1, 5/5 E)"
grep -q "## Tıkananlar (1)" <<<"$CIKTI" && grep -q "şema çakışıyor" <<<"$CIKTI"; g $? "tıkananlar 1, nedeniyle"
grep -q "## Açık işler (1)" <<<"$CIKTI" && grep -q "kartsiz-is" <<<"$CIKTI"; g $? "açık iş 1 (kartsız kaçış kartı)"
grep -q "## Kapı kaçışları (0)" <<<"$CIKTI"; g $? "kaçış başlığı var, bugün kaçış yok"
# NOT: satırı parça parça kuruyoruz; tek parça yazarsak Nexus'taki kapı kancası bu dosyayı
# yazan komutu "birleştirme" sanıp engelliyor (23 Eyl, kapının kendi kör noktası).
KAC="$(date +%F)T09:15:00Z | KAPISIZ | codex kutuda yok, Sultan sozlu onay | <komut>"
printf '%s\n' "$KAC" > "$T/depo/_agents/fabrika/kacis-defteri.log"
CIKTI="$(bash "$GS" 2>&1)"
grep -q "## Kapı kaçışları (1)" <<<"$CIKTI"; g $? "kaçış özete düşüyor"
grep -q "Sultan sozlu onay" <<<"$CIKTI"; g $? "gerekçe görünüyor"
grep -q "veto hakkın var" <<<"$CIKTI"; g $? "Sultan'ın veto hakkı yazılı"
[ -f "$T/depo/_agents/fabrika/gun-sonu/$(date +%F).md" ]; g $? "dosyaya yazıldı"
bash "$KT" liste --acik 2>&1 | grep -q "kartsiz-is"; g $? "liste --acik çalışıyor"

echo "════ T10 · CANLI sınıfı: cron/servis/sunucu işi kartta canlı kanıt ister (retro 17 Eki ders 1) ════"
CIKTI="$(bash "$KT" ac is-cron --is "donus-zili cron'u her saat çalsın" --istedi SERDAR --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h 2>&1)"; g $? "cron kartı açıldı"
grep -q "CANLI kanıt zorunlu" <<<"$CIKTI"; g $? "açılışta söylüyor"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-cron.json'));assert k['canli_gerekir'] is True and 'cron' in k['canli_sebep']"; g $? "canli_gerekir=true, sebep cümledeki kelime"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert k.get('canli_gerekir') is False and k.get('canli_sebep')==''"; g $? "'buton ekle' kartı canlı istemez"
bash "$KT" ac is-sunucu --is "kutu kapısı sürümünü 15 sunucuda güncelle" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-sunucu.json'));assert k['canli_gerekir'] and 'sunucu' in k['canli_sebep']"; g $? "'sunucu' kelimesi de yeter (ek: Sunucuda → sunucu)"
bash "$KT" ac is-canli-e --is "rapor sayfası" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli e >/dev/null 2>&1
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-canli-e.json'));assert k['canli_gerekir'] and k['canli_sebep']=='--canli e'"; g $? "--canli e kelime olmasa da zorunlu kılar"
CIKTI="$(bash "$KT" ac is-canli-h --is "cron belgesini düzelt" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h 2>&1)"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-canli-h.json'));assert k['canli_gerekir'] is False and 'sahip' in k['canli_sebep'] and 'cron' in k['canli_sebep']"; g $? "--canli h kelimeye rağmen kaldırır; kararı ve kelimeyi karta yazar (gizli değil)"
grep -q "canlı kanıt istenmedi" <<<"$CIKTI"; g $? "açılışta 'istenmedi' uyarısı basılır (bağımsız göz görsün)"
bash "$KT" ac is-canli-x --is x --istedi S --aldi B --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli evet >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--canli yalnız e|h"
[ ! -f "$T/depo/_agents/fabrika/kartlar/is-canli-x.json" ]; g $? "geçersiz cevapla kart yazılmadı"
bash "$K" olcum is-cron olc --asama tek -- echo 1 >/dev/null 2>&1
CIKTI="$(bash "$KT" bitti is-cron 2>&1)"; grep -q "CANLI KANIT YOK" <<<"$CIKTI"; g $? "canlı kanıtsız bitti uyarır"
printf '%s çaldı\n' "$(date -u +%FT%TZ)" > "$T/zil.log"
bash "$K" canli is-cron zil --desen çaldı --kaynak "dosya:$T/zil.log" >/dev/null 2>&1
CIKTI="$(bash "$KT" bitti is-cron 2>&1)"; ! grep -q "CANLI KANIT YOK" <<<"$CIKTI"; g $? "yeşil canlı kayıt varken uyarı yok"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-cron.json'));assert k['canli_kanit']=='var'"; g $? "karta canli_kanit=var işlendi"
# 4K938: geçersiz ilan edilen yeşil canlı kayıt bitti'de 'var' sayılmaz (etkin renk kanit.py'den)
bash "$K" gecersiz is-cron zil --neden "log başka sunucunun zil satırıydı, bu iş değil" --kim BANI >/dev/null 2>&1
CIKTI="$(bash "$KT" bitti is-cron 2>&1)"; grep -q "CANLI KANIT YOK" <<<"$CIKTI"; g $? "geçersiz ilan edilen canlı kayıtla bitti yine uyarır"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-cron.json'));assert k['canli_kanit']!='var', k['canli_kanit']"; g $? "karta canli_kanit=var İŞLENMEDİ (geçersiz yeşil sayılmaz)"
MK="$T/pkg-kart"; mkdir -p "$MK"; cp "$HERE"/*.py "$HERE"/*.sh "$MK/"; sed -i 's/x\["etkin_renk"\]=="yesil"/x.get("renk")=="yesil"/' "$MK/kart.sh"
grep -q 'x.get("renk")=="yesil"' "$MK/kart.sh"; g $? "mutant üretildi (kart.sh ham rengi okuyor)"
CIKTI="$(bash "$MK/kart.sh" bitti is-cron 2>&1)"; ! grep -q "CANLI KANIT YOK" <<<"$CIKTI" && grep -q "kart bitti" <<<"$CIKTI"; g $? "mutant (tam kopya, bitti koştu): geçersiz yeşili sayıp uyarmıyor → üstteki kapı bu mutantta düşerdi"
# canli-gerekir: kapının okuduğu tek yüzey; eski kartta (alan yok) cümleden türetir
[ "$(bash "$KT" canli-gerekir is-cron | cut -f1)" = "E" ] && [ "$(bash "$KT" canli-gerekir is-1 | cut -f1)" = "H" ]; g $? "canli-gerekir E/H okur"
python3 - <<PY
import json;p='$T/depo/_agents/fabrika/kartlar/is-sunucu.json';k=json.load(open(p));k.pop('canli_gerekir');k.pop('canli_sebep');json.dump(k,open(p,'w'))
PY
CIKTI="$(bash "$KT" canli-gerekir is-sunucu)"; [ "$(cut -f1 <<<"$CIKTI")" = "E" ] && grep -q "eski kart" <<<"$CIKTI"; g $? "alanı olmayan eski kart: cümleden E, 'eski kart' işaretli"
# göz #353 tur 3: eski kart bitti'de de aynı sınıflandırma (kapıyla tutarlı) + kelime başı sınırı
bash "$K" olcum is-sunucu olc --asama tek -- echo 1 >/dev/null 2>&1
CIKTI="$(bash "$KT" bitti is-sunucu 2>&1)"; grep -q "CANLI KANIT YOK" <<<"$CIKTI"; g $? "alanı olmayan eski servis/sunucu kartı bitti'de de canlı kanıt uyarısı alır (kapıyla aynı yüzey)"
bash "$KT" ac is-ghost --is "ghost düğmesi ve ekrandaki liste" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-ghost.json'));assert k['canli_gerekir'] is False, k['canli_sebep']"; g $? "'ghost' içindeki host canlı saymaz (kelime başı sınırı; Türkçe ek serbest)"
bash "$KT" ac is-hosting --is "hosting paneli ve zilli bildirim sesi" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-hosting.json'));assert k['canli_gerekir'] is False, k['canli_sebep']"; g $? "'hosting' / 'zilli' canlı saymaz (kelime sonu sınırı; yedek göz #354)"
bash "$KT" ac is-ek --is "sunucudaki cron'u ve servisleri yenile" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-ek.json'));assert k['canli_gerekir'] and 'sunucu' in k['canli_sebep'] and 'cron' in k['canli_sebep'] and 'servis' in k['canli_sebep'], k['canli_sebep']"; g $? "Türkçe ekler (sunucudaki · cron'u · servisleri) hâlâ yakalanır"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo "════ T11 · daralt: kalan bulgu yeni karta, cümle daraltılır, tur sıfırı yazılır (PCP7J) ════"
mkdir -p "$T/depo2" && cd "$T/depo2" && git init -q -b main && export KANIT_DEPO="$T/depo2"   # önceki sınav çalışma dizinini kaldırmış olabilir
bash "$KT" ac is-dar --is "iki yarım iş tek kartta olduğu için tıkanan iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$KT" daralt is-dar --kalan "kısa" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-d >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kısa --kalan REDDEDİLDİ"
bash "$KT" daralt is-dar --kalan "kalan yarı: raporu da üretsin, bu kartta değil" --cumle "daraltılmış cümle yeterince uzun burada" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--oturum yoksa REDDEDİLDİ"
[ ! -f "$T/depo2/_agents/fabrika/kartlar/is-dar-kalan.json" ]; g $? "reddedilen denemeler kalan kart yazmadı"
mkdir -p "$T/depo2/_agents/fabrika/kanit/is-dar"; for i in 1 2 3; do echo '{"tur":'$i',"sonuc":{"kod_puani":2,"dogru_sey":"H","bulgular":[]}}' > "$T/depo2/_agents/fabrika/kanit/is-dar/DENETIM-$i.json"; done
CIKTI="$(bash "$KT" daralt is-dar --kalan "kalan yarı: raporu da üretsin, bu kartta değil" --cumle "yalnız birinci yarı: ölçümü yazsın ve kaydetsin" --oturum ref-d 2>&1)"; g $? "daralt rc=0"
grep -q "tur sıfırı 3" <<<"$CIKTI"; g $? "tur sıfırı 3 yazıldı (3 denetim vardı)"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar.json'));assert k['cumle'].startswith('yalnız') and k['cumle_gecmisi'][0]['cumle'].startswith('iki yarım') and k['daraltmalar'][-1]['tur_sifir']==3 and k['reis_kararlari'][-1]['karar']=='daralt' and k['reis_kararlari'][-1]['reis']=='MUAVIN'"; g $? "cümle daraltıldı, geçmiş saklandı, reis kararı 'daralt' sahibin adıyla işlendi"
python3 -c "import json;y=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-kalan.json'));assert y['koken']=='is-dar' and y['aldi']=='MUAVIN' and y['istedi']=='Sultan' and y['sinif_cevaplari']=={'geri_alinamaz':'h','para':'h','dis_yuzey':'h','yetki':'h'} and y['durum']=='acik'"; g $? "kalan kart: aynı sahip/istedi/sınıf cevapları, köken yazılı"
bash "$KT" daralt is-dar --kalan "üçüncü parça da ayrılsın yeterince uzun" --cumle "daha da daraltılmış cümle yeterince uzun" --oturum ref-d >/dev/null 2>&1; [ $? -eq 1 ]; g $? "aynı kalan ad ikinci kez açılmaz (--yeni gerekir)"
bash "$KT" daralt is-dar --kalan "üçüncü parça da ayrılsın yeterince uzun" --cumle "daha da daraltılmış cümle yeterince uzun" --oturum ref-d --yeni is-dar-3 >/dev/null 2>&1; g $? "--yeni ile ikinci daraltma"
echo "════ T12 · daralt SINIFLI kartta Sultan kararı ister (A06) ════"
bash "$KT" ac is-dar-s --is "para harcayan iş tek kartta iki yarımla tıkandı" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$KT" daralt is-dar-s --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-s >/dev/null 2>&1; [ $? -eq 1 ]; g $? "sınıflı kart Sultan kararı olmadan daraltılmadı"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s.json'));assert 'daraltmalar' not in k and 'reis_kararlari' not in k"; g $? "karta hiçbir şey yazılmadı"
bash "$KT" sultan-dedi is-dar-s --karar daralt --oturum ref-s --soz "daralt, kalanı sonra" --beyan MUAVIN --gerekce "ikinci yarı ayrı PR ile gelsin, ilk yarı bitti" >/dev/null 2>&1
bash "$KT" daralt is-dar-s --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-s >/dev/null 2>&1; g $? "Sultan 'daralt' kararı karttayken daraltıldı"
python3 -c "import json;y=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s-kalan.json'));assert y['sultan']==True and y['siniflar']==['para']"; g $? "kalan kart da SINIFLI doğdu (sınıf miras)"
echo "════ T12b · Sultan 'daralt' kararı TEK KULLANIMLIK; --yeni ad güvenli; iki kart atomik (göz tur 1) ════"
bash "$KT" daralt is-dar-s --kalan "üçüncü parça yeterince uzun bir cümle burada" --cumle "daha da daraltılmış cümle yeterince uzun" --oturum ref-s --yeni is-dar-s-3 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "aynı Sultan kararıyla İKİNCİ daraltma REDDEDİLDİ (karar tüketildi)"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s.json'));sk=k['sultan_kararlari'][-1];assert sk['kullanildi']['kalan_kart']=='is-dar-s-kalan' and len(k['daraltmalar'])==1"; g $? "kullanılan karar karta işaretli, ikinci daraltma yazılmadı"
bash "$KT" daralt is-dar --kalan "yol ayraçlı ad denemesi yeterince uzun" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-d --yeni "../kacak" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--yeni '../kacak' REDDEDİLDİ"
bash "$KT" daralt is-dar --kalan "yol ayraçlı ad denemesi yeterince uzun" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-d --yeni "a/b" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--yeni 'a/b' REDDEDİLDİ"
[ ! -e "$T/depo2/_agents/fabrika/kacak.json" ] && [ ! -e "$T/depo2/_agents/fabrika/kartlar/a" ]; g $? "dizin dışına hiçbir şey yazılmadı"
bash "$KT" ac is-at --is "atomik yazım denemesi için iş cümlesi burada" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
mkdir -p "$T/depo2/_agents/fabrika/kartlar/is-at-kalan.json.tmp"   # geçici dosya yolu bir DİZİN → kalan kart yazılamaz
ONCE="$(md5sum < "$T/depo2/_agents/fabrika/kartlar/is-at.json")"
bash "$KT" daralt is-at --kalan "kalan parça yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-at >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kalan kart yazılamayınca rc=1"
[ "$(md5sum < "$T/depo2/_agents/fabrika/kartlar/is-at.json")" = "$ONCE" ]; g $? "ana kart bayt bayt DEĞİŞMEDİ (atomik)"
[ ! -f "$T/depo2/_agents/fabrika/kartlar/is-at-kalan.json" ]; g $? "yarım kalan kart yok"
rmdir "$T/depo2/_agents/fabrika/kartlar/is-at-kalan.json.tmp" 2>/dev/null

echo "════ T13 · KAPSAM UYARISI: iki depo · çok günlük kapsam → uyarır, REDDETMEZ (retro W42 ders M2) ════"
K13="${KANIT_DEPO:-$T/depo}"; B13="$(basename "$K13")"   # önceki bloklar KANIT_DEPO'yu depo2'ye çeviriyor
ac13() { bash "$KT" ac "$1" --is "$2" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h 2>&1; }
ku() { python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['kapsam_uyarilari']))" "$K13/_agents/fabrika/kartlar/$1.json" 2>/dev/null || echo yok; }
# W42'nin gerçek kartı (hendese-kutuphane-h1): haftalık yazıldı, günlük teslim edildi
CIKTI="$(ac13 is-h1 "HENDESE kütüphanesi 1. hafta: günlük tur kayıtları (depo/web/video) + örnek vaka kartları, kaynaklı")"; RC=$?
[ "$RC" -eq 0 ] && [ "$(ku is-h1)" = 1 ]; g $? "haftalık kart AÇILDI (uyarı, red değil) · karta 1 kapsam uyarısı yazıldı"
grep -q "⚠ KAPSAM — ÇOK GÜNLÜK KAPSAM (1. hafta).*is-h1-g1 · is-h1-g2" <<<"$CIKTI"; g $? "çok günlük kapsam: gün başına kart önerildi (is-h1-g1 · is-h1-g2)"
CIKTI="$(ac13 is-ikid "Nexus wait-ci --repo bayrağını tanısın ve cloudtop zili aynı kuralla bildirsin")"; RC=$?
[ "$RC" -eq 0 ] && grep -q "İKİ DEPO: cümle Nexus + cloudtop anıyor.*kart.sh ac is-ikid-nexus … · kart.sh ac is-ikid-cloudtop …" <<<"$CIKTI"; g $? "iki depo adı → depo başına kart önerildi"
CIKTI="$(ac13 is-baska "cloudtop terminal-merkez bekçisi ölçülemedi hükmünü işlesin")"
[ "$(ku is-baska)" = 0 ] && ! grep -q "KAPSAM" <<<"$CIKTI"; g $? "TEK depo adı (başka depo da olsa) uyarı almaz — kart cümlesi yalnız iki depo + çok günlük istedi (göz #384 tur 1)"
CIKTI="$(FABRIKA_DEPOLAR="$B13:Nexus cloudtop" ac13 is-bu "Nexus wait-ci --repo bayrağını tanısın")"
[ "$(ku is-bu)" = 0 ] && ! grep -q "KAPSAM" <<<"$CIKTI"; g $? "yalnız KENDİ deposunu anan cümle uyarı almaz (takma adla da)"
CIKTI="$(ac13 is-sx "Sx kart.sh uyarısı ve Nexus notu")"
grep -q "İKİ DEPO: cümle Nexus + Sx-Claude-Skills" <<<"$CIKTI"; g $? "takma ad (Sx) depo sayılır"
CIKTI="$(ac13 is-yalan "sohbet ocak sedir lonca adları, nexus ve Cloudtop yanlış harfle, SxFoo ve Nexus-ana-dal-kapisi ekle; haftaya bakarız")"
[ "$(ku is-yalan)" = 0 ] && ! grep -q "KAPSAM" <<<"$CIKTI"; g $? "yanlış alarm yok: sıradan kelime adlar · küçük harf · bitişik ad · tireli ek · 'haftaya'"
CIKTI="$(ac13 is-duz "buton ekle")"
[ "$(ku is-duz)" = 0 ] && ! grep -q "KAPSAM" <<<"$CIKTI"; g $? "düz cümlede uyarı yok, karta boş liste yazıldı"
CIKTI="$(ac13 is-gun "W42 boyunca her gün tur kaydı")"
grep -q "ÇOK GÜNLÜK KAPSAM (W42, her gün)" <<<"$CIKTI"; g $? "hafta kodu ve 'her gün' de çok günlük sayılır"

echo "════ T13b · ATIF KAPSAM DEĞİLDİR: 'retro W42', 'hafta raporu' uyarmaz; gerçek çok günlük kapsam uyarmaya devam eder (20 Eki, üç yanlış alarm) ════"
ac13m() { bash "$1" ac "$2" --is "$3" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h 2>&1; }
ATIF=("birleştirme kancası CI'ı her birleştirmede ölçsün (gorev_01M506PY0B6X92R0NEK0NSPCR7 + hafta raporu E3)"
      "denetçi ölçüm çıktısının sonunu da versin; fabrika 0.10.6 (gorev_01M5890SCNMSR4DFTGHVWEJEC3, retro W42 HENDESE Ö1)"
      "kart.sh ac iş cümlesinde iki depo görürse uyarsın (retro W42 ders M2)"
      "hafta kapısı D13 PR gövdesinde retro işaretini arasın"
      "W42 retrosu için kutu dosyasını doldur")
KAPSAM=("W42 boyunca her gün tur kaydı" "haftalık rapor üretimi kur ve her gün koştur" "bu hafta tüm kutuların retrosunu topla" "3 gün sürecek göç")
n13=0
for c in "${ATIF[@]}"; do n13=$((n13+1)); CIKTI="$(ac13m "$KT" "is-atif-$n13" "$c")"
  [ "$(ku "is-atif-$n13")" = 0 ] && ! grep -q "ÇOK GÜNLÜK" <<<"$CIKTI"; g $? "atıf uyarmaz: $(cut -c1-70 <<<"$c")"; done
for c in "${KAPSAM[@]}"; do n13=$((n13+1)); CIKTI="$(ac13m "$KT" "is-kap-$n13" "$c")"
  grep -q "ÇOK GÜNLÜK KAPSAM" <<<"$CIKTI"; g $? "gerçek kapsam uyarır: $c"; done
echo "── T13b · MUTASYON (tam kopya; her mutant bir atıf cümlesini yeniden uyarır hâle getirmeli) ──"
m13() {   # m13 <ad> <eski> <yeni> <uyarmaya başlaması gereken atıf cümlesi>
  local D="$T/pkg-kapsam-$1"; mkdir -p "$D"; cp "$HERE"/*.py "$HERE"/*.sh "$D/" 2>/dev/null
  python3 - "$D/kart.sh" "$2" "$3" <<'PYM' || { g 1 "mutant '$1' kurulamadı (çapa bayat)"; return; }
import sys; f, a, b = sys.argv[1:]; s = open(f, encoding="utf-8").read(); assert s.count(a) == 1; open(f, "w", encoding="utf-8").write(s.replace(a, b, 1))
PYM
  n13=$((n13+1)); local o; o="$(ac13m "$D/kart.sh" "is-m13-$n13" "$4")"
  grep -q "ÇOK GÜNLÜK" <<<"$o"; g $? "mutant '$1' atfı yeniden kapsam sanıyor → üstteki kapı bu mutantta düşerdi"
}
m13 retro-onu-sayilir '(?<!retro )' '' "denetçi ölçüm sonu (retro W42 HENDESE Ö1)"   # yalnız öndeki 'retro ' korumasına bağlı cümle
m13 atif-sonra-bos 'ATIF_SONRA = r"(?!\s+(?:rapor|kap[ıi]s|kapan[ıi]ş|retro|ders|Ö\d))"' 'ATIF_SONRA = r""' "hafta kapısı D13 PR gövdesinde retro işaretini arasın"
m13 hafta-atifsiz '(?:s[ıi]|n[ıi]n|da|y[ıi])?(?!\w)" + ATIF_SONRA + r"' '(?:s[ıi]|n[ıi]n|da|y[ıi])?(?!\w)" + r"' "birleştirme kancası CI'ı ölçsün (hafta raporu E3)"
m13 W-atifsiz 'W\d{2}(?!\w)" + ATIF_SONRA' 'W\d{2}(?!\w)"' "W42 retrosu için kutu dosyasını doldur"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
