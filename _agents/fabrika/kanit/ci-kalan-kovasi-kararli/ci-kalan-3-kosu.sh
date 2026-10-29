#!/usr/bin/env bash
# ci-kalan-3-kosu.sh <run_id> — PR dalı CI koşusunun 3 denemesinde 'kabuk sınamaları (kalan)' işi: sonuç, süre, paralel-aşım yeniden-ölçüm sayısı.
# Çıkış 0 = üçü de success ve aşım 0 · 1 = aksi · 4 = ÖLÇÜLEMEDİ (günlük boş/okunamadı). Kaynak: GitHub Actions API (gh api);
# günlük --allow-escape-sequences ile iner (yoksa gh içerik vermez ve grep -c 0 der — ilk ölçüm bu yüzden SAHTE YEŞİLDİ), ESC süzülür,
# POZİTİF KONTROL: günlükte "kova=kalan" satırı yoksa ölçülemedi.
set -u; R="$1"; REPO=sultanxgokce/Sx-Claude-Skills; TMPO="$(mktemp)"; trap 'rm -f "$TMPO"' EXIT
for a in 1 2 3; do
  gh api "repos/$REPO/actions/runs/$R/attempts/$a/jobs" -q '.jobs[] | select(.name=="kabuk sınamaları (kalan)") | "\(.id) \(.conclusion) \(((.completed_at|fromdateiso8601)-(.started_at|fromdateiso8601)))"' | while read -r id c d; do
    g="$(gh api --allow-escape-sequences "repos/$REPO/actions/jobs/$id/logs" 2>/dev/null | python3 -c "import sys,re;E=bytes([27]);b=sys.stdin.buffer.read();b=re.sub(E+rb'\\[[0-9;?]*[ -/]*[@-~]',b'',b).replace(E,b'');sys.stdout.write(b.decode('utf-8','replace'))")"
    if ! grep -q "kova=kalan" <<<"$g"; then echo "✗ ÖLÇÜLEMEDİ deneme $a: günlük boş ya da okunamadı ($(wc -l <<<"$g") satır)"; continue; fi
    asim=$(grep -c "zaman aşımına düştü" <<<"$g")
    echo "deneme $a: iş $id $c ${d}s · günlük $(wc -l <<<"$g") satır · paralelde aşım→yeniden ölçüm: $asim"
    [ "$c" = success ] && [ "$asim" = 0 ] || echo "✗ deneme $a kırmızı ya da aşımlı"
  done
done > "$TMPO" 2>&1; cat "$TMPO"; grep -q "ÖLÇÜLEMEDİ" "$TMPO" && exit 4; grep -q "✗" "$TMPO" && exit 1; [ "$(grep -c "^deneme [123]: iş" "$TMPO")" = 3 ] || exit 4; exit 0
