#!/usr/bin/env bash
# plan-motor kurulumu — idempotent. Tek gereksinim: node ≥22 + npm + ağ.
set -euo pipefail
cd "$(dirname "$0")"

if node -e "import('file://$PWD/node_modules/dxf-parser/dist/index.js').catch(()=>process.exit(1))" 2>/dev/null \
   && [ -d node_modules/dejavu-fonts-ttf ] && [ -d node_modules/sharp ]; then
  echo "✓ bağımlılıklar zaten kurulu"
else
  npm install --no-fund --no-audit
  echo "✓ kurulum tamam"
fi

node cli.mjs dogrula --model demo/ornek-model.json --metrik /dev/null >/dev/null 2>&1 \
  && echo "✓ duman testi geçti (demo model doğrulandı)" \
  || { echo "✗ duman testi BAŞARISIZ"; exit 1; }
