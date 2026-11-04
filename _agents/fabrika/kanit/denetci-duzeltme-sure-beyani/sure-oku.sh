#!/usr/bin/env bash
# Üç şeyi ölçer (göz tur 1: "411 sn kanıtsız" + "620 ≠ 411×1,5"):
#  (1) en kötü ölçülmüş koşu = sure-olcumu.txt'teki 'sn=' değerlerinin en büyüğü (ham veri, iki aynı-yük koşusu)
#  (2) beyan = 5 sn'ye YUKARI yuvarlanmış (en kötü × 1,5)  → 411×1,5=616,5 → 620 (SERDAR: "yaklaşık 620")
#  (3) CI'ın kendi sure_sec ayrıştırıcısı dosyadaki beyanı bu değer olarak okuyor; beyansız dosya 300 kalıyor
KABUK_SURE_VARSAYILAN=300; KABUK_SURE_TAVAN=900
cd "$(git rev-parse --show-toplevel)" || exit 2
K=_agents/fabrika/kanit/denetci-duzeltme-sure-beyani
eval "$(sed -n '/^sure_sec() {/,/^}/p' .github/ci/kabuk-sinamalari.sh)"
EK="$(grep -oE 'sn=[0-9]+' "$K/sure-olcumu.txt" | cut -d= -f2 | sort -n | tail -1)"
[ -n "$EK" ] || { echo "✗ ölçüm verisi okunamadı ($K/sure-olcumu.txt)"; exit 3; }
X15=$(( EK * 3 / 2 )); [ $(( EK * 3 % 2 )) -ne 0 ] && X15_TAM="$X15,5" || X15_TAM="$X15"
BEKLENEN=$(( ( (EK * 3 + 1) / 2 + 4 ) / 5 * 5 ))   # yukarı yuvarla: ceil(EK*1,5) sonra 5'in katına
a="$(sure_sec ./yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh)"; b="$(sure_sec ./yazilim-fabrikasi/scripts/manifest-ozet.test.sh)"
echo "en kötü ölçülmüş koşu = $EK sn · x1,5 = $X15_TAM · 5 sn'ye yukarı yuvarlanmış beklenen = $BEKLENEN"
echo "denetci-duzeltme-farki okunan sure=$a (beklenen $BEKLENEN) · beyansız kontrol dosyası sure=$b (beklenen 300)"
[ "$a" = "$BEKLENEN" ] && [ "$b" = 300 ]; rc=$?
[ "$rc" -ne 0 ] && echo "✗ okunan sure=$BEKLENEN kapısı düştü"
exit $rc
