#!/usr/bin/env bash
# SALT OKUMA: her cloudtop* kabında tmux bekçisi (/config/.local/bin/tmux, 'tmux-bekcisi.sh' işaretli) kurulu mu, bekçi duraklatılmış mı.
# Ekip kutusu = abc kullanıcısı olan kap. abc'siz kap (altyapı: kapi · ntfy · pano …) ayrı sayılır, ölçülemedi diye geçmez (göz tur 1).
set -u
ekip=0; kurulu=0; altyapi=0; olcmedi=0
while read -r k; do
  r="$(ssh -n -o BatchMode=yes hostsrv "sudo -n docker exec -u abc $k sh -c 'f=/config/.local/bin/tmux; if [ -f \$f ] && grep -q tmux-bekcisi.sh \$f; then printf kurulu; elif [ -e \$f ]; then printf yabanci; else printf yok; fi; [ -f /config/.terminal-onar/duraklat ] && printf \" · bekçi DURAKLATILMIŞ\"; [ -f /config/.terminal-onar/bekci.son ] || printf \" · bekçi izi yok\"' 2>&1")"
  case "$r" in
    kurulu*|yok*|yabanci*) ekip=$((ekip+1)); case "$r" in kurulu*) kurulu=$((kurulu+1)) ;; esac ;;
    *"unable to find user abc"*) r="ekip kutusu değil (abc kullanıcısı yok)"; altyapi=$((altyapi+1)) ;;
    *) r="ÖLÇÜLEMEDİ: ${r:0:80}"; olcmedi=$((olcmedi+1)) ;;
  esac
  printf '%-26s %s\n' "$k" "$r"
done < <(ssh -n -o BatchMode=yes hostsrv 'sudo -n docker ps --format "{{.Names}}"' | grep -E '^cloudtop' | sort)
echo "ÖZET: ekip kutusu $ekip · bekçi kurulu $kurulu · altyapı kabı (abc yok) $altyapi · ölçülemedi $olcmedi"
