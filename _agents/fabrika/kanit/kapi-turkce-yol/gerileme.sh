#!/usr/bin/env bash
# gerileme.sh — HEAD'i geçici dizine çıkarır, kapının ana sınavını koşar (son satır + düşenler).
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD | tar -x -C "$T" || exit 3
bash "$T/yazilim-fabrikasi/scripts/birlestirme-kapisi.test.sh" 2>&1 | grep -E '✗|SONUÇ|geçti'; exit "${PIPESTATUS[0]}"
