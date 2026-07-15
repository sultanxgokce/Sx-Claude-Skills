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

# ── FAZ-2: seans-getir + K3-primitifleri ─────────────────────────────────────────────────

# 6. seans-getir --apply guard: FAZ-3'te GERÇEK-çalışır AMA yalnız ISKAN_FAZ3_GO=1 env-marker'ıyla
#    (DOCTRINE Değişmez-3: kod-değişikliği tek-başına yeterli-tetik değil). Marker YOKSA exit=4 sabit.
env -u ISKAN_FAZ3_GO bash "$SCRIPT_DIR/iskan.sh" seans-getir --container cloudtop-code --apply >/dev/null 2>&1
[ "$?" = "4" ] && ok "seans-getir --apply: GO-marker yokken guard-exit=4" || bad "seans-getir --apply: rc beklenen 4"

# 7. seans-getir: desteklenmeyen container → doğrulanmadı + exit=3 (yazım yapmaz)
out="$(bash "$SCRIPT_DIR/iskan.sh" seans-getir --container cloudtop-baska-proje 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'doğrulanmadı' \
  && ok "seans-getir: bilinmeyen-container doğrulanmadı+exit=3" \
  || bad "seans-getir: bilinmeyen-container beklenen doğrulanmadı+rc=3, gelen rc=$rc"

# 8. seans-getir dry-run: fixture aile-registry ile deterministik alive/dead tespiti
#    (gerçek fleet zaman-içinde değişebileceğinden kendi geçici tmux-session'ımızı kurup test ediyoruz)
FIXTURE_REG="/tmp/iskan-test-registry.$$.yaml"
ALIVE_SESS="iskan-test-alive-$$"
cat > "$FIXTURE_REG" <<EOF
uyeler:
  - id: TESTALIVE
    tmux: "${ALIVE_SESS}:0"
    mod: kod
  - id: TESTDEAD
    tmux: "iskan-test-dead-neverexists-$$:0"
    mod: kod
EOF
tmux new-session -d -s "$ALIVE_SESS" 2>/dev/null
FIXTURE_TRANSCRIPT_DIR="/tmp/iskan-test-transcripts-empty.$$"
mkdir -p "$FIXTURE_TRANSCRIPT_DIR"
out="$(ISKAN_AILE_REGISTRY="$FIXTURE_REG" ISKAN_TRANSCRIPT_DIR="$FIXTURE_TRANSCRIPT_DIR" \
  bash "$SCRIPT_DIR/iskan.sh" seans-getir --container cloudtop-code 2>&1)"
rc=$?
tmux kill-session -t "$ALIVE_SESS" 2>/dev/null
if printf '%s' "$out" | grep -q "TESTALIVE" ; then
  bad "seans-getir fixture: TESTALIVE (canlı) yanlışlıkla kapalı-üye listelendi"
else
  ok "seans-getir fixture: TESTALIVE (canlı) doğru-şekilde ATLANDI"
fi
printf '%s' "$out" | grep -q "TESTDEAD" && printf '%s' "$out" | grep -q "degraded-replay" \
  && ok "seans-getir fixture: TESTDEAD tespit edildi + 0-aday→degraded-replay AÇIK-etiketli" \
  || bad "seans-getir fixture: TESTDEAD/degraded-replay beklenirdi"
[ "$rc" = "3" ] && ok "seans-getir fixture: kuru-koşu exit=3" || bad "seans-getir fixture: rc beklenen 3, gelen $rc"
rm -f "$FIXTURE_REG"
find "$FIXTURE_TRANSCRIPT_DIR" -type f -delete 2>/dev/null; find "$FIXTURE_TRANSCRIPT_DIR" -depth -type d -delete 2>/dev/null

# 9. legacy-kimlik-imza matcher: tek-anlamlı(1) vs belirsiz(2) vs 0-aday ayrımı
mk_sig_file() { # mk_sig_file <dosya> <rol>
  printf '{"message":{"role":"assistant","content":[{"type":"text","text":"🧑‍🚀 %s geri-yüklendi"}]}}\n' "$2" > "$1"
}
TDIR1="/tmp/iskan-test-imza-unique.$$"; mkdir -p "$TDIR1"
mk_sig_file "$TDIR1/aaa.jsonl" "TESTROL"
res="$(bash -c "source <(sed -n '/^_identity_imza_ara()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _identity_imza_ara TESTROL '$TDIR1'")"
[ "$res" = "aaa" ] && ok "legacy-imza: tek-dosya tek-anlamlı eşleşme (session-id=aaa)" || bad "legacy-imza: tek-eşleşme beklenirdi, gelen '$res'"
find "$TDIR1" -type f -delete 2>/dev/null; find "$TDIR1" -depth -type d -delete 2>/dev/null

TDIR2="/tmp/iskan-test-imza-ambiguous.$$"; mkdir -p "$TDIR2"
mk_sig_file "$TDIR2/bbb.jsonl" "TESTROL"
mk_sig_file "$TDIR2/ccc.jsonl" "TESTROL"
res="$(bash -c "source <(sed -n '/^_identity_imza_ara()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _identity_imza_ara TESTROL '$TDIR2'")"
n_virgul=$(printf '%s' "$res" | tr -cd ',' | wc -c)
[ "$n_virgul" = "1" ] && ok "legacy-imza: 2-dosya belirsiz-eşleşme doğru sayıldı (SUSPECT-adayı)" || bad "legacy-imza: 2-eşleşme beklenirdi, gelen '$res'"
find "$TDIR2" -type f -delete 2>/dev/null; find "$TDIR2" -depth -type d -delete 2>/dev/null

TDIR3="/tmp/iskan-test-imza-empty.$$"; mkdir -p "$TDIR3"
res="$(bash -c "source <(sed -n '/^_identity_imza_ara()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _identity_imza_ara TESTROL '$TDIR3'")"
[ -z "$res" ] && ok "legacy-imza: boş-dizin → 0-aday" || bad "legacy-imza: 0-aday beklenirdi, gelen '$res'"
find "$TDIR3" -depth -type d -delete 2>/dev/null

# 10. legacy-imza yalancı-pozitif KİLİDİ (firsthand-bulgu: geç-satırda başka-rol'ü konu-eden
#     metin sahte-eşleşme üretiyordu — whole-file-grep yerine role=assistant+ilk-60-satır kilidi)
TDIR4="/tmp/iskan-test-imza-late-mention.$$"; mkdir -p "$TDIR4"
{
  for i in $(seq 1 65); do
    printf '{"message":{"role":"user","content":[{"type":"text","text":"dolgu-satir %d"}]}}\n' "$i"
  done
  printf '{"message":{"role":"assistant","content":[{"type":"text","text":"metin-icinde BASKAROL geri-yuklendi kelimesi geciyor ama bu gercek-imza DEGIL"}]}}\n'
} > "$TDIR4/ddd.jsonl"
res="$(bash -c "source <(sed -n '/^_identity_imza_ara()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _identity_imza_ara BASKAROL '$TDIR4'")"
[ -z "$res" ] && ok "legacy-imza: 60-satır-sonrası geç-mention YAKALANMADI (whole-file-grep-tuzağı kapalı)" \
  || bad "legacy-imza: geç-mention 0-aday vermeliydi, gelen '$res'"
find "$TDIR4" -type f -delete 2>/dev/null; find "$TDIR4" -depth -type d -delete 2>/dev/null

# 11. acquire_role_lock: ikinci-kilit aynı session-id'yi ALAMAZ (pane-sahiplik-kuralı, G6)
LOCK_TEST_SID="iskan-test-lock-$$"
LOCK_TEST_DIR="/tmp/iskan-test-locks.$$"
HOLDER_SCRIPT="/tmp/iskan-test-holder.$$.sh"
CHALLENGER_SCRIPT="/tmp/iskan-test-challenger.$$.sh"
cat > "$HOLDER_SCRIPT" <<EOF
source <(sed -n '/^acquire_role_lock()/,/^}/p' "$SCRIPT_DIR/iskan.sh")
export ISKAN_LOCK_DIR="$LOCK_TEST_DIR"
acquire_role_lock "$LOCK_TEST_SID" >/dev/null
sleep 2
EOF
cat > "$CHALLENGER_SCRIPT" <<EOF
source <(sed -n '/^acquire_role_lock()/,/^}/p' "$SCRIPT_DIR/iskan.sh")
export ISKAN_LOCK_DIR="$LOCK_TEST_DIR"
acquire_role_lock "$LOCK_TEST_SID" >/dev/null 2>&1
exit \$?
EOF
bash "$HOLDER_SCRIPT" &
HOLDER_PID=$!
sleep 0.5
bash "$CHALLENGER_SCRIPT"
CHALLENGER_RC=$?
wait "$HOLDER_PID" 2>/dev/null
[ "$CHALLENGER_RC" != "0" ] && ok "acquire_role_lock: ikinci-eşzamanlı-kilit reddedildi (flock, G6)" || bad "acquire_role_lock: ikinci-kilit BAŞARILI oldu (kilitleme çalışmıyor)"
rm -f "$HOLDER_SCRIPT" "$CHALLENGER_SCRIPT"
find "$LOCK_TEST_DIR" -type f -delete 2>/dev/null; find "$LOCK_TEST_DIR" -depth -type d -delete 2>/dev/null

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
