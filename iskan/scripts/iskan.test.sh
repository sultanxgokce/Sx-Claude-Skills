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

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
