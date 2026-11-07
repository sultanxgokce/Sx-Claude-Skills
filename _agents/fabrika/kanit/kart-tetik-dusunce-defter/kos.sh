#!/usr/bin/env bash
# kos.sh <kip> — once | sonra | nazir
# once: yazilim-fabrikasi/ klasörünün geçici kopyasında kart.sh origin/main'deki hâliyle değiştirilir, YENİ kart.test.sh koşturulur (D6 düşmeli)
# sonra: bu daldaki kart.test.sh
# nazir: gerçek kutuda salt-okur yoklama — tetik betiği var mı, ssh hostsrv rc, ~/.ssh'de hostsrv ayarı (code pozitif kontrol)
set -uo pipefail
KOK="$(git rev-parse --show-toplevel)"; cd "$KOK"; S=yazilim-fabrikasi/scripts
case "${1:?kip}" in
  once) d="$(mktemp -d)"; cp -a yazilim-fabrikasi "$d/"; git show origin/main:$S/kart.sh > "$d/yazilim-fabrikasi/scripts/kart.sh"
        ( cd "$d/yazilim-fabrikasi/scripts" && timeout 900 bash kart.test.sh < /dev/null ); r=$?; find "$d" -depth -delete; exit $r ;;
  sonra) cd $S && timeout 900 bash kart.test.sh < /dev/null ;;
  nazir) timeout 40 ssh -o BatchMode=yes -o ConnectTimeout=8 hostsrv "sudo -n docker exec -u abc cloudtop-nazir sh -c 'test -x /config/projects/Nexus/scripts/oda-tetik.sh && echo tetik=var || echo tetik=yok; timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 hostsrv true >/dev/null 2>&1; echo nazir_ssh_rc=\$?; printf nazir_ssh_ayar=; grep -c \"^Host .*hostsrv\" /config/.ssh/config 2>/dev/null || echo yok'; sudo -n docker exec -u abc cloudtop-code sh -c 'printf code_ssh_ayar=; grep -c \"^Host .*hostsrv\" /config/.ssh/config'" ;;
  *) echo "bilinmeyen kip" >&2; exit 2 ;;
esac
