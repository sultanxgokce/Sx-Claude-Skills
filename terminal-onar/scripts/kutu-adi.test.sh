#!/usr/bin/env bash
# Kutu adı çözümü — beceri hangi kutunun içinde olduğunu doğru biliyor mu?
#
# Niçin var (ölçülmüş, 2026-09-29): çözüm zincirinin 2. halkası ÖLÜ KODDU
# (`for c in /config/projects/*/; do :; done` — döngü değişkeni hiç kullanılmıyordu),
# akış doğrudan makine adına düşüyordu. Kabın makine adı rastgele bir kimlik olan kutuda
# (SEDİR: `f517818d622f`) beceri kutuyu o kimlik sandı: tmux adları, kasa anahtarı ve
# TABAN yolu hep yanlış türedi. Belirti sinsiydi — hata vermiyor, YANLIŞ AD üretiyordu.
set -u
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kur() { # sahte kutu kur: $1 = kutu adı → kurulu becerinin ortak.sh yolunu basar
  local ad="$1" d="$2"
  mkdir -p "$d/projects/$ad/.claude/skills/terminal-onar/scripts"
  cp "$KOK/scripts/ortak.sh" "$d/projects/$ad/.claude/skills/terminal-onar/scripts/"
  echo "$d/projects/$ad/.claude/skills/terminal-onar/scripts/ortak.sh"
}
oku() { # $1 = ortak.sh yolu → çözülen KUTU adı ("?" = çözülemedi)
  env -u TO_KUTU -u TO_PROJE HOME=/tmp bash -c '
    set +u
    . "$1" >/dev/null 2>&1
    echo "${KUTU:-?}"' _ "$1" 2>/dev/null | tail -1
}

T=$(mktemp -d)
echo "── kurulu olduğu yerden türetme"
kapi "K1 kutu adı kurulum yolundan çözülür" "sedir" "$(oku "$(kur sedir "$T")")"
kapi "K2 başka bir kutuda o kutunun adı çözülür" "akar" "$(oku "$(kur akar "$T")")"
kapi "K3 makine adına DÜŞMÜYOR (rastgele kimlikli kap)" "e" \
  "$([ "$(oku "$(kur tellal "$T")")" = "tellal" ] && echo e || echo h)"

echo "── açık beyan her şeyin üstünde"
p=$(kur sedir "$T")
kapi "K4 TO_KUTU verilirse o kazanır" "baska" \
  "$(env -u TO_PROJE TO_KUTU=baska HOME=/tmp bash -c 'set +u; . "$1" >/dev/null 2>&1; echo "${KUTU:-?}"' _ "$p" 2>/dev/null|tail -1)"

rm -r -- "$T" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
