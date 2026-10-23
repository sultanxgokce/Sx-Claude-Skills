#!/usr/bin/env bash
# kos-fabrika-sinavlari.sh — yazilim-fabrikasi sınavlarını TEK kopyada SIRAYLA koşar (MUT_PARALEL=2), her sınavın
# SONUÇ satırını ve rc'sini basar; biri bile kırmızıysa rc 1. Ham çıktılar geçici dizinde (yolu basılır).
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../yazilim-fabrikasi/scripts" && pwd)" || exit 3
O="$(mktemp -d)"; kirmizi=0
echo "sınav dizini: $S · ham çıktılar: $O"
for t in "$S"/*.test.sh; do
  a="$(basename "$t")"
  ( cd "$S" && MUT_PARALEL=2 timeout 1800 bash "$t" ) > "$O/$a.out" 2>&1 </dev/null; rc=$?
  son="$(grep -E 'SONUÇ|geçti' "$O/$a.out" | tail -1)"
  printf '%s rc=%s · %s\n' "$a" "$rc" "${son:-(sonuç satırı yok)}"
  [ "$rc" -eq 0 ] || kirmizi=$((kirmizi+1))
done
echo "kırmızı sınav: $kirmizi"
[ "$kirmizi" -eq 0 ]
