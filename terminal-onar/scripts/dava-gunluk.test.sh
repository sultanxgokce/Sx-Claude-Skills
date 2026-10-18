#!/usr/bin/env bash
# dava-gunluk.test.sh — Dava Rafı günlük turu kapısı (hermetik: geçici durum dizini, tur yerine sayaç komutu, tarih ortamdan).
# Ölçülür: ilk koşu turu çağırır ve damgalar · aynı gün ikinci koşu ÇAĞIRMAZ (yeni uygun dava olsa bile — kapı tarihe bakar) ·
# tur düşse de damga yazılıdır, aynı gün tekrar yok · ertesi gün yeniden koşar · damga yazılamazsa tur KOŞMAZ · bekçi kapıyı çağırır.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$D/dava-gunluk.sh"; T="$(mktemp -d)"; trap 'chmod -R u+w "$T"; rm -r "$T"' EXIT
gecen=0; kalan=0; kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
mkdir -p "$T/durum"; : > "$T/sayac"
export TO_DURUM_DIZ="$T/durum" DAVA_TUR_KOMUT="echo x >> '$T/sayac'; exit \${TUR_RC:-0}"
say() { wc -l < "$T/sayac" | tr -d ' '; }
kos() { DAVA_BUGUN="$1" bash "$S" 2>"$T/hata"; }

kos 2026-10-18; rc=$?
kapi "G1 günün ilk koşusu turu çağırır, damga = bugün" "0|1|2026-10-18" "$rc|$(say)|$(cat "$T/durum/dava-bekci.gun")"
kos 2026-10-18; kos 2026-10-18
kapi "G2 aynı gün sonraki koşular turu ÇAĞIRMAZ (kapı tarihe bakar, uygun dava olup olmadığına değil)" "1" "$(say)"
TUR_RC=3 kos 2026-10-19; TUR_RC=3 kos 2026-10-19
kapi "G3 ertesi gün koşar; tur düşse de (rc 3) damga yazılı, aynı gün tekrar denenmez" "2|2026-10-19" "$(say)|$(cat "$T/durum/dava-bekci.gun")"
kos 2026-10-20
kapi "G4 sonraki gün yeniden koşar" "3" "$(say)"
chmod a-w "$T/durum"; kos 2026-10-21; rc=$?; chmod u+w "$T/durum"
kapi "G5 damga yazılamazsa tur KOŞMAZ (her dakika koşmasın), rc 0, sebebi söylenir" "0|3|1" "$rc|$(say)|$(grep -c 'damga yazılamadı' "$T/hata")"
kapi "G6 bekçi turu bu kapıdan çağırır (doğrudan dava-bekci.mjs çağrısı yok)" "1|0" \
  "$(grep -c 'bash "$BETIK_DIZ/dava-gunluk.sh"' "$D/bekci.sh")|$(grep -c 'kapi/dava-bekci.mjs' "$D/bekci.sh")"

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
