#!/usr/bin/env bash
# gercek.sh — HEAD'in on-goz.py'sini gerçek bir iş alanında koşar: Nexus on-goz-olc (#1572, dilim 1). İlk koşu (7 Kas 01:2x) A1'de gerçek bir
#   bayat kayıt buldu (pozitif-kontrol O8 düzeltmesinden önceki commit'te); kayıt yeniden alındı, şimdi UYUMLU beklenir.
set -u; R="$(git rev-parse --show-toplevel)"; A="${ALAN:-/config/projects/_wt/Nexus-on-goz-olc}"
[ -d "$A" ] || { echo "ÖLÇÜLEMEDİ: iş alanı yok ($A)"; exit 3; }
cd "$A" && python3 "$R/yazilim-fabrikasi/scripts/on-goz.py" on-goz-olc; exit $?
