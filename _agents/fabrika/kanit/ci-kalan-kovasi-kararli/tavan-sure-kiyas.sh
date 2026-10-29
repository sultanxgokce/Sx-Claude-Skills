#!/usr/bin/env bash
# tavan-sure-kiyas.sh <run_id> — PR dalı CI 'kalan' kovasının 3 denemesinde ağır sınavların ÖLÇÜLEN süresi ile bu işte seçilen TAVAN yan yana.
# Çıkış 0 = her sınavın en uzun ölçümü tavanın altında ve tavan en uzun ölçümün ≥1,5 katı (yük payı) · 1 = aksi · 4 = ÖLÇÜLEMEDİ
# (günlük boş ya da süre satırı yok — ilk sürüm 0 sn okuyup yeşil basmıştı: EKSİK VERİYİ ÖNCE SINA). Günlük --allow-escape-sequences + ESC süzgeci.
set -u; R="$1"; REPO=sultanxgokce/Sx-Claude-Skills; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT; rc=0
for a in 1 2 3; do id=$(gh api "repos/$REPO/actions/runs/$R/attempts/$a/jobs" -q '.jobs[] | select(.name=="kabuk sınamaları (kalan)") | .id'); gh api --allow-escape-sequences "repos/$REPO/actions/jobs/$id/logs" 2>/dev/null | python3 -c "import sys,re;E=bytes([27]);b=sys.stdin.buffer.read();b=re.sub(E+rb'\\[[0-9;?]*[ -/]*[@-~]',b'',b).replace(E,b'');sys.stdout.write(b.decode('utf-8','replace'))" > "$T/$a.log"; grep -q "kova=kalan" "$T/$a.log" || { echo "ÖLÇÜLEMEDİ: deneme $a günlüğü boş/okunamadı"; exit 4; }; done
printf '%-55s %6s %6s %6s %7s %6s %s\n' sınav d1 d2 d3 enuzun tavan oran
for t in ./tescil/scripts/sicil.test.sh ./yazilim-fabrikasi/scripts/agir-sira-sarma.test.sh ./oda-kur/scripts/oda.test.sh ./tescil/scripts/muhurdar.test.sh ./yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh; do
  tavan=$(head -15 "$t" | sed -n 's/^# *kabuk-testleri: *sure=\([0-9]*\).*/\1/p' | head -1); [ -n "$tavan" ] || tavan=300
  s=(); en=0
  for a in 1 2 3; do ms=$(grep -oE "✓ $(printf '%s' "$t" | sed 's/[.]/\\./g') \([0-9]+ ms\)" "$T/$a.log" | grep -oE '[0-9]+ ms' | grep -oE '[0-9]+' | head -1); sn=$(( ${ms:-0} / 1000 )); s+=("$sn"); [ "$sn" -gt "$en" ] && en=$sn; done
  [ "$en" -gt 0 ] || { echo "ÖLÇÜLEMEDİ: $t için süre satırı bulunamadı"; exit 4; }
  oran=$(python3 -c "print(round($tavan/$en,2))")
  printf '%-55s %6s %6s %6s %7s %6s %s\n' "$t" "${s[0]}" "${s[1]}" "${s[2]}" "$en" "$tavan" "$oran"
  [ "$en" -lt "$tavan" ] && python3 -c "import sys; sys.exit(0 if $tavan >= 1.5*max($en,1) else 1)" || { echo "✗ $t: en uzun ${en}s, tavan ${tavan}s — pay yetersiz"; rc=1; }
done; exit $rc
