#!/usr/bin/env bash
# onar.sh — sağlık bekleme bütçesi sınavı (hermetik; ağ/tmux/ttyd GEREKMEZ).
# Niçin: SEDİR 27 Eyl'de ölçtü — bellek sıkışıkken kapı 28 sn'de açıldı, 6 sn'lik bütçe
# "bozuk" deyip K1'e (yeni Claude) tırmanıyordu. Bütçe burada KİLİTLİ; kısalırsa kapı kırmızı.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { # ad · beklenen · gerçek
  if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"
  else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi
}

export TO_KUTU=sinav TO_DURUM_DIZ="$(mktemp -d)" TO_PROJE="$KOK"
# shellcheck disable=SC1091
. "$KOK/scripts/ortak.sh" || { echo "ortak.sh source edilemedi"; exit 2; }

echo "── B · bekleme bütçesi (gerçek bekle_saglam)"
kapi "B1 ttyd bütçesi ≥20 sn"  "e" "$([ "${TTYD_BEKLE:-0}" -ge 20 ] && echo e || echo h)"
kapi "B2 kapı bütçesi ≥40 sn"  "e" "$([ "${KAPI_BEKLE:-0}" -ge 40 ] && echo e || echo h)"

TO_BEKLE_ADIM=0.05          # sınav hızlandırması — çağrı sayısı aynı, gerçek kod yolu aynı
sayac=0
gec_saglam() { sayac=$((sayac+1)); [ "$sayac" -ge 28 ]; }   # 28. turda sağlıklı (ölçülen gerçek)
hic_saglam() { return 1; }

sayac=0; bekle_saglam gec_saglam "$KAPI_BEKLE"; rc=$?
kapi "B3 28 turda açılan kapı SAĞLIKLI sayılır" "0" "$rc"
kapi "B4 açılır açılmaz döner (boş yere beklemez)" "28" "$sayac"

sayac=0; bekle_saglam gec_saglam 6; rc=$?
kapi "B5 ESKİ 6 sn'lik bütçe aynı kapıyı KAÇIRIR (mutasyon kanıtı)" "1" "$rc"

sayac=0; bekle_saglam hic_saglam 3; rc=$?
kapi "B6 gerçekten bozuksa kırmızı döner" "1" "$rc"

echo "── K · çağıran gerçekten bu kapıyı kullanıyor mu"
kapi "K1 onar.sh ttyd beklemesini helper'dan çağırır" "1" \
  "$(grep -c 'bekle_saglam ttyd_saglam "\$TTYD_BEKLE"' "$KOK/scripts/onar.sh")"
kapi "K2 onar.sh kapı beklemesini helper'dan çağırır" "1" \
  "$(grep -c 'bekle_saglam kapi_saglam "\$KAPI_BEKLE"' "$KOK/scripts/onar.sh")"
kapi "K3 elle sayılı eski döngü kalmadı" "0" \
  "$(grep -c 'for i in 1 2 3 4 5' "$KOK/scripts/onar.sh")"

rm -r -- "$TO_DURUM_DIZ" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
