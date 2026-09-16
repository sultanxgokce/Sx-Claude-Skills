#!/usr/bin/env bash
# miras-damga.sh — rol çekirdeğinin runtime kimliği: sürüm + içerik sha (ilk 12 hane).
# Mirasçı AGENT.md'ye "miras: ekip-iletisim-uzmani@<sürüm> sha=<damga>" yazar; çekirdek değişince
# damga değişir → bayat mirasçı "güncel" diyemez (NÂZIR kabul kapısı: miras zinciri ölçülebilir).
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SURUM="$(sed -n 's/^version:[[:space:]]*//p' "$KOK/SKILL.md" | head -1)"
[ -n "$SURUM" ] || { echo "damga: SKILL.md sürümü okunamadı" >&2; exit 2; }
[ -f "$KOK/ROL-CEKIRDEGI.md" ] || { echo "damga: ROL-CEKIRDEGI.md yok" >&2; exit 2; }
SHA="$(cat "$KOK/ROL-CEKIRDEGI.md" "$KOK/scripts/iletisim-nabiz.sh" | sha256sum | cut -c1-12)"
printf 'ekip-iletisim-uzmani@%s sha=%s\n' "$SURUM" "$SHA"
