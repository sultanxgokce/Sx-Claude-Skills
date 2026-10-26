#!/usr/bin/env bash
# tarama-ekle.sh sınavı — ölçmeden iş yazılıyor mu, günlük tavan tutuyor mu, kopya yazılıyor mu, ölçülemeyen durum "yazılacak yok" sayılıyor mu.
# Hermetik: gerçek deftere GİTMEZ; sahte gorev.sh (liste) ve sahte bulgu.sh (yaz çağrısı kaydı) kullanır.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="${TARAMA_EKLE:-$KOK/tarama-ekle.sh}"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="SINAV"
unset AGENT_NAME GUNLUK_PLAN_TARAMA_TAVAN GUNLUK_PLAN_KUTU

cat > "$T/gorev.sh" <<'EOF'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
case "$1" in liste) [ "${LISTE_RC:-0}" -eq 0 ] || exit "$LISTE_RC"; cat "$T/liste.txt" ;; esac
EOF
cat > "$T/bulgu.sh" <<'EOF'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
printf '%s\n' "$*" >> "$T/yaz.log"
[ "${BULGU_RC:-0}" -eq 0 ] || exit "${BULGU_RC}"
[ -n "${BULGU_YAZMA:-}" ] || printf 'gorev_01ZZZZZZZZZZZZZZZZZZZZZZ  %s  acik  esnek  ozellik  SINAV  %s  (son: 2026-01-02T09:00)\n' "${BULGU_KUTU:-huma}" "$2" >> "$T/liste.txt"
EOF
chmod +x "$T/gorev.sh" "$T/bulgu.sh"
export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh" GUNLUK_PLAN_BULGU_SH="$T/bulgu.sh"
liste() { cat > "$T/liste.txt"; cp "$T/liste.txt" "$T/taban.txt"; }
satir() { printf 'gorev_01%s  %s  %s  esnek  ozellik  SINAV  %s  (son: %s)\n' "$1" "$2" "$3" "$4" "$5"; }   # id kutu durum başlık son
yaz_say() { [ -f "$T/yaz.log" ] && wc -l < "$T/yaz.log" | tr -d ' ' || echo 0; }
sifirla() { rm -f "$T/yaz.log"; [ -f "$T/taban.txt" ] && cp "$T/taban.txt" "$T/liste.txt"; }
K="https://example.com/rapor"; KN="bugün ölçülen: 3 dosyada aynı kalıp, grep ile sayıldı"
satir AAAAAAAAAAAAAAAAAAAAAAAA huma acik "Baska bir is" 2026-01-02T08:00 | liste

echo "── KURU koşu"
sifirla; c="$(bash "$ARAC" --baslik "Yeni tarama işi" --kaynak "$K" --kanit "$KN" --kutu huma 2>&1)"; rc=$?
kapi "T1 kuru rc=0" 0 "$rc"
kapi "T1b kuru 'yazardım' basar, bulgu.sh ÇAĞRILMAZ" "0:yes" "$(yaz_say):$(grep -q 'yazardım' <<<"$c" && echo yes || echo no)"

echo "── UYGULA"
sifirla; c="$(bash "$ARAC" --baslik "Yeni tarama işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula 2>&1)"; rc=$?
kapi "T2 uygula rc=0 ve tek yaz çağrısı" "0:1" "$rc:$(yaz_say)"
kapi "T2b başlık '[tarama] ' işaretli, etiket özellik, kim=SINAV" "yes" "$(grep -q '^yaz \[tarama\] Yeni tarama işi --kim SINAV --etiket ozellik' "$T/yaz.log" && echo yes || echo no)"
kapi "T2c not kaynak ve kanıtı taşır" "yes" "$(grep -q "kaynak: $K · kanıt: $KN" "$T/yaz.log" && echo yes || echo no)"
mkdir -p "$T/proje/ui/lib"; seq 1 50 > "$T/proje/ui/lib/x.ts"
sifirla; ( cd "$T/proje" && bash "$ARAC" --baslik "Dosya kaynaklı iş" --kaynak "ui/lib/x.ts:42" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1 ); rc=$?
kapi "T2d dosya:satır kaynağı kabul" "0:1" "$rc:$(yaz_say)"
sifirla; bash "$ARAC" --baslik "Başka kim" --kaynak "$K" --kanit "$KN" --kutu huma --kim BASKA --uygula >/dev/null 2>&1
kapi "T2e --kim ilk ajan değerini ezer" "yes" "$(grep -q -- '--kim BASKA' "$T/yaz.log" && echo yes || echo no)"

echo "── ÖLÇMEDEN İŞ YAZILMAZ"
sifirla
bash "$ARAC" --baslik "X işi" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --baslik "X işi" --kaynak "kaynak yok" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r2=$?
bash "$ARAC" --baslik "X işi" --kaynak "http://example.com/x" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r3=$?
bash "$ARAC" --baslik "X işi" --kaynak "dosya.ts:abc" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r4=$?
kapi "T3 kaynak yok / biçimsiz / http / satırsız → hepsi rc 2, yazılmadı" "2 2 2 2:0" "$r1 $r2 $r3 $r4:$(yaz_say)"
bash "$ARAC" --baslik "X işi" --kaynak "$K" --kanit "kısa" --kutu huma --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --baslik "X işi" --kaynak "$K" --kutu huma --uygula >/dev/null 2>&1; r2=$?
kapi "T4 kanıt 20 karakterden kısa ya da yok → rc 2, yazılmadı" "2 2:0" "$r1 $r2:$(yaz_say)"
bash "$ARAC" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --baslik "$(printf 'a%.0s' $(seq 1 161))" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r2=$?
bash "$ARAC" --baslik "$(printf 'a%.0s' $(seq 1 160))" --kaynak "$K" --kanit "$KN" --kutu huma >/dev/null 2>&1; r3=$?
kapi "T5 başlık yok / 161 karakter → rc 2; 160 karakter geçer (kuru)" "2 2 0:0" "$r1 $r2 $r3:$(yaz_say)"
bash "$ARAC" --bilinmeyen >/dev/null 2>&1; kapi "T5b tanınmayan argüman rc 2" 2 "$?"

c="$( cd "$T/proje" && bash "$ARAC" --baslik "X işi" --kaynak "ui/lib/yok.ts:3" --kanit "$KN" --kutu huma --uygula 2>&1 )"; r1=$?; m1="$(grep -c "kaynak dosyası yok" <<<"$c")"
( cd "$T/proje" && bash "$ARAC" --baslik "X işi" --kaynak "ui/lib/x.ts:51" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1 ); r2=$?
( cd "$T/proje" && bash "$ARAC" --baslik "X işi" --kaynak "ui/lib/x.ts:0" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1 ); r3=$?
kapi "T4b kaynak dosyası yok (mesajıyla) / satır dosyanın dışında (51, 0) → hepsi rc 2, yazılmadı" "2 2 2:0:1" "$r1 $r2 $r3:$(yaz_say):$m1"
bash "$ARAC" --baslik "X işi" --kaynak "$K" --kanit "sayı içermeyen ama yirmi karakterden uzun serbest metin" --kutu huma --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --baslik "X işi" --kaynak "$K" --kanit "3 adet" --kutu huma --uygula >/dev/null 2>&1; rk=$?
kapi "T4d sayı var ama kanıt 20 karakterden kısa → rc 2" "2:0" "$rk:$(yaz_say)"
kapi "T4c kanıtta ölçülmüş sayı yoksa rc 2 (serbest metin ölçüm değil)" "2:0" "$r1:$(yaz_say)"

echo "── KOPYA"
{ satir BBBBBBBBBBBBBBBBBBBBBBBB huma acik "Açık duran iş" 2026-01-01T08:00
  satir CCCCCCCCCCCCCCCCCCCCCCCC huma bitti "Bugün biten iş" 2026-01-02T07:30
  satir DDDDDDDDDDDDDDDDDDDDDDDD huma iptal "Eski kapanan iş" 2025-12-20T08:00
  satir EEEEEEEEEEEEEEEEEEEEEEEE huma acik "[tarama] Tarama olarak açık" 2026-01-01T10:00; } | liste
sifirla
bash "$ARAC" --baslik "AÇIK DURAN iş" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
bash "$ARAC" --baslik "Bugün biten iş!" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r2=$?
bash "$ARAC" --baslik "Tarama olarak açık" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r3=$?
kapi "T6 açık / bugün kapanan / zaten [tarama] olan aynı başlık (büyük-küçük harf, noktalama farkı dahil) → rc 2, yazılmadı" "2 2 2:0" "$r1 $r2 $r3:$(yaz_say)"
bash "$ARAC" --baslik "Eski kapanan iş" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
kapi "T6b eski günde kapanmış başlık yeniden yazılabilir" "0:1" "$r1:$(yaz_say)"

echo "── GÜNLÜK TAVAN (3)"
{ satir F1 huma acik "[tarama] Bir" 2026-01-02T01:00; satir F2 huma bitti "[tarama] İki" 2026-01-02T02:00
  satir F3 mmex acik "[tarama] Başka kutu" 2026-01-02T03:00; satir F4 huma acik "[tarama] Dün" 2026-01-01T03:00; } | liste
sifirla
bash "$ARAC" --baslik "Üçüncü iş" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
kapi "T7 bugün 2 kayıt var (başka kutu ve dün sayılmaz) → 3. yazılır" "0:1" "$r1:$(yaz_say)"
{ satir F1 huma acik "[tarama] Bir" 2026-01-02T01:00; satir F2 huma bitti "[tarama] İki" 2026-01-02T02:00; satir F5 huma acik "[tarama] Üç" 2026-01-02T03:00; } | liste
sifirla; c="$(bash "$ARAC" --baslik "Dördüncü iş" --kaynak "$K" --kanit "$KN" --kutu huma --uygula 2>&1)"; rc=$?
kapi "T7b bugün 3 kayıt dolu → rc 2, 'günlük tavan 3', yazılmadı" "2:0:yes" "$rc:$(yaz_say):$(grep -q 'günlük tavan 3' <<<"$c" && echo yes || echo no)"
sifirla; GUNLUK_PLAN_TARAMA_TAVAN=4 bash "$ARAC" --baslik "Dördüncü iş" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
kapi "T7c tavan ortam değişkeniyle YÜKSELTİLEMEZ (3 sabit)" "2:0" "$r1:$(yaz_say)"
sifirla; bash "$ARAC" --baslik "Kuru ama dolu" --kaynak "$K" --kanit "$KN" --kutu huma >/dev/null 2>&1; rc=$?
kapi "T7d kuru koşu da tavanı sayar (dolu günde rc 2)" 2 "$rc"

echo "── ÖLÇÜLEMEZSE YAZMAZ"
sifirla; LISTE_RC=1 bash "$ARAC" --baslik "Y işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
: | liste; bash "$ARAC" --baslik "Y işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r2=$?
kapi "T8 liste okunamadı / boş → rc 3, yazılmadı ('yazılacak yok' denmez)" "3 3:0" "$r1 $r2:$(yaz_say)"
satir AAAAAAAAAAAAAAAAAAAAAAAA huma acik "Baska bir is" 2026-01-02T08:00 | liste
sifirla; GUNLUK_PLAN_BULGU_SH="$T/yok.sh" bash "$ARAC" --baslik "Z işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r1=$?
BULGU_RC=1 bash "$ARAC" --baslik "Z işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; r2=$?
kapi "T9 bulgu.sh yok → rc 3; bulgu.sh düşerse → rc 1" "3 1" "$r1 $r2"
env -u GUNLUK_PLAN_AJAN bash "$ARAC" --baslik "K işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; kapi "T10 ajan kimliği yoksa rc 3 (kim yazdı belli olmadan yazılmaz)" 3 "$?"
sifirla; GUNLUK_PLAN_GOREV_SH="$T/yok.sh" bash "$ARAC" --baslik "G işi" --kaynak "$K" --kanit "$KN" --kutu huma --uygula >/dev/null 2>&1; kapi "T10b gorev.sh yok → rc 3" 3 "$?"

echo "── KUTU ADI ve YAZIM KUTUSU"
{ satir G1 mmex acik "Bir" 2026-01-02T01:00; satir G2 mmex acik "İki" 2026-01-02T01:00; satir G3 huma acik "Üç" 2026-01-02T01:00; } | liste
sifirla; c="$(bash "$ARAC" --baslik "Kutu seç" --kaynak "$K" --kanit "$KN" --uygula 2>&1)"; rc=$?
kapi "T11 liste birden çok kutu gösterip --kutu verilmezse TAHMİN YOK: rc 3, yazılmadı" "3:0" "$rc:$(yaz_say)"
{ satir G1 mmex acik "Bir" 2026-01-02T01:00; satir G2 mmex acik "İki" 2026-01-02T01:00; } | liste
sifirla; c="$(BULGU_KUTU=mmex bash "$ARAC" --baslik "Kutu seç" --kaynak "$K" --kanit "$KN" --uygula 2>&1)"; rc=$?
kapi "T11b liste tek kutu gösteriyorsa o kutu (mmex) sayılır ve kayıt orada doğrulanır" "0:yes" "$rc:$(grep -q 'kutu mmex' <<<"$c" && echo yes || echo no)"
{ satir G1 huma acik "Bir" 2026-01-02T01:00; satir G2 mmex acik "İki" 2026-01-02T01:00; } | liste
sifirla; c="$(BULGU_KUTU=mmex bash "$ARAC" --baslik "Başka kutuya düşer" --kaynak "$K" --kanit "$KN" --kutu huma --uygula 2>&1)"; rc=$?
kapi "T12 sayım 'huma'da ama kayıt 'mmex'e düştüyse rc 1 ve açıkça söylenir (tavan çevresinden dolaşılamaz)" "1:yes" "$rc:$(grep -q "'mmex' kutusuna yazıldı, tavan 'huma'" <<<"$c" && echo yes || echo no)"
sifirla; c="$(BULGU_YAZMA=1 bash "$ARAC" --baslik "Görünmeyen kayıt" --kaynak "$K" --kanit "$KN" --kutu huma --uygula 2>&1)"; rc=$?
kapi "T12b yazıldı ama defterde görünmüyorsa rc 1 ('kutu doğrulanamadı')" "1:yes" "$rc:$(grep -q 'kutu doğrulanamadı' <<<"$c" && echo yes || echo no)"

echo; echo "$gecen geçti, $kalan kaldı"; [ "$kalan" -eq 0 ]
