#!/usr/bin/env bash
# --kaynak yolu kutuda iz bırakıyor mu? Koşudan önce/sonra kutunun /tmp'sindeki dizin sayısı + koşucunun açtığı adla eşleşen kalıntı.
set -u; K="${1:?kutu}"; KAYNAK="${2:?terminal-onar}"
say() { timeout 30 ssh -o BatchMode=yes hostsrv "docker exec $K sh -c 'find /tmp -maxdepth 1 -type d -newer /proc/1 -name \"tmp.*\" -exec test -f {}/kapi/koltuk-fark.mjs \; -print 2>/dev/null | wc -l'"; }
o=$(say); bash "$(dirname "$0")/../../../../terminal-onar/scripts/koltuk-fark-filo.sh" --kaynak "$KAYNAK" "$K" | tail -n 1; s=$(say)
echo "$K: koşucu kalıntısı önce=$o sonra=$s"; [ "$s" = 0 ]
