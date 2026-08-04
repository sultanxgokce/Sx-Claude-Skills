#!/bin/sh
# kos.sh — /kesif PORTABILITY-KANITI: MMEx-DIŞI statik-panel + config-swap → generic-core (e2e-run) koşar.
# Kanıtlar: endpoint (/fixture/data) + selector ([data-testid=widget]) + origin (:8099) MMEx'ten FARKLI,
# generic-runner DEĞİŞMEDEN çalışır → çekirdek proje-bilmez. Chromium pw-libs bootstrap gerektirir.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPTS="$DIR/../scripts"
PORT=${1:-8099}
KANIT=$(mktemp -d)

sh "$SCRIPTS/../scripts/pw/bootstrap.sh" --skip-selftest 2>/dev/null || true  # pw-libs hazır değilse kur (idempotent)

node "$DIR/serve-fixture.mjs" "$PORT" >/dev/null 2>&1 &
FPID=$!
trap 'kill $FPID 2>/dev/null || true' EXIT
sleep 1

sh "$SCRIPTS/e2e-env.sh" node "$SCRIPTS/e2e-run.mjs" \
  --panel-url "http://127.0.0.1:$PORT/" --allowlist "http://127.0.0.1:$PORT" \
  --senaryolar "$DIR/senaryolar-fixture.mjs" --kanit "$KANIT" >/dev/null 2>&1 || true

node -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1]+"/e2e-senaryolar.json","utf8"));
const ok=j.kalan===0 && j.allowlist_ihlali.length===0 && j.gecen>0;
console.log((ok?"PORTABILITY-PASS":"PORTABILITY-FAIL")+": kesif config-swap → generic-core "+j.gecen+"/"+j.toplam+" (allowlist-ihlali="+j.allowlist_ihlali.length+")");
process.exit(ok?0:1);
' "$KANIT"
