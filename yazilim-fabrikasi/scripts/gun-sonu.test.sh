#!/usr/bin/env bash
# gun-sonu.test.sh — hermetik: sahte depo + sahte defterler; GERÇEK deftere dokunmaz.
# Ağırlık merkezi: SAAT KAYMASI. Defterler dünya saatiyle damgalanır, süzgeç yerel günle
# çalışır; aradaki fark her gün 3 saatlik KÖR PENCERE açıyordu (ölçülmüş canlı vaka:
# 7 Ekim yerel 00:55 ve 01:11'deki iki kapı kaçışı 7 Ekim özetinde HİÇ görünmedi).
set -uo pipefail

# 🔴 SAAT DİLİMİ ÇİVİLENİR — ve bunu bir kez CI'da düşerek öğrendim.
#   Bu sınav SAAT KAYMASINI ölçüyor; kayma ancak yerel saat ile dünya saati FARKLIYSA
#   vardır. CI dünya saatinde koşuyor; orada ikisi aynı olduğu için senaryo hiç kurulmuyor
#   ve sınav kendi fikstürünü kuramadığı için kırmızı yanıyordu. Yani sonuç ORTAMA bağlıydı
#   — oysa sonucu ortama bağlı olan bir şey ölçüm değildir, bu filoda ölçülmüş bir derstir.
#   Çözüm: dilimi SINAV seçer, ortamdan devralmaz. (Onarımın kendisi dilimden bağımsızdır;
#   çivilenen yalnız fikstürün koşullarıdır.)
export TZ="${GUN_SONU_SINAV_TZ:-Europe/Istanbul}"
_ofs="$(date +%z)"
if [ "$_ofs" = "+0000" ]; then
  echo "ATLANDI: seçilen dilim ($TZ) dünya saatiyle aynı ofsette — kayma senaryosu kurulamaz."
  echo "  (Bu bir YEŞİL DEĞİLDİR: ölçüm yapılmadı. Dilim verisi kurulu mu bakın.)"
  exit 3
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="${MUTANT:-$HERE/gun-sonu.sh}"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; GUN="$(date +%F)"
mkdir -p "$T/_agents/fabrika/kartlar"
( cd "$T" && git init -q -b olcum . ) >/dev/null 2>&1
cat > "$T/_agents/fabrika/kartlar/sinav.json" <<KART
{"is":"sinav","cumle":"sınav kartı","istedi":"sinav","aldi":"sinav",
 "zaman":"${GUN}T10:00:00+03:00","sinif_cevaplari":{},"siniflar":[],"sultan":false,
 "durum":"bitti","bitis":"${GUN}T11:00:00+03:00","gecmis":[],"pr":"","puan":null,"kanit_var":false}
KART

# YEREL bir saati DÜNYA damgasına çevirir — dilim ortamdan gelir, ÇİVİLENMEZ.
dunya() { python3 -c "
import datetime,sys
print(datetime.datetime.fromisoformat(sys.argv[1]+'T'+sys.argv[2]).astimezone()
      .astimezone(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$GUN" "$1"; }
ozet() { ( cd "$T" && bash "$G" --gun "$GUN" 2>&1 ); }
say() { printf '%s' "$1" | sed -n "s/^## $2 (\([0-9]*\)).*/\1/p" | head -1; }

GECE="$(dunya 01:11:00)"; GUNDUZ="$(dunya 14:30:00)"
echo "════ Ö0 · senaryo kurulabiliyor mu (tautoloji panzehiri) ════"
[ "${GECE:0:10}" != "$GUN" ]; g $? "Ö0 yerel gece saati FARKLI dünya-gününe düşüyor — dilim çivili, her ortamda aynı"

echo "════ Ö1 · YEREL GECE olayı o günün özetinde GÖRÜNÜR ════"
printf '%s | KAPISIZ | gece-kacisi | komut-A\n' "$GECE"   > "$T/_agents/fabrika/kacis-defteri.log"
printf '%s | TAVAN-ACILDI | is=x tur=4 | gece-tavani\n' "$GECE" > "$T/_agents/fabrika/tavan-defteri.log"
O="$(ozet)"
[ "$(say "$O" 'Kapı kaçışları')" = 1 ]; g $? "Ö1a gece kaçışı sayılıyor"
[ "$(say "$O" 'Tavan açılışları')" = 1 ]; g $? "Ö1b gece tavan açılışı sayılıyor"
grep -q 'gece-kacisi' <<<"$O"; g $? "Ö1c gerekçesi basılıyor"
# A268 (8 Eki): reis açılışı Sultan açılışından AYIRT EDİLEREK görünür; ikisi de sayılır
printf '%s | TAVAN-ACILDI-REIS | is=y tur=4 | reis-gerekcesi-uzun\n' "$GECE" >> "$T/_agents/fabrika/tavan-defteri.log"
O="$(ozet)"
[ "$(say "$O" 'Tavan açılışları')" = 2 ]; g $? "Ö1d reis açılışı da sayılıyor (2)"
grep -qE 'is=y tur=4 · reis kararı \(sınıfsız iş\) · gerekçe: reis-gerekcesi-uzun' <<<"$O"; g $? "Ö1e reis açılışı 'reis kararı (sınıfsız iş)' etiketiyle basılıyor"
grep -qE 'is=x tur=4 · Sultan kararı · gerekçe: gece-tavani' <<<"$O"; g $? "Ö1f Sultan açılışı 'Sultan kararı' etiketiyle basılıyor (karışmıyor)"
printf '%s | TAVAN-ACILDI | is=x tur=4 | gece-tavani\n' "$GECE" > "$T/_agents/fabrika/tavan-defteri.log"; O="$(ozet)"

echo "════ Ö2 · basılan SAAT yerel olmalı (Sultan 01:11'i 22:11 okumamalı) ════"
grep -qE '^- 01:11 · gerekçe' <<<"$O"; g $? "Ö2 saat YEREL basılıyor (01:11) — kaçış satırı (biçimi: saat · gerekçe · komut)"
# tavan satırının biçimi farklıdır (saat · iş/tur · kim · gerekçe) — denetim tur 3: iki satır türü ayrı ayrı sınanır
grep -qE '^- 01:11 · is=x tur=4 · Sultan kararı · gerekçe: gece-tavani' <<<"$O"; g $? "Ö2b tavan satırı da yerel saatle ve karar etiketiyle basılıyor"

echo "════ Ö3 · GÜNDÜZ olayı da görünür (onarım geceyi alıp gündüzü düşürmedi) ════"
printf '%s | KAPISIZ | gunduz-kacisi | komut-B\n' "$GUNDUZ" > "$T/_agents/fabrika/kacis-defteri.log"
O3="$(ozet)"
[ "$(say "$O3" 'Kapı kaçışları')" = 1 ]; g $? "Ö3a gündüz kaçışı sayılıyor"
grep -qE '^- 14:30 · gerekçe' <<<"$O3"; g $? "Ö3b gündüz saati de yerel"

echo "════ Ö4 · BAŞKA GÜNÜN olayı SAYILMAZ (süzgeç hâlâ süzüyor) ════"
DUN="$(date -d "$GUN -1 day" +%F)"
printf '%sT12:00:00Z | KAPISIZ | dunun-kacisi | komut-C\n' "$DUN" > "$T/_agents/fabrika/kacis-defteri.log"
O4="$(ozet)"
[ "$(say "$O4" 'Kapı kaçışları')" = 0 ]; g $? "Ö4a dünün kaçışı bugüne KARIŞMIYOR"
grep -q 'bugün kapı atlanmadı' <<<"$O4"; g $? "Ö4b boş hâli açıkça söyleniyor"

echo "════ Ö5 · ÇÖZÜLEMEYEN damga sessizce DÜŞMEZ (unknown ≠ yok) ════"
printf 'tarihsiz bir satir | KAPISIZ | bozuk | komut-D\n' > "$T/_agents/fabrika/kacis-defteri.log"
O5="$(ozet)"
[ "$(say "$O5" 'Kapı kaçışları')" = 0 ]; g $? "Ö5a bugünkü sayıya girmiyor"
grep -q 'ÇÖZÜLEMEDİ' <<<"$O5"; g $? "Ö5b çözülemediği SÖYLENİYOR (sessiz atlama yok)"
grep -q '1 satırın tarihi' <<<"$O5"; g $? "Ö5c kaç satır olduğu yazılı"

echo "════ Ö6 · DİLİMLİ (yerel) damga da doğru okunur — eski/karışık defter ════"
printf '%sT01:11:00+03:00 | KAPISIZ | dilimli | komut-E\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O6="$(ozet)"
[ "$(say "$O6" 'Kapı kaçışları')" = 1 ]; g $? "Ö6 açık dilimli damga da bugüne sayılıyor"

echo "════ Ö9 · YABANCI DİLİM: saat de çevrilmeli, gün de (göz tur-1) ════"
# 🔴 Fikstür BİLEREK kendi dilimimizden DEĞİL: +03:00 kullanmak açığı örter, çünkü
#    çevrilmemiş saat yerel saatle aynı çıkar. Çevrim gerçekten koşuyor mu, ancak
#    yabancı bir dilimle görünür. +00:00 = yerelde 03:00 (biz +03'teyiz).
printf '%sT00:00:00+00:00 | KAPISIZ | yabanci-dilim | komut-F\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O9="$(ozet)"
BEK="$(python3 -c "
import datetime,sys
t=datetime.datetime.fromisoformat(sys.argv[1]+'T00:00:00+00:00').astimezone()
print(t.strftime('%Y-%m-%d'), t.strftime('%H:%M'))" "$GUN")"
BEK_GUN="${BEK%% *}"; BEK_SAAT="${BEK##* }"
if [ "$BEK_GUN" = "$GUN" ]; then
  [ "$(say "$O9" 'Kapı kaçışları')" = 1 ]; g $? "Ö9a yabancı dilimli damga doğru güne sayılıyor"
  grep -qE "^- $BEK_SAAT · gerekçe" <<<"$O9"; g $? "Ö9b saat YEREL'e çevrilmiş basılıyor ($BEK_SAAT, ham 00:00 değil)"
  grep -qE '^- 00:00 · gerekçe' <<<"$O9"; [ $? -ne 0 ]; g $? "Ö9c ham dilim saati BASILMIYOR"
else
  g 0 "Ö9 ATLANDI: bu dilimde yabancı damga başka güne düşüyor (fikstür kurulamadı)"
fi

echo "════ Ö10 · BOZUK DİLİM özeti ÇÖKERTMEZ (göz tur-1: try kapsamı dardı) ════"
printf '%sT01:11:00+99:00 | KAPISIZ | bozuk-dilim | komut-G\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O10="$(ozet)"; RC10=$?
[ "$RC10" -eq 0 ]; g $? "Ö10a özet yine üretiliyor (çökmüyor)"
grep -q 'ÇÖZÜLEMEDİ' <<<"$O10"; g $? "Ö10b bozuk satır ÇÖZÜLEMEDİ diye sayılıyor"
[ "$(say "$O10" 'Kapı kaçışları')" = 0 ]; g $? "Ö10c bugüne sayılmıyor"
grep -q 'Açık işler' <<<"$O10"; g $? "Ö10d özetin SONRAKİ bölümleri de üretildi (akış kesilmedi)"

echo "════ Ö7 · MUTASYON: saat çevrimi koparılınca kör pencere GERİ GELİR ════"
M="$T/mutant.sh"
sed 's@^        return t.astimezone().strftime("%Y-%m-%d")@        return tarih@' "$G" > "$M"
if cmp -s "$M" "$G"; then g 1 "Ö7 mutant orijinalden FARKSIZ — ölçtüğü şey yok"; else
  printf '%s | KAPISIZ | gece-kacisi | komut-A\n' "$GECE" > "$T/_agents/fabrika/kacis-defteri.log"
  OM="$( cd "$T" && bash "$M" --gun "$GUN" 2>&1 )"
  [ "$(say "$OM" 'Kapı kaçışları')" = 0 ]; g $? "Ö7 MUTASYON: çevrim ölünce gece olayı yine KAYBOLUYOR (onarım gerçek)"
fi

echo "════ Ö8 · MUTASYON: 'çözülemedi' uyarısı kaldırılınca Ö5 kırmızıya döner ════"
M2="$T/mutant2.sh"
sed 's@^            cozulemedi.append(l)@            pass@' "$G" > "$M2"
if cmp -s "$M2" "$G"; then g 1 "Ö8 mutant2 FARKSIZ"; else
  printf 'tarihsiz bir satir | KAPISIZ | bozuk | komut-D\n' > "$T/_agents/fabrika/kacis-defteri.log"
  OM2="$( cd "$T" && bash "$M2" --gun "$GUN" 2>&1 )"
  grep -q 'ÇÖZÜLEMEDİ' <<<"$OM2"; [ $? -ne 0 ]; g $? "Ö8 MUTASYON: uyarı kaldırılınca bozuk satır SESSİZCE düşüyor"
fi

echo "════ Ö11 · MUTASYON: açık-dilim çevrimi koparılınca Ö9 kırmızıya döner ════"
M3="$T/mutant3.sh"
sed 's@^        if dilim:$@        if False:@' "$G" > "$M3"
if cmp -s "$M3" "$G"; then g 1 "Ö11 mutant3 FARKSIZ (çapa bayat)"; else
  printf '%sT00:00:00+00:00 | KAPISIZ | yabanci-dilim | komut-F\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
  OM3="$( cd "$T" && bash "$M3" --gun "$GUN" 2>&1 )"
  grep -qE '^- 00:00 · gerekçe' <<<"$OM3"; g $? "Ö11 MUTASYON: çevrim ölünce HAM dilim saati basılıyor"
fi

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
