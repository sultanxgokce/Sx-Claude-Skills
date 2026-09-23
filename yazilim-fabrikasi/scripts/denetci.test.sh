#!/usr/bin/env bash
# denetci.test.sh — bağımsız göz betiğini SAHTE denetçiyle (DENETCI_KOMUT) sahte depoda koşturur.
# Ölçtüğü: kanıt kapısı · yazan≠denetleyen · puan/karar · tavan 3(+1)/4 · geçersiz çıktı=ölçemedi · istem içeriği.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
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

echo "════ T7b · 🚪 SULTAN KAPISI: 'devam' kararı tavanı aşar, gerekçesiz aşmaz ════"
# NİÇİN (23 Eyl canlı vaka): tıkandı raporu "karar sınıf işiyse Sultan'ın" diyordu ama araçta
# o kararı kabul edecek kapı YOKTU. Kapı onarımında puanlar 3·3·2 gitti; düşüşün sebebi işin
# kötüleşmesi değil, denetçinin her turda DAHA CİDDİ kusur bulmasıydı — "ilerliyor_mu" bu ikisini
# ayırt edemez. Kural insana havale ediyor, araç insanı dinlemiyordu.
bash "$K" olcum is-s olc --asama tek -- echo 1 >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 3 H "$B,$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-s --diff "$T/d.patch" >/dev/null 2>&1; [ $? -eq 4 ]; g $? "puan düşünce tur3 tıkandı (rc=4)"
# gerekçesiz / kısa gerekçeli kapı AÇILMAZ
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-s --diff "$T/d.patch" --sultan-devam "kisa" 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "kısa gerekçe REDDEDİLDİ (rc=1)"
grep -q "GEREKÇE ister" <<<"$CIKTI"; g $? "ne istendiği yazılı"
[ ! -f "$T/_agents/fabrika/kanit/is-s/DENETIM-4.json" ]; g $? "kısa gerekçeyle denetim KOŞULMADI"
# gerekçeli kapı açılır, denetim koşar, deftere yazılır
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-s --diff "$T/d.patch" --sultan-devam "Sultan devam dedi: acik bulgu kucuk ve anlasilir, birakmak kapinin amacini cürütür" 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "gerekçeli kapı → tur4 koştu ve GEÇTİ"
grep -q "TAVAN AÇILDI" <<<"$CIKTI"; g $? "tavanın açıldığını SÖYLÜYOR (sessiz değil)"
[ -s "$T/_agents/fabrika/tavan-defteri.log" ]; g $? "tavan defteri GERÇEKTEN yazıldı"
grep -q "Sultan devam dedi" "$T/_agents/fabrika/tavan-defteri.log"; g $? "gerekçe defterde duruyor"
grep -q "TAVAN-ACILDI" "$T/_agents/fabrika/tavan-defteri.log"; g $? "defter satırı etiketli"
# 🔴 MUTLAK tavanı AÇMAZ — dört tur hâlâ mutlaktır
bash "$K" olcum is-t olc --asama tek -- echo 1 >/dev/null 2>&1
for i in 1 2 3; do SAHTE_JSON="$(J 2 H "$B,$B")" bash "$D" is-t --diff "$T/d.patch" >/dev/null 2>&1; done
SAHTE_JSON="$(J 2 H "$B")" bash "$D" is-t --diff "$T/d.patch" --sultan-devam "dorduncu tur icin Sultan karari alindi ve kayda gecti" >/dev/null 2>&1
CIKTI="$(SAHTE_JSON="$(J 5 E "")" bash "$D" is-t --diff "$T/d.patch" --sultan-devam "besinci tur icin de devam denildi ama mutlak tavan acilmamali" 2>&1)"; RC=$?
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
mut() { # mut <ad> <sed>
  local M="$HERE/.mutant-$1.sh"; sed "$2" "$HERE/denetci.sh" > "$M"; chmod +x "$M"
  IC_KOSUM=1 MUTANT_D="$M" bash "$0" >/dev/null 2>&1
  [ $? -ne 0 ]; g $? "mutant '$1' sınavı KIRMIZI yapıyor"
  rm -f "$M"
}
mut "gerekce-kontrolunu-kaldir" 's|^  if \[ "${#SULTAN_DEVAM}" -lt 20 \]; then|  if false; then|'
mut "deftere-yazmayi-kaldir" 's|^  printf .%s . TAVAN-ACILDI|  : printf "%s | TAVAN-ACILDI|'
mut "mutlak-tavani-kaldir" 's|^if \[ "$TUR" -gt "$MUTLAK" \]; then|if false; then|'

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
