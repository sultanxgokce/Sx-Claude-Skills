#!/usr/bin/env bash
# setup-tunnel-mini.sh — İSKÂN test-fixture'ı: gerçek infra/setup-tunnel.sh'in ÜÇ çıpasını
# (hostname-değişken bloğu · ingress catch-all'lı heredoc · route-dns satırları) minimal taşır.
# _iskan_tunnel_satirlari_ekle bu çıpalara ekler; _sokum_satir_cikar simetrik geri-alır.
set -euo pipefail

MIHENK_HOSTNAME="${MIHENK_HOSTNAME_OVERRIDE:-mihenk.mmepanel.com}"          # emsal-satır (son değişken)
TUNNEL="cloudtop"

cat > /dev/null <<EOF
ingress:
  - hostname: ${MIHENK_HOSTNAME}
    service: http://localhost:8448
  - service: http_status:404
EOF
cloudflared tunnel route dns "$TUNNEL" "$MIHENK_HOSTNAME" || true
