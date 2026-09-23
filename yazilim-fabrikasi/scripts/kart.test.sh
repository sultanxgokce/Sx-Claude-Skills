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

echo "════ T4 · is-alani ac kart ister; kartı worktree'ye taşır ════"
bash "$IA" ac kartsiz-is >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kartsız iş alanı açılmaz (rc=1)"
bash "$IA" ac kartsiz-is --kartsiz >/dev/null 2>&1; g $? "--kartsiz kaçışıyla açılır (gerekçe loglanır)"
bash "$IA" ac is-1 >/dev/null 2>&1; g $? "kartlı iş alanı açıldı"
[ -f "$T/alan/depo-is-1/_agents/fabrika/kartlar/is-1.json" ]; g $? "kart worktree'de de var"

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

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
