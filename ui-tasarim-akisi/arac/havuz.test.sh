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

echo "── 12 · ders: kutunun kendi defterine opak işaretçi (F2 · L40-kalem-4)"
J4="$T/ders.jsonl"
kapi "serbest metin ders → rc=1 (İ1 kalkanı)" 1 python3 "$H" yaz --havuz "$J4" \
     --kutu akar --urun akar --ekran e11 --kapi yogunluk --hukum kirmizi \
     --dusen S1 --arac 0.3.1 --ders "bu uzun bir gerekçe metni"
icerir "sebep söylenir" "ders desene uymuyor"
kapi "s0000 biçimli ders → rc=0" 0 python3 "$H" yaz --havuz "$J4" \
     --kutu akar --urun akar --ekran e11 --kapi yogunluk --hukum kirmizi \
     --dusen S1 --arac 0.3.1 --ders s0251
kapi "gerekçesiz kırmızı da yazılabilir (ders opsiyonel)" 0 python3 "$H" yaz --havuz "$J4" \
     --kutu akar --urun akar --ekran e12 --kapi yogunluk --hukum kirmizi --dusen S2 --arac 0.3.1
kapi "ders alanlı özet → rc=0" 0 python3 "$H" ozet --havuz "$J4"
icerir "gerekçesi olan kırmızı sayılır" "gerekçesi olan kırmızı: 1/2"

echo "── 13 · dusen_karar: kural mı zayıf tasarım mı zayıf (F4 · L40-kalem-4)"
J5="$T/karar.jsonl"
kapi "enum-dışı dusen_karar → rc=1 (kapalı küme)" 1 python3 "$H" yaz --havuz "$J5" \
     --kutu akar --urun akar --ekran e13 --kapi yogunluk --hukum temiz \
     --dusen S1 --arac 0.3.1 --dusen-karar "belki-oyle-belki-boyle"
icerir "sebep söylenir" "dusen_karar desene uymuyor"
kapi "kural-hatali yargısı → rc=0" 0 python3 "$H" yaz --havuz "$J5" \
     --kutu akar --urun akar --ekran e13 --kapi yogunluk --hukum temiz \
     --dusen S1 --arac 0.3.1 --dusen-karar kural-hatali
kapi "tasarim-duzeltildi yargısı → rc=0" 0 python3 "$H" yaz --havuz "$J5" \
     --kutu akar --urun akar --ekran e14 --kapi yogunluk --hukum temiz \
     --dusen S1 --arac 0.3.1 --dusen-karar tasarim-duzeltildi
kapi "ikinci tasarim-duzeltildi" 0 python3 "$H" yaz --havuz "$J5" \
     --kutu akar --urun akar --ekran e15 --kapi yogunluk --hukum temiz \
     --dusen S1 --arac 0.3.1 --dusen-karar tasarim-duzeltildi
kapi "yargı-dağılımlı özet → rc=0" 0 python3 "$H" ozet --havuz "$J5"
icerir "kural NAKKAŞ'ın sorusuna cevap verir" "S1   3  (2 tasarim-duzeltildi · 1 kural-hatali)"

echo "── 14 · GEREKÇE: kırmızıya sonradan ders bağlanır (salt-ekleme, hedefe dokunulmaz)"
J6="$T/f3.jsonl"
kapi "e20 kırmızı yazılır (gerekçesiz)" 0 python3 "$H" yaz --havuz "$J6" \
     --kutu akar --urun akar --ekran e20 --kapi yogunluk --hukum kirmizi --dusen S3 --arac 0.3.1
GID="$(printf '%s' "$SON" | sed -n 's/^havuz +1 · \([0-9a-f]\{12\}\).*/\1/p')"
kapi "ÖLÇÜM KAYBOLMAZ: gerekçesiz kırmızıya rağmen yazma sürer" 0 python3 "$H" yaz \
     --havuz "$J6" --kutu akar --urun akar --ekran e22 --kapi yogunluk \
     --hukum kirmizi --dusen S3 --arac 0.3.1
kapi "boş gerekçe reddedilir → rc=2" 2 python3 "$H" gerekce --havuz "$J6" "$GID"
icerir "boş gerekçe gerekçe değil" "boş gerekçe"
kapi "bilinmeyen hedef → rc=1" 1 python3 "$H" gerekce --havuz "$J6" ffffffffffff \
     --dusen-karar kural-hatali
kapi "geçerli gerekçe bağlanır → rc=0" 0 python3 "$H" gerekce --havuz "$J6" "$GID" \
     --ders s0300 --dusen-karar kural-hatali
icerir "hedef bildirilir" "gerekçe bağlandı"
kapi "gerekçeli özet → rc=0" 0 python3 "$H" ozet --havuz "$J6"
icerir "gerekçe satırı ÖLÇÜM sayılmaz (2 kırmızı, 1'i gerekçeli)" "gerekçesi olan kırmızı: 1/2"

echo "── 15 · F3 KAPISI: sorulur, yazma yolunu kilitlemez (Sultan-kararı 2026-08-24)"
J7="$T/kapi.jsonl"
kapi "hiç kayıt yoksa kapı AÇIK → rc=0" 0 python3 "$H" gerekce-kapisi --havuz "$J7" \
     --kutu akar --urun akar --ekran e30 --kapi yogunluk
kapi "eksik argüman → rc=2" 2 python3 "$H" gerekce-kapisi --havuz "$J7" --kutu akar
python3 "$H" yaz --havuz "$J7" --kutu akar --urun akar --ekran e30 --kapi yogunluk \
     --hukum kirmizi --dusen S3 --arac 0.3.1 >/dev/null
KID2="$(python3 "$H" oku --havuz "$J7" | head -1 | cut -d' ' -f1)"
kapi "gerekçesiz kırmızıdan sonra kapı KAPALI → rc=1" 1 python3 "$H" gerekce-kapisi \
     --havuz "$J7" --kutu akar --urun akar --ekran e30 --kapi yogunluk
icerir "reçete verilir" "havuz.py gerekce"
kapi "BAŞKA ekran etkilenmez (grup bazlı) → rc=0" 0 python3 "$H" gerekce-kapisi \
     --havuz "$J7" --kutu akar --urun akar --ekran e31 --kapi yogunluk
python3 "$H" gerekce --havuz "$J7" "$KID2" --dusen-karar tasarim-duzeltildi >/dev/null
kapi "gerekçe bağlanınca kapı AÇILIR → rc=0" 0 python3 "$H" gerekce-kapisi \
     --havuz "$J7" --kutu akar --urun akar --ekran e30 --kapi yogunluk
kapi "temiz hükümden sonra kapı AÇIK → rc=0" 0 python3 "$H" gerekce-kapisi \
     --havuz "$J7" --kutu akar --urun akar --ekran e32 --kapi yogunluk

echo "── 16 · ÇAĞIRAN GERÇEK Mİ: kapı prompt-yap.sh'te fiilen duruyor mu?"
# Bu bloğun niçini: kapı önce havuz.py'nin YAZMA yoluna konmuştu — ama prompt-yap.sh
# havuz hatalarını tek satırlık uyarıya yutuyor, yani kapı orada GÖRÜNMEZDİ. "Kural var,
# kapıda koşmuyor" hastalığının ta kendisi. Aşağısı kapının GERÇEK çağırandaki etkisini ölçer.
J8="$T/cagiran.jsonl"
_EKAD="$(basename "$ILK")"; _EKAD="$(printf '%s' "${_EKAD%.*}" | tr 'A-Z' 'a-z')"
python3 "$H" yaz --havuz "$J8" --kutu akar --urun akar --ekran "$_EKAD" \
     --kapi yogunluk --hukum kirmizi --dusen S3 --arac 0.3.1 >/dev/null 2>&1
kapi "gerekçesiz kırmızıdan sonra devam promptu ÜRETİLMEZ → rc=1" 1 \
     env UI_AKIS_HAVUZ="$J8" UI_AKIS_KUTU=akar bash "$ARAC/prompt-yap.sh" \
     "$T/proje/sablon.md" --onceki "$ILK" --dil "$T/proje/dil.md" --estetik "$T/proje/est.md"
icerir "sebep Sultan-dilinde söylenir" "önceki tur KIRMIZI ve gerekçesiz"
KID3="$(python3 "$H" oku --havuz "$J8" 2>/dev/null | head -1 | cut -d' ' -f1)"
python3 "$H" gerekce --havuz "$J8" "$KID3" --dusen-karar tasarim-duzeltildi >/dev/null 2>&1
kapi "gerekçe bağlanınca devam promptu ÜRETİLİR → rc=0" 0 \
     env UI_AKIS_HAVUZ="$J8" UI_AKIS_KUTU=akar bash "$ARAC/prompt-yap.sh" \
     "$T/proje/sablon.md" --onceki "$ILK" --dil "$T/proje/dil.md" --estetik "$T/proje/est.md"
kapi "kaçış yolu açık ama sessiz değil (UI_AKIS_GEREKCE_KAPISI=0)" 0 \
     env UI_AKIS_HAVUZ="$T/kacis.jsonl" UI_AKIS_KUTU=akar UI_AKIS_GEREKCE_KAPISI=0 \
     bash "$ARAC/prompt-yap.sh" "$T/proje/sablon.md" --onceki "$ILK" \
     --dil "$T/proje/dil.md" --estetik "$T/proje/est.md"

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
