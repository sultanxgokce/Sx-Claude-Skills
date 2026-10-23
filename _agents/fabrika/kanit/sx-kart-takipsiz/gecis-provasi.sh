#!/usr/bin/env bash
# gecis-provasi.sh <hedef ref> — Sx ana kopyasının BUGÜNKÜ hâli (layiha-global-20260722 dalı + diskteki takipsiz kart dosyaları) bir
#   klonda kurulur, sonra hedef ref'e geçiş (git switch) denenir. Ana kopyaya DOKUNMAZ.
#   Çıkış 0 = geçiş oldu VE kart dizini bayt bayt aynı kaldı · 1 = geçiş reddedildi ya da kartlar değişti · 3 = kurulamadı.
set -uo pipefail
A=/config/projects/Sx-Claude-Skills; REF="$1"; KD=_agents/fabrika/kartlar
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
S="$T/sim"; git clone -q --no-checkout --shared "$A" "$S" || exit 3
git -C "$S" fetch -q "$(git -C "$A" rev-parse --show-toplevel)" "$REF" 2>/dev/null || git -C "$S" fetch -q origin "$REF" || exit 3
H="$(git -C "$S" rev-parse FETCH_HEAD)"
git -C "$S" checkout -q -B ana "$(git -C "$A" rev-parse HEAD)" || exit 3
mkdir -p "$S/$KD"; cp -a "$A/$KD/." "$S/$KD/"
once="$(cd "$S/$KD" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
echo "ana kopya: $(git -C "$A" rev-parse --abbrev-ref HEAD) $(git -C "$A" rev-parse --short HEAD) · kart diskte $(ls "$S/$KD" | wc -l) · hedef $(git -C "$S" rev-parse --short "$H") (takipli kart $(git -C "$S" ls-tree -r --name-only "$H" -- "$KD" | wc -l))"
if git -C "$S" switch -q --detach "$H" 2> "$T/err"; then
  sonra="$(cd "$S/$KD" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
  echo "geçiş: OLDU · kart dizini bayt bayt aynı: $([ "$once" = "$sonra" ] && echo evet || echo HAYIR)"
  [ "$once" = "$sonra" ]
else
  echo "geçiş: REDDEDİLDİ — $(head -1 "$T/err") (+$(grep -c 'kartlar/' "$T/err") kart satırı)"; exit 1
fi
