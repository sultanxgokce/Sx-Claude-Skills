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

# ── FAZ-4: yeni-proje (compose-blok üreteci) ─────────────────────────────────────────────

# 12. yeni-proje --dry-run: plan-exit=3, hiçbir dosya yazılmaz, önizleme port+blok içerir
YP_FIXTURE="/tmp/iskan-test-yp-dryrun.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE"
SUM_BEFORE="$(md5sum "$YP_FIXTURE")"
out="$(ISKAN_REPO_COMPOSE="$YP_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --dry-run 2>&1)"
rc=$?
SUM_AFTER="$(md5sum "$YP_FIXTURE")"
[ "$rc" = "3" ] && ok "yeni-proje --dry-run: plan-exit=3" || bad "yeni-proje --dry-run: rc beklenen 3, gelen $rc"
[ "$SUM_BEFORE" = "$SUM_AFTER" ] && ok "yeni-proje --dry-run: dosya değişmedi" || bad "yeni-proje --dry-run: dosya DEĞİŞTİ (yazmamalıydı)"
printf '%s' "$out" | grep -q "cloudtop-testproje" && printf '%s' "$out" | grep -q "8449" \
  && ok "yeni-proje --dry-run: önizleme container-adı+port içeriyor" || bad "yeni-proje --dry-run: beklenen içerik eksik"
find /tmp -maxdepth 1 -name "iskan-test-yp-dryrun.$$.yml" -delete 2>/dev/null

# 13. yeni-proje --apply: GO-marker yokken exit=4, dosya SIFIR-değişir (negatif-kapı, G3-emsali)
YP_FIXTURE2="/tmp/iskan-test-yp-neggate.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE2"
SUM_BEFORE2="$(md5sum "$YP_FIXTURE2")"
env -u ISKAN_FAZ4_GO ISKAN_REPO_COMPOSE="$YP_FIXTURE2" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
SUM_AFTER2="$(md5sum "$YP_FIXTURE2")"
[ "$rc" != "0" ] && ok "yeni-proje --apply: GO-marker yokken exit≠0 ($rc)" || bad "yeni-proje --apply: GO-marker yokken exit=0 (guard delindi)"
[ "$SUM_BEFORE2" = "$SUM_AFTER2" ] && ok "yeni-proje --apply: GO-marker yokken dosya SIFIR-değişti" || bad "yeni-proje --apply: GO-marker yokken dosya DEĞİŞTİ (kritik-ihlal)"
find /tmp -maxdepth 1 -name "iskan-test-yp-neggate.$$.yml" -delete 2>/dev/null

# 14. yeni-proje --apply: GO-marker'lı, geçerli-YAML üretir, tek-blok ekler (append-only)
YP_FIXTURE3="/tmp/iskan-test-yp-apply.$$.yml"
YP_LOCKDIR3="/tmp/iskan-test-yp-lockdir.$$"
mkdir -p "$YP_LOCKDIR3"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE3"
ORIG_HEAD="$(head -5 "$YP_FIXTURE3")"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE3" ISKAN_PORT_LOCK_PATH="$YP_LOCKDIR3/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] && ok "yeni-proje --apply: GO-marker'lı başarılı, rc=0" || bad "yeni-proje --apply: GO-marker'lı beklenen rc=0, gelen $rc"
python3 -c "import yaml; yaml.safe_load(open('$YP_FIXTURE3'))" >/dev/null 2>&1 \
  && ok "yeni-proje --apply: sonuç geçerli-YAML" || bad "yeni-proje --apply: sonuç YAML-parse-hatası (bozuk-yazım)"
NEW_HEAD="$(head -5 "$YP_FIXTURE3")"
[ "$ORIG_HEAD" = "$NEW_HEAD" ] && ok "yeni-proje --apply: mevcut satırlara dokunulmadı (append-only, baş-değişmedi)" \
  || bad "yeni-proje --apply: dosya-başı DEĞİŞTİ (append-only ihlali)"
grep -qE "container_name:[[:space:]]*cloudtop-testproje\$" "$YP_FIXTURE3" \
  && ok "yeni-proje --apply: yeni servis-bloğu eklendi" || bad "yeni-proje --apply: yeni servis-bloğu bulunamadı"
find /tmp -maxdepth 1 -name "iskan-test-yp-apply.$$.yml" -delete 2>/dev/null
find "$YP_LOCKDIR3" -type f -delete 2>/dev/null; find "$YP_LOCKDIR3" -depth -type d -delete 2>/dev/null

# 15. yeni-proje İDEMPOTENCY: aynı-ad İKİNCİ-kez → apply rc=0 + dosya-değişmez; dry-run rc=3;
#     GO'suz apply mevcut-blokta BİLE exit≠0 (G3 negatif-kapı idempotent-yoldan delinmez)
YP_FIXTURE4="/tmp/iskan-test-yp-dup.$$.yml"
YP_LOCKDIR4="/tmp/iskan-test-yp-lockdir4.$$"
mkdir -p "$YP_LOCKDIR4"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE4"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4" ISKAN_PORT_LOCK_PATH="$YP_LOCKDIR4/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
SUM_DUP_BEFORE="$(md5sum "$YP_FIXTURE4" | awk '{print $1}')"
out="$(ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4" ISKAN_PORT_LOCK_PATH="$YP_LOCKDIR4/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply 2>&1)"
rc=$?
SUM_DUP_AFTER="$(md5sum "$YP_FIXTURE4" | awk '{print $1}')"
[ "$rc" = "0" ] && ok "yeni-proje --apply: aynı-ad ikinci-kez İDEMPOTENT-geçiş (rc=0)" || bad "yeni-proje --apply: idempotent-geçiş beklenirdi (rc=0), gelen $rc"
[ "$SUM_DUP_BEFORE" = "$SUM_DUP_AFTER" ] && ok "yeni-proje --apply: idempotent-geçişte dosya DEĞİŞMEDİ" || bad "yeni-proje --apply: idempotent-geçişte dosya DEĞİŞTİ (yeniden-yazım ihlali)"
printf '%s' "$out" | grep -q "İDEMPOTENT" && ok "yeni-proje --apply: idempotent-geçiş açıkça beyan edildi" || bad "yeni-proje --apply: idempotent-beyanı çıktıda yok"
ISKAN_REPO_COMPOSE="$YP_FIXTURE4" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --dry-run >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] && ok "yeni-proje --dry-run: mevcut-blokta plan-exit=3 (idempotent-önizleme)" || bad "yeni-proje --dry-run: mevcut-blokta beklenen rc=3, gelen $rc"
env -u ISKAN_FAZ4_GO ISKAN_REPO_COMPOSE="$YP_FIXTURE4" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && ok "yeni-proje --apply: mevcut-blokta bile GO'suz exit≠0 ($rc)" || bad "yeni-proje --apply: GO'suz idempotent-yol exit=0 (negatif-kapı delindi)"
find /tmp -maxdepth 1 -name "iskan-test-yp-dup.$$.yml" -delete 2>/dev/null
find "$YP_LOCKDIR4" -type f -delete 2>/dev/null; find "$YP_LOCKDIR4" -depth -type d -delete 2>/dev/null

# 16. yeni-proje --apply: B1 kesişim-guard — aday-blok mevcut bir volume-yolunu tekrar-kullanırsa RED
#     (compose-collision.yml fixture'ı zaten bir kesişim içeriyor; yeni-servis AYNI path'i mount ederse ek-kesişim doğar)
YP_FIXTURE5="/tmp/iskan-test-yp-b1.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-collision.yml" "$YP_FIXTURE5"
# fixture'daki mevcut bir servisin volume-host-path'ini oku, kendi ürettiğimiz bloğun İÇİNE enjekte edip B1'i tetikle
EXISTING_PATH="$(python3 -c "
import yaml
d = yaml.safe_load(open('$YP_FIXTURE5'))
for name, svc in d.get('services', {}).items():
    for v in svc.get('volumes', []) or []:
        print(str(v).split(':')[0]); raise SystemExit
")"
if [ -n "$EXISTING_PATH" ]; then
  # yeni-proje bloğunu üret, kendi config-dizinini fixture'ın mevcut-path'iyle DEĞİŞTİR → yapay-kesişim
  BLOK_TEXT="$(ISKAN_REPO_COMPOSE="$YP_FIXTURE5" bash "$SCRIPT_DIR/iskan.sh" yeni-proje b1test --dry-run 2>/dev/null | sed -n '/^  cloudtop-b1test:/,/max-file/p')"
  BLOK_COLLIDING="$(printf '%s' "$BLOK_TEXT" | sed "s#\./config-b1test:/config#${EXISTING_PATH}:/config#")"
  # NOT: "services:" ÖNEKİ EKLENMEZ — gerçek _iskan_b1_check akışında blok, repo_compose'un
  # ZATEN-açık services: eşleşmesine append edilir; ikinci "services:" anahtarı YAML'da
  # ÖNCEKİNİ EZER (duplicate-key) → alpha/beta sessizce kaybolur, yapay-negatif üretirdi (firsthand-bulgu).
  printf '%s\n' "$BLOK_COLLIDING" > "/tmp/iskan-test-b1-injected.$$.yml"
  n_new="$(bash -c "
    source <(sed -n '/^_iskan_b1_check()/,/^}/p' '$SCRIPT_DIR/iskan.sh')
    COMPOSE_PARSE='$SCRIPT_DIR/lib/compose_parse.py'
    _iskan_b1_check '$YP_FIXTURE5' '/tmp/iskan-test-b1-injected.$$.yml'
  ")"
  [ "$n_new" != "0" ] && ok "_iskan_b1_check: mevcut-path'i tekrar-kullanan aday-blok YENİ-kesişim olarak tespit edildi ($n_new)" \
    || bad "_iskan_b1_check: yapay-çakışma tespit edilemedi (B1 guard çalışmıyor), gelen '$n_new'"
  find /tmp -maxdepth 1 -name "iskan-test-b1-injected.$$.yml" -delete 2>/dev/null
else
  bad "B1-test: fixture'dan mevcut-volume-path okunamadı (test-hazırlığı başarısız)"
fi
find /tmp -maxdepth 1 -name "iskan-test-yp-b1.$$.yml" -delete 2>/dev/null

# 17. iskan-host.sh --apply: GO-marker yokken exit≠0, hostsrv'e HİÇ dokunulmaz (ssh-çağrısı yapılmadan erken-exit)
env -u ISKAN_FAZ4_GO ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje testproje >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && ok "iskan-host.sh --apply: GO-marker yokken exit≠0 (host'a hiç değmeden erken-guard)" \
  || bad "iskan-host.sh --apply: GO-marker yokken exit=0 (guard delindi)"

# 18. iskan-host.sh --apply: REPO-KANIT kapısı — aday origin/main'de YOKSA ssh'a hiç değmeden RED
#     (hermetik mini-repo: origin=kendisi, compose'da aday-servis yok → git-show başarır ama grep bulamaz)
RK_REPO="/tmp/iskan-test-rk-repo.$$"
mkdir -p "$RK_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$RK_REPO/infra/docker-compose.server.yml"
git -C "$RK_REPO" init -q -b main 2>/dev/null
git -C "$RK_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$RK_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$RK_REPO" remote add origin "$RK_REPO" 2>/dev/null
ISKAN_FAZ4_GO=1 ISKAN_CLOUDTOP_REPO_DIR="$RK_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  ISKAN_KANIT_DIR="/tmp/iskan-test-rk-kanit.$$" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje testproje >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && ok "iskan-host.sh --apply: REPO-KANIT yokken RED (rc=$rc, host'a değmeden)" \
  || bad "iskan-host.sh --apply: REPO-KANIT yokken exit=0 (REPO-FIRST kapısı delindi)"
for d in "$RK_REPO" "/tmp/iskan-test-rk-kanit.$$"; do
  find "$d" -type f -delete 2>/dev/null; find "$d" -depth -type d -delete 2>/dev/null
done

# ── FAZ-5: cf-yayin (CF-hostname yayını) ─────────────────────────────────────────────────

# 19. cf-yayin --dry-run: plan-exit=3, hiçbir dosya değişmez, önizleme hostname+onboard+sert-kapı içerir
CF_FIXTURE="/tmp/iskan-test-cf-dryrun.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$CF_FIXTURE"
SUM_CF_BEFORE="$(md5sum "$CF_FIXTURE")"
out="$(ISKAN_REPO_COMPOSE="$CF_FIXTURE" ISKAN_CLOUDTOP_REPO_DIR="/tmp/iskan-yok.$$" \
  bash "$SCRIPT_DIR/iskan.sh" cf-yayin cftest --dry-run 2>&1)"
rc=$?
SUM_CF_AFTER="$(md5sum "$CF_FIXTURE")"
[ "$rc" = "3" ] && ok "cf-yayin --dry-run: plan-exit=3" || bad "cf-yayin --dry-run: rc beklenen 3, gelen $rc"
[ "$SUM_CF_BEFORE" = "$SUM_CF_AFTER" ] && ok "cf-yayin --dry-run: dosya değişmedi" || bad "cf-yayin --dry-run: dosya DEĞİŞTİ"
printf '%s' "$out" | grep -q "cftest.mmepanel.com" && printf '%s' "$out" | grep -q "onboard" \
  && printf '%s' "$out" | grep -q "SERT-KAPI" \
  && ok "cf-yayin --dry-run: önizleme hostname+onboard+sert-kapı içeriyor" \
  || bad "cf-yayin --dry-run: beklenen önizleme-içeriği eksik"
find /tmp -maxdepth 1 -name "iskan-test-cf-dryrun.$$.yml" -delete 2>/dev/null

# 20. cf-yayin --apply: GO-marker yokken exit=4, ssh'a/CF'e HİÇ değmeden erken-guard (bozuk-host + bozuk-cf.sh ile kanıt)
env -u ISKAN_FAZ5_GO ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_CF_SH="/tmp/iskan-yok-cf.$$.sh" \
  ISKAN_CLOUDTOP_REPO_DIR="/tmp/iskan-yok.$$" \
  bash "$SCRIPT_DIR/iskan.sh" cf-yayin cftest --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "4" ] && ok "cf-yayin --apply: GO-marker yokken guard-exit=4 (CF'e/host'a sıfır-dokunuş)" \
  || bad "cf-yayin --apply: GO-marker yokken rc beklenen 4, gelen $rc"

# 21. cf-yayin --apply: GO'lu ama REPO-KANIT yok (hermetik mini-repo, setup-tunnel'da hostname yok) → ssh'a değmeden RED
CF_RK_REPO="/tmp/iskan-test-cfrk-repo.$$"
mkdir -p "$CF_RK_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$CF_RK_REPO/infra/docker-compose.server.yml"
printf '#!/usr/bin/env bash\n# fixture setup-tunnel (cftest satırı BİLEREK yok)\n' > "$CF_RK_REPO/infra/setup-tunnel.sh"
git -C "$CF_RK_REPO" init -q -b main 2>/dev/null
git -C "$CF_RK_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$CF_RK_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$CF_RK_REPO" remote add origin "$CF_RK_REPO" 2>/dev/null
ISKAN_FAZ5_GO=1 ISKAN_CLOUDTOP_REPO_DIR="$CF_RK_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" cf-yayin cftest --apply >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && [ "$rc" != "4" ] && ok "cf-yayin --apply: REPO-KANIT yokken RED (rc=$rc, host'a değmeden)" \
  || bad "cf-yayin --apply: REPO-KANIT yokken beklenen rc∉{0,4}, gelen $rc"
find "$CF_RK_REPO" -type f -delete 2>/dev/null; find "$CF_RK_REPO" -depth -type d -delete 2>/dev/null

# 22. _cf_yedi_hostname_temiz_mi: 302/401/403 temiz; 502/000 kirli
res_temiz="$(bash -c "
  source <(sed -n '/^_cf_yedi_hostname_temiz_mi()/,/^}/p' '$SCRIPT_DIR/iskan.sh')
  _cf_yedi_hostname_temiz_mi 'pc=302 code=302 vekatip=403 m=401 ' && echo TEMIZ || echo KIRLI
")"
res_kirli="$(bash -c "
  source <(sed -n '/^_cf_yedi_hostname_temiz_mi()/,/^}/p' '$SCRIPT_DIR/iskan.sh')
  _cf_yedi_hostname_temiz_mi 'pc=302 code=502 vekatip=302 ' && echo TEMIZ || echo KIRLI
")"
res_sifir="$(bash -c "
  source <(sed -n '/^_cf_yedi_hostname_temiz_mi()/,/^}/p' '$SCRIPT_DIR/iskan.sh')
  _cf_yedi_hostname_temiz_mi 'pc=000 code=302 ' && echo TEMIZ || echo KIRLI
")"
[ "$res_temiz" = "TEMIZ" ] && [ "$res_kirli" = "KIRLI" ] && [ "$res_sifir" = "KIRLI" ] \
  && ok "_cf_yedi_hostname_temiz_mi: 302/401/403=temiz · 502=kirli · 000=kirli (sert-kapı sınıflandırması)" \
  || bad "_cf_yedi_hostname_temiz_mi: sınıflandırma hatalı (temiz=$res_temiz kirli=$res_kirli sifir=$res_sifir)"

# ── FAZ-6: ekip-yerlestir (ekip-yerleştirme) + baslat-claude sarmalayıcısı ────────────────

# ortak hermetik mini-repo: origin/main compose'unda cloudtop-eytest kayıtlı
EY_REPO="/tmp/iskan-test-ey-repo.$$"
mkdir -p "$EY_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$EY_REPO/infra/docker-compose.server.yml"
cat >> "$EY_REPO/infra/docker-compose.server.yml" <<'EOF'

  cloudtop-eytest:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-eytest
    ports:
      - "127.0.0.1:9449:8443"
EOF
git -C "$EY_REPO" init -q -b main 2>/dev/null
git -C "$EY_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$EY_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$EY_REPO" remote add origin "$EY_REPO" 2>/dev/null

# 23. ekip-yerlestir: argüman-eksikliği → usage rc=2
bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir >/dev/null 2>&1
[ "$?" = "2" ] && ok "ekip-yerlestir: argümansız rc=2 (usage)" || bad "ekip-yerlestir: argümansız rc beklenen 2"

# 24. ekip-yerlestir --dry-run: plan-exit=3 + roster-adları (ISKAN_EY_ROSTER açık-override'ından)
#     önizlemede. (D6 tuzak-fix: hardcoded SABİT-default fallback KALDIRILDI — roster artık
#     yalnız açık-override ya da container-içi ekip-registry'den gelir; kaynaksız hâl test 24b'de.)
out="$(ISKAN_EY_ROSTER="denekAlfa:yonetici denekBeta:uye" \
  ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir eytest --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && ok "ekip-yerlestir --dry-run: plan-exit=3" || bad "ekip-yerlestir --dry-run: rc beklenen 3, gelen $rc"
printf '%s' "$out" | grep -q "denekAlfa" && printf '%s' "$out" | grep -q "denekBeta" \
  && ok "ekip-yerlestir --dry-run: roster-adları (denekAlfa+denekBeta) önizlemede görünür" \
  || bad "ekip-yerlestir --dry-run: roster-adları önizlemede eksik"
printf '%s' "$out" | grep -q "scaffold" && printf '%s' "$out" | grep -qi "rezerv" \
  && ok "ekip-yerlestir --dry-run: scaffold + rezerv-uuid adımları önizlemede görünür" \
  || bad "ekip-yerlestir --dry-run: scaffold/rezerv-uuid adımı önizlemede eksik"

# 24b. D6 tuzak-fix: roster-kaynağı YOKKEN (override yok + ssh-bozuk → ekip-registry okunamaz)
#      dürüst-kırmızı rc=1 + 'roster-kaynağı yok' marker + SAHTE-EKİP adları (denek*) ASLA basılmaz
out="$(env -u ISKAN_EY_ROSTER ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir eytest --dry-run 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'roster-kaynağı yok' && ! printf '%s' "$out" | grep -q 'denekAlfa' \
  && ok "ekip-yerlestir roster-kaynaksız: dürüst-kırmızı rc=1 + 'roster-kaynağı yok' + sahte-ekip adı basılmadı (D6 tuzak-fix)" \
  || bad "ekip-yerlestir roster-kaynaksız: dürüst-kırmızı sözleşmesi kırık (rc=$rc)"

# 25. ekip-yerlestir NEGATİF-KAPI (K4 TAM-STRING): bilinmeyen ad → rc≠0 + 'kayitsiz-proje' marker;
#     önek ('eytes') ve case-farkı ('EYTEST') da reddedilir (fuzzy yasak)
out="$(ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir hayaletproje --apply 2>&1)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'kayitsiz-proje' \
  && ok "ekip-yerlestir --apply: bilinmeyen-proje rc≠0 + 'kayitsiz-proje' marker" \
  || bad "ekip-yerlestir --apply: bilinmeyen-proje beklenen rc≠0+marker, gelen rc=$rc"
for p in eytes EYTEST; do
  ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
    bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir "$p" --apply >/dev/null 2>&1
  rc=$?
  [ "$rc" != "0" ] && ok "ekip-yerlestir --apply: '$p' (önek/case-farkı) reddedildi rc=$rc (K4 fuzzy-yasak)" \
    || bad "ekip-yerlestir --apply: '$p' KABUL edildi (K4 ihlali)"
done

# 26. ekip-yerlestir --apply: kayıtlı-proje ama host-erişilemez → rc=1, mutasyonsuz erken-kırmızı
ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir eytest --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "1" ] && ok "ekip-yerlestir --apply: host-erişilemezken rc=1 (mutasyonsuz erken-kırmızı)" \
  || bad "ekip-yerlestir --apply: host-erişilemezken beklenen rc=1, gelen $rc"

# 27. ekip-yerlestir rezerv-uuid YENİDEN-KULLANIM: origin/main iskan-registry'de kayıtlı uuid
#     dry-run önizlemesinde 'mevcut' kaynaklı olarak AYNEN görünür (yeniden-üretilmez)
EY_UUID_SABIT="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
cat > "$EY_REPO/infra/iskan-registry.yaml" <<EOF
proje: eytest
container_adi: cloudtop-eytest
uyeler:
  - id: denekAlfa
    tmux: "denekAlfa:0"
    cwd: /config/projects/eytest
    session_id: $EY_UUID_SABIT
    permission_mode: default
EOF
git -C "$EY_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$EY_REPO" -c user.email=t@t -c user.name=t commit -qm reg 2>/dev/null
out="$(ISKAN_EY_ROSTER="denekAlfa:yonetici denekBeta:uye" \
  ISKAN_CLOUDTOP_REPO_DIR="$EY_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir eytest --dry-run 2>&1)"
printf '%s' "$out" | grep -q "$EY_UUID_SABIT" \
  && ok "ekip-yerlestir: kayıtlı rezerv-uuid YENİDEN-KULLANILIR (origin/main'den okundu, yeniden-üretilmedi)" \
  || bad "ekip-yerlestir: kayıtlı rezerv-uuid önizlemede yok (yeniden-kullanım kırık)"
printf '%s' "$out" | grep "denekBeta" | grep -q "yeni" \
  && ok "ekip-yerlestir: kayıtsız-üye (denekBeta) için 'yeni' uuid-kaynağı raporlanır" \
  || bad "ekip-yerlestir: kayıtsız-üye uuid-kaynağı 'yeni' değil"

find "$EY_REPO" -type f -delete 2>/dev/null; find "$EY_REPO" -depth -type d -delete 2>/dev/null

# 28. baslat-claude.sh: registry'den rol çözer; claude PATH'te YOKKEN dürüst-kırmızı
#     (exit≠0 + 'claude-binary yok' marker, G9 sözleşmesi); rol-kayıtsız → exit≠0
BC_DIR="/tmp/iskan-test-bc.$$"
mkdir -p "$BC_DIR/scripts"
cp "$SCRIPT_DIR/../templates/baslat-claude.sh" "$BC_DIR/scripts/baslat-claude.sh"
cat > "$BC_DIR/iskan-registry.yaml" <<'EOF'
proje: bctest
uyeler:
  - id: denekAlfa
    tmux: "denekAlfa:0"
    cwd: /tmp
    session_id: 12345678-1234-1234-1234-123456789abc
    permission_mode: default
EOF
out="$(PATH="/usr/bin:/bin" bash "$BC_DIR/scripts/baslat-claude.sh" denekAlfa 2>&1)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'claude-binary yok' \
  && ok "baslat-claude.sh: claude yokken dürüst-kırmızı (rc=$rc + 'claude-binary yok' marker)" \
  || bad "baslat-claude.sh: dürüst-kırmızı sözleşmesi kırık (rc=$rc)"
PATH="/usr/bin:/bin" bash "$BC_DIR/scripts/baslat-claude.sh" hayaletrol >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && ok "baslat-claude.sh: rol-kayıtsız → rc≠0 ($rc)" || bad "baslat-claude.sh: rol-kayıtsız kabul edildi"

# 29. baslat-claude.sh: claude-stub PATH'teyken rezerve session-id + rol-adı + permission-mode ile exec eder
cat > "$BC_DIR/claude" <<'EOF'
#!/usr/bin/env bash
echo "STUB-CLAUDE $*"
EOF
chmod +x "$BC_DIR/claude"
out="$(PATH="$BC_DIR:/usr/bin:/bin" bash "$BC_DIR/scripts/baslat-claude.sh" denekAlfa 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q -- "--session-id 12345678-1234-1234-1234-123456789abc" \
  && printf '%s' "$out" | grep -q -- "--name denekAlfa" && printf '%s' "$out" | grep -q -- "--permission-mode default" \
  && ok "baslat-claude.sh: claude-varken rezerve-id+rol+permission-mode ile exec (K3 disiplini)" \
  || bad "baslat-claude.sh: exec-argümanları sözleşme-dışı (rc=$rc: $out)"
find "$BC_DIR" -type f -delete 2>/dev/null; find "$BC_DIR" -depth -type d -delete 2>/dev/null

# ── FAZ-7: uye-ekle (tek-üye iskânı) + roster-köprüsü + KÂHYA-adaptörü ────────────────────

# ortak hermetik mini-repo: origin/main compose'unda cloudtop-uetest + iskan-registry'de denekAlfa kayıtlı
UE_REPO="/tmp/iskan-test-ue-repo.$$"
UE_UUID_SABIT="11111111-2222-3333-4444-555555555555"
mkdir -p "$UE_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$UE_REPO/infra/docker-compose.server.yml"
cat >> "$UE_REPO/infra/docker-compose.server.yml" <<'EOF'

  cloudtop-uetest:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-uetest
    ports:
      - "127.0.0.1:9459:8443"
EOF
cat > "$UE_REPO/infra/iskan-registry.yaml" <<EOF
proje: uetest
container_adi: cloudtop-uetest
uyeler:
  - id: denekAlfa
    tmux: "denekAlfa:0"
    cwd: /config/projects/uetest
    session_id: $UE_UUID_SABIT
    permission_mode: default
EOF
git -C "$UE_REPO" init -q -b main 2>/dev/null
git -C "$UE_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$UE_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$UE_REPO" remote add origin "$UE_REPO" 2>/dev/null

# 30. uye-ekle: argüman-eksikliği → usage rc=2 (proje-yalnız / mod-yok varyantları)
bash "$SCRIPT_DIR/iskan.sh" uye-ekle >/dev/null 2>&1
rc1=$?
bash "$SCRIPT_DIR/iskan.sh" uye-ekle uetest denekGamma >/dev/null 2>&1
rc2=$?
[ "$rc1" = "2" ] && [ "$rc2" = "2" ] && ok "uye-ekle: eksik-argüman/mod rc=2 (usage)" || bad "uye-ekle: usage rc beklenen 2, gelen $rc1/$rc2"

# 31. uye-ekle --dry-run (yeni-üye): plan-exit=3 + üye-adı + 'sultan-bildirim' satırı (G2 sözleşmesi)
SUM_UE_BEFORE="$(md5sum "$UE_REPO/infra/iskan-registry.yaml")"
out="$(ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" uye-ekle uetest denekGamma --dry-run 2>&1)"
rc=$?
SUM_UE_AFTER="$(md5sum "$UE_REPO/infra/iskan-registry.yaml")"
[ "$rc" = "3" ] && ok "uye-ekle --dry-run: plan-exit=3" || bad "uye-ekle --dry-run: rc beklenen 3, gelen $rc"
printf '%s' "$out" | grep -q "denekGamma" && printf '%s' "$out" | grep -q "sultan-bildirim" \
  && ok "uye-ekle --dry-run: üye-adı + 'sultan-bildirim' satırı önizlemede" \
  || bad "uye-ekle --dry-run: üye-adı/sultan-bildirim eksik"
[ "$SUM_UE_BEFORE" = "$SUM_UE_AFTER" ] && ok "uye-ekle --dry-run: dosya değişmedi" || bad "uye-ekle --dry-run: dosya DEĞİŞTİ (yazmamalıydı)"

# 32. uye-ekle --dry-run MEVCUT-üye (denekAlfa): rc=3 KORUNUR + 'sultan-bildirim' KOŞULSUZ basılır
#     (G2 NOT-2: idempotent/mevcut→atla önizlemesi DAHİL) + çakışma-uyarısı 'uye-zaten-var' önizlenir
out="$(ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" uye-ekle uetest denekAlfa --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q "sultan-bildirim" && printf '%s' "$out" | grep -q "uye-zaten-var" \
  && ok "uye-ekle --dry-run: mevcut-üyede de rc=3 + sultan-bildirim koşulsuz + çakışma-önizlemesi" \
  || bad "uye-ekle --dry-run: mevcut-üye sözleşmesi kırık (rc=$rc)"

# 33. uye-ekle Nexus-ailesi evi (cloudtop-code, TAM-STRING): CANLI-invoke YOK → rc≠0 + 'ise-alim'
#     marker; 'code' kısayolu (cname=cloudtop-code) da aynı kapıya düşer; hiçbir ssh/git çağrısı gerekmez
for p in cloudtop-code code; do
  out="$(ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
    bash "$SCRIPT_DIR/iskan.sh" uye-ekle "$p" denekGamma --apply 2>&1)"
  rc=$?
  [ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'ise-alim' \
    && ok "uye-ekle: Nexus-hedef '$p' rc≠0 + 'ise-alim' yönlendirme-marker'ı (İ1, canlı-invoke YOK)" \
    || bad "uye-ekle: Nexus-hedef '$p' beklenen rc≠0+ise-alim, gelen rc=$rc"
done

# 34. uye-ekle NEGATİF-KAPI (K4): bilinmeyen ad → rc≠0 + 'kayitsiz-proje'; önek/case-farkı reddedilir
out="$(ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" uye-ekle hayaletproje denekGamma --apply 2>&1)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'kayitsiz-proje' \
  && ok "uye-ekle --apply: bilinmeyen-proje rc≠0 + 'kayitsiz-proje' marker" \
  || bad "uye-ekle --apply: bilinmeyen-proje beklenen rc≠0+marker, gelen rc=$rc"
for p in uetes UETEST; do
  ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
    bash "$SCRIPT_DIR/iskan.sh" uye-ekle "$p" denekGamma --apply >/dev/null 2>&1
  rc=$?
  [ "$rc" != "0" ] && ok "uye-ekle --apply: '$p' (önek/case-farkı) reddedildi rc=$rc (K4 fuzzy-yasak)" \
    || bad "uye-ekle --apply: '$p' KABUL edildi (K4 ihlali)"
done

# 35. uye-ekle --apply MEVCUT-üye: rc≠0 + 'uye-zaten-var' (çakışma-koruması; ssh-bozukken bile
#     origin/main iskan-registry fallback'inden yakalanır → mutasyonsuz erken-kırmızı)
out="$(ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" uye-ekle uetest denekAlfa --apply 2>&1)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'uye-zaten-var' \
  && ok "uye-ekle --apply: mevcut-üye rc≠0 + 'uye-zaten-var' (çakışma-koruması, G4b)" \
  || bad "uye-ekle --apply: mevcut-üye beklenen rc≠0+uye-zaten-var, gelen rc=$rc"

# 36. uye-ekle --apply yeni-üye ama host-erişilemez → rc=1, mutasyonsuz erken-kırmızı
SUM_UE_BEFORE2="$(md5sum "$UE_REPO/infra/iskan-registry.yaml")"
ISKAN_CLOUDTOP_REPO_DIR="$UE_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" uye-ekle uetest denekGamma --apply >/dev/null 2>&1
rc=$?
SUM_UE_AFTER2="$(md5sum "$UE_REPO/infra/iskan-registry.yaml")"
[ "$rc" = "1" ] && [ "$SUM_UE_BEFORE2" = "$SUM_UE_AFTER2" ] \
  && ok "uye-ekle --apply: host-erişilemezken rc=1 + repo-dosya değişmedi (mutasyonsuz erken-kırmızı)" \
  || bad "uye-ekle --apply: host-erişilemez sözleşmesi kırık (rc=$rc)"

find "$UE_REPO" -type f -delete 2>/dev/null; find "$UE_REPO" -depth -type d -delete 2>/dev/null

# 37. _ey_ekip_roster_oku (FAZ-7 roster-köprüsü parser'ı): meta.yonetici + uyeler id-listesi →
#     "rol:gorev" çiftleri (G5'in kök-fix'i: hardcoded 2-üye default yerine registry-roster)
EKIP_REG_FIXTURE="$(cat <<'EOF'
meta:
  ekip: "uetest-ekibi"
  uye_sayisi: 3
  yonetici: denekAlfa

uyeler:
  - id: denekAlfa
    tmux: "denekAlfa:0"
  - id: denekBeta
    tmux: "denekBeta:0"
  - id: denekGamma
    tmux: "denekGamma:0"
EOF
)"
res="$(bash -c "source <(sed -n '/^_ey_ekip_roster_oku()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _ey_ekip_roster_oku \"\$1\"" _ "$EKIP_REG_FIXTURE")"
[ "$res" = "denekAlfa:yonetici denekBeta:uye denekGamma:uye" ] \
  && ok "_ey_ekip_roster_oku: 3-üye roster doğru çözüldü (yonetici-etiketi dahil)" \
  || bad "_ey_ekip_roster_oku: beklenen 3-üye roster, gelen '$res'"

# 38. _ue_kahya_adaptor: KÂHYA-şema fixture → iskan-registry K2 üye-bloğu (id/tmux/cwd/session_id/
#     permission_mode anahtarları; canlı KÂHYA-invoke YOK — İSKÂN'ın Nexus-katkısı yalnız bu dönüşüm)
UE_ADP_SID="99999999-8888-7777-6666-555555555555"
res="$(bash -c "source <(sed -n '/^_ue_kahya_adaptor()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _ue_kahya_adaptor '$SCRIPT_DIR/fixtures/kahya-ornek.json' '$UE_ADP_SID'")"
printf '%s' "$res" | grep -q "id: DENEKKAHYA" \
  && printf '%s' "$res" | grep -q 'tmux: "DENEKKAHYA:0"' \
  && printf '%s' "$res" | grep -q "cwd: /opt/nexus/repo" \
  && printf '%s' "$res" | grep -q "session_id: $UE_ADP_SID" \
  && printf '%s' "$res" | grep -q "permission_mode: default" \
  && ok "_ue_kahya_adaptor: KÂHYA-şema → K2 üye-bloğu dönüşümü tam (5 anahtar)" \
  || bad "_ue_kahya_adaptor: dönüşüm eksik/bozuk: '$res'"

# ── FAZ-8: evergreen-kaydet (fixture-repo; canlı cloudtop-repo'ya DOKUNMAZ) ──────────────

# fixture cloudtop-repo üreteci: origin/main ref'i update-ref ile kurulur (remote gerekmez;
# _ey_proje_cozumu 'git show origin/main:' okur, fetch-fail sessiz-geçilir)
_eg_fixture_repo() { # <dizin> <backup-govde-ek (bash-n kapısı için bozuk-sözdizim enjekte edilebilir)>
  local d="$1" ek="${2:-}"
  mkdir -p "$d/infra"
  cat > "$d/infra/docker-compose.server.yml" <<'EOF'
services:
  cloudtop-egtest:
    image: test
    container_name: cloudtop-egtest
    ports:
      - "127.0.0.1:9999:8443"
EOF
  cat > "$d/infra/provider-inventory.yaml" <<'EOF'
cloudflare:
  tunnel:
    ingress:
      - pc.mmepanel.com       # test-mevcut
  access_apps:
    - pc.mmepanel.com
  api: test-anahtar-sonrasi-blok-siniri
EOF
  cat > "$d/infra/backup.sh" <<EOF
#!/usr/bin/env bash
${ek}
if command -v docker >/dev/null 2>&1; then
  docker inspect cloudtop > "/tmp/eg-test-inspect.json" 2>/dev/null \\
    || echo "  uyarı: docker inspect atlandı"
fi
EOF
  git -C "$d" init -q && git -C "$d" add -A \
    && git -C "$d" -c user.email=t@t -c user.name=t commit -qm fixture \
    && git -C "$d" update-ref refs/remotes/origin/main HEAD
}

EG_REPO="$(mktemp -d)"
_eg_fixture_repo "$EG_REPO" ""

# 39. evergreen-kaydet --dry-run: rc=3 + 'evergreen-onizleme' başlığı + HİÇBİR dosya yazılmaz
SUM_EG_0="$(md5sum "$EG_REPO"/infra/*.yaml "$EG_REPO"/infra/*.sh)"
out="$(ISKAN_CLOUDTOP_REPO_DIR="$EG_REPO" bash "$SCRIPT_DIR/iskan.sh" evergreen-kaydet egtest --dry-run 2>&1)"
rc=$?
SUM_EG_1="$(md5sum "$EG_REPO"/infra/*.yaml "$EG_REPO"/infra/*.sh)"
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'evergreen-onizleme' && [ "$SUM_EG_0" = "$SUM_EG_1" ] \
  && ok "evergreen-kaydet --dry-run: rc=3 + evergreen-onizleme + yazımsız (md5 önce=sonra)" \
  || bad "evergreen-kaydet --dry-run: sözleşme kırık (rc=$rc)"
printf '%s' "$out" | grep -q 'EKLENECEK' \
  && ok "evergreen-kaydet --dry-run: EKLENECEK satır-diff'i görünür" \
  || bad "evergreen-kaydet --dry-run: EKLENECEK diff'i yok"

# 40. evergreen-kaydet --apply (1. koşu): rc=0 + üç kayıt yazıldı + .bak üretildi + bash -n temiz
ISKAN_CLOUDTOP_REPO_DIR="$EG_REPO" bash "$SCRIPT_DIR/iskan.sh" evergreen-kaydet egtest --apply >/dev/null 2>&1
rc=$?
ing_ok="$(awk '/ingress:/{f=1} /access_apps:/{f=0} f' "$EG_REPO/infra/provider-inventory.yaml" | grep -c 'egtest.mmepanel.com')"
acc_ok="$(awk '/access_apps:/{f=1} f' "$EG_REPO/infra/provider-inventory.yaml" | grep -c 'egtest.mmepanel.com')"
[ "$rc" = "0" ] && [ "$ing_ok" -ge 1 ] && [ "$acc_ok" -ge 1 ] \
  && grep -q 'cloudtop-egtest' "$EG_REPO/infra/backup.sh" && bash -n "$EG_REPO/infra/backup.sh" \
  && ok "evergreen-kaydet --apply: rc=0 + ingress/access_apps/backup-inspect üç-kayıt yazıldı (bash -n temiz)" \
  || bad "evergreen-kaydet --apply: yazım eksik (rc=$rc ing=$ing_ok acc=$acc_ok)"
[ -f "$EG_REPO/infra/provider-inventory.yaml.bak" ] && [ -f "$EG_REPO/infra/backup.sh.bak" ] \
  && ok "evergreen-kaydet --apply: her yazılan dosyaya .bak üretildi" \
  || bad "evergreen-kaydet --apply: .bak eksik"

# 41. evergreen-kaydet --apply (2.+ koşu): İDEMPOTENT no-op rc=0 + 'mevcut' dili + md5 değişmez
SUM_EG_2="$(md5sum "$EG_REPO"/infra/*.yaml "$EG_REPO"/infra/*.sh)"
out="$(ISKAN_CLOUDTOP_REPO_DIR="$EG_REPO" bash "$SCRIPT_DIR/iskan.sh" evergreen-kaydet egtest --apply 2>&1)"
rc=$?
SUM_EG_3="$(md5sum "$EG_REPO"/infra/*.yaml "$EG_REPO"/infra/*.sh)"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'mevcut' && [ "$SUM_EG_2" = "$SUM_EG_3" ] \
  && ok "evergreen-kaydet --apply 2.koşu: idempotent no-op (rc=0 + 'mevcut' + md5 değişmez)" \
  || bad "evergreen-kaydet --apply 2.koşu: idempotency kırık (rc=$rc)"

# 42. NEGATİF-KAPI (K4): kayıtsız proje → rc≠0 + 'kayitsiz-proje' + manifest md5 değişmez
out="$(ISKAN_CLOUDTOP_REPO_DIR="$EG_REPO" bash "$SCRIPT_DIR/iskan.sh" evergreen-kaydet hayaletproje --apply 2>&1)"
rc=$?
SUM_EG_4="$(md5sum "$EG_REPO"/infra/*.yaml "$EG_REPO"/infra/*.sh)"
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'kayitsiz-proje' && [ "$SUM_EG_3" = "$SUM_EG_4" ] \
  && ok "evergreen-kaydet: kayıtsız-proje rc≠0 + 'kayitsiz-proje' + yazımsız" \
  || bad "evergreen-kaydet: kayıtsız-proje kapısı kırık (rc=$rc)"

find "$EG_REPO" -type f -delete 2>/dev/null; find "$EG_REPO" -depth -type d -delete 2>/dev/null

# 43. bash -n KAPISI: backup.sh sözdizim-bozuk fixture'da apply → rc≠0 + .bak-restore (byte-eş geri)
EG_REPO2="$(mktemp -d)"
_eg_fixture_repo "$EG_REPO2" "if true; then   # bilinçli-bozuk: fi eksik (bash -n düşer)"
SUM_BK_0="$(md5sum "$EG_REPO2/infra/backup.sh")"
out="$(ISKAN_CLOUDTOP_REPO_DIR="$EG_REPO2" bash "$SCRIPT_DIR/iskan.sh" evergreen-kaydet egtest --apply 2>&1)"
rc=$?
SUM_BK_1="$(md5sum "$EG_REPO2/infra/backup.sh")"
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'bash -n' && [ "$SUM_BK_0" = "$SUM_BK_1" ] \
  && ok "evergreen-kaydet: bash -n kapısı düştü → rc=1 + backup.sh .bak-restore (byte-eş geri)" \
  || bad "evergreen-kaydet: bash -n kapısı sözleşmesi kırık (rc=$rc)"
find "$EG_REPO2" -type f -delete 2>/dev/null; find "$EG_REPO2" -depth -type d -delete 2>/dev/null

# ── FAZ-9: port-override + provizyon-gate + roster-override ──────────────────────────────

# 44. yeni-proje --port: override dry-run önizlemesi override-portu içerir + kaynak-beyanı + rc=3 + dosya değişmez
PO_FIXTURE="/tmp/iskan-test-po.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$PO_FIXTURE"
SUM_PO_0="$(md5sum "$PO_FIXTURE")"
out="$(ISKAN_REPO_COMPOSE="$PO_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje portproje --port 8448 --dry-run 2>&1)"
rc=$?
SUM_PO_1="$(md5sum "$PO_FIXTURE")"
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '127.0.0.1:8448:8443' && printf '%s' "$out" | grep -q 'port-kaynağı: operatör-override' \
  && [ "$SUM_PO_0" = "$SUM_PO_1" ] \
  && ok "yeni-proje --port: override-port compose-önizlemede + kaynak-beyanı + rc=3 + yazımsız" \
  || bad "yeni-proje --port: override sözleşmesi kırık (rc=$rc)"

# 45. ISKAN_PORT env: --port ile aynı yol; ayrıca sayısal-olmayan değer rc=2
out="$(ISKAN_PORT=8448 ISKAN_REPO_COMPOSE="$PO_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje portproje --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '127.0.0.1:8448:8443' \
  && ok "yeni-proje ISKAN_PORT: env-override arg'la eş-davranış (rc=3 + 8448)" \
  || bad "yeni-proje ISKAN_PORT: env-override kırık (rc=$rc)"
ISKAN_REPO_COMPOSE="$PO_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje portproje --port abc --dry-run >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] && ok "yeni-proje --port: sayısal-olmayan değer rc=2" || bad "yeni-proje --port: sayısal-olmayan kabul edildi (rc=$rc)"

# 46. port-override ÇAKIŞMA-kapısı: compose'da zaten bağlı porta override → rc=1 + RED + yazımsız
cat >> "$PO_FIXTURE" <<'EOF'

  cloudtop-mevcutport:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-mevcutport
    ports:
      - "127.0.0.1:8448:8443"
EOF
SUM_PO_2="$(md5sum "$PO_FIXTURE")"
out="$(ISKAN_REPO_COMPOSE="$PO_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje portproje --port 8448 --dry-run 2>&1)"
rc=$?
SUM_PO_3="$(md5sum "$PO_FIXTURE")"
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'zaten repo-compose.da kullanımda' && [ "$SUM_PO_2" = "$SUM_PO_3" ] \
  && ok "yeni-proje --port: kullanımda-olan porta override rc=1 (çakışma-kapısı) + yazımsız" \
  || bad "yeni-proje --port: çakışma-kapısı kırık (rc=$rc)"
# GOLDEN: override YOKKEN pick_port davranışı aynen (8448 dolu → floor 8449 seçilir, kaynak-beyanı YOK)
out="$(ISKAN_REPO_COMPOSE="$PO_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje portproje --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '127.0.0.1:8449:8443' && ! printf '%s' "$out" | grep -q 'port-kaynağı: operatör-override' \
  && ok "yeni-proje (override'sız): pick_port golden-davranış korunuyor (8449, beyan-yok)" \
  || bad "yeni-proje (override'sız): golden-davranış BOZULDU (rc=$rc)"
find /tmp -maxdepth 1 -name "iskan-test-po.$$.yml" -delete 2>/dev/null

# 47. provizyon NEGATİF-KAPI (G7-sözleşmesi): marker-yokken --apply → rc=4 + stderr'de 'ISKAN_FAZ9_GO'
err="$(env -u ISKAN_FAZ9_GO bash "$SCRIPT_DIR/iskan.sh" provizyon gatetest --apply 2>&1 >/dev/null)"
rc=$?
[ "$rc" = "4" ] && printf '%s' "$err" | grep -q 'ISKAN_FAZ9_GO' \
  && ok "provizyon --apply: GO-marker yokken rc=4 + stderr'de marker-adı (FAZ-4 konvansiyonu)" \
  || bad "provizyon --apply: negatif-kapı sözleşmesi kırık (rc=$rc)"

# 48. provizyon dry-run: host/repo erişilemezken bile plan-exit=3 + doğrulanmadı-dili + plan-satırı
out="$(ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_CLOUDTOP_REPO_DIR="/tmp/iskan-yok.$$" \
  bash "$SCRIPT_DIR/iskan.sh" provizyon gatetest 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'doğrulanmadı' && printf '%s' "$out" | grep -q 'setsid -w bash' \
  && ok "provizyon dry-run: offline'da rc=3 + doğrulanmadı-dili + plan-satırı" \
  || bad "provizyon dry-run: plan-sözleşmesi kırık (rc=$rc)"
bash "$SCRIPT_DIR/iskan.sh" provizyon >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] && ok "provizyon: projesiz çağrı rc=2 (usage)" || bad "provizyon: projesiz rc beklenen 2, gelen $rc"

# 49. ekip-yerlestir ISKAN_EY_ROSTER override: 5-üye küçük-ASCII roster parse + dry-run planında 5 satır
EYR_REPO="/tmp/iskan-test-eyr-repo.$$"
mkdir -p "$EYR_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$EYR_REPO/infra/docker-compose.server.yml"
cat >> "$EYR_REPO/infra/docker-compose.server.yml" <<'EOF'

  cloudtop-rostertest:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-rostertest
    ports:
      - "127.0.0.1:9448:8443"
EOF
git -C "$EYR_REPO" init -q -b main 2>/dev/null
git -C "$EYR_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$EYR_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$EYR_REPO" remote add origin "$EYR_REPO" 2>/dev/null
git -C "$EYR_REPO" fetch -q origin main 2>/dev/null
out="$(ISKAN_EY_ROSTER="nisanci:yonetici seyyah:uye mumeyyiz:uye vakanuvis:uye nakkas:uye" \
  ISKAN_CLOUDTOP_REPO_DIR="$EYR_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir rostertest --dry-run 2>&1)"
rc=$?
n_uye="$(printf '%s\n' "$out" | grep -cE '^\s+- (nisanci|seyyah|mumeyyiz|vakanuvis|nakkas) \(')"
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'ISKAN_EY_ROSTER (açık-override)' && [ "$n_uye" = "5" ] \
  && ok "ekip-yerlestir ISKAN_EY_ROSTER: 5-üye küçük-ASCII override parse + planında 5 satır + rc=3" \
  || bad "ekip-yerlestir ISKAN_EY_ROSTER: override sözleşmesi kırık (rc=$rc, üye=$n_uye)"
find "$EYR_REPO" -type f -delete 2>/dev/null; find "$EYR_REPO" -depth -type d -delete 2>/dev/null

# 50. MOUNT-FARKINDA hedef-yol çözümü (k0084-H4 gölgelenme-bug'ı regresyon-testi, host'suz):
#     (a) paylaşımlı-mount servis (./config/projects/X:/config/projects/X) → host-yol = mount'un kendisi
#     (b) tek-mount servis (./config-Y:/config) → host-yol = config-Y/projects/Y (eski davranış korunur)
MM_REPO="/tmp/iskan-test-mm-repo.$$"
mkdir -p "$MM_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$MM_REPO/infra/docker-compose.server.yml"
cat >> "$MM_REPO/infra/docker-compose.server.yml" <<'EOF'

  cloudtop-paylasimli:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-paylasimli
    volumes:
      - ./config-paylasimli:/config
      - ./config/.claude:/config/.claude
      - ./config/projects/paylasimli:/config/projects/paylasimli
    ports:
      - "127.0.0.1:9448:8443"

  cloudtop-tekmount:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-tekmount
    volumes:
      - ./config-tekmount:/config
    ports:
      - "127.0.0.1:9449:8443"
EOF
git -C "$MM_REPO" init -q -b main 2>/dev/null
git -C "$MM_REPO" -c user.email=t@t -c user.name=t add -A 2>/dev/null
git -C "$MM_REPO" -c user.email=t@t -c user.name=t commit -qm x 2>/dev/null
git -C "$MM_REPO" remote add origin "$MM_REPO" 2>/dev/null
git -C "$MM_REPO" fetch -q origin main 2>/dev/null
out="$(ISKAN_EY_ROSTER="denekAlfa:yonetici" ISKAN_CLOUDTOP_REPO_DIR="$MM_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir paylasimli --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '→ /opt/cloudtop/config/projects/paylasimli (host)' \
  && ok "mount-çözümü: paylaşımlı-mount → mount'un kendisi (gölgelenme-panzehiri)" \
  || bad "mount-çözümü: paylaşımlı-mount yanlış çözüldü (rc=$rc)"
out="$(ISKAN_EY_ROSTER="denekAlfa:yonetici" ISKAN_CLOUDTOP_REPO_DIR="$MM_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir tekmount --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '→ /opt/cloudtop/config-tekmount/projects/tekmount (host)' \
  && ok "mount-çözümü: tek-mount eski-davranış korunuyor (config-<ad>/projects/<ad>)" \
  || bad "mount-çözümü: tek-mount davranışı BOZULDU (rc=$rc)"
find "$MM_REPO" -type f -delete 2>/dev/null; find "$MM_REPO" -depth -type d -delete 2>/dev/null

# ── SÖKÜM (k0083): sokum alt-komutu — dry-run-default · GO-kapısı · durum-sinyalleri ──────

# fixture cloudtop-repo (5-manifest'li; origin/main update-ref ile — remote gerekmez)
_sk_fixture_repo() { # <dizin>
  local d="$1"
  mkdir -p "$d/infra"
  cat > "$d/infra/docker-compose.server.yml" <<'EOF'
services:
  cloudtop-komsu:
    image: test
    container_name: cloudtop-komsu
    ports:
      - "127.0.0.1:9997:8443"

  # ── İSKÂN FAZ-4 provizyon: sokumtest (iskan.sh yeni-proje ile üretildi) ────────────────
  cloudtop-sokumtest:
    image: test
    container_name: cloudtop-sokumtest
    volumes:
      - ./config-sokumtest:/config
    ports:
      - "127.0.0.1:9998:8443"
EOF
  cat > "$d/infra/setup-tunnel.sh" <<'EOF'
#!/usr/bin/env bash
SOKUMTEST_HOSTNAME="sokumtest.mmepanel.com"
cat > /tmp/x <<ING
  - hostname: ${SOKUMTEST_HOSTNAME}
    service: http://localhost:9998
ING
EOF
  cat > "$d/infra/provider-inventory.yaml" <<'EOF'
cloudflare:
  tunnel:
    ingress:
      - pc.mmepanel.com
      - sokumtest.mmepanel.com   # İSKÂN-container
  access_apps:
    - pc.mmepanel.com
    - sokumtest.mmepanel.com     # İSKÂN-container
EOF
  cat > "$d/infra/backup.sh" <<'EOF'
#!/usr/bin/env bash
docker inspect cloudtop cloudtop-sokumtest > "/tmp/sk-inspect.json" 2>/dev/null || true
EOF
  cat > "$d/infra/iskan-registry.yaml" <<'EOF'
# iskan-registry.yaml — İSKÂN K2 künye TEK-KAYNAĞI (test-fixture).
proje: sokumtest
container_adi: cloudtop-sokumtest
EOF
  git -C "$d" init -q && git -C "$d" add -A \
    && git -C "$d" -c user.email=t@t -c user.name=t commit -qm fixture \
    && git -C "$d" update-ref refs/remotes/origin/main HEAD
}

# ssh-stub: her çağrıyı SSH_STUB_LOG'a yazar; arşiv-probe'a sahte-arşiv-yolu döner
SK_STUB_DIR="$(mktemp -d)"
cat > "$SK_STUB_DIR/ssh" <<'EOF'
#!/usr/bin/env bash
echo "call: $*" >> "${SSH_STUB_LOG:?}"
case "$*" in
  *_sokum-arsiv*) echo "/opt/cloudtop/_sokum-arsiv/ghost-2026-01-01" ;;
esac
exit 0
EOF
chmod +x "$SK_STUB_DIR/ssh"

SK_REPO="$(mktemp -d)"
_sk_fixture_repo "$SK_REPO"

# 48. sokum dry-run (DEFAULT — mode-arg'sız): rc=3 + plan + hiçbir dosya değişmez
SUM_SK_0="$(md5sum "$SK_REPO"/infra/*)"
out="$(ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" sokum sokumtest 2>&1)"
rc=$?
SUM_SK_1="$(md5sum "$SK_REPO"/infra/*)"
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'KURU-KOŞU' && printf '%s' "$out" | grep -q 'down cloudtop-sokumtest' \
  && [ "$SUM_SK_0" = "$SUM_SK_1" ] \
  && ok "sokum dry-run (DEFAULT): rc=3 + servis-scoped down-planı + md5-değişmez" \
  || bad "sokum dry-run: sözleşme kırık (rc=$rc)"

# 49. sokum --apply GO-marker'sız: rc=4 + stderr'de ISKAN_SOKUM_GO + SIFIR-dokunuş (md5 + ssh-stub-çağrı=0)
SK_LOG="$(mktemp)"
err="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum sokumtest --apply 2>&1 >/dev/null)"
rc=$?
SUM_SK_2="$(md5sum "$SK_REPO"/infra/*)"
[ "$rc" = "4" ] && printf '%s' "$err" | grep -q 'ISKAN_SOKUM_GO' && [ "$SUM_SK_1" = "$SUM_SK_2" ] \
  && [ "$(grep -c . "$SK_LOG")" = "0" ] \
  && ok "sokum marker-yok: rc=4 + stderr ISKAN_SOKUM_GO + md5-değişmez + ssh-stub-çağrı=0 (sıfır-dokunuş)" \
  || bad "sokum marker-yok: GO-kapısı kırık (rc=$rc ssh-çağrı=$(grep -c . "$SK_LOG"))"

# 50. sokum kayıtsız-proje: compose-kaydı YOK + arşiv-izi YOK → rc≠0 + 'kayitsiz' + md5-değişmez
out="$(ISKAN_SOKUM_GO=1 ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" sokum hayalet --apply 2>&1)"
rc=$?
SUM_SK_3="$(md5sum "$SK_REPO"/infra/*)"
[ "$rc" != "0" ] && printf '%s' "$out" | grep -qi 'kayitsiz' && [ "$SUM_SK_2" = "$SUM_SK_3" ] \
  && ok "sokum kayitsiz-proje: rc≠0 + 'kayitsiz' marker + md5-değişmez (fail-closed)" \
  || bad "sokum kayitsiz-proje: kapı kırık (rc=$rc)"

# 51. sokum zaten-sokuk: compose-kaydı YOK ∧ host'ta arşiv-izi VAR (ssh-stub) → rc=0 + 'zaten-sokuk'
SK_LOG2="$(mktemp)"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG2" ISKAN_SOKUM_GO=1 ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost --apply 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'zaten-sokuk' \
  && ok "sokum zaten-sokuk: kayıt-yok + arşiv-var → rc=0 idempotent ('zaten-sokuk' sinyali)" \
  || bad "sokum zaten-sokuk: durum-sinyali kırık (rc=$rc)"

# 51b. sokum P1d (kur-durum-dosyası temizliği): dry-run planı ADIM-8'i içerir + dry-run dosyaya DOKUNMAZ;
#      zaten-sokuk --apply bayat kur-izini temizler (F4 'state-dosyası-silinmiş' söküm-oracle'ının mekanizması)
SK_STATE_DIR="$(mktemp -d)"
out="$(ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" \
  bash "$SCRIPT_DIR/iskan.sh" sokum sokumtest 2>&1)"
printf '%s' "$out" | grep -q 'kur-durum-dosyası temizliği' \
  && ok "sokum dry-run: plan ADIM-8 kur-durum-temizliğini içeriyor (P1d)" \
  || bad "sokum dry-run: ADIM-8 planda yok (P1d eksik)"
printf 'ekip-yerlestir\n' > "$SK_STATE_DIR/iskan-kur-ghost.state"
SK_LOG3="$(mktemp)"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG3" ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost 2>&1)"
rc=$?
[ "$rc" = "0" ] && [ -f "$SK_STATE_DIR/iskan-kur-ghost.state" ] && printf '%s' "$out" | grep -q 'bayat kur-durum-dosyası duruyor' \
  && ok "sokum zaten-sokuk dry-run: bayat kur-izi UYARILIR ama SİLİNMEZ (dry-run yazmaz)" \
  || bad "sokum zaten-sokuk dry-run: state-dokunma sözleşmesi kırık (rc=$rc, dosya $([ -f "$SK_STATE_DIR/iskan-kur-ghost.state" ] && echo var || echo YOK))"
printf 'ekip-yerlestir\n' > "$SK_STATE_DIR/iskan-kur-ghost.state"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG3" ISKAN_SOKUM_GO=1 ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost --apply 2>&1)"
rc=$?
[ "$rc" = "0" ] && [ ! -f "$SK_STATE_DIR/iskan-kur-ghost.state" ] && printf '%s' "$out" | grep -q 'bayat kur-durum-dosyası temizlendi' \
  && ok "sokum zaten-sokuk --apply: bayat kur-izi TEMİZLENDİ (P1d tamamlayıcı)" \
  || bad "sokum zaten-sokuk --apply: kur-izi temizliği kırık (rc=$rc)"
# MINOR fix: state silindiğinde 'hiçbir şeye dokunulmadı' DEMEZ (çelişki) — 'yalnız lokal kur-izi temizlendi' der
printf 'ekip-yerlestir\n' > "$SK_STATE_DIR/iskan-kur-ghost.state"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG3" ISKAN_SOKUM_GO=1 ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost --apply 2>&1)"
printf '%s' "$out" | grep -q 'yalnız bayat lokal kur-izi temizlendi' && ! printf '%s' "$out" | grep -q 'temizlendi.*idempotent.*hiçbir şeye dokunulmadı' \
  && ok "sokum zaten-sokuk --apply: state-silinince 'dokunulmadı' iddiası ayrıştırıldı (MINOR fix, çelişki yok)" \
  || bad "sokum zaten-sokuk --apply: 'dokunulmadı' çelişkisi sürüyor"
# MAJOR fix: rm-başarısızlığı SESSİZ yutulmasın — state-dizini salt-oku iken kırmızı + rc≠0 (ADIM-8 simetrisi)
printf 'ekip-yerlestir\n' > "$SK_STATE_DIR/iskan-kur-ghost.state"
chmod 555 "$SK_STATE_DIR"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG3" ISKAN_SOKUM_GO=1 ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost --apply 2>&1)"
rc=$?
chmod 755 "$SK_STATE_DIR"
[ "$rc" != "0" ] && printf '%s' "$out" | grep -q 'bayat kur-durum-dosyası silinemedi' \
  && ok "sokum zaten-sokuk --apply: rm-başarısızlığı SESSİZ yutulmuyor → kırmızı + rc≠0 (MAJOR fix, ADIM-8 simetrisi)" \
  || bad "sokum zaten-sokuk --apply: rm-hatası sessiz yutuldu (rc=$rc — MAJOR regresyon)"
rm -f "$SK_LOG3"
find "$SK_STATE_DIR" -type f -delete 2>/dev/null; find "$SK_STATE_DIR" -depth -type d -delete 2>/dev/null

rm -f "$SK_LOG" "$SK_LOG2"
find "$SK_REPO" "$SK_STUB_DIR" -type f -delete 2>/dev/null
find "$SK_REPO" "$SK_STUB_DIR" -depth -type d -delete 2>/dev/null

# ── D6: kur (UC1 zincirleyici — duraklı durum-makinesi) + tuzak-fix'ler ───────────────────

# ortak hermetik fixture: cloudtop-repo (compose'da cloudtop-kurtest kayıtlı + evergreen-manifestler)
KR_REPO="$(mktemp -d)"
KR_STATE="$(mktemp -d)"
mkdir -p "$KR_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$KR_REPO/infra/docker-compose.server.yml"
cat >> "$KR_REPO/infra/docker-compose.server.yml" <<'EOF'

  cloudtop-kurtest:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-kurtest
    volumes:
      - ./config-kurtest:/config
    ports:
      - "127.0.0.1:9447:8443"
EOF
cat > "$KR_REPO/infra/provider-inventory.yaml" <<'EOF'
cloudflare:
  tunnel:
    ingress:
      - pc.mmepanel.com       # test-mevcut
  access_apps:
    - pc.mmepanel.com
  api: test-anahtar-sonrasi-blok-siniri
EOF
cat > "$KR_REPO/infra/backup.sh" <<'EOF'
#!/usr/bin/env bash
docker inspect cloudtop > "/tmp/kur-test-inspect.json" 2>/dev/null || true
EOF
git -C "$KR_REPO" init -q && git -C "$KR_REPO" add -A \
  && git -C "$KR_REPO" -c user.email=t@t -c user.name=t commit -qm fixture \
  && git -C "$KR_REPO" update-ref refs/remotes/origin/main HEAD
KR_ENV=(ISKAN_STATE_DIR="$KR_STATE" ISKAN_CLOUDTOP_REPO_DIR="$KR_REPO" \
  ISKAN_REPO_COMPOSE="$KR_REPO/infra/docker-compose.server.yml" \
  ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  ISKAN_EY_ROSTER="denekAlfa:yonetici")

# 52. kur usage: projesiz rc=2; bilinmeyen bayrak rc=2
bash "$SCRIPT_DIR/iskan.sh" kur >/dev/null 2>&1; rc1=$?
bash "$SCRIPT_DIR/iskan.sh" kur kurtest --bilinmeyen >/dev/null 2>&1; rc2=$?
[ "$rc1" = "2" ] && [ "$rc2" = "2" ] && ok "kur: projesiz/bilinmeyen-bayrak rc=2 (usage)" || bad "kur: usage rc beklenen 2/2, gelen $rc1/$rc2"

# 53. kur 3-Çit: mahrem-tenant adları REDDEDİLİR (rc=1 + '3-Çit' marker; hiçbir adım koşulmaz,
#     durum-dosyası doğmaz) — izole aile İSKÂN-doğumu değildir
for p in mihenk huma; do
  out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur "$p" --dry-run 2>&1)"
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$out" | grep -q '3-Çit' && [ ! -e "$KR_STATE/iskan-kur-$p.state" ] \
    && ok "kur 3-Çit: '$p' reddedildi (rc=1 + marker + durum-dosyası yok)" \
    || bad "kur 3-Çit: '$p' reddi kırık (rc=$rc)"
done

# 54. kur --dry-run: 7-adım zincir-planı uçtan-uca basılır + plan-exit=3 + HİÇBİR yazma
#     (fixture md5 değişmez, durum-dosyası DOĞMAZ)
SUM_KR_0="$(md5sum "$KR_REPO"/infra/*)"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --dry-run 2>&1)"
rc=$?
SUM_KR_1="$(md5sum "$KR_REPO"/infra/*)"
[ "$rc" = "3" ] && ok "kur --dry-run: plan-exit=3" || bad "kur --dry-run: rc beklenen 3, gelen $rc"
adim_eksik=""
for a in "1/7: yeni-proje" "2/7: durak1-cloudtop-pr" "3/7: iskan-host" "4/7: provizyon" "5/7: cf-yayin" "6/7: ekip-yerlestir" "7/7: evergreen-kaydet"; do
  printf '%s' "$out" | grep -q "kur adım $a" || adim_eksik="$adim_eksik [$a]"
done
[ -z "$adim_eksik" ] && ok "kur --dry-run: 7 adımın hepsi zincir-planında (FAZ-sırasıyla)" \
  || bad "kur --dry-run: zincir-planında eksik adım:$adim_eksik"
[ "$SUM_KR_0" = "$SUM_KR_1" ] && [ ! -e "$KR_STATE/iskan-kur-kurtest.state" ] \
  && ok "kur --dry-run: hiçbir yazma yok (fixture md5 değişmez + durum-dosyası doğmadı)" \
  || bad "kur --dry-run: yazma tespit edildi (dry-run sözleşme ihlali)"
printf '%s' "$out" | grep -q 'DURAK-1' && ok "kur --dry-run: DURAK-1 (cloudtop-PR merge durağı) planda görünür" \
  || bad "kur --dry-run: DURAK-1 planda yok"

# 55. kur GO'suz apply: adım-1 yeni-proje --apply exit=4 AYNEN iletilir + zincir DURur
#     (adım 2'ye geçilmez, dosya md5 değişmez, durum-dosyası doğmaz)
SUM_KR_2="$(md5sum "$KR_REPO/infra/docker-compose.server.yml")"
out="$(env -u ISKAN_FAZ4_GO "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurgo 2>&1)"
rc=$?
SUM_KR_3="$(md5sum "$KR_REPO/infra/docker-compose.server.yml")"
[ "$rc" = "4" ] && printf '%s' "$out" | grep -q 'ISKAN_FAZ4_GO' && printf '%s' "$out" | grep -q 'GO-durağında DURDU' \
  && ok "kur GO'suz: adım-1 exit=4 iletildi + GO-durağı Sultan-dilinde raporlandı" \
  || bad "kur GO'suz: exit-4 iletimi kırık (rc=$rc)"
[ "$SUM_KR_2" = "$SUM_KR_3" ] && [ ! -e "$KR_STATE/iskan-kur-kurgo.state" ] && ! printf '%s' "$out" | grep -q 'kur adım 2/7' \
  && ok "kur GO'suz: zincir DURdu (adım-2 koşulmadı + md5 değişmez + durum-dosyası doğmadı)" \
  || bad "kur GO'suz: DUR sözleşmesi kırık"

# 56. kur DURAK-1 durum-makinesi: GO'lu adım-1 sonrası origin/main'de blok YOK → DURAK exit=0
#     + durum-dosyası 'yeni-proje' (adım-scope'lu env; kalıcı export YOK)
out="$(env "${KR_ENV[@]}" ISKAN_FAZ4_GO=1 bash "$SCRIPT_DIR/iskan.sh" kur kurdurak 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "kur DURAK-1: merge-öncesi zincir İNSAN-durağında durdu (exit=0 adım-tamam)" \
  || bad "kur DURAK-1: durak sözleşmesi kırık (rc=$rc)"
[ "$(cat "$KR_STATE/iskan-kur-kurdurak.state" 2>/dev/null)" = "yeni-proje" ] \
  && ok "kur durum-dosyası: son-tamamlanan='yeni-proje' yazıldı (git-DIŞI state)" \
  || bad "kur durum-dosyası: beklenen 'yeni-proje', gelen '$(cat "$KR_STATE/iskan-kur-kurdurak.state" 2>/dev/null)'"

# 57. kur --durum: salt-oku (rc=0 + son-tamamlanan + sıradaki; durum-dosyası md5 değişmez)
SUM_ST_0="$(md5sum "$KR_STATE/iskan-kur-kurdurak.state")"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurdurak --durum 2>&1)"
rc=$?
SUM_ST_1="$(md5sum "$KR_STATE/iskan-kur-kurdurak.state")"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'son-tamamlanan: yeni-proje' \
  && printf '%s' "$out" | grep -q 'sıradaki: durak1-cloudtop-pr' && [ "$SUM_ST_0" = "$SUM_ST_1" ] \
  && ok "kur --durum: salt-oku durum-raporu (son-tamamlanan + sıradaki + md5 değişmez)" \
  || bad "kur --durum: salt-oku sözleşmesi kırık (rc=$rc)"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurhic --durum 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'hiç koşulmamış' \
  && ok "kur --durum: durum-dosyası yokken 'hiç koşulmamış — baştan' (rc=0)" \
  || bad "kur --durum: dosyasız-durum raporu kırık (rc=$rc)"

# 58. kur --devam: durum-dosyasından sürer (adım-1 TEKRAR koşulmaz), DURAK-1 hâlâ merge'siz → yine DURAK
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurdurak --devam 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'son-tamamlanan=yeni-proje' \
  && ! printf '%s' "$out" | grep -q 'kur adım 1/7' && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "kur --devam: state'ten adım-2'den sürdü (adım-1 atlandı) + DURAK-1 idempotent" \
  || bad "kur --devam: state-resume kırık (rc=$rc)"

# 59. kur --devam İLERLEME: origin/main'de kayıtlı proje (kurtest) DURAK-1'i GEÇER, state ilerler,
#     adım-3 (iskan-host --apply) GO'suz exit=4 AYNEN iletilir → GO-sonrası --devam kaldığı yerden
printf 'yeni-proje\n' > "$KR_STATE/iskan-kur-kurtest.state"
out="$(env -u ISKAN_FAZ4_GO "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --devam 2>&1)"
rc=$?
[ "$rc" = "4" ] && printf '%s' "$out" | grep -q 'kur adım 3/7: iskan-host' \
  && ! printf '%s' "$out" | grep -q 'kur adım 1/7' && printf '%s' "$out" | grep -q 'ISKAN_FAZ4_GO' \
  && ok "kur --devam ilerleme: DURAK-1 geçildi (origin/main'de blok) + adım-3 GO'suz exit=4 iletildi" \
  || bad "kur --devam ilerleme: sözleşme kırık (rc=$rc)"
[ "$(cat "$KR_STATE/iskan-kur-kurtest.state" 2>/dev/null)" = "durak1-cloudtop-pr" ] \
  && ok "kur --devam ilerleme: durum-dosyası 'durak1-cloudtop-pr'a ilerledi (GO-sonrası kaldığı yerden)" \
  || bad "kur --devam ilerleme: state ilerlemedi ('$(cat "$KR_STATE/iskan-kur-kurtest.state" 2>/dev/null)')"

find "$KR_REPO" "$KR_STATE" -type f -delete 2>/dev/null
find "$KR_REPO" "$KR_STATE" -depth -type d -delete 2>/dev/null

# 60. D6 tuzak-fix (mem_limit): default artık 2g ("sessiz-ölü ekip" panzehiri) + uyarı yok
MEM_FIXTURE="/tmp/iskan-test-mem.$$.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$MEM_FIXTURE"
out="$(ISKAN_REPO_COMPOSE="$MEM_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje memtest --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'mem_limit: 2g' && ! printf '%s' "$out" | grep -q '2g-altı' \
  && ok "yeni-proje default mem_limit=2g (512m tuzağı kapandı; uyarısız)" \
  || bad "yeni-proje default mem_limit sözleşmesi kırık (rc=$rc)"

# 61. D6 tuzak-fix (mem_limit): 2g-altı açık-beyan WARN'lanır ama hard-fail ETMEZ (bilinçli-küçük serbest)
out="$(ISKAN_REPO_COMPOSE="$MEM_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje memtest --mem-limit 512m --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q '2g-altı' && printf '%s' "$out" | grep -q 'mem_limit: 512m' \
  && ok "yeni-proje --mem-limit 512m: WARN basıldı + rc=3 korundu (hard-fail değil)" \
  || bad "yeni-proje --mem-limit 512m: WARN sözleşmesi kırık (rc=$rc)"
out="$(ISKAN_REPO_COMPOSE="$MEM_FIXTURE" bash "$SCRIPT_DIR/iskan.sh" yeni-proje memtest --mem-limit 4g --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && ! printf '%s' "$out" | grep -q '2g-altı' \
  && ok "yeni-proje --mem-limit 4g: 2g-üstü uyarısız (golden)" \
  || bad "yeni-proje --mem-limit 4g: yanlış-uyarı (rc=$rc)"
find /tmp -maxdepth 1 -name "iskan-test-mem.$$.yml" -delete 2>/dev/null

# ── P1e: iskan-host.sh HOST-KAPASİTE satırı (kur adım-3 önizlemesine kapasite-görüşü) ──────

# 62. kapasite yeşil-yol (ssh-stub): avail 4096MB + 42G → SIĞAR; düşük-RAM → SIĞMAZ; erişilemez → doğrulanmadı
HK_STUB="$(mktemp -d)"
cat > "$HK_STUB/ssh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"free -m"*) echo "${HK_MEM:-4096}" ;;
  *"df -BG"*) echo "${HK_DISK:-42}" ;;
esac
exit 0
EOF
chmod +x "$HK_STUB/ssh"
out="$(PATH="$HK_STUB:$PATH" HK_MEM=4096 HK_DISK=42 ISKAN_SSH_HOST=stubhost \
  ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'SIĞAR' && printf '%s' "$out" | grep -q 'boş 42G' \
  && ok "iskan-host kapasite: avail 4096MB + 42G → SIĞAR satırı basıldı (rc=3 korunur)" \
  || bad "iskan-host kapasite: yeşil-yol kırık (rc=$rc)"
out="$(PATH="$HK_STUB:$PATH" HK_MEM=1024 HK_DISK=6 ISKAN_SSH_HOST=stubhost \
  ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'SIĞMAZ' && printf '%s' "$out" | grep -q 'DAR' \
  && ok "iskan-host kapasite: avail 1024MB + 6G → SIĞMAZ + disk-DAR uyarıları (dry-run karar vermez, rc=3)" \
  || bad "iskan-host kapasite: dar-yol kırık (rc=$rc)"
out="$(ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" \
  bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
printf '%s' "$out" | grep -q 'SIĞAR/SIĞMAZ verilemez' \
  && ok "iskan-host kapasite: erişilemez-host → dürüst 'doğrulanamadı' (sahte-verdikt yok)" \
  || bad "iskan-host kapasite: erişilemez-host 3-durum dili eksik"
# MINOR fix: bozuk eşik-env (sayısal-olmayan) → SAHTE [kırmızı] SIĞMAZ değil, dürüst [doğrulanmadı]
out="$(PATH="$HK_STUB:$PATH" HK_MEM=4096 HK_DISK=42 ISKAN_SSH_HOST=stubhost ISKAN_KAPASITE_MEM_MB='abc' ISKAN_KAPASITE_DISK_G='10 20' \
  ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'RAM eşiği geçersiz' && printf '%s' "$out" | grep -q 'disk eşiği geçersiz' \
  && ! printf '%s' "$out" | grep -q 'integer expression' && ! printf '%s' "$out" | grep -qE '\[kırmızı\] (RAM|disk).*SIĞMAZ|\[kırmızı\] disk.*DAR' \
  && ok "iskan-host kapasite: bozuk eşik-env → dürüst [doğrulanmadı] (SAHTE SIĞMAZ + ham bash-hatası yok, MINOR fix)" \
  || bad "iskan-host kapasite: bozuk-eşik sözleşmesi kırık (rc=$rc)"
# re-verify MINOR: sayısal-AMA-taşan eşik (int64-üstü, 20 hane) da [doğrulanamadı] — ham hata+sahte SIĞMAZ yok
out="$(PATH="$HK_STUB:$PATH" HK_MEM=4096 HK_DISK=42 ISKAN_SSH_HOST=stubhost ISKAN_KAPASITE_MEM_MB='99999999999999999999' \
  ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'RAM eşiği geçersiz' && ! printf '%s' "$out" | grep -q 'integer expression' && ! printf '%s' "$out" | grep -qE '\[kırmızı\] RAM.*SIĞMAZ' \
  && ok "iskan-host kapasite: taşan-sayı eşik (20-hane) → [doğrulanamadı] (int64-overflow ham-hata+sahte SIĞMAZ yok, re-verify MINOR fix)" \
  || bad "iskan-host kapasite: taşan-eşik hâlâ ham-hata/sahte-SIĞMAZ üretiyor (rc=$rc)"
find "$HK_STUB" -type f -delete 2>/dev/null; find "$HK_STUB" -depth -type d -delete 2>/dev/null

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
