#!/usr/bin/env bash
# canli-kabuk-olc.sh — her kutuda el kabuğu sekmesi (<kutu>-kabuk tmux oturumu) var mı? İki yüzey: tmux ls (süreç) + /config/.terminal-onar/kabuk.son (bekçi damgası).
# Salt okur (ssh hostsrv → docker exec -u abc). Çıkış: her kutu bir satır; rc 0 = probe edilen her kutuda ikisi de VAR, aksi 1. Pozitif kontrol: <kutu>-ana oturumu da sayılır (tmux ls çalışıyor mu?).
set -u
KUTULAR="akar huma huzur mihenk mmex nazir revak sedir tellal tez nova vekatip medigate code"   # terminal-onar canlı-kutular listesiyle aynı 14 kutu (kapi-bekci-eski-kod kanıtı)
eksik=0; n=0
for k in $KUTULAR; do
  out=$(ssh -o ConnectTimeout=10 hostsrv "docker exec -u abc cloudtop-$k sh -c 'tmux ls 2>/dev/null | cut -d: -f1 | tr \"\\n\" \" \"; printf \"|\"; cat /config/.terminal-onar/kabuk.son 2>/dev/null || printf yok'" 2>/dev/null)
  rc=$?; n=$((n+1))
  oturumlar=${out%%|*}; damga=${out##*|}
  ana=$(printf '%s' "$oturumlar" | tr ' ' '\n' | grep -c "^$k-ana$")
  kabuk=$(printf '%s' "$oturumlar" | tr ' ' '\n' | grep -c "^$k-kabuk$")
  if [ $rc -ne 0 ] || [ "$ana" -ne 1 ]; then echo "$(date -Is) $k ÖLÇÜLEMEDİ (ssh rc=$rc, ana=$ana)"; eksik=$((eksik+1)); continue; fi
  if [ "$kabuk" -eq 1 ] && [ "$damga" = "ok" ]; then echo "$(date -Is) $k VAR  kabuk-oturumu=$k-kabuk kabuk.son=ok"; else echo "$(date -Is) $k YOK  kabuk=$kabuk kabuk.son=$damga"; eksik=$((eksik+1)); fi
done
echo "$(date -Is) TOPLAM kutu=$n eksik=$eksik"
[ "$eksik" -eq 0 ]
