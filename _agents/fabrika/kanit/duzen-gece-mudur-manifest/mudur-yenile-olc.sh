#!/usr/bin/env bash
# Kullanım: mudur-yenile-olc.sh eski|yeni — Nexus SERDAR kimliğinin (MÜDÜR temeli) gece kurulumunun koşacağı yenile komutunu
# zamanlayıcı ortamında (env -i, çıplak PATH) KURU koşar. eski = paket ekipc.sh (1.6.9 davranışı) · yeni = depo ekipc.sh + paket vendor PyYAML (1.6.10).
set -u
PAKET=/config/.claude/skills/duzen; DEPO=/config/projects/Nexus
case "${1:-}" in
  eski) env -i HOME=/config PATH=/usr/bin:/bin bash "$PAKET/scripts/ekipc.sh" yenile --dosya "$DEPO/_agents/serdar/AGENT.md" --rol MÜDÜR ;;
  yeni) cd "$DEPO" && env -i HOME=/config PATH=/usr/bin:/bin PYTHONPATH="$PAKET/scripts/../vendor" bash "$DEPO/scripts/ekipc.sh" yenile --dosya "$DEPO/_agents/serdar/AGENT.md" --rol MÜDÜR ;;
  *) echo "kullanım: eski|yeni" >&2; exit 2 ;;
esac
