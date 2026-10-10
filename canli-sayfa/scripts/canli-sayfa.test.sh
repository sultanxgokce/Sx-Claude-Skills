#!/usr/bin/env bash
# canli-sayfa.test.sh — canlı sayfa kaydının sınavı. Hermetik: sahte kayıt dizini, sahte ölçer.
# Gerçek kayda ve ağa DOKUNMAZ. CANLI_SAYFA_TEST_SUT ile başka bir kopya sınanabilir (mutasyon kanıtı için).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SUT="${CANLI_SAYFA_TEST_SUT:-$HERE/canli-sayfa.sh}"
T="$(mktemp -d /tmp/canli-sayfa-sinav.XXXXXX)"; trap 'find "$T" -delete' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✓ $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
esit() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (beklenen '$2' · gelen '$3')"; fi; }
icerir() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else no "$1 (yok: $3)"; fi; }
icermez() { if printf '%s' "$2" | grep -qF -- "$3"; then no "$1 (var: $3)"; else ok "$1"; fi; }

KAPI='https://ekip.cloudflareaccess.com/cdn-cgi/access/login/x'
kur() {
  find "$T" -mindepth 1 -delete; D="$T/kayit"
  cat > "$T/cevaplar" <<C
https://bulgu.ornek.com 302 $KAPI
https://fikir.ornek.com 302 $KAPI
https://acik.ornek.com 200
https://acik.ornek.com/akar 200
https://kilitli.ornek.com 401
https://baska.ornek.com 301 https://baska-yer.ornek.com/
https://yok.ornek.com 404
https://bozuk.ornek.com 502
https://yonsuz.ornek.com 302
https://karne.ornek.com 200
https://gercek-acik.ornek.com 200
https://govdesiz.ornek.com 200
C
  cat > "$T/olcer.sh" <<'O'
s="$(grep -m1 "^$1 " "$(dirname "$0")/cevaplar")" || { echo "000"; exit 0; }
echo "${s#* }"
O
  # sahte gövde (1.2): karne = betikle yüklenen korumalı sayfanın anonim kabuğu (içerik yok) · gercek-acik = içerik anonimde de var · govdesiz = okunamıyor
  cat > "$T/govde.sh" <<'G'
case "$1" in
  https://karne.ornek.com) printf '<!doctype html><html><head><title>Claude Artifact</title></head><body><div id="root"></div><script src="/app.js"></script></body></html>' ;;
  https://gercek-acik.ornek.com) printf '<html><head><title>Karne Raporu</title></head><body><h1>Karne Raporu</h1><p>MÜCESSEM · 12 ölçüm</p></body></html>' ;;
  *) exit 7 ;;
esac
G
}
# her çağrı 20 saniyeyle sınırlı: asılı kalan araç sınavı kilitlemez, rc 124 ile kırmızı olur
cag() { CIKTI="$(CANLI_SAYFA_DIZIN="$D" CANLI_SAYFA_OLCER="bash $T/olcer.sh" CANLI_SAYFA_GOVDE="bash $T/govde.sh" timeout 20 bash "$SUT" "$@" 2>&1)"; RC=$?; }
ekle() { cag ekle --adres "$1" --ad "${2:-Bulgu Defteri}" --ne "${3:-Kutulardan gelen bulguların tek listesi}" --kutu "${4:-merkez}" --ekleyen "${5:-SERDAR}" "${@:6}"; }
say() { find "$D" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l; }
alan() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get(sys.argv[2],""))' "$1" "$2"; }

echo "== T1: kapı arkasındaki canlı sayfa kayda girer =="
kur; ekle https://bulgu.ornek.com
esit "rc 0" 0 "$RC"
esit "kayıt dosyası oluştu" 1 "$(say)"
esit "giriş kapalı yazıldı" kapali "$(alan "$D/bulgu.ornek.com.json" giris)"
esit "durum canlı" canli "$(alan "$D/bulgu.ornek.com.json" durum)"
esit "kutu yazıldı" merkez "$(alan "$D/bulgu.ornek.com.json" kutu)"
icerir "kayda girdiğini söylüyor" "$CIKTI" "✓ kayda girdi: Bulgu Defteri"
icermez "kurulmamış bir yüzey hakkında söz vermiyor" "$CIKTI" "menü"
cag liste; esit "liste rc 0" 0 "$RC"
icerir "listede adı var" "$CIKTI" "Bulgu Defteri"
icerir "listede adresi var" "$CIKTI" "https://bulgu.ornek.com"
icerir "listede kapı bilgisi var" "$CIKTI" "kapı arkasında"
icerir "sayı doğru" "$CIKTI" "── 1 sayfa"
cag liste --json
esit "json okunuyor ve bir sayfa taşıyor" 1 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')"

echo "== T2: canlı olmayan ya da ölçülemeyen sayfa KAYDEDİLMEZ =="
for a in https://yok.ornek.com https://bozuk.ornek.com https://hic-yok.ornek.com https://yonsuz.ornek.com; do
  kur; ekle "$a"
  esit "$a → rc 3" 3 "$RC"
  esit "$a → kayıt yok" 0 "$(say)"
done
kur; CIKTI="$(CANLI_SAYFA_DIZIN="$D" CANLI_SAYFA_OLCER="false" bash "$SUT" ekle --adres https://bulgu.ornek.com --ad "Bulgu" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR 2>&1)"; RC=$?
esit "ölçer hiç cevap vermiyor → rc 3" 3 "$RC"
esit "kayıt yok" 0 "$(say)"

echo "== T3: kapısız açılan sayfa onaysız kayda girmez =="
kur; ekle https://acik.ornek.com "Tanıtım Sayfası" "Herkesin görebildiği tanıtım sayfası"
esit "onaysız → rc 4" 4 "$RC"
esit "kayıt yok" 0 "$(say)"
icerir "sebebi söylüyor" "$CIKTI" "GİRİŞ KAPISI OLMADAN"
ekle https://acik.ornek.com "Tanıtım Sayfası" "Herkesin görebildiği tanıtım sayfası" merkez SERDAR --herkese-acik evet
esit "onaylı → rc 0" 0 "$RC"
esit "giriş açık yazıldı" acik "$(alan "$D/acik.ornek.com.json" giris)"
cag liste; icerir "listede herkese açık diye görünüyor" "$CIKTI" "HERKESE AÇIK"
kur; ekle https://acik.ornek.com "Tanıtım Sayfası" "Herkesin görebildiği tanıtım sayfası" merkez SERDAR --herkese-acik hayir
esit "onay 'evet' değilse → rc 4" 4 "$RC"
kur; ekle https://bulgu.ornek.com "Bulgu Defteri" "Bulguların listesi" merkez SERDAR --herkese-acik evet
esit "kapalı sayfada onay bayrağı kapıyı değiştirmez" kapali "$(alan "$D/bulgu.ornek.com.json" giris)"

echo "== T3b (1.2, A314): 200 dönen ama GÖVDESİ KORUMALI sayfa — üçüncü SARI hâl: ne kapalı ne açık, yanlış beyan gerekmez =="
kur; ekle https://karne.ornek.com "Karne Sayfası" "Ajan karnelerinin canlı sayfası" tellal MUCESSEM --imza "Karne Raporu"
esit "gövde korumalı + imza → rc 5 (kayıt var, giriş ÖLÇÜLEMEDİ — yeşil değil)" 5 "$RC"
esit "kayıt oluştu (kayıtsız canlı sayfa ihlaldir)" 1 "$(say)"
esit "giriş olculemedi (kapali DEĞİL, acik DEĞİL)" olculemedi "$(alan "$D/karne.ornek.com.json" giris)"
esit "ölçü gövde" govde "$(alan "$D/karne.ornek.com.json" giris_olcu)"
esit "imza kayda yazıldı" "Karne Raporu" "$(alan "$D/karne.ornek.com.json" imza)"
icerir "SARI olduğunu söyler" "$CIKTI" "ÖLÇÜLEMEDİ (SARI)"; icerir "kapalı sayılmaz der" "$CIKTI" "'kapalı' sayılmaz"
icermez "yeşil tik basmıyor" "$CIKTI" "✓ kayda girdi"
cag liste; icerir "listede sarı hâl görünür" "$CIKTI" "GİRİŞ ÖLÇÜLEMEDİ (sarı: gövde korumalı, kapı bilinmiyor) · gövdeden ölçüldü"
icermez "listede kapı arkasında demiyor" "$CIKTI" "kapı arkasında"
cag dogrula; esit "dogrula aynı imzayla yeniden ölçer → hâlâ sarı → rc 5 (yeşil değil)" 5 "$RC"
icerir "sarı satır" "$CIKTI" "△ ÖLÇÜLEMEDİ  Karne Sayfası"; icermez "yeşil tik yok" "$CIKTI" "✓ Karne Sayfası"; icerir "özet sarı sayar" "$CIKTI" "1 sarı (giriş ölçülemedi)"
# gövde değişip imza anonimde görünür olursa KAPI DEĞİŞTİ (artık gerçekten açık)
sed -i 's|https://karne.ornek.com) printf .*|https://karne.ornek.com) printf "<title>Karne Raporu</title>" ;;|' "$T/govde.sh"
cag dogrula; esit "imza anonimde göründü → rc 1" 1 "$RC"; icerir "kapı değişti yazar" "$CIKTI" "KAPI DEĞİŞTİ"
kur; ekle https://karne.ornek.com "Karne Sayfası" "Ajan karnelerinin canlı sayfası" tellal MUCESSEM
esit "imzasız: eski kural, 2xx = açık → rc 4" 4 "$RC"; esit "kayıt yok" 0 "$(say)"
icerir "imza yolunu söylüyor" "$CIKTI" "--imza"
kur; ekle https://gercek-acik.ornek.com "Tanıtım Sayfası" "Herkesin görebildiği tanıtım sayfası" merkez SERDAR --imza "Karne Raporu"
esit "imza anonim gövdede VAR → gerçekten açık → onaysız rc 4" 4 "$RC"; esit "kayıt yok" 0 "$(say)"
kur; ekle https://gercek-acik.ornek.com "Tanıtım Sayfası" "Herkesin görebildiği tanıtım sayfası" merkez SERDAR --imza "Karne Raporu" --herkese-acik evet
esit "onayla → rc 0" 0 "$RC"; esit "giriş açık" acik "$(alan "$D/gercek-acik.ornek.com.json" giris)"; esit "ölçü gövde" govde "$(alan "$D/gercek-acik.ornek.com.json" giris_olcu)"
kur; ekle https://govdesiz.ornek.com "Karne Sayfası" "Ajan karnelerinin canlı sayfası" tellal MUCESSEM --imza "Karne Raporu"
esit "gövde okunamıyor → ölçülemedi rc 3 (kapalı DENMEZ)" 3 "$RC"; esit "kayıt yok" 0 "$(say)"; icerir "sebep" "$CIKTI" "govde-okunamadi"
kur; ekle https://karne.ornek.com "Karne Sayfası" "Ajan karnelerinin canlı sayfası" tellal MUCESSEM --imza "ab"
esit "imza çok kısa → rc 2" 2 "$RC"
kur; ekle https://karne.ornek.com "Karne Sayfası" "Ajan karnelerinin canlı sayfası" tellal MUCESSEM --imza "token=abcdefghijklmnop"
esit "imza sır deseni → rc 2" 2 "$RC"; icermez "değer basılmadı" "$CIKTI" "abcdefghijklmnop"
kur; cag ekle --adres https://karne.ornek.com --ad "Karne" --ne "Karne sayfası" --kutu tellal --ekleyen MUCESSEM --imza
esit "--imza değersiz → rc 2" 2 "$RC"

echo "== T4: kendi kilidi olan ve başka yere yönlenen sayfa =="
kur; ekle https://kilitli.ornek.com "Kilitli Sayfa" "Kendi parolasıyla açılan sayfa"
esit "401 → kapalı" kapali "$(alan "$D/kilitli.ornek.com.json" giris)"
ekle https://baska.ornek.com "Yönlenen Sayfa" "Başka adrese yönlenen sayfa"
esit "başka yere yönlenme → yönleniyor" yonleniyor "$(alan "$D/baska.ornek.com.json" giris)"

echo "== T5: adres kuralları =="
for a in http://bulgu.ornek.com "https://bulgu.ornek.com/?anahtar=1" "https://bulgu.ornek.com/#x" https://kim:parola@bulgu.ornek.com \
         https://bulgu.ornek.com:8443 https://bulgu "https://bulgu.ornek.com/a b" "https://bulgu.ornek.com/../x" bulgu.ornek.com ""; do
  kur; ekle "$a"
  esit "kurala uymayan adres '$a' → rc 2" 2 "$RC"
  esit "kayıt yok" 0 "$(say)"
done
kur; ekle "https://BULGU.ornek.com/"
esit "büyük harf ve sondaki eğik çizgi düzeltilir → rc 0" 0 "$RC"
esit "düzeltilmiş adres yazıldı" https://bulgu.ornek.com "$(alan "$D/bulgu.ornek.com.json" adres)"
ekle https://acik.ornek.com/akar "Akar Tanıtım" "Kira yönetimi tanıtım sayfası" akar MUTEVELLI --herkese-acik evet
esit "yollu adres ayrı kayıt" 2 "$(say)"
esit "yollu adres olduğu gibi" https://acik.ornek.com/akar "$(alan "$D/acik.ornek.com%2Fakar.json" adres)"
# iki ayrı adres aynı dosyaya düşemez: /a/b ile /a_b
kur; printf '%s\n' "https://acik.ornek.com/a/b 200" "https://acik.ornek.com/a_b 200" >> "$T/cevaplar"
ekle https://acik.ornek.com/a/b "Birinci Sayfa" "Eğik çizgili adresteki sayfa" merkez SERDAR --herkese-acik evet
ekle https://acik.ornek.com/a_b "İkinci Sayfa" "Alt çizgili adresteki sayfa" merkez SERDAR --herkese-acik evet
esit "iki ayrı kayıt dosyası" 2 "$(say)"
cag liste; icerir "birinci sayfa kayıtta duruyor" "$CIKTI" "Birinci Sayfa"; icerir "ikinci sayfa kayıtta duruyor" "$CIKTI" "İkinci Sayfa"
# dosya adında başka adresin kaydı duruyorsa (elle konmuş) üzerine yazılmaz
kur; ekle https://bulgu.ornek.com; ekle https://fikir.ornek.com "Fikir Defteri" "Yeni iş fikirlerinin defteri" mihenk MIHENK
cp "$D/fikir.ornek.com.json" "$D/bulgu.ornek.com.json"; ekle https://bulgu.ornek.com
esit "başka adresin kaydının üzerine yazılmaz → rc 3" 3 "$RC"
esit "o dosyadaki kayıt olduğu gibi" https://fikir.ornek.com "$(alan "$D/bulgu.ornek.com.json" adres)"
cag emekli --adres https://bulgu.ornek.com --gerekce "sayfa kaldırıldı, adres kapandı"
esit "emekli de başka adresin kaydına dokunmaz → rc 3" 3 "$RC"
esit "durum değişmedi" canli "$(alan "$D/bulgu.ornek.com.json" durum)"

echo "== T6: metin kuralları (Sultan'ın okuyacağı dil · sır · uzunluk) =="
red() { kur; cag ekle --adres https://bulgu.ornek.com "$@"; esit "$BASLIK → rc 2" 2 "$RC"; esit "$BASLIK → kayıt yok" 0 "$(say)"; }
BASLIK="ad beş kelime"; red --ad "bir iki üç dört beş" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR
BASLIK="ad boş"; red --ad "" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR
BASLIK="ad çok uzun"; red --ad "$(printf 'a%.0s' $(seq 1 41))" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR
BASLIK="açıklama çok uzun"; red --ad "Bulgu" --ne "$(printf 'a %.0s' $(seq 1 80))" --kutu merkez --ekleyen SERDAR
BASLIK="açıklamada dosya yolu"; red --ad "Bulgu" --ne "Kaynağı /srv/kilavuz/bulgu altında" --kutu merkez --ekleyen SERDAR
BASLIK="açıklamada dosya adı"; red --ad "Bulgu" --ne "Sayfayı tazele.sh üretir" --kutu merkez --ekleyen SERDAR
BASLIK="açıklamada adres"; red --ad "Bulgu" --ne "Asıl adres https://x.ornek.com" --kutu merkez --ekleyen SERDAR
BASLIK="açıklamada kod imi"; red --ad "Bulgu" --ne 'Komut `liste` ile' --kutu merkez --ekleyen SERDAR
BASLIK="açıklama iki satır"; red --ad "Bulgu" --ne $'Bulgu\nlistesi' --kutu merkez --ekleyen SERDAR
BASLIK="kutu yok"; red --ad "Bulgu" --ne "Bulgu listesi" --ekleyen SERDAR
BASLIK="kutu adı düzgün değil"; red --ad "Bulgu" --ne "Bulgu listesi" --kutu "Merkez Kutu" --ekleyen SERDAR
BASLIK="ekleyen yok"; red --ad "Bulgu" --ne "Bulgu listesi" --kutu merkez
BASLIK="tanınmayan bayrak"; red --ad "Bulgu" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR --zorla
GIZLI="parola=CokGizliDeger12345"
kur; cag ekle --adres https://bulgu.ornek.com --ad "Bulgu" --ne "Girişte $GIZLI kullanılır" --kutu merkez --ekleyen SERDAR
esit "açıklamada sır → rc 2" 2 "$RC"
icermez "sır değeri çıktıya basılmadı" "$CIKTI" "CokGizliDeger12345"
esit "kayıt yok" 0 "$(say)"
kur; cag ekle --adres https://bulgu.ornek.com --ad "Bulgu" --ne "Anahtar 0123456789abcdef0123456789abcdef0123" --kutu merkez --ekleyen SERDAR
esit "uzun anahtar gibi değer → rc 2" 2 "$RC"

echo "== T6b: açıklama tek cümle (denetim tur 4 bulgusu) =="
kur; ekle https://bulgu.ornek.com "Bulgu" "Bulguların listesi. Her kutu buraya yazar."
esit "iki cümle → rc 2" 2 "$RC"; icerir "sebep: tek cümle" "$CIKTI" "tek cümle"; esit "kayıt yok" 0 "$(say)"
kur; ekle https://bulgu.ornek.com "Bulgu" "Bulgular burada mı? Evet"
esit "soru + ikinci söz → rc 2" 2 "$RC"
kur; ekle https://bulgu.ornek.com "Bulgu" "Bulgu listesi; kutular yazar"
esit "noktalı virgül zinciri → rc 2" 2 "$RC"
kur; ekle https://bulgu.ornek.com "Bulgu" "Bulguların tek listesi."
esit "sonda nokta olan tek cümle geçer" 0 "$RC"
kur; ekle https://bulgu.ornek.com "Bulgu" "Sürüm 2.5 bulgularının listesi"
esit "ondalık sayı cümle sayılmaz" 0 "$RC"
kur; ekle https://bulgu.ornek.com "Bulgu" "Bulguların listesi, kutular buraya yazar"
esit "virgülle bağlı tek cümle geçer" 0 "$RC"

echo "== T7: aynı adres yeniden eklenirse kayıt güncellenir, ilk tarih korunur =="
kur; ekle https://bulgu.ornek.com
python3 - "$D/bulgu.ornek.com.json" <<'PY'
import json, sys
k = json.load(open(sys.argv[1])); k["eklendi"] = "2026-01-01T00:00:00+03:00"; json.dump(k, open(sys.argv[1], "w"))
PY
ekle https://bulgu.ornek.com "Bulgu Toplayıcı" "Bütün kutuların bulguları tek yerde"
esit "rc 0" 0 "$RC"
esit "tek kayıt" 1 "$(say)"
esit "ad güncellendi" "Bulgu Toplayıcı" "$(alan "$D/bulgu.ornek.com.json" ad)"
esit "ilk tarih korundu" "2026-01-01T00:00:00+03:00" "$(alan "$D/bulgu.ornek.com.json" eklendi)"
esit "geçici dosya kalmadı" 0 "$(find "$D" -name '.*.yeni' -type f | wc -l)"

echo "== T8: emekli — kayıt silinmez, menüden kalkar =="
kur; ekle https://bulgu.ornek.com; ekle https://fikir.ornek.com "Fikir Defteri" "Yeni iş fikirlerinin defteri" mihenk MIHENK
cag emekli --adres https://bulgu.ornek.com --gerekce "kısa"
esit "gerekçe kısa → rc 2" 2 "$RC"
esit "durum değişmedi" canli "$(alan "$D/bulgu.ornek.com.json" durum)"
for g in "parola=CokGizliDeger12345 yüzünden kapandı" "Kaynağı /srv/kilavuz/bulgu altından kalktı" $'sayfa kaldırıldı\nadres kapandı' "$(printf 'a %.0s' $(seq 1 110))" 'Komut `sil` ile kaldırıldı'; do
  cag emekli --adres https://bulgu.ornek.com --gerekce "$g"
  esit "kurala uymayan gerekçe → rc 2" 2 "$RC"
  esit "durum değişmedi" canli "$(alan "$D/bulgu.ornek.com.json" durum)"
  icermez "sır değeri çıktıya basılmadı" "$CIKTI" "CokGizliDeger12345"
done
esit "kayıt dosyasına sır yazılmadı" 0 "$(grep -c CokGizli "$D/bulgu.ornek.com.json")"
cag emekli --adres https://yok-kayit.ornek.com --gerekce "sayfa kaldırıldı, adres kapandı"
esit "olmayan kayıt → rc 1" 1 "$RC"
cag emekli --adres https://bulgu.ornek.com --gerekce "sayfa kaldırıldı, adres kapandı"
esit "rc 0" 0 "$RC"
esit "kayıt dosyası duruyor" 2 "$(say)"
esit "durum emekli" emekli "$(alan "$D/bulgu.ornek.com.json" durum)"
cag liste; icermez "emekli sayfa listede yok" "$CIKTI" "Bulgu Defteri"
icerir "öbür sayfa listede" "$CIKTI" "Fikir Defteri"
cag liste --hepsi; icerir "--hepsi emekliyi de gösterir" "$CIKTI" "emekli"
ekle https://bulgu.ornek.com
esit "emekli sayfa yeniden eklenince canlıya döner" canli "$(alan "$D/bulgu.ornek.com.json" durum)"

echo "== T9: bozuk kayıt sessizce yutulmaz =="
kur; ekle https://bulgu.ornek.com; echo "{bozuk" > "$D/kirik.json"; echo '{"adres":"https://eksik.ornek.com"}' > "$D/eksik.json"
cag liste
esit "liste rc 1" 1 "$RC"
icerir "bozuk kayıtlar adıyla yazıldı" "$CIKTI" "BOZUK KAYIT: 2 (eksik.json, kirik.json)"
icerir "sağlam kayıt yine listede" "$CIKTI" "Bulgu Defteri"
cag liste --json
esit "json sağlam kaydı taşıyor" 1 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')"
esit "json bozukları sayıyor" 2 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["bozuk"]))')"
kur; mkdir -p "$D"; echo '{"v":1,"adres":"https://adsiz.ornek.com","durum":"canli","giris":"kapali"}' > "$D/adsiz.json"
cag liste --json
esit "adı ve açıklaması olmayan kayıt menüye geçmez" 0 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')"
esit "bozuk diye sayılır" 1 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["bozuk"]))')"
kur; mkdir -p "$D"; echo '{"v":1,"adres":"javascript:alert(1)","ad":"x","ne":"x","kutu":"x","ekleyen":"x","giris":"acik","durum":"canli","eklendi":"x"}' > "$D/kotu.json"
cag liste --json
esit "https olmayan adresli kayıt menüye geçmez" 0 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')"

echo "== T9b: hedef dosyadaki bozuk kayıt delildir, üstüne yazılmaz (denetim tur 1) =="
kur; mkdir -p "$D"; printf '{bozuk kayit' > "$D/bulgu.ornek.com.json"
ekle https://bulgu.ornek.com
esit "ekle rc 3" 3 "$RC"; icerir "sebep: bozuk kayıt" "$CIKTI" "BOZUK"
esit "bozuk dosya aynen duruyor" "{bozuk kayit" "$(cat "$D/bulgu.ornek.com.json")"
esit "başka dosya açılmadı" 1 "$(say)"
cag emekli --adres https://bulgu.ornek.com --gerekce "Sayfa kapatıldı, artık yok"
esit "emekli rc 3" 3 "$RC"
esit "emekli de dokunmadı" "{bozuk kayit" "$(cat "$D/bulgu.ornek.com.json")"
for kotu in '{}' '{"adres":null}' '[]' '{"ad":"Bulgu","ne":"x"}'; do   # okunuyor ama kayıt değil (denetim tur 2)
  kur; mkdir -p "$D"; printf '%s' "$kotu" > "$D/bulgu.ornek.com.json"; ekle https://bulgu.ornek.com
  esit "şemasız hedef $kotu → ekle rc 3" 3 "$RC"; esit "dosya aynen duruyor ($kotu)" "$kotu" "$(cat "$D/bulgu.ornek.com.json")"
done

echo "== T9c: aynı sayfaya eşzamanlı yazım sıraya girer (denetim tur 3) =="
kur; mkdir -p "$D"; K="$D/.bulgu.ornek.com.json.kilit"
( flock -x "$K" -c "sleep 2" ) & TUTAN=$!; sleep 0.3
CIKTI="$(CANLI_SAYFA_DIZIN="$D" CANLI_SAYFA_OLCER="bash $T/olcer.sh" CANLI_SAYFA_KILIT_SURE=0 timeout 20 bash "$SUT" ekle --adres https://bulgu.ornek.com --ad "Bulgu" --ne "Bulgu listesi" --kutu merkez --ekleyen SERDAR 2>&1)"; RC=$?
esit "kilit başkasındayken beklemesiz ekle rc 3" 3 "$RC"; icerir "sebep: kilit" "$CIKTI" "kilit"; esit "yazmadı" 0 "$(say)"
ekle https://bulgu.ornek.com   # varsayılan bekleme 10 sn: kilit 2 sn sonra düşer, kayıt yazılır
esit "kilit düşünce ekle rc 0" 0 "$RC"; esit "kayıt yazıldı" 1 "$(say)"; wait "$TUTAN" 2>/dev/null
kur; for i in 1 2 3 4 5 6; do
  ( CANLI_SAYFA_DIZIN="$D" CANLI_SAYFA_OLCER="bash $T/olcer.sh" bash "$SUT" ekle --adres https://bulgu.ornek.com --ad "Bulgu $i" --ne "Kutu $i yazdı" --kutu "kutu$i" --ekleyen SERDAR >/dev/null 2>&1; echo $? >> "$T/rc-esz" ) &
done; wait
esit "altı eşzamanlı yazım hepsi rc 0" "0 0 0 0 0 0" "$(sort "$T/rc-esz" | tr '\n' ' ' | sed 's/ $//')"
esit "tek kayıt dosyası" 1 "$(say)"
cag liste --json; esit "kayıt okunur ve sağlam" 1 "$(printf '%s' "$CIKTI" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')"
kur; ekle https://bulgu.ornek.com; ( flock -x "$K" -c "sleep 2" ) & TUTAN=$!; sleep 0.3
CIKTI="$(CANLI_SAYFA_DIZIN="$D" CANLI_SAYFA_KILIT_SURE=0 timeout 20 bash "$SUT" emekli --adres https://bulgu.ornek.com --gerekce "Sayfa kapatıldı, artık yok" 2>&1)"; RC=$?
esit "emekli de kilide uyar → rc 3" 3 "$RC"; esit "durum değişmedi" canli "$(alan "$D/bulgu.ornek.com.json" durum)"; wait "$TUTAN" 2>/dev/null

echo "== T10: dogrula — kayıtlı sayfalar yeniden ölçülür =="
kur; ekle https://bulgu.ornek.com; ekle https://fikir.ornek.com "Fikir Defteri" "Yeni iş fikirlerinin defteri" mihenk MIHENK
cag dogrula
esit "hepsi açılıyor → rc 0" 0 "$RC"
icerir "sayı doğru" "$CIKTI" "── 2 sayfa ölçüldü"
sed -i 's#^https://fikir.ornek.com .*#https://fikir.ornek.com 502#' "$T/cevaplar"; cag dogrula
esit "biri açılmıyor → rc 1" 1 "$RC"
icerir "hangisinin açılmadığı yazıyor" "$CIKTI" "AÇILMIYOR   Fikir Defteri"
sed -i 's#^https://fikir.ornek.com .*#https://fikir.ornek.com 200#' "$T/cevaplar"; cag dogrula
esit "kapı kalkmış → rc 1" 1 "$RC"
icerir "kapının değiştiği yazıyor" "$CIKTI" "KAPI DEĞİŞTİ Fikir Defteri"
esit "dogrula kaydı değiştirmez" kapali "$(alan "$D/fikir.ornek.com.json" giris)"
kur; cag dogrula; esit "kayıt yokken rc 0" 0 "$RC"

echo "== T11: kullanım =="
kur; cag; esit "komutsuz → rc 2" 2 "$RC"
cag sil --adres https://bulgu.ornek.com; esit "silme komutu yok → rc 2" 2 "$RC"
for s in --adres --ad --ne --kutu --ekleyen --herkese-acik --gerekce; do
  cag ekle $s; esit "değersiz $s → rc 2 (asılı kalmaz)" 2 "$RC"
  icerir "değersiz $s → sebebi söylüyor" "$CIKTI" "$s bir değer ister"
done
cag ekle --adres https://bulgu.ornek.com --ad "Bulgu" --ne "Bulgu listesi" --kutu merkez --ekleyen
esit "sondaki seçenek değersiz → rc 2" 2 "$RC"
esit "kayıt yok" 0 "$(say)"
# ölçer girdiyi yutmaya çalışsa da dogrula bütün kayıtları ölçer
kur; ekle https://bulgu.ornek.com; ekle https://fikir.ornek.com "Fikir Defteri" "Yeni iş fikirlerinin defteri" mihenk MIHENK
printf '%s\n' 'cat > /dev/null' "$(cat "$T/olcer.sh")" > "$T/olcer-yutan.sh"; mv "$T/olcer-yutan.sh" "$T/olcer.sh"
cag dogrula; icerir "girdiyi yutan ölçerle de iki sayfa ölçüldü" "$CIKTI" "── 2 sayfa ölçüldü"
kur; cag liste; esit "kayıt dizini yokken liste rc 0" 0 "$RC"
icerir "sıfır sayfa" "$CIKTI" "── 0 sayfa"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ]
