#!/usr/bin/env bash
# kanit-pr-kontrol.sh <taban-ref> — "Kanıt PR kontrolü" iş akışının gövdesi (sınanabilsin diye betikte).
# YALNIZ _agents/ altı değişen PR'ı denetler: kanıt/kart JSON'ları ayrışıyor mu. Kod (ya da _agents dışı başka bir şey) de
# değişiyorsa DENETLEMEZ: o PR'ı lint.yml zaten koşturur; bu iş "atlandı" der ve 0 döner.
# Çıkış: 0 temiz ya da atlandı · 1 bozuk JSON · 2 kullanım.
set -euo pipefail
taban="${1:-}"; [ -n "$taban" ] || { echo "kullanım: kanit-pr-kontrol.sh <taban-ref>" >&2; exit 2; }
git diff --name-only --diff-filter=AM "$taban...HEAD" > "${TMPDIR:-/tmp}/kpk-degisen.$$"
trap 'rm -f "${TMPDIR:-/tmp}/kpk-degisen.$$"' EXIT
d="${TMPDIR:-/tmp}/kpk-degisen.$$"
echo "değişen dosya: $(wc -l < "$d")"
if grep -qv '^_agents/' "$d"; then echo "atlandı: _agents dışı dosya da değişiyor (kod PR'ı; lint.yml koşar)"; exit 0; fi
bozuk=0
while IFS= read -r f; do
  case "$f" in
    _agents/*/kanit/*.json|_agents/fabrika/kartlar/*.json)
      python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$f" || { echo "::error file=$f::JSON ayrışmıyor"; bozuk=1; } ;;
  esac
done < "$d"
[ "$bozuk" -eq 0 ] || exit 1
echo "kanıt dosyaları ayrışıyor"
