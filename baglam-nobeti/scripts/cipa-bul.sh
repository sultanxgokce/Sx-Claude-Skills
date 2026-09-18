#!/usr/bin/env bash
# cipa-bul.sh — compact'tan ÖNCE tazelenecek ÇIPA dosyalarını BU KUTUDA bulur.
# NİÇİN: kural AKAR'da doğdu ve AKAR'ın dosya adlarıyla yazıldı (DURUM.md · tanitim/ANA-AKS.md ·
# _agents/durum/<AD>.json · Notlarim/notlarim.md). Global kurulunca her kutunun çıpası farklı;
# olmayan dosyaya "yazdım" denmesin diye VAR OLANLAR ölçülür, uydurulmaz. Hiçbiri yoksa rc=1 ve
# tek öneri basılır (Notlarim/notlarim.md — filo genelinde kabul görmüş not dosyası).
# Kullanım: cipa-bul.sh [proje-kökü]   (varsayılan: CLAUDE_PROJECT_DIR → cwd)
set -u
KOK="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
ADAYLAR="DURUM.md tanitim/ANA-AKS.md Notlarim/notlarim.md _agents/CONTEXT.md _agents/handoff/serdar-defter.md"
n=0
for a in $ADAYLAR; do [ -f "$KOK/$a" ] && { printf '%s\n' "$KOK/$a"; n=$((n+1)); }; done
if [ -d "$KOK/_agents/durum" ]; then
  for j in "$KOK"/_agents/durum/*.json; do [ -f "$j" ] && { printf '%s\n' "$j"; n=$((n+1)); }; done
fi
if [ "$n" -eq 0 ]; then
  printf 'ÇIPA YOK: %s altında bilinen çıpa dosyası bulunamadı — öneri: %s/Notlarim/notlarim.md (oluştur, son satıra "nerede kaldım" yaz)\n' "$KOK" "$KOK" >&2
  exit 1
fi
exit 0
