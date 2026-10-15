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

# ── L57 · sözlük çatalı fazları ───────────────────────────────────────────────
CEK="$BURASI/../cekirdek/sozlesme.md"
MARKA="$FIK/altin/marka-profili.json"

# 7 · F1+F2 ALTIN YÜZ: yalnız ÇEKİRDEK adlarını kullanan ekran, çekirdeğin HİÇBİR adını
#     içermeyen marka profili altında TEMİZ geçmeli. Birleşim (çekirdek ∪ profil) yoksa
#     bu ekran "sessiz icat" ile reddedilir — sözleşmeye uyanı cezalandıran vaka.
#     Aynı satır F3'ün de tek çağıranıdır: --profil <yol> fiilen kullanılıyor.
cikti="$(python3 "$KAPI" "$FIK/altin" --profil "$MARKA" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then gecti "altin-cekirdek-adlari" "rc=0 — çekirdek ∪ profil"
else kaldi "altin-cekirdek-adlari" "rc=$rc — YANLIŞ-KIRMIZI: $(printf '%s' "$cikti" | grep -m1 '·')"; fi

# 7b · ALTIN'ın KIRMIZI İKİZİ: aynı profil, aynı çekirdek adları, TEK fark uydurma ad.
#      Birleşim "her adı kabul et"e dönüşürse burası sessizce yeşile döner.
cikti="$(python3 "$KAPI" "$FIK/birlesim-kirmizi" --profil "$MARKA" 2>&1)"; rc=$?
if [ "$rc" = "1" ] && printf '%s' "$cikti" | grep -q 'X2 sözlük-dışı.*KPI vitrin şeridi'; then
  gecti "birlesim-gevsemedi" "ne çekirdekte ne markada olan ad hâlâ X2"
else kaldi "birlesim-gevsemedi" "rc=$rc — birleşim gevşedi (uydurma ad cezasız)"; fi

# 7c · NEGATİF KANIT: birleşimin TAŞIYICI olduğu kanıtlanır. Çekirdekten `Liste satırı`
#      düşürülürse ALTIN ekranı anında kırmızıya döner — yeşil, birleşim sayesindedir.
gecici="$(mktemp -d)"
sed 's/`Liste satırı` · //' "$CEK" > "$gecici/sozlesme.md"
cikti="$(python3 "$KAPI" "$FIK/altin" --profil "$MARKA" --cekirdek "$gecici/sozlesme.md" 2>&1)"; rc=$?
if [ "$rc" = "1" ] && printf '%s' "$cikti" | grep -q 'X2 sözlük-dışı.*Liste satırı'; then
  gecti "birlesim-tasiyici" "çekirdekten ad düşünce ALTIN kırmızıya döndü"
else kaldi "birlesim-tasiyici" "rc=$rc — ALTIN'ın yeşili çekirdeğe BAĞLI değil (birleşim süs)"; fi

# 7d · çekirdek okunamıyorsa "temiz" değil ÖLÇÜLEMEDİ: profil-yalnız'a sessizce düşmek
#      eski yanlış-KIRMIZI davranışını fark ettirmeden geri getirirdi.
python3 "$KAPI" "$FIK/altin" --profil "$MARKA" --cekirdek "$gecici/yok.md" >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] && gecti "cekirdeksiz-rc2" "rc=2 (yanlış-yeşil/kırmızı vermez)" \
  || kaldi "cekirdeksiz-rc2" "rc=$rc (2 olmalı)"
rm -rf "$gecici"

# 8 · F3: --profil bayrağı. Eski kod bayrağı eliyor ama DEĞERİNİ elemiyordu → konumsal
#     argüman 2 sayılıp rc=2 dönüyordu; ilan edilmiş bayrak ölü yoldu, sınav kapsamı 0'dı.
cikti="$(python3 "$KAPI" "$FIK/altin" "--profil=$MARKA" 2>&1)"; rc=$?
[ "$rc" = "0" ] && gecti "profil-esitli-bicim" "--profil=<yol> rc=0" \
  || kaldi "profil-esitli-bicim" "rc=$rc — =-biçimi çalışmıyor"
python3 "$KAPI" "$FIK/altin" --profil >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] && gecti "profil-degersiz-rc2" "değeri eksik bayrak rc=2 (sessizce yutulmaz)" \
  || kaldi "profil-degersiz-rc2" "rc=$rc (2 olmalı)"

# 9 · F2/G3: becerinin KENDİ fikstür profili çekirdeği kapsamalı. Kapsamazsa 140 sınavın
#     hiçbiri öz-tutarsızlığı görmez (bekçi yalnız ORNEK_PROFIL'e bakar).
eksik="$(python3 - "$FIK/kapi-profili.json" "$CEK" <<'PY'
import json, sys
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(sys.argv[0])))
import importlib.util, os
b = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), "..", "cekirdek-sozluk-denetle.py")
spec = importlib.util.spec_from_file_location("_b", b)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
kume = set(json.load(open(sys.argv[1], encoding="utf-8"))["sozluk"])
print(", ".join(a for a in m.cekirdek_adlari(sys.argv[2]) if a not in kume))
PY
)"
[ -z "$eksik" ] && gecti "fikstur-profili-hizali" "çekirdeğin her adı fikstür profilinde" \
  || kaldi "fikstur-profili-hizali" "fikstür profilinde eksik: $eksik"

# 10 · F4/G4 ROL — ÇİFT YÖNLÜ: aynı bayt, iki profil, tek fark rol_adlari.
cikti="$(python3 "$KAPI" "$FIK/rol" --profil "$FIK/rol/rol-profili.json" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then gecti "rol-yesil" "rc=0 — panel/vitrin/gezinme profilden türedi"
else kaldi "rol-yesil" "rc=$rc — kutunun kendi yazımı hâlâ tanınmıyor: $(printf '%s' "$cikti" | grep -m1 '·')"; fi

cikti="$(python3 "$KAPI" "$FIK/rol" --profil "$FIK/rol/rol-yalin-profili.json" 2>&1)"; rc=$?
[ "$rc" = "1" ] && gecti "rol-kirmizi-rc" "rc=1" \
  || kaldi "rol-kirmizi-rc" "rc=$rc (1 olmalı) — rol_adlari'sız profil cezasız kaldı"
printf '%s' "$cikti" | grep -q 'S1\[sayfa\]' \
  && gecti "rol-kirmizi-yuzey" "panel rolü yok → yüzey açılmadı, bütçeler birleşti" \
  || kaldi "rol-kirmizi-yuzey" "S1 çıkmadı — panel rolü hâlâ koda gömülü olabilir"
printf '%s' "$cikti" | grep -q 'X1 gezinme' \
  && gecti "rol-kirmizi-gezinme" "gezinme rolü yok → X1" \
  || kaldi "rol-kirmizi-gezinme" "X1 çıkmadı — gezinme rolü profilden türemiyor"
printf '%s' "$cikti" | grep -q 'X2 sözlük-dışı.*OrnekDurumlar' \
  && gecti "rol-kirmizi-vitrin" "vitrin rolü yok → muafiyet düştü" \
  || kaldi "rol-kirmizi-vitrin" "vitrin muafiyeti hâlâ koda gömülü ada bağlı"

# 10b · rol_adlari'nda bilinmeyen rol sessizce yutulmamalı (yazım hatası = ölçülmemiş rol)
gecici="$(mktemp -d)"
python3 -c 'import json,sys
P=json.load(open(sys.argv[1]));P["rol_adlari"]={"panelll":"X"}
json.dump(P,open(sys.argv[2],"w"),ensure_ascii=False)' "$MARKA" "$gecici/p.json"
python3 "$KAPI" "$FIK/altin" --profil "$gecici/p.json" >/dev/null 2>&1; rc=$?
[ "$rc" = "2" ] && gecti "rol-bilinmeyen-rc2" "bilinmeyen rol adı rc=2" \
  || kaldi "rol-bilinmeyen-rc2" "rc=$rc (2 olmalı) — yazım hatası sessizce yutuldu"
rm -rf "$gecici"

# 11 · F4/G5 SAHTE-YEŞİL: blok_turu anahtarı sözlükte yoksa hiçbir işareti tutamaz →
#      S2 bütçesi hiç ölçülmez ve eski kod buna "temiz" derdi (`if tur:` sessiz atlama).
cikti="$(python3 "$KAPI" "$FIK/temiz" --profil "$FIK/g5-oksuz-profil.json" 2>&1)"; rc=$?
if [ "$rc" = "2" ] && printf '%s' "$cikti" | grep -q 'sahte-yeşil'; then
  gecti "g5-oksuz-blok-rc2" "öksüz blok_turu anahtarı rc=2 + teşhis"
else kaldi "g5-oksuz-blok-rc2" "rc=$rc — sessiz atlama sürüyor (yanlış-YEŞİL)"; fi

# 11b · G5 YEŞİL YÜZ: anahtarlar tutuyorsa uyarı ÇIKMAMALI (uyarı gürültüye dönerse
#       kimse okumaz — çift yön burada da gerekli).
cikti="$(python3 "$KAPI" "$FIK/temiz" 2>&1)"; rc=$?
if [ "$rc" = "0" ] && ! printf '%s' "$cikti" | grep -q 'blok_turu haritası'; then
  gecti "g5-tutan-harita" "eşleşen harita → uyarı yok, rc=0"
else kaldi "g5-tutan-harita" "rc=$rc — tutan haritada yanlış uyarı/kırmızı"; fi

# 11c · G5 UYARI YÜZÜ: harita geçerli ama kümede HİÇ tutmuyorsa S2 ölçülmemiştir; kapı
#       bunu 'temiz' derken susmamalı. (ALTIN kümesi çekirdek-yalın → blok adı yok.)
cikti="$(python3 "$KAPI" "$FIK/altin" --profil "$MARKA" 2>&1)"
printf '%s' "$cikti" | grep -q 'blok_turu haritası bu kümede HİÇ tutmadı' \
  && gecti "g5-olcumsuz-uyari" "ölçülmemiş S2 sessiz kalmıyor" \
  || kaldi "g5-olcumsuz-uyari" "uyarı çıkmadı — 'temiz' ölçülmemişi kapsıyor gibi görünüyor"

# 12 · L57-EK · SIFIRLA BİTEN PUNTO — çift yönlü (NAKKAŞ ölçtü 2026-08-07)
#      Eski normalizasyon (`rstrip("0")`) tam sayının sıfırını da yiyordu: 20→2 · 10→1 · 100→1.
#      Sonu sıfırla biten HER punto sahte-kırmızı alıyordu; 172 sınavın hiçbiri görmedi çünkü
#      tüm fikstür profilleri 12.5/14.5/16.5/21/25 idi — hiçbiri sıfırla bitmiyor. Bu kör-nokta
#      HUZUR'un ölçeğinde (12/14/16/20) patladı: 5 ekranda 5 sahte ihlal, göçürme bloke.
#      ALTIN yüz: sıfırla biten punto küme-İÇİNDE → YEŞİL kalmalı (kırpma tam sayıyı yerse kırmızıya döner).
#      KIRMIZI yüz: sıfırla biten punto küme-DIŞI → S5 ile düşmeli (kırpma iki yanı da yerse yeşile döner).
cikti="$(python3 "$KAPI" "$FIK/punto/yesil" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then gecti "punto-sifirsonu-altin" "rc=0 — 20/12/14/16 küme içinde, sahte-kırmızı yok"
else kaldi "punto-sifirsonu-altin" "rc=$rc — SAHTE-KIRMIZI geri geldi: $(printf '%s' "$cikti" | grep -m1 'S5')"; fi

cikti="$(python3 "$KAPI" "$FIK/punto/kirmizi" 2>&1)"; rc=$?
if [ "$rc" = "1" ] && printf '%s' "$cikti" | grep -q 'S5 font-kademe küme-dışı: 30px'; then
  gecti "punto-sifirsonu-kirmizi" "küme-dışı 30px S5 ile yakalandı"
else kaldi "punto-sifirsonu-kirmizi" "rc=$rc — küme-dışı punto cezasız kaldı (normalizasyon gevşemiş)"; fi

# 13 · İÇ-İÇE sc-if — huzur ölçtü 2026-08-10, üretim hattı durmuştu.
#      Aralık eşlemesi her açılış için İLK kapanışı alıyordu: iç-içe sc-if'te DIŞ aralık
#      İÇ etiketin kapanışında bitmiş sayılıyor, aradaki öğeler "koşulsuz" görünüp bütçeye
#      yazılıyordu. Sonuç: sahte-kırmızı → prompt-yap.sh --onceki hiç prompt üretemiyordu.
#      Fikstür bilerek 3 blok-türü taşır ve üçüncüsü dış sc-if'in İÇİNDE, iç sc-if'in SONRASINDA.
cikti="$(python3 "$KAPI" "$FIK/scif-ic-ice" --profil "$FIK/kapi-profili.json" 2>&1)"; rc=$?
if [ "$rc" = "0" ] && printf '%s' "$cikti" | grep -q 'koşullu dallarla 3 tür'; then
  gecti "scif-ic-ice-yesil" "iç-içe sc-if: koşullu sayıldı, sahte-kırmızı yok"
else kaldi "scif-ic-ice-yesil" "rc=$rc — iç-içe sc-if yine sahte-kırmızı: $(printf '%s' "$cikti" | grep -m1 'S2')"; fi

# 13b · Aynı onarımın birim yüzü: kardeş/kapanmamış hâller bozulmadı mı (aşırı-düzeltme freni).
python3 - "$KAPI" <<'PYEOF' && gecti "scif-aralik-birim" "kardeş + kapanmamış aralıklar korundu" \
  || kaldi "scif-aralik-birim" "aralık eşlemesi kardeş/kapanmamış hâlde bozuldu"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("y", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
ic = "A<sc-if a>B<sc-if b>C</sc-if>D</sc-if>E"
kardes = "A<sc-if a>C</sc-if>D<sc-if b>E</sc-if>"
acik = "A<sc-if a>C"
assert m.kapsayan(ic.index("D"), m.araliklar(ic, "sc-if")) is not None, "iç-içe: dış aralık kayıp"
assert m.kapsayan(ic.index("E"), m.araliklar(ic, "sc-if")) is None, "iç-içe: dış aralık taştı"
assert m.kapsayan(kardes.index("D"), m.araliklar(kardes, "sc-if")) is None, "kardeş: araya taştı"
assert m.kapsayan(acik.index("C"), m.araliklar(acik, "sc-if")) is not None, "kapanmamış: açık uç kayıp"
PYEOF

# 14 · F5 KAPISI — KURAL DEĞİŞİKLİĞİ KANITSIZ SÜRÜM ALAMAZ (Sultan-kararı 2026-08-24)
# Niçin: S5 kapısının "sonu 0 olan font kademesinde kırılması" kuralın kendi hatasıydı; o vaka
# ancak bir fikstür ÇİFTİ (kırmızı + yeşil) yazıldığında kapandı. Kural sonradan yazmak bedava;
# bu yüzden kanıt kuralın kendisiyle aynı anda istenir. Yeni bir kural kodu (ör. S6) eklenip
# fikstürü yazılmazsa bu kapı KIRMIZI döner — beyan değil, sayım.
kodlar="$(grep -oE '(ihlaller|notlar)\.append\("[SX][0-9]' "$KAPI" \
          | grep -oE '[SX][0-9]' | sort -u)"
eksik=""
for kod in $kodlar; do
  if ! ls "$FIK/kirli/$kod"-*.html >/dev/null 2>&1; then eksik="$eksik $kod"; fi
done
if [ -z "$eksik" ]; then
  gecti "f5-fikstur-cifti" "$(printf '%s' "$kodlar" | wc -w) kural kodunun hepsinde kırmızı fikstür var"
else
  kaldi "f5-fikstur-cifti" "kanıtsız kural kodu:$eksik (fikstur/kirli/<KOD>-*.html yaz)"
fi
# Çiftin yeşil yarısı: temiz küme zaten §1'de rc=0 veriyor; ikisi birlikte ÇİFT eder.
if ls "$FIK/temiz/"*.html >/dev/null 2>&1; then
  gecti "f5-yesil-yari" "çiftin yeşil yarısı mevcut (fikstur/temiz)"
else
  kaldi "f5-yesil-yari" "yeşil fikstür yok — çift yarım, kanıt sayılmaz"
fi

echo "────────────────────────────────────────────"
printf 'TOPLAM: %d geçti · %d kaldı\n' "$GECTI" "$KALDI"
[ "$KALDI" = "0" ] || exit 1
