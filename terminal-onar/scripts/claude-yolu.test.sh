#!/usr/bin/env bash
# claude-yolu.test.sh — JRCK8J (29 Eki, vekatip): koltuk bekçisi 500 baytlık "native binary not installed" kabuğu olan
# eski nvm sürümünü seçip koltuğu "Permission denied" ile açamadı. Sınav sahte nvm kökü kurar (hermetik): eski sürüm = kabuk,
# yeni sürüm = gerçek boyutlu ikili. Ölçülen: claude_yolu yeni olanı verir, kabuğu ASLA; hiçbiri geçerli değilse boş + rc 1.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T="$(mktemp -d)"; trap 'rm -r -- "$T" 2>/dev/null' EXIT
export TO_KUTU=sinav TO_DURUM_DIZ="$T/durum" TO_PROJE="$KOK"
# shellcheck disable=SC1091
. "$KOK/scripts/ortak.sh" || { echo "ortak.sh source edilemedi"; exit 2; }

kur() {  # $1 = kök · eski sürüm = 500 baytlık kabuk, yeni sürüm = 2 MB ikili
  local k="$1" v
  for v in v22.23.0 v22.23.1; do mkdir -p "$k/$v/bin" "$k/$v/lib"; printf '#!/bin/sh\n' > "$k/$v/bin/node"; chmod +x "$k/$v/bin/node"; done
  head -c 500 /dev/zero > "$k/v22.23.0/lib/claude.exe"; chmod +x "$k/v22.23.0/lib/claude.exe"; ln -s ../lib/claude.exe "$k/v22.23.0/bin/claude"
  head -c 2097152 /dev/zero > "$k/v22.23.1/lib/claude.exe"; chmod +x "$k/v22.23.1/lib/claude.exe"; ln -s ../lib/claude.exe "$k/v22.23.1/bin/claude"
}
K="$T/nvm"; kur "$K"
cozum() { ( PATH="$1:/usr/bin:/bin" TO_NVM_KOK="$K" claude_yolu 2>/dev/null ); }

echo "── 1) claude_yolu çalışan ikiliyi seçer"
kapi "Y1 bayat PATH eski (kabuk) sürümü gösterirken YENİ sürüm seçilir" "$K/v22.23.1/bin/claude" "$(cozum "$K/v22.23.0/bin")"
kapi "Y2 PATH'te claude yokken en yeni geçerli sürüm seçilir" "$K/v22.23.1/bin/claude" "$(cozum "/yok")"
kapi "Y3 PATH zaten geçerli olanı gösteriyorsa o korunur" "$K/v22.23.1/bin/claude" "$(cozum "$K/v22.23.1/bin")"
rm "$K/v22.23.1/bin/claude"
kapi "Y4 yeni sürümde claude yoksa kabuğa DÜŞMEZ (boş döner)" "" "$(cozum "$K/v22.23.0/bin")"
( PATH="/usr/bin:/bin" TO_NVM_KOK="$K" claude_yolu >/dev/null 2>&1 ); kapi "Y4b … ve rc 1 (ölçülemedi, uydurma yol yok)" "1" "$?"
ln -s ../lib/claude.exe "$K/v22.23.1/bin/claude"

echo "── 2) PATH'e giren node dizini claude'un dizini"
kapi "N1 _node_yolu claude'un geçerli olduğu sürümü verir" "$K/v22.23.1/bin" "$( PATH="$K/v22.23.0/bin:/usr/bin:/bin" TO_NVM_KOK="$K" _node_yolu 2>/dev/null )"

echo "── 3) çağıranlar gerçekten kullanıyor"
kapi "C1 onar.sh claude_baslat komutu mutlak yola çevirir" "1" "$(grep -c 'claude_yolu' "$KOK/scripts/onar.sh")"
kapi "C2 koltuk-ac.sh dava yolu claude_yolu ile çözer" "1" "$(grep -c 'TO_CLAUDE:-\$(claude_yolu' "$KOK/scripts/koltuk-ac.sh")"

echo "── 4) mutant: ölçüt kaldırılırsa sınav DÜŞER"
MU="$T/mutant"; mkdir -p "$MU"; sed 's/-ge 1048576/-ge 0/' "$KOK/scripts/ortak.sh" > "$MU/ortak.sh"
kapi "M1 mutant gerçekten uygulandı" "h" "$(cmp -s "$KOK/scripts/ortak.sh" "$MU/ortak.sh" && echo e || echo h)"
kapi "M1b mutantta bayat PATH kabuğu seçer (Y1 bunu yakalar)" "$K/v22.23.0/bin/claude" \
  "$( PATH="$K/v22.23.0/bin:/usr/bin:/bin" TO_NVM_KOK="$K" TO_KUTU=sinav TO_DURUM_DIZ="$T/durum2" TO_PROJE="$KOK" bash -c ". '$MU/ortak.sh' && claude_yolu" 2>/dev/null )"

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
