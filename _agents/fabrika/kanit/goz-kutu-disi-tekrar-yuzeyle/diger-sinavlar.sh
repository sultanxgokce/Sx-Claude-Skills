#!/usr/bin/env bash
# Göz aracının öteki sınavları (denetci*.test.sh; denetci-kutu-disi ayrıca ölçülür ve asıl sınav denetci.test.sh onu da çağırır) — sırayla, her birinin son satırı basılır.
# Çıkış: hepsi rc 0 ise 0, biri bile düşerse 1.
set -u
cd "$(git rev-parse --show-toplevel)/yazilim-fabrikasi/scripts" || exit 2
dusen=0
kos() {   # <etiket> <komut...> — rc'yi ve son satırı basar; '✗' sayısı YALNIZ bilgi (asıl sınavın kendi mutant anlatımında da geçer), hüküm rc'dir
  local etiket="$1"; shift; local cikti rc; cikti=$("$@" 2>&1); rc=$?
  echo "$etiket rc=$rc · $(printf '%s\n' "$cikti" | tail -1 | cut -c1-120)"
  if [ "$rc" -ne 0 ]; then dusen=$((dusen+1)); printf '%s\n' "$cikti" | grep -E '^ *✗' | head -5; fi
}
for f in denetci*.test.sh; do
  [ "$f" = denetci-kutu-disi.test.sh ] && continue
  [ "$f" = denetci.test.sh ] && continue
  kos "$f" timeout 900 bash "$f"
done
# Asıl sınav CI'da olduğu gibi ÜÇ PARÇADA koşar (.github/ci/kabuk-sinamalari.sh denetci-1..3): bölünmemiş koşu 900 sn sınırını aşıyor (53 mutant × tam süit).
# Parça sınırı burada 1800 sn: bu kutu CI koşucusundan yüklü; sınır aşılırsa rc 124 görünür ve sınav DÜŞMÜŞ sayılır.
for k in 1 2 3; do kos "denetci.test.sh parça $k/3" env DENETCI_PARCA="$k/3" timeout 1800 bash denetci.test.sh; done
echo "DÜŞEN SINAV: $dusen"
[ "$dusen" -eq 0 ]
