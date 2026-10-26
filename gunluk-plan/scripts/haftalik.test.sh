#!/usr/bin/env bash
# haftalik.test.sh — haftalik.sh sınavı (hermetik: sahte gorev.sh + sahte ulak.sh, gerçek defter/posta yok)
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="$KOK/haftalik.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; D=0
kapi() { if [ "$3" = "$2" ]; then echo "  ✓ $1"; G=$((G+1)); else echo "  ✗ $1 (beklenen=$2 gelen=$3)"; D=$((D+1)); fi; }

cat > "$T/gorev.sh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "liste" ] || exit 2
[ -f "$FAKE_LISTE" ] || exit 4
cat "$FAKE_LISTE"
EOF
cat > "$T/ulak.sh" <<'EOF'
#!/usr/bin/env bash
[ -n "${FAKE_ULAK_HATA:-}" ] && exit 1
printf '%s\n' "$*" >> "$FAKE_ULAK_LOG"
EOF
export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh" GUNLUK_PLAN_ULAK_SH="$T/ulak.sh" GUNLUK_PLAN_TARIH=2026-10-26 FAKE_ULAK_LOG="$T/ulak.log" FAKE_LISTE="$T/liste"
satir() { printf 'gorev_%s  %s  %s  acil  ozellik  X  %s  (son: %s)\n' "$1" "$2" "$3" "$4" "$5"; }

echo "== haftalik.sh =="
# H1: son 7 günde kapanış yok, açık iş var → Z1
{ satir A code acik "iş bir" 2026-10-25; satir B code calisiliyor "iş iki" 2026-10-26; } > "$T/liste"
o="$(bash "$ARAC" 2>&1)"; rc=$?
kapi "H1 hiç kapanış yok + açık iş → Z1 (rc=0)" "0:1" "$rc:$(printf '%s\n' "$o" | grep -c '^Z1 ')"

# H2: 7 günden eski açık iş → Z2 başlıkla
{ satir A code acik "eski iş burada" 2026-10-01; satir B code bitti "yeni biten" 2026-10-25; } > "$T/liste"
o="$(bash "$ARAC" 2>&1)"
kapi "H2 hareketsiz açık iş Z2'de başlık ve gün sayısıyla (kapanış varken Z1 yok)" "1:0" "$(printf '%s\n' "$o" | grep -c '^Z2 .*eski iş burada (25 gün)'):$(printf '%s\n' "$o" | grep -c '^Z1 ')"

# H3: bekleyen yığını → Z3
{ satir A code bekliyor "b1" 2026-10-25; satir B code bekliyor "b2" 2026-10-25; satir C code bitti "k" 2026-10-25; } > "$T/liste"
o="$(bash "$ARAC" 2>&1)"
kapi "H3 bekleyen > yürüyen+açık → Z3" "1" "$(printf '%s\n' "$o" | grep -c '^Z3 ')"

# H4: temiz kutu → 'ZAYIF yok'
{ satir A code bitti "k1" 2026-10-24; satir B code calisiliyor "c1" 2026-10-26; } > "$T/liste"
o="$(bash "$ARAC" 2>&1)"
kapi "H4 temiz kutu → 'ZAYIF yok'" "1:0" "$(printf '%s\n' "$o" | grep -c '^ZAYIF yok\|^yok$'):$(printf '%s\n' "$o" | grep -c 'Z[123] ')"

# H5: liste okunamıyor → rc=3, 'sorun yok' basılmaz
rm -f "$FAKE_LISTE"; o="$(bash "$ARAC" 2>&1)"; rc=$?
kapi "H5 liste okunamadı → rc=3 ve 'yok' denmez" "3:0" "$rc:$(printf '%s\n' "$o" | grep -c 'yok$')"
: > "$FAKE_LISTE"; bash "$ARAC" >/dev/null 2>&1; kapi "H5b liste boş → rc=3" "3" "$?"

# H6/H7: kuru göndermez; --uygula gönderir
{ satir A code acik "x" 2026-10-01; } > "$T/liste"; : > "$FAKE_ULAK_LOG"
bash "$ARAC" >/dev/null 2>&1; kapi "H6 kuru koşu mektup GÖNDERMEZ" "0" "$(wc -l < "$FAKE_ULAK_LOG" | tr -d ' ')"
bash "$ARAC" --uygula >/dev/null 2>&1; rc=$?
kapi "H7 --uygula SERDAR'a tek mektup gönderir, içinde Z2 var" "0:1:1" "$rc:$(grep -c '^gonder SERDAR ' "$FAKE_ULAK_LOG"):$(grep -c 'Z2' "$FAKE_ULAK_LOG")"
bash "$ARAC" --uygula --hedef REIS >/dev/null 2>&1; kapi "H7b --hedef alıcıyı değiştirir" "1" "$(grep -c '^gonder REIS ' "$FAKE_ULAK_LOG")"

# H8: gönderim hatası → rc=1
FAKE_ULAK_HATA=1 bash "$ARAC" --uygula >/dev/null 2>&1; kapi "H8 gönderim hatası rc=1" "1" "$?"
# H8b: ulak yok → rc=3
GUNLUK_PLAN_ULAK_SH="$T/yok.sh" bash "$ARAC" --uygula >/dev/null 2>&1; kapi "H8b ulak.sh yoksa --uygula rc=3" "3" "$?"

# H9-H10: kullanım
bash "$ARAC" --bilinmeyen >/dev/null 2>&1; kapi "H9 tanınmayan argüman rc=2" "2" "$?"
bash "$ARAC" --gun abc >/dev/null 2>&1; kapi "H10 --gun sayı değil rc=2" "2" "$?"
bash "$ARAC" --gun 0 >/dev/null 2>&1; kapi "H10b --gun 0 rc=2" "2" "$?"
bash "$ARAC" --gun 91 >/dev/null 2>&1; kapi "H10c --gun 91 rc=2" "2" "$?"

# H11: iki kutu → en sık kutu; --kutu ile seçilir
{ satir A code acik "kod1" 2026-10-25; satir B code acik "kod2" 2026-10-25; satir C nova acik "nova1" 2026-10-25; } > "$T/liste"
o="$(bash "$ARAC" 2>&1)"; o2="$(bash "$ARAC" --kutu nova 2>&1)"
kapi "H11 kutu verilmezse en sık kutu; --kutu seçer" "kutu code:kutu nova" "$(printf '%s\n' "$o" | grep -o 'kutu code'):$(printf '%s\n' "$o2" | grep -o 'kutu nova')"

# H12: --gun eşiği Z2'yi oynatır (aynı veri)
{ satir A code acik "orta eski" 2026-10-15; satir B code bitti "k" 2026-10-25; } > "$T/liste"
a="$(bash "$ARAC" 2>&1 | grep -c 'Z2')"; b="$(bash "$ARAC" --gun 14 2>&1 | grep -c 'Z2')"
kapi "H12 11 günlük iş: gün=7 Z2 var, gün=14 yok" "1:0" "$a:$b"

# H13: tam eşik günü (7 gün) hareketsiz sayılmaz (>, >= değil)
{ satir A code acik "tam yedi gun" 2026-10-19; satir B code bitti "k" 2026-10-25; } > "$T/liste"
kapi "H13 tam 7 günlük açık iş Z2 DEĞİL (eşik dahil değil)" "0" "$(bash "$ARAC" 2>&1 | grep -c '^Z2 ')"

# H14: pencere dışı kapanış sayılmaz → Z1
{ satir A code bitti "eski kapanis" 2026-10-01; satir B code acik "yeni acik" 2026-10-25; } > "$T/liste"
kapi "H14 20 gün önce kapanan iş son hafta sayılmaz → Z1" "1" "$(bash "$ARAC" 2>&1 | grep -c '^Z1 ')"

# H15: liste dolu ama hiçbir satırda tarih yok → ölçülemedi (rc=3), 'ZAYIF yok' basılmaz
printf 'gorev_Z code acik acil ozellik X tarihsiz satir\n' > "$T/liste"
o="$(bash "$ARAC" 2>&1)"; rc=$?
kapi "H15 tarihsiz liste → rc=3 ve temiz denmez" "3:0" "$rc:$(printf '%s\n' "$o" | grep -c 'ZAYIF yok\|^yok$')"

# H16: listede olmayan --kutu → ölçülemedi (rc=3), 'ZAYIF yok' basılmaz (göz tur 1)
{ satir A code acik "kod1" 2026-10-25; } > "$T/liste"
o="$(bash "$ARAC" --kutu yokkutu 2>&1)"; rc=$?
kapi "H16 var olmayan --kutu → rc=3 ve temiz denmez" "3:0" "$rc:$(printf '%s\n' "$o" | grep -c 'ZAYIF yok\|^yok$')"

echo "== $G geçti · $D düştü =="
[ "$D" -eq 0 ]
