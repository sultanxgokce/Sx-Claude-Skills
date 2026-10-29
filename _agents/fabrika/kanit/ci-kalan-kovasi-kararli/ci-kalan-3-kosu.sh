#!/usr/bin/env bash
# ci-kalan-3-kosu.sh <run_id> — PR dalı CI koşusunun 3 denemesinde 'kabuk sınamaları (kalan)' işi: sonuç, süre, paralel-aşım yeniden-ölçüm sayısı.
# Çıkış 0 = üçü de success ve aşım 0 · 1 = aksi. Kaynak: GitHub Actions API (gh api), günlükler gh ile indirilir.
set -u; R="$1"; REPO=sultanxgokce/Sx-Claude-Skills; rc=0; n=0
for a in 1 2 3; do
  gh api "repos/$REPO/actions/runs/$R/attempts/$a/jobs" -q '.jobs[] | select(.name=="kabuk sınamaları (kalan)") | "\(.id) \(.conclusion) \(((.completed_at|fromdateiso8601)-(.started_at|fromdateiso8601)))"' | while read -r id c d; do
    asim=$(gh api "repos/$REPO/actions/jobs/$id/logs" 2>/dev/null | grep -c "zaman aşımına düştü")
    echo "deneme $a: iş $id $c ${d}s · paralelde aşım→yeniden ölçüm: $asim"
    [ "$c" = success ] && [ "$asim" = 0 ] || echo "✗ deneme $a kırmızı ya da aşımlı"
  done
done | tee /dev/stderr | { grep -q "✗" && exit 1; c=$(grep -c "deneme [123]: iş" /dev/stdin 2>/dev/null); exit 0; }
