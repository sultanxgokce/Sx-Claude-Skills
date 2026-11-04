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
elif [ "\$1" = ac ]; then echo "\$*" >> "$T/ac.log"; exit 0; fi
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
koş() { GOREV_SH="$T/gorev.sh" HASAT_SH="$T/hasat.sh" ILE_REGISTRY="${REG:-$T/reg.yaml}" HASAT_GECE_ZAMAN=Z HASAT_GECE_DOGAN_OKU="${DOGAN:-$T/dogan.sh}" bash "$B" "$@"; }

echo "── KURU kip (varsayılan)"
rm -f "$T/ac.log"; C="$(koş)"; RC=$?
[ "$RC" -eq 0 ]; g $? "K1 koştu rc=0"
[ ! -s "$T/ac.log" ]; g $? "K2 🔴 kuru kipte hasat.sh ac HİÇ çağrılmadı"
printf '%s' "$C" | grep -q 'kip=kuru'; g $? "K3 varsayılan kip kuru"
printf '%s' "$C" | tail -1 | grep -q 'acilan=3'; g $? "K4 🔴 tavan 3: açılabilir temiz kayıtlardan en çok 3 'açardı'"
printf '%s' "$C" | grep -q 'gorev_FFF0 tavan-doldu'; g $? "K5 dördüncüsü tavan-doldu diye günlükte"
printf '%s' "$C" | grep -q 'gorev_SSS5 atlandi-sinifli'; g $? "K6 🔴 'sil' sözlü kayıt sınıflı: atlandı (günlükte)"
printf '%s' "$C" | grep -q 'gorev_KKK6 atlandi-sinifli (kapi: karar)'; g $? "K7 🔴 kapı alanı dolu kayıt sınıflı: atlandı"
printf '%s' "$C" | grep -q 'gorev_OOO7 atlandi-sahipsiz'; g $? "K8 🔴 atanan ve odası yok: sahipsiz → AÇILMADI, günlükte"
printf '%s' "$C" | tail -1 | grep -q 'olmaz=1'; g $? "K9 bayat doğrulama olmaz sayıldı"
printf '%s' "$C" | grep -q 'gorev_BBB2 KURU: acardi → SERDAR'; g $? "K10 🔴 sahip = odanın müdürü (aile-registry oda_muduru)"
! printf '%s' "$C" | grep -q 'gorev_ZZZ9'; g $? "K11 havuz dışı kayıt hiç işlenmedi"
printf '%s' "$C" | grep -q 'gorev_AAA1 atlandi-dogmus'; g $? "K12 🔴 doğan görevi olan kayıt TEKRAR açılmaz (tekilleştirme: hasat.sh ac kendisi yapmıyor)"
printf '%s' "$C" | tail -1 | grep -q 'atlandi_dogmus=1'; g $? "K13 doğmuş kayıt özet satırında sayıldı"

echo "── GERÇEK kip (açık --gercek)"
rm -f "$T/ac.log"; C="$(koş --gercek)"; RC=$?
[ "$(wc -l < "$T/ac.log")" -eq 3 ]; g $? "G1 hasat.sh ac tam 3 kez çağrıldı (tavan)"
grep -q -- '--kip otomatik' "$T/ac.log"; g $? "G2 kip otomatik"
grep -q -- '--atanan SERDAR' "$T/ac.log"; g $? "G3 🔴 --atanan verildi (sahipsiz görev yok)"
! grep -qE 'SSS5|KKK6|OOO7|AAA1' "$T/ac.log"; g $? "G4 🔴 sınıflı/sahipsiz/doğmuş kayıt için ac ÇAĞRILMADI"

echo "── OLUR=0 ve bozuk girdi"
printf 'gorev_NNN8  code  havuz  -  bug  -  Doğrulaması bayat  (son: 2026-11-04T12:00)  oda: agentic-os\n' > "$T/liste.txt"
C="$(koş)"; printf '%s' "$C" | tail -1 | grep -q 'olur=0 acilan=0'; g $? "Z1 🔴 hiçbiri OLUR değil: günlüğe olur=0 yazıldı"
printf '' > "$T/liste.txt"; C="$(koş)"; RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$C" | grep -q 'olculemedi=defter'; g $? "Z2 🔴 defter boş/okunamadı: rc=3 ÖLÇÜLEMEDİ, olur=0 UYDURULMADI"
koş --tavan x >/dev/null 2>&1; [ "$?" -eq 2 ]; g $? "Z3 sayısız --tavan rc=2"
koş --bilinmeyen >/dev/null 2>&1; [ "$?" -eq 2 ]; g $? "Z4 bilinmeyen bayrak rc=2"
printf 'gorev_AAA1  code  havuz  -  bug  -  Temiz  (son: x)  oda: agentic-os\n' > "$T/liste.txt"; C="$(REG=/yok koş)"; printf '%s' "$C" | grep -q 'atlandi-sahipsiz'; g $? "Z5 registry okunamıyor: sahipsiz → açılmadı (fail-closed)"

printf 'gorev_EEE0  code  havuz  -  bug  -  Doğan okunamayan  (son: x)  oda: agentic-os\n' > "$T/liste.txt"; rm -f "$T/ac.log"; C="$(koş --gercek)"
printf '%s' "$C" | grep -q 'gorev_EEE0 olculemedi' && [ ! -s "$T/ac.log" ]; g $? "Z6 🔴 doğan görev okunamadı: AÇILMADI (fail-closed), ölçülemedi diye günlükte"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
