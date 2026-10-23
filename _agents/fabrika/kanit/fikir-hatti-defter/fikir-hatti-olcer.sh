#!/usr/bin/env bash
# fikir-hatti-olcer.sh <kod kaynağı: git ref | "agac"> — 4FDVE5: fikir hattı (bileyi + mucit-t1) merkezî Görev Defteri'ndeki
#   bulguları GÖRÜYOR mu? Verilen kaynaktaki beceri ağacıyla, GERÇEK defter (salt-okur GET) ve Nexus odası üstünde koşar;
#   hiçbir şey yazmaz (bileyi olc · mucit-t1 suz salt-okurdur). Ölçülen: bileyi iz satırında defter kaynağı + "N tanesi görev
#   defterinden", mucit eleme özetinde "görev defteri: N bulgu eklendi". Çıkış 0 = ikisi de defteri görüyor · 1 = görmüyor.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
if [ "$1" = agac ]; then A="$R"; else git -C "$R" archive "$1" | tar -x -C "$T"; A="$T"; fi
echo "kod kaynağı: $1 · oda: /config/projects/Nexus · defter: canlı (salt-okur)"
B="$(cd /config/projects/Nexus && python3 "$A/bileyi/scripts/bileyi.py" --depo /config/projects/Nexus olc < /dev/null 2>&1)"; br=$?
printf '%s\n' "$B" | grep -E "^   (iz|havuz):" 
M="$(cd /config/projects/Nexus && bash "$A/mucit-suz/scripts/mucit-t1.sh" suz --profil layiha < /dev/null 2>&1 >/dev/null)"; mr=$?
printf '%s\n' "$M" | grep -E "eleme-özeti|T2'ye geçen|🟡"
bd=$(printf '%s\n' "$B" | grep -oE "[0-9]+ tanesi görev defterinden" | grep -oE "^[0-9]+"); md=$(printf '%s\n' "$M" | grep -oE "görev defteri: [0-9]+ bulgu eklendi" | grep -oE "[0-9]+")
echo "bileyi rc=$br · defterden: ${bd:-0} · mucit rc=$mr · defterden: ${md:-0}"
[ "${bd:-0}" -gt 0 ] && [ "${md:-0}" -gt 0 ]
