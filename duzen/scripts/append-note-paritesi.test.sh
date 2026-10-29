#!/usr/bin/env bash
# append-note-paritesi.test.sh — paketlenmiş append-note.sh'ın bütünlüğü ve Nexus kanoniğiyle eşitliği (gorev-yolu Y7 emsali).
# P1 paketlenmiş kopya var ve sözdizimi geçerli · P2 ajan-defteri satırına saat damgası + ÇIPA başlığı yazar (işlev)
# P3 var olmayan dosyaya yazmaz (rc 1) · P4 Nexus kanoniği bu kutuda varsa md5 EŞİT (drift yok; sapmışsa kanoniği buraya kopyala)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; A="$HERE/append-note.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }

bash -n "$A" 2>/dev/null; ok "P1 paketlenmiş append-note.sh var ve sözdizimi geçerli" "$([ $? -eq 0 ] && [ -f "$A" ] && echo 0 || echo 1)"
mkdir -p "$T/_agents/test"; printf '# defter\n' > "$T/_agents/test/NOTES.md"
APPEND_NOTE_SIMDI=1793264400 bash "$A" "$T/_agents/test/NOTES.md" "- [BÂNİ → SERDAR] deneme" >/dev/null 2>&1; rc=$?
ok "P2 ajan defterine ÇIPA başlığı + saat damgası yazar" "$([ $rc -eq 0 ] && grep -qx '## ÇIPA 2026-10-29' "$T/_agents/test/NOTES.md" && grep -qE '^\- \[BÂNİ → SERDAR 29 Eki [0-9]{2}:[0-9]{2}\] deneme$' "$T/_agents/test/NOTES.md" && echo 0 || echo 1)" "→ rc=$rc $(tail -2 "$T/_agents/test/NOTES.md")"
bash "$A" "$T/yok.md" "x" >/dev/null 2>&1; rc=$?; ok "P3 var olmayan dosyayı AÇMAZ (rc 1)" "$([ $rc -eq 1 ] && [ ! -e "$T/yok.md" ] && echo 0 || echo 1)" "→ rc=$rc"
KAN="${DUZEN_APPEND_NOTE_KANONIK:-/config/projects/Nexus/scripts/append-note.sh}"
if [ -f "$KAN" ]; then
  a="$(md5sum < "$KAN" | cut -d' ' -f1)"; b="$(md5sum < "$A" | cut -d' ' -f1)"
  ok "P4 Nexus kanoniğiyle md5 EŞİT ($b)" "$([ "$a" = "$b" ] && echo 0 || echo 1)" "→ kanonik $a ≠ paket $b (kanoniği buraya yeniden kopyala)"
else echo "  · P4 atlandı: Nexus kanoniği bu kutuda yok (eşitlik ölçülemedi)"; fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
