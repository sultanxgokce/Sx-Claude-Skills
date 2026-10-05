#!/usr/bin/env bash
# cipa.sh sınavı — çıpa yazılıyor mu, compact önerisi ÇIPASIZ üretiliyor mu (fail-closed).
# Hermetik: gerçek çıpaya DOKUNMAZ, kendi geçici dizininde koşar.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="$KOK/cipa.sh"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
# Çıpa artık AJAN BAŞINA dosyaya yazıyor (b0097); sınav kimliği sabitler ki yol tahmin edilmesin.
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="sinav"
C="$T/cipa/gunluk-plan-cipa.sinav.md"

echo "── ÇIPASIZ compact önerisi ÜRETİLMEZ (fail-closed · asıl kapı)"
bash "$ARAC" compact-onerisi >/dev/null 2>&1; kapi "K1 çıpa yokken öneri rc=3" "3" "$?"
kapi "K2 çıpa yokken çıktı da üretilmez" "0" "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'compact yapalım')"

echo "── çıpa yazılır ve GERİ OKUNUR"
bash "$ARAC" yaz --plan "1) ilk is | 2) ikinci is | 3) ucuncu is" >/dev/null 2>&1; kapi "K3 yaz rc=0" "0" "$?"
kapi "K4 dosya diskte" "1" "$([ -f "$C" ] && echo 1 || echo 0)"
kapi "K5 üç madde yazıldı" "3" "$(grep -c '^- \[' "$C" 2>/dev/null)"
kapi "K6 tarih çıpada" "1" "$(grep -c '2026-01-02' "$C" 2>/dev/null; true)"
bash "$ARAC" yaz >/dev/null 2>&1; kapi "K7 plansız yaz REDDEDİLİR (boş çıpa çıpa değildir)" "2" "$?"

echo "── çıpa VARKEN öneri üretilir"
bash "$ARAC" compact-onerisi >/dev/null 2>&1; kapi "K8 çıpa varken öneri rc=0" "0" "$?"
kapi "K9 öneri Sultan'a sorulacak cümleyi taşır (K8 tautoloji değil)" "1" \
     "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'compact yapalım mı')"
kapi "K10 öneri OTOMATİK yapmadığını SÖYLER" "1" \
     "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'Otomatik YAPILMAZ')"

echo "── madde durumu tazelenir"
bash "$ARAC" tazele --madde 2 --durum kapandi --not "kanit var" >/dev/null 2>&1; kapi "K11 tazele rc=0" "0" "$?"
kapi "K12 ikinci madde KAPANDI" "1" "$(grep -c '^- \[x\] 2) ikinci is → KAPANDI · kanit var' "$C" 2>/dev/null; true)"
kapi "K13 öteki maddeler DOKUNULMADI" "2" "$(grep -c '^- \[ \]' "$C" 2>/dev/null; true)"
bash "$ARAC" tazele --madde 9 --durum kapandi >/dev/null 2>&1; kapi "K14 olmayan madde REDDEDİLİR" "1" "$?"
bash "$ARAC" tazele --madde 1 --durum uydurma >/dev/null 2>&1; kapi "K15 geçersiz durum REDDEDİLİR" "2" "$?"
bash "$ARAC" tazele --madde 3 --durum yarim >/dev/null 2>&1
kapi "K16 yarım madde işaretlenir (ertesi güne taşınacak olan)" "1" "$(grep -c '^- \[~\] 3) ucuncu is → YARIM' "$C" 2>/dev/null; true)"

echo "── tazeleme İKİ KEZ koşunca çoğaltmaz (idempotent)"
bash "$ARAC" tazele --madde 2 --durum kapandi --not "kanit var" >/dev/null 2>&1
kapi "K17 tek KAPANDI etiketi (üst üste yazmaz)" "1" "$(grep -c 'KAPANDI' "$C" 2>/dev/null; true)"

echo "── NÂZIR'ın bulduğu üç kusur (araç yazıldığı gün bulundu)"
# 🔴 K19: değersiz bayrak SONSUZ DÖNGÜ yapıyordu (shift 2 tek argümanda ilerlemiyor, işlemci %100).
#    Kapı zaman aşımıyla ölçer: 124 dönerse araç ASILMIŞ demektir ve bu BAŞARI SAYILMAZ.
for b in "--plan" "--madde" "--durum"; do
  timeout 5 bash "$ARAC" yaz $b >/dev/null 2>&1; rc=$?
  kapi "K19 değersiz $b → asılmaz, reddeder (rc=2)" "2" "$rc"
done
timeout 5 bash "$ARAC" yaz --plan --not x >/dev/null 2>&1
kapi "K19d bayrak-bayrak → değer verilmemiş sayılır" "2" "$?"
# K20: geri alınmış madde ayrı bir durumdur; kapanmış gibi görünmemeli.
bash "$ARAC" tazele --madde 1 --durum geri-alindi --not "vazgecildi" >/dev/null 2>&1
kapi "K20 geri alınan madde [-] işaretlenir" "1" "$(grep -c '^- \[-\] 1) ilk is → GERİ ALINDI' "$C" 2>/dev/null; true)"
bash "$ARAC" tazele --madde 1 --durum kapandi >/dev/null 2>&1
kapi "K20b geri alınmış madde kapandıya çevrilince ÜST ÜSTE YAZILMAZ" "0" \
     "$(grep -c 'GERİ ALINDI → KAPANDI' "$C" 2>/dev/null; true)"
kapi "K21 geçersiz durum hâlâ reddedilir (K20 kapıyı gevşetmedi)" "2" \
     "$(bash "$ARAC" tazele --madde 1 --durum uydurma >/dev/null 2>&1; echo $?)"

echo "── ÇIPA AJAN BAŞINA (b0097 · KÂŞİF/BASİRET buldu, kusur bendeydi)"
# 🔴 Niçin: ilk yazımda çıpa TEK dosyaydı ve `yaz` KESEREK yazıyordu; o dizin kutular
#    arası ortak olduğu için ikinci ajan birincinin planını SİLİYORDU. Ölçülmüş vaka var.
AT="$T/ajanli"; export GUNLUK_PLAN_CIPA_DIZ="$AT"
GUNLUK_PLAN_AJAN=BIRINCI bash "$ARAC" yaz --plan "1) birinci isi" >/dev/null 2>&1
GUNLUK_PLAN_AJAN=IKINCI  bash "$ARAC" yaz --plan "1) ikinci isi"  >/dev/null 2>&1
kapi "K22 iki ajan İKİ ayrı dosya" "2" "$(ls "$AT" 2>/dev/null | grep -c '^gunluk-plan-cipa\..*\.md$')"
kapi "K23 birincinin planı DURUYOR (ikinci ezmedi)" "1" \
     "$(grep -c 'birinci isi' "$AT/gunluk-plan-cipa.birinci.md" 2>/dev/null; true)"
kapi "K24 ikincinin planı kendi dosyasında" "1" \
     "$(grep -c 'ikinci isi' "$AT/gunluk-plan-cipa.ikinci.md" 2>/dev/null; true)"
kapi "K25 birinci dosyada ikincinin planı YOK (K23 tautoloji değil)" "0" \
     "$(grep -c 'ikinci isi' "$AT/gunluk-plan-cipa.birinci.md" 2>/dev/null; true)"
# Eski tek dosya duruyorsa EZİLMEDEN yanına taşınır (geriye dönük).
ET="$T/eski"; mkdir -p "$ET"; printf '# eski plan\n- [ ] 1) eski madde\n' > "$ET/gunluk-plan-cipa.md"
GUNLUK_PLAN_CIPA_DIZ="$ET" GUNLUK_PLAN_AJAN=UCUNCU bash "$ARAC" oku >/dev/null 2>&1
kapi "K26 eski TEK dosya korunur (silinmez)" "1" "$(grep -c 'eski madde' "$ET/gunluk-plan-cipa.md" 2>/dev/null; true)"
kapi "K27 eski plan ajanın dosyasına TAŞINIR (kaybolmaz)" "1" \
     "$(grep -c 'eski madde' "$ET/gunluk-plan-cipa.ucuncu.md" 2>/dev/null; true)"
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="sinav"

# K28-K30 · `yol` komutu: BAŞKA araçların yolu TAHMİN etmemesi için tek kaynak (2026-10-05).
#   Ölçülmüş vaka: /gun-ortasi'nın cipa-ekle.sh'ı yolu kendi türetiyordu; ajan-başına dosyaya
#   geçince eski TEK dosyaya yazmaya devam etti → kimsenin okumadığı dosya + ortak kilit öldü.
YOL="$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="sinav" bash "$ARAC" yol 2>/dev/null)"
kapi "K28 yol, yaz'ın yazdığı dosyanın TA KENDİSİ" "$C" "$YOL"
rm -f "$T/cipa/gunluk-plan-cipa.yokajan.md"
kapi "K29 dosya YOKKEN de yol basar (rc=0) — 'nereye' ile 'yazdım mı' ayrı" "0" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=yokajan bash "$ARAC" yol >/dev/null 2>&1; echo $?)"
kapi "K30 yol AJANA göre değişir (tek dosyaya dönmez)" "0" \
     "$(a=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=bir bash "$ARAC" yol); \
        b=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=iki bash "$ARAC" yol); \
        [ "$a" != "$b" ] && echo 0 || echo 1)"

echo "── GERÇEK çıpaya dokunulmadı"
kapi "K18 sınav kendi dizininde kaldı" "1" "$(printf '%s' "$C" | grep -c "^$T/" )"

echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
