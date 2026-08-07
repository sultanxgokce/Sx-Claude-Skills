#!/usr/bin/env bash
# havuz.test.sh — havuzun sınavı. Asıl mesele "yazıyor mu" değil,
# ŞEMANIN KAPALI OLDUĞU: içerik taşıyan hiçbir alan içeri sızmamalı.
set -u

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$ARAC/havuz.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
J="$T/havuz.jsonl"
GECTI=0; KALDI=0

kapi() { local ad="$1" bek="$2"; shift 2
  local c r; c="$("$@" 2>&1)"; r=$?
  if [ "$r" = "$bek" ]; then echo "  ✓ $ad (rc=$r)"; GECTI=$((GECTI+1))
  else echo "  ✗ $ad — beklenen rc=$bek, gelen rc=$r"; echo "$c" | sed 's/^/      /'; KALDI=$((KALDI+1)); fi
  SON="$c"; }
icerir() { if printf '%s' "$SON" | grep -qF -- "$2"; then echo "  ✓ $1"; GECTI=$((GECTI+1))
  else echo "  ✗ $1 — çıktıda yok: $2"; KALDI=$((KALDI+1)); fi; }
icermez() { if printf '%s' "$SON" | grep -qF -- "$2"; then echo "  ✗ $1 — çıktıda VAR: $2"; KALDI=$((KALDI+1))
  else echo "  ✓ $1"; GECTI=$((GECTI+1)); fi; }

yaz() { python3 "$H" yaz --havuz "$J" "$@"; }

echo "── 1 · geçerli kayıt yazılır"
kapi "temiz kayıt → rc=0" 0 yaz --kutu akar --urun akar --ekran e1-giris \
     --kapi yogunluk --hukum temiz --arac 0.1.5
kapi "kırmızı kayıt → rc=0" 0 yaz --kutu akar --urun akar --ekran e4-bugun \
     --kapi yogunluk --hukum kirmizi --dusen S2,X1 --arac 0.1.5
icerir "düşen kodlar görünür" "düşen:S2,X1"

echo "── 2 · ŞEMA KAPALI: serbest metin alanı eklenemez"
# Arayüzde "not/gerekce/alinti" diye bir bayrak YOKTUR: bilinmeyen bayrak sessizce
# yok sayılır ve zorunlu alanlar eksik kaldığı için kayıt reddedilir. İçerik, şemada
# yeri olmadığı için havuza giremez — politika değil, yapı.
kapi "serbest metin bayrağı işe yaramaz → rc=1" 1 yaz --not "gizli müşteri notu"
icermez "metin havuza girmedi" "gizli müşteri notu"

echo "── 3 · geçersiz değerler reddedilir (fail-closed)"
kapi "bilinmeyen hüküm → rc=1" 1 yaz --kutu akar --urun akar --ekran e1 \
     --kapi yogunluk --hukum yesil --arac 0.1.5
icerir "sebep söylenir" "hukum desene uymuyor"
kapi "bilinmeyen kapı → rc=1" 1 yaz --kutu akar --urun akar --ekran e1 \
     --kapi tahmin --hukum temiz --arac 0.1.5
kapi "düşen alanına serbest metin → rc=1" 1 yaz --kutu akar --urun akar --ekran e1 \
     --kapi yogunluk --hukum kirmizi --dusen "müşteri adı Ahmet" --arac 0.1.5
icerir "yalnız kod alır denir" "yalnız KOD alır"
kapi "kutu adında boşluk/uzunluk → rc=1" 1 yaz --kutu "gizli müşteri projesi" \
     --urun akar --ekran e1 --kapi yogunluk --hukum temiz --arac 0.1.5

echo "── 4 · reddedilen kayıt dosyaya DÜŞMEZ (yarım yazma yok)"
N="$(wc -l < "$J")"
yaz --kutu akar --urun akar --ekran e1 --kapi yogunluk --hukum yesil --arac 0.1.5 >/dev/null 2>&1
if [ "$(wc -l < "$J")" = "$N" ]; then echo "  ✓ satır sayısı değişmedi ($N)"; GECTI=$((GECTI+1))
else echo "  ✗ reddedilen kayıt yine de yazılmış"; KALDI=$((KALDI+1)); fi

echo "── 5 · okuma ve özet"
kapi "oku → rc=0" 0 python3 "$H" oku --havuz "$J"
icerir "kayıt görünür" "e4-bugun"
kapi "ozet → rc=0" 0 python3 "$H" ozet --havuz "$J"
icerir "en çok düşen kural listelenir" "S2"

echo "── 6 · BOŞ havuz 'temiz' DEĞİL 'bakılmamış' der"
kapi "boş havuz → rc=0" 0 python3 "$H" ozet --havuz "$T/yok.jsonl"
icerir "dürüst dil" "hiç bakılmamış"
icermez "ölçüm yapılmış gibi tablo basmaz" "EN ÇOK DÜŞEN"
icermez "sıfır-ihlal iddiası yok" "Hiçbir kural düşmemiş"

echo "── 7 · bozuk satır okumayı çökertmez, sessizce elenir"
printf 'bu json degil\n{"kutu":"x"}\n' >> "$J"
kapi "bozuk satırlı havuz → rc=0" 0 python3 "$H" oku --havuz "$J"

echo "── 8 · ÇAĞIRAN gerçek: ölçüm anında kayıt kendiliğinden düşer"
mkdir -p "$T/proje/tasarim" "$T/proje/ciktilar"
cp "$ARAC/fikstur/temiz/"*.html "$T/proje/ciktilar/"
cp "$ARAC/fikstur/kapi-profili.json" "$T/proje/"
printf '# dil\nrenk: #123456\n' > "$T/proje/dil.md"
printf '# estetik\nsakin\n' > "$T/proje/est.md"
printf 'x\n> n\n---\n{{ONCEKI_HTML}}\n{{TASARIM_DILI}}\n{{ESTETIK_YON}}\n' > "$T/proje/sablon.md"
ILK="$(ls "$T/proje/ciktilar/"*.html | head -1)"
bash "$ARAC/tik-kaydet.sh" "$ILK" G1=3:2 >/dev/null   # tık kapısı: ölçüm olmadan rc=3
J2="$T/otomatik.jsonl"
kapi "devam promptu → rc=0" 0 env UI_AKIS_HAVUZ="$J2" UI_AKIS_KUTU=akar \
     bash "$ARAC/prompt-yap.sh" "$T/proje/sablon.md" --onceki "$ILK" \
     --dil "$T/proje/dil.md" --estetik "$T/proje/est.md"
if [ -s "$J2" ] && grep -q '"kapi": *"yogunluk"' "$J2"; then
  echo "  ✓ havuza kendiliğinden yazıldı (kimse çağırmadı)"; GECTI=$((GECTI+1))
else echo "  ✗ havuza yazılmadı — çağıran yok demektir"; KALDI=$((KALDI+1)); fi

echo "── 9 · havuz yazılamasa bile prompt üretimi DÜŞMEZ (defter kapı değildir)"
kapi "yazılamaz havuz → yine rc=0" 0 env UI_AKIS_HAVUZ="/olmayan-kok-dizin/h.jsonl" \
     UI_AKIS_KUTU=akar bash "$ARAC/prompt-yap.sh" "$T/proje/sablon.md" --onceki "$ILK" \
     --dil "$T/proje/dil.md" --estetik "$T/proje/est.md"

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
