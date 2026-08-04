#!/usr/bin/env bash
# wa-preflight.sh <proje-kökü> — Baileys entegrasyon deterministik denetim eli.
#
# Salt-okur · zero-dep · INERT · value-safe. Baileys-pairing'i kıran bilinen anti-desenleri tarar.
# DEĞİŞMEZ: eşleşen-satır-metni / env-değeri / auth-içeriği ASLA basılmaz. Bulgu formatı yalnızca:
#   dosya:satır  KURAL  [KIRMIZI|UYARI]
#
# RC: 0 = KIRMIZI yok (temiz ya da yalnız UYARI) · 1 = ≥1 KIRMIZI · 2 = kullanım/yol hatası.

set -u

ROOT="${1:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "kullanım: wa-preflight.sh <proje-kökü>   (dizin bulunamadı)" >&2
  exit 2
fi

RED=0
WARN=0

# Salt file:line üret (eşleşen METİN düşürülür → value-safe). Path'lerde ':' beklenmez.
emit() {  # <regex> <kural> <seviye>
  local pat="$1" rule="$2" level="$3"
  grep -rnI --include='*.ts' --include='*.js' --include='*.mjs' --include='*.cjs' \
       --include='*.sh' --exclude-dir=node_modules --exclude-dir=.git \
       -E "$pat" "$ROOT" 2>/dev/null | cut -d: -f1,2 | while IFS= read -r loc; do
    printf '%s  %s  [%s]\n' "$loc" "$rule" "$level"
  done
}

count() {  # <regex> → eşleşme sayısı (value görmez)
  grep -rnI --include='*.ts' --include='*.js' --include='*.mjs' --include='*.cjs' \
       --include='*.sh' --exclude-dir=node_modules --exclude-dir=.git \
       -E "$1" "$ROOT" 2>/dev/null | wc -l | tr -d ' '
}

# --- KIRMIZI kurallar ---
# 1) Bayat-sürüm API'si (#2679) — fetchLatestWaWebVersion olmalı.
n=$(count 'fetchLatestBaileysVersion')
if [ "$n" -gt 0 ]; then emit 'fetchLatestBaileysVersion' 'BAYAT-SURUM-API(#2679)' 'KIRMIZI'; RED=$((RED+n)); fi

# 2) Yanlış browser imzası (#2306/#1761) — Browsers.ubuntu olmalı.
n=$(count 'Browsers\.macOS')
if [ "$n" -gt 0 ]; then emit 'Browsers\.macOS' 'YANLIS-BROWSER(#2306)' 'KIRMIZI'; RED=$((RED+n)); fi

# 3) Auth-silen dal — auth dizinini silen ifade (throttle #2691 kaynağı). Heuristik: gözden geçir.
AUTHDEL='(rm[[:space:]]+-rf|rmSync|unlinkSync|rimraf)[^;\n]*[Aa]uth'
n=$(count "$AUTHDEL")
if [ "$n" -gt 0 ]; then emit "$AUTHDEL" 'AUTH-SILEN-DAL(#2691)' 'KIRMIZI'; RED=$((RED+n)); fi

# --- UYARI kurallar ---
# 4) Gevşek Baileys pin — exact pin (@...@7.0.0-rc13) önerilir; ^/~ gevşek.
PINLOOSE='@whiskeysockets/baileys.*[\^~]'
n=$(count "$PINLOOSE")
if [ "$n" -gt 0 ]; then emit "$PINLOOSE" 'PIN-GEVSEK' 'UYARI'; WARN=$((WARN+n)); fi

# 5) Tek-instance-kilidi yok mu — advisory-lock/flock hiç geçmiyorsa çift-socket riski (mimari A).
if [ "$(count 'pg_try_advisory_lock|flock|O_EXCL')" -eq 0 ]; then
  printf '%s  %s  [%s]\n' "$ROOT" 'TEK-INSTANCE-KILIDI-YOK' 'UYARI'
  WARN=$((WARN+1))
fi

echo "---"
echo "özet: KIRMIZI=$RED  UYARI=$WARN"
if [ "$RED" -gt 0 ]; then exit 1; fi
exit 0
