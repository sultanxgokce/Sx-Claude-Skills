#!/usr/bin/env bash
# iskan.test.sh — İSKÂN FAZ-1 offline-testleri (host/ağ bağımsız, fixture-tabanlı).
#
# Kapsam: compose_parse.py doğruluğu (B1 kesişim-tespiti) + iskan-host.sh dry-run'ın
# host-erişimi olmasa bile plan-exit sözleşmesine (rc=3) uyduğu + iskan/scripts/ içinde
# silme-primitifi bulunmadığı (G1'in kendi kilidi — regresyona erken yakalar).
#
# Bu test canlı ssh/hostsrv gerektirmez (ISKAN_SSH_HOST bilinçli-bozuk-host'a işaret eder).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

ok() { PASS=$((PASS+1)); echo "  ok - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }

echo "== iskan.test.sh =="

# 1. compose_parse temiz-fixture: kesişim=0
out="$(python3 "$SCRIPT_DIR/lib/compose_parse.py" "$SCRIPT_DIR/fixtures/compose-clean.yml" 2>/dev/null)"
n_int="$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["intersections"]))' 2>/dev/null)"
[ "$n_int" = "0" ] && ok "compose-clean: kesişim=0" || bad "compose-clean: kesişim beklenen 0, gelen '$n_int'"

# 2. compose_parse çakışma-fixture: kesişim=1 tespit edilir
out="$(python3 "$SCRIPT_DIR/lib/compose_parse.py" "$SCRIPT_DIR/fixtures/compose-collision.yml" 2>/dev/null)"
n_int="$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["intersections"]))' 2>/dev/null)"
[ "$n_int" = "1" ] && ok "compose-collision: kesişim=1 tespit edildi (B1)" || bad "compose-collision: kesişim beklenen 1, gelen '$n_int'"

# 3. compose_parse stdin ("-") desteği
out2="$(cat "$SCRIPT_DIR/fixtures/compose-clean.yml" | python3 "$SCRIPT_DIR/lib/compose_parse.py" - 2>/dev/null)"
[ "$out2" = "$(python3 "$SCRIPT_DIR/lib/compose_parse.py" "$SCRIPT_DIR/fixtures/compose-clean.yml" 2>/dev/null)" ] \
  && ok "compose_parse: stdin('-') dosya-argümanıyla bayt-eş" || bad "compose_parse: stdin çıktısı dosya-argümanından farklı"

# 4. iskan-host.sh --dry-run: host erişilemese BİLE plan-exit sözleşmesi (rc=3) korunur
ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" \
  bash "$SCRIPT_DIR/iskan-host.sh" --dry-run >/tmp/iskan-test-dryrun.$$ 2>&1
rc=$?
[ "$rc" = "3" ] && ok "iskan-host.sh --dry-run: host-erişilemez durumda da rc=3" || bad "iskan-host.sh --dry-run: rc beklenen 3, gelen $rc"
grep -qE 'doğrulanmadı' /tmp/iskan-test-dryrun.$$ && ok "iskan-host.sh --dry-run: erişilemeyen-host 'doğrulanmadı' diliyle raporlandı" \
  || bad "iskan-host.sh --dry-run: 'doğrulanmadı' beklenirdi"
rm -f /tmp/iskan-test-dryrun.$$

# 5. iskan-host.sh: --dry-run dışı argüman reddedilir (usage + rc=2)
bash "$SCRIPT_DIR/iskan-host.sh" >/dev/null 2>&1
[ "$?" = "2" ] && ok "iskan-host.sh: argümansız çağrı rc=2 (usage)" || bad "iskan-host.sh: argümansız rc beklenen 2"

# NOT: G1'in kendi put-only-gate grep-deseni burada BİLEREK tekrarlanmıyor — o deseni bu
# dosyaya (iskan/scripts/ altına) literal yazmak kendi-kendini-eşleyip sahte-KIRMIZI üretir
# (bkz Nexus CLAUDE.md "Araç & Hook Sürtünmesi": pattern'i literal yazma, tarif et). Gerçek
# put-only doğrulaması GEREKLILIK.md G1'in kendisinde koşar (iskan/scripts/ dışından).

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
