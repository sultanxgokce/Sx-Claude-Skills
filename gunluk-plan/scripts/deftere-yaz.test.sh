#!/usr/bin/env bash
# deftere-yaz.sh sınavı — çıpadaki açık maddeler deftere yazılıyor mu, ikinci koşu çift yazıyor mu, ölçülemeyen durum 'iş yok' sayılıyor mu.
# Hermetik: gerçek deftere GİTMEZ; sahte gorev.sh (liste + ekle kaydı) ve geçici çıpa dizini kullanır.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="${DEFTERE_YAZ:-$KOK/deftere-yaz.sh}"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="SINAV"
export DEFTER_JETON_YOL="$T/jeton-yok" DEFTER_UC="http://127.0.0.1:9"
export GUNLUK_PLAN_CIPA_SH="$KOK/cipa.sh"

# sahte gorev.sh: liste $T/liste.txt'i basar (LISTE_RC çıkış kodu), ekle satırı $T/ekle.log'a ekler ve (EKLE_RC) ile döner; ekleneni listeye de katar
cat > "$T/gorev.sh" <<'EOF'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
case "$1" in
  liste) [ "${LISTE_RC:-0}" -eq 0 ] || exit "$LISTE_RC"; cat "$T/liste.txt" ;;
  ekle) printf '%s\n' "$*" >> "$T/ekle.log"; [ "${EKLE_RC:-0}" -eq 0 ] || exit "$EKLE_RC" ;;
esac
EOF
chmod +x "$T/gorev.sh"; export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh"
cat > "$T/liste.txt" <<'EOF'
gorev_01AAAAAAAAAAAAAAAAAAAAAAAA  huma       acik           esnek     ozellik  SINAV      Dolu başlık zaten defterde  (son: 2026-01-02T08:00)
gorev_01BBBBBBBBBBBBBBBBBBBBBBBB  huma       iptal          -         -        -          Iptal edilmis is  (son: 2026-01-01T08:00)
gorev_01CCCCCCCCCCCCCCCCCCCCCCCC  huma       onay-bekliyor  acil      bug      SINAV      Onay bekleyen is  (son: 2026-01-01T09:00)
EOF
: > "$T/ekle.log"
bash "$KOK/cipa.sh" yaz --plan "1) Yeni is bir | 2) Dolu BAŞLIK zaten defterde | 3) Iptal edilmis is | 4) Onay bekleyen is" >/dev/null 2>&1

echo "── KURU: neyi yazacağını basar, deftere yazmaz"
c="$(bash "$ARAC" 2>&1)"; rc=$?
kapi "D1 kuru rc=0" "0" "$rc"
kapi "D2 kuru: ekle çağrılmaz" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
kapi "D3 kuru: 'yazardım' satırları (yeni + iptal olan = 2)" "2" "$(printf '%s\n' "$c" | grep -c 'yazardım')"
kapi "D4 kuru: açık ve onay bekleyen görevle aynı başlık (büyük/küçük harf, sıra numarası farkıyla) atlanır" "2" "$(printf '%s\n' "$c" | grep -c 'atlandı')"
kapi "D4b kutu listeden türedi (huma)" "1" "$(printf '%s\n' "$c" | grep -c 'kutu=huma')"

echo "── UYGULA: yazar, İKİNCİ koşu çift yazmaz"
c="$(bash "$ARAC" --uygula 2>&1)"; rc=$?
kapi "D5 uygula rc=0" "0" "$rc"
kapi "D6 iki görev yazıldı" "2" "$(wc -l < "$T/ekle.log" | tr -d ' ')"
kapi "D7 ekle bayrakları: kutu · atanan · özellik · günlük plan kaynağı" "2" "$(grep -c -- "--kutu huma .*--etiket ozellik .*--atanan SINAV .*--kaynak-nereden günlük plan" "$T/ekle.log")"
# yazılanlar listeye girmiş say (gerçek defter gibi)
awk -F' ' '{print}' "$T/ekle.log" | sed -n 's/^ekle \(.*\) --kutu.*/gorev_01ZZ  huma       acik           esnek     ozellik  SINAV      \1  (son: x)/p' >> "$T/liste.txt"
: > "$T/ekle.log"
c="$(bash "$ARAC" --uygula 2>&1)"; rc=$?
kapi "D8 ikinci koşu: hiçbir şey yazılmaz (idempotent)" "0" "$(wc -l < "$T/ekle.log" | tr -d ' ')"

echo "── ÖLÇÜLEMEYEN durum 'yazılacak bir şey yok' DENMEZ"
LISTE_RC=7 bash "$ARAC" --uygula --kutu huma >/dev/null 2>&1; kapi "D9 defter listesi okunamadı → rc=3" "3" "$?"
GUNLUK_PLAN_CIPA_DIZ="$T/bos" bash "$ARAC" --uygula >/dev/null 2>&1; kapi "D10 çıpa yok → rc=3" "3" "$?"
: > "$T/ekle.log"; : > "$T/liste.txt"
LISTE_RC=0 bash "$ARAC" --kutu huma >/dev/null 2>&1; kapi "D10b liste BOŞ → rc=3 (boş liste 'iş yok' değil, ölçülemedi)" "3" "$?"

echo "── Hata ve sınırlar"
cat > "$T/liste.txt" <<'EOF'
gorev_01AAAAAAAAAAAAAAAAAAAAAAAA  huma       acik           esnek     ozellik  SINAV      Baska is  (son: 2026-01-02T08:00)
EOF
: > "$T/ekle.log"
EKLE_RC=1 bash "$ARAC" --uygula >/dev/null 2>&1; kapi "D11 ekle başarısız → rc=1 (yazıldı denmez)" "1" "$?"
bash "$KOK/cipa.sh" yaz --plan "1) $(printf 'x%.0s' $(seq 1 210))" >/dev/null 2>&1
: > "$T/ekle.log"
bash "$ARAC" --uygula >/dev/null 2>&1; rc=$?
kapi "D12 200 karakter üstü madde REDDEDİLİR (rc=1), ekle çağrılmaz" "1:0" "$rc:$(wc -l < "$T/ekle.log" | tr -d ' ')"
bash "$ARAC" --aciliyet yok >/dev/null 2>&1; kapi "D13 geçersiz aciliyet rc=2" "2" "$?"
bash "$ARAC" --bilinmeyen >/dev/null 2>&1; kapi "D14 tanınmayan argüman rc=2" "2" "$?"
bash "$KOK/cipa.sh" yaz --plan "1) Bir is" >/dev/null 2>&1; : > "$T/ekle.log"
bash "$ARAC" --uygula --kutu tellal --kim ORNEK --aciliyet acil >/dev/null 2>&1
kapi "D15 --kutu/--kim/--aciliyet ayarları ekle'ye geçer" "1" "$(grep -c -- '--kutu tellal --etiket ozellik --aciliyet acil --atanan ORNEK --kaynak-kim ORNEK' "$T/ekle.log")"
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
