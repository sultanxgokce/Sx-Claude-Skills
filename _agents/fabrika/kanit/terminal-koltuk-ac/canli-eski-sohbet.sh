#!/usr/bin/env bash
# CANLI: GERÇEK ekip-ac.sh + geçici aile kaydı → sınav koltuğunu öldür → koltuk-ac.sh ac --eski → aynı sohbet kimliğiyle geri gelir mi.
# Kapı şeridinde (abonelik yanmaz). Yalnız kimlik ADI/sid karşılaştırılır; sohbet metni basılmaz.
SID="77a7c8f7-f8e1-4fcf-8070-9dd6a416f327"; AD=bani-sinav2; R=/tmp/claude-1000/resume-sinav/reg.yaml
S="$(cd "$(dirname "$0")/../../../../terminal-onar/scripts" && pwd)"
tmux kill-session -t "=$AD" 2>/dev/null; sleep 1
echo "önce: $(env -u TMUX -u TMUX_PANE TO_KUTU=code TO_PROJE=/config/projects/Nexus TO_EKIP_AC=/config/projects/Nexus/scripts/ekip-ac.sh AILE_REGISTRY=$R bash $S/koltuk-ac.sh durum $AD)"
env -u TMUX -u TMUX_PANE TO_KUTU=code TO_PROJE=/config/projects/Nexus TO_EKIP_AC=/config/projects/Nexus/scripts/ekip-ac.sh AILE_REGISTRY=$R bash $S/koltuk-ac.sh ac $AD --eski 2>&1 | grep -E "resume-if-known|doğdu|açıldı"; echo "rc=${PIPESTATUS[0]}"
sleep 20
echo "sonra: $(env -u TMUX -u TMUX_PANE TO_KUTU=code TO_PROJE=/config/projects/Nexus TO_EKIP_AC=/config/projects/Nexus/scripts/ekip-ac.sh AILE_REGISTRY=$R bash $S/koltuk-ac.sh durum $AD)"
g=0; for f in /config/.claude/sessions/*.json; do python3 -c "import json,sys;j=json.load(open('$f'));sys.exit(0 if str(j.get('tmux','')).startswith('$AD') and j.get('sessionId')=='$SID' else 1)" 2>/dev/null && g=1; done
echo "oturum kaydında aynı sid ($SID): $([ $g = 1 ] && echo EVET || echo HAYIR)"
echo "süreçte --resume $SID: $(pgrep -af "resume $SID" | grep -vc pgrep)"
echo "ekranda önceki sohbetin izi (sınav mesajı sayısı): $(tmux capture-pane -p -t $AD: -S -300 | grep -c 'sınav mesajı')"
echo "ikinci 'ac' → ikinci kopya açılmaz: $(env -u TMUX -u TMUX_PANE TO_KUTU=code TO_PROJE=/config/projects/Nexus TO_EKIP_AC=/config/projects/Nexus/scripts/ekip-ac.sh AILE_REGISTRY=$R bash $S/koltuk-ac.sh ac $AD) · oturum sayısı: $(tmux list-sessions -F '#{session_name}' | grep -c "^$AD$")"
[ $g = 1 ]
