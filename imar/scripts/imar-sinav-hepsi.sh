#!/usr/bin/env bash
# imar-sinav-hepsi.sh — yedi sınavı koşar ve sayıyı DÜRÜST basar.
#
# 🔴 NİÇİN VAR (bağımsız gözün tur-1 bulgusu): "165 kapı, hepsi hermetik" demek yetmez.
#    Sınavlar bağımlılık yoksa bazı kapıları "ATLANDI — ölçülemedi, geçti sayılmaz" diye
#    atlıyor ve süit YİNE rc=0 dönüyor. O hâlde toplam "geçti" sayısı tek başına kaç kapının
#    FİİLEN koştuğunu söylemez. Bu araç üç sayıyı AYRI basar: geçti · düştü · ATLANDI.
#    Atlanan kapı yeşil DEĞİLDİR; yalnız kırmızı da değildir — ölçülemedi.
#
# Kullanım: imar-sinav-hepsi.sh [betik-dizini]
# rc: 0 hepsi geçti (atlanan olabilir, sayısı basılır) · 1 düşen var · 3 sınav bulunamadı
set -uo pipefail
D="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$D" || { echo "✗ dizin yok: $D" >&2; exit 3; }
# 🔴 Göreli yol koşulduğu dizine göre kayar: cd'den SONRA mutlaklaştırılır, yoksa "$D/.." yanlış yere bakar.
D="$PWD"
SINAVLAR=(imar imar-defter devir-ayikla betik-bekcisi dersler-brif imar-ikinci-goz imar-kutu-bagimsizlik)
TOP=0; DUSEN_S=0; ATLANAN=0
for t in "${SINAVLAR[@]}"; do
  [ -f "./$t.test.sh" ] || { echo "✗ sınav yok: $t.test.sh" >&2; exit 3; }
  printf '%-32s ' "$t.test.sh"
  O="$(timeout 110 bash "./$t.test.sh" 2>&1)"; rc=$?
  n="$(printf '%s' "$O" | grep -oE '([0-9]+) geçti|geçti ([0-9]+)|geçen=([0-9]+)' | tail -1 | grep -oE '[0-9]+')"
  # 🔴 SAYAÇ KENDİ KAPI ADINI EŞLEMESİN (15 Eki, bu araçta bizzat oldu): bir kapının ADI
  #    "ATLANDI/⏭" kelimesini taşıyınca sayaç onu gerçek bir atlama sanıp 2 yerine 3 saydı.
  #    Gerçek atlama satırı kapı işaretiyle (✓/✗) BAŞLAMAZ; kapı satırları ayıklanır.
  a="$(printf '%s' "$O" | grep -vE '^[[:space:]]*[✓✗]' | grep -cE 'ATLANDI|⏭' || true)"
  TOP=$((TOP + ${n:-0})); ATLANAN=$((ATLANAN + a))
  [ "$rc" -ne 0 ] && DUSEN_S=$((DUSEN_S + 1))
  echo "rc=$rc geçti=${n:-?} atlanan=$a"
done
echo
echo "ÖLÇÜLEN KAPI = $TOP · ATLANAN (ölçülemedi, geçti SAYILMAZ) = $ATLANAN · DÜŞEN SINAV = $DUSEN_S"
[ "$ATLANAN" -gt 0 ] && echo "🔴 $ATLANAN kapı bu kutuda ÖLÇÜLEMEDİ (bağımlılık yok) — 'hepsi koştu' DENMEZ."
# 🔴 BELGEDEKİ SAYI BAYATLAMASIN (gözün tur-4 bulgusu): SKILL.md "176 · 2" diyordu, araç "183 · 1"
#    basıyordu — sayıyı bir kez yazıp sonra kapı ekleyince belgeyi tazelemeyi unutmuştum. Bayat sayı
#    ölçülmemiş sayıdan KÖTÜDÜR, çünkü ölçülmüş gibi durur. Sayıyı BİLEN araç belgeyi denetler.
#    🔴 Bu denetim neden SINAVDA değil BURADA: sınava koyunca kapı bu koşucuyu çağırıyordu, koşucu da
#    o sınavı — sonsuz özyineleme (aynı tuzağa bugün İKİNCİ kez düştüm; birincisi F1/F2'ydi).
SK="$(cd "$D/.." && pwd)/SKILL.md"
if [ -r "$SK" ]; then
  if grep -q "ÖLÇÜLEN $TOP kapı · ATLANAN $ATLANAN" "$SK"; then
    echo "✓ SKILL.md sayıları ölçümle uyuşuyor ($TOP · $ATLANAN)"
  else
    echo "🔴 SKILL.md BAYAT: belgede \"$(grep -o 'ÖLÇÜLEN [0-9]* kapı · ATLANAN [0-9]*' "$SK" | head -1)\" · ölçülen \"ÖLÇÜLEN $TOP kapı · ATLANAN $ATLANAN\""
    DUSEN_S=$((DUSEN_S + 1))
  fi
else
  echo "⏭️  SKILL.md okunamadı — belge/ölçüm uyumu ÖLÇÜLEMEDİ"
fi
[ "$DUSEN_S" -eq 0 ]
