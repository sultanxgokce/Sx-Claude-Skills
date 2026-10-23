#!/usr/bin/env bash
# bassiz-olcer.sh <tescil-dizini> — S14 başsız şapka ölçümü: verilen tescil ağacının KOPYASINDA bu dalın muhurdar.test.sh'ını koşar,
#   başsız kapılarını (u: başsız mühür + sicil bassiz e · v: başsız koşu kendi-işi kuralına tabi) ayrı basar. Önce = origin/main
#   tescil (kapılar yok → kırmızı), sonra = dal (yeşil). Gerçek sicile dokunmaz (sınav hermetik).
set -uo pipefail
KAYNAK="$(cd "$1" && pwd)"; SINAV="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/tescil/scripts/muhurdar.test.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
cp -r "$KAYNAK" "$T/tescil"; cp "$SINAV" "$T/tescil/scripts/muhurdar.test.sh"
bash "$T/tescil/scripts/muhurdar.test.sh" < /dev/null > "$T/cikti" 2>&1; rc=$?
for k in u v; do grep -E "^  [✓✗] $k " "$T/cikti" || echo "  ✗ $k (kapı satırı yok)"; done
grep -E "^── SONUÇ|kaldı" "$T/cikti" | tail -1
[ $rc -eq 0 ] && echo "── başsız şapka: ✓ ölçüldü (sınav rc 0)" || echo "── başsız şapka: ✗ (sınav rc $rc)"
exit $rc
