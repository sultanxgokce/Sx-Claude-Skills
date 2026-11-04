#!/usr/bin/env bash
# Beyan = tam sayıya YUKARI yuvarlanmış (en kötü ölçülmüş koşu x 1,5). Tek yuvarlama nedeni: sure= tam sayı ister.
#  (1) en kötü koşu = araç imzalı olcum-kosu-suresi-tek.txt'teki 'sn=' değerlerinin en büyüğü (kosu-olc.sh: main ve dal aynı yükte)
#  (2) CI'ın kendi sure_sec ayrıştırıcısı dosyadaki beyanı bu değer olarak okuyor; beyansız dosya 300 kalıyor
KABUK_SURE_VARSAYILAN=300; KABUK_SURE_TAVAN=900
cd "$(git rev-parse --show-toplevel)" || exit 2
K=_agents/fabrika/kanit/denetci-duzeltme-sure-beyani
eval "$(sed -n '/^sure_sec() {/,/^}/p' .github/ci/kabuk-sinamalari.sh)"
EK="$(grep -oE 'sn=[0-9]+' "$K/olcum-kosu-suresi-tek.txt" | cut -d= -f2 | sort -n | tail -1)"
[ -n "$EK" ] || { echo "✗ ölçüm verisi okunamadı ($K/olcum-kosu-suresi-tek.txt)"; exit 3; }
BEKLENEN=$(( (EK * 3 + 1) / 2 ))
[ $(( EK * 3 % 2 )) -ne 0 ] && TAM="$(( EK * 3 / 2 )),5" || TAM="$(( EK * 3 / 2 ))"
a="$(sure_sec ./yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh)"; b="$(sure_sec ./yazilim-fabrikasi/scripts/manifest-ozet.test.sh)"
echo "en kötü ölçülmüş koşu = $EK sn · x1,5 = $TAM · tam sayıya yukarı = $BEKLENEN"
echo "denetci-duzeltme-farki okunan sure=$a (beklenen $BEKLENEN) · beyansız kontrol dosyası sure=$b (beklenen 300)"
[ "$a" = "$BEKLENEN" ] && [ "$b" = 300 ]; rc=$?
[ "$rc" -ne 0 ] && echo "✗ okunan sure=$BEKLENEN kapısı düştü"
exit $rc
