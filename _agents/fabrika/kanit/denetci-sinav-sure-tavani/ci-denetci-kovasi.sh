#!/usr/bin/env bash
# ci-denetci-kovasi.sh [<dal>] — ölçüm yeri CI: verilen daldaki son koşuların 'kabuk sınamaları (denetci*)' işlerinin sonucu ve süresi.
# Çıkış: hepsi success ise 0, biri failure/timeout ise 1. (önce: main'deki bölünmemiş kova · sonra: PR dalındaki denetci-1/2/3)
set -u; DAL="${1:-main}"; N="${2:-3}"; kirmizi=0; toplam=0
for r in $(gh run list --branch "$DAL" --workflow lint.yml --limit "$N" --json databaseId -q '.[].databaseId'); do
  gh run view "$r" --json headSha,createdAt,jobs -q '.headSha[0:8]+" "+.createdAt+" "+([.jobs[]|select(.name|test("denetci"))|"\(.name|gsub("kabuk sınamaları ";""))=\(.conclusion) \((((.completedAt|fromdateiso8601)-(.startedAt|fromdateiso8601)) ))s"]|join(" · "))' 2>/dev/null
  while read -r c; do toplam=$((toplam+1)); [ "$c" = success ] || kirmizi=$((kirmizi+1)); done < <(gh run view "$r" --json jobs -q '.jobs[]|select(.name|test("denetci"))|.conclusion')
done
echo "denetci işi: toplam=$toplam kırmızı=$kirmizi (dal=$DAL, son $N koşu)"; [ "$kirmizi" -eq 0 ]
