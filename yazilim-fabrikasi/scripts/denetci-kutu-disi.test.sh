#!/usr/bin/env bash
# denetci-kutu-disi.test.sh — "kutuda ölçülemeyen bulgu ayrı sınıftır ve tur yakmaz" kapıları.
#
# NİÇİN AYRI DOSYA: denetci.test.sh bu iş açılırken PR #331'in (--kare, 0.6.5) elindeydi;
# aynı dosyayı büyütmek onun değişikliğini ezerdi. Asıl sınav bu dosyayı ÇAĞIRIR (dosyanın
# sonundaki blok), yani "test yazmak onu koşturmaz" tuzağına düşmez. #331 inince gövde oraya
# taşınır. Görev: WC3VBZAA.
#
# ÖLÇÜLMÜŞ VAKA (SERDAR, 15 Eki 2026): cloudtop #635 DÖRT turunu "canlıda kurulu değil"
# bulgusuyla yaktı. Kod kusursuzdu; bulgu gerçekti ama o kutuda ölçülemezdi. Tur yandı, iş durdu.
#
# HERMETİK: gerçek denetçi (codex/claude) çağrılmaz — DENETCI_KOMUT ile sahte bir betik kullanılır.
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI (gerçek koltuklara çalmasın); zil kapısı kendi sahtesini verir
cd "$(dirname "$0")"
D="$PWD/denetci.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren() { local ad="$1" ara="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if [[ "$out" == *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (çıktıda '$ara' yok)"; fi; }
icermeyen() { local ad="$1" ara="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if [[ "$out" != *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' çıktıda var, olmamalı)"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
( cd "$KOK" && git init -q . && git config user.email s@s && git config user.name s && \
  echo a > a.txt && git add -A && git commit -q -m "chore: sinav deposu" )
mkdir -p "$KOK/_agents/fabrika/kartlar"
printf 'diff --git a/uretim/k.py b/uretim/k.py\n--- a/uretim/k.py\n+++ b/uretim/k.py\n@@ -1 +1 @@\n-e\n+y\n' > "$KOK/f.patch"

# Sahte denetçi: SONUC_JSON ortam değişkenindeki JSON'u basar (turu turu değiştirebiliriz)
cat > "$KOK/sd.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$SONUC_JSON"
SH
chmod +x "$KOK/sd.sh"

kart() {  # kart <is>
  cat > "$KOK/_agents/fabrika/kartlar/$1.json" <<JSON
{"is":"$1","cumle":"s","istedi":"s","aldi":"s",
 "cevaplar":{"geri_alinamaz":"h","para":"h","dis_yuzey":"h","yetki":"h"},
 "siniflar":[],"sultan":false,"durum":"acik","gecmis":[]}
JSON
}
hazirla() {  # hazirla <is> → kart + arac imzali kanit manifesti
  kart "$1"
  KANIT_DEPO="$KOK" python3 "$PWD/kanit.py" olcum "$1" s --asama tek -- echo o >/dev/null 2>&1
}
kos() {  # kos <is> <sonuc-json> [ek-ortam...]
  local is="$1" js="$2"; shift 2
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sd.sh" SONUC_JSON="$js" "$@" \
      bash "$D" "$is" --diff "$KOK/f.patch" --depo "$KOK"
}

# JSON kalıpları
KD='{"kod_puani":3,"dogru_sey":"E","ozet":"s","bulgular":[{"ne":"canlida kurulu degil","kanit":"canli kutuda yok","konum":"x:1","agirlik":"kutu-disi","kutu_disi_yuzey":"Sultan%s Mac%s"}],"kanit_gorusu":"s"}'
KD=$(printf "$KD" "'in" "i")
KD_YUZEYSIZ='{"kod_puani":3,"dogru_sey":"E","ozet":"s","bulgular":[{"ne":"olcemedim","kanit":"k","konum":"x:1","agirlik":"kutu-disi"}],"kanit_gorusu":"s"}'
NORMAL='{"kod_puani":3,"dogru_sey":"E","ozet":"s","bulgular":[{"ne":"gercek kusur","kanit":"k","konum":"x:1","agirlik":"uygulama"}],"kanit_gorusu":"s"}'
KARISIK='{"kod_puani":3,"dogru_sey":"E","ozet":"s","bulgular":[{"ne":"gercek kusur","kanit":"k","konum":"x:1","agirlik":"uygulama"},{"ne":"canlida yok","kanit":"k","konum":"y:2","agirlik":"kutu-disi","kutu_disi_yuzey":"canli site + yetki"}],"kanit_gorusu":"s"}'
GECTI='{"kod_puani":5,"dogru_sey":"E","ozet":"s","bulgular":[],"kanit_gorusu":"s"}'

echo "A · 🔴 kutu-dışı bulgu TUR YAKMAZ (asıl talep)"
# 🔴 Sonsuz-döngü freni (E bloğu) burada BİLEREK yükseltiliyor: A'nın ölçtüğü şey tavanın
#    yakılmaması; fren devreye girerse ölçtüğüm şey fren olur, tavan olmaz (iki kapı birbirini
#    maskeler). Ham tur 3'ü ve 4'ü GEÇİYOR ama tıkanma YOK — ölçülen tam budur.
hazirla is-a
A_ORT=(DENETCI_KUTU_DISI_TAVAN=9)
kapi "A1 tur 1 (kutu-dışı bulgu) → düzelt-dön" 1 kos is-a "$KD" "${A_ORT[@]}"
kapi "A2 tur 2" 1 kos is-a "$KD" "${A_ORT[@]}"
kapi "A3 🔴 ham tur 3 = TAVAN ama SAYILI tur 0 → TIKANMAZ (rc=1)" 1 kos is-a "$KD" "${A_ORT[@]}"
kapi "A4 🔴 ham tur 4 = MUTLAK tavan ama yine tıkanmaz" 1 kos is-a "$KD" "${A_ORT[@]}"
iceren "A5 🔴 'tur yakmadı' SÖYLENİR (sessiz muafiyet yok)" "tur yakmadı" kos is-a "$KD" "${A_ORT[@]}"
icermeyen "A6 🔴 bu turlarda TIKANDI raporu BASILMAZ" "⛔ TIKANDI" kos is-a "$KD" "${A_ORT[@]}"
iceren "A7 sayılı tur ekranda 0 olarak yazılır" "sayılı tur 0/" kos is-a "$KD" "${A_ORT[@]}"

echo "B · 🔴 normal bulgu YİNE tur yakar (muafiyet sızmasın)"
hazirla is-b
kapi "B1 tur 1 (normal bulgu)" 1 kos is-b "$NORMAL"
kapi "B2 tur 2 (normal bulgu)" 1 kos is-b "$NORMAL"
kapi "B3 🔴 tur 3'te TIKANIR (rc=4) — eski davranış korundu" 4 kos is-b "$NORMAL"
iceren "B4 tıkanma raporu basılır" "⛔ TIKANDI" kos is-b "$NORMAL"

echo "C · 🔴 karışık tur SAYILIR (içinde bir normal bulgu varsa)"
hazirla is-c
kapi "C1 tur 1 (karışık)" 1 kos is-c "$KARISIK"
kapi "C2 tur 2 (karışık)" 1 kos is-c "$KARISIK"
kapi "C3 🔴 tur 3'te TIKANIR — karışık tur muafiyet ALMAZ" 4 kos is-c "$KARISIK"

echo "D · 🔴 muafiyet BEDELSİZ değil: yüzey yazılmazsa sınıf DÜŞÜRÜLÜR"
hazirla is-d
iceren "D1 yüzeysiz kutu-dışı bulgu 'uygulama'ya DÜŞÜRÜLÜR" "[uygulama]" kos is-d "$KD_YUZEYSIZ"
iceren "D2 düşürüldüğü SÖYLENİR" "kutu-disi → uygulama" kos is-d "$KD_YUZEYSIZ"
hazirla is-d2
kapi "D3 tur 1 (yüzeysiz)" 1 kos is-d2 "$KD_YUZEYSIZ"
kapi "D4 tur 2 (yüzeysiz)" 1 kos is-d2 "$KD_YUZEYSIZ"
# 🔴 D5 rc'ye DEĞİL MESAJA bakar: yüzey şartı kalkarsa bulgu kutu-dışı kalır ve sonsuz-döngü
#    freni aynı rc=4'ü verir — kapı kazara yeşil kalırdı (ölçtüğüm şey fren olur, yüzey şartı olmaz).
#    Ayırt edici: yüzey şartı ÇALIŞIYORSA bu bir KOD tıkanmasıdır (⛔ TIKANDI), çalışmıyorsa
#    "KUTUDA İLERLETİLEMİYOR" basılır.
iceren "D5 🔴 yüzeysiz bulgu tur YAKAR → KOD tıkanması (etiket bedava muafiyet değil)" "⛔ TIKANDI" kos is-d2 "$KD_YUZEYSIZ"
icermeyen "D6 🔴 yüzeysiz bulgu kutu-dışı MUAFİYETİ ALMAZ" "KUTUDA İLERLETİLEMİYOR" kos is-d2 "$KD_YUZEYSIZ"

echo "E · 🔴 sonsuz döngü KAPALI: muafiyet sınırsız değil"
hazirla is-e
kapi "E1 tur 1" 1 kos is-e "$KD"
kapi "E2 tur 2" 1 kos is-e "$KD"
kapi "E3 tur 3 (yakmayan 3 > tavan 2) → rc=4" 4 kos is-e "$KD"
iceren "E4 🔴 bu ret KOD tıkanması DEĞİL diye söylenir" "KUTUDA İLERLETİLEMİYOR" kos is-e "$KD"
iceren "E5 çare 'yüzeye git' olarak verilir" "YÜZEYE GİT" kos is-e "$KD"
icermeyen "E6 🔴 'DEVAM — gerekçeyle' yolu ÖNERİLMEZ (yanlış çare)" "1) DEVAM" kos is-e "$KD"
hazirla is-e2
kapi "E7 tavan ortamla değiştirilebilir (DENETCI_KUTU_DISI_TAVAN=1 → tur 2'de rc=4)" 1 kos is-e2 "$KD" DENETCI_KUTU_DISI_TAVAN=1
kapi "E8 ikinci yakmayan turda rc=4" 4 kos is-e2 "$KD" DENETCI_KUTU_DISI_TAVAN=1

echo "H · 🔴 tur-1 bulgusu: fren ARDIŞIK dizi sayar, TOPLAM değil"
# Eski sayaç kümülatifti (ONCEKI-SAYILI): kutu-dışı/normal/kutu-dışı/normal/kutu-dışı dizisinde
# üç ARDIŞIK yakmayan tur olmadığı hâlde iş durabilirdi. Arada normal bir tur geçtiyse iş kutuda
# İLERLİYOR; sayaç orada sıfırlanmalı. Aşağıdaki dizi tam o vakayı kurar.
hazirla is-h
kapi "H1 tur 1 kutu-dışı" 1 kos is-h "$KD"
kapi "H2 tur 2 kutu-dışı" 1 kos is-h "$KD"
kapi "H3 🔴 tur 3 NORMAL → ardışık dizi SIFIRLANIR (fren tetiklenmez)" 1 kos is-h "$NORMAL"
icermeyen "H4 🔴 normal tur sonrası 'KUTUDA İLERLETİLEMİYOR' BASILMAZ" "KUTUDA İLERLETİLEMİYOR" kos is-h "$KD"
# Buraya kadar ham tur 4, yakmayan toplam 3 (>2) ama ARDIŞIK 1 → fren susmalı.
# Kümülatif sayaçta H4 kırmızı olurdu.
hazirla is-h2
kapi "H5 ardışık dizi gerçekten üst üste olunca fren ÇALIŞIR (tur 1)" 1 kos is-h2 "$KD"
kapi "H6 tur 2" 1 kos is-h2 "$KD"
iceren "H7 🔴 tur 3 üst üste → fren çalışır" "KUTUDA İLERLETİLEMİYOR" kos is-h2 "$KD"

echo "I · 🔴 kendi #332 işimden sızan gürültü"
hazirla is-i
icermeyen "I1 ayıklayıcı sayıları ekrana '0 0' diye düşmez" "0 0" kos is-i "$GECTI"

echo "F · 🔴 muafiyetin karşılığı İZLENEBİLİRLİK: ayrı deftere yazılır"
hazirla is-f
kos is-f "$KD" >/dev/null 2>&1
kapi "F1 KUTU-DISI.jsonl yazıldı ve yüzeyi taşıyor" 0 python3 -c "
import json,sys
sat=[json.loads(l) for l in open('$KOK/_agents/fabrika/kanit/is-f/KUTU-DISI.jsonl',encoding='utf-8') if l.strip()]
assert len(sat)==1, sat
assert sat[0]['yuzey'], sat[0]
assert sat[0]['ne']=='canlida kurulu degil', sat[0]
"
kos is-f "$KD" >/dev/null 2>&1
kapi "F2 🔴 aynı bulgu her turda YENİDEN yazılmaz (defter şişmez)" 0 python3 -c "
import json
sat=[l for l in open('$KOK/_agents/fabrika/kanit/is-f/KUTU-DISI.jsonl',encoding='utf-8') if l.strip()]
assert len(sat)==1, len(sat)
"
iceren "F3 defterin yolu ekrana basılır" "kutu-dışı defteri" kos is-f "$KD"
hazirla is-f2
kos is-f2 "$NORMAL" >/dev/null 2>&1
kapi "F4 kutu-dışı bulgu YOKSA defter KURULMAZ (boş dosya bırakmaz)" 1 \
  test -f "$KOK/_agents/fabrika/kanit/is-f2/KUTU-DISI.jsonl"

echo "G · 🔴 geçiş ve ayrı yazdırma bozulmadı"
hazirla is-g
kapi "G1 5+E yine GEÇER (rc=0)" 0 kos is-g "$GECTI"
hazirla is-g2
iceren "G2 kutu-dışı bulgular AYRI başlıkta listelenir" "── KUTU-DIŞI" kos is-g2 "$KARISIK"
iceren "G3 gereken yüzey yazdırılır" "gereken yüzey: canli site + yetki" kos is-g2 "$KARISIK"
iceren "G4 işin sahibine gideceği söylenir" "işin SAHIBINE gider" kos is-g2 "$KARISIK"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
