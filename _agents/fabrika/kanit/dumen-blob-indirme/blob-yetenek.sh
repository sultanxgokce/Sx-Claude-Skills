#!/usr/bin/env bash
# blob-yetenek.sh <once|sonra> — sayfaya gömülü (blob:) dosyayı indirme yeteneği. once: ana daldaki sürücü · sonra: bu daldaki sürücü. Sınav dosyası aynı.
set -u; K="${1:?once|sonra}"; R="$(git rev-parse --show-toplevel)"; D="$R/dumen-surucu/scripts"
CH="${DUMEN_CHROME:-$(ls -d /config/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)}"
[ -x "$CH" ] || { echo "ÖLÇÜLEMEDİ: headless Chromium yok"; exit 3; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
if [ "$K" = once ]; then git -C "$R" show origin/main:dumen-surucu/scripts/dumen.mjs > "$T/dumen.mjs" || { echo "ÖLÇÜLEMEDİ: ana daldaki sürücü okunamadı"; exit 3; }
else cp "$D/dumen.mjs" "$T/dumen.mjs"; fi
C="$(DUMEN_CHROME="$CH" DUMEN_LIB="$T/dumen.mjs" timeout 200 node "$D/dumen-dosya.test.mjs" 2>&1)"; RC=$?
G="$(printf '%s\n' "$C" | grep -c '^  ✓ B[0-9] ')"
printf '%s\n' "$C" | grep -E '^  [✓✗] B[0-9] |SINAV ÇÖKTÜ|SONUÇ' | cut -c1-200
echo "blob kapısı geçen: $G/8 (sürücü: $K) rc=$RC"
[ "$G" -eq 8 ] && [ "$RC" -eq 0 ]
