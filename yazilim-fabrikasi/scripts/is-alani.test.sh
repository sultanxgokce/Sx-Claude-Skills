#!/usr/bin/env bash
# is-alani.test.sh — iş-alanı korumasını SAHTE depoda gerçekten koşturur (cloudtop sınavı temel + kapsam kontrolü).
# İki yönü de ölçer: engellemesi gerekeni engelliyor mu, meşru işi (main'e commit, izole alan) engellemiyor mu.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS="$HERE/is-alani.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

commit_gorunuyor() {
  local dizin="$1" mesaj="$2" i
  for i in 1 2 3 4 5; do
    ( cd "$dizin" && git log --oneline 2>/dev/null | grep -q -- "$mesaj" ) && return 0
    sleep 0.05
  done
  return 1
}

kur() {
  local T; T="$(mktemp -d)"
  mkdir -p "$T/uzak" "$T/depo"
  ( cd "$T/uzak" && git init -q --bare ) >/dev/null 2>&1
  ( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T &&
    echo ilk > dosya.txt && git add -A && git commit -qm "chore: ilk" &&
    git remote add origin "$T/uzak" && git push -q -u origin main ) >/dev/null 2>&1
  echo "$T"
}

T="$(kur)"
export IS_ALANI_DEPO="$T/depo" IS_ALANI_KOK="$T/alan"

echo "════ T0 · kanca-kur: şablondan kopyalar, hooksPath ayarlar, idempotent ════"
( cd "$T/depo" && bash "$IS" kanca-kur ) >/dev/null 2>&1; g $? "kanca kuruldu"
[ -x "$T/depo/.githooks/pre-commit" ]; g $? "pre-commit dosyası var ve çalıştırılabilir"
[ "$(git -C "$T/depo" config core.hooksPath)" = ".githooks" ]; g $? "core.hooksPath=.githooks"
# Not: `komut | grep -q` KULLANMA — grep ilk eşleşmede kapanır, üretici SIGPIPE alır, pipefail rc'yi kirletir (sahte kırmızı).
CIKTI="$( cd "$T/depo" && bash "$IS" kanca-kur 2>&1 )"; grep -q "zaten" <<<"$CIKTI"; g $? "ikinci kurulum: dokunmadı (idempotent)"

echo "════ T1 · paylaşılan ağaç · main → SERBEST ════"
( cd "$T/depo" && echo a >> dosya.txt && git add -A && git commit -qm "chore: ana dal" ) >/dev/null 2>&1
g $? "main'e commit atılabildi"
commit_gorunuyor "$T/depo" "chore: ana dal"; g $? "commit gerçekten düştü"

echo "════ T2 · paylaşılan ağaç · özellik dalı → BLOKE ════"
( cd "$T/depo" && git checkout -q -b ozellik && echo b >> dosya.txt && git add -A )
CIKTI="$( cd "$T/depo" && git commit -m "chore: ozellik" 2>&1 )"; RC=$?
[ "$RC" -ne 0 ]; g $? "commit ENGELLENDİ (rc=$RC)"
grep -q "is-alani.sh ac" <<<"$CIKTI"; g $? "ne yapılacağı komutla yazılı"
( cd "$T/depo" && ! git log --oneline | grep -q "chore: ozellik" ); g $? "commit gerçekten düşmedi"

echo "════ T3 · acil kaçış ════"
( cd "$T/depo" && PAYLASILAN_COMMIT=1 git commit -qm "chore: acil" ) >/dev/null 2>&1
g $? "PAYLASILAN_COMMIT=1 ile geçilebiliyor"
( cd "$T/depo" && git checkout -q main ) >/dev/null 2>&1

echo "════ T4 · ac: kendi alanı, origin/main'den, <depo>-<iş> adıyla ════"
CIKTI="$( cd "$T/depo" && bash "$IS" ac yeni-is --kartsiz 2>&1 )"; g $? "alan açıldı"
[ ! -e "$T/alan/depo-yeni-is/_agents/fabrika/kartlar" ]; g $? "kart iş alanına KOPYALANMADI (tek kaynak birincil; 15 Eki — kopya bayatlıyor ve PR'la birincil pull'unu tıkıyordu)"
grep -q "kopyalanmadı" <<<"$CIKTI"; g $? "açılış mesajı kartın birincilde kaldığını söylüyor"
grep -q "TAZE" <<<"$CIKTI"; g $? "origin/main üstünde açtığını söylüyor"
grep -q "PAYLAŞILAN KAYNAĞI izole etmez" <<<"$CIKTI"; g $? "paylaşılan-kaynak uyarısı basıldı"
grep -q "dosya listesi verilmedi" <<<"$CIKTI"; g $? "kapsam bakılmadığını SÖYLÜYOR (sessiz atlama yok)"
[ -d "$T/alan/depo-yeni-is" ]; g $? "worktree dizini <depo>-<iş> adıyla var"
( cd "$T/alan/depo-yeni-is" && echo c >> dosya.txt && git add -A && git commit -qm "chore: izole" ) >/dev/null 2>&1
g $? "İZOLE alanda özellik dalına commit SERBEST"
commit_gorunuyor "$T/alan/depo-yeni-is" "chore: izole"; g $? "commit düştü"
( cd "$T/depo" && bash "$IS" ac yeni-is --kartsiz >/dev/null 2>&1 ); [ $? -ne 0 ]; g $? "aynı adla ikinci açılış REDDEDİLDİ"

echo "════ T5 · kontrol üç durum ════"
CIKTI="$( cd "$T/alan/depo-yeni-is" && bash "$IS" kontrol 2>&1 )"; grep -q "güvenli" <<<"$CIKTI"; g $? "izole alanda: güvenli (IS_ALANI_DEPO dışarıdan verilmişken bile)"
CIKTI="$( cd "$T/depo" && bash "$IS" kontrol 2>&1 )"; grep -q "güvenli" <<<"$CIKTI"; g $? "paylaşılan+main: güvenli"
( cd "$T/depo" && git checkout -q -b riskli-dal )
CIKTI="$( cd "$T/depo" && bash "$IS" kontrol 2>&1 )"; RC=$?
[ "$RC" -eq 1 ]; g $? "paylaşılan+özellik dalı: rc=1"
grep -q "RİSKLİ" <<<"$CIKTI"; g $? "riskli olduğunu söylüyor"
( cd "$T/depo" && git checkout -q main )

echo "════ T6 · kapat: kirli alanı silmez ════"
echo kirli > "$T/alan/depo-yeni-is/kirli.txt"
( cd "$T/depo" && bash "$IS" kapat yeni-is >/dev/null 2>&1 ); [ $? -ne 0 ]; g $? "kayıtsız değişiklik varken KAPATMADI"
[ -d "$T/alan/depo-yeni-is" ]; g $? "alan yerinde (iş kaybı yok)"
rm -f "$T/alan/depo-yeni-is/kirli.txt"
# 🔴 göz tur 1: kartlar/ altındaki İZLENEN ve DEĞİŞTİRİLMİŞ dosya iş'tir — kapat onu ne kir dışı sayar ne siler
WT="$T/alan/depo-yeni-is"; mkdir -p "$WT/_agents/fabrika/kartlar"; echo '{"is":"izlenen"}' > "$WT/_agents/fabrika/kartlar/izlenen.json"
( cd "$WT" && git add _agents/fabrika/kartlar/izlenen.json && git -c user.email=t@t -c user.name=T commit -qm "chore: izlenen kart" ) >/dev/null 2>&1
echo '{"is":"izlenen","degisti":1}' > "$WT/_agents/fabrika/kartlar/izlenen.json"
( cd "$T/depo" && bash "$IS" kapat yeni-is >/dev/null 2>&1 ); [ $? -ne 0 ]; g $? "🔴 kartlar/ altında İZLENEN+DEĞİŞMİŞ dosya varken KAPATMADI (iş sayıldı)"
[ -d "$WT" ] && grep -q '"degisti":1' "$WT/_agents/fabrika/kartlar/izlenen.json"; g $? "izlenen kart dosyası SİLİNMEDİ, değişiklik yerinde (iş kaybı yok)"
echo '{"is":"eklenen"}' > "$WT/_agents/fabrika/kartlar/eklenen.json"; ( cd "$WT" && git add _agents/fabrika/kartlar/eklenen.json ) >/dev/null 2>&1
( cd "$T/depo" && bash "$IS" kapat yeni-is >/dev/null 2>&1 ); [ $? -ne 0 ] && [ -f "$WT/_agents/fabrika/kartlar/eklenen.json" ]; g $? "indekse EKLENMİŞ (A) kart dosyası da iş: kapatmadı, silmedi"
( cd "$WT" && git reset -q HEAD _agents/fabrika/kartlar/eklenen.json && git checkout -- _agents/fabrika/kartlar/izlenen.json ) >/dev/null 2>&1; rm -f "$WT/_agents/fabrika/kartlar/eklenen.json"
mkdir -p "$T/alan/depo-yeni-is/_agents/fabrika/kartlar"; echo '{"is":"yeni-is"}' > "$T/alan/depo-yeni-is/_agents/fabrika/kartlar/yeni-is.json"   # eski aracın bıraktığı kayıtsız kart kopyası
( cd "$T/depo" && bash "$IS" kapat yeni-is ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && [ ! -d "$T/alan/depo-yeni-is" ]; g $? "temizken kapatıldı — kartlar/ altındaki kayıtsız kopya 'kayıtsız iş' SAYILMADI (kart birincilde)"

echo "════ T7 · kapsam kontrolü (sahte gh): çakışma → rc=2, açmaz; temiz → açar ════"
SAHTE="$T/sahte-bin"; mkdir -p "$SAHTE"
cat > "$SAHTE/gh" <<'GH'
#!/usr/bin/env bash
# sahte gh: tek açık PR (#7) dosya.txt ve b.txt'ye dokunuyor
case "$1 $2" in
  "pr list") echo 7 ;;
  "pr diff") printf 'dosya.txt\nb.txt\n' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$SAHTE/gh"
CIKTI="$( cd "$T/depo" && PATH="$SAHTE:$PATH" bash "$IS" ac cakisan-is --kartsiz --dosyalar dosya.txt,z.txt 2>&1 )"; RC=$?
[ "$RC" -eq 2 ]; g $? "çakışmada rc=2"
grep -q "PR #7" <<<"$CIKTI"; g $? "hangi PR'la çakıştığı yazılı"
[ ! -d "$T/alan/depo-cakisan-is" ]; g $? "alan AÇILMADI"
grep -q "PR #7 tek yüzey (merge-base ölçülemedi" <<<"$CIKTI"; g $? "iki yüzey (30 Eki): sahte gh 'pr view' vermiyor → git yolu düştü, TEK YÜZEY uyarısı basıldı (sessiz düşme yok), hüküm GitHub listesinden"
CIKTI="$( cd "$T/depo" && PATH="$SAHTE:$PATH" bash "$IS" ac temiz-is --kartsiz --dosyalar z.txt 2>&1 )"; RC=$?
[ "$RC" -eq 0 ]; g $? "çakışma yokken rc=0"
grep -q "çakışması yok" <<<"$CIKTI"; g $? "kaç PR'a bakıldığı yazılı"
( cd "$T/depo" && bash "$IS" kapat temiz-is ) >/dev/null 2>&1

echo "════ T7b · dosya listesi YOKKEN benzer açık PR uyarısı (görev …Z2G: aynı iş iki kez inşa edildi) ════"
BENZ="$T/benzer-bin"; mkdir -p "$BENZ"
cat > "$BENZ/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr list") echo '[{"number":2,"title":"fix: ana dalda commit kancası komut çözümü","headRefName":"main-commit-kancasi-komut-cozumu"},{"number":3,"title":"feat: alakasız başka şey","headRefName":"alakasiz-baska-sey"}]' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$BENZ/gh"
CIKTI="$( cd "$T/depo" && PATH="$BENZ:$PATH" bash "$IS" ac ana-dal-commit-kancasi-kilidi --kartsiz 2>&1 )"; RC=$?
[ "$RC" -eq 0 ]; g $? "benzer PR varken de alan AÇILIR (yalnız uyarı, yanlış alarm işi durdurmaz)"
grep -q "BENZER İŞ: açık PR #2" <<<"$CIKTI"; g $? "benzer PR #2 adıyla uyarıldı"
! grep -q "açık PR #3" <<<"$CIKTI"; g $? "alakasız PR #3 uyarıya girmedi"
grep -q "DUR, PR'a bak" <<<"$CIKTI"; g $? "uyarı ne yapılacağını söylüyor"
( cd "$T/depo" && bash "$IS" kapat ana-dal-commit-kancasi-kilidi ) >/dev/null 2>&1
CIKTI="$( cd "$T/depo" && PATH="$BENZ:$PATH" bash "$IS" ac kapsam-raporu-yeni --kartsiz 2>&1 )"; RC=$?
grep -q "benzeyen yok" <<<"$CIKTI" && ! grep -q "BENZER İŞ" <<<"$CIKTI"; g $? "benzemeyen işte uyarı YOK, kaç PR'a bakıldığı yazılı"
( cd "$T/depo" && bash "$IS" kapat kapsam-raporu-yeni ) >/dev/null 2>&1
BOZ3="$T/bozuk3-bin"; mkdir -p "$BOZ3"; printf '#!/usr/bin/env bash\necho "bozuk{"\n' > "$BOZ3/gh"; chmod +x "$BOZ3/gh"
BOZ4="$T/bozuk4-bin"; mkdir -p "$BOZ4"; cat > "$BOZ4/gh" <<'GH4'
#!/usr/bin/env bash
python3 -c 'import json;print(json.dumps([{"number":i,"title":"x","headRefName":"y"} for i in range(50)]))'
GH4
chmod +x "$BOZ4/gh"
BOZ2="$T/bozuk2-bin"; mkdir -p "$BOZ2"; printf '#!/usr/bin/env bash\nexit 1\n' > "$BOZ2/gh"; chmod +x "$BOZ2/gh"
CIKTI="$( cd "$T/depo" && PATH="$BOZ2:$PATH" bash "$IS" ac benzer-gh-yok --kartsiz 2>&1 )"; RC=$?
[ "$RC" -eq 0 ]; g $? "gh düşünce alan yine açılır"
grep -q "benzer iş kontrolü YAPILAMADI" <<<"$CIKTI"; g $? "gh düşünce 'YAPILAMADI' denir (sessiz atlama yok)"
( cd "$T/depo" && bash "$IS" kapat benzer-gh-yok ) >/dev/null 2>&1
CIKTI="$( cd "$T/depo" && PATH="$BOZ3:$PATH" bash "$IS" ac benzer-json-bozuk --kartsiz 2>&1 )"; RC=$?
[ "$RC" -eq 0 ]; g $? "gh bozuk JSON dönerse alan yine açılır"
grep -q "gh yanıtı çözülemedi" <<<"$CIKTI"; g $? "bozuk JSON sessiz geçilmez, 'YAPILAMADI' denir"
( cd "$T/depo" && bash "$IS" kapat benzer-json-bozuk ) >/dev/null 2>&1
CIKTI="$( cd "$T/depo" && PATH="$BOZ4:$PATH" bash "$IS" ac benzer-tavan --kartsiz 2>&1 )"
grep -q "tavana (50) ulaştı" <<<"$CIKTI"; g $? "50 açık PR tavanına ulaşılınca söylenir"
( cd "$T/depo" && bash "$IS" kapat benzer-tavan ) >/dev/null 2>&1
CIKTI="$( cd "$T/depo" && PATH="$BENZ:$PATH" bash "$IS" ac dosyali-benzer-yok --kartsiz --dosyalar z.txt 2>&1 )"
! grep -q "BENZER İŞ\|benzer iş" <<<"$CIKTI"; g $? "--dosyalar verilince benzer-iş sezgisi koşmaz (kesin kontrol var)"
( cd "$T/depo" && bash "$IS" kapat dosyali-benzer-yok ) >/dev/null 2>&1

echo "════ T8 · gh DÜŞÜNCE (yetkisiz/ağsız): ölçülemedi der, yine açar (sessiz atlama yok) ════"
BOZUK="$T/bozuk-bin"; mkdir -p "$BOZUK"; printf '#!/usr/bin/env bash\nexit 1\n' > "$BOZUK/gh"; chmod +x "$BOZUK/gh"
CIKTI="$( cd "$T/depo" && PATH="$BOZUK:$PATH" bash "$IS" ac ghsiz --kartsiz --dosyalar z.txt 2>&1 )"; RC=$?
grep -q "YAPILAMADI" <<<"$CIKTI"; g $? "kapsam kontrolü yapılamadığını söyledi"
[ -d "$T/alan/depo-ghsiz" ]; g $? "alan yine açıldı"

echo "════ T9 · worktree İÇİNDEN çağrı: birincil depo bulunur, yol çift ad almaz (13 Eki) ════"
( cd "$T/depo" && bash "$IS" ac icerden-is --kartsiz >/dev/null 2>&1 )
( cd "$T/alan/depo-icerden-is" && IS_ALANI_DEPO= bash "$IS" ac ikinci-is --kartsiz >/dev/null 2>&1 ); r=$?
[ $r -eq 0 ] && [ -d "$T/alan/depo-ikinci-is" ] && [ ! -d "$T/alan/depo-icerden-is-ikinci-is" ]; g $? "worktree içinden 'ac': alan <depo>-<iş> (çift ad değil)"
git -C "$T/alan/depo-ikinci-is" add -A >/dev/null 2>&1; git -C "$T/alan/depo-ikinci-is" -c user.email=t@t -c user.name=t commit -q -m "kart" >/dev/null 2>&1
( cd "$T/alan/depo-icerden-is" && IS_ALANI_DEPO= bash "$IS" kapat ikinci-is >/dev/null 2>&1 ); r=$?
[ $r -eq 0 ] && [ ! -d "$T/alan/depo-ikinci-is" ]; g $? "worktree içinden 'kapat': doğru alanı buldu ve kaldırdı"
( cd "$T/depo" && bash "$IS" kapat icerden-is >/dev/null 2>&1 )

echo "════ T10 · olmayan alanı kapatmak YEŞİL değil (rc 2, sahte başarı yok) ════"
CIKTI="$( cd "$T/depo" && bash "$IS" kapat boyle-bir-is-yok 2>&1 )"; r=$?
[ $r -eq 2 ] && grep -q "YOK" <<<"$CIKTI"; g $? "olmayan alan → rc 2 + 'YOK' (eskiden rc 0 'zaten yok')"

echo "════ T11 · KART KAPANIŞI (CBBQEE): PR birleşmişse kapat kartı alanın İÇİNDEN 'bitti' yapar; değilse açık bırakır ve söyler ════"
GHK="$T/gh-kart"; mkdir -p "$GHK"; : > "$T/pr-harita"; : > "$T/gh-log"
cat > "$GHK/gh" <<GH
#!/usr/bin/env bash
echo "\$*" >> "$T/gh-log"
h=""; while [ \$# -gt 0 ]; do [ "\$1" = --head ] && h="\$2"; shift; done
awk -v h="\$h" '\$1==h{print \$2}' "$T/pr-harita"
GH
chmod +x "$GHK/gh"
KD="$T/depo/_agents/fabrika/kartlar"; mkdir -p "$KD"
kart() { printf '{"is":"%s","cumle":"c","istedi":"S","aldi":"H","durum":"%s","gecmis":%s}\n' "$1" "$2" "${3:-[]}" > "$KD/$1.json"; }
kdur() { python3 -c 'import json,sys;k=json.load(open(sys.argv[1]));print(k["durum"],k.get("pr",""),k.get("kanit_var",""))' "$KD/$1.json"; }
alan_ac() {   # alan aç + kanıt dosyası YALNIZ alanda (commit'li): bitti onu görüyorsa alanın İÇİNDEN koşmuştur
  ( cd "$T/depo" && bash "$IS" ac "$1" --kartsiz >/dev/null 2>&1 )
  mkdir -p "$T/alan/depo-$1/_agents/fabrika/kanit/$1"; echo '{}' > "$T/alan/depo-$1/_agents/fabrika/kanit/$1/KANIT.json"
  git -C "$T/alan/depo-$1" add -A >/dev/null 2>&1; git -C "$T/alan/depo-$1" -c user.email=t@t -c user.name=t commit -q -m "kanit" >/dev/null 2>&1
}
kart kb1 acik; alan_ac kb1; echo "kb1 42" >> "$T/pr-harita"
CIKTI="$( cd "$T/depo" && PATH="$GHK:$PATH" bash "$IS" kapat kb1 2>&1 )"; RC=$?
[ "$RC" -eq 0 ] && [ "$(kdur kb1)" = "bitti 42 True" ] && [ ! -d "$T/alan/depo-kb1" ]; g $? "🔴 PR birleşmiş + kart açık → kart 'bitti' (pr 42) · kanıt alanın İÇİNDEN görüldü · alan kapandı ($(kdur kb1))"
grep -q "kart kendiliğinden bitti: kb1 · PR #42" <<<"$CIKTI"; g $? "kapanış ne yaptığını söylüyor"
kart kb2 acik; alan_ac kb2
CIKTI="$( cd "$T/depo" && PATH="$GHK:$PATH" bash "$IS" kapat kb2 2>&1 )"; RC=$?
[ "$RC" -eq 0 ] && [ "$(kdur kb2)" = "acik  " ] && grep -q "birleşmiş PR'ı yok — kart AÇIK kaldı" <<<"$CIKTI" && [ ! -d "$T/alan/depo-kb2" ]; g $? "PR birleşmemiş (geri al/terk) → kart AÇIK kalır + söylenir, alan kapanır"
kart kb3 acik; alan_ac kb3
CIKTI="$( cd "$T/depo" && PATH="$BOZUK:$PATH" bash "$IS" kapat kb3 2>&1 )"; RC=$?
[ "$RC" -eq 0 ] && [ "$(kdur kb3)" = "acik  " ] && grep -q "PR'ı ÖLÇÜLEMEDİ (gh) — kart AÇIK kaldı" <<<"$CIKTI"; g $? "gh düşünce ölçülemedi denir, kart açık kalır, kapanış durmaz (sessiz 'bitti' yok)"
kart kb4 bitti; alan_ac kb4; : > "$T/gh-log"; echo "kb4 9" >> "$T/pr-harita"
( cd "$T/depo" && PATH="$GHK:$PATH" bash "$IS" kapat kb4 >/dev/null 2>&1 )
[ ! -s "$T/gh-log" ] && [ "$(kdur kb4 | cut -d' ' -f1-2)" = "bitti " ]; g $? "zaten kapanmış kart: gh'ye HİÇ sorulmaz, kart değişmez"
kart kb5 acik '"bozuk"'; alan_ac kb5; echo "kb5 77" >> "$T/pr-harita"
CIKTI="$( cd "$T/depo" && PATH="$GHK:$PATH" bash "$IS" kapat kb5 2>&1 )"; RC=$?
[ "$RC" -ne 0 ] && [ -d "$T/alan/depo-kb5" ] && grep -q "kart kapanmadı, alan SİLİNMEDİ" <<<"$CIKTI"; g $? "🔴 kart.sh bitti düşerse alan SİLİNMEZ (silinseydi kart bir daha alanın içinden kapatılamazdı)"
( cd "$T/depo" && PATH="$BOZUK:$PATH" bash "$IS" kapat kb5 >/dev/null 2>&1 ) || true
echo "── T11 · MUTASYON (tam kopya): kapanış çağrısı kalkınca kart açık kalır → üstteki 🔴 kapı düşerdi ──"
MD="$T/pkg-kk"; mkdir -p "$MD"; cp "$HERE"/*.sh "$HERE"/*.py "$MD/" 2>/dev/null
python3 - "$MD/is-alani.sh" <<'PYM' && kart kbm acik && alan_ac kbm && echo "kbm 5" >> "$T/pr-harita" && ( cd "$T/depo" && PATH="$GHK:$PATH" bash "$MD/is-alani.sh" kapat kbm >/dev/null 2>&1 ); [ "$(kdur kbm 2>/dev/null)" = "acik  " ]; g $? "mutant (kart_kapanisi çağrılmıyor): birleşmiş PR'lı kart AÇIK kaldı → üstteki kapı bu mutantta düşerdi"
import sys; f=sys.argv[1]; s=open(f,encoding="utf-8").read(); a='    kart_kapanisi "$is" "$yol"'; assert s.count(a)==1; open(f,"w",encoding="utf-8").write(s.replace(a,'    :'))
PYM

echo "════ T12 · KAPSAM BAYAT LİSTE (MÜZEHHİP dersi 30 Eki 02:02): PR dalı main'i merge etmişse GitHub'ın dosya listesi main'den gelenleri de sayar; ════"
echo "          kapı yalnız o listeye bakarsa dokunulmayan dosya için SAHTE çakışma verir. Beklenen: merge-base farkı (origin/main...dal) ile ikinci yüzey ════"
# Fikstür (gerçek kayıttan: cloudtop PR #1185 gh=275 dosya · merge-base=21 · fazla 265): depo'da pr-dali açılır, kendi dosyası pr-kendi.txt;
# sonra main dosya.txt'yi değiştirir, pr-dali main'i MERGE eder. Sahte gh = GitHub'ın şişkin listesi (dosya.txt + pr-kendi.txt);
# gerçek fark `git diff --name-only origin/main...origin/pr-dali` = yalnız pr-kendi.txt.
# (T0 kancası paylaşılan ağaçta özellik dalına commit'i engeller — fikstür T3'teki acil kaçışla kurulur; `git add -A` YOK: T11'in kartlar/ artığı dala karışmasın)
( cd "$T/depo" && export PAYLASILAN_COMMIT=1 && git checkout -q -b pr-dali && echo kendi > pr-kendi.txt && git add pr-kendi.txt && git -c user.email=t@t -c user.name=T commit -qm "feat: pr kendi dosyası" &&
  git push -q -u origin pr-dali && git checkout -q main && echo main-ilerledi >> dosya.txt && git add dosya.txt && git -c user.email=t@t -c user.name=T commit -qm "chore: main ilerledi" &&
  git push -q origin main && git checkout -q pr-dali && git -c user.email=t@t -c user.name=T merge -q --no-edit main && git push -q origin pr-dali && git checkout -q main ) >/dev/null 2>&1
g $? "fikstür: pr-dali main'i merge etti, origin'de ikisi de var"
MB="$( cd "$T/depo" && git diff --name-only origin/main...origin/pr-dali )"
[ "$MB" = "pr-kendi.txt" ]; g $? "fikstür doğru: merge-base farkı YALNIZ pr-kendi.txt (dosya.txt main'den geldi) — fark: $(printf '%s' "$MB" | tr '\n' ' ')"
BAYAT="$T/bayat-bin"; mkdir -p "$BAYAT"; : > "$T/bayat-log"
cat > "$BAYAT/gh" <<GH
#!/usr/bin/env bash
# sahte gh = GitHub'ın BAYAT/ŞİŞKİN görünümü: PR #9 (pr-dali) listesinde main'den gelen dosya.txt de var
echo "\$*" >> "$T/bayat-log"
case "\$1 \$2" in
  "pr list") echo 9 ;;
  "pr diff") printf 'dosya.txt\npr-kendi.txt\n' ;;
  "pr view") case " \$* " in *" --jq "*) echo pr-dali ;; *) echo '{"number":9,"headRefName":"pr-dali","baseRefName":"main"}' ;; esac ;;
  *) exit 1 ;;
esac
GH
chmod +x "$BAYAT/gh"
# K1 — kırmızı beklenen (bug): dosya.txt yalnız şişkin listede; PR'ın gerçek farkında YOK → çakışma OLMAMALI, alan açılmalı
CIKTI="$( cd "$T/depo" && PATH="$BAYAT:$PATH" bash "$IS" ac bayat-sahte-cakisma --kartsiz --dosyalar dosya.txt 2>&1 )"; RC=$?
grep -q "PR #9\|9 PR\|1 PR" <<<"$CIKTI" && grep -q "pr diff 9" "$T/bayat-log"; g $? "pozitif kontrol: sahte gh kullanıldı, PR #9'a bakıldı (ölçüm gerçek, ÖLÇÜLEMEDİ değil)"
[ "$RC" -eq 0 ] && [ -d "$T/alan/depo-bayat-sahte-cakisma" ]; g $? "🔴 main'den gelen dosya.txt için SAHTE çakışma YOK: rc=0, alan açıldı (rc=$RC · $(printf '%s' "$CIKTI" | grep -o 'KAPSAM ÇAKIŞMASI\|çakışması yok' | head -1))"
( cd "$T/depo" && bash "$IS" kapat bayat-sahte-cakisma ) >/dev/null 2>&1 || true
# K1b — DALGIÇ ön-göz 30 Eki: git yolunun ÜÇ düşüş kapısı da tek-yüzey uyarısıyla GitHub listesine düşmeli (sessiz değil).
#   (i) pr view dal verir ama dal origin'de YOK → fetch düşer; (ii) pr view bozuk JSON → dal adı okunamaz; (iii) dal = ana → merge-base farkı BOŞ (çakışma yok, ölçüldü).
mk_gh() { # <dizin> <pr view çıktısı>
  mkdir -p "$1"; cat > "$1/gh" <<GH
#!/usr/bin/env bash
case "\$1 \$2" in
  "pr list") echo 9 ;;
  "pr diff") printf 'dosya.txt\npr-kendi.txt\n' ;;
  "pr view") printf '%s\n' '$2' ;;
  *) exit 1 ;;
esac
GH
  chmod +x "$1/gh"
}
mk_gh "$T/fetch-duser-bin" '{"number":9,"headRefName":"origin-de-olmayan-dal","baseRefName":"main"}'
CIKTI="$( cd "$T/depo" && PATH="$T/fetch-duser-bin:$PATH" bash "$IS" ac fetch-duser --kartsiz --dosyalar dosya.txt 2>&1 )"; RC=$?
[ "$RC" -eq 2 ] && grep -q "PR #9 tek yüzey (merge-base ölçülemedi: git fetch origin origin-de-olmayan-dal düştü)" <<<"$CIKTI" && [ ! -d "$T/alan/depo-fetch-duser" ]
g $? "(i) dal origin'de yok → fetch düştü → TEK YÜZEY uyarısı (sebep: fetch) + GitHub listesinden hüküm rc=2, alan açılmadı (rc=$RC)"
mk_gh "$T/json-bozuk-bin" 'bozuk{'
CIKTI="$( cd "$T/depo" && PATH="$T/json-bozuk-bin:$PATH" bash "$IS" ac json-bozuk --kartsiz --dosyalar dosya.txt 2>&1 )"; RC=$?
[ "$RC" -eq 2 ] && grep -q "PR #9 tek yüzey (merge-base ölçülemedi: dal adı okunamadı" <<<"$CIKTI" && [ ! -d "$T/alan/depo-json-bozuk" ]
g $? "(ii) pr view bozuk JSON → 'dal adı okunamadı' TEK YÜZEY uyarısı + GitHub listesinden hüküm rc=2 (rc=$RC)"
mk_gh "$T/bos-fark-bin" '{"number":9,"headRefName":"main","baseRefName":"main"}'
CIKTI="$( cd "$T/depo" && PATH="$T/bos-fark-bin:$PATH" bash "$IS" ac bos-fark --kartsiz --dosyalar dosya.txt,pr-kendi.txt 2>&1 )"; RC=$?
[ "$RC" -eq 0 ] && ! grep -q "tek yüzey" <<<"$CIKTI" && grep -q "çakışması yok (1 PR bakıldı)" <<<"$CIKTI" && [ -d "$T/alan/depo-bos-fark" ]
g $? "(iii) merge-base farkı BOŞ (dal=ana, ölçüldü) → GitHub listesi ne derse desin çakışma YOK, tek-yüzey uyarısı YOK, alan açıldı (rc=$RC)"
( cd "$T/depo" && bash "$IS" kapat bos-fark ) >/dev/null 2>&1 || true
# K2 — pozitif kontrol (yeşil kalmalı): PR'ın KENDİ dosyası (pr-kendi.txt, merge-base farkında da var) → gerçek çakışma rc=2, alan AÇILMAZ
CIKTI="$( cd "$T/depo" && PATH="$BAYAT:$PATH" bash "$IS" ac gercek-cakisma --kartsiz --dosyalar pr-kendi.txt 2>&1 )"; RC=$?
[ "$RC" -eq 2 ] && grep -q "PR #9" <<<"$CIKTI" && [ ! -d "$T/alan/depo-gercek-cakisma" ]; g $? "pozitif kontrol: PR'ın kendi dosyası pr-kendi.txt → GERÇEK çakışma rc=2, PR #9 adıyla, alan AÇILMADI (rc=$RC)"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""

echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
