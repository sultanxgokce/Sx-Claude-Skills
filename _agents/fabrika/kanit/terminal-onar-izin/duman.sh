#!/usr/bin/env bash
# terminal-onar'ı GERÇEK sync-skills.mjs ile sahte bir hedefe kurar ve duman testinin hükmünü basar.
# Gerçek /config/.claude'a dokunmaz. Kullanım: duman.sh <depo-kökü>   (rc 0 = duman temiz)
set -u
KOK="${1:?depo kökü}"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
cp "$KOK/sync-skills.mjs" "$T/"
cp -rp "$KOK/terminal-onar" "$T/"
mkdir -p "$T/hedef"
printf '{"targets":{"_t":"%s/hedef"},"install":{"terminal-onar":["_t"]}}\n' "$T" > "$T/sync-targets.json"
out="$(cd "$T" && node sync-skills.mjs --apply --skill terminal-onar 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -E 'ÇALIŞTIRILAMAZ|SÖZDİZİMİ|DUMAN|özet' || true
echo "sync-skills rc=$rc"
exit "$rc"
