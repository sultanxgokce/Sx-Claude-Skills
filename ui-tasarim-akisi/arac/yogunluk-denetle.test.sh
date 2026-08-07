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

# 5 · ÇİFT-YÖNLÜ FİKSTÜR: aynı sayfa iki yazımla — biri yeşilde kalmalı, öbürü kırmızı
#     NİÇİN: tek-yönlü fikstür yalnız KATILAŞMAYI yakalar, GEVŞEMEYİ yakalamaz. Yüzey
#     ayrımı bozulursa (panel ayrı yüzey sayılmazsa) yeşil yüz kırmızıya döner; ad-eşleme
#     gevşerse (casefold) kırmızı yüz yeşile döner. İkisi birlikte iki yönü de kilitler.
#     (Öneri: NAKKAŞ + MÜTEVELLİ, 2026-08-07 — ilk uygulaması burası.)
cikti="$(python3 "$KAPI" "$FIK/panel-yesil" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then gecti "cift-yonlu-yesil" "rc=0 — panel ayrı yüzey, iki bütçe de içeride"
else kaldi "cift-yonlu-yesil" "rc=$rc — GEVŞEME/KATILAŞMA: $(printf '%s' "$cikti" | grep -m1 '·')"; fi

cikti="$(python3 "$KAPI" "$FIK/panel-kirmizi" 2>&1)"; rc=$?
[ "$rc" = "1" ] && gecti "cift-yonlu-kirmizi-rc" "rc=1" \
  || kaldi "cift-yonlu-kirmizi-rc" "rc=$rc (1 olmalı) — yanlış yazım cezasız kaldı"
printf '%s' "$cikti" | grep -q 'X2 sözlük-dışı bileşen adı.*Yan Panel' \
  && gecti "cift-yonlu-X2" "yanlış yazım X2 ile yakalandı" \
  || kaldi "cift-yonlu-X2" "X2 çıkmadı — ad eşlemesi gevşemiş olabilir (casefold?)"
printf '%s' "$cikti" | grep -q 'S1\[sayfa\]' \
  && gecti "cift-yonlu-S1" "yüzey açılmadı → bütçeler birleşti (canlı vakanın kendisi)" \
  || kaldi "cift-yonlu-S1" "S1 çıkmadı — yüzey modeli beklenenden farklı davranıyor"

# 6 · BEKÇİ: çekirdek sözleşme ⟂ araç varsayılan sözlüğü tek gerçek olmalı
#     Bu, 5'teki tek vakayı değil SINIFI kapatır: çekirdeğe yeni bir ad eklenip araca
#     eklenmezse (ya da yazımı saparsa) burası kırmızı yanar.
BEKCI="$BURASI/cekirdek-sozluk-denetle.py"
cikti="$(python3 "$BEKCI" 2>&1)"; rc=$?
[ "$rc" = "0" ] && gecti "bekci-hizali" "çekirdeğin her adı araç sözlüğünde" \
  || kaldi "bekci-hizali" "rc=$rc — $(printf '%s' "$cikti" | grep -m1 '·')"

# 6b · NEGATİF KANIT: bekçinin gerçekten kırmızı yandığı kanıtlanır (yoksa bekçi süstür)
gecici="$(mktemp -d)"
sed 's/`Yan panel`/`Yan Panel`/' "$BURASI/../cekirdek/sozlesme.md" > "$gecici/sozlesme.md"
cikti="$(python3 "$BEKCI" --sozlesme "$gecici/sozlesme.md" 2>&1)"; rc=$?
if [ "$rc" = "1" ] && printf '%s' "$cikti" | grep -q 'YALNIZ HARF KASASI'; then
  gecti "bekci-negatif" "bozuk çekirdekte rc=1 + harf-kasası teşhisi"
else kaldi "bekci-negatif" "rc=$rc — bekçi bozuk çekirdeği YAKALAMADI (süs bekçi)"; fi
# 6c · parse edilemeyen çekirdek "temiz" değil ÖLÇÜLEMEDİ'dir
printf '# bos\n' > "$gecici/bos.md"
python3 "$BEKCI" --sozlesme "$gecici/bos.md" >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] && gecti "bekci-rc2" "Ç3 yoksa rc=2 (yanlış-yeşil vermez)" \
  || kaldi "bekci-rc2" "rc=$rc (2 olmalı)"
rm -rf "$gecici"

echo "────────────────────────────────────────────"
printf 'TOPLAM: %d geçti · %d kaldı\n' "$GECTI" "$KALDI"
[ "$KALDI" = "0" ] || exit 1
