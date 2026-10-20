#!/usr/bin/env bash
# SALT OKUMA: her ekip kutusunda tmux bekçisi (/config/.local/bin/tmux, 'tmux-bekcisi.sh' işaretli) kurulu mu, bekçi duraklatılmış mı.
set -u
ssh -o BatchMode=yes hostsrv 'sudo -n docker ps --format "{{.Names}}"' | grep -E '^cloudtop' | sort | while read -r k; do
  r="$(ssh -n -o BatchMode=yes hostsrv "sudo -n docker exec -u abc $k sh -c 'f=/config/.local/bin/tmux; if [ -f \$f ] && grep -q tmux-bekcisi.sh \$f; then printf kurulu; elif [ -e \$f ]; then printf yabanci; else printf yok; fi; [ -f /config/.terminal-onar/duraklat ] && printf \" · bekçi DURAKLATILMIŞ\"; [ -f /config/.terminal-onar/bekci.son ] || printf \" · bekçi izi yok\"'" 2>/dev/null)" || r="ÖLÇÜLEMEDİ"
  printf '%-22s %s\n' "$k" "$r"
done
