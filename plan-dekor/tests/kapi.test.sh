#!/usr/bin/env bash
# CI keşif sarmalayıcısı — merkezî CI `*.test.sh` arar; plan-dekor'un kapıları zaten
# paketin içinde (`kapi-testi.sh`) ama o ad keşfe takılmıyordu. Kapılar KOPYALANMADI:
# bu betik ürün kapısını ÇAĞIRIR, taklit etmez (tekrar = iki gerçek kaynağı demektir).
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$PAKET/kapi-testi.sh" "$@"
