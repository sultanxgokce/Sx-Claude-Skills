#!/usr/bin/env bash
# CANLI, YENİDEN KOŞTURULABİLİR: GERÇEK ekip-ac.sh ile "eski sohbete dön" — aynı sohbet kimliğiyle geri gelir mi; ikinci kopya açılmaz mı.
# Geçici aile kaydını KENDİSİ üretir (depo dışı duruma bağımlı değil — yedek göz tur 2). Kapı şeridinde (abonelik yanmaz).
# Kullanım: canli-eski-sohbet.sh [sid]   sid verilmezse bu kutudaki en yeni sınav sohbeti (projects/-tmp-claude-1000-sinav-oda) alınır.
# Yalnız kimlik adı/sid karşılaştırılır; sohbet metni basılmaz. Sonunda açılan koltuğu kapatır.
set -uo pipefail
AD=bani-sinav2; S="$(cd "$(dirname "$0")/../../../../terminal-onar/scripts" && pwd)"
SID="${1:-$(ls -t "$HOME"/.claude/projects/-tmp-claude-1000-sinav-oda/*.jsonl 2>/dev/null | head -1 | xargs -r basename | sed 's/\.jsonl$//')}"
[ -n "$SID" ] || { echo "ÖLÇÜLEMEDİ: eski sohbet kaydı (sid) yok — önce bir sınav koltuğu aç"; exit 3; }
T="$(mktemp -d)"; trap 'tmux kill-session -t "=$AD" 2>/dev/null; rm -r "$T"' EXIT
printf 'uyeler:\n  - id: SINAVROL\n    tmux: "%s:0"\n    mod: kod\n    serit: kapi\n    session_id: "%s"\n' "$AD" "$SID" > "$T/reg.yaml"
KA() { env -u TMUX -u TMUX_PANE TO_KUTU=code TO_PROJE=/config/projects/Nexus TO_EKIP_AC=/config/projects/Nexus/scripts/ekip-ac.sh AILE_REGISTRY="$T/reg.yaml" bash "$S/koltuk-ac.sh" "$@"; }
tmux kill-session -t "=$AD" 2>/dev/null; sleep 1
echo "sid: $SID"; echo "önce: $(KA durum $AD)"
KA ac $AD --eski 2>&1 | grep -E "resume-if-known|doğdu|açıldı"; echo "ac rc=${PIPESTATUS[0]}"
sleep 20
echo "sonra: $(KA durum $AD)"
g=0; for f in "$HOME"/.claude/sessions/*.json; do python3 -c "import json,sys;j=json.load(open('$f'));sys.exit(0 if str(j.get('tmux','')).startswith('$AD') and j.get('sessionId')=='$SID' else 1)" 2>/dev/null && g=1; done
echo "oturum kaydında aynı sid: $([ $g = 1 ] && echo EVET || echo HAYIR)"
echo "süreçte --resume $SID: $(pgrep -af "resume $SID" | grep -vc pgrep)"
echo "ikinci 'ac' → $(KA ac $AD) · oturum sayısı: $(tmux list-sessions -F '#{session_name}' | grep -c "^$AD$")"
[ $g = 1 ]
