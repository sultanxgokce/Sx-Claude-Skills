#!/usr/bin/env bash
# sizinti-olcer.sh <komut…> — komut (denetçi sınavı) koşarken GERÇEK sinyal kütüğüne sınav işinden (is-*) zil düştü mü?
#   SERDAR 21:18: sınavdan 'BILINMEYEN iş-bitti is-zb' zili 3 kez kaçtı. Ölçüt: komuttan önce/sonra kütükte
#   "denetçi: is-<ad> tur" satırı sayısı (BILINMEYEN · HARICI · herhangi gönderen) — fark 0 olmalı.
set -uo pipefail
L="${AILE_SINYAL_LOG_GERCEK:-/config/projects/Nexus/_agents/handoff/aile-sinyal.log}"
[ -f "$L" ] || { echo "ÖLÇÜLEMEDİ: sinyal kütüğü yok: $L"; exit 4; }
# YALNIZ yeni gönderim sayılır: kütük satırı "kimlik|zaman|TÜR|…" — sızıntı her zaman yeni bir done/waiting satırı yazar.
#   kuyruk/ping satırları ESKİ bir zilin taşınması ya da iletimidir (ölçüldü 21:45: 20:41'deki eski sızıntının kuyruk 'tasti' satırı
#   koşum sırasında düştü ve ilk sürüm onu yeni sızıntı saydı).
say() { grep -acE '^[^|]*\|[^|]*\|(done|waiting)\|.*denetçi( \([^)]*\))?: is-[a-z0-9-]+ tur' "$L"; }
once=$(say); "$@"; rc=$?; sonra=$(say)
echo "── SIZINTI: gerçek sinyal kütüğünde sınav işi zili önce $once · sonra $sonra · fark $((sonra-once)) (komut rc $rc)"
[ "$rc" -eq 0 ] && [ "$sonra" -eq "$once" ] && exit 0
exit 1
