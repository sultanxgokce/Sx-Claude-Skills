#!/usr/bin/env bash
# denetci-tavan.test.sh — bağımsız göz VARSAYILAN tavanı: 2 tur (+1 ilerleyene), 3 mutlak (0.27.50, Sultan 3 Kas 2026, öneri #2).
# Neden ayrı dosya: denetci.test.sh eski turlu sınavlarını DENETCI_TAVAN=3/4 dikişiyle sabitledi; varsayılanın kendi sınavı değişkensiz
# koşmalı. Asıl sınav bu dosyayı ÇAĞIRIR (denetci-kutu-disi.test.sh deseni), yani "test yazmak onu koşturmaz" tuzağı yok.
# Önce/sonra ölçümü: MUTANT_D=<eski denetci.sh> ile koşunca kırmızı, yenisiyle yeşil.
# kabuk-testleri: sure=120
set -uo pipefail
export DALGIC_KAPALI=1 KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=-
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'find "$T" -delete 2>/dev/null' EXIT
( cd "$T" && git init -q -b main ) >/dev/null 2>&1
ZB="$T/.zil-kilidi"; mkdir -p "$ZB"; printf '#!/usr/bin/env bash\nexit 0\n' > "$ZB/aile-notify.sh"; chmod +x "$ZB/aile-notify.sh"
export PATH="$ZB:$PATH" AILE_SINYAL_LOG="$ZB/sinyal.log" KANIT_DEPO="$T"
printf 'diff --git a/x b/x\n+satir\n' > "$T/d.patch"
SAHTE="$T/sahte.sh"; printf '#!/usr/bin/env bash\nprintf "%%s" "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"; export DENETCI_KOMUT="$SAHTE"
J() { printf '{"kod_puani":%s,"dogru_sey":"%s","ozet":"o","bulgular":[%s],"kanit_gorusu":"k"}' "$1" "$2" "$3"; }
B='{"ne":"n","kanit":"k","konum":"x:1","agirlik":"uygulama"}'
unset DENETCI_TAVAN DENETCI_MUTLAK   # ölçülen şey VARSAYILAN: dikiş açık bırakılmaz
N() { SAHTE_JSON="$1" bash "$D" "$2" --diff "$T/d.patch" 2>&1; }

echo "════ T7n · VARSAYILAN tavan 2 (+1 ilerleyene), 3 mutlak ════"
# Anlam: tavan iki göz turu (1 bulgu + 1 düzeltme). 2. tur da geçmediyse iş "düzelt" (rc=1) alır; TIKANMA ÜÇÜNCÜ çağrıda söylenir.
# İlerlemeyen iş 3. çağrıda göz koşmadan rc=4 alır; ilerleyen iş 3. turu (+1 pay) koşar, orada mutlak.
bash "$K" olcum is-n1 olc --asama tek -- echo 1 >/dev/null 2>&1
N "$(J 2 H "$B,$B")" is-n1 >/dev/null; [ $? -eq 1 ]; g $? "T7n tur1 rc=1"
N "$(J 2 H "$B,$B")" is-n1 >/dev/null; [ $? -eq 1 ]; g $? "T7n tur2 (düzeltme turu) geçmedi: 'düzelt' rc=1, henüz tıkanma yok"
[ -f "$T/_agents/fabrika/kanit/is-n1/DENETIM-2.json" ]; g $? "T7n iki göz turu koştu (DENETIM-2 yazıldı)"
CIKTI="$(N "$(J 5 E "")" is-n1)"; RC=$?
[ "$RC" -eq 4 ]; g $? "🔴 T7n ilerlemeyen iş: TIKANMA 3. çağrıda, göz koşmadan rc=4"
grep -q "tavan 2" <<<"$CIKTI"; g $? "T7n tıkandı raporu 'tavan 2' diyor"
[ ! -f "$T/_agents/fabrika/kanit/is-n1/DENETIM-3.json" ]; g $? "T7n DENETIM-3 yazılmadı (3. göz turu YOK)"
bash "$K" olcum is-n2 olc --asama tek -- echo 1 >/dev/null 2>&1
N "$(J 2 H "$B,$B,$B")" is-n2 >/dev/null; [ $? -eq 1 ]; g $? "T7n ilerleyen iş: tur1 rc=1"
N "$(J 3 H "$B,$B")" is-n2 >/dev/null; [ $? -eq 1 ]; g $? "T7n ilerleyen iş: tur2 rc=1 (puan↑ bulgu↓, tıkanmadı)"
CIKTI="$(N "$(J 5 E "")" is-n2)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T7n ilerleyen iş 3. tur payını alır ve 5/E ile GEÇER (rc=0)"
grep -q "+1 tur payı" <<<"$CIKTI"; g $? "T7n +1 tur payı yazılı"
bash "$K" olcum is-n3 olc --asama tek -- echo 1 >/dev/null 2>&1
N "$(J 2 H "$B,$B,$B")" is-n3 >/dev/null; N "$(J 3 H "$B,$B")" is-n3 >/dev/null
N "$(J 4 H "$B")" is-n3 >/dev/null; [ $? -eq 4 ]; g $? "T7n pay turu da geçmediyse rc=4 (3 mutlak)"
N "$(J 5 E "")" is-n3 >/dev/null; [ $? -eq 4 ]; g $? "🔴 T7n 4. çağrı MUTLAK: pay ile bile en çok 3 göz turu"
[ ! -f "$T/_agents/fabrika/kanit/is-n3/DENETIM-4.json" ]; g $? "T7n DENETIM-4 yazılmadı"
# Dikiş yalnız sahte göz varken açılır: gerçek koşuda ortam değişkeni tavanı yükseltemez
DIKIS="$(sed -n '/^TAVAN=2; MUTLAK=3/,/^fi$/p' "$D")"; grep -q 'DENETCI_KOMUT' <<<"$DIKIS"; g $? "T7n tavan dikişi yalnız sahte göz varken açılır (gerçek koşuda ortamdan okunmaz)"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
