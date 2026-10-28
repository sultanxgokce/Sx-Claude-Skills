#!/usr/bin/env bash
# canli-kabuk-olc.sh — her kutuda el kabuğu sekmesi (<kutu>-kabuk tmux oturumu) var mı? İki yüzey: tmux ls (süreç) + /config/.terminal-onar/kabuk.son (bekçi damgası).
# Salt okur (ssh hostsrv → docker exec -u abc). Çıkış: her kutu bir satır; rc 0 = probe edilen her kutuda ikisi de VAR, aksi 1. Pozitif kontrol: <kutu>-ana oturumu da sayılır (tmux ls çalışıyor mu?).
set -u
# Kanonik liste: Sx _agents/fabrika/kanit/kapi-bekci-eski-kod/canli-kutular-olc.sh satır 4 (terminal-onar canlı-kutular, 14 kutu). KUTULAR ortamdan ezilebilir (negatif kontrol).
# --negatif: verilen kutularda kabuk BEKLENMEZ; YOK görülürse rc 0 (ölçer YOK'u ayırt edebiliyor mu — pozitif kontrolün tersi). VAR görülürse rc 1.
KANON_DOSYA=/config/projects/Sx-Claude-Skills/_agents/fabrika/kanit/kapi-bekci-eski-kod/canli-kutular-olc.sh
KANON="$(sed -n 's/^for k in \(.*\); do$/\1/p' "$KANON_DOSYA" 2>/dev/null | head -1)"
KUTULAR="${KUTULAR:-${KANON:-akar huma huzur mihenk mmex nazir revak sedir tellal tez nova vekatip medigate code}}"
NEGATIF=0; [ "${1:-}" = "--negatif" ] && NEGATIF=1
echo "$(date -Is) KAYNAK LİSTE: $KANON_DOSYA → '$KANON' (kutu sayısı $(printf '%s\n' $KUTULAR | wc -l)) · kip: $([ $NEGATIF -eq 1 ] && echo 'NEGATİF KONTROL (kabuk beklenmez)' || echo 'pozitif (her kutuda kabuk beklenir)')"
echo "$(date -Is) YÜZEY 1: süreç — ssh hostsrv 'docker exec -u abc cloudtop-<kutu> tmux ls' (salt okur) · YÜZEY 2: bekçi damgası — /config/.terminal-onar/kabuk.son (salt okur) · POZİTİF KONTROL: aynı tmux ls <kutu>-ana oturumunu görüyor mu"
eksik=0; n=0
for k in $KUTULAR; do
  out=$(ssh -o ConnectTimeout=10 hostsrv "docker exec -u abc cloudtop-$k sh -c 'tmux ls 2>/dev/null | cut -d: -f1 | tr \"\\n\" \" \"; printf \"|\"; cat /config/.terminal-onar/kabuk.son 2>/dev/null || printf yok'" 2>/dev/null)
  rc=$?; n=$((n+1))
  oturumlar=${out%%|*}; damga=${out##*|}
  ana=$(printf '%s' "$oturumlar" | tr ' ' '\n' | grep -c "^$k-ana$")
  kabuk=$(printf '%s' "$oturumlar" | tr ' ' '\n' | grep -c "^$k-kabuk$")
  # pozitif kontrol: pozitif kipte <kutu>-ana görülmeli; negatif kipte (terminal-onar kurulu olmayan kutu) ana yoktur, tmux ls'in en az bir oturum döndürmesi yeter
  if [ $rc -ne 0 ] || { [ $NEGATIF -eq 0 ] && [ "$ana" -ne 1 ]; } || { [ $NEGATIF -eq 1 ] && [ -z "$(printf '%s' "$oturumlar" | tr -d ' ')" ]; }; then echo "$(date -Is) $k ÖLÇÜLEMEDİ (ssh rc=$rc, ana=$ana, oturum='$oturumlar')"; eksik=$((eksik+1)); continue; fi
  if [ "$kabuk" -eq 1 ] && [ "$damga" = "ok" ]; then echo "$(date -Is) $k VAR  yüzey1=tmux:$k-kabuk yüzey2=kabuk.son:ok ana=$k-ana"; [ $NEGATIF -eq 1 ] && eksik=$((eksik+1)); else echo "$(date -Is) $k YOK  yüzey1=tmux-kabuk:$kabuk yüzey2=kabuk.son:$damga ana=$k-ana"; [ $NEGATIF -eq 0 ] && eksik=$((eksik+1)); fi
done
echo "$(date -Is) TOPLAM kutu=$n $([ $NEGATIF -eq 1 ] && echo 'beklenmedik-VAR' || echo 'eksik')=$eksik"
[ "$eksik" -eq 0 ]
