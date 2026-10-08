#!/usr/bin/env bash
# soluklan.test.sh — hermetik: sahte çıpa aracı + sahte çıpa dosyası; gerçek çıpaya DOKUNMAZ.
# Ağırlık merkezi: FAIL-CLOSED. Çıpa yok/bayat/boş ise öneri ÜRETİLMEMELİ; doluluk
# verilmemişse "ölçemedim" denmeli, yeşil değil.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/soluklan.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"
BUGUN=2026-10-07; ESKI=2026-10-05

# sahte çıpa aracı: yalnız `yol` verbini bilir (gerçeğinin bu işe bakan yüzü o)
mk_arac() { printf '#!/usr/bin/env bash\n[ "${1:-}" = yol ] && printf "%%s" %q\n' "$1" > "$T/cipa.sh"; chmod +x "$T/cipa.sh"; }
kos() { SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" "$@" 2>&1; }

taze_cipa() { cat > "$T/cipa.md" <<EOF
# ⚓ GÜNÜN PLANI ÇIPASI · $BUGUN
## Maddeler
- [~] 1) yarım iş
- [ ] 2) açılmamış iş
- [x] 3) biten iş

_yazıldı: $(date -d '-300 min' +%FT%T)_
_dokunuldu: $(date +%FT%T)
EOF
touch "$T/cipa.md"
}
# aynı GÜN ama ESKİ: damga da dosya da geriye çekilir (iki yüzey birden)
yasli_cipa() { local dk="${1:-500}"
  cat > "$T/cipa.md" <<EOF
# ⚓ GÜNÜN PLANI ÇIPASI · $BUGUN
## Maddeler
- [~] 1) sabah yazılmış, akşam bayatlamış iş

_yazıldı: $(date -d "-$dk min" +%FT%T)_
_dokunuldu: $(date -d "-$dk min" +%FT%T)
EOF
  touch -d "-$dk min" "$T/cipa.md"
}
# Dünün çıpası ama damgası TAZE: böylece bayatlığı yakalayan TEK şey başlık tarihidir.
# (Damgasız yazsaydım ikinci bir kapı da tutardı ve S12a mutasyonu hiçbir şey ölçmezdi —
#  savunma derinliği iyidir ama mutasyon sınavını kör eder.)
bayat_cipa() { cat > "$T/cipa.md" <<EOF
# ⚓ GÜNÜN PLANI ÇIPASI · $ESKI
## Maddeler
- [~] 1) dünün yarım işi

_dokunuldu: $(date +%FT%T)
EOF
}
# İLERİ TARİHLİ damga: bugünün çıpası ama damga geleceği gösteriyor (bozuk damga ya da
# kaymış saat). Dosya zamanı da ileri alınır, yoksa "EN ESKİ kazanır" kuralı negatifi yutar
# ve sınav aslında mtime'ı ölçer — ölçtüğünü sandığın şeyi ölçmeyen kapı sınıfı.
gelecek_cipa() { local dk="${1:-120}"
  cat > "$T/cipa.md" <<EOF
# ⚓ GÜNÜN PLANI ÇIPASI · $BUGUN
## Maddeler
- [ ] 1) henüz yazılmamış olması gereken iş

_yazıldı: $(date -d "+$dk min" +%FT%T)_
_dokunuldu: $(date -d "+$dk min" +%FT%T)
EOF
  touch -d "+$dk min" "$T/cipa.md"
}
bos_cipa() { printf '# ⚓ GÜNÜN PLANI ÇIPASI · %s\n\n## Maddeler\n\n_madde yok_\n' "$BUGUN" > "$T/cipa.md"; }

mk_arac "$T/cipa.md"

echo "════ S1 · ÇIPA YOK → öneri ÜRETİLMEZ (fail-closed) ════"
rm -f "$T/cipa.md"
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S1a rc=3 (çıpa yok)"
grep -q 'ÇIPA YOK' <<<"$O"; g $? "S1b sebebi söylüyor"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S1c 🔴 öneri METNİ BASILMADI — doluluk 90 olsa bile"

echo "════ S2 · ÇIPA BAYAT → yok sayılır (var olan aracın kapatmadığı açık) ════"
bayat_cipa
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S2a rc=3 (bayat)"
grep -q "ÇIPA BAYAT ($ESKI)" <<<"$O"; g $? "S2b hangi tarihe ait olduğunu söylüyor"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S2c dünün çıpasıyla compact ÖNERİLMİYOR"

echo "════ S3 · ÇIPA BOŞ → dosya var ama hiçbir şey korumuyor ════"
bos_cipa
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S3a rc=3 (boş)"
grep -q 'hiçbir şey korumuyor' <<<"$O"; g $? "S3b boş dosyanın koruma OLMADIĞI yazılı"

echo "════ S4 · DOLULUK VERİLMEDİ → ölçemedim (4), yeşil DEĞİL ════"
taze_cipa
O="$(kos oneri)"; RC=$?
[ "$RC" -eq 4 ]; g $? "S4a rc=4 (ölçemedim)"
grep -q 'ÖLÇEMEDİM' <<<"$O"; g $? "S4b dürüst sınırı söylüyor"
grep -q 'ajanın kendi göstergesinden' <<<"$O"; g $? "S4c doluluğun NEREDEN geldiğini söylüyor"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S4d 🔴 sayı yokken öneri UYDURULMUYOR"

echo "════ S5 · EŞİK ALTI → compact önerilmez (rc=1) ════"
O="$(kos oneri --doluluk 59)"; RC=$?
[ "$RC" -eq 1 ]; g $? "S5a rc=1 (59 < 60)"
grep -q 'Eşik aşılmadı' <<<"$O"; g $? "S5b sebebi yazılı"
# 🔴 Sultan'ın sözü "60'IN ÜSTÜ" — tam eşik TETİKLEMEZ (göz tur-1 bulgusu).
O="$(kos oneri --doluluk 60)"; RC=$?
[ "$RC" -eq 1 ]; g $? "S5c tam eşikte (60) ÖNERİLMEZ — 'üstü' demek sınır dahil DEĞİL"
O="$(kos oneri --doluluk 61)"; RC=$?
[ "$RC" -eq 0 ]; g $? "S5d eşiğin BİR ÜSTÜ (61) önerilir"
grep -q 'Compact yapalım mı' <<<"$O"; g $? "S5e öneri metni basıldı"

echo "════ S6 · EŞİK taşınabilir (Sultan 60 dedi ama kural çivili değil) ════"
O="$(kos oneri --doluluk 70 --esik 80)"; RC=$?
[ "$RC" -eq 1 ]; g $? "S6a --esik 80 ile 70 eşik ALTI"
RC=0; O="$(SOLUKLAN_ESIK=40 SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 45 2>&1)" || RC=$?
[ "$RC" -eq 0 ]; g $? "S6b ortamdan eşik 40 ile 45 ÖNERİLİR"

echo "════ S6c · BOZUK EŞİK sessizce 0 sayılmaz (göz tur-1: fail-open riski) ════"
RC=0; O="$(SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 90 --esik seksen 2>&1)" || RC=$?
[ "$RC" -eq 2 ]; g $? "S6c harfli --esik rc=2"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S6d bozuk eşikte öneri ÜRETİLMİYOR (fail-closed)"
RC=0; O="$(SOLUKLAN_ESIK=abc SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 90 2>&1)" || RC=$?
[ "$RC" -eq 2 ]; g $? "S6e ortamdan gelen bozuk eşik de rc=2"
RC=0; O="$(SOLUKLAN_AZAMI_YAS_DK=cok SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 90 2>&1)" || RC=$?
[ "$RC" -eq 2 ]; g $? "S6f bozuk azami-yaş da rc=2"

echo "════ S6g · AYNI GÜN BAYATLAMA: takvim günü tazelik DEĞİLDİR (göz tur-1) ════"
yasli_cipa 500
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S6g1 bugünün ama 500 dk dokunulmamış çıpa → rc=3"
grep -q 'ÇIPA YAŞLI' <<<"$O"; g $? "S6g2 sebebi 'yaşlı' diye söyleniyor (bayat/boş ile karışmıyor)"
grep -q 'Takvim günü tazelik değildir' <<<"$O"; g $? "S6g3 kuralın niçini yazılı"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S6g4 yaşlı çıpayla öneri ÜRETİLMİYOR"
RC=0; O="$(SOLUKLAN_AZAMI_YAS_DK=600 SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 90 2>&1)" || RC=$?
[ "$RC" -eq 0 ]; g $? "S6g5 azami yaş 600'e çıkınca AYNI çıpa taze sayılır (eşik gerçekten okunuyor)"
taze_cipa

echo "════ S13 · BOŞ DOKUNUŞ tazelik SAYILMAZ (göz tur-2: fail-open idi) ════"
# Eski içerik + yeni dosya zamanı: ilk yazımda "taze olan kazanır" diyordum ve BU GEÇİYORDU.
yasli_cipa 500; touch "$T/cipa.md"          # dosya ŞİMDİ dokunulmuş gibi
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S13a boş dokunuş yaşı sıfırlamıyor → rc=3"
grep -q 'ÇIPA YAŞLI' <<<"$O"; g $? "S13b hâlâ yaşlı diyor (EN ESKİ yüzey kazanıyor)"
# Gerçek tazeleme (dokunma damgası YENİ) ise geçmeli — yoksa kapı her şeyi reddeder
taze_cipa
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 0 ]; g $? "S13c GERÇEK tazelemede (yeni dokunma damgası) geçiyor — kapı kör değil"

echo "════ S14 · DAMGASIZ çıpa 'taze' sayılmaz, ölçemedim denir ════"
printf '# ⚓ GÜNÜN PLANI ÇIPASI · %s\n\n## Maddeler\n- [~] 1) damgasiz plan\n' "$BUGUN" > "$T/cipa.md"
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S14a damgasız çıpa rc=3"
grep -q 'ÇIPA DAMGASIZ' <<<"$O"; g $? "S14b sebebi ayrı sınıf olarak söyleniyor"
grep -q 'TAHMİN, ölçüm değil' <<<"$O"; g $? "S14c dosya zamanının ölçüm olmadığı yazılı"

echo "════ S15 · TARİH BAŞLIKTAN okunur, gövdeden ARANMAZ (göz tur-2) ════"
# Dünün çıpası ama gövdesinde bugünün tarihi geçiyor — eski kapı bunu TAZE sayıyordu.
cat > "$T/cipa.md" <<EOF
# ⚓ GÜNÜN PLANI ÇIPASI · $ESKI
## Maddeler
- [~] 1) teslim $BUGUN tarihinde yapılacak

_dokunuldu: $(date +%FT%T)
EOF
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S15a gövdede bugünün tarihi geçse de BAYAT (rc=3)"
grep -q "ÇIPA BAYAT ($ESKI)" <<<"$O"; g $? "S15b başlıktaki GERÇEK tarih bildiriliyor"
# başlıksız çıpa da taze sayılmaz
printf '## Maddeler\n- [~] 1) başlıksız\n\n_dokunuldu: %s\n' "$(date +%FT%T)" > "$T/cipa.md"
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S15c başlıksız çıpa da geçmiyor"
taze_cipa

echo "════ S7 · AÇIK MADDE SAYIMI doğru (biten madde sayılmaz) ════"
O="$(kos oneri --doluluk 90)"
grep -q '2 açık madde' <<<"$O"; g $? "S7 yarım+açılmamış=2 sayılıyor, biten sayılmıyor"

echo "════ S8 · SONRASI · çıpayı geri okur + üç adımı dayatır ════"
O="$(kos sonrasi)"; RC=$?
[ "$RC" -eq 0 ]; g $? "S8a rc=0"
grep -q 'yarım iş' <<<"$O"; g $? "S8b çıpanın İÇERİĞİ basıldı (özet değil, aslı)"
grep -q 'ORTAM DAMGASI' <<<"$O"; g $? "S8c ortam damgası adımı var (compact harness'ı sıfırlar)"
grep -q 'bir İDDİADIR, ölçüm değil' <<<"$O"; g $? "S8d 'açık' damgasının iddia olduğu yazılı"

echo "════ S9 · SONRASI · çıpa yoksa UYDURMA PLAN YAZMA der ════"
rm -f "$T/cipa.md"
O="$(kos sonrasi)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S9a rc=3"
grep -q 'Uydurma plan yazma' <<<"$O"; g $? "S9b kayıp planı uydurmak YASAKLANIYOR"

echo "════ S10 · ÇIPA ARACI YOKSA → ölçemedim, 'çıpa yok' DEĞİL ════"
O="$(SOLUKLAN_CIPA_ARAC=/yok/cipa.sh SOLUKLAN_BUGUN="$BUGUN" bash "$S" oneri --doluluk 90 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S10a aracsızken de öneri ÜRETİLMİYOR (fail-closed)"
grep -q 'Compact yapalım mı' <<<"$O"; [ $? -ne 0 ]; g $? "S10b öneri metni yok"

echo "════ S11 · bozuk doluluk reddedilir (sessiz 0 sayılmaz) ════"
taze_cipa
O="$(kos oneri --doluluk altmis)"; RC=$?
[ "$RC" -eq 2 ]; g $? "S11a harf verilince rc=2"
O="$(kos oneri --doluluk)"; RC=$?
[ "$RC" -eq 2 ]; g $? "S11b değersiz bayrak rc=2 (sessiz yutulmuyor)"

echo "════ S13 · İLERİ TARİHLİ DAMGA → taze SAYILMAZ (fail-closed) ════"
gelecek_cipa 120
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S13a ileri tarihli damgada öneri ÜRETİLMEZ (rc=3)"
printf '%s' "$O" | grep -q "GELECEĞİ GÖSTERİYOR"; g $? "S13b sebebi söylüyor: damga geleceği gösteriyor"
printf '%s' "$O" | grep -qi "ölçemedim"; g $? "S13c 'taze' demiyor, 'ölçemedim' diyor"
O="$(kos hazir-mi --doluluk 90)"; RC=$?
[ "$RC" -eq 3 ]; g $? "S13d hazır-mı da ileri damgada 3 dönüyor"
O="$(kos sonrasi)"; RC=$?
printf '%s' "$O" | grep -q "geleceği gösteriyor"; g $? "S13e sonrası planı okurken uyarı basıyor"
# POZİTİF KONTROL: aynı fikstür damgası geri alınınca YEŞİL olmalı — yoksa S13 her şeyi reddeden
# bir kapıdır ve hiçbir şey ölçmez.
taze_cipa
O="$(kos oneri --doluluk 90)"; RC=$?
[ "$RC" -eq 0 ]; g $? "S13f POZİTİF KONTROL: damga geri alınınca aynı yol YEŞİL (kapı ayırt ediyor)"

echo "════ S12 · MUTASYON: tazelik kapısı kaldırılınca sınav KIRMIZI olmalı ════"
M="$T/mutant.sh"
sed 's@^  if \[ "\$baslik_tarih" != "\$BUGUN" \]; then@  if false; then@' "$S" > "$M"
if cmp -s "$M" "$S"; then g 1 "S12a mutant orijinalden FARKSIZ — ölçtüğü şey yok (çapa bayat)"; else
  bayat_cipa
  SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$M" oneri --doluluk 90 >/dev/null 2>&1
  [ $? -eq 0 ]; g $? "S12a MUTASYON: tarih kapısı ölünce DÜNÜN çıpası öneri üretiyor (kapı gerçek)"
fi
# EN ESKİ yüzey kuralı da mutasyonla ölçülür — "taze olan kazanır"a geri dönülürse yakalanmalı
M3="$T/mutant3.sh"
sed 's@^  \[ "\$mtime_yas" -gt "\$yas_dk" \] && yas_dk="\$mtime_yas".*@  [ "$mtime_yas" -lt "$yas_dk" ] \&\& yas_dk="$mtime_yas"@' "$S" > "$M3"
if cmp -s "$M3" "$S"; then g 1 "S12c mutant3 FARKSIZ (çapa bayat)"; else
  yasli_cipa 500; touch "$T/cipa.md"
  SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$M3" oneri --doluluk 90 >/dev/null 2>&1
  [ $? -eq 0 ]; g $? "S12c MUTASYON: 'taze olan kazanır'a dönülünce boş dokunuş kapıyı yine geçiyor"
  taze_cipa
fi
M2="$T/mutant2.sh"
sed 's@^    if \[ -z "\$DOLULUK" \]; then@    if false; then@' "$S" > "$M2"
if cmp -s "$M2" "$S"; then g 1 "S12b mutant2 FARKSIZ"; else
  taze_cipa
  SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$M2" oneri >/dev/null 2>&1
  [ $? -ne 4 ]; g $? "S12b MUTASYON: 'ölçemedim' kapısı ölünce doluluksuz çağrı 4 dönmüyor"
fi

# İleri tarihli damga kapısı mutasyonla ölçülür: negatif yaş denetimi ölünce ileri
# tarihli çıpa yine "taze" basmalı (yani kapı gerçekten o satırda yaşıyor).
M4="$T/mutant4.sh"
sed 's@^  if \[ "\$yas_dk" -lt 0 \] || \[ "\$mtime_yas" -lt 0 \]; then@  if false; then@' "$S" > "$M4"
if cmp -s "$M4" "$S"; then g 1 "S13g mutant4 FARKSIZ — negatif-yaş kapısı sınavda ölçülmüyor"; else
  gelecek_cipa 120
  SOLUKLAN_CIPA_ARAC="$T/cipa.sh" SOLUKLAN_BUGUN="$BUGUN" bash "$M4" oneri --doluluk 90 >/dev/null 2>&1
  [ $? -eq 0 ]; g $? "S13g MUTASYON: negatif-yaş kapısı ölünce ileri tarihli çıpa öneri üretiyor"
  taze_cipa
fi

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
