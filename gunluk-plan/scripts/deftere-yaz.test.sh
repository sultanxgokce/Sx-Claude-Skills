#!/usr/bin/env bash
# deftere-yaz.sh sınavı — çıpadaki açık maddeler deftere yazılıyor mu, ikinci koşu çift yazıyor mu, ölçülemeyen durum 'iş yok' sayılıyor mu.
# Hermetik: gerçek deftere GİTMEZ; sahte gorev.sh (liste + ekle kaydı) ve geçici çıpa dizini kullanır.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="${DEFTERE_YAZ:-$KOK/deftere-yaz.sh}"
gecen=0; kalan=0
ONAY=""
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="SINAV"
export DEFTER_JETON_YOL="$T/jeton-yok" DEFTER_UC="http://127.0.0.1:9"
export GUNLUK_PLAN_CIPA_SH="$KOK/cipa.sh"
# onay referansı MEVCUT planın imzasını taşır (kuru koşu basar); plan değişince yeniden alınır
yenile_onay(){ local i; i="$(bash "$ARAC" --kutu huma 2>/dev/null | sed -n 's/.*plan-imzası=\([0-9a-f]*\).*/\1/p')"
  ONAY="2026-01-02 Sultan: plan onaylandi (sohbet · oturum-sinav-1 · \"bugunku plan tamam\" · beyan:SINAV · plan:$i)"; }

# sahte gorev.sh: liste $T/liste.txt'i basar (LISTE_RC çıkış kodu), ekle satırı $T/ekle.log'a ekler ve (EKLE_RC) ile döner; ekleneni listeye de katar
cat > "$T/gorev.sh" <<'EOF'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
case "$1" in
  liste) [ "${LISTE_RC:-0}" -eq 0 ] || exit "$LISTE_RC"; cat "$T/liste.txt" ;;
  ekle) printf '%s\n' "$*" >> "$T/ekle.log"
        # gerçek geçidin açılış kapısı: --ozet yoksa 400 (mihenk/s08, 27 Eki — sahte betik bunu hiç sormuyordu, birim yeşil yol kırık kaldı)
        case "$*" in *" --ozet "?*) ;; *) echo "HTTP 400 ozet_acilista_gerekli" >&2; exit 1 ;; esac
        [ "${EKLE_RC:-0}" -eq 0 ] || exit "$EKLE_RC" ;;
  adim) printf '%s\n' "$*" >> "$T/adim.log"; [ "${ADIM_RC:-0}" -eq 0 ] || exit "$ADIM_RC" ;;
esac
EOF
chmod +x "$T/gorev.sh"; export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh"
cat > "$T/liste.txt" <<'EOF'
gorev_01AAAAAAAAAAAAAAAAAAAAAAAA  huma       acik           esnek     ozellik  SINAV      Dolu başlık zaten defterde  (son: 2026-01-02T08:00)
gorev_01BBBBBBBBBBBBBBBBBBBBBBBB  huma       iptal          -         -        -          Iptal edilmis is  (son: 2026-01-01T08:00)
gorev_01CCCCCCCCCCCCCCCCCCCCCCCC  huma       onay-bekliyor  acil      bug      SINAV      Onay bekleyen is  (son: 2026-01-01T09:00)
gorev_01DDDDDDDDDDDDDDDDDDDDDDDD  huma       bitti          acil      bug      SINAV      Bugun biten is  (son: 2026-01-02T07:30)
gorev_01EEEEEEEEEEEEEEEEEEEEEEEE  huma       iptal          -         -        -          Bugun iptal edilen is  (son: 2026-01-02T07:40)
EOF
: > "$T/ekle.log"
bash "$KOK/cipa.sh" yaz --plan "1) Yeni is bir | 2) Dolu BAŞLIK zaten defterde | 3) Iptal edilmis is | 4) Onay bekleyen is | 5) Bugun biten is | 6) Bugun iptal edilen is" >/dev/null 2>&1

echo "── KURU: neyi yazacağını basar, deftere yazmaz"
c="$(bash "$ARAC" 2>&1)"; rc=$?
kapi "D1 kuru rc=0" "0" "$rc"
kapi "D2 kuru: ekle çağrılmaz" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
kapi "D3 kuru: 'yazardım' satırları (yeni + eski günde iptal olan = 2)" "2" "$(printf '%s\n' "$c" | grep -c 'yazardım')"
kapi "D4 kuru: açık, onay bekleyen VE bugün kapanan görevle aynı başlık (büyük/küçük harf, sıra numarası farkıyla) atlanır" "4" "$(printf '%s\n' "$c" | grep -c 'atlandı')"
kapi "D4b kutu listeden türedi (huma)" "1" "$(printf '%s\n' "$c" | grep -c 'kutu=huma')"

yenile_onay
echo "── UYGULA: yazar, İKİNCİ koşu çift yazmaz"
c="$(bash "$ARAC" --uygula --onay "$ONAY" 2>&1)"; rc=$?
kapi "D5 uygula rc=0" "0" "$rc"
kapi "D6 iki görev yazıldı" "2" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
kapi "D7 ekle bayrakları: kutu · atanan · özellik · günlük plan kaynağı" "2" "$(grep -c -- "--kutu huma .*--etiket ozellik .*--atanan SINAV .*--kaynak-nereden günlük plan" "$T/ekle.log")"
# yazılanlar listeye girmiş say (gerçek defter gibi)
awk -F' ' '{print}' "$T/ekle.log" | sed -n 's/^ekle \(.*\) --kutu.*/gorev_01ZZ  huma       acik           esnek     ozellik  SINAV      \1  (son: x)/p' >> "$T/liste.txt"
: > "$T/ekle.log"
c="$(bash "$ARAC" --uygula --onay "$ONAY" 2>&1)"; rc=$?
kapi "D8 ikinci koşu: hiçbir şey yazılmaz (idempotent)" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"

echo "── ÖLÇÜLEMEYEN durum 'yazılacak bir şey yok' DENMEZ"
LISTE_RC=7 bash "$ARAC" --uygula --onay "$ONAY" --kutu huma >/dev/null 2>&1; kapi "D9 defter listesi okunamadı → rc=3" "3" "$?"
GUNLUK_PLAN_CIPA_DIZ="$T/bos" bash "$ARAC" --uygula --onay "$ONAY" >/dev/null 2>&1; kapi "D10 çıpa yok → rc=3" "3" "$?"
: > "$T/ekle.log"; : > "$T/liste.txt"
LISTE_RC=0 bash "$ARAC" --kutu huma >/dev/null 2>&1; kapi "D10b liste BOŞ → rc=3 (boş liste 'iş yok' değil, ölçülemedi)" "3" "$?"

echo "── ONAY KAPISI (A06/D1): onaysız plan deftere yazılmaz"
printf 'gorev_01AAAAAAAAAAAAAAAAAAAAAAAA  huma       acik           esnek     ozellik  SINAV      Baska is  (son: 2026-01-02T08:00)\n' > "$T/liste.txt"
bash "$KOK/cipa.sh" yaz --plan "1) Yeni onay sinavi is" >/dev/null 2>&1
yenile_onay
: > "$T/ekle.log"
bash "$ARAC" --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --uygula --onay "onayladi" >/dev/null 2>&1; r2=$?
bash "$ARAC" --uygula --onay "2026-01-02 Sultan: onay (sohbet · ref · beyan:SINAV)" >/dev/null 2>&1; r3=$?
I="${ONAY##*plan:}"; I="${I%)}"
kapi "D16 --onay'sız --uygula REDDEDİLİR (rc=2)" "2" "$r1"
kisa="${ONAY/bugunku plan tamam/ab}"; bash "$ARAC" --uygula --onay "$kisa" >/dev/null 2>&1; kapi "D17b iki harflik kırpık (tarih+imza doğru, yalnız biçim kapısı yakalar) REDDEDİLİR" "2" "$?"
beyansiz="${ONAY/ · beyan:SINAV/}"; bash "$ARAC" --uygula --onay "$beyansiz" >/dev/null 2>&1; kapi "D17g beyan parçası eksik (tarih+imza doğru) REDDEDİLİR" "2" "$?"
kapi "D17 biçimsiz onay (kırpık/ref eksik) REDDEDİLİR" "2:2" "$r2:$r3"
kapi "D18 reddedilen koşuda ekle ÇAĞRILMAZ" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
bash "$ARAC" >/dev/null 2>&1; eski="${ONAY/2026-01-02 Sultan/2026-01-01 Sultan}"; bash "$ARAC" --uygula --onay "$eski" >/dev/null 2>&1; kapi "D17c ESKİ tarihli onay REDDEDİLİR (bugün değil)" "2" "$?"
yanlis="${ONAY/plan:$I/plan:00000000}"; bash "$ARAC" --uygula --onay "$yanlis" >/dev/null 2>&1; kapi "D17d başka planın imzasını taşıyan onay REDDEDİLİR" "2" "$?"
bash "$KOK/cipa.sh" yaz --plan "1) Onaydan sonra degisen is" >/dev/null 2>&1; bash "$ARAC" --uygula --onay "$ONAY" >/dev/null 2>&1; kapi "D17e plan onaydan SONRA değişti → eski onay düşer" "2" "$?"
kapi "D18b reddedilen koşularda ekle çağrılmadı" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
bash "$KOK/cipa.sh" yaz --plan "1) Yeni onay sinavi is" >/dev/null 2>&1; yenile_onay
bash "$ARAC" --uygula --onay "$ONAY" >/dev/null 2>&1; kapi "D17f doğru imza + bugün + biçim → KABUL (rc=0, 1 görev yazıldı)" "0:1" "$?:$(wc -l < "$T/ekle.log" | tr -d ' ')"
: > "$T/ekle.log"
c19="$(bash "$ARAC" 2>&1)"; rc19=$?
kapi "D19 kuru koşu onaysız ÇALIŞIR (rc=0, 'kuru:' ve plan-imzası basar, ekle çağrılmaz)" "0:1:0" "$rc19:$(printf '%s\n' "$c19" | grep -c 'kuru: .*plan-imzası=[0-9a-f]\{8\}'):$(wc -l < "$T/ekle.log" | tr -d ' ')"
uzun="${ONAY/bugunku plan tamam/bir iki uc dort bes alti yedi sekiz dokuz on onbir oniki onuc ondort onbes onalti}"; bash "$ARAC" --uygula --onay "$uzun" >/dev/null 2>&1; kapi "D17h 15 kelimeyi aşan alıntı REDDEDİLİR (tarih+imza doğru)" "2" "$?"
on5="${ONAY/bugunku plan tamam/bir iki uc dort bes alti yedi sekiz dokuz on onbir oniki onuc ondort onbes}"; : > "$T/ekle.log"; bash "$ARAC" --uygula --onay "$on5" >/dev/null 2>&1; kapi "D17i tam 15 kelimelik alıntı KABUL (sınır dahil)" "0" "$?"

echo "── Hata ve sınırlar"
cat > "$T/liste.txt" <<'EOF'
gorev_01AAAAAAAAAAAAAAAAAAAAAAAA  huma       acik           esnek     ozellik  SINAV      Baska is  (son: 2026-01-02T08:00)
EOF
: > "$T/ekle.log"
yenile_onay
EKLE_RC=1 bash "$ARAC" --uygula --onay "$ONAY" >/dev/null 2>&1; kapi "D11 ekle başarısız → rc=1 (yazıldı denmez)" "1" "$?"
bash "$KOK/cipa.sh" yaz --plan "1) $(printf 'x%.0s' $(seq 1 210))" >/dev/null 2>&1
yenile_onay
: > "$T/ekle.log"
bash "$ARAC" --uygula --onay "$ONAY" >/dev/null 2>&1; rc=$?
kapi "D12 200 karakter üstü madde REDDEDİLİR (rc=1), ekle çağrılmaz" "1:0" "$rc:$(wc -l < "$T/ekle.log" | tr -d ' ')"
bash "$ARAC" --aciliyet yok >/dev/null 2>&1; kapi "D13 geçersiz aciliyet rc=2" "2" "$?"
bash "$ARAC" --bilinmeyen >/dev/null 2>&1; kapi "D14 tanınmayan argüman rc=2" "2" "$?"
bash "$KOK/cipa.sh" yaz --plan "1) Bir is" >/dev/null 2>&1; yenile_onay; : > "$T/ekle.log"
bash "$ARAC" --uygula --onay "$ONAY" --kutu tellal --kim ORNEK --aciliyet acil >/dev/null 2>&1
kapi "D15 --kutu/--kim/--aciliyet ayarları ekle'ye geçer" "1" "$(grep -c -- '--kutu tellal --etiket ozellik --aciliyet acil --atanan ORNEK --kaynak-kim ORNEK' "$T/ekle.log")"
echo "── AÇILIŞ ÖZETİ (mihenk/s08): ekle --ozet taşır, hata sebebi ekrana basılır"
bash "$KOK/cipa.sh" yaz --plan "1) Ozetli is" >/dev/null 2>&1; yenile_onay; : > "$T/ekle.log"
bash "$ARAC" --uygula --onay "$ONAY" --kutu huma >/dev/null 2>&1
kapi "D19 ekle çağrısı --ozet taşır (Sultan-dili, madde metniyle)" "1" "$(grep -c -- '--ozet .*→ henüz başlanmadı → .*Ozetli is' "$T/ekle.log")"
c="$(EKLE_RC=9 bash "$ARAC" --uygula --onay "$ONAY" --kutu huma 2>&1)"
kapi "D20 reddedilen yazım YAZILAMADI + sebep satırı basar" "1:1" "$(printf '%s' "$c" | grep -c 'YAZILAMADI'):$(printf '%s' "$c" | grep -c 'sebep:')"
echo "── GÖREV KİMLİKLİ MADDE ve İKİZ (GJRBF1T8): sırada duran işin ikizi açılmaz"
cat > "$T/liste.txt" <<'EOF'
gorev_01AAAAAAAAAAAAAAAAAAJRCK8J  huma       acik           esnek     ozellik  SINAV      Terminal arayuzunde ortak klasor gezgini Finder gibi  (son: 2026-01-02T08:00)
gorev_01BBBBBBBBBBBBBBBBBB1R33ZG  huma       sira-bende     acil      bug      -          Kokpitte posta sekmesi ajan basina gelen kutusu  (son: 2026-01-02T08:00)
gorev_01CCCCCCCCCCCCCCCCCC1R33ZG  huma       bitti          acil      bug      SINAV      Eski ayni sonekli is  (son: 2026-01-01T08:00)
gorev_01DDDDDDDDDDDDDDDDDDFVJEYF  huma       acik           esnek     ozellik  SINAV      Nabiz sayaci gorevin ilk calisiliyor anindan sayiyor  (son: 2026-01-02T08:00)
EOF
: > "$T/ekle.log"; : > "$T/adim.log"
bash "$KOK/cipa.sh" yaz --plan "1) görev …JRCK8J tamamlanacak: ortak klasör gezgini biter (sahip: SINAV) | 2) Kokpitte posta sekmesi gorev_01BBBBBBBBBBBBBBBBBB1R33ZG | 3) Terminal arayüzünde ortak klasör gezgini bitirilecek | 4) Nabız sayacı görevin ilk çalışılıyor anından saymalı | 5) Bambaşka yepyeni bir iş fikri" >/dev/null 2>&1
c="$(bash "$ARAC" --kutu huma 2>&1)"; rc=$?
kapi "D21 kuru: kimlikli iki madde 'bağlardım' (yeni kayıt yok), ikiz iki madde ✗, bir yeni madde yazardım; rc 1 (ikiz var)" "1:2:2:1" "$rc:$(grep -c 'bağlardım' <<<"$c"):$(grep -c 'İKİZ OLABİLİR' <<<"$c"):$(grep -c 'yazardım' <<<"$c")"
kapi "D21b ikiz uyarısı kimliği ve son-ekini söyler (…JRCK8J, …FVJEYF)" "1:1" "$(grep -c 'görev …gorev_01AAAAAAAAAAAAAAAAAAJRCK8J' <<<"$c"):$(grep -c 'görev …gorev_01DDDDDDDDDDDDDDDDDDFVJEYF' <<<"$c")"
kapi "D21c özet satırı bağlanan=2 ikiz=2 yazılan=1" "1" "$(grep -c 'yazılan=1 bağlanan=2 atlanan=0 ikiz=2' <<<"$c")"
yenile_onay 2>/dev/null; I2="$(bash "$ARAC" --kutu huma 2>/dev/null | sed -n 's/.*plan-imzası=\([0-9a-f]*\).*/\1/p')"; ONAY="2026-01-02 Sultan: plan onaylandi (sohbet · oturum-sinav-1 · \"bugunku plan tamam\" · beyan:SINAV · plan:$I2)"
c="$(bash "$ARAC" --kutu huma --uygula --onay "$ONAY" 2>&1)"; rc=$?
kapi "D22 uygula: kimlikli maddeler için gorev.sh adim ÇAĞRILDI (2), ekle yalnız yeni madde için (1), ikizler YAZILMADI" "2:1:1" "$(wc -l < "$T/adim.log" | tr -d ' '):$(wc -l < "$T/ekle.log" | tr -d ' '):$rc"
kapi "D22b adım doğru kayda, 'bugünün planında' metniyle (kısa son-ek JRCK8J → tam kimlik)" "1:1" "$(grep -c '^adim gorev_01AAAAAAAAAAAAAAAAAAJRCK8J bugünün planında (SINAV, 2026-01-02)' "$T/adim.log"):$(grep -c '^adim gorev_01BBBBBBBBBBBBBBBBBB1R33ZG ' "$T/adim.log")"
kapi "D22c ekle yalnız 'Bambaşka yepyeni' maddesi için" "1" "$(grep -c 'ekle Bambaşka yepyeni' "$T/ekle.log")"
: > "$T/ekle.log"; : > "$T/adim.log"
bash "$KOK/cipa.sh" yaz --plan "1) görev …1R33ZG tamamlanacak: posta sekmesi | 2) görev …YOKYOK tamamlanacak: hayalet | 3) Hayalet tam kimlik gorev_01ZZZZZZZZZZZZZZZZZZZZZZZZ" >/dev/null 2>&1
c="$(bash "$ARAC" --kutu huma 2>&1)"; rc=$?
kapi "D23 son-ek iki kayda uyuyor (…1R33ZG) → ✗ çözülemedi; defterde olmayan son-ek ve tam kimlik → ✗; rc 1, tahmin yok" "1:3:1:2" "$rc:$(grep -c 'görev kimliği çözülemedi' <<<"$c"):$(grep -c 'SON-EK BİRDEN ÇOK' <<<"$c"):$(grep -c 'KİMLİK DEFTERDE YOK' <<<"$c")"
: > "$T/ekle.log"
bash "$KOK/cipa.sh" yaz --plan "1) Nabız sayacı yeniden ayarlanacak" >/dev/null 2>&1
c="$(bash "$ARAC" --kutu huma 2>&1)"; rc=$?
kapi "D24 örtüşme %60 altı (2/4 kelime) → ikiz DEĞİL, yazardım, rc 0" "0:1:0" "$rc:$(grep -c 'yazardım' <<<"$c"):$(grep -c 'İKİZ' <<<"$c")"
I3="$(bash "$ARAC" --kutu huma 2>/dev/null | sed -n 's/.*plan-imzası=\([0-9a-f]*\).*/\1/p')"; ONAY="2026-01-02 Sultan: plan onaylandi (sohbet · oturum-sinav-1 · \"bugunku plan tamam\" · beyan:SINAV · plan:$I3)"
bash "$KOK/cipa.sh" yaz --plan "1) görev …FVJEYF tamamlanacak: nabız" >/dev/null 2>&1; I4="$(bash "$ARAC" --kutu huma 2>/dev/null | sed -n 's/.*plan-imzası=\([0-9a-f]*\).*/\1/p')"; ONAY="2026-01-02 Sultan: plan onaylandi (sohbet · oturum-sinav-1 · \"bugunku plan tamam\" · beyan:SINAV · plan:$I4)"
: > "$T/adim.log"; c="$(ADIM_RC=1 bash "$ARAC" --kutu huma --uygula --onay "$ONAY" 2>&1)"; rc=$?
kapi "D25 adim yazılamazsa ✗ ADIM YAZILAMADI + sebep, rc 1 (bağlandı denmez)" "1:1" "$rc:$(grep -c 'ADIM YAZILAMADI' <<<"$c")"
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
