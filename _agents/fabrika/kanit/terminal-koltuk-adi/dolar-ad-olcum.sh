#!/usr/bin/env bash
# Ölçüm (yedek göz tur 2): adı '$1' olan koltuk eski betikte '-t "$1:"' ile oturum KİMLİĞİ sanılır → son etkinlik BAŞKA oturumdan
# okunur. Yeni betik -t'ye ad yazmaz (list-sessions/list-panes eşlemesi). Gerçek tmux, ayrı sunucu (-L).
K="$(cd "$(dirname "$0")" && pwd)"; L=bani-olc4; D="$K/../../../.."
command tmux -L $L kill-server 2>/dev/null
command tmux -L $L new -d -s "x/y" "sleep 60"; sleep 1.2; command tmux -L $L new -d -s '$1' "sleep 60"
echo "oturumlar (kimlik ad etkinlik):"; command tmux -L $L ls -F "#{session_id} #{session_name} #{session_activity}"
git -C "$D" show origin/main:terminal-onar/scripts/koltuk-bagla.sh > /tmp/claude-1000/kb-eski2.sh
tmux() { command tmux -L bani-olc4 "$@"; }; export -f tmux
echo "ESKİ betik (ad son):"; bash /tmp/claude-1000/kb-eski2.sh --liste | cut -f1,2 | grep -P '^(\$1|x/y)\t'
echo "YENİ betik (ad son):"; bash "$D/terminal-onar/scripts/koltuk-bagla.sh" --liste | cut -f1,2 | grep -P '^(\$1|x/y)\t'
echo "beklenen: yeni betikte '\$1' satırının son değeri kendi list-sessions değeri; eski betikte x/y'ninkiyle aynı (kimlik karışması)"
command tmux -L $L kill-server
