#!/usr/bin/env bash
# posta — ajanın posta komutu (POSTANE F1). Ayrıntı: posta.mjs başı.
# Kutu kabuğunda node PATH'te olmayabilir (31 Eki tellal, akar ölçüldü); o zaman kutunun nvm kökündeki en yeni sürüm kullanılır.
N="$(command -v node)" || N="$(ls -d "${POSTA_NVM:-/config/.nvm}"/versions/node/v*/bin/node 2>/dev/null | sort -V | tail -1)"
[ -n "$N" ] || { echo "✗ posta: node bulunamadı (PATH ve ${POSTA_NVM:-/config/.nvm})" >&2; exit 127; }
exec "$N" "$(dirname "$(readlink -f "$0")")/posta.mjs" "$@"
