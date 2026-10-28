#!/usr/bin/env bash
# 13 kutuda kapı süreci diskteki koddan eski mi? (salt-okur: docker exec -u abc … ps/find/cat) — rc 0 = ESKİ 0, rc 1 = ESKİ>0, rc 4 = ölçülemedi var
set -u; eski=0; olc=0; toplam=0
for k in akar huma huzur mihenk mmex nazir revak sedir tellal tez nova vekatip medigate code; do
  toplam=$((toplam+1))
  o=$(ssh -o BatchMode=yes -o ConnectTimeout=8 hostsrv "docker exec -u abc cloudtop-$k sh -c '
    pid=\$(pgrep -f \"node .*kapi/sunucu\\.mjs\" | head -1); [ -n \"\$pid\" ] || { echo surec-yok; exit 0; }
    et=\$(ps -o etimes= -p \$pid | tr -d \" \"); now=\$(date +%s); bas=\$((now-et))
    kod=\$(find /config/.claude/skills/terminal-onar/kapi -name \"*.mjs\" -not -path \"*/node_modules/*\" -not -name \"*.test.mjs\" -printf \"%T@\\n\" 2>/dev/null | sort -rn | head -1 | cut -d. -f1)
    sur=\$(grep -m1 \"^version:\" /config/.claude/skills/terminal-onar/SKILL.md | cut -d\" \" -f2)
    son=\$(tail -1 /config/.claude/terminal-onar/durum/gunluk.log 2>/dev/null | grep -c \"bekçi: kapı\")
    if [ \"\$kod\" -gt \"\$bas\" ]; then echo \"ESKI etimes=\$et kod-bas=\$((kod-bas))s surum=\$sur\"; else echo \"guncel etimes=\$et surum=\$sur\"; fi'" 2>&1)
  case "$o" in ESKI*) eski=$((eski+1));; guncel*) ;; *) olc=$((olc+1));; esac
  printf '%s %-9s %s\n' "$(date +%H:%M:%S)" "$k" "$o"
done
echo "$(date '+%Y-%m-%d %H:%M:%S') ÖZET: toplam=$toplam ESKİ=$eski ölçülemedi=$olc"
[ "$olc" -gt 0 ] && exit 4; [ "$eski" -gt 0 ] && exit 1; exit 0
