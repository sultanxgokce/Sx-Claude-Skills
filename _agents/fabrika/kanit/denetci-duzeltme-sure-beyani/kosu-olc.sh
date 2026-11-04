#!/usr/bin/env bash
# denetci-duzeltme-farki.test.sh'ı AYNI ANDA iki kez koşturur (aynı yük): origin/main kopyası ve bu dal. Süreleri 'sn=' olarak basar.
# kanit.sh bu betiğin çıktısını ve rc'sini imzalı ölçüm kaydına yazar → "en kötü ölçülmüş koşu" araç imzalı kayıttan okunur.
cd "$(git rev-parse --show-toplevel)" || exit 2
T="$(mktemp -d)"; M="$T/main"; G="$(mktemp -d)"
git fetch -q origin main || exit 2
git worktree add -q --detach "$M" origin/main || exit 2
( s=$(date +%s); bash "$M/yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh" >"$G/main.log" 2>&1; echo "main rc=$? sn=$(( $(date +%s)-s ))" >"$G/main.res" ) &
( s=$(date +%s); bash "./yazilim-fabrikasi/scripts/denetci-duzeltme-farki.test.sh" >"$G/dal.log" 2>&1; echo "dal rc=$? sn=$(( $(date +%s)-s ))" >"$G/dal.res" ) &
wait
cat "$G/main.res" "$G/dal.res"
tail -1 "$G/main.log" | cut -c1-100; tail -1 "$G/dal.log" | cut -c1-100
git worktree remove --force "$M" >/dev/null 2>&1
grep -q 'rc=0 ' "$G/main.res" && grep -q 'rc=0 ' "$G/dal.res"; rc=$?
exit $rc
