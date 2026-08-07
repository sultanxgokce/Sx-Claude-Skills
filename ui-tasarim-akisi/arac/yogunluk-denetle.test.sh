#!/usr/bin/env bash
# yogunluk-denetle.test.sh — kapının kendi sınavı.
#
# NİÇİN: "negatif fikstürü olmayan kapı devreye alınmaz". Bu suit iki şeyi birden kanıtlar:
#   (a) temiz küme YEŞİL (kapı yanlış-kırmızı vermiyor — insanın onayladığı işi reddetmiyor)
#   (b) her ihlal sınıfı için bilerek bozulmuş bir ekran KIRMIZI ve TAM O KODLA yakalanıyor
# Kapının kendisi bozulursa (b) sessizce yeşile döner — o yüzden kod eşleşmesi aranır.
#
# Koşum:  bash arac/yogunluk-denetle.test.sh ; echo rc=$?
set -u
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAPI="$BURASI/yogunluk-denetle.py"
FIK="$BURASI/fikstur"
GECTI=0; KALDI=0

kayit() { printf '%-28s %s\n' "$1" "$2"; }
gecti() { GECTI=$((GECTI+1)); kayit "$1" "✅ GEÇTİ  $2"; }
kaldi() { KALDI=$((KALDI+1)); kayit "$1" "❌ KALDI  $2"; }

# 1 · temiz küme yeşil olmalı (yanlış-pozitif yok)
cikti="$(python3 "$KAPI" "$FIK/temiz" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then gecti "temiz-kume" "rc=0"
else kaldi "temiz-kume" "rc=$rc — YANLIŞ-KIRMIZI: $(printf '%s' "$cikti" | grep -m1 '·')"; fi

# 2 · her ihlal sınıfı yakalanmalı, hem de kendi koduyla
cikti="$(python3 "$KAPI" "$FIK/kirli" 2>&1)"; rc=$?
[ "$rc" = "1" ] && gecti "kirli-kume-rc" "rc=1" || kaldi "kirli-kume-rc" "rc=$rc (1 olmalı)"
for kod in S1 S2 S3 S4 S5 X1 X2 X3; do
  dosya="$(ls "$FIK/kirli" | grep -m1 "^$kod-")"
  satir="$(printf '%s' "$cikti" | grep -A4 "KIRMIZI  ${dosya%.html}$" | grep -m1 "· $kod")"
  if [ -n "$satir" ]; then gecti "$kod-yakalandi" "${satir#*· }"
  else kaldi "$kod-yakalandi" "${dosya:-fikstür yok} için $kod satırı ÇIKMADI"; fi
done

# 3 · X4 (küme-genelinde yazım çatalı) ayrı kümede
cikti="$(python3 "$KAPI" "$FIK/catal" 2>&1)"
printf '%s' "$cikti" | grep -q '· X4' && gecti "X4-yakalandi" "durum-yazımı çatalı" \
  || kaldi "X4-yakalandi" "çatal kümesinde X4 çıkmadı"

# 4 · profil yoksa RC=2 (varsayılan uydurup yanlış-yeşil VERMEZ)
gecici="$(mktemp -d)"; cp "$FIK/temiz"/*.html "$gecici/"
python3 "$KAPI" "$gecici" >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] && gecti "profilsiz-rc2" "rc=2 çalıştırılamadı" || kaldi "profilsiz-rc2" "rc=$rc (2 olmalı)"
rm -rf "$gecici"

echo "────────────────────────────────────────────"
printf 'TOPLAM: %d geçti · %d kaldı\n' "$GECTI" "$KALDI"
[ "$KALDI" = "0" ] || exit 1
