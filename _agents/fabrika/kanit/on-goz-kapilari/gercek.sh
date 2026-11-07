#!/usr/bin/env bash
# gercek.sh — HEAD'in on-goz.py'sini gerçek bir iş alanında koşar. İlk hedef Nexus on-goz-olc (#1572) alanıydı: ilk koşu (7 Kas 01:2x) A1'de gerçek bir
#   bayat kayıt buldu, kayıt yeniden alındı, UYUMLU döndü. #1572 birleşip alanı kapanınca (7 Kas 01:4x) hedef BU işin kendi alanı oldu (itilmiş baş,
#   PR #737): araç kendi PR'ını ölçer. ALAN ve IS ile başka alan verilebilir.
set -u; R="$(git rev-parse --show-toplevel)"; A="${ALAN:-$R}"; I="${IS:-on-goz-kapilari}"
[ -d "$A" ] || { echo "ÖLÇÜLEMEDİ: iş alanı yok ($A)"; exit 3; }
cd "$A" && python3 "$R/yazilim-fabrikasi/scripts/on-goz.py" "$I" ${PR:+--pr "$PR"}; exit $?
