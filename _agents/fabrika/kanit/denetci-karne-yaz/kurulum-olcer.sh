#!/usr/bin/env bash
# kurulum-olcer.sh — göz #418 tur 1 bulgusu: denetci-kayit-commit.test.sh kurulum checkout'u düşünce yutuyordu (14/14 yeşil).
#   Sınavın KOPYASINDAN `export DENETCI_KARNE=0` satırı çıkarılır (tur 1 durumu: karne e kapısında dala girer, checkout düşer);
#   kurulum koruması çalışıyorsa kopya KIRMIZI biter. Çıkış 0 = kopya kırmızı + KURULUM-HATASI görüldü (koruma ölçüldü); 1 = yutuldu.
set -uo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/yazilim-fabrikasi/scripts"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
cp -r "$S/." "$T/"
python3 - "$T/denetci-kayit-commit.test.sh" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read(); a="export DENETCI_KARNE=0\n"; assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,""))
PY
bash "$T/denetci-kayit-commit.test.sh" < /dev/null > "$T/cikti.log" 2>&1; rc=$?
cat "$T/cikti.log"
echo "── kopya rc=$rc · 'would be overwritten' satırı: $(grep -c 'would be overwritten' "$T/cikti.log")"
[ "$rc" -ne 0 ] && grep -q "✗ e birincil checkout" "$T/cikti.log"
