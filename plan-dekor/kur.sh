#!/usr/bin/env bash
# plan-dekor kurulumu — idempotent. Bağımlılık YOKTUR (package.json dependencies boş);
# bu script yalnız ORTAMI DOĞRULAR ve duman testi koşar.
set -euo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KOK"

echo "── plan-dekor kur ──"

# 1) node sürümü
if ! command -v node >/dev/null 2>&1; then echo "✗ node yok (≥22 gerekir)"; exit 1; fi
MAJ="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$MAJ" -lt 22 ]; then echo "✗ node $MAJ — ≥22 gerekir"; exit 1; fi
echo "✓ node $(node -v)"

# 2) plan-motor — CLI sınırı (zorunlu bağımlılık, requires: [plan-motor])
PM="${PLAN_MOTOR_DIR:-}"
for aday in "$PM" "$KOK/../plan-motor" /config/.claude/skills/plan-motor; do
  [ -n "$aday" ] && [ -f "$aday/cli.mjs" ] && PM="$aday" && break
done
if [ -z "$PM" ] || [ ! -f "$PM/cli.mjs" ]; then
  echo "✗ plan-motor bulunamadı — PLAN_MOTOR_DIR ver ya da kardeş dizine kur"
  exit 1
fi
echo "✓ plan-motor: $PM"

# 3) plan-motor'un kendi kurulumu (sharp — PNG için) yapılmış mı
if [ ! -d "$PM/node_modules/sharp" ]; then
  echo "⚠ plan-motor node_modules eksik — PNG üretilemez. Çözüm: bash $PM/kur.sh"
else
  echo "✓ sharp (PNG) hazır"
fi

# 4) duman testi — CAD-suz kol uçtan uca
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/y.json" --adet 1 --metrik "$TMP/m.jsonl" >/dev/null 2>&1
node cli.mjs ciz --model demo/ornek-daire.json --yerlesim "$TMP/y.json" --cikti "$TMP/p.svg" --metrik "$TMP/m.jsonl" >/dev/null 2>&1
if [ ! -s "$TMP/p.svg" ]; then echo "✗ duman testi: SVG üretilmedi"; exit 1; fi
echo "✓ duman testi geçti ($(wc -c <"$TMP/p.svg") bayt SVG)"

echo "── hazır: node $KOK/cli.mjs ──"
