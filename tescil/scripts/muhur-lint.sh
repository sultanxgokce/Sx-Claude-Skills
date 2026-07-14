#!/usr/bin/env bash
# muhur-lint.sh — MUHUR.md + kanıt şema-doğrulaması (tescil skill'i; DİVAN K5, k0054).
# Şemasız/çıplak-"geçti" → RC≠0 GEÇERSİZ. İş-tipi asgari-kanıt tablosunu ZORLAR
# (ui→≥1 e2e-check · kod→≥1 api-check|e2e-check · docs→dosya-varlık/anchor-grep/lint sınıfı).
# Jenerik-G dedektörü: --tescil-root verilirse bu kartın G-komut-sha'ları son-20 kartla
# karşılaştırılır; örtüşme >%70 → "jenerik-gereklilik" UYARI-satırı (RC etkilemez).
#
# Kullanım: muhur-lint.sh <deneme-dizini> [--tescil-root <_agents/tescil>]
# RC: 0=geçerli · 1=GEÇERSİZ · 2=kullanım/harness
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
[ -n "${1:-}" ] || { echo "kullanım: muhur-lint.sh <deneme-dizini> [--tescil-root <dir>]" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "muhur-lint: python3 yok (harness)" >&2; exit 2; }

python3 "$LIB/muhur.py" lint "$@"
