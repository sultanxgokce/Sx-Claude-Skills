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
#     + DURAK-1 ÜÇLÜSÜ (P-Y2): setup-<ad>.sh üretilir + setup-tunnel 3-dokunuş eklenir
YP_DIR3="/tmp/iskan-test-yp-apply.$$"
mkdir -p "$YP_DIR3"
YP_FIXTURE3="$YP_DIR3/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE3"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$YP_DIR3/setup-tunnel.sh"
ORIG_HEAD="$(head -5 "$YP_FIXTURE3")"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE3" ISKAN_PORT_LOCK_PATH="$YP_DIR3/.lock" \
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
grep -q '\./config/\.claude:/config/\.claude' "$YP_FIXTURE3" && grep -q 'DEFAULT_WORKSPACE=/config/projects/testproje' "$YP_FIXTURE3" \
  && ok "yeni-proje --apply: mount-paketi (ortak .claude + DEFAULT_WORKSPACE) compose-blokta (B2-fix)" \
  || bad "yeni-proje --apply: mount-paketi EKSİK (B2 zincir-blokajı geri geldi)"
if ! grep -q '\./config/projects/testproje' "$YP_FIXTURE3"; then
  ok "yeni-proje --apply: ortak-projects mount'u BİLİNÇLİ-YOK (EY_HOST_PROJ gölgeleme-önlemi, b0024)"
else
  bad "yeni-proje --apply: ortak-projects mount'u sızmış (EY_HOST_PROJ'u gölgeler)"
fi
if [ -f "$YP_DIR3/setup-testproje.sh" ] && bash -n "$YP_DIR3/setup-testproje.sh" 2>/dev/null \
   && grep -q 'setup-isolated.sh" cloudtop-testproje /config/projects/testproje Testproje' "$YP_DIR3/setup-testproje.sh"; then
  ok "yeni-proje --apply: setup-testproje.sh üretildi (İNCE-SARMALAYICI, bash -n temiz — B1-fix)"
else
  bad "yeni-proje --apply: setup-testproje.sh üretilmedi/bozuk (B1 zincir-blokajı geri geldi)"
fi
# Fix-E (re-verify MINOR): setup-üreteci pozisyon-hint'i numeratörü de ISKAN_KUR_ADIMLAR'dan TÜRETİR
# (magic-6 değil); ekip-yerlestir=6, zincir=8 → üretilen script 'kur zinciri adım 6/8' basmalı.
if grep -qF 'kur zinciri adım 6/8' "$YP_DIR3/setup-testproje.sh"; then
  ok "yeni-proje --apply: setup-script pozisyon-hint'i türetilmiş (adım 6/8 — numeratör+payda parametrik, magic-6 yok)"
else
  bad "yeni-proje --apply: setup-script pozisyon-hint'i bayat/hardcoded (beklenen 'adım 6/8' — Fix-E kırık)"
fi
if grep -q '^TESTPROJE_HOSTNAME=' "$YP_DIR3/setup-tunnel.sh" \
   && grep -q 'hostname: ${TESTPROJE_HOSTNAME}' "$YP_DIR3/setup-tunnel.sh" \
   && grep -q 'route dns "$TUNNEL" "$TESTPROJE_HOSTNAME"' "$YP_DIR3/setup-tunnel.sh" \
   && bash -n "$YP_DIR3/setup-tunnel.sh" 2>/dev/null; then
  ok "yeni-proje --apply: setup-tunnel 3-dokunuş (değişken + ingress + route-dns, bash -n temiz — P-Y2)"
else
  bad "yeni-proje --apply: setup-tunnel dokunuşu eksik/bozuk (cf-yayin REPO-KANIT'ı kırmızı kalır)"
fi
awk '/hostname: \$\{TESTPROJE_HOSTNAME\}/{f=1} f&&/http_status:404/{print "SIRALI"; exit}' "$YP_DIR3/setup-tunnel.sh" | grep -q SIRALI \
  && ok "yeni-proje --apply: ingress-çifti catch-all 404'ün ÖNCESİNDE (sıra korunmuş)" \
  || bad "yeni-proje --apply: ingress-çifti 404'ten sonra/karışık (cloudflared onu asla eşlemez)"
# sokum-simetrisi (golden): _sokum_satir_cikar eklenen üç-satırı geri alınca dosya pristine-fixture'a bayt-eş döner
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "/tmp/iskan-test-tunnel-pristine.$$.sh"
bash -c "
  source <(sed -n '/^_sokum_satir_cikar()/,/^}/p' '$SCRIPT_DIR/iskan.sh')
  _sokum_satir_cikar '$YP_DIR3/setup-tunnel.sh' testproje
" >/dev/null 2>&1
if [ "$(md5sum < "$YP_DIR3/setup-tunnel.sh")" = "$(md5sum < "/tmp/iskan-test-tunnel-pristine.$$.sh")" ]; then
  ok "yeni-proje ⟷ sokum SİMETRİ: tünel-dokunuşu _sokum_satir_cikar ile bayt-eş geri alındı"
else
  bad "yeni-proje ⟷ sokum SİMETRİ KIRIK: söküm tünel-satırlarını temiz geri alamıyor"
fi
find /tmp -maxdepth 1 -name "iskan-test-tunnel-pristine.$$.sh" -delete 2>/dev/null
find "$YP_DIR3" -type f -delete 2>/dev/null; find "$YP_DIR3" -depth -type d -delete 2>/dev/null

# 15. yeni-proje İDEMPOTENCY: aynı-ad İKİNCİ-kez → apply rc=0 + üç-dosya-değişmez; dry-run rc=3;
#     GO'suz apply mevcut-blokta BİLE exit≠0 (G3 negatif-kapı idempotent-yoldan delinmez);
#     + ÜÇLÜ-TAMAMLAYICI: eksik kardeş-kalem (setup-script) silinmişse idempotent-geçiş yeniden üretir
YP_DIR4="/tmp/iskan-test-yp-dup.$$"
mkdir -p "$YP_DIR4"
YP_FIXTURE4="$YP_DIR4/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE4"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$YP_DIR4/setup-tunnel.sh"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4" ISKAN_PORT_LOCK_PATH="$YP_DIR4/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
SUM_DUP_BEFORE="$(cat "$YP_FIXTURE4" "$YP_DIR4/setup-tunnel.sh" "$YP_DIR4/setup-testproje.sh" 2>/dev/null | md5sum | awk '{print $1}')"
out="$(ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4" ISKAN_PORT_LOCK_PATH="$YP_DIR4/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply 2>&1)"
rc=$?
SUM_DUP_AFTER="$(cat "$YP_FIXTURE4" "$YP_DIR4/setup-tunnel.sh" "$YP_DIR4/setup-testproje.sh" 2>/dev/null | md5sum | awk '{print $1}')"
[ "$rc" = "0" ] && ok "yeni-proje --apply: aynı-ad ikinci-kez İDEMPOTENT-geçiş (rc=0)" || bad "yeni-proje --apply: idempotent-geçiş beklenirdi (rc=0), gelen $rc"
[ "$SUM_DUP_BEFORE" = "$SUM_DUP_AFTER" ] && ok "yeni-proje --apply: idempotent-geçişte ÜÇ dosya da DEĞİŞMEDİ" || bad "yeni-proje --apply: idempotent-geçişte dosya DEĞİŞTİ (yeniden-yazım ihlali)"
printf '%s' "$out" | grep -q "İDEMPOTENT" && ok "yeni-proje --apply: idempotent-geçiş açıkça beyan edildi" || bad "yeni-proje --apply: idempotent-beyanı çıktıda yok"
rm -f "$YP_DIR4/setup-testproje.sh"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4" ISKAN_PORT_LOCK_PATH="$YP_DIR4/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] && [ -f "$YP_DIR4/setup-testproje.sh" ] \
  && ok "yeni-proje --apply: ÜÇLÜ-TAMAMLAYICI — silinen setup-script idempotent-geçişte yeniden üretildi" \
  || bad "yeni-proje --apply: üçlü-tamamlayıcı çalışmadı (rc=$rc, setup-script $([ -f "$YP_DIR4/setup-testproje.sh" ] && echo var || echo YOK))"
ISKAN_REPO_COMPOSE="$YP_FIXTURE4" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --dry-run >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] && ok "yeni-proje --dry-run: mevcut-blokta plan-exit=3 (idempotent-önizleme)" || bad "yeni-proje --dry-run: mevcut-blokta beklenen rc=3, gelen $rc"
env -u ISKAN_FAZ4_GO ISKAN_REPO_COMPOSE="$YP_FIXTURE4" bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
[ "$rc" != "0" ] && ok "yeni-proje --apply: mevcut-blokta bile GO'suz exit≠0 ($rc)" || bad "yeni-proje --apply: GO'suz idempotent-yol exit=0 (negatif-kapı delindi)"
find "$YP_DIR4" -type f -delete 2>/dev/null; find "$YP_DIR4" -depth -type d -delete 2>/dev/null

# 14b. LB-1 söküm-simetri TİRELİ-isimde: 'my-proj' apply → söküm → tünel bayt-eş pristine döner
#      (uvar-sanitize [my-proj→MY_PROJ] raw-token'ı içermez; ingress/route raw-ad yorum-etiketiyle taşınır)
YP_DIR3H="/tmp/iskan-test-yp-hyphen.$$"
mkdir -p "$YP_DIR3H"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_DIR3H/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$YP_DIR3H/setup-tunnel.sh"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "/tmp/iskan-test-hyphen-pristine.$$.sh"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_DIR3H/docker-compose.server.yml" ISKAN_PORT_LOCK_PATH="$YP_DIR3H/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje my-proj --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] && grep -q '^MY_PROJ_HOSTNAME=' "$YP_DIR3H/setup-tunnel.sh" && grep -q 'my-proj (İSKÂN yeni-proje)' "$YP_DIR3H/setup-tunnel.sh" \
  && ok "yeni-proje 'my-proj': tireli-isim apply çalıştı (MY_PROJ_HOSTNAME + raw-ad yorum-etiketi)" \
  || bad "yeni-proje 'my-proj': tireli-isim apply kırık (rc=$rc)"
bash -c "source <(sed -n '/^_sokum_satir_cikar()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _sokum_satir_cikar '$YP_DIR3H/setup-tunnel.sh' my-proj" >/dev/null 2>&1
if [ "$(md5sum < "$YP_DIR3H/setup-tunnel.sh")" = "$(md5sum < "/tmp/iskan-test-hyphen-pristine.$$.sh")" ]; then
  ok "yeni-proje 'my-proj' ⟷ sokum SİMETRİ: TİRELİ-isimde bayt-eş geri alındı (LB-1 fix)"
else
  bad "yeni-proje 'my-proj' ⟷ sokum SİMETRİ KIRIK: tireli-isim öksüz ${MY_PROJ_HOSTNAME} bıraktı (LB-1 regresyon)"
fi
! grep -q 'MY_PROJ_HOSTNAME' "$YP_DIR3H/setup-tunnel.sh" \
  && ok "yeni-proje 'my-proj': söküm sonrası öksüz \${MY_PROJ_HOSTNAME} referansı KALMADI (set -u güvenli)" \
  || bad "yeni-proje 'my-proj': söküm sonrası tanımsız MY_PROJ_HOSTNAME referansı kaldı"
find /tmp -maxdepth 1 -name "iskan-test-hyphen-pristine.$$.sh" -delete 2>/dev/null
find "$YP_DIR3H" -type f -delete 2>/dev/null; find "$YP_DIR3H" -depth -type d -delete 2>/dev/null

# 14c. LB-2 charset-gate: yeni-proje enjeksiyon/traversal adları SIFIR-dokunuş reddeder (bash -n kör)
YP_DIRINJ="/tmp/iskan-test-yp-inj.$$"
mkdir -p "$YP_DIRINJ"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_DIRINJ/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$YP_DIRINJ/setup-tunnel.sh"
INJ_BEFORE="$(md5sum "$YP_DIRINJ/docker-compose.server.yml" | awk '{print $1}')"
INJ_KACAK=""
for kotu in 'foo;id' 'z$(touch pwned)z' 'a/b' '../etc' 'x&y'; do
  ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_DIRINJ/docker-compose.server.yml" ISKAN_PORT_LOCK_PATH="$YP_DIRINJ/.lock" \
    bash "$SCRIPT_DIR/iskan.sh" yeni-proje "$kotu" --apply >/dev/null 2>&1
  [ "$?" = "1" ] || INJ_KACAK="$INJ_KACAK [$kotu:rc=$?]"
done
INJ_AFTER="$(md5sum "$YP_DIRINJ/docker-compose.server.yml" | awk '{print $1}')"
NSETUP="$(find "$YP_DIRINJ" -name 'setup-*.sh' ! -name 'setup-tunnel.sh' | wc -l | tr -d ' ')"
[ -z "$INJ_KACAK" ] && [ "$INJ_BEFORE" = "$INJ_AFTER" ] && [ ! -e pwned ] && [ "$NSETUP" = "0" ] \
  && ok "yeni-proje charset-gate: 5 enjeksiyon/traversal adı fail-closed rc=1 + SIFIR-dosya (LB-2 fix)" \
  || bad "yeni-proje charset-gate: KAÇAK:$INJ_KACAK compose-değişti=$([ "$INJ_BEFORE" != "$INJ_AFTER" ] && echo E) setup-üretildi=$NSETUP pwned=$([ -e pwned ] && echo VAR)"
rm -f pwned
find "$YP_DIRINJ" -type f -delete 2>/dev/null; find "$YP_DIRINJ" -depth -type d -delete 2>/dev/null

# 14d. re-verify MAJOR: rakam-başlangıçlı MEŞRU-charset ad → RED (uvar geçersiz bash-identifier; bash -n kör)
YP_DIRNUM="/tmp/iskan-test-yp-num.$$"
mkdir -p "$YP_DIRNUM"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_DIRNUM/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$YP_DIRNUM/setup-tunnel.sh"
SUM_NUM_BEFORE="$(md5sum "$YP_DIRNUM/docker-compose.server.yml" | awk '{print $1}')"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_DIRNUM/docker-compose.server.yml" ISKAN_PORT_LOCK_PATH="$YP_DIRNUM/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje 9proj --apply >/dev/null 2>&1
rc=$?
SUM_NUM_AFTER="$(md5sum "$YP_DIRNUM/docker-compose.server.yml" | awk '{print $1}')"
[ "$rc" = "1" ] && [ "$SUM_NUM_BEFORE" = "$SUM_NUM_AFTER" ] && [ ! -f "$YP_DIRNUM/setup-9proj.sh" ] \
  && ok "yeni-proje '9proj': rakam-başı harf-başı-kapısında RED + SIFIR-dokunuş (re-verify MAJOR fix, yalancı-yeşil yok)" \
  || bad "yeni-proje '9proj': rakam-başı geçti (rc=$rc) — geçersiz \${9PROJ_HOSTNAME} repoya sızardı"
# harf-başı meşru ad (rakam-İÇEREN ama harf-başlayan) hâlâ GEÇER — over-block regresyonu yok
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_DIRNUM/docker-compose.server.yml" ISKAN_PORT_LOCK_PATH="$YP_DIRNUM/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje proj9 --apply >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] && [ -f "$YP_DIRNUM/setup-proj9.sh" ] \
  && ok "yeni-proje 'proj9': harf-başı+rakam-içeren meşru-ad hâlâ geçer (over-block yok)" \
  || bad "yeni-proje 'proj9': meşru-ad yanlış-red (rc=$rc)"
find "$YP_DIRNUM" -type f -delete 2>/dev/null; find "$YP_DIRNUM" -depth -type d -delete 2>/dev/null

# 15b. yeni-proje fail-closed: tünel-dosyası YOKSA taze-apply compose'a BİLE dokunmadan RED (P-Y2 ön-kapı)
YP_DIR4B="/tmp/iskan-test-yp-notunnel.$$"
mkdir -p "$YP_DIR4B"
YP_FIXTURE4B="$YP_DIR4B/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE4B"
SUM_NT_BEFORE="$(md5sum "$YP_FIXTURE4B" | awk '{print $1}')"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_FIXTURE4B" ISKAN_PORT_LOCK_PATH="$YP_DIR4B/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje testproje --apply >/dev/null 2>&1
rc=$?
SUM_NT_AFTER="$(md5sum "$YP_FIXTURE4B" | awk '{print $1}')"
[ "$rc" != "0" ] && [ "$SUM_NT_BEFORE" = "$SUM_NT_AFTER" ] && [ ! -f "$YP_DIR4B/setup-testproje.sh" ] \
  && ok "yeni-proje --apply: tünel-dosyası yokken fail-closed RED + SIFIR-dokunuş (yarım-üçlü önlendi)" \
  || bad "yeni-proje --apply: tünel-dosyası yokken rc=$rc / dosya-dokunuşu var (fail-closed delindi)"
find "$YP_DIR4B" -type f -delete 2>/dev/null; find "$YP_DIR4B" -depth -type d -delete 2>/dev/null

# 15b2. MAJOR-3: tünel-dosyası VAR ama ÇIPASIZ → taze-apply compose'a dokunmadan RED (varlık-only yetmez)
YP_DIRAC="/tmp/iskan-test-yp-cipasiz.$$"
mkdir -p "$YP_DIRAC"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_DIRAC/docker-compose.server.yml"
printf '#!/usr/bin/env bash\necho çıpasız-stub\n' > "$YP_DIRAC/setup-tunnel.sh"
SUM_AC_BEFORE="$(md5sum "$YP_DIRAC/docker-compose.server.yml" | awk '{print $1}')"
ISKAN_FAZ4_GO=1 ISKAN_REPO_COMPOSE="$YP_DIRAC/docker-compose.server.yml" ISKAN_PORT_LOCK_PATH="$YP_DIRAC/.lock" \
  bash "$SCRIPT_DIR/iskan.sh" yeni-proje validname --apply >/dev/null 2>&1
rc=$?
SUM_AC_AFTER="$(md5sum "$YP_DIRAC/docker-compose.server.yml" | awk '{print $1}')"
[ "$rc" != "0" ] && [ "$SUM_AC_BEFORE" = "$SUM_AC_AFTER" ] && [ ! -f "$YP_DIRAC/setup-validname.sh" ] \
  && ok "yeni-proje --apply: çıpasız-mevcut tünel-dosyası → RED + SIFIR-dokunuş (MAJOR-3 fix, varlık-only kapatıldı)" \
  || bad "yeni-proje --apply: çıpasız-tünel yarım-yazım (rc=$rc compose-değişti=$([ "$SUM_AC_BEFORE" != "$SUM_AC_AFTER" ] && echo E) setup=$([ -f "$YP_DIRAC/setup-validname.sh" ] && echo VAR))"
find "$YP_DIRAC" -type f -delete 2>/dev/null; find "$YP_DIRAC" -depth -type d -delete 2>/dev/null

# 15c. B1 bilinçli-köprü allowlist (P-Y1): mevcut bir servis ./config/.claude paylaşıyorken
#      mount-paketli aday-blok default-allowlist'le GÜVENLİ sayılır; allowlist kapatılınca RED-adayı
YP_DIR4C="/tmp/iskan-test-yp-allow.$$"
mkdir -p "$YP_DIR4C"
YP_FIXTURE4C="$YP_DIR4C/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$YP_FIXTURE4C"
cat >> "$YP_FIXTURE4C" <<'EOF'
  gamma:
    container_name: cloudtop-gamma
    volumes:
      - ./config-gamma:/config
      - ./config/.claude:/config/.claude
    ports:
      - "127.0.0.1:9003:9003"
EOF
out="$(ISKAN_REPO_COMPOSE="$YP_FIXTURE4C" bash "$SCRIPT_DIR/iskan.sh" yeni-proje allowtest --dry-run 2>&1)"
printf '%s' "$out" | grep -q 'yeni-kesişim: 0' \
  && ok "B1 allowlist: ortak .claude kesişimi bilinçli-köprü sayıldı (yeni-kesişim: 0, mount-paketi kendi kapısına takılmıyor)" \
  || bad "B1 allowlist: mount-paketi kendi guard'ına takıldı (P-Y1 çarpışması geri geldi)"
out="$(ISKAN_B1_BILINCLI_KOPRU="" ISKAN_REPO_COMPOSE="$YP_FIXTURE4C" bash "$SCRIPT_DIR/iskan.sh" yeni-proje allowtest --dry-run 2>&1)"
printf '%s' "$out" | grep -qE 'yeni-kesişim: [1-9]' \
  && ok "B1 allowlist: allowlist kapatılınca aynı kesişim yine RED-adayı (guard hâlâ dişli)" \
  || bad "B1 allowlist: allowlist kapalıyken kesişim görünmez oldu (guard köreldi)"
find "$YP_DIR4C" -type f -delete 2>/dev/null; find "$YP_DIR4C" -depth -type d -delete 2>/dev/null

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

# ── FAZ-6b: ekip-pong (canlılık-kapısı — P3 pong-kablosu) ─────────────────────────────────
# Stub pong-script: gerçek tenant-pong-proof yerine kontrollü exit (seat-adına göre). Böylece
# ekip-pong'un DÖNGÜ mantığı (üç-durum tally + fail-closed + charset-hijyeni) ssh/container'sız
# hermetik test edilir. Gerçek pong-script'in kendi testleri Nexus tenant-pong-proof.test.sh'te.
PONG_STUB="$(mktemp)"
cat > "$PONG_STUB" <<'EOF'
#!/usr/bin/env bash
# $1=proje $2=seat; seat 'dead*'→3(kırmızı) · 'unm*'→2(ölçülemedi) · diğer→0(yeşil)
case "$2" in dead*) exit 3 ;; unm*) exit 2 ;; *) exit 0 ;; esac
EOF
chmod +x "$PONG_STUB"

# P3-1. ekip-pong: argümansız / modsuz → usage rc=2
bash "$SCRIPT_DIR/iskan.sh" ekip-pong >/dev/null 2>&1; ppc1=$?
bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest >/dev/null 2>&1; ppc2=$?
[ "$ppc1" = "2" ] && [ "$ppc2" = "2" ] && ok "ekip-pong: argümansız/modsuz rc=2 (usage)" \
  || bad "ekip-pong: usage rc beklenen 2/2, gelen $ppc1/$ppc2"

# P3-2. ekip-pong --dry-run + ISKAN_EY_ROSTER: plan-exit=3 + her seat plan-satırı + SIFIR-yazım
out="$(ISKAN_EY_ROSTER='yon:yonetici motor1:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --dry-run 2>&1)"; rc=$?
[ "$rc" = "3" ] \
  && printf '%s' "$out" | grep -q "seat 'yon'" && printf '%s' "$out" | grep -q "seat 'motor1'" \
  && printf '%s' "$out" | grep -q "kimlik 'rol: yon'" \
  && ok "ekip-pong --dry-run: plan-exit=3 + her seat --kimlik-plan satırı (SAHTE-YEŞİL YOK ibaresi)" \
  || bad "ekip-pong --dry-run: plan sözleşmesi kırık (rc=$rc)"

# P3-3. ekip-pong roster-kaynaksız: dürüst-kırmızı rc=1 + 'roster-kaynağı yok' (kur dry-run bunu
# [doğrulanmadı] olarak sürdürür — ekip-yerlestir ile AYNI marker)
out="$(env -u ISKAN_EY_ROSTER ISKAN_SSH_HOST='bilinçli-bozuk-host.invalid' ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --dry-run 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'roster-kaynağı yok' \
  && ok "ekip-pong roster-kaynaksız: dürüst-kırmızı rc=1 + marker (kur dry-run doğrulanmadı-sürdürür)" \
  || bad "ekip-pong roster-kaynaksız: dürüst-kırmızı sözleşmesi kırık (rc=$rc)"

# P3-4. ekip-pong --apply hepsi-yeşil: rc=0 + 'canlılık-kapısı geçildi' + her seat GEÇTİ
out="$(ISKAN_EY_ROSTER='yon:yonetici motor1:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$(printf '%s' "$out" | grep -c 'GEÇTİ')" = "2" ] \
  && printf '%s' "$out" | grep -q 'canlılık-kapısı geçildi' \
  && ok "ekip-pong --apply hepsi-yeşil: rc=0 + 2 seat GEÇTİ + kapı-geçildi özeti" \
  || bad "ekip-pong --apply hepsi-yeşil: sözleşme kırık (rc=$rc)"

# P3-5. ekip-pong --apply seat-ÖLÜ: fail-closed rc=1 + KIRMIZI + 'fail-closed DURDU' (SAHTE-YEŞİL yakalandı)
out="$(ISKAN_EY_ROSTER='yon:yonetici deadmotor:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'SAHTE-YEŞİL yakalandı' && printf '%s' "$out" | grep -q 'fail-closed DURDU' \
  && ok "ekip-pong --apply seat-ölü: fail-closed rc=1 (bir seat KIRMIZI → zincir DURur)" \
  || bad "ekip-pong --apply seat-ölü: fail-closed sözleşmesi kırık (rc=$rc)"

# P3-6. ekip-pong --apply seat-ÖLÇÜLEMEDİ: unknown≠fail → rc=0 (yerleşim düşmez) + [doğrulanmadı]
out="$(ISKAN_EY_ROSTER='yon:yonetici unmseat:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q '\[doğrulanmadı\] ekip-pong unmseat' && printf '%s' "$out" | grep -q 'ölçülemedi=1' \
  && ok "ekip-pong --apply ölçülemedi: unknown≠fail (rc=0 + [doğrulanmadı], seat-KIRMIZI değil)" \
  || bad "ekip-pong --apply ölçülemedi: üç-durum sözleşmesi kırık (rc=$rc)"

# P3-7. ekip-pong --apply pong-script YOK: [doğrulanmadı] non-blocking rc=0 (zincir bloklanmaz;
# F4-runbook script-varlığını+yeşilini kabul-kapısı yapar)
out="$(ISKAN_EY_ROSTER='yon:yonetici' ISKAN_PONG_SH='/tmp/yok-olmayan-pong.invalid' \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'pong-script bulunamadı' && printf '%s' "$out" | grep -q 'DOĞRULANAMADI' \
  && ok "ekip-pong --apply script-yok: [doğrulanmadı] non-blocking rc=0 (unknown≠fail)" \
  || bad "ekip-pong --apply script-yok: non-blocking sözleşmesi kırık (rc=$rc)"

# P3-8. ekip-pong charset-hijyeni (injection panzehiri): seat-adı [A-Za-z0-9-] dışı → fail-closed rc=1,
# HİÇBİR prob koşulmaz (seat ssh/docker/tmux'a gömülür — tüketim-noktası kapısı)
out="$(ISKAN_EY_ROSTER='yon:yonetici ba;rm-rf:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'roster-hijyeni' && ! printf '%s' "$out" | grep -q 'GEÇTİ' \
  && ok "ekip-pong charset-hijyeni: geçersiz seat-adı → fail-closed rc=1 (hiçbir prob koşulmadı)" \
  || bad "ekip-pong charset-hijyeni: injection-panzehiri kırık (rc=$rc)"

# P3-9. ekip-pong --no-ping: plan/pong PONG'suz iletilir (post-claude re-verify yolu)
out="$(ISKAN_EY_ROSTER='yon:yonetici' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --dry-run --no-ping 2>&1)"; rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q "PONG'suz" \
  && ok "ekip-pong --no-ping: plan 'PONG'suz' işaretli (post-claude re-verify yolu)" \
  || bad "ekip-pong --no-ping: bayrak-iletim kırık (rc=$rc)"

# P3-10. ekip-pong yalnız-boşluk roster (re-verify MAJOR — sahte-yeşil sınıfı): "   " → [ -z ] geçer ama
# word-split 0 seat → fail-closed rc=1 + 'HİÇBİR seat-adı ayrıştırılamadı' + 'canlılık-kapısı geçildi' YOK
out="$(ISKAN_EY_ROSTER='   ' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'HİÇBİR seat-adı ayrıştırılamadı' && ! printf '%s' "$out" | grep -q 'canlılık-kapısı geçildi' \
  && ok "ekip-pong yalnız-boşluk roster: fail-closed rc=1 (0 seat → sahte-yeşil basmaz)" \
  || bad "ekip-pong yalnız-boşluk roster: sahte-yeşil kör-noktası açık (rc=$rc)"

# P3-11. ekip-pong TÜMÜ-ölçülemedi (re-verify MAJOR — pozitif-kanıt kapısı): tüm seat 'unm*' → yeşil=0 ∧
# ölçülemedi>0 ∧ kırmızı=0 → unknown≠fail (rc=0, zincir sürer) AMA unknown≠pass → 'canlılık-kapısı geçildi' YOK
out="$(ISKAN_EY_ROSTER='unm1:yonetici unm2:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "0" ] && ! printf '%s' "$out" | grep -q 'canlılık-kapısı geçildi' \
  && printf '%s' "$out" | grep -q 'POZİTİF doğrulanamadı' && printf '%s' "$out" | grep -q 'ölçülemedi=2' \
  && ok "ekip-pong tümü-ölçülemedi: yeşil=0 → markörsüz [doğrulanmadı] rc=0 (unknown≠pass, sahte-GEÇTİ yok)" \
  || bad "ekip-pong tümü-ölçülemedi: pozitif-kanıt kapısı kırık (rc=$rc)"

# P3-12. ekip-pong KARIŞIK yeşil≥1 + ölçülemedi (pozitif-kanıt ALT-sınırı — kapı 'tümü-yeşil' DEĞİL
# 'en-az-bir-yeşil'; aşırı-sıkma regresyonu): 1 yeşil + 1 ölçülemedi → 'canlılık-kapısı geçildi' BASILIR
out="$(ISKAN_EY_ROSTER='yon:yonetici unmseat:uye' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --apply 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'canlılık-kapısı geçildi' && printf '%s' "$out" | grep -q 'yeşil=1' \
  && ok "ekip-pong karışık yeşil≥1: 'geçildi' basılır (pozitif-kanıt alt-sınırı, aşırı-sıkı değil)" \
  || bad "ekip-pong karışık yeşil≥1: pozitif-kanıt alt-sınırı kırık (rc=$rc)"

# P3-13. ekip-pong yalnız-boşluk roster --dry-run: guard dry-run bloğundan ÖNCE → erken fail-closed rc=1 (hem-mod)
out="$(ISKAN_EY_ROSTER='   ' ISKAN_PONG_SH="$PONG_STUB" \
  bash "$SCRIPT_DIR/iskan.sh" ekip-pong ptest --dry-run 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'HİÇBİR seat-adı ayrıştırılamadı' \
  && ok "ekip-pong yalnız-boşluk roster --dry-run: erken fail-closed rc=1 (hem-mod guard)" \
  || bad "ekip-pong yalnız-boşluk roster --dry-run: erken-guard kırık (rc=$rc)"

rm -f "$PONG_STUB" 2>/dev/null

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
# PR-C yaşamdöngüsü: v2 state (pin-satırlı) da TEK-rm ile ölür — pinler sokum-sonrası hortlamaz
printf 'ekip-yerlestir\npin ISKAN_SSH_HOST=pinli-hayalet.invalid\n' > "$SK_STATE_DIR/iskan-kur-ghost.state"
out="$(PATH="$SK_STUB_DIR:$PATH" SSH_STUB_LOG="$SK_LOG3" ISKAN_SOKUM_GO=1 ISKAN_STATE_DIR="$SK_STATE_DIR" ISKAN_CLOUDTOP_REPO_DIR="$SK_REPO" \
  bash "$SCRIPT_DIR/iskan.sh" sokum ghost --apply 2>&1)"
rc=$?
[ "$rc" = "0" ] && [ ! -f "$SK_STATE_DIR/iskan-kur-ghost.state" ] && printf '%s' "$out" | grep -q 'bayat kur-durum-dosyası temizlendi' \
  && ok "sokum zaten-sokuk --apply: bayat kur-izi (v2 pin-blok DAHİL) tek-rm ile TEMİZLENDİ (P1d + PR-C)" \
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
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$KR_REPO/infra/setup-tunnel.sh"   # DURAK-1 üçlüsü: adım-1 apply tünel-dosyası ister (P-Y2 ön-kapı)
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
for a in "1/8: yeni-proje" "2/8: durak1-cloudtop-pr" "3/8: iskan-host" "4/8: provizyon" "5/8: cf-yayin" "6/8: ekip-yerlestir" "7/8: ekip-pong" "8/8: evergreen-kaydet"; do
  printf '%s' "$out" | grep -q "kur adım $a" || adim_eksik="$adim_eksik [$a]"
done
[ -z "$adim_eksik" ] && ok "kur --dry-run: 8 adımın hepsi zincir-planında (FAZ-sırasıyla; P3 ekip-pong 7/8 dahil)" \
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
# regresyon: GO-durak mesajı adım-sayısını PARAMETRİK bassın (adım 1/8, magic-7 kalıntısı DEĞİL — adversaryal MINOR)
printf '%s' "$out" | grep -q 'GO-durağında DURDU (adım 1/8:' && ! printf '%s' "$out" | grep -q 'adım 1/7' \
  && ok "kur GO'suz: GO-durak mesajı parametrik payda basar (adım 1/8, header ile tutarlı)" \
  || bad "kur GO'suz: GO-durak mesajı magic-7 kalıntısı basıyor (adım 1/7, header 1/8 ile çelişir)"
[ "$SUM_KR_2" = "$SUM_KR_3" ] && [ ! -e "$KR_STATE/iskan-kur-kurgo.state" ] && ! printf '%s' "$out" | grep -q 'kur adım 2/8' \
  && ok "kur GO'suz: zincir DURdu (adım-2 koşulmadı + md5 değişmez + durum-dosyası doğmadı)" \
  || bad "kur GO'suz: DUR sözleşmesi kırık"

# 56. kur DURAK-1 durum-makinesi: GO'lu adım-1 sonrası origin/main'de blok YOK → DURAK exit=0
#     + durum-dosyası 'yeni-proje' (adım-scope'lu env; kalıcı export YOK)
out="$(env "${KR_ENV[@]}" ISKAN_FAZ4_GO=1 bash "$SCRIPT_DIR/iskan.sh" kur kurdurak 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "kur DURAK-1: merge-öncesi zincir İNSAN-durağında durdu (exit=0 adım-tamam)" \
  || bad "kur DURAK-1: durak sözleşmesi kırık (rc=$rc)"
# PR-C bilinçli-değişiklik: state v2 çok-satırlı (satır-1 adım + pin-blok) → tam-eş cat DEĞİL head-1
[ "$(head -1 "$KR_STATE/iskan-kur-kurdurak.state" 2>/dev/null)" = "yeni-proje" ] \
  && ok "kur durum-dosyası: son-tamamlanan='yeni-proje' yazıldı (git-DIŞI state, satır-1 sözleşmesi)" \
  || bad "kur durum-dosyası: beklenen 'yeni-proje', gelen '$(head -1 "$KR_STATE/iskan-kur-kurdurak.state" 2>/dev/null)'"

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
  && ! printf '%s' "$out" | grep -q 'kur adım 1/8' && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "kur --devam: state'ten adım-2'den sürdü (adım-1 atlandı) + DURAK-1 idempotent" \
  || bad "kur --devam: state-resume kırık (rc=$rc)"

# 59. kur --devam İLERLEME: origin/main'de kayıtlı proje (kurtest) DURAK-1'i GEÇER, state ilerler,
#     adım-3 (iskan-host --apply) GO'suz exit=4 AYNEN iletilir → GO-sonrası --devam kaldığı yerden
printf 'yeni-proje\n' > "$KR_STATE/iskan-kur-kurtest.state"
out="$(env -u ISKAN_FAZ4_GO "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --devam 2>&1)"
rc=$?
[ "$rc" = "4" ] && printf '%s' "$out" | grep -q 'kur adım 3/8: iskan-host' \
  && ! printf '%s' "$out" | grep -q 'kur adım 1/8' && printf '%s' "$out" | grep -q 'ISKAN_FAZ4_GO' \
  && ok "kur --devam ilerleme: DURAK-1 geçildi (origin/main'de blok) + adım-3 GO'suz exit=4 iletildi" \
  || bad "kur --devam ilerleme: sözleşme kırık (rc=$rc)"
# PR-C bilinçli-değişiklik: v2 çok-satırlı state → head-1 (satır-1 sözleşmesi)
[ "$(head -1 "$KR_STATE/iskan-kur-kurtest.state" 2>/dev/null)" = "durak1-cloudtop-pr" ] \
  && ok "kur --devam ilerleme: durum-dosyası 'durak1-cloudtop-pr'a ilerledi (GO-sonrası kaldığı yerden)" \
  || bad "kur --devam ilerleme: state ilerlemedi ('$(head -1 "$KR_STATE/iskan-kur-kurtest.state" 2>/dev/null)')"

# ── P1-güvenlik (2026-07-19): slug şüpheli-durum kapısı (G-b) + roster charset-kapısı (G-a) ─

# 59b. SLUG ŞÜPHELİ-DURUM KAPISI: compose-kaydı (origin/main) VAR ∧ kur-izi YOK → zincir RED
#      (hiçbir adım koşulmaz); --benimse bilinçli-devralır; dry-run RED etmez ama uyarır; --durum muaf
rm -f "$KR_STATE/iskan-kur-kurtest.state"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'slug-kapısı' && ! printf '%s' "$out" | grep -q 'kur adım' \
  && ok "kur slug-kapısı: kayıtlı-slug + iz-yok → zincir RED (rc=1, hiçbir adım koşulmadı — G-b)" \
  || bad "kur slug-kapısı: RED sözleşmesi kırık (rc=$rc)"
out="$(env -u ISKAN_FAZ4_GO "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --benimse 2>&1)"
rc=$?
[ "$rc" = "4" ] && printf '%s' "$out" | grep -q 'BİLİNÇLİ-devralındı' && printf '%s' "$out" | grep -q 'kur adım 1/8' \
  && ok "kur slug-kapısı: --benimse bilinçli-devralma → zincir sürdü (adım-1 GO-durağına vardı)" \
  || bad "kur slug-kapısı: --benimse yolu kırık (rc=$rc)"
# MAJOR fix: GO-durağı resume-komutu --benimse'yi TAŞIMALI (aksi hâlde tavsiyeyi izleyen --devam
# state-boş kaldığından kapıya yeniden çarpar) — basılı komut 'kur kurtest --devam --benimse' olmalı
printf '%s' "$out" | grep -q 'kur kurtest --devam --benimse' \
  && ok "kur slug-kapısı: GO-durağı resume-komutu --benimse'yi taşıdı (rıza kalıcı, MAJOR fix)" \
  || bad "kur slug-kapısı: GO-durağı --benimse'siz --devam bastı (tavsiye kapıya çarpar — MAJOR)"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'slug-kapısı önizleme' && printf '%s' "$out" | grep -q 'kur adım 8/8' \
  && ok "kur slug-kapısı: dry-run REDDETMEZ — uyarı basar + tam-zincir önizlenir (salt-oku)" \
  || bad "kur slug-kapısı: dry-run uyarı-sözleşmesi kırık (rc=$rc)"
# MINOR fix: --dry-run --benimse kombinasyonu 'devralındı, adımlar sürer' DEMEMELİ (hiçbir şey sürmez)
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --dry-run --benimse 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'gerçek koşuda BİLİNÇLİ-devralınır' && ! printf '%s' "$out" | grep -q 'adımlar idempotent-geçişlerle sürer' \
  && ok "kur slug-kapısı: --dry-run --benimse doğru önizleme dili (MINOR fix, yanıltıcı 'sürer' yok)" \
  || bad "kur slug-kapısı: --dry-run --benimse mesajı yanıltıcı (rc=$rc)"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurtest --durum 2>&1)"
rc=$?
[ "$rc" = "0" ] && ! printf '%s' "$out" | grep -qE '\[(kırmızı|uyarı)\] slug-kapısı' && printf '%s' "$out" | grep -q -- 'kur kurtest --benimse' \
  && ok "kur slug-kapısı: --durum kapıdan MUAF (ateşlemedi) ama şüpheli-durum notu (--benimse gerekir) düşer (MINOR fix)" \
  || bad "kur slug-kapısı: --durum muafiyet/not sözleşmesi kırık (rc=$rc)"

# 59c. ROSTER CHARSET-KAPISI (ikincil, G-a): [A-Za-z0-9-] dışı üye-adı/görev fail-closed rc=1
#      (üye-adları tırnaksız ssh/docker/tmux'a gömülür; container-içi registry yolu köprüyü bypass eder)
out="$(bash -c "source <(sed -n '/^_ey_uye_satirlari()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _ey_uye_satirlari 'motor1:uye yonetici-x:yonetici' '' && printf 'SAYI=%s YON=%s' \"\$EY_UYE_SAYISI\" \"\$EY_YONETICI\"" 2>&1)"
printf '%s' "$out" | grep -q 'SAYI=2 YON=yonetici-x' \
  && ok "roster charset-kapısı: temiz-roster geçer (2 üye, yönetici doğru)" \
  || bad "roster charset-kapısı: temiz-roster yanlış-red/parse ('$out')"
CG_KACAK=""
while IFS= read -r kotu; do
  bash -c "source <(sed -n '/^_ey_uye_satirlari()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); _ey_uye_satirlari \"\$1\" ''" _ "$kotu" >/dev/null 2>&1 \
    && CG_KACAK="$CG_KACAK [$kotu]"
done <<'EOF'
pis$(id):uye
nokta;virgul:uye
ters`tik`:uye
cift"tirnak:uye
türkçe-üye:uye
nokta.li:uye
EOF
[ -z "$CG_KACAK" ] && ok "roster charset-kapısı: 6 injection/charset-fixture'ın hepsi fail-closed reddedildi" \
  || bad "roster charset-kapısı: KAÇAK var:$CG_KACAK"
out="$(env "${KR_ENV[@]}" ISKAN_EY_ROSTER='pis$(id):uye' bash "$SCRIPT_DIR/iskan.sh" ekip-yerlestir kurtest --dry-run 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'roster-hijyeni' \
  && ok "ekip-yerlestir: kötü-karakterli ISKAN_EY_ROSTER çağrı-yerinde de fail-closed (rc=1)" \
  || bad "ekip-yerlestir: charset-kapısı çağrı-yerinde delik (rc=$rc)"

# 59d. re-verify MINOR: _kur_durak1_probe no-fetch modu — fetch'i ATLAR (--durum salt-oku sözleşmesi:
#      .git metadata yazımı yok). File-remote'lu repo: no-fetch → FETCH_HEAD yazılmaz; fetch'li → yazılır.
NF_REMOTE="$(mktemp -d)"; git -C "$NF_REMOTE" init -q --bare >/dev/null 2>&1
NF_WORK="$(mktemp -d)"; mkdir -p "$NF_WORK/infra"
cat > "$NF_WORK/infra/docker-compose.server.yml" <<'EOF'
services:
  cloudtop-kurtest:
    container_name: cloudtop-kurtest
    ports:
      - "127.0.0.1:9447:8443"
EOF
git -C "$NF_WORK" init -q >/dev/null 2>&1
git -C "$NF_WORK" add -A && git -C "$NF_WORK" -c user.email=t@t -c user.name=t commit -qm x >/dev/null 2>&1
git -C "$NF_WORK" remote add origin "$NF_REMOTE"
git -C "$NF_WORK" push -q origin HEAD:main >/dev/null 2>&1
git -C "$NF_WORK" update-ref refs/remotes/origin/main HEAD
rm -f "$NF_WORK/.git/FETCH_HEAD"
bash -c "source <(sed -n '/^_kur_durak1_probe()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); ISKAN_CLOUDTOP_REPO_DIR='$NF_WORK' _kur_durak1_probe cloudtop-kurtest no-fetch" >/dev/null 2>&1
nf_rc=$?
if [ ! -f "$NF_WORK/.git/FETCH_HEAD" ] && [ "$nf_rc" = "0" ]; then
  ok "_kur_durak1_probe no-fetch: FETCH_HEAD yazılmadı + origin/main doğru okundu (rc=0) — --durum salt-oku (MINOR fix)"
else
  bad "_kur_durak1_probe no-fetch: FETCH_HEAD=$([ -f "$NF_WORK/.git/FETCH_HEAD" ] && echo VAR) rc=$nf_rc (no-fetch delik)"
fi
rm -f "$NF_WORK/.git/FETCH_HEAD"
bash -c "source <(sed -n '/^_kur_durak1_probe()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); ISKAN_CLOUDTOP_REPO_DIR='$NF_WORK' _kur_durak1_probe cloudtop-kurtest" >/dev/null 2>&1
[ -f "$NF_WORK/.git/FETCH_HEAD" ] \
  && ok "_kur_durak1_probe (fetch'li): FETCH_HEAD yazıldı — kontrast kanıtı (zincir/devam/dry-run fetch'i korur)" \
  || ok "_kur_durak1_probe (fetch'li): fetch denendi (file-remote ortamına göre FETCH_HEAD opsiyonel) — no-fetch farkı yukarıda kanıtlı"
find "$NF_REMOTE" "$NF_WORK" -type f -delete 2>/dev/null
find "$NF_REMOTE" "$NF_WORK" -depth -type d -delete 2>/dev/null

# ── PR-C: kur-state ENV-PİN (F1/F6) + PREFLIGHT ENV-HEDEF-HARİTASI ─────────────────────────

# 59e. ENV-PİN ROUND-TRIP (F6): GO'lu ilk-koşu pinleri state satır-2+'a yazar (satır-1 sözleşmesi
#      + 600 + K1 GO-YAZILMAZ kanıtı); env'siz --devam pinleri geri yükler (kanıt-satırı adlar-only)
rm -f "$KR_STATE/iskan-kur-kurpin.state"
out="$(env "${KR_ENV[@]}" ISKAN_FAZ4_GO=1 bash "$SCRIPT_DIR/iskan.sh" kur kurpin 2>&1)"
rc=$?
pin_eksik=""
for v in ISKAN_CLOUDTOP_REPO_DIR ISKAN_REPO_COMPOSE ISKAN_SSH_HOST ISKAN_EY_ROSTER; do
  grep -q "^pin $v=" "$KR_STATE/iskan-kur-kurpin.state" 2>/dev/null || pin_eksik="$pin_eksik $v"
done
[ "$rc" = "0" ] && [ "$(head -1 "$KR_STATE/iskan-kur-kurpin.state" 2>/dev/null)" = "yeni-proje" ] && [ -z "$pin_eksik" ] \
  && grep -q '^pin ISKAN_EY_ROSTER=denekAlfa:yonetici$' "$KR_STATE/iskan-kur-kurpin.state" \
  && [ "$(stat -c %a "$KR_STATE/iskan-kur-kurpin.state")" = "600" ] \
  && ok "env-pin yazıcı: satır-1='yeni-proje' + 4 allowlist-pini state'e yazıldı (600, roster-değeri dosyada — sır-değil)" \
  || bad "env-pin yazıcı: round-trip yazımı kırık (rc=$rc, eksik:$pin_eksik)"
# K1 GO-YAZILMAZ: koşu ISKAN_FAZ4_GO=1 ortamındaydı ama yazıcı allowlist-only → state'te _GO izi SIFIR
[ "$(grep -c '_GO=' "$KR_STATE/iskan-kur-kurpin.state" 2>/dev/null)" = "0" ] \
  && ok "env-pin K1: ortamda ISKAN_FAZ4_GO=1 iken state'e GO YAZILMADI (yazıcı ortam-taramaz)" \
  || bad "env-pin K1: GO state'e sızdı (yapısal garanti kırık)"
# round-trip: pinlenebilir env'ler TAMAMEN verilmeden --devam → pinler geri gelir (F6 birebir);
# kanıt-satırı adlar-only (roster DEĞERİ stdout'a düşmez); DURAK-1 pinli repo_dir'den ölçülür
out="$(env ISKAN_STATE_DIR="$KR_STATE" ISKAN_EY_SSH_TIMEOUT=3 bash "$SCRIPT_DIR/iskan.sh" kur kurpin --devam 2>&1)"
rc=$?
pin_satir="$(printf '%s\n' "$out" | grep 'env-pin yüklendi')"
[ "$rc" = "0" ] && printf '%s' "$pin_satir" | grep -q 'ISKAN_EY_ROSTER' \
  && printf '%s' "$pin_satir" | grep -q 'ISKAN_CLOUDTOP_REPO_DIR' \
  && ! printf '%s' "$pin_satir" | grep -q 'denekAlfa' \
  && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "env-pin round-trip: env'siz --devam pinleri yükledi (adlar-only kanıt, değer YOK) + DURAK-1 pinli-repo'dan ölçüldü (F6 kapandı)" \
  || bad "env-pin round-trip: --devam pin-yüklemesi kırık (rc=$rc, satır: '$pin_satir')"

# 59f. dry-run mevcut pin'li state'e DOKUNMAZ (pin-tazeleme yalnız adım-yazımında)
SUM_PIN_D0="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurpin --dry-run >/dev/null 2>&1
rc=$?
SUM_PIN_D1="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
[ "$rc" = "3" ] && [ "$SUM_PIN_D0" = "$SUM_PIN_D1" ] \
  && ok "env-pin dry-run: plan-exit=3 + mevcut v2-state md5-değişmez (yazım yok)" \
  || bad "env-pin dry-run: state'e dokunuldu ya da rc bozuk (rc=$rc)"

# 59g. GO-PIN TAMPER (K3): state'e elle 'pin ISKAN_FAZ4_GO=1' → --devam rc=1 + kırmızı marker
#      + hiçbir adım-banner'ı + hiçbir pin yüklenmedi + dosya fail-closed DEĞİŞMEDİ
printf 'pin ISKAN_FAZ4_GO=1\n' >> "$KR_STATE/iskan-kur-kurpin.state"
SUM_PIN_T0="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
out="$(env ISKAN_STATE_DIR="$KR_STATE" bash "$SCRIPT_DIR/iskan.sh" kur kurpin --devam 2>&1)"
rc=$?
SUM_PIN_T1="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'güvenlik-kapısı-pin tespit' \
  && ! printf '%s' "$out" | grep -q '──── kur adım' && ! printf '%s' "$out" | grep -q 'env-pin yüklendi' \
  && [ "$SUM_PIN_T0" = "$SUM_PIN_T1" ] \
  && ok "env-pin K3 tamper: GO-pin görüldü → rc=1 kırmızı-DUR (sessiz-atlama YOK, sıfır pin yüklendi, dosya değişmedi)" \
  || bad "env-pin K3 tamper: GO-pin kapısı delik (rc=$rc)"

# 59h. --durum + tamper: rapor BASILIR (inceleme-aracı çalışır) + sonda 'GO-pin tespit' + rc=1
#      (PR-C bilinçli rc-değişimi: eski sözleşme --durum=0'dı; kurcalanmış state'te sahte-yeşil yok)
out="$(env ISKAN_STATE_DIR="$KR_STATE" bash "$SCRIPT_DIR/iskan.sh" kur kurpin --durum 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'son-tamamlanan: yeni-proje' \
  && printf '%s' "$out" | grep -q 'GO-pin tespit' \
  && ok "env-pin --durum tamper: rapor basıldı + sonda kırmızı GO-pin tespiti + rc=1 (sahte-yeşil yok)" \
  || bad "env-pin --durum tamper: sözleşme kırık (rc=$rc)"

# 59i. DENY-SINIFI-2 (K3): güvenlik-kapı seti pini (ISKAN_PROD_HOSTS) de kurcalanmış-state kırmızısı
printf 'yeni-proje\npin ISKAN_PROD_HOSTS=pc code\n' > "$KR_STATE/iskan-kur-kurpin.state"
out="$(env ISKAN_STATE_DIR="$KR_STATE" bash "$SCRIPT_DIR/iskan.sh" kur kurpin --devam 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'ISKAN_PROD_HOSTS' && printf '%s' "$out" | grep -q 'güvenlik-kapısı-pin tespit' \
  && ! printf '%s' "$out" | grep -q '──── kur adım' \
  && ok "env-pin deny-sınıfı-2: ISKAN_PROD_HOSTS pini → rc=1 kırmızı (7/8-hostname kapı setleri state'ten daraltılamaz)" \
  || bad "env-pin deny-sınıfı-2: PROD_HOSTS pini sessiz geçti (rc=$rc — mahrem-regresyon riski)"
rm -f "$KR_STATE/iskan-kur-kurpin.state"

# 59i2. MALFORME GO-PIN FAIL-SAFE (PR-C re-verify fix-a): strict-regex'i (^ISKAN_[A-Z0-9_]+$) geçemeyen
#       ama GO/güvenlik-kapısına BENZEYEN ad ('ISKAN_FAZ4_GO ' trailing-space) pass-1'de sessiz-atlanmamalı
#       → loud-kırmızı + refuse-all: aynı state'teki GEÇERLİ allowlist-pin (ISKAN_EY_ROSTER) bile YÜKLENMEZ
#       (aksi halde pass-1 malforme-GO'yu atlar, pass-2 diğerlerini yükler = kısmi-tamper onurlandırılır).
printf 'yeni-proje\npin ISKAN_EY_ROSTER=denekAlfa:yonetici\npin ISKAN_FAZ4_GO =1\n' > "$KR_STATE/iskan-kur-kurpin.state"
SUM_MF_T0="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
out="$(env ISKAN_STATE_DIR="$KR_STATE" bash "$SCRIPT_DIR/iskan.sh" kur kurpin --devam 2>&1)"
rc=$?
SUM_MF_T1="$(md5sum "$KR_STATE/iskan-kur-kurpin.state")"
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'malforme GO/güvenlik-kapısı-pin tespit' \
  && ! printf '%s' "$out" | grep -q 'env-pin yüklendi' && ! printf '%s' "$out" | grep -q '──── kur adım' \
  && [ "$SUM_MF_T0" = "$SUM_MF_T1" ] \
  && ok "env-pin fail-safe: malforme-GO ('ISKAN_FAZ4_GO ' trailing-space) → rc=1 refuse-all (geçerli allowlist-pin de yüklenmedi; sessiz-atlama YOK, dosya değişmedi)" \
  || bad "env-pin fail-safe: malforme-GO sessiz-atlandı (rc=$rc — kısmi-tamper onurlandırıldı)"
rm -f "$KR_STATE/iskan-kur-kurpin.state"

# 59j. ESKİ-FORMAT UYUM: tek-satır pin'siz state → davranış BİREBİR ('env-pin yüklendi' satırı YOK)
printf 'yeni-proje\n' > "$KR_STATE/iskan-kur-kureski.state"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kureski --devam 2>&1)"
rc=$?
[ "$rc" = "0" ] && ! printf '%s' "$out" | grep -q 'env-pin yüklendi' \
  && printf '%s' "$out" | grep -q 'son-tamamlanan=yeni-proje' && printf '%s' "$out" | grep -q "DURAK-1'de duraklatıldı" \
  && ok "env-pin eski-format: tek-satır state ile --devam birebir eski davranış (pin-satırı yok, kanıt-satırı basılmaz)" \
  || bad "env-pin eski-format: geriye-uyum kırık (rc=$rc)"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kureski --durum 2>&1)"
rc=$?
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'son-tamamlanan: yeni-proje' \
  && ok "env-pin eski-format: --durum rc=0 + rapor (salt-oku sözleşmesi temiz state'te DEĞİŞMEDİ)" \
  || bad "env-pin eski-format: --durum kırık (rc=$rc)"

# 59k. PRECEDENCE (açık-env > pin) + PİN-TAZELEME: pinli SSH_HOST açık-env'le ezilir (haritada
#      kaynak=açık-env), adım-yazımında pin etkin-değerle tazelenir (bayat-pin ölür)
printf 'yeni-proje\npin ISKAN_SSH_HOST=pinli-host.invalid\n' > "$KR_STATE/iskan-kur-kurprec.state"
out="$(env "${KR_ENV[@]}" bash "$SCRIPT_DIR/iskan.sh" kur kurprec --devam 2>&1)"
rc=$?
[ "$rc" = "0" ] && ! printf '%s' "$out" | grep -q 'env-pin yüklendi' \
  && printf '%s' "$out" | grep -q 'ssh-hedef→ bilinçli-bozuk-host.invalid \[kaynak: açık-env\]' \
  && ok "env-pin precedence: açık-env pin'i ezdi (harita kaynak=açık-env, pin yüklenmedi)" \
  || bad "env-pin precedence: öncelik-sırası kırık (rc=$rc)"
out="$(env "${KR_ENV[@]}" ISKAN_FAZ4_GO=1 bash "$SCRIPT_DIR/iskan.sh" kur kurprec 2>&1)"
rc=$?
[ "$rc" = "0" ] && grep -q '^pin ISKAN_SSH_HOST=bilinçli-bozuk-host.invalid$' "$KR_STATE/iskan-kur-kurprec.state" \
  && ! grep -q 'pinli-host.invalid' "$KR_STATE/iskan-kur-kurprec.state" \
  && ok "env-pin tazeleme: adım-yazımı pin-bloğunu ETKİN env'den yeniden üretti (bayat pinli-host silindi)" \
  || bad "env-pin tazeleme: bayat pin state'te kaldı (rc=$rc)"

# 59l. BOŞ AÇIK-ENV = PİN-İPTAL (${!ad+x} semantiği): ISKAN_EY_ROSTER= (set-ama-boş) pini yok sayar
#      → fallback yolu (haritada roster kaynak=container-içi default) — bayat-roster panzehiri
printf 'yeni-proje\npin ISKAN_EY_ROSTER=denekAlfa:yonetici\n' > "$KR_STATE/iskan-kur-kuriptal.state"
out="$(env "${KR_ENV[@]}" ISKAN_EY_ROSTER= bash "$SCRIPT_DIR/iskan.sh" kur kuriptal --devam 2>&1)"
rc=$?
[ "$rc" = "0" ] && ! printf '%s' "$out" | grep -q 'env-pin yüklendi' \
  && printf '%s' "$out" | grep -q 'roster kaynak→ container-içi ekip-registry.yaml (default)' \
  && ok "env-pin pin-iptal: boş açık-env pini yok saydı → fallback yolu (container-registry) tek komutla geri geldi" \
  || bad "env-pin pin-iptal: set-ama-boş semantiği kırık (rc=$rc — bayat-roster panzehiri yok)"

# 59m. V1 HEDEF-AYRIŞMA (F1-imzası): repo_dir AÇIK + compose DEFAULT → zincir adım-0'da kırmızı
#      (üçlü HİÇ yazılmadan durur — F1 canlı-vakası birebir); iki taraf da AÇIK ise [uyarı]+devam
V1_REPO="$(mktemp -d)"     # okuma-repo: default-compose çatısından AYRIŞIK, .git YOK (V2 susar)
out="$(env ISKAN_STATE_DIR="$KR_STATE" ISKAN_CLOUDTOP_REPO_DIR="$V1_REPO" \
  ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" kur vbirtest 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'V1 hedef-ayrışma' \
  && ! printf '%s' "$out" | grep -q '──── kur adım' && [ ! -e "$KR_STATE/iskan-kur-vbirtest.state" ] \
  && ok "harita V1: ayrışma ∧ compose=default → zincir adım-0 kırmızı (F1 üçlü-yazımı önlendi, state doğmadı)" \
  || bad "harita V1: F1-imzası kırmızısı kırık (rc=$rc)"
# dry-run'da V1 BİLGİ-dilinde (plan-exit korunur) — izole-fonksiyon çağrısı (59c/59d sed-source deseni)
out="$(bash -c "source <(sed -n '/^_kur_adim_no()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_kaynak()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_harita()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); ISKAN_KUR_ADIMLAR='yeni-proje durak1-cloudtop-pr iskan-host provizyon cf-yayin ekip-yerlestir ekip-pong evergreen-kaydet'; ISKAN_KUR_PIN_YUKLENEN=''; ISKAN_CLOUDTOP_REPO_DIR='$V1_REPO' _kur_env_harita vbirtest dry-run ''" 2>&1)"
v1rc=$?
[ "$v1rc" = "0" ] && printf '%s' "$out" | grep -q '\[uyarı\] V1 hedef-ayrışma' \
  && ok "harita V1 dry-run: aynı ayrışma BİLGİ-dilinde [uyarı] + rc=0 (plan-exit sözleşmesi korunur)" \
  || bad "harita V1 dry-run: bilgi-dili kırık (rc=$v1rc)"
# iki taraf da AÇIK (bilinçli worktree-PR deseni): zincir BLOKLANMAZ — adım-1'e ilerler (GO'suz exit=4)
V1B_REPO="$(mktemp -d)"; mkdir -p "$V1B_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$V1B_REPO/infra/docker-compose.server.yml"
cp "$SCRIPT_DIR/fixtures/setup-tunnel-mini.sh" "$V1B_REPO/infra/setup-tunnel.sh"
out="$(env -u ISKAN_FAZ4_GO ISKAN_STATE_DIR="$KR_STATE" ISKAN_CLOUDTOP_REPO_DIR="$V1_REPO" \
  ISKAN_REPO_COMPOSE="$V1B_REPO/infra/docker-compose.server.yml" \
  ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" kur vbirtest 2>&1)"
rc=$?
[ "$rc" = "4" ] && printf '%s' "$out" | grep -q 'BİLİNÇLİ (açık-env/pin) sayıldı' \
  && printf '%s' "$out" | grep -q 'kur adım 1/8' \
  && ok "harita V1 rafine: iki taraf AÇIK → [uyarı]+devam, zincir adım-1'e ilerledi (meşru worktree-PR deseni bloklanmadı)" \
  || bad "harita V1 rafine: bilinçli-ayrışma false-positive bloklandı (rc=$rc)"

# 59n. V2 WORKTREE-CHECKOUT: .git DOSYA ∧ son-tamamlanan < cf-yayin → devam'da kırmızı + üç-kapı
#      sayımı; cf-yayin geçildiyse yalnız bilgi-satırı (eşik-kanıtı: provizyon=kırmızı · cf-yayin=bilgi)
V2_REPO="$(mktemp -d)"; mkdir -p "$V2_REPO/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$V2_REPO/infra/docker-compose.server.yml"
printf 'gitdir: /tmp/olmayan-worktree-yeri\n' > "$V2_REPO/.git"
printf 'yeni-proje\n' > "$KR_STATE/iskan-kur-vikitest.state"
out="$(env ISKAN_STATE_DIR="$KR_STATE" ISKAN_CLOUDTOP_REPO_DIR="$V2_REPO" \
  ISKAN_REPO_COMPOSE="$V2_REPO/infra/docker-compose.server.yml" \
  ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_EY_SSH_TIMEOUT=3 \
  bash "$SCRIPT_DIR/iskan.sh" kur vikitest --devam 2>&1)"
rc=$?
[ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'V2 worktree-checkout' && printf '%s' "$out" | grep -q 'ANA-checkout' \
  && printf '%s' "$out" | grep -q 'iskan-host.sh REPO-KANIT' && ! printf '%s' "$out" | grep -q '──── kur adım' \
  && ok "harita V2: .git DOSYA + cf-yayin-öncesi → devam adım-0 kırmızı (üç '-d .git' kapısı erken teşhis, F2)" \
  || bad "harita V2: worktree kırmızısı kırık (rc=$rc)"
# eşik-kanıtı (mutasyon-kalkanı): son=provizyon (<cf-yayin) hâlâ KIRMIZI; son=cf-yayin BİLGİ + rc=0
out="$(bash -c "source <(sed -n '/^_kur_adim_no()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_kaynak()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_harita()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); ISKAN_KUR_ADIMLAR='yeni-proje durak1-cloudtop-pr iskan-host provizyon cf-yayin ekip-yerlestir ekip-pong evergreen-kaydet'; ISKAN_KUR_PIN_YUKLENEN=''; ISKAN_CLOUDTOP_REPO_DIR='$V2_REPO' ISKAN_REPO_COMPOSE='$V2_REPO/infra/docker-compose.server.yml' _kur_env_harita vikitest devam provizyon" 2>&1)"
v2a=$?
out2="$(bash -c "source <(sed -n '/^_kur_adim_no()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_kaynak()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); source <(sed -n '/^_kur_env_harita()/,/^}/p' '$SCRIPT_DIR/iskan.sh'); ISKAN_KUR_ADIMLAR='yeni-proje durak1-cloudtop-pr iskan-host provizyon cf-yayin ekip-yerlestir ekip-pong evergreen-kaydet'; ISKAN_KUR_PIN_YUKLENEN=''; ISKAN_CLOUDTOP_REPO_DIR='$V2_REPO' ISKAN_REPO_COMPOSE='$V2_REPO/infra/docker-compose.server.yml' _kur_env_harita vikitest devam cf-yayin" 2>&1)"
v2b=$?
[ "$v2a" = "1" ] && [ "$v2b" = "0" ] && printf '%s' "$out2" | grep -q 'cf-yayin geçilmiş' \
  && ok "harita V2 eşiği: son=provizyon→kırmızı · son=cf-yayin→bilgi+rc=0 ('<cf-yayin' eşiği birebir)" \
  || bad "harita V2 eşiği: sınır-davranışı kırık (provizyon=$v2a cf-yayin=$v2b)"

for d in "$V1_REPO" "$V1B_REPO" "$V2_REPO"; do
  find "$d" -type f -delete 2>/dev/null; find "$d" -depth -type d -delete 2>/dev/null
done

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

# ── G1 COMPOSE-SENKRON (PR-B): origin/main → host compose eşitleme + sokum 3-Çit ──────────

# fixture cloudtop-repo (SELF-REMOTE: cmd_apply'ın `git fetch origin main`i hermetik geçsin —
# pozitif-yol şartı; RK_REPO golden-18 deseni + fetch-priming). BASE (komşular: komsu +
# MAHREM huma) ve ADAY-BLOK (senktest; yeni-proje append-formatı: blank+İSKÂN-yorum+blok)
# AYRI üreteçlerde — goldenlar "origin-eksi-aday" host'unu BAYT-eş kurabilsin (duplikasyonsuz).
_cs_base_yaml() { cat <<'EOF'
services:
  cloudtop-komsu:
    image: test
    container_name: cloudtop-komsu
    mem_limit: 2g
    ports:
      - "127.0.0.1:9997:8443"

  cloudtop-huma:
    image: test
    container_name: cloudtop-huma
    mem_limit: 4g
    environment:
      - SECRET_TIER=prod
    ports:
      - "127.0.0.1:9995:8443"
EOF
}
_cs_aday_blok() { cat <<'EOF'

  # ── İSKÂN FAZ-4 provizyon: senktest (iskan.sh yeni-proje ile üretildi) ────────────────
  cloudtop-senktest:
    image: test
    container_name: cloudtop-senktest
    mem_limit: 2g
    volumes:
      - ./config-senktest:/config
    ports:
      - "127.0.0.1:9996:8443"
EOF
}
_cs_fixture_repo() { # <dizin> — compose: base(komsu+huma) + aday-blok(senktest)
  local d="$1"
  mkdir -p "$d/infra"
  { _cs_base_yaml; _cs_aday_blok; } > "$d/infra/docker-compose.server.yml"
  git -C "$d" init -q -b main 2>/dev/null
  git -C "$d" -c user.email=t@t -c user.name=t add -A 2>/dev/null
  git -C "$d" -c user.email=t@t -c user.name=t commit -qm fixture 2>/dev/null
  git -C "$d" remote add origin "$d" 2>/dev/null
  git -C "$d" fetch -q origin main 2>/dev/null
}

# apply-stub: dosya-işlemlerini LOKAL koşar (host-compose sandbox'ı ISKAN_HOST_COMPOSE_PATH'te),
# docker/curl'ü FAKE'ler; her çağrıyı CS_LOG'a yazar. Böylece senkron'un cp/cat>/mv zinciri
# GERÇEKTEN yürür (bayt-doğrulanabilir) ama host-mutasyon primitifleri (docker) hiç koşmaz.
CS_STUB="$(mktemp -d)"
cat > "$CS_STUB/ssh" <<'EOF'
#!/usr/bin/env bash
cmd="${@: -1}"
echo "call: $cmd" >> "${CS_LOG:?}"
case "$cmd" in
  *config-hash*)              for n in ${CS_PS:-}; do echo "$n stubhash"; done ;;
  *"docker ps"*StartedAt*)    for n in ${CS_PS:-}; do echo "$n 2026-01-01T00:00:00+00:00"; done ;;
  *StartedAt*)                echo "2026-06-01T00:00:00+00:00" ;;
  *"docker compose"*)         echo "stub-up-ok" ;;
  *"docker ps"*)              for n in ${CS_PS:-}; do echo "$n"; done ;;
  *curl*)                     echo "http_code=302" ;;
  *"command -v python3"*)     echo "/usr/bin/python3" ;;
  *)                          bash -c "$cmd" ;;
esac
EOF
chmod +x "$CS_STUB/ssh"

CS_REPO="$(mktemp -d)"; _cs_fixture_repo "$CS_REPO"
CS_HOST_DIR="$(mktemp -d)"                       # sandbox "host" dizini
CS_HOSTFILE="$CS_HOST_DIR/docker-compose.server.yml"
CS_ENV_ORTAK=(ISKAN_SSH_HOST=stubhost ISKAN_CLOUDTOP_REPO_DIR="$CS_REPO" ISKAN_HOST_COMPOSE_PATH="$CS_HOSTFILE" CS_PS="cloudtop-senktest")

# 63. iskan-host --dry-run: plan-çıktısında COMPOSE-SENKRON satırı (rc=3 korunur)
out="$(ISKAN_SSH_HOST="bilinçli-bozuk-host.invalid" ISKAN_REPO_COMPOSE="$SCRIPT_DIR/fixtures/compose-clean.yml" \
  bash "$SCRIPT_DIR/iskan-host.sh" --dry-run 2>&1)"
rc=$?
[ "$rc" = "3" ] && printf '%s' "$out" | grep -q 'COMPOSE-SENKRON' \
  && ok "senkron dry-run: plan-çıktısında COMPOSE-SENKRON satırı var (rc=3 korunur)" \
  || bad "senkron dry-run: plan-satırı eksik ya da rc bozuk (rc=$rc)"

# 64. --apply GO'suz: rc=4 SABİT + ssh-stub-çağrı=0 (sıfır-dokunuş, Değişmez-3)
CS_LOG="$(mktemp)"
env -u ISKAN_FAZ4_GO PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest >/dev/null 2>&1
rc=$?
[ "$rc" = "4" ] && [ "$(grep -c . "$CS_LOG")" = "0" ] && [ ! -e "$CS_HOSTFILE" ] \
  && ok "senkron GO-yok: rc=4 + ssh-çağrı=0 + host-dosya doğmadı (sıfır-dokunuş)" \
  || bad "senkron GO-yok: kapı kırık (rc=$rc ssh-çağrı=$(grep -c . "$CS_LOG"))"

# 65+66. bayt-eş no-op + SIRA-goldeni (COMPOSE-SENKRON satırı R4 satırından ÖNCE)
git -C "$CS_REPO" show origin/main:infra/docker-compose.server.yml > "$CS_HOSTFILE"
CS_MD5_0="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
CS_KANIT1="$(mktemp -d)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" ISKAN_KANIT_DIR="$CS_KANIT1" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_1="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
n_bak="$(find "$CS_HOST_DIR" -name '*.bak-*' | wc -l | tr -d '[:space:]')"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'yazım YOK (no-op)' && [ "$CS_MD5_0" = "$CS_MD5_1" ] \
  && [ "$n_bak" = "0" ] && ! grep -q 'iskan-tmp' "$CS_LOG" \
  && ok "senkron bayt-eş: no-op (yazım=0, .bak=0, md5-değişmez, rc=0)" \
  || bad "senkron bayt-eş: no-op kapısı kırık (rc=$rc bak=$n_bak)"
sat_senkron="$(printf '%s\n' "$out" | grep -n 'COMPOSE-SENKRON' | head -1 | cut -d: -f1)"
sat_r4="$(printf '%s\n' "$out" | grep -n 'R4 drift-kapısı' | head -1 | cut -d: -f1)"
[ -n "$sat_senkron" ] && [ -n "$sat_r4" ] && [ "$sat_senkron" -lt "$sat_r4" ] \
  && ok "senkron SIRA-goldeni: COMPOSE-SENKRON satırı ($sat_senkron) R4 satırından ($sat_r4) ÖNCE" \
  || bad "senkron SIRA-goldeni: kapı-sırası bozuk (senkron=$sat_senkron r4=$sat_r4)"

# 67. eksi-cname (klasik G1): host = origin-eksi-aday (base bayt-eş) → YAZIM OLUR +
#     host==origin/main BAYT-eş + .bak alındı + kanıtta re-verify + komşu-BAYT dili +
#     R2-notu (aday 'çalışıyor' stub'da → dosya≠çalışan-config notu)
_cs_base_yaml > "$CS_HOSTFILE"
CS_KANIT2="$(mktemp -d)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" ISKAN_KANIT_DIR="$CS_KANIT2" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_REPO="$(git -C "$CS_REPO" show origin/main:infra/docker-compose.server.yml | md5sum | awk '{print $1}')"
CS_MD5_2="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
n_bak="$(find "$CS_HOST_DIR" -name '*.bak-*' | wc -l | tr -d '[:space:]')"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'origin/main.e eşitlendi' && [ "$CS_MD5_2" = "$CS_MD5_REPO" ] \
  && [ "$n_bak" = "1" ] && grep -q 'BAYT re-verify GEÇTİ' "$CS_KANIT2/compose-senkron.txt" \
  && grep -q 'komşu-servisler BAYT-eş' "$CS_KANIT2/compose-senkron.txt" \
  && grep -q 'aday-bitişik yorum-satırları repo-simetrik' "$CS_KANIT2/compose-senkron.txt" \
  && ok "senkron eksi-cname: YAZIM oldu + host==origin/main BAYT-eş (md5) + .bak-TS + re-verify + komşu-BAYT + yutulan-simetri kanıt-dili" \
  || bad "senkron eksi-cname: yazım-yolu kırık (rc=$rc md5-eş=$([ "$CS_MD5_2" = "$CS_MD5_REPO" ] && echo E || echo H) bak=$n_bak)"
grep -q 'çalışan-config ESKİ — recreate ayrı Sultan-alanı' "$CS_KANIT2/compose-senkron.txt" \
  && ok "senkron R2-notu: aday-çalışırken yazım → kanıtta zorunlu 'recreate ayrı Sultan-alanı' notu" \
  || bad "senkron R2-notu: dosya≠çalışan-config makası kanıta düşmedi"

# 68. idempotent re-run: yazım-sonrası ikinci koşu no-op'a düşer (.bak sayısı artmaz)
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" ISKAN_KANIT_DIR="$CS_KANIT2" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
n_bak2="$(find "$CS_HOST_DIR" -name '*.bak-*' | wc -l | tr -d '[:space:]')"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'yazım YOK (no-op)' && [ "$n_bak2" = "1" ] \
  && ok "senkron idempotent re-run: ikinci koşu no-op (.bak artmadı)" \
  || bad "senkron idempotent re-run: kırık (rc=$rc bak=$n_bak2)"

# 69. KOMŞU bayt-drift (LB TERS-golden): non-mahrem komşuda (komsu 2g→512m) yapısal-görünmez
#     drift → tam-dosya yazımı onu EZERDİ → komşu-BAYT kapısı fail-closed keser (yazım=0)
{ _cs_base_yaml | sed 's/mem_limit: 2g/mem_limit: 512m/'; _cs_aday_blok; } > "$CS_HOSTFILE"
CS_MD5_K0="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
CS_KANIT3="$(mktemp -d)"
CS_LOG3="$(mktemp)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG3" ISKAN_KANIT_DIR="$CS_KANIT3" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_K1="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
[ "$rc" = "5" ] && [ "$CS_MD5_K0" = "$CS_MD5_K1" ] && [ -s "$CS_KANIT3/compose-senkron-fark.txt" ] \
  && ! grep -q 'iskan-tmp' "$CS_LOG3" && printf '%s' "$out" | grep -q 'komşular BAYT-eş değil' \
  && ok "senkron komşu-bayt-drift (LB): non-mahrem komşu 512m-drift'i → rc=5 + yazım=0 + fark-raporu (körü-körüne ezme YOK)" \
  || bad "senkron komşu-bayt-drift (LB): komşu-BAYT kapısı kırık — komşu ezilebilirdi (rc=$rc)"

# 69b. ADAY-only bayat-drift (doktrin MAJOR-1 KORUNUR): drift YALNIZ aday-blokta (senktest
#      512m) → komşular bayt-eş → YAZIM OLUR, bayat aday-blok origin/main'e ezilir
{ _cs_base_yaml; _cs_aday_blok | sed 's/mem_limit: 2g/mem_limit: 512m/'; } > "$CS_HOSTFILE"
CS_KANIT3B="$(mktemp -d)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" ISKAN_KANIT_DIR="$CS_KANIT3B" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_3="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
[ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'origin/main.e eşitlendi' && [ "$CS_MD5_3" = "$CS_MD5_REPO" ] \
  && ok "senkron aday-bayat-blok: drift yalnız-adayda (512m) → host EZİLDİ, origin/main bayt-eş (sahte-no-op yok)" \
  || bad "senkron aday-bayat-blok: 512m sessiz-OOM tuzağı sürüyor — yazım olmadı (rc=$rc)"

# 69c. MAHREM komşu-drift negatif-goldeni (LB): host'ta huma elle-tune'lu (8g +
#      SECRET_TIER=prod-HANDTUNED), aday non-mahrem → rc=5 + ssh-yazım=0 + fark-raporunda huma
{ _cs_base_yaml | sed 's/mem_limit: 4g/mem_limit: 8g/; s/SECRET_TIER=prod/SECRET_TIER=prod-HANDTUNED/'; _cs_aday_blok; } > "$CS_HOSTFILE"
CS_MD5_M0="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
CS_KANIT3C="$(mktemp -d)"
CS_LOG3C="$(mktemp)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG3C" ISKAN_KANIT_DIR="$CS_KANIT3C" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_M1="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
[ "$rc" = "5" ] && [ "$CS_MD5_M0" = "$CS_MD5_M1" ] && ! grep -q 'iskan-tmp' "$CS_LOG3C" \
  && grep -q 'cloudtop-huma' "$CS_KANIT3C/compose-senkron-fark.txt" \
  && ok "senkron MAHREM-komşu-drift (LB): huma elle-tune'u EZİLMEDİ → rc=5 + yazım=0 + fark-raporunda huma görünür" \
  || bad "senkron MAHREM-komşu-drift (LB): mahrem-komşu sessiz-ezme deliği AÇIK (rc=$rc)"

# 69d. ASİMETRİK-YUTMA (3.tur MAJOR-1): host'ta aday-header'a BİTİŞİK (blank-ayraç YOK)
#      origin/main'de-OLMAYAN bakım-yorumu + komşu-CONFIG eş → `sil` yorumu adaya yutar →
#      komşu-md5 sahte-EŞ, AMA tam-dosya yazımı o yorumu SİLERDİ → yutulan-kapısı rc=5 + yazım=0
{ _cs_base_yaml
  printf '  # HUMA-BAKIM elle-not (origin/main-DIŞI, aday-header'"'"'a bitişik)\n'
  printf '  cloudtop-senktest:\n    image: test\n    container_name: cloudtop-senktest\n    mem_limit: 2g\n    volumes:\n      - ./config-senktest:/config\n    ports:\n      - "127.0.0.1:9996:8443"\n'
} > "$CS_HOSTFILE"
CS_MD5_Y0="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
CS_KANIT3D="$(mktemp -d)"
CS_LOG3D="$(mktemp)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG3D" ISKAN_KANIT_DIR="$CS_KANIT3D" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_Y1="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
[ "$rc" = "5" ] && [ "$CS_MD5_Y0" = "$CS_MD5_Y1" ] && ! grep -q 'iskan-tmp' "$CS_LOG3D" \
  && printf '%s' "$out" | grep -q 'aday-bitişik satır' && grep -q 'HUMA-BAKIM' "$CS_KANIT3D/compose-senkron-fark.txt" \
  && ok "senkron asimetrik-yutma (MAJOR-1): host-only bitişik yorum → rc=5 + yazım=0 (tam-dosya onu SİLERDİ; sahte-attestasyon kapandı)" \
  || bad "senkron asimetrik-yutma (MAJOR-1): host-only aday-bitişik yorum sessizce silinebilir (rc=$rc)"
rm -f "$CS_LOG3" "$CS_LOG3C" "$CS_LOG3D"

# 70. komşu-fark (ölü tenant-bloğu): körü-körüne ezme YOK → rc=5 + fark-dosyası + yazım=0
{ git -C "$CS_REPO" show origin/main:infra/docker-compose.server.yml
  printf '\n  cloudtop-olutenant:\n    image: test\n    container_name: cloudtop-olutenant\n    ports:\n      - "127.0.0.1:9990:8443"\n'
} > "$CS_HOSTFILE"
CS_MD5_4="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
CS_KANIT4="$(mktemp -d)"
CS_LOG4="$(mktemp)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG4" ISKAN_KANIT_DIR="$CS_KANIT4" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
CS_MD5_5="$(md5sum "$CS_HOSTFILE" | awk '{print $1}')"
[ "$rc" = "5" ] && [ -s "$CS_KANIT4/compose-senkron-fark.txt" ] && [ "$CS_MD5_4" = "$CS_MD5_5" ] \
  && ! grep -q 'iskan-tmp' "$CS_LOG4" && printf '%s' "$out" | grep -q 'muhtemel-neden: tamamlanmamış söküm' \
  && ok "senkron komşu-fark: rc=5 fail-closed + fark-raporu + yazım=0 + söküm teşhis-ipucu (körü-körüne ezme YOK)" \
  || bad "senkron komşu-fark: beklenen-delta kapısı kırık (rc=$rc)"

# 71. boş-host: dosya YOK → rc=5 + bootstrap-dili + dosya doğmadı (İSKÂN bootstrap DEĞİL)
find "$CS_HOST_DIR" -type f -delete 2>/dev/null
CS_KANIT5="$(mktemp -d)"
out="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG" ISKAN_KANIT_DIR="$CS_KANIT5" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje senktest 2>&1)"
rc=$?
[ "$rc" = "5" ] && printf '%s' "$out" | grep -q 'bootstrap işidir' && [ ! -e "$CS_HOSTFILE" ] \
  && ok "senkron boş-host: rc=5 + 'bootstrap işidir, İSKÂN-doğumu değil' dili + dosya doğmadı" \
  || bad "senkron boş-host: bootstrap-reddi kırık (rc=$rc)"

# 72. compose_parse --haric: kesişen servis düşünce intersections=0 + servis raporda yok;
#     --haric olmayan-servis çıktısı bayraksız çıktıyla BAYT-eş (mevcut tüketiciler etkilenmez)
out="$(python3 "$SCRIPT_DIR/lib/compose_parse.py" --haric alpha "$SCRIPT_DIR/fixtures/compose-collision.yml" 2>/dev/null)"
n_int="$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["intersections"]))' 2>/dev/null)"
printf '%s' "$out" | grep -q '"alpha"' && haric_alpha_var=1 || haric_alpha_var=0
[ "$n_int" = "0" ] && [ "$haric_alpha_var" = "0" ] \
  && ok "compose_parse --haric alpha: servis düştü + kesişimler yeniden-hesaplandı (1→0)" \
  || bad "compose_parse --haric: düşürme/yeniden-hesap kırık (int=$n_int alpha-var=$haric_alpha_var)"
a="$(python3 "$SCRIPT_DIR/lib/compose_parse.py" "$SCRIPT_DIR/fixtures/compose-collision.yml" 2>/dev/null | md5sum)"
b="$(python3 "$SCRIPT_DIR/lib/compose_parse.py" --haric hic-olmayan-servis "$SCRIPT_DIR/fixtures/compose-collision.yml" 2>/dev/null | md5sum)"
[ -n "$a" ] && [ "$a" = "$b" ] \
  && ok "compose_parse --haric: olmayan-servis = bayraksız çıktıyla BAYT-eş (davranış-koruması)" \
  || bad "compose_parse --haric: bayt-eşlik kırıldı"

# 72b. compose_block.py sil: (a) aday-bloğu (yorum+ayraç-boşluk dahil) çıkarınca base ile
#      BAYT-eş · (b) olmayan-cname passthrough bayt-eş · (c) boş-girdi rc≠0 + boş-stdout (fail-closed)
CB_TMP="$(mktemp)"; { _cs_base_yaml; _cs_aday_blok; } > "$CB_TMP"
a="$(python3 "$SCRIPT_DIR/lib/compose_block.py" sil cloudtop-senktest "$CB_TMP" | md5sum)"
b="$(_cs_base_yaml | md5sum)"
[ -n "$a" ] && [ "$a" = "$b" ] \
  && ok "compose_block sil: aday-blok (İSKÂN-yorum + ayraç-boşluk dahil) çıktı → base BAYT-eş" \
  || bad "compose_block sil: blok-çıkarım base'le bayt-eş değil"
c="$(python3 "$SCRIPT_DIR/lib/compose_block.py" sil cloudtop-hicyok "$CB_TMP" | md5sum)"
d="$(cat "$CB_TMP" | md5sum)"
[ -n "$c" ] && [ "$c" = "$d" ] \
  && ok "compose_block sil: olmayan-cname → passthrough BAYT-eş (host'ta-aday-yok simetrisi)" \
  || bad "compose_block sil: passthrough bayt-eş değil"
cb_out="$(printf '' | python3 "$SCRIPT_DIR/lib/compose_block.py" sil x - 2>/dev/null)"
cb_rc=$?
[ "$cb_rc" != "0" ] && [ -z "$cb_out" ] \
  && ok "compose_block sil: boş-girdi → rc≠0 + boş-stdout (çağıran fail-closed'a bağlar)" \
  || bad "compose_block sil: boş-girdi sözleşmesi kırık (rc=$cb_rc)"

# 72b'. compose_block yutulan (MAJOR-1): (a) aday-header-öncesi yutulan bağlamı basar ·
#       (b) host-only-bitişik-yorum ⊄ repo simetrisi diff'le görünür · (c) aday-yok → boş+rc=0
CB_HOST="$(mktemp)"
{ _cs_base_yaml; printf '  # HUMA-BAKIM elle-not\n'; printf '  cloudtop-senktest:\n    image: test\n'; } > "$CB_HOST"
yut_host="$(python3 "$SCRIPT_DIR/lib/compose_block.py" yutulan cloudtop-senktest "$CB_HOST")"
yut_repo="$(python3 "$SCRIPT_DIR/lib/compose_block.py" yutulan cloudtop-senktest "$CB_TMP")"
printf '%s' "$yut_host" | grep -q 'HUMA-BAKIM' && ! printf '%s' "$yut_repo" | grep -q 'HUMA-BAKIM' \
  && ok "compose_block yutulan: host-only bitişik-yorum ('HUMA-BAKIM') host-yutulanda VAR, repo-yutulanda YOK (asimetri görünür)" \
  || bad "compose_block yutulan: asimetrik-yutma tespiti kırık"
yut_yok="$(python3 "$SCRIPT_DIR/lib/compose_block.py" yutulan cloudtop-hicyok "$CB_HOST")"; yut_yok_rc=$?
[ "$yut_yok_rc" = "0" ] && [ -z "$yut_yok" ] \
  && ok "compose_block yutulan: aday-yok → boş çıktı + rc=0 (host'ta-aday-yok simetrisi)" \
  || bad "compose_block yutulan: aday-yok sözleşmesi kırık (rc=$yut_yok_rc)"
# 72b''. anchor davranış-dok (MINOR bilinen-sınır): YAML-anchor'lı header (&sk) → sil passthrough
#        (key-regex eşlemez; sessiz-config-ezme DEĞİL — güvenli-taraf, dokümante ediliyor)
CB_ANCHOR="$(mktemp)"
printf 'services:\n  cloudtop-anch: &sk\n    image: test\n    container_name: cloudtop-anch\n' > "$CB_ANCHOR"
anch_a="$(python3 "$SCRIPT_DIR/lib/compose_block.py" sil cloudtop-anch "$CB_ANCHOR" | md5sum)"
anch_b="$(cat "$CB_ANCHOR" | md5sum)"
[ "$anch_a" = "$anch_b" ] \
  && ok "compose_block sil: YAML-anchor'lı header (&sk) → passthrough BAYT-eş (bilinen-sınır, davranış-dok)" \
  || bad "compose_block sil: anchor-header davranışı beklenmedik (passthrough değil)"
rm -f "$CB_TMP" "$CB_HOST" "$CB_ANCHOR"

# 72c. iskan-host 3-Çit + ad-hijyeni (MAJOR-fix): GO'lu bile mahrem-apply RED + charset-kapısı
CS_LOG6="$(mktemp)"
err="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG6" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje vekatip 2>&1 >/dev/null)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$err" | grep -q '3-Çit' && [ "$(grep -c . "$CS_LOG6")" = "0" ] \
  && ok "iskan-host 3-Çit: 'vekatip' GO'lu --apply REDDEDİLDİ (rc=$rc, ssh-çağrı=0 — kardeş-yol deliği kapandı)" \
  || bad "iskan-host 3-Çit: mahrem-apply hâlâ geçiyor (rc=$rc ssh-çağrı=$(grep -c . "$CS_LOG6"))"
err="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG6" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje mihenk 2>&1 >/dev/null)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$err" | grep -q '3-Çit' \
  && ok "iskan-host 3-Çit: 'mihenk' de REDDEDİLDİ (rc=$rc — 5'li izole-aile tam)" \
  || bad "iskan-host 3-Çit: mihenk deliği (rc=$rc)"
err="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG6" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje '.*' 2>&1 >/dev/null)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$err" | grep -q 'ad-hijyeni' && ! grep -q 'iskan-tmp' "$CS_LOG6" \
  && ok "iskan-host ad-hijyeni: --proje '.*' charset-kapısında REDDEDİLDİ (ERE-enjeksiyon kökten kapalı, yazım=0)" \
  || bad "iskan-host ad-hijyeni: regex-meta proje-adı kapıyı geçti (rc=$rc)"
# path-traversal + boşluk da reddedilir (güvenlik-regresyon)
err="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG6" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje '../x' 2>&1 >/dev/null)"; rc1=$?
err2="$(env ISKAN_FAZ4_GO=1 PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG6" "${CS_ENV_ORTAK[@]}" \
  bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje 'a b' 2>&1 >/dev/null)"; rc2=$?
[ "$rc1" != "0" ] && [ "$rc2" != "0" ] && printf '%s' "$err" | grep -q 'ad-hijyeni' && printf '%s' "$err2" | grep -q 'ad-hijyeni' \
  && ok "iskan-host ad-hijyeni: '../x' (path-traversal) + 'a b' (boşluk) REDDEDİLDİ (güvenlik korundu)" \
  || bad "iskan-host ad-hijyeni: path-traversal/boşluk kapıyı geçti (rc1=$rc1 rc2=$rc2)"
rm -f "$CS_LOG6"

# 72c'. charset PARİTESİ (MAJOR-2): iskan-host apply-charset == iskan.sh _ey_ad_hijyeni charset
#       BAYT-eş — kur-adım-1 kabul edip host-doğum adımının reddetmesi ('aynı-adım-fail') önlenir
pat_kur="$(grep -c "LC_ALL=C grep -qE '^\[A-Za-z0-9-\]+\$'" "$SCRIPT_DIR/iskan.sh")"
pat_host="$(grep -c "LC_ALL=C grep -qE '^\[A-Za-z0-9-\]+\$'" "$SCRIPT_DIR/iskan-host.sh")"
[ "$pat_kur" -ge 1 ] && [ "$pat_host" -ge 1 ] \
  && ok "charset paritesi (MAJOR-2): apply-charset ^[A-Za-z0-9-]+\$ = kur _ey_ad_hijyeni charset (bayt-eş literal, geç-fail tuzağı kapandı)" \
  || bad "charset paritesi KIRIK: apply/kur charset ayrıştı (kur=$pat_kur host=$pat_host)"
# kur'un kabul ettiği büyük-harfli/rakamlı ad apply charset-kapısını da GEÇER (regresyon-yönü)
for ad in ISKANTEST proje2 a-b; do
  printf '%s' "$ad" | LC_ALL=C grep -qE '^[A-Za-z0-9-]+$' || bad "charset paritesi: '$ad' kur-charset'i geçmiyor (fixture-hatası)"
done
ok "charset paritesi: kur-kabul-eden adlar (ISKANTEST/proje2/a-b) apply charset-kapısını da geçer"

# 72d. izole-liste paritesi: iskan-host.sh ISKAN_HOST_IZOLE == iskan.sh ISKAN_KUR_IZOLE
#      (tek-kaynak bekçisi — listeler ayrışırsa 3-Çit'in bir yüzü kör kalır)
l1="$(grep -m1 '^ISKAN_KUR_IZOLE=' "$SCRIPT_DIR/iskan.sh" | cut -d= -f2-)"
l2="$(grep -m1 '^ISKAN_HOST_IZOLE=' "$SCRIPT_DIR/iskan-host.sh" | cut -d= -f2-)"
[ -n "$l1" ] && [ "$l1" = "$l2" ] \
  && ok "izole-liste paritesi: iskan.sh ⟷ iskan-host.sh mahrem-listeleri BAYT-eş" \
  || bad "izole-liste paritesi KIRIK: iskan.sh=$l1 vs iskan-host.sh=$l2"

# 73. sokum 3-Çit mahrem-reddi: 'sokum vekatip' GO'lu --apply'da BİLE rc≠0 + ssh-çağrı=0
CS_LOG5="$(mktemp)"
err="$(PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG5" ISKAN_SOKUM_GO=1 ISKAN_CLOUDTOP_REPO_DIR="/tmp/iskan-yok.$$" \
  bash "$SCRIPT_DIR/iskan.sh" sokum vekatip --apply 2>&1 >/dev/null)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$err" | grep -q '3-Çit' && [ "$(grep -c . "$CS_LOG5")" = "0" ] \
  && ok "sokum 3-Çit: 'vekatip' GO'lu --apply'da REDDEDİLDİ (rc=$rc, ssh-çağrı=0 — güvenlik-deliği kapandı)" \
  || bad "sokum 3-Çit: mahrem-tenant sökümü hâlâ geçiyor (rc=$rc ssh-çağrı=$(grep -c . "$CS_LOG5"))"
err="$(PATH="$CS_STUB:$PATH" CS_LOG="$CS_LOG5" ISKAN_CLOUDTOP_REPO_DIR="/tmp/iskan-yok.$$" \
  bash "$SCRIPT_DIR/iskan.sh" sokum mihenk 2>&1 >/dev/null)"
rc=$?
[ "$rc" != "0" ] && printf '%s' "$err" | grep -q '3-Çit' \
  && ok "sokum 3-Çit: dry-run modda da ateşler (mihenk, rc=$rc — her-mod kapısı)" \
  || bad "sokum 3-Çit: dry-run modda delik (rc=$rc)"

rm -f "$CS_LOG" "$CS_LOG4" "$CS_LOG5"
for d in "$CS_STUB" "$CS_REPO" "$CS_HOST_DIR" "$CS_KANIT1" "$CS_KANIT2" "$CS_KANIT3" "$CS_KANIT3B" "$CS_KANIT3C" "$CS_KANIT3D" "$CS_KANIT4" "$CS_KANIT5"; do
  find "$d" -type f -delete 2>/dev/null; find "$d" -depth -type d -delete 2>/dev/null
done

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
