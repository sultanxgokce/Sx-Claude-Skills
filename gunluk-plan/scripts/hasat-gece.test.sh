#!/usr/bin/env bash
# hasat-gece.test.sh — gecelik Hasat betiğinin hermetik sınavı (görev …QCJYWG · SERDAR 4 Kas). Sahte gorev.sh / hasat.sh / registry.
# MUTANT_B=<bozuk hasat-gece.sh yolu> ile koşunca kapılar o dosyayı sınar.
# kabuk-testleri: sure=120
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="${MUTANT_B:-$HERE/hasat-gece.sh}"
T="$(mktemp -d)"; trap 'find "$T" -delete 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

# sahte defter: 7 havuz kaydı + 1 havuz dışı
cat > "$T/liste.txt" <<'EOF'
gorev_AAA1  code  havuz  -  bug  -  Temiz kayıt, odası var  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_BBB2  code  havuz  -  bug  -  Başka temiz kayıt  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_CCC3  code  havuz  -  bug  -  Üçüncü temiz  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_DDD4  code  havuz  -  bug  -  Dördüncü temiz  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_FFF0  code  havuz  -  bug  -  Beşinci temiz kayıt  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_SSS5  code  havuz  -  bug  -  Eski yedekleri sil  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_KKK6  code  havuz  -  bug  -  Kapılı kayıt  (son: 2026-11-04T12:00)  oda: agentic-os  kapi: karar
gorev_OOO7  code  havuz  -  bug  -  Odasız kayıt  (son: 2026-11-04T12:00)
gorev_NNN8  code  havuz  -  bug  -  Doğrulaması bayat  (son: 2026-11-04T12:00)  oda: agentic-os
gorev_ZZZ9  code  acik  -  bug  -  Havuzda değil  (son: 2026-11-04T12:00)  oda: agentic-os
EOF
printf '#!/usr/bin/env bash\n[ "$1" = liste ] && cat "%s/liste.txt"\n' "$T" > "$T/gorev.sh"
# sahte hasat: durum → kayıt kimliğine göre; ac → çağrıyı kaydeder
cat > "$T/hasat.sh" <<EOF
#!/usr/bin/env bash
if [ "\$1" = durum ]; then
  case "\$2" in
    gorev_NNN8) echo "HASAT=OLMAZ"; exit 1 ;;
    gorev_ERR0) echo "HASAT=ÖLÇÜLEMEDİ"; exit 3 ;;
    *) echo "HASAT=OLUR"; exit 0 ;;
  esac
elif [ "\$1" = ac ]; then echo "\$*" >> "$T/ac.log"; sleep "\${AC_BEKLE:-0}"; [ -z "\${AC_FAIL:-}" ]; exit \$?; fi
EOF
chmod +x "$T/gorev.sh" "$T/hasat.sh"
cat > "$T/reg.yaml" <<'EOF'
  - id: SERDAR
    oda: agentic-os
    oda_muduru: evet
  - id: BENNÂ
    oda: agentic-os
EOF
printf '#!/usr/bin/env bash\ncase "$1" in gorev_AAA1) echo 1 ;; gorev_EEE0) exit 7 ;; *) echo 0 ;; esac\n' > "$T/dogan.sh"
ic()  { grep -q -- "$1" <<< "$C"; }                      # günlükte var mı (boru yok: çıkış kodu maskelenmez)
son() { local l; l="$(tail -1 <<< "$C")"; grep -q -- "$1" <<< "$l"; }   # son (özet) satırda var mı
koş() { GOREV_SH="$T/gorev.sh" HASAT_SH="$T/hasat.sh" ILE_REGISTRY="${REG:-$T/reg.yaml}" HASAT_GECE_GUN=2026-11-05 HASAT_GECE_DURUM="${DURUM:-$T/durum.$RANDOM}" HASAT_GECE_ZAMAN=Z HASAT_GECE_DOGAN_OKU="${DOGAN:-$T/dogan.sh}" bash "$B" "$@"; }

echo "── KURU kip (varsayılan)"
rm -f "$T/ac.log"; C="$(koş)"; RC=$?
[ "$RC" -eq 0 ]; g $? "K1 koştu rc=0"
[ ! -s "$T/ac.log" ]; g $? "K2 🔴 kuru kipte hasat.sh ac HİÇ çağrılmadı"
ic 'kip=kuru'; g $? "K3 varsayılan kip kuru"
son 'acilan=3'; g $? "K4 🔴 tavan 3: açılabilir temiz kayıtlardan en çok 3 'açardı'"
ic 'gorev_FFF0 tavan-doldu'; g $? "K5 dördüncüsü tavan-doldu diye günlükte"
ic 'gorev_SSS5 atlandi-sinifli'; g $? "K6 🔴 'sil' sözlü kayıt sınıflı: atlandı (günlükte)"
ic 'gorev_KKK6 atlandi-sinifli (kapi: karar)'; g $? "K7 🔴 kapı alanı dolu kayıt sınıflı: atlandı"
ic 'gorev_OOO7 atlandi-sahipsiz'; g $? "K8 🔴 atanan ve odası yok: sahipsiz → AÇILMADI, günlükte"
son 'olmaz=1'; g $? "K9 bayat doğrulama olmaz sayıldı"
ic 'gorev_BBB2 KURU: acardi → SERDAR'; g $? "K10 🔴 sahip = odanın müdürü (aile-registry oda_muduru)"
! ic 'gorev_ZZZ9'; g $? "K11 havuz dışı kayıt hiç işlenmedi"
ic 'gorev_AAA1 atlandi-dogmus'; g $? "K12 🔴 doğan görevi olan kayıt TEKRAR açılmaz (tekilleştirme: hasat.sh ac kendisi yapmıyor)"
son 'atlandi_dogmus=1'; g $? "K13 doğmuş kayıt özet satırında sayıldı"

echo "── GERÇEK kip (açık --gercek)"
rm -f "$T/ac.log"; C="$(koş --gercek)"; RC=$?
[ "$(wc -l < "$T/ac.log")" -eq 3 ]; g $? "G1 hasat.sh ac tam 3 kez çağrıldı (tavan)"
grep -q -- '--kip otomatik' "$T/ac.log"; g $? "G2 kip otomatik"
grep -q -- '--atanan SERDAR' "$T/ac.log"; g $? "G3 🔴 --atanan verildi (sahipsiz görev yok)"
! grep -qE 'SSS5|KKK6|OOO7|AAA1' "$T/ac.log"; g $? "G4 🔴 sınıflı/sahipsiz/doğmuş kayıt için ac ÇAĞRILMADI"

echo "── OLUR=0 ve bozuk girdi"
printf 'gorev_NNN8  code  havuz  -  bug  -  Doğrulaması bayat  (son: 2026-11-04T12:00)  oda: agentic-os\n' > "$T/liste.txt"
C="$(koş)"; son 'olur=0 acilan=0'; g $? "Z1 🔴 hiçbiri OLUR değil: günlüğe olur=0 yazıldı"
printf '' > "$T/liste.txt"; C="$(koş)"; RC=$?
[ "$RC" -eq 3 ] && ic 'olculemedi=defter'; g $? "Z2 🔴 defter boş/okunamadı: rc=3 ÖLÇÜLEMEDİ, olur=0 UYDURULMADI"
koş --tavan x >/dev/null 2>&1; [ "$?" -eq 2 ]; g $? "Z3 sayısız --tavan rc=2"
koş --bilinmeyen >/dev/null 2>&1; [ "$?" -eq 2 ]; g $? "Z4 bilinmeyen bayrak rc=2"
printf 'gorev_AAA1  code  havuz  -  bug  -  Temiz  (son: x)  oda: agentic-os\n' > "$T/liste.txt"; C="$(REG=/yok koş)"; ic 'atlandi-sahipsiz'; g $? "Z5 registry okunamıyor: sahipsiz → açılmadı (fail-closed)"

printf 'gorev_EEE0  code  havuz  -  bug  -  Doğan okunamayan  (son: x)  oda: agentic-os\n' > "$T/liste.txt"; rm -f "$T/ac.log"; C="$(koş --gercek)"
ic 'gorev_EEE0 olculemedi' && [ ! -s "$T/ac.log" ]; g $? "Z6 🔴 doğan görev okunamadı: AÇILMADI (fail-closed), ölçülemedi diye günlükte"

# günlük tavan KOŞULAR ARASI (göz tur 1 ciddi bulgu): aynı gün ikinci gerçek koşu ek 3 daha açmaz
printf 'gorev_P1  code  havuz  -  bug  -  Bir  (son: x)  oda: agentic-os\ngorev_P2  code  havuz  -  bug  -  İki  (son: x)  oda: agentic-os\ngorev_P3  code  havuz  -  bug  -  Üç  (son: x)  oda: agentic-os\ngorev_P4  code  havuz  -  bug  -  Dört  (son: x)  oda: agentic-os\ngorev_P5  code  havuz  -  bug  -  Beş  (son: x)  oda: agentic-os\ngorev_P6  code  havuz  -  bug  -  Altı  (son: x)  oda: agentic-os\ngorev_P7  code  havuz  -  bug  -  Yedi  (son: x)  oda: agentic-os\n' > "$T/liste.txt"
rm -f "$T/ac.log" "$T/durum7"; DURUM="$T/durum7" koş --gercek >/dev/null; DURUM="$T/durum7" koş --gercek >/dev/null
[ "$(wc -l < "$T/ac.log")" -eq 3 ]; g $? "Z7 🔴 aynı gün iki gerçek koşu: TOPLAM 3 açıldı (ikinci koşu ek açmadı)"
C="$(DURUM="$T/durum7" koş --kuru)"; son 'acilan=0'; g $? "Z8 kuru kip günün dolu tavanını görür: acilan=0, dosyaya yazmaz"
[ "$(wc -l < "$T/durum7")" -eq 3 ]; g $? "Z9 kuru kip durum dosyasına YAZMADI (3 satır kaldı)"
rm -f "$T/ac.log"; mkdir -p "$T/ro"; chmod 555 "$T/ro"; C="$(DURUM="$T/ro/x/durum" koş --gercek)"; RC=$?
[ "$RC" -eq 3 ] && [ ! -s "$T/ac.log" ]; g $? "Z10 🔴 durum dosyası yazılamıyor: gerçek kip rc=3 ve HİÇBİR ŞEY AÇMADI (fail-closed)"; chmod 755 "$T/ro"
rm -f "$T/ac.log" "$T/durum10b"; : > "$T/durum10b"; chmod 444 "$T/durum10b"; C="$(DURUM="$T/durum10b" koş --gercek)"; RC=$?
[ "$RC" -eq 3 ] && [ ! -s "$T/ac.log" ]; g $? "Z10b 🔴 dizin yazılabilir ama durum DOSYASI salt-okur: rc=3, HİÇBİR ŞEY AÇILMADI (kilit değil dosya koruması)"; chmod 644 "$T/durum10b"

# eşzamanlılık (göz tur 2 B1): iki gerçek koşu AYNI ANDA → toplam 3 (kilitsizde 6 olurdu)
rm -f "$T/ac.log" "$T/durum11"; ( DURUM="$T/durum11" AC_BEKLE=1 koş --gercek >/dev/null & DURUM="$T/durum11" AC_BEKLE=1 koş --gercek >/dev/null & wait )
[ "$(wc -l < "$T/ac.log")" -eq 3 ]; g $? "Z11 🔴 iki EŞZAMANLI gerçek koşu: TOPLAM 3 açıldı (kilit; kilitsizde 6)"
# başarısız açış da sayılır (rezerve-sonra-aç): ac hep düşerse bile ikinci koşu ek deneme yapmaz
rm -f "$T/ac.log" "$T/durum12"; AC_FAIL=1 DURUM="$T/durum12" koş --gercek >/dev/null; AC_FAIL=1 DURUM="$T/durum12" koş --gercek >/dev/null
[ "$(wc -l < "$T/durum12")" -eq 3 ] && [ "$(wc -l < "$T/ac.log")" -eq 3 ]; g $? "Z12 🔴 açış 3 kez başarısız: rezerve satırları kaldı (3), ikinci koşu yeniden denemedi"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
