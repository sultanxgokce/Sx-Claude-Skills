#!/usr/bin/env bash
# posta — ajanın posta komutu (POSTANE F1). Ayrıntı: posta.mjs başı.
exec node "$(dirname "$(readlink -f "$0")")/posta.mjs" "$@"
