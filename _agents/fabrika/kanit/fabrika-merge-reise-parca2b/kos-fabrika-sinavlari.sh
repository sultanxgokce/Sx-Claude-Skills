#!/usr/bin/env bash
# kos-fabrika-sinavlari.sh — kart.sh'a dokunan fabrika sınavlarını TEK kopyada SIRAYLA koşar (MUT_PARALEL=2), her sınavın
# SONUÇ satırını ve rc'sini basar; biri bile kırmızıysa rc 1. Ham çıktılar geçici dizinde (yolu basılır).
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../yazilim-fabrikasi/scripts" && pwd)" || exit 3
O="$(mktemp -d)"; kirmizi=0
echo "sınav dizini: $S · ham çıktılar: $O"
for a in kart.test.sh birlestirme-kapisi.test.sh denetci.test.sh is-alani.test.sh denetci-fark-kendisi.test.sh; do
  ( cd "$S" && MUT_PARALEL=2 timeout 1800 bash "$a" ) > "$O/$a.out" 2>&1 </dev/null; rc=$?
  son="$(grep -E 'SONUÇ|geçti' "$O/$a.out" | tail -1)"
  printf '%s rc=%s · %s\n' "$a" "$rc" "${son:-(sonuç satırı yok)}"
  [ "$rc" -eq 0 ] || kirmizi=$((kirmizi+1))
done
echo "kırmızı sınav: $kirmizi"
[ "$kirmizi" -eq 0 ]
