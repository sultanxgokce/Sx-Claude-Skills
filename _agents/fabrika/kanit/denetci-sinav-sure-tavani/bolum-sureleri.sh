#!/usr/bin/env bash
# bolum-sureleri.sh <denetci.test.sh yolu> [DENETCI_PARCA] — sınavı saat damgalı koşturur, bölüm (════/──) başına geçen süreyi basar.
# Çıkış: sınavın kendi rc'si. (önce: origin/main kopyası, bölünmemiş · sonra: bu dal, parça 1/3)
set -u; T="$1"; P="${2:-}"; L="$(mktemp)"; T0=$(date +%s)
( cd "$(dirname "$T")" && env ${P:+DENETCI_PARCA=$P} bash "$(basename "$T")" 2>&1 ) | while IFS= read -r l; do printf '%s %s\n' "$(( $(date +%s) - T0 ))" "$l"; done > "$L"; rc=${PIPESTATUS[0]}
awk -v son=$(( $(date +%s) - T0 )) '/════|^[0-9]+ ──|\(bilgi\)|SONUÇ/{ if (ad!="") printf "%5d sn  %s\n", $1-bas, ad; bas=$1; ad=substr($0,index($0,$2),80) } END{ printf "%5d sn  %s\n", son-bas, ad }' "$L"
echo "TOPLAM $(( $(date +%s) - T0 )) sn · rc=$rc · $(grep -oE 'SONUÇ: [0-9]+ geçti · [0-9]+ kaldı' "$L" | tail -1)"; rm -f "$L"; exit $rc
