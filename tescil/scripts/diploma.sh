#!/usr/bin/env bash
# diploma.sh — Mühürdarlık diploma sınavı (G13 · kadro şeması §6). Mantık lib/diploma.py'de.
#   diploma.sh sina  <personel> [--kume DIR] [--kanit DIR]   → kümeyi mühürdar usulüyle koşar, diploma defterine §6 satırı
#   diploma.sh durum <personel>                               → gecerli · bayat (el kitabı sürümü değişti) · yok · askida (sicil)
# Sınav gerçek sicile ve telemetriye yazmaz. RC: 0 geçti/geçerli · 1 kaldı/yok/bayat/askida · 2 kullanım · 3 ölçülemedi
# Ortam: DIPLOMA_DEFTERI · TESCIL_KATALOG · SICIL_DIZIN · MUHURDAR_MODEL (muhurdar.sh'a geçer)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in sina|durum) ;; *) sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;; esac
exec python3 "$HERE/lib/diploma.py" "$@"
