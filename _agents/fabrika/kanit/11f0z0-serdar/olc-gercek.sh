#!/usr/bin/env bash
# olc-gercek.sh — kart 11f0z0-serdar: GERÇEK görev defterinde `merkez --hafta 2026-W43` koşusu.
#   Kök geçici bir kopyadır (Nexus ana ağacına yazılmaz): yalnız aile-registry.yaml kopyalanır → katılım ÇALIŞMADI (iz yok),
#   havuz köprüsü ise gerçektir: bu deponun bulgu/scripts/bulgu.sh (retro.py'nin varsayılan kardeş yolu) + /config/defter-jeton.
#   Basılan: merkez rc · MERKEZ.md'deki havuz satırı sayısı · köprünün o anki ham sayısı (aynı an, aynı kaynak) · satırlar.
#   Kart cümlesindeki "6 havuz satırı" 22 Eki ANLIK sayımdır; defter canlıdır, koşu anındaki sayı köprü sayısıyla birlikte basılır.
set -uo pipefail
R="${RETRO_PY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/retro/scripts/retro.py}"
BSH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/bulgu/scripts/bulgu.sh"
T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
KOK="$T/nexus-kopya"; mkdir -p "$KOK/_agents/handoff"
cp /config/projects/Nexus/_agents/handoff/aile-registry.yaml "$KOK/_agents/handoff/aile-registry.yaml"
kopru_ham="$(bash "$BSH" havuz-cek 2>/dev/null | grep -c '"durum": "ham"')"
python3 "$R" merkez --hafta 2026-W43 --kok "$KOK" > "$T/merkez.out" 2>&1; mrc=$?
M="$KOK/_agents/handoff/retro/2026-W43/MERKEZ.md"
n=0; [ -f "$M" ] && n="$(grep -cE '^- gorev_[0-9A-Z]{26} · ' "$M")"
echo "merkez_rc=$mrc havuz_satiri=$n kopru_ham=$kopru_ham"
grep -E 'MERKEZ.md iskeleti|ÖLÇÜLEMEDİ' "$T/merkez.out"
[ -f "$M" ] && sed -n '/^## Havuz süzümü/,/^## Dersler/p' "$M" | grep -E '^(## Havuz|- gorev_|_\()' | cut -c1-120
exit 0
