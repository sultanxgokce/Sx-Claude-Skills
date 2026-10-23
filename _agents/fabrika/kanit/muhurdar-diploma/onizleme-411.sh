#!/usr/bin/env bash
# onizleme-411.sh — birleşme önizlemesi: bu dalın tescil'i + açık Sx #411'in sicil yazıcısı (muhurdar.sh + lib/sicil.py + SKILL.md)
# geçici kopyada; diploma.test.sh orada koşulur → sicil ayrımı mutantı ve gerçek sicil sözleşmesi (i2) ÖLÇÜLÜR. Dal değişmez.
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
git -C "$K" fetch -q origin muhurdar-sicil || { echo "ÖLÇÜLEMEDİ: #411 dalı alınamadı"; exit 3; }
echo "── #411 başı: $(git -C "$K" rev-parse --short FETCH_HEAD)"
cp -r "$K/tescil" "$T/tescil"
for f in tescil/scripts/muhurdar.sh tescil/scripts/lib/sicil.py tescil/SKILL.md; do git -C "$K" show "FETCH_HEAD:$f" > "$T/$f"; done
bash "$T/tescil/scripts/diploma.test.sh"
