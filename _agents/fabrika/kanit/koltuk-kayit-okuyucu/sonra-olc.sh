#!/usr/bin/env bash
# yeni koltuk-ac.sh'yi kutuda YALNIZ 'durum' ile koşar (salt-okur): geçici dizine akıtılır, ortak.sh + koltuk-bagla.sh kutunun kurulu kopyasından
S="$1"
for k in "enis ENIS" "enis MURSIT" "nazir nazir-yon" "akar MUTEVELLI"; do set -- $k
  printf '%s/%s: ' "$1" "$2"
  ssh hostsrv "docker exec -i -u abc cloudtop-$1 bash -c 'd=\$(mktemp -d); cat > \$d/koltuk-ac.sh; b=/config/.claude/skills/terminal-onar/scripts; cp \$b/ortak.sh \$b/koltuk-bagla.sh \$d/; TO_KUTU=$1 bash \$d/koltuk-ac.sh durum $2; find \$d -mindepth 1 -delete; rmdir \$d'" < "$S"
done
