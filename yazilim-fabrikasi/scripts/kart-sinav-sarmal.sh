#!/usr/bin/env bash
# kart-sinav-sarmal.sh — YALNIZ SINAVLAR için: `kart.sh ac` görev kimliği ya da --gorevsiz ister (görev …DZJ0D);
# sınavların yüzlerce fikstür kartı görev defterine bağlı değildir. Bu sarmal, bayrak verilmemişse açık gerekçeli
# --gorevsiz ekler; başka hiçbir şeye karışmaz. Kuralın kendisi kart.test.sh'ta GERÇEK kart.sh ile sınanır.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = ac ]; then
  v=0; for a in "$@"; do case "$a" in --gorev|--gorevsiz) v=1 ;; esac; done
  [ "$v" = 1 ] || exec bash "$HERE/kart.sh" "$@" --gorevsiz "sınav fikstürü: görev defteri yok"
fi
exec bash "$HERE/kart.sh" "$@"
