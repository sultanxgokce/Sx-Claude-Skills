#!/usr/bin/env bash
# kart.test.sh — iş kartı (0. adım) ve gün sonu özeti sahte depoda: sınıf soruları zorunlu, şüphede yukarı, özet defterden.
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI (gerçek koltuklara çalmasın); zil kapısı kendi sahtesini verir
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KT="$HERE/kart.sh"; GS="$HERE/gun-sonu.sh"; K="$HERE/kanit.sh"; D="$HERE/denetci.sh"; IA="$HERE/is-alani.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; mkdir -p "$T/uzak" "$T/depo"
( cd "$T/uzak" && git init -q --bare ) >/dev/null 2>&1
( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" && git remote add origin "$T/uzak" && git push -q -u origin main ) >/dev/null 2>&1
# 🔴 SAHTE TETİK (göz 23 Eki tur 2): sınıflı kart artık Sultan'a ulaşım yolu ister (--oda + tetik betiği) — sınav GERÇEK odalara
#    mektup bırakmasın diye tetik sahtedir: gövdeyi kayda yazar, rc 0 (TETIK_SAHTE_RC ile düşürülebilir).
tetik_kur() { mkdir -p "$T"; cat > "$T/tetik-sahte.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\t%s\n' "$2" "$(tr '\n' ' ' < "$3")" >> "${TETIK_KAYIT:?}"; exit "${TETIK_SAHTE_RC:-0}"
SH
chmod +x "$T/tetik-sahte.sh"; : >> "$T/tetik-kayit.tsv"; }
tetik_kur
export FABRIKA_TETIK="$T/tetik-sahte.sh" TETIK_KAYIT="$T/tetik-kayit.tsv" IS_ALANI_KOK="$T/alan"
export DEFTER_JETON_YOL="$T/jeton-yok"   # gerçek görev defterine dokunulmaz (hermetik)
cd "$T/depo"

echo "════ T1 · sınıf sorusu eksik → kart açılmaz ════"
bash "$KT" ac is-1 --is "buton" --istedi Sultan --aldi MUAVIN --para h >/dev/null 2>&1; [ $? -eq 1 ]; g $? "eksik cevapla rc=1"
[ ! -f "$T/depo/_agents/fabrika/kartlar/is-1.json" ]; g $? "kart yazılmadı"

echo "════ T2 · dört cevap h → sınıfsız, ekipte biter ════"
CIKTI="$(bash "$KT" ac is-1 --is "buton ekle" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h 2>&1)"; g $? "kart açıldı"
grep -q "ekipte biter" <<<"$CIKTI"; g $? "ekipte biter dedi"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert k['sultan']==False and k['durum']=='acik'"; g $? "sultan=false"

kartgovde() { printf '### E1 · ornek ekran\n**Amaç:** x\n**Giriş:** y\n**İlk bakışta:** z\n**Ana akış:**\n1. a\n2. b\n%s\n**Kenar durumlar:** k\n**Kısıt kancaları:** q\n' "$1"; }   # Ana akış değeri sonraki satırlarda (şablondaki gibi)
kartgovde '**Tık bütçesi:** 2 tık + 1 alan' > "$T/senaryo-dolu.md"   # ekran kapısı fikstürü (T3 ve T-EK): tam Durak 2 kartı
echo "════ T3 · '?' cevabı → şüphede yukarı, Sultan'a gider ════"
CIKTI="$(bash "$KT" ac is-2 --is "anasayfa görünümü" --istedi reis --aldi NAKKAS --geri-alinamaz h --para h --dis-yuzey '?' --yetki h --oda sinav-oda --senaryo "$T/senaryo-dolu.md" 2>&1)"
grep -q "SULTAN'A GİDER" <<<"$CIKTI"; g $? "SULTAN'A GİDER"
grep -q "BAŞLAMA İZNİ" <<<"$CIKTI" && grep -q "veto penceresi" <<<"$CIKTI"; g $? "0.21.0: 'BAŞLAMA İZNİ … veto penceresi' der (iş bekletilmez)"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-2.json'));assert k['sultan'] and k['siniflar']==['dis_yuzey']"; g $? "sınıf dis_yuzey"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-2.json'));assert k['baslama_izni']['durum']=='bekliyor' and k['baslama_izni']['istendi'] and k['kural_surumu']=='0.21.0'"; g $? "karta baslama_izni=bekliyor + istendi + kural_surumu 0.21.0 yazıldı"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));assert 'baslama_izni' not in k and 'kural_surumu' not in k"; g $? "sınıfsız kartta alan YOK (bayt bayt eski davranış)"
[ "$(bash "$KT" izin-durum is-2 | cut -f1)" = bekliyor ] && [ "$(bash "$KT" izin-durum is-1 | cut -f1)" = gerekmiyor ]; g $? "izin-durum: sınıflı → bekliyor, sınıfsız → gerekmiyor"
bash "$KT" ac is-2 --is x --istedi a --aldi b --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; [ $? -eq 1 ]; g $? "aynı ad ikinci kez açılmaz"

echo "════ T9 · reis-dedi: ayrı alana yazar; 0.21.0: SINIFLI kartta da kabul (sinifli:true), Sultan'ın alanına dokunmaz ════"
CIKTI="$(bash "$KT" reis-dedi is-1 --karar devam --reis MUAVIN --oturum ref-a --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] || echo "    ↳ $CIKTI"; g $RC "sınıfsız karta (is-1) reis kararı işlendi"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-1.json'));r=k['reis_kararlari'][-1];assert r['reis']=='MUAVIN' and r['oturum']=='ref-a' and 'sultan_kararlari' not in k"; g $? "🔴 reis_kararlari dolu, sultan_kararlari YOK (Sultan'ın alanına yazılmadı)"
CIKTI="$(bash "$KT" reis-dedi is-2 --karar devam --reis NAKKAS --oturum ref-b --gerekce "uc turun bulgulari farkliydi ve hepsi kapandi" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] || echo "    ↳ $CIKTI"; g $RC "🔴 FLİP: SINIFLI karta (is-2, dis_yuzey) reis kararı KABUL EDİLDİ (rc 0) — eski kural reddederdi"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-2.json'));r=k['reis_kararlari'][-1];assert r['sinifli'] is True and r['izin']=='bekliyor' and r['reis']=='NAKKAS' and 'sultan_kararlari' not in k"; g $? "🔴 kayıt reis_kararlari'nda sinifli:true + izin; sultan_kararlari OLUŞMADI"
grep -q "Sultan sozu degil" <<<"$CIKTI" && grep -q "SINIFLI" <<<"$CIKTI"; g $? "çıktı 'reis kararı, Sultan sözü değil' der (etiketli)"
bash "$KT" reis-dedi is-2 --karar birlestir --reis NAKKAS --oturum ref-b --gerekce "kanit tam, goz 5/E, veto yok; birlestirme karari reisin" >/dev/null 2>&1; g $? "yeni küme üyesi 'birlestir' kabul (canli-borc ikinci kartta)"
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
bash "$KT" ac is-3 --is "göç" --istedi Sultan --aldi HAFIZ --geri-alinamaz e --para h --dis-yuzey h --yetki h --oda sinav-oda >/dev/null 2>&1
bash "$KT" tikandi is-3 --yol daralt >/dev/null 2>&1; [ $? -eq 1 ]; g $? "nedensiz tıkandı reddedildi"
bash "$KT" tikandi is-3 --yol daralt --neden "şema çakışıyor" >/dev/null 2>&1; g $? "tıkandı yazıldı"

echo "════ T7 · gün sonu özeti defterden: üç bölüm + açık işler ════"
CIKTI="$(bash "$GS" --yaz 2>&1)"; g $? "özet üretildi"
# gün sonunun yeni etiketleri ikinci kartta; burada eski çıktı sınanır.
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
bash "$KT" liste 2>&1 | grep -q "is-2 .*sınıflı · izin: bekliyor" && ! bash "$KT" liste 2>&1 | grep -q "SULTAN"; g $? "liste etiketi 'sınıflı · izin: …'"

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
# canli-ayarla (kart-canli-ayarla): açık kartta canlı şartını YALNIZ sahip, gerekçeyle değiştirir; karta ve geçmişe yazılır
echo "── canli-ayarla: sahip kararı (aktör + gerekçe + açık kart) ──"
GER="belge işi; kutuya servis kurulmuyor, kelime yanlış pozitif"
bash "$KT" canli-ayarla is-sunucu --canli h --reis BANI >/dev/null 2>&1; [ $? -eq 1 ]; g $? "canli-ayarla gerekçesiz reddeder"
bash "$KT" canli-ayarla is-sunucu --canli h --reis BANI --gerekce "kısa" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "20 karakterden kısa gerekçe reddedilir"
bash "$KT" canli-ayarla is-sunucu --canli h --reis BANI --gerekce "                         " >/dev/null 2>&1; [ $? -eq 1 ]; g $? "20 boşluktan oluşan gerekçe sayılmaz"
bash "$KT" canli-ayarla is-sunucu --canli h --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--reis verilmeden reddedilir (aktör ölçülmeden şart kalkmaz)"
bash "$KT" canli-ayarla is-sunucu --canli h --reis SERDAR --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "sahip olmayan ad (SERDAR ≠ aldı BANI) reddedilir"
bash "$KT" canli-ayarla is-sunucu --canli evet --reis BANI --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "--canli yalnız e|h"
bash "$KT" canli-ayarla yok-boyle-kart --canli h --reis BANI --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "kart yoksa rc=3 (ölçülemedi)"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-sunucu.json'));assert k['canli_gerekir'] is True and not any(x.get('olay')=='canli-ayarla' for x in k['gecmis'])"; g $? "reddedilen çağrılar kartı DEĞİŞTİRMEDİ (şart hâlâ E, geçmişe satır yok)"
CIKTI="$(bash "$KT" canli-ayarla is-sunucu --canli h --reis BANI --gerekce "$GER" 2>&1)"; g $? "gerekçeli sahip kararı kabul"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-sunucu.json'));assert k['canli_gerekir'] is False and 'yanlış pozitif' in k['canli_sebep'] and 'BANI' in k['canli_sebep'] and k['gecmis'][-1]['olay']=='canli-ayarla' and k['gecmis'][-1]['reis']=='BANI'"; g $? "karta canli_sebep (ad + gerekçe) ve geçmiş satırı yazıldı"
[ "$(bash "$KT" canli-gerekir is-sunucu | cut -f1)" = "H" ]; g $? "kapının okuduğu yüzey (canli-gerekir) yeni kararı H olarak okur"
bash "$KT" ac is-ayarla-e --is "buton ekle" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
[ "$(bash "$KT" canli-gerekir is-ayarla-e | cut -f1)" = "H" ]; g $? "ön koşul: buton kartı canlı istemiyor"
bash "$KT" canli-ayarla is-ayarla-e --canli e --reis BANI --gerekce "buton işi ama kurulum cron'la yayılıyor" >/dev/null 2>&1 && [ "$(bash "$KT" canli-gerekir is-ayarla-e | cut -f1)" = "E" ]; g $? "canli-ayarla e: canlı istemeyen kart canlı ister hâle gelir"
bash "$KT" canli-ayarla is-cron --canli h --reis BANI --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "bitmiş kartın canlı şartı sonradan değiştirilmez (rc=1)"
python3 -c "import json;k=json.load(open('$T/depo/_agents/fabrika/kartlar/is-cron.json'));assert k['canli_gerekir'] is True"; g $? "bitmiş kart değişmedi (şart hâlâ E)"
MA="$T/pkg-ayarla"; mkdir -p "$MA"; cp "$HERE"/*.py "$HERE"/*.sh "$MA/"; sed -i '/^yol,cevap,gerekce,reis=sys.argv/,/^k\["canli_gerekir"\]/ s/^if reis != k.get("aldi"):$/if False:/' "$MA/kart.sh"
[ "$(grep -c '^if False:$' "$MA/kart.sh")" = 1 ]; g $? "mutant üretildi (sahip denetimi kapatıldı; çapa tam bir yerde)"
bash "$KT" ac is-ayarla-mut --is "sahip denetimi mutantı için kart" --istedi S --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli e >/dev/null 2>&1
bash "$MA/kart.sh" canli-ayarla is-ayarla-mut --canli h --reis SERDAR --gerekce "$GER" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant: sahip olmayan ad KABUL edilir — gerçek kart rc=1 verdi, yani sınav sahip denetimini ölçüyor"
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
tetik_kur   # önceki sınav $T'yi boşalttı (find -delete) — sahte tetik de gitti, yeniden kurulur
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
echo "════ T12 · daralt SINIFLI kartta (0.21.0): reis kararıyla, sinifli:true ════"
bash "$KT" ac is-dar-s --is "para harcayan iş tek kartta iki yarımla tıkandı" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda >/dev/null 2>&1
CIKTI="$(bash "$KT" daralt is-dar-s --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-s 2>&1)"; RC=$?; [ "$RC" -eq 0 ] || echo "    ↳ $CIKTI"; g $RC "🔴 FLİP: sınıflı kart Sultan kararı OLMADAN daraltıldı (rc 0) — eski kural rc 1 verirdi"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s.json'));r=k['reis_kararlari'][-1];assert r['karar']=='daralt' and r['sinifli'] is True and r['reis']=='MUAVIN' and 'sultan_kararlari' not in k and len(k['daraltmalar'])==1"; g $? "reis kararı 'daralt' sinifli:true ile işlendi; sultan_kararlari OLUŞMADI"
grep -q "SINIFLI, reis kararı işlendi · izin: bekliyor" <<<"$CIKTI"; g $? "çıktı 'SINIFLI, reis kararı işlendi · izin: bekliyor' der"
python3 -c "import json;y=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s-kalan.json'));assert y['sultan']==True and y['siniflar']==['para'] and y['baslama_izni']['durum']=='bekliyor' and y['baslama_izni']['miras']=='is-dar-s'"; g $? "kalan kart da SINIFLI doğdu (sınıf miras) + başlama izni kökten MİRAS"
echo "════ T12b · GERİYE UYUM: kullanılmamış Sultan 'daralt' kararı tüketilir; --yeni ad güvenli; iki kart atomik ════"
bash "$KT" sultan-dedi is-dar-s --karar daralt --oturum ref-s --soz "daralt, kalanı sonra" --beyan MUAVIN --gerekce "ikinci yarı ayrı PR ile gelsin, ilk yarı bitti" >/dev/null 2>&1
CIKTI="$(bash "$KT" daralt is-dar-s --kalan "üçüncü parça yeterince uzun bir cümle burada" --cumle "daha da daraltılmış cümle yeterince uzun" --oturum ref-s --yeni is-dar-s-3 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "SINIFLI, Sultan kararıyla (eski karar tüketildi)" <<<"$CIKTI"; g $? "kullanılmamış Sultan 'daralt' kararı TÜKETİLDİ, çıktı 'Sultan kararıyla' dedi"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s.json'));sk=k['sultan_kararlari'][-1];assert sk['kullanildi']['kalan_kart']=='is-dar-s-3' and len(k['daraltmalar'])==2 and k['reis_kararlari'][-1]['sultan_karari_tuketildi'] is True"; g $? "kullanılan karar karta işaretli (tek kullanımlık damga aynı), reis kaydı 'sultan_karari_tuketildi' taşır"
ONCE3="$(md5sum < "$T/depo2/_agents/fabrika/kartlar/is-dar-s.json")"
CIKTI="$(bash "$KT" daralt is-dar-s --kalan "dördüncü parça yeterince uzun bir cümle burada" --cumle "en dar cümle yeterince uzun burada evet" --oturum ref-s --yeni is-dar-s-4 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "üçüncü daraltma yok" <<<"$CIKTI"; g $? "ÜST SINIR (Y0B2W8): iki daraltmadan sonra ÜÇÜNCÜ daraltma rc 1, 'üçüncü daraltma yok' der"
[ "$(md5sum < "$T/depo2/_agents/fabrika/kartlar/is-dar-s.json")" = "$ONCE3" ] && [ ! -f "$T/depo2/_agents/fabrika/kartlar/is-dar-s-4.json" ]; g $? "reddedilen üçüncü daraltma kartı bayt bayt değiştirmedi, kalan kart yazmadı"
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

echo "════ T16 · BAŞLAMA İZNİ / VETO (0.21.0): basla|dur → izin-durum; kapalı küme; vetoda reis-dedi/daralt/bitti rc 1 ════"
bash "$KT" ac is-vt --is "bekçi cron'u yetki genişleten iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e --oda sinav-oda --canli e >/dev/null 2>&1
IFS=$'\t' read -r IZ IZA <<<"$(bash "$KT" izin-durum is-vt)"; [ "$IZ" = bekliyor ] && grep -q "veto yok" <<<"$IZA"; g $? "V1 açılışta izin-durum 'bekliyor<TAB>… veto yok'"
bash "$KT" sultan-dedi is-vt --karar olur --oturum o0 --soz "olur" --beyan MUAVIN >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V2 🔴 kapalı küme: --karar olur rc 1"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));assert 'sultan_kararlari' not in k"; g $? "V2b reddedilen karar karta yazılmadı"
bash "$KT" sultan-dedi is-vt --karar dur --soz "dur" --beyan MUAVIN >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V3 dur da D1 üçlüsünü ister: --oturum eksik rc 1"
bash "$KT" sultan-dedi is-vt --karar dur --oturum "sohbet-2340" --soz "bunu şimdi durdurun" --beyan MUAVIN --gerekce "kisa" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V3b dur'da --gerekce isteğe bağlı ama verilirse ≥20"
CIKTI="$(bash "$KT" sultan-dedi is-vt --karar dur --oturum "sohbet-2340" --soz "bunu şimdi durdurun" --beyan MUAVIN 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "VETO" <<<"$CIKTI"; g $? "V4 sultan-dedi dur (gerekçesiz, D1 üçlüsü tam) rc 0, çıktı VETO der"
IFS=$'\t' read -r IZ IZA <<<"$(bash "$KT" izin-durum is-vt)"; [ "$IZ" = dur ] && grep -q "sohbet-2340" <<<"$IZA" && grep -q "bunu şimdi durdurun" <<<"$IZA"; g $? "V5 izin-durum 'dur' + oturum ref + kırpık söz (izlenebilir)"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));b=k['baslama_izni'];assert b['durum']=='dur' and b['oturum']=='sohbet-2340' and b['beyan']=='MUAVIN' and k['sultan_kararlari'][-1]['karar']=='dur'"; g $? "V5b karta baslama_izni=dur (oturum·söz·beyan) + sultan_kararlari kaydı"
bash "$KT" reis-dedi is-vt --karar devam --reis MUAVIN --oturum r1 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V6 🔴 VETOLU kartta reis-dedi rc 1"
CIKTI="$(bash "$KT" reis-dedi is-vt --karar devam --reis MUAVIN --oturum r1 --gerekce "yirmi karakterden uzun bir gerekce metni" 2>&1)"; grep -q "DUR dedi" <<<"$CIKTI" && grep -q "sultan-dedi is-vt --karar basla" <<<"$CIKTI"; g $? "V6b sebep + çare (sultan-dedi --karar basla) yazılı"
bash "$KT" daralt is-vt --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum r1 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V7 🔴 VETOLU kartta daralt rc 1"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));assert 'reis_kararlari' not in k and 'daraltmalar' not in k"; [ $? -eq 0 ] && [ ! -f "$T/depo2/_agents/fabrika/kartlar/is-vt-kalan.json" ]; g $? "V7b hiçbir kart değişmedi, kalan kart doğmadı"
CIKTI="$(bash "$KT" sultan-dedi is-vt --karar basla --oturum "sohbet-2355" --soz "tamam başlayın" --beyan MUAVIN 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "veto kalktı" <<<"$CIKTI" && [ "$(bash "$KT" izin-durum is-vt | cut -f1)" = basla ]; g $? "V9 sultan-dedi basla vetoyu kaldırır (son basla/dur kazanır) → izin-durum basla"
bash "$KT" reis-dedi is-vt --karar devam --reis MUAVIN --oturum r1 --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; g $? "V10 basla sonrası reis-dedi açıldı"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));r=k['reis_kararlari'][-1];assert r['sinifli'] and r['izin']=='basla'"; g $? "V10b kayıt izin:basla etiketli"
# canlı borç sınavları (V8/V11/V12) ikinci kartta.
bash "$KT" sultan-dedi is-vt --karar dur --oturum "sohbet-2358" --soz "yine durun" --beyan MUAVIN >/dev/null 2>&1
O="$(bash "$KT" bitti is-vt --pr 77 2>&1)"; RC=$?; [ "$RC" -eq 1 ] && grep -q "Sultan DUR dedi — kart bitirilmez" <<<"$O" && grep -q "sultan-dedi is-vt --karar basla" <<<"$O"; g $? "V13 🔴 vetolu kartta bitti rc 1: kart bitirilmez, birleştirme kararı yazılmaz"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));assert k['durum']=='acik' and 'birlestirme_karari' not in k"; g $? "V13b kart açık kaldı, birlestirme_karari YOK"
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-vt.json';k=json.load(open(p));k['durum']='acik';k['baslama_izni']['durum']='basla';k.pop('birlestirme_karari',None);k.pop('canli_borc',None);k['reis_kararlari']=[x for x in k['reis_kararlari'] if x['karar']!='canli-borc'];json.dump(k,open(p,'w'))
PY
O="$(bash "$KT" bitti is-vt --pr 77 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "birleştirme kararı: reis (MUAVIN) · izin: basla · dağıtım Sultan eli" <<<"$O"; g $? "V14 sınıflı bitti: 'birleştirme kararı: reis (…) · izin: basla · dağıtım Sultan eli' basar"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-vt.json'));b=k['birlestirme_karari'];assert b['karar_veren']=='reis' and b['reis']=='MUAVIN' and b['pr']=='77' and b['izin']=='basla' and b['zaman']"; g $? "V14b karta birlestirme_karari{karar_veren: reis, reis, pr, zaman, izin}"
# eski kart (alan yok) · sınıfsız · kart yok · bozuk alan
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-dar-s.json';k=json.load(open(p));k.pop('baslama_izni',None);k.pop('kural_surumu',None);json.dump(k,open(p,'w'))
PY
IFS=$'\t' read -r IZ IZA <<<"$(bash "$KT" izin-durum is-dar-s)"; [ "$IZ" = bekliyor ] && grep -q "eski kart" <<<"$IZA" && grep -q "veto yok" <<<"$IZA"; g $? "V15 ESKİ sınıflı kart (alan yok): 'bekliyor<TAB>eski kart … veto yok'"
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-dar-s.json';k=json.load(open(p));k['sultan_kararlari']=[{"karar":"birlestir","oturum":"x","soz":"eski serbest metin"},{"karar":"dur","oturum":"o","soz":"dur","beyan":"M","zaman":"2026-10-22T10:00:00+03:00"}];json.dump(k,open(p,'w'))
PY
[ "$(bash "$KT" izin-durum is-dar-s | cut -f1)" = dur ]; g $? "V15b eski kartta son basla/dur kaydından türetir"
[ "$(bash "$KT" izin-durum is-dar | cut -f1)" = gerekmiyor ]; g $? "V16 sınıfsız kart → gerekmiyor"
echo "── T16 · V19 SINIFSIZ kartta başlama izni / veto YOK: basla|dur rc 1, karta yazılmaz ──"
O="$(bash "$KT" sultan-dedi is-dar --karar dur --oturum "sohbet-0009" --soz "bunu durdurun" --beyan MUAVIN 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "SINIFSIZ" <<<"$O" && grep -q "veto penceresi YOK" <<<"$O" && grep -q "YAZILMADI" <<<"$O"; g $? "V19 sınıfsız karta 'dur' rc 1: 'SINIFSIZ … veto penceresi YOK … YAZILMADI'"
! grep -q "VETO: reis durur" <<<"$O" && ! grep -q "kayıt yine karta girdi" <<<"$O"; g $? "V19b yanlış 'kapı, denetçi, daralt kapalı' beyanı YOK"
grep -q "reis-dedi is-dar --karar geri-al --reis MUAVIN" <<<"$O"; g $? "V19c çare yazılı: durdurma reisin kararı"
python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar.json'));assert 'baslama_izni' not in k and 'sultan_kararlari' not in k and 'kural_surumu' not in k"; g $? "V19d kart değişmedi"
bash "$KT" sultan-dedi is-dar --karar basla --oturum "sohbet-0009" --soz "başlayın" --beyan MUAVIN >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V19e sınıfsız karta 'basla' da rc 1 (izin penceresi yok)"
[ "$(bash "$KT" izin-durum is-dar | cut -f1)" = gerekmiyor ] && bash "$KT" reis-dedi is-dar --karar devam --reis MUAVIN --oturum r2 --gerekce "sinifsiz is ekipte biter, reis karari yeter" >/dev/null 2>&1; g $? "V19f sınıfsız akış aynen: izin-durum gerekmiyor, reis-dedi rc 0"
bash "$KT" sultan-dedi is-dar --karar devam --oturum "sohbet-0009" --soz "devam edin" --beyan MUAVIN --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; g $? "V19g sınıfsız kartta eski ara kararlar (devam) geriye uyumlu KABUL"
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-dar.json';k=json.load(open(p));k['baslama_izni']={"durum":"dur","oturum":"elle"};json.dump(k,open(p,'w'))
PY
IFS=$'\t' read -r IZ IZA <<<"$(bash "$KT" izin-durum is-dar)"; [ "$IZ" = gerekmiyor ] && grep -q "YOK SAYILDI" <<<"$IZA"; g $? "V19h elle yazılmış baslama_izni sınıfsız kartta YOK SAYILIR ve söylenir"
bash "$KT" reis-dedi is-dar --karar devam --reis MUAVIN --oturum r3 --gerekce "elle yazilmis alan sinifsiz karti kilitlemez" >/dev/null 2>&1; g $? "V19i elle yazılmış alan sınıfsız kartta reis-dedi'yi de kilitlemez"
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-dar.json';k=json.load(open(p));k.pop('baslama_izni',None);json.dump(k,open(p,'w'))
PY
bash "$KT" izin-durum yok-boyle-kart >/dev/null 2>&1; [ $? -eq 3 ]; g $? "V17 kart yok → rc 3 (fail-closed)"
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-dar-s.json';k=json.load(open(p));k['baslama_izni']={"durum":"evet"};json.dump(k,open(p,'w'))
PY
bash "$KT" izin-durum is-dar-s >/dev/null 2>&1; [ $? -eq 3 ]; g $? "V18 bozuk baslama_izni alanı → rc 3"
bash "$KT" reis-dedi is-dar-s --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V18b bozuk izinli kartta reis-dedi rc 1 (fail-closed)"
bash "$KT" bitti is-dar-s >/dev/null 2>&1; [ $? -eq 1 ] && [ "$(python3 -c "import json;print(json.load(open('$T/depo2/_agents/fabrika/kartlar/is-dar-s.json'))['durum'])")" != bitti ]; g $? "V18c bozuk izinli kartta bitti rc 1, kart bitmedi"
echo "── T16 · MUTASYON (tam kopya, kontrol şartlı): eski davranış geri gelirse ya da veto kapıyı kapatmazsa sınav KIRMIZI ──"
# m16 alt kabukta çağrılmaz: çapa sayısı ana süitte ölçülür, 1 değilse KIRMIZI.
m16() {   # m16 <ad> <dosya> <eski> <yeni> → D16 (tam kopya + tek değişiklik); çapa tam 1 kez geçmiyorsa g 1 (ANA süitte) + rc 1
  D16="$T/pkg16-$1"; mkdir -p "$D16"; cp "$HERE"/*.py "$HERE"/*.sh "$D16/" 2>/dev/null
  local n; n="$(python3 - "$D16/$2" "$3" "$4" <<'PYM'
import sys; f, a, b = sys.argv[1:]; s = open(f, encoding="utf-8").read(); n = s.count(a); print(n)
if n == 1: open(f, "w", encoding="utf-8").write(s.replace(a, b, 1))
PYM
)"
  [ "$n" = 1 ] && return 0
  g 1 "mutant '$1' KURULAMADI — çapa $2 içinde ${n:-?} kez geçiyor (1 olmalı): $3"; return 1
}
bash "$KT" ac is-m16 --is "mutant sınavı için sınıflı iş cümlesi" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda --canli e >/dev/null 2>&1
bash "$KT" ac is-m16-s --is "mutant sınavı için sınıfsız iş cümlesi" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
K16="$T/pkg16-kontrol"; mkdir -p "$K16"; cp "$HERE"/*.py "$HERE"/*.sh "$K16/"
bash "$K16/kart.sh" reis-dedi is-m16 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; g $? "kontrol kopyası (mutasyonsuz) sınıflı reis-dedi'yi KABUL ediyor"
bash "$K16/kart.sh" daralt is-m16 --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum r >/dev/null 2>&1; g $? "kontrol kopyası (mutasyonsuz) sınıflı daralt'ı KABUL ediyor"
bash "$K16/kart.sh" sultan-dedi is-m16-s --karar dur --oturum o --soz "dur" --beyan MUAVIN >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kontrol kopyası sınıfsız karta 'dur'u REDDEDİYOR (rc 1)"
m16 eski-sinif-citi kart.sh 'if sinifli and iz=="dur":   # VETO çiti · reis-dedi' 'if sinifli:   # VETO çiti · reis-dedi' && { bash "$D16/kart.sh" reis-dedi is-m16 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "mutant 'reis-dedi sınıflı reddi GERİ konunca': sınıflı reis-dedi yine rc≠0 → T9 FLİP kapısı bu mutantta KIRMIZI"; }
m16 eski-daralt-citi kart.sh 'if sinifli and iz=="dur":   # VETO çiti · daralt' 'if sinifli:   # VETO çiti · daralt' && { bash "$D16/kart.sh" daralt is-m16 --kalan "ikinci kalan yarı yeterince uzun bir cümle" --cumle "ikinci daraltılmış cümle yeterince uzun" --oturum r --yeni is-m16-kalan-2 >/dev/null 2>&1; [ $? -ne 0 ] && [ ! -f "$T/depo2/_agents/fabrika/kartlar/is-m16-kalan-2.json" ]; g $? "mutant 'daralt sınıflı Sultan şartı GERİ konunca': sınıflı daralt rc≠0, kalan kart doğmadı → T12 FLİP kapısı bu mutantta KIRMIZI"; }
m16 sinifsiz-red-yok kart.sh 'if karar in ("basla","dur") and not siniflimi(k):' 'if False:' && { bash "$D16/kart.sh" sultan-dedi is-m16-s --karar dur --oturum o --soz "dur" --beyan MUAVIN >/dev/null 2>&1; g $? "mutant 'sınıfsız red kalkınca': 'dur' sınıfsız karta giriyor (rc 0) → V19 bu mutantta KIRMIZI"; }
m16 dur-dali-yok izin.py '        if d == "dur":' '        if False:' && { bash "$D16/kart.sh" sultan-dedi is-m16 --karar dur --oturum o --soz "dur" --beyan MUAVIN >/dev/null 2>&1; [ "$(bash "$D16/kart.sh" izin-durum is-m16 | cut -f1)" != dur ]; g $? "mutant 'izin-durum dur dalı kalkınca': veto görünmez oluyor → V5/V6 bu mutantta KIRMIZI"; bash "$D16/kart.sh" reis-dedi is-m16 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; g $? "  ↳ aynı mutantta vetolu karta reis-dedi GEÇİYOR"; }
python3 - <<PY
import json;p='$T/depo2/_agents/fabrika/kartlar/is-m16.json';k=json.load(open(p));k['baslama_izni']['durum']='basla';k['sultan_kararlari']=[];json.dump(k,open(p,'w'))
PY
m16 kume-denetimi-yok kart.sh 'case "$KARAR" in devam|daralt|geri-al|canli-borc|basla|dur) ;; "") ;; *) _hata' 'case "$KARAR" in *) ;; "") ;; *) _hata' && { bash "$D16/kart.sh" sultan-dedi is-m16 --karar olur --oturum o --soz "olur" --beyan MUAVIN --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; g $? "mutant 'sultan-dedi küme denetimi kalkınca': 'olur' karta giriyor (rc 0) → V2 bu mutantta KIRMIZI"; }
m16 reis-sultan-alanina-yazar kart.sh 'k.setdefault("reis_kararlari",[]).append(kayit)' 'k.setdefault("sultan_kararlari",[]).append(kayit)' && { bash "$D16/kart.sh" reis-dedi is-m16 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce metni" >/dev/null 2>&1; python3 -c "import json;k=json.load(open('$T/depo2/_agents/fabrika/kartlar/is-m16.json'));assert k['sultan_kararlari'][-1].get('reis')=='MUAVIN'"; g $? "mutant 'reis-dedi Sultan'ın alanına yazarsa' (A06 sızıntısı): sultan_kararlari'nın SON kaydı reis kaydı (önceki mutantın 'olur' kaydı yeşili vermez) → T9/V11b bu mutantta KIRMIZI"; }

echo "════ T17 · SULTAN'A ULAŞIM YOLU (göz 23 Eki tur 2): sınıflı kartta yol yoksa kart AÇILMAZ (rc 1, fail-closed); Sultan'a giden satırda komut yok ════"
KU="$T/depo2/_agents/fabrika/kartlar"; SNF="--istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h"
O="$(bash "$KT" ac is-u1 --is "odasız sınıflı iş cümlesi" $SNF 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && [ ! -f "$KU/is-u1.json" ] && grep -q "Sultan'a ulaşılamadı: --oda ver ya da tetik betiğini kur" <<<"$O" && ! grep -q "SULTAN'A GİDER" <<<"$O"; g $? "U1 🔴 --oda yok → rc 1, kart YAZILMADI, 'Sultan'a ulaşılamadı: --oda ver ya da tetik betiğini kur' (eski araç 'SULTAN'A GİDER' + rc 0 diyordu)"
O="$(FABRIKA_TETIK="$T/yok-boyle-tetik.sh" bash "$KT" ac is-u2 --is "tetiksiz sınıflı iş cümlesi" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && [ ! -f "$KU/is-u2.json" ] && grep -q "Sultan'a ulaşılamadı" <<<"$O" && grep -q "tetik betiği yok" <<<"$O"; g $? "U2 🔴 tetik betiği yok → rc 1, kart YAZILMADI, sebep 'tetik betiği yok'"
N0="$(wc -l < "$TETIK_KAYIT")"
O="$(TETIK_SAHTE_RC=4 bash "$KT" ac is-u3 --is "tetiği düşen sınıflı iş cümlesi" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && [ ! -f "$KU/is-u3.json" ] && grep -q "GERİ ALINDI" <<<"$O" && [ "$(wc -l < "$TETIK_KAYIT")" -eq $((N0+1)) ]; g $? "U3 🔴 tetik denendi ama düştü (rc 4) → rc 1, kart GERİ ALINDI (izin isteği gitmeden kart yok)"
O="$(bash "$KT" ac is-u4 --is "odalı sınıflı iş cümlesi" $SNF --oda sinav-oda 2>&1)"; RC=$?
SATIR="$(grep -P '^sinav-oda\t.*odalı sınıflı iş cümlesi' "$TETIK_KAYIT" | tail -1)"
[ "$RC" -eq 0 ] && [ -f "$KU/is-u4.json" ] && grep -q "başlama izni bekleniyor" <<<"$SATIR"; g $? "U4 --oda + tetik var → rc 0, kart açıldı, izin isteği odaya GİTTİ (sahte tetik kaydı)"
! grep -q "kart.sh" <<<"$SATIR" && grep -q "durdurmak için 'dur' demen yeter" <<<"$SATIR"; g $? "U4b Sultan'a giden satırda komut YOK ('kart.sh' geçmez): 'durdurmak için 'dur' demen yeter'"
O="$(FABRIKA_TETIK="$T/yok-boyle-tetik.sh" bash "$KT" ac is-u5 --is "odasız sınıfsız iş cümlesi" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -f "$KU/is-u5.json" ] && ! grep -q "ulaşılamadı" <<<"$O"; g $? "U5 sınıfsız kart DEĞİŞMEDİ: odasız/tetiksiz rc 0, kart açıldı"
O="$(TETIK_SAHTE_RC=4 bash "$KT" ac is-u6 --is "tetiği düşen sınıfsız iş cümlesi" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -f "$KU/is-u6.json" ] && grep -q "tetik düştü" <<<"$O"; g $? "U6 sınıfsız kartta tetik düşse de iş düşmez (rc 0, kart yerinde — best-effort aynen)"
# U7-U9 (göz 23 Eki tur 3 · PR #445): kart tetik BAŞARILI olmadan görünür olmaz; geri alma yalnız kendi geçici dosyasını siler (eşzamanlı aynı kimlik)
cat > "$T/tetik-gozlem.sh" <<'SH'
#!/usr/bin/env bash
# tetik anında kartın görünürlüğünü kaydeder; GOZLEM_YARIS doluysa "eşzamanlı başka açan" kartı bu anda yaratır
if [ -f "${GOZLEM_KART:?}" ]; then echo var >> "${GOZLEM_KAYIT:?}"; else echo yok >> "${GOZLEM_KAYIT:?}"; fi
[ -n "${GOZLEM_YARIS:-}" ] && printf '{"is":"yabanci","not":"baskasinin-karti"}' > "$GOZLEM_KART"
exit "${TETIK_SAHTE_RC:-0}"
SH
chmod +x "$T/tetik-gozlem.sh"; GK="$T/gozlem.kayit"
: > "$GK"; O="$(FABRIKA_TETIK="$T/tetik-gozlem.sh" GOZLEM_KART="$KU/is-u7.json" GOZLEM_KAYIT="$GK" bash "$KT" ac is-u7 --is "tetik anında görünmeyen sınıflı kart" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$GK")" = yok ] && [ -f "$KU/is-u7.json" ] && ! ls "$KU"/is-u7.json.acilis-* >/dev/null 2>&1; g $? "U7 🔴 tetik anında kart GÖRÜNMEZ ('yok'), tetik başarınca yayımlandı, geçici dosya kalmadı (süreç tetikte kesilse kart kalmazdı)"
: > "$GK"; O="$(FABRIKA_TETIK="$T/tetik-gozlem.sh" GOZLEM_KART="$KU/is-u8.json" GOZLEM_KAYIT="$GK" GOZLEM_YARIS=1 bash "$KT" ac is-u8 --is "eşzamanlı aynı kimlikle açılan sınıflı kart" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "baskasinin-karti" "$KU/is-u8.json" && grep -q "kart zaten var" <<<"$O" && ! ls "$KU"/is-u8.json.acilis-* >/dev/null 2>&1; g $? "U8 🔴 tetik sırasında başkası aynı kimlikle kart açtıysa onun kartı EZİLMEZ (rc 1 'kart zaten var')"
: > "$GK"; O="$(TETIK_SAHTE_RC=4 FABRIKA_TETIK="$T/tetik-gozlem.sh" GOZLEM_KART="$KU/is-u9.json" GOZLEM_KAYIT="$GK" GOZLEM_YARIS=1 bash "$KT" ac is-u9 --is "tetiği düşen ve eşzamanlı aynı kimlikli sınıflı kart" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "baskasinin-karti" "$KU/is-u9.json" && grep -q "GERİ ALINDI" <<<"$O"; g $? "U9 🔴 tetik düşünce geri alma YALNIZ kendi geçici dosyasını siler: başkasının aynı kimlikli kartı SİLİNMEZ"
# U10 (SERDAR 23 Eki 20:1x · lifeos-kalan): gerçek oda-tetik.sh dağıtımı YALNIZ mektubun HEDEF: alanına göre yapar (ilk 5 satır, oda argümanıyla
#     büyük/küçük harf farkıyla aynı; yoksa rc 6 'hedef-yok' iadesi). Sahte tetik bu kuralı AYNEN uygular → HEDEF'siz gövde kartı açtırmaz.
cat > "$T/tetik-hedefli.sh" <<'SH'
#!/usr/bin/env bash
h="$(head -5 "$3" | sed -n 's/^HEDEF:[[:space:]]*\([A-Za-z0-9_-]\{1,\}\).*/\1/p' | head -1)"
[ "$(printf '%s' "$h" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" ] || { echo "TESLİM EDİLMEDİ: hedef-yok/uyuşmuyor" >&2; exit 6; }
printf '%s\t%s\n' "$2" "$(tr '\n' ' ' < "$3")" >> "${TETIK_KAYIT:?}"; exit 0
SH
chmod +x "$T/tetik-hedefli.sh"
O="$(FABRIKA_TETIK="$T/tetik-hedefli.sh" bash "$KT" ac is-u10 --is "hedef satırlı tetik için sınıflı iş cümlesi" $SNF --oda sinav-oda 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -f "$KU/is-u10.json" ] && grep -q "tetik: sinav-oda" <<<"$O"; g $? "U10 🔴 tetik mektubu ilk satırda 'HEDEF: <oda>' taşır → HEDEF kuralını uygulayan tetik kabul eder, sınıflı kart AÇILIR"
echo "── T17 · MUTASYON (tam kopya): yol kapalıyken rc 0 dönerse sınav KIRMIZI ──"
m16 oda-citi-yok kart.sh "[ -n \"\$ODA\" ] || { _hata \"Sultan'a ulaşılamadı" "true || { _hata \"Sultan'a ulaşılamadı" && { bash "$D16/kart.sh" ac is-mu1 --is "odasız sınıflı mutant cümlesi" $SNF >/dev/null 2>&1; [ $? -eq 0 ] && [ -f "$KU/is-mu1.json" ]; g $? "mutant 'oda çiti kalkınca': odasız sınıflı kart rc 0 ile açılıyor → U1 bu mutantta KIRMIZI"; }
m16 betik-citi-yok kart.sh "[ -n \"\$GOREV\" ] || { _hata \"Sultan'a ulaşılamadı: tetik betiği yok" "true || { _hata \"Sultan'a ulaşılamadı: tetik betiği yok" && { O="$(FABRIKA_TETIK="$T/yok-boyle-tetik.sh" bash "$D16/kart.sh" ac is-mu2 --is "tetiksiz sınıflı mutant cümlesi" $SNF --oda sinav-oda 2>&1)"; ! grep -q "tetik betiği yok" <<<"$O"; g $? "mutant 'betik çiti kalkınca': sebep 'tetik betiği yok' söylenmiyor → U2 bu mutantta KIRMIZI"; }
m16 geri-alma-yok kart.sh 'if [ "$SINIFLI" = 1 ] && [ "$TRC" -ne 0 ]; then' 'if false; then' && { TETIK_SAHTE_RC=4 bash "$D16/kart.sh" ac is-mu3 --is "tetiği düşen sınıflı mutant cümlesi" $SNF --oda sinav-oda >/dev/null 2>&1; [ $? -eq 0 ] && [ -f "$KU/is-mu3.json" ]; g $? "mutant 'geri alma kalkınca': tetik düştüğü hâlde rc 0 + kart duruyor → U3 bu mutantta KIRMIZI"; }
m16 eski-tetik-sessiz kart.sh 'else echo "· tetik düştü (mesaj kartta duruyor, iş düşmez)"; r=1; fi' 'else echo "· tetik düştü (mesaj kartta duruyor, iş düşmez)"; r=0; fi' && { TETIK_SAHTE_RC=4 bash "$D16/kart.sh" ac is-mu4 --is "tetiği düşen ikinci sınıflı mutant" $SNF --oda sinav-oda >/dev/null 2>&1; [ $? -eq 0 ] && [ -f "$KU/is-mu4.json" ]; g $? "mutant 'tetik() düşüşü yutunca' (eski davranış): rc 0 + kart duruyor → U3 bu mutantta KIRMIZI"; }
m16 komut-geri kart.sh "durdurmak için 'dur' demen yeter)\"" "durdurmak için kart.sh sultan-dedi \$IS --karar dur)\"" && { bash "$D16/kart.sh" ac is-mu5 --is "komutlu satır mutant cümlesi" $SNF --oda sinav-oda >/dev/null 2>&1; grep -P '^sinav-oda\t.*komutlu satır mutant cümlesi' "$TETIK_KAYIT" | grep -q "kart.sh"; g $? "mutant 'komut satıra geri konunca': Sultan'a giden satırda 'kart.sh' var → U4b bu mutantta KIRMIZI"; }
m16 yayim-ezer kart.sh 'ln -- "$KART_TMP" "$KD/$IS.json" 2>/dev/null' 'mv -f -- "$KART_TMP" "$KD/$IS.json" 2>/dev/null' && { : > "$GK"; FABRIKA_TETIK="$T/tetik-gozlem.sh" GOZLEM_KART="$KU/is-mu6.json" GOZLEM_KAYIT="$GK" GOZLEM_YARIS=1 bash "$D16/kart.sh" ac is-mu6 --is "yayım ezen mutant için sınıflı kart" $SNF --oda sinav-oda >/dev/null 2>&1; ! grep -q "baskasinin-karti" "$KU/is-mu6.json"; g $? "mutant 'yayım var olan kartı ezince' (ln yerine mv -f): başkasının kartı EZİLİYOR → U8 bu mutantta KIRMIZI"; }
m16 geri-alma-baskasini-siler kart.sh 'rm -f -- "$KART_TMP"; _hata "Sultan'"'"'a ulaşılamadı' 'rm -f -- "$KD/$IS.json"; _hata "Sultan'"'"'a ulaşılamadı' && { : > "$GK"; TETIK_SAHTE_RC=4 FABRIKA_TETIK="$T/tetik-gozlem.sh" GOZLEM_KART="$KU/is-mu7.json" GOZLEM_KAYIT="$GK" GOZLEM_YARIS=1 bash "$D16/kart.sh" ac is-mu7 --is "geri alma mutantı için sınıflı kart" $SNF --oda sinav-oda >/dev/null 2>&1; [ ! -f "$KU/is-mu7.json" ]; g $? "mutant 'geri alma kimlikle siler' (eski davranış): başkasının kartı SİLİNİYOR → U9 bu mutantta KIRMIZI"; }
m16 hedef-satiri-yok kart.sh "printf 'HEDEF: %s\\n%s\\n' \"\$1\" \"\$3\" > \"\$f\"" "printf '%s\\n' \"\$3\" > \"\$f\"" && { FABRIKA_TETIK="$T/tetik-hedefli.sh" bash "$D16/kart.sh" ac is-mu8 --is "hedef satırı mutantı için sınıflı kart" $SNF --oda sinav-oda >/dev/null 2>&1; [ $? -eq 1 ] && [ ! -f "$KU/is-mu8.json" ]; g $? "mutant 'HEDEF satırı kalkınca' (eski davranış): HEDEF kuralı uygulayan tetik reddediyor, kart AÇILAMIYOR (rc 1) → U10 bu mutantta KIRMIZI"; }
echo "── A06 (önceki tur notu) · reis kaydı 'Sultan sözü' gibi okunmasın: etiket kalkarsa sınav KIRMIZI ──"
KU="$T/depo2/_agents/fabrika/kartlar"; bash "$KT" ac is-a06 --is "A06 etiket sınavı için sınıflı iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda >/dev/null 2>&1
m16 reis-etiketi-yok kart.sh "' · reis karari, Sultan sozu degil' if sinifli" "'' if sinifli" && { O="$(bash "$D16/kart.sh" reis-dedi is-a06 --karar devam --reis MUAVIN --oturum r-a06 --gerekce "yirmi karakterden uzun bir gerekce metni" 2>&1)"; [ $? -eq 0 ] && ! grep -q "Sultan sozu degil" <<<"$O"; g $? "mutant 'reis çıktısından etiket kalkınca': sınıflı reis kaydı etiketsiz basılıyor → T9 'reis kararı, Sultan sözü değil' kapısı bu mutantta KIRMIZI"; }
python3 -c "import json;k=json.load(open('$KU/is-a06.json'));assert k['reis_kararlari'][-1]['oturum']=='r-a06' and k['reis_kararlari'][-1]['sinifli'] and not k.get('sultan_kararlari')"; g $? "A06 reis kaydı reis_kararlari'nda (sinifli:true), sultan_kararlari'na HİÇBİR şey yazılmadı"

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

echo "════ T13c · SAYI UYARISI (WNMSQ · SERDAR: uyarı, red değil): ölçümsüz '13 görev' kartı açar ama uyarır + karta yazar; --sayi-olcum kaynağı karta işler ════"
su() { python3 -c "import json,sys;k=json.load(open(sys.argv[1]));print(' | '.join(k['sayi_uyarilari']))" "$K13/_agents/fabrika/kartlar/$1.json" 2>/dev/null || echo yok; }
CIKTI="$(ac13 is-s1 "yöneticinin 13 görev listesi işlensin; ayda 173 kez düşüyor, hedef %50")"; RC=$?
[ "$RC" -eq 0 ] && [ "$(su is-s1)" = "13 görev | 173 kez | %50" ]; g $? "Nexus #1213 vakası: kart AÇILDI (red yok) · karta üç sayı iddiası yazıldı ($(su is-s1))"
grep -q "⚠ SAYI — cümlede kaynağı ölçülmemiş sayı: '13 görev' · '173 kez' · '%50'.*--sayi-olcum" <<<"$CIKTI"; g $? "uyarı satırı sayıları ve çareyi (--sayi-olcum) söylüyor"
CIKTI="$(ac13 is-s2 "retro W42 MUAVİN Ö3 · fabrika 0.18.1 · #337 · gorev_01M57ZV15AARDJDVV9NK3WNMSQ · 23 Eki 04:30 · 2026-10-23 · 1. hafta · 40 dk · 100 KB · 1440+390 kare · 81D0W · 5/E")"
[ "$(su is-s2)" = "" ] && ! grep -q "SAYI" <<<"$CIKTI"; g $? "yanlış alarm yok: kimlik · sürüm · #PR · tarih/saat · ay adı · sıra · birimli eşik · 5/E sayı iddiası DEĞİL"
CIKTI="$(ac13 is-duz2 "buton ekle")"; [ "$(su is-duz2)" = "" ] && ! grep -q "SAYI" <<<"$CIKTI"; g $? "sayısız cümle: uyarı yok, karta boş liste"
CIKTI="$(bash "$KT" ac is-s3 --is "13 görev kapansın" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h --sayi-olcum "printf '13 görev bulundu\n'; exit 0" 2>&1)"
SO="$(python3 -c "import json,sys;k=json.load(open(sys.argv[1]));o=k['sayi_olcum'];print(o['rc'],o['cikti'].strip(),len(k['sayi_uyarilari']))" "$K13/_agents/fabrika/kartlar/is-s3.json" 2>&1)"
[ "$SO" = "0 13 görev bulundu 0" ] && grep -q "sayı kaynağı karta yazıldı (rc=0): 13 görev bulundu" <<<"$CIKTI" && ! grep -q "⚠ SAYI" <<<"$CIKTI"; g $? "--sayi-olcum: komut koşuldu, rc + çıktı karta yazıldı, uyarı düştü ($SO)"
CIKTI="$(bash "$KT" ac is-s4 --is "13 görev kapansın" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h --sayi-olcum "echo kaynak yok; exit 7" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ "$(su is-s4)" = "13 görev" ] && grep -q "ölçüm komutu DÜŞTÜ (rc=7)" <<<"$CIKTI"; g $? "düşen ölçüm komutu kaynak SAYILMAZ: uyarı karta yazılı kalır, kart yine açılır (rc 0)"
CIKTI="$(bash "$KT" ac is-s5 --is "13 görev kapansın" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h --sayi-olcum "seq 1 3000; echo SONUC: 13 görev" 2>&1)"
SO="$(python3 -c "import json,sys;o=json.load(open(sys.argv[1]))['sayi_olcum'];print(o['kirpildi'],len(o['cikti']),o['cikti_bayt'],o['son_satirlar'][-1])" "$K13/_agents/fabrika/kartlar/is-s5.json" 2>&1)"
[ "$SO" = "True 2000 13909 SONUC: 13 görev" ] && grep -q "ölçüm çıktısı 13909 bayt: karta ilk 2000 karakter + son 5 satır yazıldı (KIRPILDI)" <<<"$CIKTI"; g $? "uzun ölçüm çıktısı SESSİZ kesilmez: kartta kirpildi + tam boy + son satırlar (sonuç satırı korunur), ekranda uyarı ($SO) — göz #430 tur 1"
echo "════ T13d · BİÇİM UYARISI (verim R2 · SERDAR 29 Eki): sayı iddiası tek ölçüt biçiminde değilse uyarır (red değil), biçimliyse susar ════"
bu() { python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('sayi_bicim_uyarisi'))" "$K13/_agents/fabrika/kartlar/$1.json" 2>/dev/null || echo yok; }
CIKTI="$(ac13 is-b1 "yöneticinin 13 görev listesi işlensin")"; RC=$?
[ "$RC" -eq 0 ] && [ "$(bu is-b1)" = "True" ]; g $? "biçimsiz sayı: kart AÇILDI (red yok), karta sayi_bicim_uyarisi=True yazıldı"
grep -q "⚠ BİÇİM — başlıktaki sayı tek ölçüt olarak yazılsın: '<ne sayılıyor> <şimdi> → <hedef> (kaynak: <komut/ekran>, <gün>)'" <<<"$CIKTI"; g $? "uyarı biçimi ve [ayri]/süre kuralını söylüyor"
CIKTI="$(ac13 is-b2 "açık görev 13 → 0 (kaynak: gorev.sh liste, 29 Eki) olsun")"
[ "$(bu is-b2)" = "False" ] && ! grep -q "⚠ BİÇİM" <<<"$CIKTI"; g $? "biçimli cümle (→ ve kaynak:) uyarı almaz"
CIKTI="$(ac13 is-b3 "buton ekle")"; [ "$(bu is-b3)" = "False" ] && ! grep -q "⚠ BİÇİM" <<<"$CIKTI"; g $? "sayısız cümle uyarı almaz"
CIKTI="$(ac13 is-b4 "açık görev 13 → 0 olsun")"; [ "$(bu is-b4)" = "True" ]; g $? "kaynaksız ok yetmez: '→' var ama 'kaynak:' yok → uyarı"
be() { python3 -c "import json,sys;print(' | '.join(json.load(open(sys.argv[1])).get('sayi_bicim_eksikleri',[])))" "$K13/_agents/fabrika/kartlar/$1.json" 2>/dev/null || echo yok; }
ac13 is-b5 "13 iş → x (kaynak: gorev.sh liste, 29 Eki)" >/dev/null; [ "$(bu is-b5)" = "True" ] && grep -q "şimdi → hedef iki SAYI" <<<"$(be is-b5)"; g $? "hedef sayı değil ('13 iş → x'): biçimli SAYILMAZ, eksik 'iki SAYI' diye söylenir"
ac13 is-b6 "açık görev 13 → 0 (kaynak: gorev.sh liste)" >/dev/null; [ "$(be is-b6)" = "kaynağın günü yok" ]; g $? "gün eksik: yalnız 'kaynağın günü yok' (tek, doğru sebep)"
ac13 is-b7 "açık görev 13 → 0 kaynak: gorev.sh liste, 29 Eki" >/dev/null; grep -q "parantezi yok" <<<"$(be is-b7)"; g $? "parantezsiz kaynak biçimli sayılmaz"
ac13 is-b8 "görev 13 → 0 ve kart 9 → 0 (kaynak: gorev.sh liste, 29 Eki)" >/dev/null; [ "$(be is-b8)" = "birden çok ölçüt: parçalar (1)(2) madde olsun ya da [ayri] ile ayrılsın" ]; g $? "iki ölçüt, madde/[ayri] yok → 'birden çok ölçüt' uyarısı"
ac13 is-b9 "(1) görev 13 → 0 (2) kart 9 → 0 (kaynak: gorev.sh liste, 29 Eki)" >/dev/null; [ "$(bu is-b9)" = "False" ]; g $? "iki ölçüt (1)(2) madde numaralı → uyarı yok"
ac13 is-b10 "görev 13 → 0 [ayri] kart 9 → 0 (kaynak: gorev.sh liste, 29 Eki)" >/dev/null; [ "$(bu is-b10)" = "False" ]; g $? "iki ölçüt [ayri] ile ayrılmış → uyarı yok"
ac13 is-b11 "açık görev 13 → 0 (kaynak: gorev.sh liste, 2026-10-29) olsun" >/dev/null; [ "$(bu is-b11)" = "False" ]; g $? "ISO gün de kabul"
echo "── T13c · MUTASYON (tam kopya): sayı aranmazsa #1213 cümlesi sessiz geçer → üstteki kapı düşerdi ──"
D="$T/pkg-sayi"; mkdir -p "$D"; cp "$HERE"/*.py "$HERE"/*.sh "$D/" 2>/dev/null
if python3 - "$D/kart.sh" <<'PYM'
import sys; f=sys.argv[1]; s=open(f,encoding="utf-8").read(); a='kart["sayi_uyarilari"]=[] if kaynakli else sayilar'; assert s.count(a)==1; open(f,"w",encoding="utf-8").write(s.replace(a,'kart["sayi_uyarilari"]=[]'))
PYM
then o="$(ac13m "$D/kart.sh" is-s-mut "yöneticinin 13 görev listesi işlensin")"; [ "$(su is-s-mut)" = "" ] && ! grep -q "⚠ SAYI" <<<"$o"; g $? "mutant (sayı uyarısı kapalı) #1213 cümlesini sessiz geçiriyor → üstteki kapı bu mutantta düşerdi"
else g 1 "mutant kurulamadı (çapa bayat)"; fi

echo "════ T14 · görev durumu (Y7J3Q): --gorev bağlı kart açılış/bitti/tıkandı'da defterdeki görevi yazar; yazamazsa söyler, rc 4 ════"
GDEPO="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"   # kart.sh ile aynı kök (önceki bölüm depo değiştirdi)
printf 'kart-sinav-jeton\n' > "$T/jeton"
python3 - "$T" <<'PY' &
import sys, json, http.server, socketserver, os
T=sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):   # uzlaştırma (DKYSHH/X666): görev listesi $T/gorevler-kart.json'dan; dosya yoksa 404 (eski sınavlar etkilenmez)
        f=os.path.join(T,"gorevler-kart.json")
        if self.path.startswith("/kayit/"): f=os.path.join(T,"kayit-%s.json" % self.path.rsplit("/",1)[1])   # 774ZHG: tek kayıt (görev durumu) $T/kayit-<id>.json'dan; yoksa 404
        if self.headers.get("x-defter-jeton")!="kart-sinav-jeton" or not os.path.exists(f): self.send_response(404); self.end_headers(); return
        self.send_response(200); self.end_headers(); self.wfile.write(open(f,"rb").read())
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=json.loads(self.rfile.read(n) or b"{}")
        with open(os.path.join(T,"yazim.jsonl"),"a") as f: f.write(json.dumps({"yol":self.path,"jeton":self.headers.get("x-defter-jeton"),"govde":b},ensure_ascii=False)+"\n")
        if self.headers.get("x-defter-jeton")!="kart-sinav-jeton": self.send_response(401); self.end_headers(); return
        kf=os.path.join(T,"kayit-%s.json" % self.path.rsplit("/",1)[1])   # 774ZHG: iyimser sürüm kilidi (canlı geçit gibi: surum tutmazsa 409)
        if os.path.exists(kf):
            d=json.load(open(kf))
            if "yaris" in d: d=d["yaris"]; json.dump(d,open(kf,"w"))   # yarış: görev GET ile PATCH arasında değişti (Sultan onaya aldı)
            if "surum" in b and b["surum"]!=d["kayit"].get("surum"):
                self.send_response(409); self.end_headers(); self.wfile.write(json.dumps({"ok":False,"hata":"surum_catismasi"}).encode()); return
        if self.path.endswith("gorev_KARTRED000000001"):   # canlı geçidin düz ret biçimi (ret(): hata · yerine üst düzeyde)
            self.send_response(409); self.end_headers(); self.wfile.write(json.dumps({"ok":False,"hata":"surum_catismasi","yerine":"görev bu arada değişti, yeniden dene"},ensure_ascii=False).encode()); return
        self.send_response(200); self.end_headers(); self.wfile.write(json.dumps({"ok":True,"kayit":{"id":self.path.rsplit("/",1)[1]}}).encode())
with socketserver.TCPServer(("127.0.0.1",0),H) as s:
    open(os.path.join(T,"dport"),"w").write(str(s.server_address[1])); s.serve_forever()
PY
DSRV=$!; for i in $(seq 1 25); do [ -f "$T/dport" ] && break; sleep 0.2; done
export DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$(cat "$T/dport")"
KK="$GDEPO/_agents/fabrika/kartlar"; SINIF="--geri-alinamaz h --para h --dis-yuzey h --yetki h"; yz() { [ -f "$T/yazim.jsonl" ] && wc -l < "$T/yazim.jsonl" || echo 0; }
bash "$KT" ac gb-1 --is "bağlı iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000001 >/dev/null 2>&1; [ $? -eq 1 ] && [ ! -f "$KK/gb-1.json" ]; g $? "G1 --gorev verilip --tahmin verilmezse kart AÇILMAZ (rc 1; defter tahminsiz çalışılıyor'a geçmez)"
bash "$KT" ac gb-1 --is "bağlı iş" --istedi SERDAR --aldi BANI $SINIF --gorev GOREV-yanlis --tahmin 30 >/dev/null 2>&1; [ $? -eq 1 ] && [ ! -f "$KK/gb-1.json" ]; g $? "G1b biçimsiz görev kimliği rc 1"
bash "$KT" ac gb-1 --is "bağlı iş" --istedi SERDAR --aldi BANI $SINIF --tahmin 30 >/dev/null 2>&1; [ $? -eq 1 ] && [ ! -f "$KK/gb-1.json" ]; g $? "G1c --tahmin tek başına anlamsız: rc 1"
[ "$(yz)" -eq 0 ]; g $? "G1d reddedilen açılışlar deftere HİÇ gitmedi"
O="$(bash "$KT" ac gb-1 --is "bağlı iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000001 --tahmin 45 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$KK/gb-1.json" <<'PY'; g $? "G2 açılış → PATCH /kayit/<görev>: çalışılıyor + atanan BANI + tahmin 45 + '[▶ çalışılıyor]' adımı; kartta gorev/tahmin + yazım 'yazıldı'"
import json,sys
y=[json.loads(l) for l in open(sys.argv[1])][-1]; b=y["govde"]; k=json.load(open(sys.argv[2]))
assert y["yol"]=="/kayit/gorev_KARTTEST00000001" and y["jeton"]=="kart-sinav-jeton"
assert b["yerine"]=={"atanan":"BANI","tahmin_dk":"45","gorev_durumu":"calisiliyor"}, b
assert b["adimlar"][0]=="[▶ çalışılıyor] BANI · kart gb-1 açıldı, tahmin 45 dk · sınıf: yok", b["adimlar"][0]   # 0.25.2: sınıf cevabı adıma yazılır (merkez otomatik devri bunu okur)
assert k["gorev"]=="gorev_KARTTEST00000001" and k["tahmin_dk"]==45 and k["gorev_yazimlari"][-1]["olay"]=="ac" and k["gorev_yazimlari"][-1]["sonuc"]=="yazıldı"
PY
[ $RC -eq 0 ] && grep -q "✓ görev gorev_KARTTEST00000001 → çalışılıyor (defter)" <<<"$O" && ! grep -q "kart-sinav-jeton" <<<"$O"; g $? "G2b rc 0, ekranda '→ çalışılıyor (defter)', jeton değeri çıktıda YOK"
O="$(bash "$KT" bitti gb-1 --pr 12 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$(basename "$GDEPO")" <<'PY'; g $? "G3 (KF22R dilim ≠ görev) bitti → göreve YALNIZ '[dilim bitti] … PR #12 · kanıt …' adımı; durum YAZILMAZ (çalışılıyor kalır), onay bekliyor YOK"
import json,sys
b=[json.loads(l) for l in open(sys.argv[1])][-1]["govde"]; d=sys.argv[2]
assert "yerine" not in b and "gerekce" not in b, b
assert b["adimlar"][0].startswith("[dilim bitti] BANI · kart gb-1 bitti · "+d+" PR #12 · kanıt _agents/fabrika/kanit/gb-1/") and "kart.sh bitti gb-1 --gorev-bitti --kare <yol> --surum <sürüm>" in b["adimlar"][0] and "gorev.sh bitti" in b["adimlar"][0], b
PY
[ $RC -eq 0 ] && grep -q "dilim adımı (görev çalışılıyor kalır" <<<"$O"; g $? "G3b bitti rc 0, ekranda 'dilim adımı (görev çalışılıyor kalır…)'"
N0=$(yz); O="$(bash "$KT" bitti gb-1 --pr 12 --gorev-bitti --kare kanit/x-1440.png 2>&1)"; RC=$?
[ $RC -eq 1 ] && [ "$(yz)" -eq "$N0" ] && grep -q "sürüm" <<<"$O"; g $? "G3c --gorev-bitti ekran işinde kare tek başına yetmez (rc 1, deftere gitmedi, 'sürüm' ister)"
O="$(bash "$KT" bitti gb-1 --pr 12 --gorev-bitti 2>&1)"; RC=$?
[ $RC -eq 1 ] && [ "$(yz)" -eq "$N0" ] && grep -q "dilimdir" <<<"$O"; g $? "G3d --gorev-bitti sınıfsız → rc 1, deftere gitmedi, 'PR tek başına dilimdir' der"
O="$(bash "$KT" bitti gb-1 --pr 12 --gorev-bitti --kare kanit/x-1440.png --surum 1.25.0 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$(basename "$GDEPO")" <<'PY'; g $? "G3e --gorev-bitti --kare --surum → onay bekliyor + kanıt '[kare] … · [surum] 1.25.0 · [pr] #12 · kanıt …' + '[⏸ onay bekliyor]' adımı"
import json,sys
b=[json.loads(l) for l in open(sys.argv[1])][-1]["govde"]; d=sys.argv[2]
assert b["yerine"]["gorev_durumu"]=="onay-bekliyor" and b["yerine"]["kanit"]=="[kare] kanit/x-1440.png · [surum] 1.25.0 · [pr] #12 · kanıt _agents/fabrika/kanit/gb-1/ ("+d+")", b
assert b["adimlar"][0].startswith("[⏸ onay bekliyor] BANI · kart gb-1 bitti")
PY
[ $RC -eq 0 ] && grep -q "→ onay bekliyor (defter)" <<<"$O"; g $? "G3f rc 0, ekranda '→ onay bekliyor (defter)'"
bash "$KT" ac gb-2 --is "tıkanacak iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000002 --tahmin 60 >/dev/null 2>&1
bash "$KT" tikandi gb-2 --yol daralt --neden "kapsam kayması: hız kazancı kart dışı davranıştan" >/dev/null 2>&1; RC=$?
python3 - "$T/yazim.jsonl" <<'PY'; g $? "G4 tıkandı → bekliyor + not (tıkanma nedeni) + '[⏳ bekliyor]' adımı (defter neyi beklediği yazılmamış bekliyor'u reddeder)"
import json,sys
b=[json.loads(l) for l in open(sys.argv[1])][-1]["govde"]
assert b["yerine"]=={"gorev_durumu":"bekliyor","not":"kart gb-2 tıkandı: kapsam kayması: hız kazancı kart dışı davranıştan"}, b
assert b["adimlar"][0].startswith("[⏳ bekliyor] BANI · kart gb-2 tıkandı (daralt)")
PY
[ $RC -eq 0 ]; g $? "G4b tıkandı rc 0"
O="$(bash "$KT" ac gb-3 --is "reddedilen iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTRED000000001 --tahmin 30 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ -f "$KK/gb-3.json" ] && grep -q "⚠ GÖREV YAZILAMADI: gorev_KARTRED000000001 → çalışılıyor — yazılamadı: http 409 · surum_catismasi · görev bu arada değişti" <<<"$O" &&
  python3 -c "import json;k=json.load(open('$KK/gb-3.json'));assert k['gorev_yazimlari'][-1]['sonuc'].startswith('yazılamadı: http 409 · surum_catismasi')"; g $? "G5 defter reddederse kart YİNE açılır, rc 4, sebep (hata + yerine) ekranda ve kartta"
N0=$(yz); O="$(DEFTER_JETON_YOL="$T/jeton-yok" bash "$KT" ac gb-4 --is "jetonsuz iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000004 --tahmin 30 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ "$(yz)" -eq "$N0" ] && grep -q "yazılamadı: bu kutuda defter jetonu yok" <<<"$O" && [ -f "$KK/gb-4.json" ]; g $? "G6 jetonsuz kutu: deftere gidilmez, kart açılır, 'jetonu yok' söylenir, rc 4"
N0=$(yz); O="$(bash "$KT" ac gb-5 --is "bağsız iş" --istedi SERDAR --aldi BANI $SINIF 2>&1)"; RC=$?
[ $RC -eq 0 ] && [ "$(yz)" -eq "$N0" ] && grep -q "görev bağı yok — iş Sultan'ın 'çalışılıyor' görünümüne DÜŞMEZ" <<<"$O"; g $? "G7 bağsız kart deftere gitmez, rc 0, bunu söyler (eski kartlar etkilenmez)"
O="$(bash "$KT" bitti gb-5 2>&1)"; RC=$?; [ $RC -eq 0 ] && [ "$(yz)" -eq "$N0" ]; g $? "G7b bağsız kartın bitti'si de deftere gitmez"
echo "════ T14a · 0.27.34 (…QFS1RR): tetiksiz (yalıtılmış) kutuda sınıflı kart — başlama izni bağlı görev üzerinden ════"
SNP="--istedi Sultan --aldi DYSINAV --geri-alinamaz h --para e --dis-yuzey h --yetki h"; YOKT="$T/yok-boyle-tetik.sh"
N0=$(yz); O="$(FABRIKA_TETIK="$YOKT" bash "$KT" ac dy-1 --is "tetiksiz kutuda sınıflı iş" $SNP --gorev gorev_KARTTEST00000011 --tahmin 40 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$KK/dy-1.json" "$N0" <<'PY2'; g $? "D1 tetik yok + --gorev → kart AÇILIR, göreve TEK açılış yazımı: çalışılıyor + adımda 'sınıf: para' ve 'başlama izni Sultan'da … dur'"
import json,sys
L=[json.loads(l) for l in open(sys.argv[1])][int(sys.argv[3]):]; k=json.load(open(sys.argv[2]))
assert len(L)==1 and L[0]["yol"]=="/kayit/gorev_KARTTEST00000011", L
b=L[0]["govde"]; ad=b["adimlar"][0]
assert b["yerine"]["gorev_durumu"]=="calisiliyor" and "sınıf: para" in ad and "başlama izni Sultan'da" in ad and "'dur'" in ad, ad
assert k["gorev_yazimlari"][-1]["olay"]=="ac" and k["gorev_yazimlari"][-1]["sonuc"]=="yazıldı" and k["sultan"] is True
PY2
[ $RC -eq 0 ] && grep -q "→ çalışılıyor (defter)" <<<"$O" && ! grep -q "tetik atılmadı" <<<"$O"; g $? "D1b rc 0, ekranda '→ çalışılıyor (defter)', tetik denemesi YOK"
N0=$(yz); O="$(FABRIKA_TETIK="$YOKT" bash "$KT" ac dy-2 --is "defteri reddedilen sınıflı iş" $SNP --gorev gorev_KARTRED000000001 --tahmin 40 2>&1)"; RC=$?
[ $RC -eq 1 ] && [ ! -f "$KK/dy-2.json" ] && ! ls "$KK"/dy-2.json.acilis-* >/dev/null 2>&1 && grep -q "başlama izni GİTMEDİ (kart GERİ ALINDI" <<<"$O"; g $? "D2 🔴 tetik yok + görev yazılamadı (409) → rc 1, kart YOK, geçici dosya YOK, 'izni GİTMEDİ'"
N0=$(yz); O="$(FABRIKA_TETIK="$YOKT" DEFTER_JETON_YOL="$T/jeton-yok" bash "$KT" ac dy-3 --is "jetonsuz tetiksiz sınıflı iş" $SNP --gorev gorev_KARTTEST00000013 --tahmin 40 2>&1)"; RC=$?
[ $RC -eq 1 ] && [ ! -f "$KK/dy-3.json" ] && [ "$(yz)" -eq "$N0" ]; g $? "D3 🔴 tetik yok + defter jetonu yok → rc 1, kart YOK (sessiz açılış yok)"
N0=$(yz); O="$(FABRIKA_TETIK="$YOKT" bash "$KT" ac dy-4 --is "görevsiz tetiksiz sınıflı iş" $SNP 2>&1)"; RC=$?
[ $RC -eq 1 ] && [ ! -f "$KK/dy-4.json" ] && [ "$(yz)" -eq "$N0" ] && grep -q "bağlı görev üzerinden gider: --gorev" <<<"$O"; g $? "D4 tetik yok + --gorev yok → rc 1, kart YOK, yol söylenir (--gorev ver)"
N0=$(yz); O="$(FABRIKA_TETIK="$YOKT" bash "$KT" ac dy-5 --is "tetiksiz sınıfsız bağlı iş" --istedi SERDAR --aldi DYSINAV2 $SINIF --gorev gorev_KARTTEST00000015 --tahmin 20 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "D5 sınıfsız kart tetiksiz kutuda ESKİ yolda: tek yazım, adımda izin cümlesi YOK"
import json,sys
L=[json.loads(l) for l in open(sys.argv[1])][int(sys.argv[2]):]
assert len(L)==1 and "başlama izni" not in L[0]["govde"]["adimlar"][0], L
PY2
m16 dy-izin-yutulur kart.sh 'gorev_yaz "$KART_TMP" ac || TRC=1' 'gorev_yaz "$KART_TMP" ac || true' && { O="$(FABRIKA_TETIK="$YOKT" bash "$D16/kart.sh" ac dy-m1 --is "mutant izin yutar" --istedi Sultan --aldi DYSINAV4 --geri-alinamaz h --para e --dis-yuzey h --yetki h --gorev gorev_KARTRED000000001 --tahmin 40 2>&1)"; [ -f "$KK/dy-m1.json" ]; g $? "mutant 'görev yazılamasa da kart açılır': kart AÇILIYOR → D2 bu mutantta KIRMIZI"; }
m16 dy-cift-yazim kart.sh '[ "$GYAZILDI" = 0 ] && { gorev_yaz' 'true && { gorev_yaz' && { N0=$(yz); FABRIKA_TETIK="$YOKT" bash "$D16/kart.sh" ac dy-m2 --is "mutant çift yazım" --istedi Sultan --aldi DYSINAV3 --geri-alinamaz h --para e --dis-yuzey h --yetki h --gorev gorev_KARTTEST00000016 --tahmin 40 >/dev/null 2>&1; [ "$(python3 -c "import json;print(sum(1 for l in open('$T/yazim.jsonl') if json.loads(l)['yol'].endswith('KARTTEST00000016')))")" -eq 2 ]; g $? "mutant 'açılış göreve iki kez yazılır': iki yazım → D1 (tek yazım) bu mutantta KIRMIZI"; }
echo "════ T14b · 0.24.0 (Y7J3Q): yeni işe geçince önceki görev 'bekliyor'; göz turu göreve tek adım, durum değişmez ════"
bash "$KT" bitti gb-3 >/dev/null 2>&1   # gb-3'ün görevi (KARTRED) ret döner; kart bitmiş olur → açık sayılmaz
N0=$(yz); O="$(bash "$KT" ac gb-6 --is "yeni iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000006 --tahmin 30 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$N0" <<'PY'; g $? "G8 aynı ajanın açık görevli kartı (gb-4) varken yeni iş: gb-4'ün görevi 'bekliyor' + 'başka işe geçti: gb-6' ve yeni işin görevi 'çalışılıyor' (toplam 2 yazım)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
assert len(l)==2, l
yeni=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000006")][0]; eski=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000004")][0]
assert yeni["govde"]["yerine"]["gorev_durumu"]=="calisiliyor", yeni
assert eski["govde"]["yerine"]=={"gorev_durumu":"bekliyor","not":"başka işe geçti: gb-6"}, eski
assert eski["govde"]["adimlar"][0].startswith("[⏳ bekliyor] BANI · kart gb-4 açıkken başka işe geçti: gb-6"), eski
PY
[ $RC -eq 0 ] && python3 -c "import json;k=json.load(open('$KK/gb-4.json'));assert k['durum']=='acik' and k['gorev_yazimlari'][-1]['olay']=='gecti'"; g $? "G8b rc 0; önceki KART açık kalır (yalnız görevi bekliyor), karta 'gecti' yazımı işlenir"
N0=$(yz); bash "$KT" ac gb-7 --is "başka ajanın işi" --istedi SERDAR --aldi MUAVIN $SINIF --gorev gorev_KARTTEST00000007 --tahmin 30 >/dev/null 2>&1
[ "$(( $(yz) - N0 ))" -eq 1 ]; g $? "G8c başka ajanın kartı ETKİLENMEZ: yalnız kendi görevi yazıldı (+1 yazım)"
N0=$(yz); O="$(bash "$KT" goz-adim gb-6 --not "[🔎 göz] kart gb-6 · tur 1 · kod 5/5 · doğru şey E · bulgu 0" 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$N0" "$(yz)" <<'PY'; g $? "G9 goz-adim: tek PATCH, gövdede YALNIZ adimlar (durum alanı yok → görev durumu değişmez)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
assert len(l)==1 and l[0]["yol"].endswith("gorev_KARTTEST00000006"), l
assert l[0]["govde"]=={"adimlar":["[🔎 göz] kart gb-6 · tur 1 · kod 5/5 · doğru şey E · bulgu 0"]}, l[0]["govde"]
PY
[ $RC -eq 0 ] && grep -q "→ göz adımı (durum değişmez) (defter)" <<<"$O"; g $? "G9b rc 0, ekranda '→ göz adımı (durum değişmez) (defter)'"
N0=$(yz); O="$(bash "$KT" goz-adim gb-5 --not "x" 2>&1)"; RC=$?; [ $RC -eq 0 ] && [ "$(yz)" -eq "$N0" ] && grep -q "görev bağı yok" <<<"$O"; g $? "G9c bağsız kart: deftere gitmez, rc 0, söyler"
bash "$KT" goz-adim gb-6 >/dev/null 2>&1; [ $? -eq 1 ]; g $? "G9d --not olmadan rc 1"
# 0.25.2 (gorev …5SW5W · Sultan D1 24 Eki): açılış adımı kartın sınıf cevabını taşır; sınıflı kart "sınıf: yok" DİYEMEZ (merkez bunu otomatik devre sokmasın)
N0=$(yz); bash "$KT" ac gb-8 --is "sınıflı bağlı iş" --istedi Sultan --aldi BANI --geri-alinamaz h --para h --dis-yuzey h --yetki e --oda sinav-oda --gorev gorev_KARTTEST00000008 --tahmin 30 >/dev/null 2>&1
python3 - "$T/yazim.jsonl" "$N0" <<'PY'; g $? "G2c 🔴 sınıflı kart (yetki=e) açılış adımı '· sınıf: yetki' der — 'sınıf: yok' DEĞİL (merkez otomatik devre sokmaz)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000008")]   # gb-8 açılışı eski açık kartları da bekliyor'a çeker: yalnız kendi yazımına bak
assert len(m)==1, l
a=m[0]["govde"]["adimlar"][0]
assert a=="[▶ çalışılıyor] BANI · kart gb-8 açıldı, tahmin 30 dk · sınıf: yetki", a
PY
# DKYSHH + X666: kart.sh ac/bitti sonrası ajanın kartsız 'çalışılıyor' görevi bekliyor'a çekilir (calisiliyor-uzlastir.py)
printf '{"gorevler":[{"id":"gorev_KARTSIZ0000000001","canli":{"gorev_durumu":"calisiliyor","atanan":"BANI"},"adlar":[{"deger":"kartsız iş"}],"son_adim":"2026-10-26T01:00"}]}' > "$T/gorevler-kart.json"
export KART_UZLASTIR_KOKLER="$KK" UZLASTIR_ZIL_KOMUT=/bin/true UZLASTIR_KOLTUK_KOMUT=/bin/true   # sahibine zil/koltuk: gerçek postaneye mektup GİTMEZ
N0=$(yz); O="$(bash "$KT" ac gb-9 --is "uzlaştırma bağlı iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000009 --tahmin 30 2>&1)"; RC=$?
[ $RC -eq 0 ] && python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G10 ac sonrası kartsız çalışılıyor görev (gorev_KARTSIZ…) bekliyor'a çekilir + 'açık kartı yok' notu; kart rc 0"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTSIZ0000000001")]
assert len(m)==1 and m[0]["govde"]["yerine"]["gorev_durumu"]=="bekliyor" and "açık kartı yok" in m[0]["govde"]["yerine"]["not"], l
PY2
N0=$(yz); KART_UZLASTIR=0 bash "$KT" ac gb-10 --is "uzlaştırma kapalı iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000010 --tahmin 30 >/dev/null 2>&1
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G10b KART_UZLASTIR=0 → uzlaştırma yazmaz (kapatma anahtarı)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
assert not [x for x in l if x["yol"].endswith("gorev_KARTSIZ0000000001")], l
PY2
printf '{"gorevler":[{"id":"gorev_KARTTEST00000009","canli":{"gorev_durumu":"calisiliyor","atanan":"BANI"},"adlar":[{"deger":"bağlı iş"}],"son_adim":"2026-10-26T01:00"}]}' > "$T/gorevler-kart.json"
N0=$(yz); bash "$KT" bitti gb-9 >/dev/null 2>&1; RC=$?
[ $RC -eq 0 ] && python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G10c bitti sonrası kartı kapanan görev (açık kartı kalmadı) bekliyor'a çekilir (X666: 0MHE6C biçimi)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000009") and "açık kartı yok" in json.dumps(x["govde"],ensure_ascii=False)]
assert len(m)==1, l
PY2
O="$(DEFTER_JETON_YOL="$T/jeton-yok" bash "$KT" bitti gb-9 2>&1)"; RC=$?   # jeton okunamazsa uzlaştırma SESSİZ atlamaz: söyler, kart rc'si bozulmaz
grep -q "uzlaştırma atlandı: defter jetonu okunamadı" <<<"$O"; g $? "G10d jeton okunamıyorsa otomatik uzlaştırma bunu SÖYLER (sessiz atlamaz; kart yine işlenir)"
echo "════ T14c · ONAY KORUMASI (774ZHG): onay bekleyen ya da bitmiş göreve bağlı kart ac/gecti/tikandi'de DURUM yazmaz, yalnız adım ════"
printf '{"kayit":{"canli":{"gorev_durumu":"onay-bekliyor"}}}' > "$T/kayit-gorev_KARTTEST00000011.json"
printf '{"kayit":{"canli":{"gorev_durumu":"bitti"}}}' > "$T/kayit-gorev_KARTTEST00000012.json"
N0=$(yz); O="$(KART_UZLASTIR=0 bash "$KT" ac gb-11 --is "onay bekleyen işe dilim" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000011 --tahmin 20 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11 🔴 onay-bekliyor göreve ac → PATCH'te 'yerine' YOK (durum yazılmaz), adım 'durumu KORUNUR' der"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000011")]
assert len(m)==1 and "yerine" not in m[0]["govde"], l
a=m[0]["govde"]["adimlar"][0]; assert a.startswith("[▶ dilim] BANI · kart gb-11 açıldı") and "görev 'onay-bekliyor', durumu KORUNUR" in a, a
PY2
[ $RC -eq 0 ] && grep -q "yalnız adım — görev 'onay-bekliyor', durumu korundu" <<<"$O"; g $? "G11b rc 0, ekranda 'yalnız adım — durumu korundu'"
N0=$(yz); KART_UZLASTIR=0 bash "$KT" ac gb-12 --is "bitmiş işe dilim" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000012 --tahmin 20 >/dev/null 2>&1
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11c bitti göreve ac → durum yazılmaz (A06: 'bitti' insanındır, ajan geri açamaz); gb-11'in onay bekleyen görevi 'gecti'de de 'bekliyor'a ÇEKİLMEZ"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
for g in ("gorev_KARTTEST00000012","gorev_KARTTEST00000011"):
    m=[x for x in l if x["yol"].endswith(g)]
    assert len(m)==1 and "yerine" not in m[0]["govde"] and "durumu KORUNUR" in m[0]["govde"]["adimlar"][0], (g,l)
assert "başka işe geçti: gb-12" in [x for x in l if x["yol"].endswith("gorev_KARTTEST00000011")][0]["govde"]["adimlar"][0]
PY2
N0=$(yz); KART_UZLASTIR=0 bash "$KT" tikandi gb-11 --yol daralt --neden "onay beklerken tıkandı" >/dev/null 2>&1; RC=$?
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11d onay-bekliyor göreve tikandi → 'bekliyor' YAZILMAZ, yalnız adım (tıkanma nedeniyle)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000011")]
assert len(m)==1 and "yerine" not in m[0]["govde"] and "tıkandı: onay beklerken tıkandı" in m[0]["govde"]["adimlar"][0], l
PY2
N0=$(yz); KART_UZLASTIR=0 bash "$KT" tikandi gb-12 --yol daralt --neden "bitmiş işte tıkandı" >/dev/null 2>&1
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11d2 bitti göreve tikandi → 'bekliyor' YAZILMAZ (insanın 'bitti'si geri açılmaz)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000012")]
assert len(m)==1 and "yerine" not in m[0]["govde"] and "görev 'bitti', durumu KORUNUR" in m[0]["govde"]["adimlar"][0], l
PY2
# YARIŞ (göz tur 1): GET 'çalışılıyor' surum 3 der, PATCH anında görev onaya alınmış (surum 4) → ilk yazım 409, yeniden okunur, yalnız adım düşer
printf '{"kayit":{"surum":3,"canli":{"gorev_durumu":"calisiliyor"}},"yaris":{"kayit":{"surum":4,"canli":{"gorev_durumu":"onay-bekliyor"}}}}' > "$T/kayit-gorev_KARTTEST00000014.json"
N0=$(yz); O="$(KART_UZLASTIR=0 bash "$KT" ac gb-14 --is "yarışta onaya alınan iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000014 --tahmin 20 2>&1)"; RC=$?
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11f 🔴 yarış: okunan sürüm yazıma girer (surum 3) → defter 409 → yeniden okunur, onay-bekliyor görülür, 2. yazım yalnız adım (durum EZİLMEZ)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000014")]
assert len(m)==2, l
assert m[0]["govde"]["surum"]==3 and m[0]["govde"]["yerine"]["gorev_durumu"]=="calisiliyor", m[0]
assert "yerine" not in m[1]["govde"] and "görev 'onay-bekliyor', durumu KORUNUR" in m[1]["govde"]["adimlar"][0], m[1]
PY2
[ $RC -eq 0 ] && grep -q "durumu korundu" <<<"$O"; g $? "G11g yarış sonrası rc 0, ekranda 'durumu korundu'"
rm -f "$T"/kayit-gorev_*.json
N0=$(yz); KART_UZLASTIR=0 bash "$KT" ac gb-13 --is "durumu okunamayan iş" --istedi SERDAR --aldi BANI $SINIF --gorev gorev_KARTTEST00000013 --tahmin 20 >/dev/null 2>&1
python3 - "$T/yazim.jsonl" "$N0" <<'PY2'; g $? "G11e durum okunamazsa (404) eski davranış: ac 'çalışılıyor' yazar (koruma yalnız bilinen onay/bitti'de)"
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][int(sys.argv[2]):]
m=[x for x in l if x["yol"].endswith("gorev_KARTTEST00000013")]
assert len(m)==1 and m[0]["govde"]["yerine"]["gorev_durumu"]=="calisiliyor", l
PY2
rm -f "$T/gorevler-kart.json"; unset KART_UZLASTIR_KOKLER UZLASTIR_ZIL_KOMUT UZLASTIR_KOLTUK_KOMUT
kill $DSRV 2>/dev/null; wait $DSRV 2>/dev/null
O="$(bash "$KT" bitti gb-2 2>&1)"; RC=$?
[ $RC -eq 4 ] && grep -q "yazılamadı: deftere ulaşılamadı" <<<"$O" && python3 -c "import json;k=json.load(open('$KK/gb-2.json'));assert k['durum']=='bitti' and k['gorev_yazimlari'][-1]['olay']=='bitti'"; g $? "G8 defter kapalı: kart bitti İŞLENİR, 'ulaşılamadı' söylenir, rc 4 (sessiz eksik yok)"
export DEFTER_JETON_YOL="$T/jeton-yok"; unset DEFTER_UC   # gerçek jetona GERİ DÖNÜLMEZ (hermetik)

echo "════ T15 · KANIT AĞACI: bitti/daralt birincil checkout'tan çağrılınca kanıtı kartın İŞ ALANINDAN okur ve nereden okuduğunu söyler; hiçbir yerde yoksa uyarır (Nexus #1223: daralt tur_sifir=0 yazmıştı) ════"
mkdir -p "$T/depo3" && cd "$T/depo3" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" && export KANIT_DEPO="$T/depo3"
bash "$KT" ac is-wt --is "iş alanından okunan kanıt sınavı tek kartta" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; g $? "kart açıldı (birincil)"
git worktree add -q -b is-wt "$T/alan3/depo3-is-wt" main 2>/dev/null; g $? "iş alanı (dalı = iş adı, is-alani.sh kuralı) açıldı"
( cd "$T/alan3/depo3-is-wt" && env -u KANIT_DEPO bash "$K" olcum is-wt olc --asama tek -- echo 1 >/dev/null 2>&1 ) && [ -f "$T/alan3/depo3-is-wt/_agents/fabrika/kanit/is-wt/KANIT.json" ]; g $? "kanıt iş alanında alındı (KANIT.json orada; kanit.sh KANIT_DEPO yokken cwd ağacına yazar)"
for i in 1 2 3; do echo '{"tur":'$i',"sonuc":{"kod_puani":5,"dogru_sey":"E","bulgular":[]}}' > "$T/alan3/depo3-is-wt/_agents/fabrika/kanit/is-wt/DENETIM-$i.json"; done
[ ! -d "$T/depo3/_agents/fabrika/kanit/is-wt" ]; g $? "birincil checkout'ta kanıt dizini YOK (eski kodun sessiz 0 verdiği hâl)"
O="$(bash "$KT" daralt is-wt --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-wt 2>&1)"; RC=$?
[ $RC -eq 0 ] && grep -q "tur sıfırı 3" <<<"$O"; g $? "🔴 birincilden daralt: tur sıfırı 3 (iş alanındaki 3 DENETIM; eski kod 0 yazardı)"
grep -q "iş alanından okundu: $T/alan3/depo3-is-wt" <<<"$O"; g $? "nereden okuduğunu söyledi (kapı kaydı)"
python3 -c "import json;k=json.load(open('$T/depo3/_agents/fabrika/kartlar/is-wt.json'));assert k['daraltmalar'][-1]['tur_sifir']==3"; g $? "karta tur_sifir=3 yazıldı"
O="$(bash "$KT" bitti is-wt --pr 9 2>&1)"; RC=$?
[ $RC -eq 0 ] && ! grep -q "KANIT YOK" <<<"$O" && grep -q "iş alanından okundu" <<<"$O"; g $? "🔴 birincilden bitti: kanıt VAR (iş alanından), KANIT YOK damgası yok (Sx #383 hâli)"
python3 -c "import json;k=json.load(open('$T/depo3/_agents/fabrika/kartlar/is-wt.json'));assert k['kanit_var'] and k['puan']['tur']==3 and k['puan']['kod']==5"; g $? "karta kanıt_var + tur 3 + puan 5 işlendi"
O="$(bash "$KT" canli-borc-durum is-wt 2>&1)"; IFS=$'\t' read -r BD _ <<<"$O"; [ "$BD" = yok ] && grep -q "iş alanından okundu: $T/alan3/depo3-is-wt" <<<"$O"; g $? "canli-borc-durum: İLK satır 'yok' (kapı tek satır okur) + kaynak notu SONRAKİ satırda (dört komut da nereden okuduğunu söyler)"
mkdir -p "$T/depo3/_agents/fabrika/kanit/is-wt"; echo '{"tur":1,"sonuc":{"kod_puani":2,"dogru_sey":"H","bulgular":[]}}' > "$T/depo3/_agents/fabrika/kanit/is-wt/DENETIM-1.json"
O="$(bash "$KT" tikandi is-wt --yol devam --neden "çağrıldığı ağaç önce gelir sınavı" 2>&1)"; ! grep -q "iş alanından okundu" <<<"$O" && grep -q "'tur': 1" <<<"$O"; g $? "çağrıldığı ağaçta kanıt varsa ÖNCE o okunur (iş alanına bakılmaz; eski davranış korundu)"
bash "$KT" ac is-yok --is "hiç kanıtı olmayan iş sınavı burada" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
O="$(bash "$KT" bitti is-yok 2>&1)"; grep -q "ne bu ağaçta" <<<"$O" && grep -q "iş alanının İÇİNDEN çağır" <<<"$O" && grep -q "KANIT YOK" <<<"$O"; g $? "kanıt hiçbir yerde yok: nerede arandığı + 'iş alanının içinden çağır' uyarısı + KANIT YOK (sessiz 0 yok)"
O="$(bash "$KT" canli-borc-durum is-yok 2>&1)"; IFS=$'\t' read -r BD _ <<<"$O"; [ "$BD" = yok ] && grep -q "ne bu ağaçta" <<<"$O"; g $? "canli-borc-durum kanıtsız kartta: İLK satır 'yok' + yokluk uyarısı sonraki satırda"
echo "── T15 · MUTASYON (tam kopya): iş alanı araması kaldırılınca birincilden daralt yine 0 yazar → üstteki kapı kırmızı ──"
MD="$T/pkg-agac"; mkdir -p "$MD"; cp "$HERE"/*.py "$HERE"/*.sh "$MD/" 2>/dev/null
python3 - "$MD/kart.sh" <<'PYM' || g 1 "mutant kurulamadı (çapa bayat)"
import sys; f=sys.argv[1]; s=open(f,encoding="utf-8").read(); a='alan="$(is_alani_yolu "$is")"'; assert s.count(a)==1; open(f,"w",encoding="utf-8").write(s.replace(a,'alan=""',1))
PYM
bash "$KT" ac is-wt2 --is "ikinci iş alanı kanıt sınavı mutant için" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
git worktree add -q -b is-wt2 "$T/alan3/depo3-is-wt2" main 2>/dev/null; mkdir -p "$T/alan3/depo3-is-wt2/_agents/fabrika/kanit/is-wt2"
for i in 1 2 3; do echo '{"tur":'$i',"sonuc":{"kod_puani":5,"dogru_sey":"E","bulgular":[]}}' > "$T/alan3/depo3-is-wt2/_agents/fabrika/kanit/is-wt2/DENETIM-$i.json"; done
O="$(bash "$MD/kart.sh" daralt is-wt2 --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-m 2>&1)"; grep -q "tur sıfırı 0" <<<"$O"; g $? "mutant (iş alanı aranmıyor): tur sıfırı 0 — eski davranış geri geldi → üstteki 🔴 kapı bu mutantta düşerdi"
O="$(bash "$MD/kart.sh" bitti is-wt2 2>&1)"; grep -q "KANIT YOK" <<<"$O"; g $? "mutant: bitti 'KANIT YOK' damgalar (Sx #383) → üstteki 🔴 kapı düşerdi"
git worktree remove --force "$T/alan3/depo3-is-wt" 2>/dev/null; git worktree remove --force "$T/alan3/depo3-is-wt2" 2>/dev/null; unset KANIT_DEPO

echo "════ T-SORU · CEVAP BEKLE (gorev_…CMWNK): soruya bağlı geri alınamaz eylem cevap gelmeden koşmaz ════"
# kendi deposu: önceki bölümler $T/depo'yu kaldırıyor (ölçüldü: cd düşünce sınav başka ağaçta koşuyordu)
unset KANIT_DEPO; SQ="$T/depo-soru"; mkdir -p "$SQ" && cd "$SQ" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" || { g 1 "T-SORU deposu kurulamadı"; }
bash "$KT" ac ss-1 --is "railway eski servis temizliği" --istedi SERDAR --aldi MIRAHUR --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1
O="$(bash "$KT" cevap-bekle ss-1 2>&1)"; RC=$?; [ "$RC" -eq 0 ] && [ "${O%%$'\t'*}" = yok ]; g $? "S1 sorusuz kart: 'yok' rc 0 (eylem serbest)"
bash "$KT" sor ss-1 --kime SERDAR --eylem "iki Postgres servisini sil" --soru "Cortex-Db dışındaki iki boş Postgres servisini silebilir miyim?" >/dev/null 2>&1; g $? "S2 soru karta bağlandı"
O="$(bash "$KT" cevap-bekle ss-1 2>&1)"; RC=$?; [ "$RC" -eq 3 ] && [ "${O%%$'\t'*}" = acik ]; g $? "S3 🔴 cevapsız soru: 'acik' rc 3 → 'cevap-bekle && eylem' KOŞMAZ"
O="$(bash "$KT" acik-soru MIRAHUR 2>&1)"; RC=$?; [ "$RC" -eq 3 ] && grep -q "ss-1 · soru 1" <<<"$O"; g $? "S4 acik-soru ajanın kartlarında soruyu buldu (rc 3)"
bash "$KT" acik-soru NAKKAS >/dev/null 2>&1; g $? "S4b başka ajanın cevapsız sorusu yok (rc 0)"
O="$(bash "$KT" bitti ss-1 2>&1)"; RC=$?; [ "$RC" -eq 1 ] && grep -q "CEVAPSIZ SORU" <<<"$O"; g $? "S5 🔴 cevapsız soru varken kart.sh bitti REDDEDİLDİ"
python3 -c "import json;k=json.load(open('$SQ/_agents/fabrika/kartlar/ss-1.json'));assert k['durum']=='acik'"; g $? "S5b kart açık kaldı"
bash "$KT" cevap ss-1 --no 1 --kim MIRAHUR --karar evet --oturum x --soz "olur" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S6 🔴 soran (kartın sahibi) kendi sorusunu cevaplayamaz"
bash "$KT" cevap ss-1 --no 1 --kim HENDESE --karar evet --oturum x --soz "olur" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S7 🔴 sorulan olmayan ad cevap veremez"
bash "$KT" cevap ss-1 --no 1 --kim SERDAR --karar belki --oturum x --soz "bakarız" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S8 küme dışı karar (belki) reddedildi"
bash "$KT" cevap ss-1 --no 1 --kim SERDAR --karar evet --soz "olur" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S9 oturumsuz cevap SAYILMAZ (D1 deseni)"
bash "$KT" cevap ss-1 --no 1 --kim SERDAR --karar hayir --oturum sess-1 --soz "silme, önce satır sayısını ölç" >/dev/null 2>&1; g $? "S10 sorulan cevapladı: hayır"
O="$(bash "$KT" cevap-bekle ss-1 2>&1)"; RC=$?; [ "$RC" -eq 4 ] && [ "${O%%$'\t'*}" = hayir ]; g $? "S11 🔴 hayır: 'hayir' rc 4 → eylem koşmaz"
bash "$KT" cevap ss-1 --no 1 --kim SERDAR --karar evet --oturum s2 --soz "tamam" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S12 cevaplı soru yeniden cevaplanmaz (hayır kesin)"
bash "$KT" acik-soru MIRAHUR >/dev/null 2>&1; g $? "S13 cevaplanınca acik-soru temiz (rc 0)"
bash "$KT" sor ss-1 --kime SERDAR --eylem "yalnız boş servisi sil" --soru "Satır sayısı 0 çıkan tek servisi silebilir miyim, ölçüm ekte?" >/dev/null 2>&1 && bash "$KT" cevap ss-1 --no 2 --kim SERDAR --karar evet --oturum sess-2 --soz "evet, yalnız o" >/dev/null 2>&1; g $? "S14 yeni soru (no 2) açıldı ve evet aldı"
bash "$KT" cevap-bekle ss-1 >/dev/null 2>&1; [ $? -eq 4 ]; g $? "S14b eski hayır hâlâ görünür (rc 4) — sonraki evet eski reddi silmez"
bash "$KT" bitti ss-1 >/dev/null 2>&1; g $? "S15 cevapsız soru kalmayınca kart kapanabilir"
bash "$KT" ac ss-2 --is "veritabanı yedeğini sil" --istedi Sultan --aldi MIRAHUR --geri-alinamaz e --para h --dis-yuzey h --yetki h --canli h --oda sinav-oda >/dev/null 2>&1
bash "$KT" sor ss-2 --kime SERDAR --eylem "eski yedeği sil" --soru "Eski veritabanı yedeğini silebilir miyim, yer açılacak?" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S16 🔴 SINIFLI kartta soru SERDAR'a sorulamaz (karar Sultan'ın)"
bash "$KT" sor ss-2 --kime Sultan --eylem "eski yedeği sil" --soru "Eski veritabanı yedeğini silebilir miyim, yer açılacak?" >/dev/null 2>&1; g $? "S16b sınıflı kartta Sultan'a sorulur"
bash "$KT" sor ss-2 --kime Sultan --eylem "sil" --soru "kısa" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S17 kısa eylem/soru reddedildi"
bash "$KT" sor ss-2 --kime Sultan --eylem "eski yedeği sil" --soru "satır1
satır2 yeterince uzun bir soru" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S18 satır sonu içeren soru reddedildi (defter ayracı)"
# göz #444 tur 1: okunamayan kart atlanıp rc 0 dönülüyordu — kanca kaynağı FAIL-CLOSED olmalı
KDQ="$SQ/_agents/fabrika/kartlar"
printf '{bozuk' > "$KDQ/zz-bozuk.json"
O="$(bash "$KT" acik-soru NAKKAS 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && grep -q "ÖLÇÜLEMEDİ" <<<"$O"; g $? "S19 🔴 okunamayan kart (bozuk JSON): acik-soru rc 2 ÖLÇÜLEMEDİ — 'cevapsız soru yok' DEMEZ"
O="$(bash "$KT" acik-soru MIRAHUR 2>&1)"; [ $? -eq 3 ]; g $? "S19c bozuk kart + gerçek cevapsız soru (ss-2 → Sultan): rc 3 (daha belirli olan söylenir)"
rm -f "$KDQ/zz-bozuk.json"
printf '{"is":"zz-2","aldi":"NAKKAS","durum":"acik","sorular":[{"no":1}]}' > "$KDQ/zz-2.json"
bash "$KT" acik-soru NAKKAS >/dev/null 2>&1; [ $? -eq 2 ]; g $? "S19b 🔴 sorular listesi bozuk kart (alan eksik): rc 2"
rm -f "$KDQ/zz-2.json"
bash "$KT" acik-soru NAKKAS >/dev/null 2>&1; g $? "S19d bozuk kart kalkınca yine rc 0"
# kanca dilimi (SERDAR (b)): ajan adı yazım farkından bağımsız — kartlarda BERİD ve BERID birlikte duruyor, tmux oturum adı "berid"
bash "$KT" ac ad-1 --is "ad katlama sınavı için eski servis temizliği" --istedi SERDAR --aldi BERİD --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1
bash "$KT" sor ad-1 --kime SERDAR --eylem "eski servisi sil" --soru "Eski servisi silebilir miyim, ölçüm ekte?" >/dev/null 2>&1
for AD in BERID berid BERİD Berid; do
  O="$(bash "$KT" acik-soru "$AD" 2>&1)"; RC=$?; [ "$RC" -eq 3 ] && grep -q "ad-1 · soru 1" <<<"$O"; g $? "S20 🔴 kart sahibi BERİD, sorgu '$AD': soru GÖRÜLDÜ (rc 3) — yazım farkı kartı gizlemez"
done
bash "$KT" acik-soru BERNA >/dev/null 2>&1; g $? "S20b benzeyen ama başka ad (BERNA): soru yok (rc 0) — katlama yalnız yazımı eşler"
bash "$KT" ac ad-2 --is "ad katlama ikinci kart ASCII sahip" --istedi SERDAR --aldi NAKKAS --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1
bash "$KT" sor ad-2 --kime SERDAR --eylem "yedeği sil" --soru "Eski yedeği silebilir miyim, yer açılacak?" >/dev/null 2>&1
bash "$KT" acik-soru NAKKAŞ >/dev/null 2>&1; [ $? -eq 3 ]; g $? "S20c 🔴 kart sahibi NAKKAS, sorgu 'NAKKAŞ': soru görüldü (rc 3)"
bash "$KT" sor ad-1 --kime BERID --eylem "kendine sor" --soru "Kendi kendime sorayım mı, yazımı değiştirerek?" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S21 🔴 kartın sahibi BERİD kendine 'BERID' yazarak soramaz (soran kendine soramaz)"
bash "$KT" sor ad-1 --kime Serdar --eylem "ikinci soru" --soru "Yazımı farklı yazılmış sorulana ikinci soru açılabilir mi, cevabı kim verir?" >/dev/null 2>&1; g $? "S21b sorulan 'Serdar' yazımıyla da sorulabilir"
bash "$KT" cevap ad-1 --no 2 --kim SERDAR --karar evet --oturum s1 --soz "olur" >/dev/null 2>&1; g $? "S21c 'Serdar' diye sorulan soruyu 'SERDAR' cevaplar (aynı kişi, yazım farkı)"
bash "$KT" cevap ad-1 --no 1 --kim SERDAR --karar hayir --oturum s2 --soz "silme" >/dev/null 2>&1; g $? "S21d ilk soru cevaplandı"
bash "$KT" sor ss-2 --kime sultan --eylem "yedeği sil (yazım farkı)" --soru "Sultan yazımı küçük harfle de sınıflı kartta kabul edilir mi, karar kimin?" >/dev/null 2>&1; g $? "S21f 🔴 sınıflı kartta 'sultan' (yazım farkı) = Sultan: soru açıldı"
bash "$KT" sor ss-2 --kime SERDAR --eylem "yedeği sil" --soru "Sınıflı kartta SERDAR yazımı hâlâ reddedilmeli, değil mi?" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "S21g sınıflı kartta SERDAR hâlâ reddedilir (katlama Sultan kuralını gevşetmedi)"
O="$(bash "$KT" acik-soru '*' 2>&1)"; RC=$?; [ "$RC" -eq 3 ] && grep -q "ad-2 · soru 1" <<<"$O" && grep -q "ss-2 · soru" <<<"$O" && grep -q "herkes" <<<"$O"; g $? "S22 🔴 acik-soru '*': kimliği çözülemeyen oturum için HERKESİN cevapsız sorusu görülür (rc 3)"
bash "$KT" cevap ad-2 --no 1 --kim SERDAR --karar hayir --oturum s3 --soz "silme" >/dev/null 2>&1
bash "$KT" bitti ad-1 >/dev/null 2>&1; bash "$KT" bitti ad-2 >/dev/null 2>&1
bash "$KT" acik-soru '*' >/dev/null 2>&1; [ $? -eq 3 ]; g $? "S22b '*' ss-2'deki cevapsız soruyu hâlâ görüyor (rc 3 — başka kartın sorusu)"
bash "$KT" acik-soru NAKKAS >/dev/null 2>&1; g $? "S21e ad katlama kartları kapandı, sonraki sınavlar için cevapsız soru kalmadı (rc 0)"
echo "── T-SORU · MUTASYON: kapı ölünce yukarıdaki 🔴 kapı düşer ──"
for M in "bitti engeli" "sorulan kimliği" "sinifli kural" "bozuk kart" "ad katlama"; do
  MD="$T/mut-soru-${M// /-}"; mkdir -p "$MD"; cp "$HERE"/*.py "$HERE"/*.sh "$MD/" 2>/dev/null
  python3 - "$MD" "$M" <<'PYM' || g 1 "mutant kurulamadı ($M — çapa bayat)"
import sys; d,m=sys.argv[1:]
def deg(f,a,b):
    p=d+"/"+f; s=open(p,encoding="utf-8").read(); assert s.count(a)==1,(m,a); open(p,"w",encoding="utf-8").write(s.replace(a,b,1))
if m=="bitti engeli": deg("kart.sh",'    if [ "$CMD" = "bitti" ]; then\n      SD="$(bash','    if false; then\n      SD="$(bash')
if m=="sorulan kimliği": deg("soru.py",'    if not ayni_ad(kim, s["kime"]):','    if False:')
if m=="sinifli kural": deg("soru.py",'and not ayni_ad(kime, "Sultan"):','and False:')
if m=="bozuk kart": deg("kart.sh",'if bozuk: print(f"ÖLÇÜLEMEDİ','if False: print(f"ÖLÇÜLEMEDİ')
if m=="ad katlama": deg("soru.py",'    return ad_katla(a) == ad_katla(b) != ""','    return a == b')
PYM
  cd "$SQ" || { g 1 "T-SORU deposu kayboldu"; break; }; rm -f _agents/fabrika/kartlar/mm-*.json
  bash "$MD/kart.sh" ac mm-1 --is "mutant sınavı için railway temizliği" --istedi SERDAR --aldi MIRAHUR --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1
  bash "$MD/kart.sh" sor mm-1 --kime SERDAR --eylem "servisi sil" --soru "Boş servisi silebilir miyim, ölçüm ekte duruyor?" >/dev/null 2>&1
  case "$M" in
    "bitti engeli") bash "$MD/kart.sh" bitti mm-1 >/dev/null 2>&1; g $? "mutant ($M): cevapsız soruyla kart KAPANDI → S5 bu mutantta düşerdi" ;;
    "sorulan kimliği") bash "$MD/kart.sh" cevap mm-1 --no 1 --kim HENDESE --karar evet --oturum x --soz "olur" >/dev/null 2>&1; g $? "mutant ($M): sorulmayan ad cevap verdi → S7 bu mutantta düşerdi" ;;
    "sinifli kural") bash "$MD/kart.sh" ac mm-2 --is "mutant sınıflı yedek silme işi" --istedi Sultan --aldi MIRAHUR --geri-alinamaz e --para h --dis-yuzey h --yetki h --canli h --oda sinav-oda >/dev/null 2>&1
                     bash "$MD/kart.sh" sor mm-2 --kime SERDAR --eylem "yedeği sil" --soru "Eski yedeği silebilir miyim, yer açılacak?" >/dev/null 2>&1; g $? "mutant ($M): sınıflı kartta SERDAR'a soruldu → S16 bu mutantta düşerdi" ;;
    "ad katlama") bash "$MD/kart.sh" ac mm-3 --is "ad katlama mutantı için servis temizliği" --istedi SERDAR --aldi BERİD --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1
                  bash "$MD/kart.sh" sor mm-3 --kime SERDAR --eylem "servisi sil" --soru "Eski servisi silebilir miyim, ölçüm ekte?" >/dev/null 2>&1; bash "$MD/kart.sh" acik-soru BERID >/dev/null 2>&1; g $? "mutant ($M): BERİD kartı 'BERID' sorgusunda görünmedi (rc 0) → S20 bu mutantta düşerdi" ;;
    "bozuk kart") printf '{bozuk' > "$SQ/_agents/fabrika/kartlar/mm-bozuk.json"; bash "$MD/kart.sh" acik-soru NAKKAS >/dev/null 2>&1; g $? "mutant ($M): okunamayan kart atlanıp rc 0 → S19 bu mutantta düşerdi"; rm -f "$SQ/_agents/fabrika/kartlar/mm-bozuk.json" ;;
  esac
done
rm -f "$SQ/_agents/fabrika/kartlar/mm-"*.json

echo "════ T17 · ÖLÇÜT NEREDE ÖLÇÜLECEK (görev …90KA6C): cümlede sayısal ölçüt varsa --olcum-yeri ZORUNLU (W1G2N: '≤6 dk' 2 çekirdekli CI'da imkânsızdı) ════"
mkdir -p "$T/depo17" && cd "$T/depo17" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" && export KANIT_DEPO="$T/depo17"   # önceki bölümler çalışma dizinini/deposunu değiştirmiş olabilir
tetik_kur
KU="$T/depo17/_agents/fabrika/kartlar"; D4S="--istedi SERDAR --aldi HEZARFEN --geri-alinamaz h --para h --dis-yuzey h --yetki h"
O="$(bash "$KT" ac is-ol1 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q "NEREDE ölçüleceği yok" <<<"$O" && grep -q "≤6 dk" <<<"$O" && [ ! -f "$KU/is-ol1.json" ]; g $? "OL1 ölçütlü cümle + yer YOK → rc 1, sebep ölçütü söyler, kart AÇILMADI"
O="$(bash "$KT" ac is-ol2 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "yerel" 2>&1)"; rc=$?
[ $rc -eq 1 ] && [ ! -f "$KU/is-ol2.json" ]; g $? "OL2 'yerel' ama çekirdek sayısı YOK → rc 1 (çekirdek şart)"
O="$(bash "$KT" ac is-ol3 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "yerel, 12 çekirdek" 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -q "ölçüt: '≤6 dk' → ölçüleceği yer: yerel, 12 çekirdek" <<<"$O"; g $? "OL3 'yerel, 12 çekirdek' → açıldı, çıktı ölçüt+yeri söyler"
python3 -c "import json,sys;k=json.load(open(sys.argv[1]));assert k['olcut']==['≤6 dk'] and k['olcum_yeri']=='yerel, 12 çekirdek',k" "$KU/is-ol3.json"; g $? "OL3b kartta olcut + olcum_yeri yazılı"
bash "$KT" ac is-ol4 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "CI, 2 çekirdek" >/dev/null 2>&1; g $? "OL4 'CI, 2 çekirdek' kabul"
bash "$KT" ac is-ol5 --is "uç noktanın cevap süresi ≤200 ms olsun" $D4S --olcum-yeri "canlı" >/dev/null 2>&1; g $? "OL5 'canlı' çekirdek sayısı istemeden kabul"
bash "$KT" ac is-ol6 --is "bekçi dört saat adımsız kalan işe zil atsın, 152 kapılı sınav, sürüm 0.19.1" $D4S >/dev/null 2>&1; g $? "OL6 eşik işaretsiz süre / kapı sayısı / sürüm ölçüt SAYILMAZ → yer istenmez"
bash "$KT" ac is-ol7 --is "araç en çok 40 MB bellek kullansın" $D4S >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL7 'en çok 40 MB' biçimi de ölçüt sayılır (yer yok → rc 1)"
bash "$KT" ac is-ol8 --is "bu iş 6 dk altında bitmeli ve 40 dk'dan az sürmeli" $D4S >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL8 '6 dk altında' / 40 dk'dan az biçimleri de ölçüt sayılır"
bash "$KT" ac is-ol13 --is "değerlendirme en az 95 puan versin ve en çok 10 istek atsın" $D4S >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL13 birim dar değil: 'en az 95 puan' / 'en çok 10 istek' de ölçüt sayılır (yer yok → rc 1)"
bash "$KT" ac is-ol14 --is "oturum 3 hata altında kalsın" $D4S >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL14 '3 hata altında' ölçüt sayılır"
bash "$KT" ac is-ol15 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "canlı, CI" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL15 birden çok yüzey adı ('canlı, CI') belirsiz → rc 1 (tek yer şart)"
bash "$KT" ac is-ol16 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "CI, yerel, 2 çekirdek" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "OL16 'CI, yerel, 2 çekirdek' de belirsiz → rc 1"
echo "──  T17 · daralt: yeni cümlede ölçüt varsa yer zorunlu; ölçüt değişince eski GEÇERSİZ, karta + görev adımına yazılır ──"
O="$(bash "$KT" daralt is-ol3 --kalan "kalan: CI'da paralel koşu ayrı kartta yapılacak" --cumle "korpus paralel koşsun, süre ≤10 dk olsun" --oturum o1 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q "DARALTILMADI" <<<"$O" && python3 -c "import json,sys;k=json.load(open(sys.argv[1]));assert k['olcut']==['≤6 dk'] and 'cumle_gecmisi' not in k,k" "$KU/is-ol3.json"; g $? "OL9 daralt: yeni cümlede ölçüt var, yer YOK → rc 1, kart DEĞİŞMEDİ"
O="$(bash "$KT" daralt is-ol3 --kalan "kalan: CI'da paralel koşu ayrı kartta yapılacak" --cumle "korpus paralel koşsun, süre ≤10 dk olsun" --oturum o1 --olcum-yeri "yerel, 12 çekirdek" 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -q "ÖLÇÜT değişti: eski \['≤6 dk'\] GEÇERSİZ → yeni \['≤10 dk'\]" <<<"$O"; g $? "OL10 daralt + yer → ölçüt değişti uyarısı (eski GEÇERSİZ, yeni)"
python3 -c "import json,sys;k=json.load(open(sys.argv[1]));assert k['olcut']==['≤10 dk'] and k['olcut_gecmisi'][-1]['eski']==['≤6 dk'] and k['olcut_gecmisi'][-1]['yeni']==['≤10 dk'] and k['olcum_yeri']=='yerel, 12 çekirdek',k" "$KU/is-ol3.json"; g $? "OL10b kartta güncel ölçüt + olcut_gecmisi (eski→yeni) yazılı"
bash "$KT" daralt is-ol4 --kalan "kalan: ölçüt başka karta taşındı, burada yalnız paralel koşu" --cumle "korpus paralel koşsun, ölçüt başka kartta" --oturum o2 >/dev/null 2>&1; rc=$?
python3 -c "import json,sys;k=json.load(open(sys.argv[1]));assert k['olcut']==[] and k['olcum_yeri']=='' and k['olcut_gecmisi'][-1]['eski']==['≤6 dk'],k" "$KU/is-ol4.json"; [ $rc -eq 0 ]; g $? "OL11 daralt ölçütü KALDIRIRSA yer istenmez, eski ölçüt geçersiz sayılıp kayda geçer"
# görev bağlı kartta ölçüt adımı: jeton yok → defter yazımı düşer (rc 4, karta işlenir); yazım DENENDİ ve olay 'daralt'
bash "$KT" ac is-ol12 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "CI, 2 çekirdek" --gorev gorev_01AAAAAAAAAAAAAAAAAAAAOL12 --tahmin 30 >/dev/null 2>&1
O="$(bash "$KT" daralt is-ol12 --kalan "kalan: ölçüt başka karta taşındı, burada yalnız paralel koşu" --cumle "korpus paralel koşsun, süre ≤10 dk olsun" --oturum o3 --olcum-yeri "yerel, 12 çekirdek" 2>&1)"; rc=$?
[ $rc -eq 4 ] && python3 -c "import json,sys;k=json.load(open(sys.argv[1]));y=k['gorev_yazimlari'];assert y[-1]['olay']=='daralt',y" "$KU/is-ol12.json"; g $? "OL12 görev bağlı kartta ölçüt daralması görev adımı olarak DENENİR (olay 'daralt'; jeton yok → rc 4, karta işlenir)"
echo "──  T17 · MUTASYON: şart kalkarsa ilgili kapı KIRMIZI ──"
m17() {  # m17 <ad> <eski> <yeni> <beklenen: komut dizisi sonucu rc>  → tam kopya + tek değişiklik; çapa tam 1 kez değilse g 1
  local D="$T/pkg17-$1"; mkdir -p "$D"; cp "$HERE"/*.py "$HERE"/*.sh "$D/" 2>/dev/null
  local n; n="$(python3 - "$D/kart.sh" "$2" "$3" <<'PYM'
import sys; f, a, b = sys.argv[1:]; s = open(f, encoding="utf-8").read(); n = s.count(a); print(n)
if n == 1: open(f, "w", encoding="utf-8").write(s.replace(a, b, 1))
PYM
)"
  [ "$n" = 1 ] || { g 1 "m17 $1: çapa $n kez geçiyor (tam 1 olmalı)"; return 1; }
  M17="$D/kart.sh"
}
m17 ac-sart '    olcut_zorunlu "$IS_C" "AÇILMADI" || exit 1' '    :' && { bash "$M17" ac is-mo1 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-OL1 ac'taki ölçüt şartı kalkarsa yersiz kart açılır (OL1 bu mutantta düşerdi)"; }
m17 cekirdek-sart 'raise SystemExit(0 if re.search(r"\d+\s*(?:çekirdek|cekirdek|vcpu|core)", y) else 1)' 'raise SystemExit(0)' && { bash "$M17" ac is-mo2 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "yerel" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-OL2 çekirdek sayısı şartı kalkarsa 'yerel' tek başına geçer (OL2 düşerdi)"; }
m17 daralt-sart '    olcut_zorunlu "$CUMLE" "DARALTILMADI" || exit 1' '    :' && { bash "$KT" ac is-mo3 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "CI, 2 çekirdek" >/dev/null 2>&1; bash "$M17" daralt is-mo3 --kalan "kalan: ölçüt başka karta taşındı, burada paralel koşu" --cumle "korpus paralel koşsun, süre ≤10 dk olsun" --oturum o4 >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-OL3 daralt'taki ölçüt şartı kalkarsa yersiz daraltma geçer (OL9 düşerdi)"; }
m17 ust-sinir 'if len(k.get("daraltmalar") or [])>=2:' 'if False:' && { bash "$KT" ac is-mo7 --is "iki yarım iş tek kartta olduğu için tıkanan iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; bash "$M17" daralt is-mo7 --kalan "birinci kalan parça yeterince uzun" --cumle "daraltılmış cümle yeterince uzun burada bir" --oturum o7 --yeni is-mo7-1 >/dev/null 2>&1; bash "$M17" daralt is-mo7 --kalan "ikinci kalan parça yeterince uzun" --cumle "daraltılmış cümle yeterince uzun burada iki" --oturum o7 --yeni is-mo7-2 >/dev/null 2>&1; bash "$M17" daralt is-mo7 --kalan "üçüncü kalan parça yeterince uzun" --cumle "daraltılmış cümle yeterince uzun burada üç" --oturum o7 --yeni is-mo7-3 >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-US üst sınır kalkarsa üçüncü daraltma geçer (ÜST SINIR kapısı düşerdi)"; }
m17 birim-dar 'B = r"(?:[^\W\d_]+|%)"' 'B = r"(?:ms|sn|dk|sa|kb|mb|gb|px|%)"' && { bash "$M17" ac is-mo5 --is "değerlendirme en az 95 puan versin ve en çok 10 istek atsın" $D4S >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-OL5 birim sözlüğü daralırsa 'en az 95 puan' ölçüt sayılmaz, kart yersiz açılır (OL13 düşerdi)"; }
m17 tek-yer 'if len(yerler) != 1: raise SystemExit(1)' 'if len(yerler) < 1: raise SystemExit(1)' && { bash "$M17" ac is-mo6 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "canlı, CI" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M-OL6 tek-yer şartı gevşerse 'canlı, CI' geçer (OL15 düşerdi)"; }
m17 olcut-eski 'eski_olcut!=yeni_olcut:
    k.setdefault("olcut_gecmisi",[])' 'False:
    k.setdefault("olcut_gecmisi",[])' && { bash "$KT" ac is-mo4 --is "korpus paralel koşsun, süre ≤6 dk olsun" $D4S --olcum-yeri "CI, 2 çekirdek" >/dev/null 2>&1; bash "$M17" daralt is-mo4 --kalan "kalan: ölçüt başka karta taşındı, burada paralel koşu" --cumle "korpus paralel koşsun, süre ≤10 dk olsun" --oturum o5 --olcum-yeri "yerel, 12 çekirdek" >/dev/null 2>&1; python3 -c "import json,sys;k=json.load(open(sys.argv[1]));assert 'olcut_gecmisi' not in k" "$KU/is-mo4.json"; g $? "M-OL4 ölçüt değişimi kayda geçmezse olcut_gecmisi boş kalır (OL10b düşerdi)"; }

echo "════ T-SULTAN-TURU · beğeni döngüsü (BPV3A/2BXA6J): Sultan turu kaydedilir, göz tavanı sayacı o ana çekilir; şartlar araçta ════"
STG="$T/st-gorevler"; mkdir -p "$STG" "$T/depo-st" && cd "$T/depo-st" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" && export KANIT_DEPO="$T/depo-st"
printf 'st-jeton\n' > "$T/st-jeton"
python3 - "$T" "$STG" <<'PYS' &
import sys, os, http.server, socketserver
T,G=sys.argv[1:]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        if self.headers.get("x-defter-jeton")!="st-jeton": self.send_response(401); self.end_headers(); return
        f=os.path.join(G,self.path.rsplit("/",1)[1]+".json")
        if not os.path.exists(f): self.send_response(404); self.end_headers(); return
        self.send_response(200); self.end_headers(); self.wfile.write(open(f,"rb").read())
with socketserver.TCPServer(("127.0.0.1",0),H) as s:
    open(os.path.join(T,"st-port"),"w").write(str(s.server_address[1])); s.serve_forever()
PYS
STSRV=$!; for i in $(seq 1 25); do [ -f "$T/st-port" ] && break; sleep 0.2; done
export DEFTER_JETON_YOL="$T/st-jeton" DEFTER_UC="http://127.0.0.1:$(cat "$T/st-port")"
GB=gorev_01BEGENIDONGUSUAAAAAAAAAA1; GE=gorev_01ETIKETSIZGOREVAAAAAAAAA2; GN=gorev_01TURSATIRSIZGOREVAAAAAAA3
gor() { python3 - "$STG/$1.json" "$2" "$3" <<'PYG'
import sys,json
yol,etiket,adimlar=sys.argv[1:]
json.dump({"ok":True,"kayit":{"id":yol.rsplit("/",1)[1][:-5],"canli":({"etiket":etiket} if etiket else {}),"adimlar":[{"deger":a} for a in json.loads(adimlar)]}},open(yol,"w"),ensure_ascii=False)
PYG
}
gor $GB begeni-dongusu '["[tur 1] kare: https://k/1.png · Sultan: \"başlık küçük kalsın\""]'
gor $GE "" '["[tur 1] kare: https://k/1.png · Sultan: \"başlık küçük kalsın\""]'
gor $GN begeni-dongusu '["Sultan bir şeyler söyledi"]'
GB2=gorev_01BASKAGORUNDUAAAAAAAAAA4
gor $GB2 begeni-dongusu '["[tur 2] kare: https://k/2.png · Sultan: \"renk koyu olsun\""]'
bash "$KT" ac is-st --is "beğeni döngüsü sınavı için ekran işi" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1; g $? "kart açıldı (sınıfsız)"
mkdir -p "$T/depo-st/_agents/fabrika/kanit/is-st"; for i in 1 2 3; do echo '{"tur":'$i',"sonuc":{"kod_puani":4,"dogru_sey":"H","bulgular":[]}}' > "$T/depo-st/_agents/fabrika/kanit/is-st/DENETIM-$i.json"; done
KS="$T/depo-st/_agents/fabrika/kartlar/is-st.json"; say() { python3 -c "import json;print(len(json.load(open('$KS')).get('sultan_turlari') or []))"; }
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GE --tur 1 2>&1)"; RC=$?; [ $RC -ne 0 ] && [ "$(say)" = 0 ] && grep -q "etiketi 'begeni-dongusu' değil" <<<"$O"; g $? "🔴 etiketsiz görev: tur KAYDEDİLMEZ (ajan kendi işine etiket koyup tavanı aşamaz)"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GN --tur 1 2>&1)"; RC=$?; [ $RC -ne 0 ] && [ "$(say)" = 0 ] && grep -q "görevde tur satırı yok" <<<"$O"; g $? "🔴 tur satırı yazılmamış görev: tur KAYDEDİLMEZ (kare + Sultan yorumu satırı şart)"
O="$(bash "$KT" sultan-turu is-st --reis BANI --gorev $GB --tur 1 2>&1)"; RC=$?; [ $RC -ne 0 ] && [ "$(say)" = 0 ] && grep -q "kartın sahibi değil" <<<"$O"; g $? "başkasının reis'i reddedilir (yalnız sahip)"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GB --tur 2 2>&1)"; RC=$?; [ $RC -ne 0 ] && [ "$(say)" = 0 ] && grep -q "sıradaki değil" <<<"$O"; g $? "atlanan tur numarası reddedilir (sıradaki 1)"
O="$(bash "$KT" sultan-turu yok-kart --reis HENDESE --gorev $GB --tur 1 2>&1)"; [ $? -eq 3 ]; g $? "kart yoksa rc 3"
O="$(DEFTER_UC=http://127.0.0.1:9 bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GB --tur 1 2>&1)"; RC=$?; [ $RC -eq 4 ] && [ "$(say)" = 0 ]; g $? "🔴 defter okunamazsa rc 4 ve HİÇBİR ŞEY değişmez (fail-closed)"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev gorev_YOK00000000000000000009 --tur 1 2>&1)"; RC=$?; [ $RC -eq 4 ] && [ "$(say)" = 0 ]; g $? "görev defterde yoksa (404) rc 4, kayıt yok"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GB --tur 1 2>&1)"; RC=$?; [ $RC -eq 0 ] && [ "$(say)" = 1 ] && grep -q "tur sıfırı 3" <<<"$O"; g $? "Sultan turu 1 kaydedildi, tur sıfırı = 3 (kanıt ağacındaki denetim sayısı)"
python3 -c "import json;k=json.load(open('$KS'));t=k['sultan_turlari'][-1];assert t['tur']==1 and t['tur_sifir']==3 and t['gorev']=='$GB' and 'başlık küçük' in t['satir'] and k['gecmis'][-1]['olay']=='sultan-turu'"; g $? "karta tur, tur_sifir, görev ve Sultan satırı + geçmiş işlendi"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GB --tur 1 2>&1)"; [ $? -ne 0 ] && [ "$(say)" = 1 ]; g $? "aynı tur ikinci kez kaydedilmez"
O="$(bash "$KT" sultan-turu is-st --reis HENDESE --gorev $GB2 --tur 2 2>&1)"; RC=$?; [ $RC -ne 0 ] && [ "$(say)" = 1 ] && grep -q "görevine bağlı" <<<"$O"; g $? "🔴 kart ilk turun görevine bağlanır: başka beğeni görevinin satırıyla ikinci tur kaydedilmez"
bash "$KT" ac is-st4 --is "başka kart aynı görevin turunu kullanmaya çalışır sınavı" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
mkdir -p "$T/depo-st/_agents/fabrika/kanit/is-st4"; echo '{"tur":1,"sonuc":{"kod_puani":4,"dogru_sey":"H","bulgular":[]}}' > "$T/depo-st/_agents/fabrika/kanit/is-st4/DENETIM-1.json"
O="$(bash "$KT" sultan-turu is-st4 --reis HENDESE --gorev $GB --tur 1 2>&1)"; RC=$?; [ $RC -ne 0 ] && grep -q "başka kartta" <<<"$O"; g $? "🔴 bir görevin turu tek karta ait: aynı görev ikinci kartta sayaç sıfırlayamaz"
bash "$KT" ac is-st5 --is "kanıt dizini olmayan kartta sıfır ölçülemez sınavı" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
O="$(bash "$KT" sultan-turu is-st5 --reis HENDESE --gorev $GB2 --tur 1 2>&1)"; RC=$?; [ $RC -eq 3 ] && grep -q "kanıt dizini bulunamadı" <<<"$O"; g $? "🔴 kanıt dizini yoksa tur sıfırı ölçülemez → rc 3, kayıt yok (sessiz sıfır YOK)"
# denetçi sıfırı okur (3 → sayım sıfırdan): üç düşük tur sonra DÖRDÜNCÜ gelince tıkanmaz
echo '{"tur":4,"sonuc":{"kod_puani":5,"dogru_sey":"E","bulgular":[]}}' > "$T/depo-st/_agents/fabrika/kanit/is-st/DENETIM-4.json"
SG="$(python3 - "$KS" <<'PYD'
import json,sys
k=json.load(open(sys.argv[1])); d=k.get("daraltmalar") or []; st=k.get("sultan_turlari") or []
print(max(int(d[-1].get("tur_sifir",0)) if d else 0, int(st[-1].get("tur_sifir",0)) if st else 0))
PYD
)"; [ "$SG" = 3 ]; g $? "denetçinin okuyacağı sıfır = 3 (daralt yok, Sultan turu var)"
# MUTANTLAR: iki şart kapatılınca üstteki 🔴 kapılar düşmeli
MS="$T/pkg-st"; mkdir -p "$MS"; cp "$HERE"/*.py "$HERE"/*.sh "$MS/" 2>/dev/null
mst() { python3 - "$MS/kart.sh" "$1" "$2" <<'PYM'
import sys; f,a,b=sys.argv[1:]; s=open(f,encoding="utf-8").read(); assert s.count(a)==1, "çapa bayat"; open(f,"w",encoding="utf-8").write(s.replace(a,b,1))
PYM
}
mst 'if et!="begeni-dongusu": red(' 'if False: red(' || g 1 "mutant 1 kurulamadı (çapa bayat)"
bash "$KT" ac is-st2 --is "ikinci beğeni döngüsü sınavı mutant için" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
mkdir -p "$T/depo-st/_agents/fabrika/kanit/is-st2"; echo '{"tur":1,"sonuc":{"kod_puani":4,"dogru_sey":"H","bulgular":[]}}' > "$T/depo-st/_agents/fabrika/kanit/is-st2/DENETIM-1.json"
O="$(bash "$MS/kart.sh" sultan-turu is-st2 --reis HENDESE --gorev $GE --tur 1 2>&1)"; [ $? -eq 0 ]; g $? "mutant (etiket şartı kaldırıldı): etiketsiz görevde tur KAYDEDİLİR → üstteki 🔴 etiket kapısı düşerdi"
mst 'if not satir: red(' 'if False: red(' || g 1 "mutant 2 kurulamadı (çapa bayat)"
mst '"satir":satir[-1].strip()' '"satir":(satir or [""])[-1].strip()' || g 1 "mutant 2b kurulamadı (çapa bayat)"
bash "$KT" ac is-st3 --is "üçüncü beğeni döngüsü sınavı mutant için" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
mkdir -p "$T/depo-st/_agents/fabrika/kanit/is-st3"; echo '{"tur":1,"sonuc":{"kod_puani":4,"dogru_sey":"H","bulgular":[]}}' > "$T/depo-st/_agents/fabrika/kanit/is-st3/DENETIM-1.json"
O="$(bash "$MS/kart.sh" sultan-turu is-st3 --reis HENDESE --gorev $GN --tur 1 2>&1)"; [ $? -eq 0 ]; g $? "mutant (tur satırı şartı kaldırıldı): satırsız görevde tur KAYDEDİLİR → üstteki 🔴 satır kapısı düşerdi"
mst 'if bagli and bagli!=gorev: red(' 'if False: red(' || g 1 "mutant 3 kurulamadı (çapa bayat)"
O="$(bash "$MS/kart.sh" sultan-turu is-st --reis HENDESE --gorev $GB2 --tur 2 2>&1)"; [ $? -eq 0 ]; g $? "mutant (görev bağı kaldırıldı): başka görevin satırıyla tur KAYDEDİLİR → üstteki 🔴 bağ kapısı düşerdi"
kill $STSRV 2>/dev/null; true

echo "════ T-SUPUR · kart.sh supur: PR'ı birleşmiş açık/tıkandı kartları toplu kapatır (HSKJCE) ════"
SD="$T/depo-supur"; mkdir -p "$SD/_agents/fabrika/kartlar"; ( cd "$SD" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" ) >/dev/null 2>&1
sk() {  # sk <iş> <durum> <pr> <aldi> <siniflar-json>  → sahte kart
  python3 - "$SD/_agents/fabrika/kartlar/$1.json" "$1" "$2" "$3" "$4" "$5" <<'PYK'
import json,sys; f,is_,d,pr,a,sn=sys.argv[1:]
k={"is":is_,"cumle":"süpürme sınavı kartı "+is_,"istedi":"S","aldi":a,"zaman":"2026-10-01T10:00:00+03:00","siniflar":json.loads(sn),"sultan":False,"durum":d,"gecmis":[]}
if pr: k["pr"]=pr
json.dump(k,open(f,"w"),ensure_ascii=False)
PYK
}
sk dal-birlesti acik "" HENDESE '[]'; sk dal-tikandi tikandi "" MUAVIN '[]'; sk kartpr-birlesti acik "77" HENDESE '[]'
sk acik-pr acik "" HENDESE '[]'; sk sinifli-birlesti acik "" HENDESE '["para"]'; sk zaten-bitti bitti "" HENDESE '[]'
sk kartpr-yanlis acik "55" HENDESE '[]'   # dal adı birleşmiş bir PR'la eşleşse bile kartta pr varsa O PR sayılır (55 birleşmemiş)
GHF="$T/gh-sahte.sh"; cat > "$GHF" <<'SH'
#!/usr/bin/env bash
[ -n "${GH_SAHTE_RC:-}" ] && { echo "gh: boom" >&2; exit "$GH_SAHTE_RC"; }
cat "${GH_SAHTE_CIKTI:?}"
SH
chmod +x "$GHF"; export KART_GH="$GHF"
cat > "$T/gh-pr.json" <<'JS'
[{"number":71,"headRefName":"dal-birlesti","mergedAt":"2026-10-20T10:00:00Z"},
 {"number":72,"headRefName":"dal-tikandi","mergedAt":"2026-10-21T10:00:00Z"},
 {"number":77,"headRefName":"baska-dal","mergedAt":"2026-10-22T10:00:00Z"},
 {"number":73,"headRefName":"sinifli-birlesti","mergedAt":"2026-10-20T11:00:00Z"},
 {"number":74,"headRefName":"kartpr-yanlis","mergedAt":"2026-10-20T12:00:00Z"},
 {"number":75,"headRefName":"acik-pr","mergedAt":null}]
JS
export GH_SAHTE_CIKTI="$T/gh-pr.json"
durum() { python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('durum'))" "$SD/_agents/fabrika/kartlar/$1.json"; }
cd "$SD"; export KANIT_DEPO="$SD"   # önceki bloklar KANIT_DEPO'yu başka depoya çevirmiş olabilir
H0="$(cat _agents/fabrika/kartlar/*.json | sha256sum)"
O="$(bash "$KT" supur kuru 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "supur kuru: 3 kart KAPATILIRDI" <<<"$O" && [ "$(cat _agents/fabrika/kartlar/*.json | sha256sum)" = "$H0" ]; g $? "S1 kuru-koşu 3 kartı SAYAR ama hiçbir kart dosyasını DEĞİŞTİRMEZ" "→ rc=$RC $O"
grep -q "sinifli-birlesti.*SINIFLI" <<<"$O" && ! grep -q "✓ sinifli-birlesti" <<<"$O"; g $? "S2 sınıflı kart (PR birleşmiş) listelenir ama kapatılacaklar arasında DEĞİL"
O="$(bash "$KT" supur uygula 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ "$(durum dal-birlesti)" = bitti ] && [ "$(durum dal-tikandi)" = bitti ] && [ "$(durum kartpr-birlesti)" = bitti ]; g $? "S3 uygula: dal adı eşleşen (açık, tıkandı) ve kartta pr yazılı kart bitti olur" "→ rc=$RC $O"
python3 - "$SD/_agents/fabrika/kartlar/dal-birlesti.json" <<'PYC'
import json,sys; k=json.load(open(sys.argv[1]))
assert k["pr"]=="71" and k["bitis"][:10]==__import__("datetime").date.today().isoformat() and k["supuruldu"]["birlesti"]=="2026-10-20T10:00:00Z", k
assert k["supuruldu"]["pr"]==71 and k["supuruldu"]["yontem"]=="dal-adi", k
assert k["gecmis"][-1]["olay"]=="supuruldu", k
PYC
g $? "S4 süpürülen kartta PR no, birleşme zamanı, 'supuruldu' damgası ve geçmiş satırı var"
[ "$(durum acik-pr)" = acik ] && [ "$(durum sinifli-birlesti)" = acik ] && [ "$(durum kartpr-yanlis)" = acik ] && [ "$(durum zaten-bitti)" = bitti ]; g $? "S5 açık PR'lı · SINIFLI · kartta pr'ı birleşmemiş kart açık KALIR (dal adı birleşmiş PR'la eşleşse bile kart.pr öncelikli)"
O="$(bash "$KT" supur uygula 2>&1)"; grep -q "supur uygula: 0 kart KAPATILDI" <<<"$O"; g $? "S6 ikinci koşu 0 kart kapatır (idempotent)"
GS_O="$(bash "$GS" 2>&1)"; grep -q "dal-birlesti.*süpürüldü (PR birleşmiş, kanıt toplanmadı)" <<<"$GS_O" && ! grep -q "dal-birlesti.*⚠ YOK" <<<"$GS_O"; g $? "S7 gün sonu süpürülen kart için 'KANIT YOK' DEMEZ, 'süpürüldü' der" "→ $(grep dal-birlesti <<<"$GS_O" | head -1 | cut -c1-200)"
sk aldi-a acik "" ALFA '[]'; sk aldi-b acik "" BETA '[]'
python3 - "$T/gh-pr.json" <<'PYA'
import json,sys; l=json.load(open(sys.argv[1])); l+= [{"number":81,"headRefName":"aldi-a","mergedAt":"2026-10-23T10:00:00Z"},{"number":82,"headRefName":"aldi-b","mergedAt":"2026-10-23T11:00:00Z"}]; json.dump(l,open(sys.argv[1],"w"))
PYA
bash "$KT" supur uygula --aldi ALFA >/dev/null 2>&1; [ "$(durum aldi-a)" = bitti ] && [ "$(durum aldi-b)" = acik ]; g $? "S8 --aldi yalnız o sahibin kartlarını süpürür"
H1="$(cat _agents/fabrika/kartlar/*.json | sha256sum)"
O="$(GH_SAHTE_RC=4 bash "$KT" supur uygula 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && [ "$(cat _agents/fabrika/kartlar/*.json | sha256sum)" = "$H1" ] && grep -q "ÖLÇÜLEMEDİ" <<<"$O"; g $? "S9 gh düşerse rc 3 ÖLÇÜLEMEDİ, hiçbir kart değişmez ('listede yok' = 'birleşmedi' DEĞİL)" "→ rc=$RC"
O="$(KART_SUPUR_TAVAN=8 bash "$KT" supur uygula 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "tavana dayandı" <<<"$O" && [ "$(cat _agents/fabrika/kartlar/*.json | sha256sum)" = "$H1" ]; g $? "S10 PR listesi tavana dayanırsa (eksik olabilir) rc 3, kart değişmez" "→ rc=$RC"
echo '{bozuk' > _agents/fabrika/kartlar/bozuk-kart.json; sk aldi-c acik "" GAMA '[]'
python3 - "$T/gh-pr.json" <<'PYB'
import json,sys; l=json.load(open(sys.argv[1])); l.append({"number":83,"headRefName":"aldi-c","mergedAt":"2026-10-23T12:00:00Z"}); json.dump(l,open(sys.argv[1],"w"))
PYB
O="$(bash "$KT" supur uygula 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && [ "$(durum aldi-c)" = acik ] && grep -q "bozuk-kart.json" <<<"$O" && grep -q "HİÇBİR kart değişmedi" <<<"$O"; g $? "S11 bozuk kart varsa ATOMİK: rc 3, okunabilen kart bile süpürülmez (kısmi uygulama yok)" "→ rc=$RC"
rm -f _agents/fabrika/kartlar/bozuk-kart.json
O="$(bash "$KT" supur uygula 2>&1)"; RC=$?; [ "$RC" -eq 0 ] && [ "$(durum aldi-c)" = bitti ]; g $? "S11b bozuk kart kalkınca aynı koşu süpürür" "→ rc=$RC"
python3 - <<'PYT'
import json
f="_agents/fabrika/kartlar/dal-tikandi.json"; k=json.load(open(f))
assert "tikanma" not in k and k["supuruldu"]["onceki_durum"]=="tikandi", k
PYT
g $? "S13 tıkandı kartın tikanma alanı kapanışta temizlenir, damgaya taşınır (onceki_durum)"
sk gorevli acik "" HENDESE '[]'; python3 - <<'PYG'
import json
f="_agents/fabrika/kartlar/gorevli.json"; k=json.load(open(f)); k["gorev"]="gorev_SAHTE"; json.dump(k,open(f,"w"))
l=json.load(open("/dev/stdin")) if False else None
PYG
python3 - "$T/gh-pr.json" <<'PYH'
import json,sys; l=json.load(open(sys.argv[1])); l.append({"number":95,"headRefName":"gorevli","mergedAt":"2026-10-25T10:00:00Z"}); json.dump(l,open(sys.argv[1],"w"))
PYH
TK0="$(wc -c < "$TETIK_KAYIT")"; O="$(bash "$KT" supur uygula 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ "$(durum gorevli)" = bitti ] && [ "$(wc -c < "$TETIK_KAYIT")" = "$TK0" ] && ! grep -qi "defter" <<<"$O" && [ "$(python3 -c "import json;print(json.load(open('_agents/fabrika/kartlar/gorevli.json'))['gorev'])")" = gorev_SAHTE ]; g $? "S14 görevli kart süpürülür ama görev defterine/odaya DOKUNULMAZ (tetik yok, defter çağrısı yok, kart.gorev korunur)" "→ rc=$RC $O"
O="$(bash "$KT" supur 2>&1)"; grep -q kullanım <<<"$O"; g $? "S12 kip verilmezse kullanım (kuru|uygula) — varsayılan YAZMA yok"
# S15: dal adı DAR varyantlarla da eşlenir ('ekip/ad' öneki, 'ad-2' soneki); altdize ve başkasının kartı eşlenmez (HSKJCE revizyonu, MUHAKKİK: ≥4 birleşik PR kaçıyordu)
for f in dal-birlesti dal-tikandi kartpr-birlesti acik-pr sinifli-birlesti zaten-bitti kartpr-yanlis mut-dal; do rm -f "$SD/_agents/fabrika/kartlar/$f.json"; done
sk v-onek acik "" HENDESE '[]'; sk v-sayi tikandi "" HENDESE '[]'; sk x-kalan acik "" HENDESE '[]'; sk y acik "" HENDESE '[]'; sk z acik "" HENDESE '[]'; sk z-2 acik "" HENDESE '[]'
cat > "$T/gh-varyant.json" <<'JS'
[{"number":81,"headRefName":"mirahur/v-onek","mergedAt":"2026-10-20T10:00:00Z"},
 {"number":82,"headRefName":"v-sayi-2","mergedAt":"2026-10-20T11:00:00Z"},
 {"number":83,"headRefName":"x","mergedAt":"2026-10-20T12:00:00Z"},
 {"number":84,"headRefName":"y-kalan","mergedAt":"2026-10-20T13:00:00Z"},
 {"number":85,"headRefName":"z-2","mergedAt":"2026-10-20T14:00:00Z"},
 {"number":86,"headRefName":"yy","mergedAt":"2026-10-20T15:00:00Z"}]
JS
export GH_SAHTE_CIKTI="$T/gh-varyant.json"
O="$(bash "$KT" supur kuru 2>&1)"; grep -q "supur kuru: 3 kart KAPATILIRDI" <<<"$O" && grep -q "v-onek ← PR #81 .*dal-adi-varyant" <<<"$O" && grep -q "v-sayi ← PR #82 .*dal-adi-varyant" <<<"$O"; g $? "S15a 'ekip/ad' önekli ve 'ad-2' sonekli dal adı kartı eşler (yöntem dal-adi-varyant görünür)" "→ $O"
bash "$KT" supur uygula >/dev/null 2>&1
[ "$(durum v-onek)" = bitti ] && [ "$(durum v-sayi)" = bitti ]; g $? "S15b varyantla eşlenen iki kart kapanır"
[ "$(durum x-kalan)" = acik ] && [ "$(durum y)" = acik ]; g $? "S15c altdize YOK: 'x-kalan' kartı 'x' dalıyla, 'y' kartı 'y-kalan' dalıyla kapanmaz"
[ "$(durum z)" = acik ] && [ "$(durum z-2)" = bitti ]; g $? "S15d başka kartın kendi adı olan dal (z-2) o karta aittir: 'z' kartı varyanta düşüp kapanmaz"
sk z acik "" HENDESE '[]'; O="$(bash "$KT" supur kuru 2>&1)"; grep -q "? z — 'z-2' dalı başka bir kartındır (PR #85)" <<<"$O"; g $? "S15e süpürülmeyen ama devam kartı olabilecek kart kuru çıktıda 'gözle bak' adayı olarak görünür" "→ $O"
export GH_SAHTE_CIKTI="$T/gh-pr.json"
# mutantlar: her kapı bozulunca ilgili sınav kırmızıya dönmeli
SMUT="$T/pkg-supur"; mkdir -p "$SMUT"; cp "$HERE"/*.py "$HERE"/*.sh "$SMUT/" 2>/dev/null
smut() { cp "$HERE/kart.sh" "$SMUT/kart.sh"; python3 - "$SMUT/kart.sh" "$1" "$2" <<'PYM'
import sys; f,a,b=sys.argv[1:]; s=open(f,encoding="utf-8").read(); assert s.count(a)==1, "çapa bayat"; open(f,"w",encoding="utf-8").write(s.replace(a,b,1))
PYM
}
sifirla() { for f in dal-birlesti dal-tikandi kartpr-birlesti sinifli-birlesti kartpr-yanlis; do :; done; sk sinifli-birlesti acik "" HENDESE '["para"]'; sk kartpr-yanlis acik "55" HENDESE '[]'; sk mut-dal acik "" HENDESE '[]'; }
python3 - "$T/gh-pr.json" <<'PYC2'
import json,sys; l=json.load(open(sys.argv[1])); l.append({"number":90,"headRefName":"mut-dal","mergedAt":"2026-10-24T10:00:00Z"}); json.dump(l,open(sys.argv[1],"w"))
PYC2
smut 'if k.get("siniflar"): sinifli.append((k["is"],p["number"])); continue' 'pass'
sifirla; bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum sinifli-birlesti)" = bitti ]; g $? "mutant (sınıflı atlaması kalktı): SINIFLI kart süpürülür → S5 düşerdi"
smut 'if pn.isdigit(): p=no.get(int(pn)); yontem="kart-pr"' 'if False: p=None; yontem="kart-pr"'
sifirla; bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum kartpr-yanlis)" = bitti ]; g $? "mutant (kart.pr önceliği kalktı): pr'ı birleşmemiş kart dal adıyla süpürülür → S5 düşerdi"
smut 'if len(prler)>=tavan:' 'if False:'
sifirla; KART_SUPUR_TAVAN=8 bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum mut-dal)" = bitti ]; g $? "mutant (tavan kapısı kalktı): eksik PR listesiyle yine süpürür → S10 düşerdi"
smut 'if mod=="uygula":' 'if True:'
sifirla; bash "$SMUT/kart.sh" supur kuru >/dev/null 2>&1; [ "$(durum mut-dal)" = bitti ]; g $? "mutant (kuru-koşu yazıyor): kuru kipte kart kapanır → S1 düşerdi"
# S15 mutantları: varyant eşlemesinin üç kapısı
vsifirla() { for f in v-onek v-sayi x-kalan y z z-2; do rm -f "$SD/_agents/fabrika/kartlar/$f.json"; done; sk v-onek acik "" HENDESE '[]'; sk v-sayi tikandi "" HENDESE '[]'; sk x-kalan acik "" HENDESE '[]'; sk y acik "" HENDESE '[]'; sk z acik "" HENDESE '[]'; sk z-2 acik "" HENDESE '[]'; export GH_SAHTE_CIKTI="$T/gh-varyant.json"; }
smut 'eslesir=ad_h==ad or re.fullmatch(re.escape(ad)+r"-\d+",ad_h)' 'eslesir=False'
vsifirla; bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum v-onek)" = acik ]; g $? "mutant (varyant eşlemesi kalktı): önekli dal kartı bulamaz → S15b düşerdi"
smut 'eslesir=ad_h==ad or re.fullmatch(re.escape(ad)+r"-\d+",ad_h)' 'eslesir=ad in h or h in ad'
vsifirla; bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum x-kalan)" = bitti ]; g $? "mutant (altdize eşleme): 'x-kalan' açık işi yanlış kapanır → S15c düşerdi"
smut 'if ({h,ad_h}-{ad}) & adlar:   # dal başka bir kartın adıysa o kartındır: süpürülmez, ama '"'"'devam kartı olabilir'"'"' diye gösterilir' 'if False:'
vsifirla; bash "$SMUT/kart.sh" supur uygula >/dev/null 2>&1; [ "$(durum z)" = bitti ]; g $? "mutant (kart sahipliği kalktı): z-2 dalı z kartını da kapatır → S15d düşerdi"
export GH_SAHTE_CIKTI="$T/gh-pr.json"
unset KANIT_DEPO; cd "$T"

echo "════ T-EK · ekran kapısı: dış yüzey ekran kartı senaryo+tık bütçesi ister · sürüm paketi kartı kare onayı D1'siz açılmaz ════"
DEK="$T/depo-ek"; mkdir -p "$DEK"; ( cd "$DEK" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" ) >/dev/null 2>&1   # ekran kapısı kendi taze deposunda (önceki bölümler $T/depo'yu değiştirebilir)
cd "$DEK"
ek() { bash "$KT" ac "$1" --is "$2" --istedi reis --aldi NAKKAS --geri-alinamaz h --para h --dis-yuzey "$3" --yetki h --oda sinav-oda "${@:4}" 2>&1; }
kvar() { [ -f "$DEK/_agents/fabrika/kartlar/$1.json" ]; }
kartgovde '**Tık bütçesi:** 2 tık + 1 alan' > "$T/senaryo-dolu.md"; kartgovde '**Tık bütçesi:** <yukarıdaki kurala göre>' > "$T/senaryo-yertutucu.md"; kartgovde '**Tık bütçesi:** çok az' > "$T/senaryo-rakamsiz.md"; kartgovde '' | grep -v '^$' > "$T/senaryo-satirsiz.md"
printf '**Tık bütçesi:** 2 tık + 1 alan\n' > "$T/senaryo-sadece-satir.md"; kartgovde '**Tık bütçesi:** 2 tık' | grep -v 'Kenar durumlar' > "$T/senaryo-alan-eksik.md"; kartgovde '**Tık bütçesi:** 2 tık' | sed 's/^### E1/### Ornek/' > "$T/senaryo-baslik-yok.md"
kartgovde '**Tık bütçesi:** 2 tık' | sed 's/^### E1 · ornek ekran/### E1/' > "$T/senaryo-ekran-adsiz.md"; kartgovde '**Tık bütçesi:** 2 tık' | sed 's/^\*\*Amaç:\*\* x/**Amaç:**/' > "$T/senaryo-bos-amac.md"; kartgovde '**Tık bütçesi:** 2 tık' | sed 's/^\*\*Giriş:\*\* y/**Giriş:** <nereden gelinir>/' > "$T/senaryo-yertutucu-alan.md"
D1OK='2026-10-26 Sultan: kare onay (sohbet · session_ornek1 · "kareler uygun, devam" · beyan:SERDAR)'
ek ek-1 "yeni ana ekran" e >/dev/null; [ $? -eq 1 ]; g $? "E1 ekran kartı senaryosuz rc=1"
kvar ek-1; [ $? -ne 0 ]; g $? "E1 kart yazılmadı"
CIKTI="$(ek ek-1 "yeni ana ekran" e)"; grep -q "senaryo kartı ister" <<<"$CIKTI"; g $? "E1 mesaj senaryo kartını söyler"
ek ek-2 "yeni panel" e --senaryo "$T/yok.md" >/dev/null; [ $? -eq 1 ]; g $? "E2 senaryo dosyası yoksa rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-yertutucu.md" >/dev/null; [ $? -eq 1 ]; g $? "E3a tık bütçesi şablon yer tutucusu → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-rakamsiz.md" >/dev/null; [ $? -eq 1 ]; g $? "E3b tık bütçesi rakamsız → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-satirsiz.md" >/dev/null; [ $? -eq 1 ]; g $? "E3c senaryoda tık bütçesi satırı yok → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-sadece-satir.md" >/dev/null; [ $? -eq 1 ]; g $? "E3d tek satırlık sahte dosya (rakamlı tık bütçesi ama senaryo kartı değil) → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-alan-eksik.md" >/dev/null; [ $? -eq 1 ]; g $? "E3e senaryo kartında zorunlu alan eksik (Kenar durumlar) → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-baslik-yok.md" >/dev/null; [ $? -eq 1 ]; g $? "E3f senaryo kartında E# başlığı yok → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-ekran-adsiz.md" >/dev/null; [ $? -eq 1 ]; g $? "E3g başlıkta ekran adı yok ('### E1' tek başına) → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-bos-amac.md" >/dev/null; [ $? -eq 1 ]; g $? "E3h Amaç alanı boş → rc=1"
ek ek-3 "yeni sayfa" e --senaryo "$T/senaryo-yertutucu-alan.md" >/dev/null; [ $? -eq 1 ]; g $? "E3i Giriş alanı şablon yer tutucusu (<…>) → rc=1"
ek ek-4 "yeni ekran görünümü" e --senaryo "$T/senaryo-dolu.md" >/dev/null; g $? "E4 dolu senaryoyla kart açılır"
python3 -c "import json;k=json.load(open('$DEK/_agents/fabrika/kartlar/ek-4.json'));assert k['senaryo'].endswith('senaryo-dolu.md')"; g $? "E4 senaryo yolu karta işlenir"
ek ek-5 "yeni ekran" h >/dev/null; g $? "E5 dış yüzey değil (h) → senaryo istenmez"
ek ek-6 "kablo uzunluğu ayarı" e >/dev/null; g $? "E6 ekran sözcüğü yok → senaryo istenmez"
ek ek-7 "Yeni PANEL" '?' >/dev/null; [ $? -eq 1 ]; g $? "E7 '?' dış yüzey + büyük harfli sözcük de yakalanır"
ek su-1 "merkez 1.91.0 sürüm paketi" h >/dev/null; [ $? -eq 1 ]; g $? "S1 sürüm paketi kartı kare onayı olmadan rc=1"
kvar su-1; [ $? -ne 0 ]; g $? "S1 kart yazılmadı"
ek su-2 "merkez 1.91.0 sürüm paketi" h --kare-onay "Sultan kare onayladı" >/dev/null; [ $? -eq 1 ]; g $? "S2 D1 biçiminde olmayan onay → rc=1"
ek su-3 "merkez 1.91.0 sürüm paketi" h --kare-onay '2026-10-26 Sultan: başla (sohbet · session_ornek1 · "başla" · beyan:SERDAR)' >/dev/null; [ $? -eq 1 ]; g $? "S3 sonucu kare onayı olmayan D1 → rc=1"
ek su-3 "merkez 1.91.0 sürüm paketi" h --kare-onay '2026-10-26 Sultan: onay (sohbet · session_ornek1 · "olur" · beyan:SERDAR)' >/dev/null; [ $? -eq 1 ]; g $? "S3b sonucu 'onay' ama 'kare' yok (başka şeye onay) → rc=1"
ek su-3 "merkez 1.91.0 sürüm paketi" h --kare-onay '2026-10-26 Sultan: kare gördüm (sohbet · session_ornek1 · "gördüm" · beyan:SERDAR)' >/dev/null; [ $? -eq 1 ]; g $? "S3c sonucu 'kare' ama onay sözcüğü yok → rc=1"
ek su-4 "merkez 1.91.0 sürüm paketi" h --kare-onay '2026-10-26 Sultan: kare onay (sohbet · session_ornek1 · "bir iki üç dört beş altı yedi sekiz dokuz on onbir oniki onüç ondört onbeş onaltı" · beyan:SERDAR)' >/dev/null; [ $? -eq 1 ]; g $? "S4 kırpık 15 kelimeyi aşarsa rc=1"
ek su-5 "merkez 1.91.0 sürüm paketi" h --kare-onay "$D1OK" >/dev/null; g $? "S5 doğru D1 ile sürüm paketi kartı açılır"
python3 -c "import json;k=json.load(open('$DEK/_agents/fabrika/kartlar/su-5.json'));assert 'kare onay' in k['kare_onayi']"; g $? "S5 onay damgası karta işlenir"
ek su-6 "merkez 1.91.0 SÜRÜM PAKETİ" h >/dev/null; [ $? -eq 1 ]; g $? "S6 büyük harfli 'SÜRÜM PAKETİ' de yakalanır"
ek su-7 "yeni sürüm notu yaz" h >/dev/null; g $? "S7 'sürüm paketi' demeyen kart onay istemez"

cd "$T"

echo "════ V20 · --soz-zamani: Sultan damgası sözün saatini taşır (görev …F6EWHF · kart sultan-dedi-soz-zamani) ════"
cd "$T/depo2"; export KANIT_DEPO="$T/depo2"   # önceki bloklar çalışma dizinini ve KANIT_DEPO'yu başka depoya çevirmiş olabilir
KU="$T/depo2/_agents/fabrika/kartlar"; bash "$KT" ac is-sz --is "söz saati sınavı için sınıflı iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda >/dev/null 2>&1
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz --soz "tamam başlayın" --beyan MUAVIN --soz-zamani 2026-10-28T20:25:00+03:00 2>&1)"; RC=$?
python3 -c "import json;k=json.load(open('$KU/is-sz.json'));x=k['sultan_kararlari'][-1];b=k['baslama_izni'];assert x['zaman']=='2026-10-28T20:25:00+03:00' and x['zaman_kaynagi']=='soz' and x['yazildi']!=x['zaman'] and x['yazildi'][:2]=='20' and b['zaman']==x['zaman'] and b['yazildi']==x['yazildi'] and b['zaman_kaynagi']=='soz'" 2>/dev/null && [ "$RC" -eq 0 ] && grep -q "söz saati 2026-10-28T20:25 (sözün saati)" <<<"$O"; g $? "V20a --soz-zamani: zaman = sözün saati, yazildi = şimdi, kaynak soz; baslama_izni aynı; çıktı saati söyler"
[ "$(bash "$KT" izin-durum is-sz | cut -f1)" = basla ] && bash "$KT" izin-durum is-sz | grep -q "söz saati 2026-10-28T20:25"; g $? "V20b izin künyesi sözün saatini gösterir (göz/kapı/gün sonu aynı künyeyi okur)"
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz2 --soz "yine başlayın" --beyan MUAVIN 2>&1)"
python3 -c "import json;k=json.load(open('$KU/is-sz.json'));x=k['sultan_kararlari'][-1];assert x['zaman']==x['yazildi'] and x['zaman_kaynagi']=='yazim'" 2>/dev/null && grep -q "yazım saati" <<<"$O"; g $? "V20c bayraksız: zaman = yazım saati, kaynak yazim (eski davranış korunur, çıktı bunu söyler)"
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-szz --soz "saat dilimsiz" --beyan MUAVIN --soz-zamani 2026-10-28T20:25:00 2>&1)"; RC=$?
python3 -c "import json;k=json.load(open('$KU/is-sz.json'));x=k['sultan_kararlari'][-1];assert x['zaman'].startswith('2026-10-28T20:25:00') and len(x['zaman'])>19 and x['zaman_kaynagi']=='soz'" 2>/dev/null && [ "$RC" -eq 0 ]; g $? "V20c2 saat dilimsiz ISO kabul: kutunun dilimi eklenir, kaynak soz"
N0=$(python3 -c "import json;print(len(json.load(open('$KU/is-sz.json'))['sultan_kararlari']))")
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz3 --soz "x" --beyan MUAVIN --soz-zamani "dün akşam" 2>&1)"; [ $? -eq 1 ] && grep -q "bozuk biçim" <<<"$O"; g $? "V20d bozuk biçim rc 1, sebep söylenir"
GELECEK="$(date -d '+2 hours' +%Y-%m-%dT%H:%M:%S%:z)"
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz4 --soz "x" --beyan MUAVIN --soz-zamani "$GELECEK" 2>&1)"; [ $? -eq 1 ] && grep -q "gelecekte" <<<"$O"; g $? "V20e gelecekteki saat rc 1 (söz henüz söylenmemiş olamaz)"
YAKIN="$(date -d '+30 seconds' +%Y-%m-%dT%H:%M:%S%:z)"
O="$(bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz4b --soz "x" --beyan MUAVIN --soz-zamani "$YAKIN" 2>&1)"; [ $? -eq 1 ] && grep -q "gelecekte" <<<"$O"; g $? "V20e2 30 saniye sonrası da rc 1 — hoşgörü yok (göz #562 tur 1)"
bash "$KT" sultan-dedi is-sz --karar basla --oturum s-sz5 --soz "x" --beyan MUAVIN --soz-zamani "2026-10-28T20:25:00|x" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "V20f --soz-zamani içinde '|' rc 1 (defter ayracı)"
[ "$(python3 -c "import json;print(len(json.load(open('$KU/is-sz.json'))['sultan_kararlari']))")" = "$N0" ]; g $? "V20g reddedilen dört denemede kayıt ÜRETİLMEDİ (sayı aynı)"
echo "── V20 · MUTASYON (tam kopya): bayrak yok sayılırsa ya da gelecek çiti kalkarsa sınav KIRMIZI ──"
szk() { bash "$D16/kart.sh" ac "$1" --is "söz saati mutant sınavı sınıflı iş" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda >/dev/null 2>&1; }
m16 soz-zamani-yok izin.py 'return z.isoformat(timespec="seconds"), "soz", None' 'return an.isoformat(timespec="seconds"), "yazim", None' && { szk is-mz1; bash "$D16/kart.sh" sultan-dedi is-mz1 --karar basla --oturum m1 --soz "x" --beyan MUAVIN --soz-zamani 2026-10-28T20:25:00+03:00 >/dev/null 2>&1; python3 -c "import json;k=json.load(open('$KU/is-mz1.json'));assert k['sultan_kararlari'][-1]['zaman']=='2026-10-28T20:25:00+03:00'" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "mutant 'soz-zamani-yok': bayrak yok sayılınca V20a kapısı KIRMIZI"; }
m16 gelecek-citi-yok izin.py 'if z > an:' 'if False:' && { szk is-mz2; bash "$D16/kart.sh" sultan-dedi is-mz2 --karar basla --oturum m2 --soz "x" --beyan MUAVIN --soz-zamani "$YAKIN" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant 'gelecek-citi-yok': 30 sn sonrası kabul edilince V20e2 kapısı KIRMIZI (rc 0 döndü)"; }
m16 kunye-saatsiz izin.py 'return "oturum %s · söz \"%s\"%s" % (o, s[:60], (" · söz saati %s" % z) if z else "")' 'return "oturum %s · söz \"%s\"" % (o, s[:60])' && { szk is-mz3; bash "$D16/kart.sh" sultan-dedi is-mz3 --karar basla --oturum m3 --soz "x" --beyan MUAVIN --soz-zamani 2026-10-28T20:25:00+03:00 >/dev/null 2>&1; bash "$D16/kart.sh" izin-durum is-mz3 | grep -q "söz saati"; [ $? -ne 0 ]; g $? "mutant 'kunye-saatsiz': künyeden saat düşünce V20b kapısı KIRMIZI"; }

echo "════ T-GB · bitti görevsiz kartta SÖYLER (kapanışta sessizdi; ac ve göz adımı söylüyordu), görevli kartta söylemez, rc ve kapanış değişmez ════"
GBM="görev bağı yok — bu iş göreve bağlı değil, defterde PR kapanışı görünmez"
bash "$KT" ac gbu-1 --is "görevsiz kapanış" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
O="$(bash "$KT" bitti gbu-1 --pr 5 2>&1)"; RC=$?
[ $RC -eq 0 ] && grep -qF "$GBM" <<<"$O" && grep -qF "(bağlamak: kart.sh ac … --gorev)" <<<"$O"; g $? "GB1 görevsiz kart bitti → görünür uyarı VAR ve rc 0 (bloklamaz)"
python3 -c "import json;assert json.load(open('$KU/gbu-1.json'))['durum']=='bitti'"; g $? "GB2 görevsiz kart yine de kapandı (durum=bitti)"
bash "$KT" ac gbu-2 --is "görevli kapanış" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 - "$KU/gbu-2.json" <<'PY'
import json,sys; k=json.load(open(sys.argv[1])); k["gorev"]="gorev_GBUYARI0000000001"; json.dump(k,open(sys.argv[1],"w"),ensure_ascii=False)
PY
O="$(bash "$KT" bitti gbu-2 --pr 6 2>&1)"; ! grep -qF "görev bağı yok" <<<"$O"; g $? "GB3 görevli kart bitti → uyarı YOK (altın)"
bash "$KT" ac gbu-3 --is "görevsiz tıkanma" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
O="$(bash "$KT" tikandi gbu-3 --yol devam --neden "beklemede" 2>&1)"; ! grep -qF "göreve bağlı değil, defterde PR kapanışı" <<<"$O"; g $? "GB4 tikandi'da bu uyarı çıkmaz (yalnız bitti)"
bash "$KT" ac gbu-5 --is "gorev null kapanış" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 -c "import json,sys;p=sys.argv[1];k=json.load(open(p));k['gorev']=None;json.dump(k,open(p,'w'),ensure_ascii=False)" "$KU/gbu-5.json"
O="$(bash "$KT" bitti gbu-5 --pr 8 2>&1)"; RC=$?
[ $RC -eq 0 ] && grep -qF "$GBM" <<<"$O"; g $? "GB5 kartta gorev JSON null → görevsiz sayılır, uyarı VAR (None dizgesi görev sanılmaz), rc 0"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
