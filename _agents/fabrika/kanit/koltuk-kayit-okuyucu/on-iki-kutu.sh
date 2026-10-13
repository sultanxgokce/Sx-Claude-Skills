#!/usr/bin/env bash
# 12 İSKÂN kutusu: her kutunun iskan-registry.yaml'ındaki İLK koltuk, YALNIZ 'durum' (salt-okur).
#   $1 boş → kutuya KURULU koltuk-ac.sh (önce) · $1 = yeni koltuk-ac.sh yolu → geçici dizine akıtılır (sonra), iş bitince silinir.
S="${1:-}"
for k in akar enis huzur maiset menzil mmex nazir nova s02 sedir tellal tez; do
  ad="$(ssh hostsrv "grep -m1 -oP 'tmux:\s*\"?\K[^\":]+' /opt/cloudtop/config-$k/projects/$k/iskan-registry.yaml" 2>/dev/null)"
  [ -n "$ad" ] || { echo "$k: ÖLÇÜLEMEDİ (iskan kaydında tmux yok)"; continue; }
  printf '%-7s %-12s ' "$k" "$ad"
  if [ -z "$S" ]; then
    ssh hostsrv "docker exec -u abc cloudtop-$k bash -c 'TO_KUTU=$k bash /config/.claude/skills/terminal-onar/scripts/koltuk-ac.sh durum $ad'" < /dev/null
  else
    ssh hostsrv "docker exec -i -u abc cloudtop-$k bash -c 'd=\$(mktemp -d); cat > \$d/koltuk-ac.sh; b=/config/.claude/skills/terminal-onar/scripts; cp \$b/ortak.sh \$b/koltuk-bagla.sh \$d/; TO_KUTU=$k bash \$d/koltuk-ac.sh durum $ad; find \$d -mindepth 1 -delete; rmdir \$d'" < "$S"
  fi
done | python3 -c '
import sys, json
for l in sys.stdin:
    p = l.split(None, 2)
    try:
        j = json.loads(p[2]); yol, rol, du = j["yol"], j["rol"] or "-", j["durum"]
        print("%-7s %-12s yol=%-8s rol=%-12s durum=%s" % (p[0], p[1], yol, rol, du))
    except Exception: print(l.rstrip())'
