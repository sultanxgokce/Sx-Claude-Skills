#!/bin/sh
# jargon-lint.sh — MOTOR proje-BİLMEZLİK regresyon-kilidi (L0: POSIX-sh, kendi-kendini de tarar).
# "PROMOTE-gate jargon-lint'te denetler" 3 yerde YAZILI ama script yoktu — bu onu kodlar.
# MOTOR-dosyaları (core/ + reference/ + scripts/teslim-lint.sh) hiçbir GERÇEK-proje adı/portu/roster-adı
# içeremez (config-driven kalmalı). Bulursa İSİMLİ-FAIL. Kendi dosya-adları/yorumları hariç tutulur değil —
# yasak-terimler öyle seçilir ki motor-metninde meşru geçmezler.
# Kullanım: jargon-lint.sh [--kok <skill-koku>]   (default: bu script'in iki-üst dizini = skill kökü)
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KOK="$SELF_DIR/.."   # core/ -> skill kökü
[ "${1:-}" = "--kok" ] && KOK="$2"

# Yasak-terim listesi (MOTOR-sabiti): gerçek-proje/port/roster/domain-tablo adları. Genişletilebilir.
# NOT: 'panel' gibi jenerik-UI-kavramı DIŞARIDA (false-positive) — yalnız kesin-proje-özgül terimler.
YASAK='mmex|mmepanel|sinanmmex|cabirmmex|sadikmmex|\bSINAN\b|\bCABIR\b|\bSultan\b|127\.0\.0\.1:8000|aron_legacy|ys_portal|cagri_merkezi|fis_konumu|slot_log|heal_state|reconcile'

# Taranan MOTOR-yüzeyi: core/*.mjs + core/*.sh + reference/*.md + scripts/teslim-lint.sh
# (selftest/ HARİÇ — testler soyut-fixture kullanır ama 'C-HAYALET' vb. içerebilir; motor-metni değil.
#  SKILL.md HARİÇ — frontmatter author:sultanxgokce meşru-metadata, motor-mantığı değil.)
HEDEFLER=""
for f in "$KOK"/core/*.mjs "$KOK"/core/*.sh "$KOK"/reference/*.md "$KOK"/scripts/teslim-lint.sh; do
  [ -f "$f" ] && HEDEFLER="$HEDEFLER $f"
done

IHLAL=0
for f in $HEDEFLER; do
  # kendi-kendini tarama: bu script YASAK-değişkeninin kendisini içerir → atla
  case "$f" in *jargon-lint.sh) continue ;; esac
  if grep -nEi "$YASAK" "$f" >/dev/null 2>&1; then
    echo "jargon-lint İHLAL: MOTOR-dosyasında proje-özgül terim: $f" >&2
    grep -nEi "$YASAK" "$f" | sed 's/^/    /' >&2
    IHLAL=1
  fi
done

if [ "$IHLAL" -eq 0 ]; then
  echo "jargon-lint: TEMİZ (MOTOR proje-bilmez)"
  exit 0
fi
echo "jargon-lint: KİRLİ — MOTOR proje-değeri gömemez (config-driven kalmalı)" >&2
exit 1
