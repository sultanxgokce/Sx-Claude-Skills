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

echo "── 6 · BOŞ havuz 'temiz' DEĞİL 'bakılmamış' der — METİN de KOD da"
# Bir çağıran için rc=0 "temiz" demektir. Metin dürüstken kodun 0 dönmesi, sessizliği
# başarı saymanın makine hâliydi (bulan: NAKKAŞ, 2026-08-07). 3 = ÖLÇÜLEMEDİ.
kapi "boş havuz → rc=3 ÖLÇÜLEMEDİ" 3 python3 "$H" ozet --havuz "$T/yok.jsonl"
icerir "dürüst dil" "hiç bakılmamış"
icermez "ölçüm yapılmış gibi tablo basmaz" "EN ÇOK DÜŞEN"
icermez "sıfır-ihlal iddiası yok" "Hiçbir kural düşmemiş"
kapi "kayıt VAR ama o kutuda yok → rc=3" 3 python3 "$H" ozet --havuz "$J" --kutu bosluk

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

echo "── 10 · İPTAL: yanlış satır SİLİNMEDEN geçersiz kılınabilir (salt-ekleme korunur)"
# Canlı vaka (MÜTEVELLİ, 2026-08-07): 4 satır ölçmeden tahminle yazıldı, 2'si yanlış çıktı;
# geri alma yolu olmadığı için özet sonsuza dek yalan söylüyordu.
J3="$T/iptal.jsonl"
ipt() { python3 "$H" iptal --havuz "$J3" "$@"; }
kapi "hedef kayıt yazılır" 0 python3 "$H" yaz --havuz "$J3" --kutu akar --urun akar \
     --ekran e9-yanlis --kapi yogunluk --hukum kirmizi --dusen S1,S2 --arac 0.2.2
KID="$(printf '%s' "$SON" | sed -n 's/^havuz +1 · \([0-9a-f]\{12\}\).*/\1/p')"
kapi "doğru kayıt da yazılır" 0 python3 "$H" yaz --havuz "$J3" --kutu akar --urun akar \
     --ekran e9-dogru --kapi yogunluk --hukum kirmizi --dusen S5 --arac 0.2.2
if [ -n "$KID" ]; then echo "  ✓ oku/yaz kayıt-id basıyor ($KID)"; GECTI=$((GECTI+1))
else echo "  ✗ kayıt-id çıkmadı — iptal çağrılamaz"; KALDI=$((KALDI+1)); fi

kapi "geçersiz sebep REDDEDİLİR (serbest metin yok)" 1 ipt "$KID" --sebep "müşteri istedi"
icerir "kapalı küme söylenir" "kapalı küme"
kapi "bilinmeyen kayıt-id → rc=1" 1 ipt ffffffffffff --sebep tekrar
kapi "geçerli iptal → rc=0" 0 ipt "$KID" --sebep olcmeden-yazildi
icerir "eski satırın durduğu söylenir" "DURUYOR"

kapi "iptal sonrası özet → rc=0" 0 python3 "$H" ozet --havuz "$J3"
icermez "iptal edilen kural sayımdan DÜŞTÜ" "S1  "
icerir "geçerli kayıt sayımda KALDI" "S5"
kapi "oku varsayılan görünüm → rc=0" 0 python3 "$H" oku --havuz "$J3"
icermez "iptal edilen satır varsayılan görünümde yok" "e9-yanlis"
kapi "oku --iptaller-dahil → rc=0" 0 python3 "$H" oku --havuz "$J3" --iptaller-dahil
icerir "geçmiş DURUYOR (salt-ekleme)" "e9-yanlis"
icerir "mezar-taşı görünür" "iptal→"
kapi "aynı kayıt ikinci kez iptal edilmez" 0 ipt "$KID" --sebep tekrar
icerir "ikinci mezar-taşı yazılmadı" "zaten iptal edilmiş"

echo "── 11 · profil_sha: 'ölçüm doğru, referans yanlış' vakasına karşı skalar parmak izi"
kapi "profil_sha ile yazılır → rc=0" 0 python3 "$H" yaz --havuz "$J3" --kutu akar \
     --urun akar --ekran e10 --kapi yogunluk --hukum temiz --arac 0.2.2 \
     --profil-sha 9f2a1c0b7d34
kapi "desene uymayan profil_sha → rc=1" 1 python3 "$H" yaz --havuz "$J3" --kutu akar \
     --urun akar --ekran e10 --kapi yogunluk --hukum temiz --arac 0.2.2 \
     --profil-sha "kapi-profili.json"
icerir "sebep söylenir" "profil_sha desene uymuyor"
kapi "parmak-izsiz ölçüm özette dürüstçe sayılır" 0 python3 "$H" ozet --havuz "$J3"
icerir "eksik parmak-izi bildirilir" "profil parmak-izi YOK"

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
