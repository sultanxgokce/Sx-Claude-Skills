#!/usr/bin/env bash
# cloudflare-erisim golden-testleri — TAMAMEN OFFLINE (PATH-shim curl-stub; gerçek CF'e SIFIR istek).
# Odak: cmd_offboard sözleşmesi (v1.2.0): korumalı-liste literal-çekirdek + yalnız-ekleme env'ler ·
# per-yarı ≤1-assertion + zaten-yok idempotans · Access tamlık-kapısı · fail-closed delete ·
# çok-pozisyonel reddi · sır-hijyeni. Desen: iskan.test.sh (hermetik, fixture-tabanlı, ok/FAIL sayaç).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CF_SH="$SCRIPT_DIR/cf.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
iddia(){ local ad="$1"; shift; if "$@"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ FAIL: $ad"; fi }

# ── curl-stub (PATH-shim): URL desenine göre fixture basar, her çağrıyı METHOD+URL loglar ──
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/curl" <<'EOS'
#!/usr/bin/env bash
method="GET"; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -H|-d) shift 2 ;;
    -sS|-s|-S) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s %s\n' "$method" "$url" >> "${CURL_LOG:?}"
case "$method|$url" in
  GET\|*"/access/apps?per_page="*)        cat "${FIX_APPS:?}" ;;
  GET\|*"/dns_records?type=CNAME&name="*) cat "${FIX_DNS:?}" ;;
  DELETE\|*"/access/apps/"*)              cat "${FIX_DEL_APP:?}" ;;
  DELETE\|*"/dns_records/"*)              cat "${FIX_DEL_DNS:?}" ;;
  GET\|*"/zones?name="*)                  cat "${FIX_ZONES:-/dev/null}" 2>/dev/null || echo '{"success":true,"result":[]}' ;;
  *) echo '{"success":true,"result":[]}' ;;
esac
EOS
chmod +x "$STUB/curl"

# ── fixture'lar ────────────────────────────────────────────────────────────────
FIX="$TMP/fix"; mkdir -p "$FIX"
cat > "$FIX/apps-1.json" <<'EOF'
{"success":true,"result":[
  {"id":"APPX","domain":"baska-app.mmepanel.com","name":"baska"},
  {"id":"APP1","domain":"iskantest.mmepanel.com","name":"iskantest"}
],"result_info":{"total_count":2,"per_page":100}}
EOF
cat > "$FIX/apps-0.json" <<'EOF'
{"success":true,"result":[{"id":"APPX","domain":"baska-app.mmepanel.com","name":"baska"}],"result_info":{"total_count":1,"per_page":100}}
EOF
cat > "$FIX/apps-2.json" <<'EOF'
{"success":true,"result":[
  {"id":"APP1","domain":"iskantest.mmepanel.com","name":"a"},
  {"id":"APP2","domain":"iskantest.mmepanel.com","name":"b"}
],"result_info":{"total_count":2,"per_page":100}}
EOF
cat > "$FIX/apps-150.json" <<'EOF'
{"success":true,"result":[{"id":"APPX","domain":"baska-app.mmepanel.com","name":"baska"}],"result_info":{"total_count":150,"per_page":100}}
EOF
cat > "$FIX/apps-nototal.json" <<'EOF'
{"success":true,"result":[{"id":"APP1","domain":"iskantest.mmepanel.com","name":"iskantest"}]}
EOF
cat > "$FIX/dns-1.json" <<'EOF'
{"success":true,"result":[{"id":"REC1","type":"CNAME","name":"iskantest.mmepanel.com","content":"T1.cfargotunnel.com","proxied":true}],"result_info":{"total_count":1}}
EOF
cat > "$FIX/dns-0.json" <<'EOF'
{"success":true,"result":[],"result_info":{"total_count":0}}
EOF
cat > "$FIX/dns-2.json" <<'EOF'
{"success":true,"result":[
  {"id":"REC1","type":"CNAME","name":"iskantest.mmepanel.com","content":"T1.cfargotunnel.com"},
  {"id":"REC2","type":"CNAME","name":"iskantest.mmepanel.com","content":"T2.cfargotunnel.com"}
],"result_info":{"total_count":2}}
EOF
printf '{"success":true,"result":{"id":"X"}}\n'                      > "$FIX/ok.json"
printf '{"success":false,"errors":[{"message":"stub-DELETE-hatasi"}]}\n' > "$FIX/fail.json"

# ── sahte kimlik/cache (sır-değeri FAKE; gerçek sır YOK) ───────────────────────
FAKE_ENV="$TMP/access.env"
printf 'export CLOUDFLARE_API_TOKEN=FAKE-TOKEN-XYZ\n' > "$FAKE_ENV"; chmod 600 "$FAKE_ENV"
FAKE_CACHE="$TMP/cf-cache.json"
printf '{"zone_name":"mmepanel.com","zone_id":"Z1","account_id":"A1","tunnel_id":"T1"}\n' > "$FAKE_CACHE"

CIKTI="$TMP/cikti.txt"; LOG="$TMP/curl.log"; TUM_CIKTILAR="$TMP/tum-ciktilar.txt"; : > "$TUM_CIKTILAR"

cf_kos(){  # cf_kos [EK_ENV=deger ...] -- <cf.sh argümanları...>  → rc; çıktı $CIKTI, curl-log $LOG
  local -a ek=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do ek+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  : > "$LOG"
  env PATH="$STUB:$PATH" CURL_LOG="$LOG" \
    CORTEX_ACCESS_ENV="$FAKE_ENV" CF_CACHE="$FAKE_CACHE" VAULT_CEK_BIN="$TMP/yok" \
    FIX_APPS="${FIX_APPS:-$FIX/apps-1.json}" FIX_DNS="${FIX_DNS:-$FIX/dns-1.json}" \
    FIX_DEL_APP="${FIX_DEL_APP:-$FIX/ok.json}" FIX_DEL_DNS="${FIX_DEL_DNS:-$FIX/ok.json}" \
    "${ek[@]}" \
    bash "$CF_SH" "$@" > "$CIKTI" 2>&1
  local rc=$?
  cat "$CIKTI" >> "$TUM_CIKTILAR"; cat "$LOG" >> "$TUM_CIKTILAR"
  return $rc
}
del_say(){ grep -c '^DELETE ' "$LOG" 2>/dev/null || true; }

echo "== cloudflare-erisim golden-testleri (offline) =="

# T1 · sözdizim
bash -n "$CF_SH"; iddia "T1 bash -n cf.sh" [ $? -eq 0 ]

# T2 · korumalı-ÇEKİRDEK reddi (mahrem + kök örneklemi) — apply'da bile sıfır-dokunuş
for h in huma.mmepanel.com mihenk.mmepanel.com vekatip.mmepanel.com mmepanel.com; do
  cf_kos -- offboard "$h" --apply; rc=$?
  iddia "T2 çekirdek-RED rc≠0 ($h)" [ $rc -ne 0 ]
  iddia "T2 çekirdek-RED mesaj ($h)" grep -q 'REDDEDİLDİ' "$CIKTI"
  iddia "T2 çekirdek-RED DELETE=0 ($h)" [ "$(del_say)" = "0" ]
done

# T3 · sert-kapı KAYDIRILAMAZ: CF_ZONE_NAME=evil.com iken çekirdek YİNE korur
cf_kos CF_ZONE_NAME=evil.com -- offboard huma.mmepanel.com --apply; rc=$?
iddia "T3 evil-zone rc≠0" [ $rc -ne 0 ]
iddia "T3 evil-zone REDDEDİLDİ" grep -q 'REDDEDİLDİ' "$CIKTI"
iddia "T3 evil-zone DELETE=0" [ "$(del_say)" = "0" ]

# T4 · eski CF_OFFBOARD_PROTECTED artık DARALTAMAZ (yalnız-ekleme): çekirdek korunur + eklenen de korunur
cf_kos CF_OFFBOARD_PROTECTED=legacy.mmepanel.com -- offboard huma.mmepanel.com --apply; rc=$?
iddia "T4 legacy-var çekirdeği daraltamaz" [ $rc -ne 0 ]
cf_kos CF_OFFBOARD_PROTECTED=legacy.mmepanel.com -- offboard legacy.mmepanel.com --apply; rc=$?
iddia "T4 legacy-var yine-de EKLER" [ $rc -ne 0 ]

# T5 · CF_OFFBOARD_PROTECTED_EXTRA ekler
cf_kos CF_OFFBOARD_PROTECTED_EXTRA=ozel.mmepanel.com -- offboard ozel.mmepanel.com --apply; rc=$?
iddia "T5 EXTRA-koruma rc≠0" [ $rc -ne 0 ]
iddia "T5 EXTRA-koruma DELETE=0" [ "$(del_say)" = "0" ]

# T6 · dry-run DEFAULT (1/1): plan basar, hiçbir DELETE yok
cf_kos -- offboard iskantest.mmepanel.com; rc=$?
iddia "T6 dry-run rc=0" [ $rc -eq 0 ]
iddia "T6 dry-run KURU-ÇALIŞMA" grep -q 'KURU-ÇALIŞMA' "$CIKTI"
iddia "T6 dry-run DELETE=0" [ "$(del_say)" = "0" ]

# T7 · apply mutlu-yol: 2 DELETE, sıra access→dns (merge'li davranış korunur), OFFBOARD-SONUC
cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T7 apply rc=0" [ $rc -eq 0 ]
iddia "T7 apply DELETE=2" [ "$(del_say)" = "2" ]
acc_satir="$(grep -n '^DELETE .*access/apps/' "$LOG" | head -1 | cut -d: -f1)"
dns_satir="$(grep -n '^DELETE .*dns_records/' "$LOG" | head -1 | cut -d: -f1)"
iddia "T7 apply sıra access→dns" [ -n "$acc_satir" ] && [ -n "$dns_satir" ] && [ "$acc_satir" -lt "$dns_satir" ]
iddia "T7 OFFBOARD-SONUC silindi×2" grep -q '^OFFBOARD-SONUC: access=silindi dns=silindi$' "$CIKTI"

# T8 · idempotans çift-zaten-yok: apply'da bile rc=0 + DELETE=0 (söküm re-run güvenliği)
FIX_APPS="$FIX/apps-0.json" FIX_DNS="$FIX/dns-0.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T8 çift-zaten-yok rc=0" [ $rc -eq 0 ]
iddia "T8 çift-zaten-yok DELETE=0" [ "$(del_say)" = "0" ]
iddia "T8 OFFBOARD-SONUC zaten-yok×2" grep -q '^OFFBOARD-SONUC: access=zaten-yok dns=zaten-yok$' "$CIKTI"
FIX_APPS="$FIX/apps-0.json" FIX_DNS="$FIX/dns-0.json" cf_kos -- offboard iskantest.mmepanel.com; rc=$?
iddia "T8b dry-run zaten-yok planı rc=0" [ $rc -eq 0 ]
iddia "T8b dry-run zaten-yok satırı" grep -q 'zaten-yok' "$CIKTI"

# T9 · yarım-kalmış re-run: access zaten-yok + dns var → yalnız DNS silinir
FIX_APPS="$FIX/apps-0.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T9 yarım-re-run rc=0" [ $rc -eq 0 ]
iddia "T9 yarım-re-run DELETE=1" [ "$(del_say)" = "1" ]
iddia "T9 yalnız-DNS DELETE" grep -q '^DELETE .*dns_records/' "$LOG"
iddia "T9 OFFBOARD-SONUC karışık" grep -q '^OFFBOARD-SONUC: access=zaten-yok dns=silindi$' "$CIKTI"

# T10 · >1 kayıt → DUR (toplu-silme ASLA) — iki yarı simetrik
FIX_APPS="$FIX/apps-2.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T10 access>1 rc≠0" [ $rc -ne 0 ]
iddia "T10 access>1 assertion-mesajı" grep -q '≤1-assertion' "$CIKTI"
iddia "T10 access>1 DELETE=0" [ "$(del_say)" = "0" ]
FIX_DNS="$FIX/dns-2.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T10 dns>1 rc≠0" [ $rc -ne 0 ]
iddia "T10 dns>1 DELETE=0" [ "$(del_say)" = "0" ]

# T11 · tamlık-kapısı: total_count>per_page ya da okunamıyor → DUR (unknown ≠ yok)
FIX_APPS="$FIX/apps-150.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T11 total=150 rc≠0" [ $rc -ne 0 ]
iddia "T11 total=150 TAM-değil mesajı" grep -q 'TAM değil' "$CIKTI"
iddia "T11 total=150 DELETE=0" [ "$(del_say)" = "0" ]
FIX_APPS="$FIX/apps-nototal.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T11 total-yok rc≠0" [ $rc -ne 0 ]
iddia "T11 total-yok kanıtlanamadı-mesajı" grep -q 'tamlığı kanıtlanamadı' "$CIKTI"
iddia "T11 total-yok DELETE=0" [ "$(del_say)" = "0" ]

# T12 · DELETE-fail fail-closed: access-DELETE düşerse DNS'e DOKUNULMAZ
FIX_DEL_APP="$FIX/fail.json" cf_kos -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T12 delete-fail rc≠0" [ $rc -ne 0 ]
iddia "T12 delete-fail DNS-dokunulmadı" [ "$(grep -c '^DELETE .*dns_records/' "$LOG" || true)" = "0" ]

# T13 · çok-pozisyonel sessiz-ezme kapalı: iki hostname → usage-die, sıfır-dokunuş
cf_kos -- offboard alfa.mmepanel.com beta.mmepanel.com --apply; rc=$?
iddia "T13 çok-pozisyonel rc≠0" [ $rc -ne 0 ]
iddia "T13 çok-pozisyonel mesaj" grep -q 'birden fazla hostname' "$CIKTI"
iddia "T13 çok-pozisyonel DELETE=0" [ "$(del_say)" = "0" ]

# T14 · zone-yok fail-closed: cache'te zone_id boş + Zone-Read'siz keşif → DNS-yarısı doğrulanamaz → DUR
FAKE_CACHE2="$TMP/cf-cache-zonesuz.json"
printf '{"zone_name":"mmepanel.com","zone_id":"","account_id":"","tunnel_id":""}\n' > "$FAKE_CACHE2"
FAKE_ENV2="$TMP/access2.env"
printf 'export CLOUDFLARE_API_TOKEN=FAKE-TOKEN-XYZ\nexport CF_ACCOUNT_ID=A1\n' > "$FAKE_ENV2"; chmod 600 "$FAKE_ENV2"
FIX_ZONES_DOSYA="$FIX/zones-bos.json"
printf '{"success":true,"result":[]}\n' > "$FIX_ZONES_DOSYA"
cf_kos CF_CACHE="$FAKE_CACHE2" CORTEX_ACCESS_ENV="$FAKE_ENV2" FIX_ZONES="$FIX_ZONES_DOSYA" -- offboard iskantest.mmepanel.com --apply; rc=$?
iddia "T14 zone-yok rc≠0" [ $rc -ne 0 ]
iddia "T14 zone-yok mesaj" grep -q 'zone_id çözülemedi' "$CIKTI"
iddia "T14 zone-yok DELETE=0" [ "$(del_say)" = "0" ]

# T15 · sır-hijyeni: hiçbir test-çıktısında/curl-log'unda token-değeri geçmedi
iddia "T15 sır-hijyeni (FAKE-TOKEN 0 kez)" [ "$(grep -c 'FAKE-TOKEN-XYZ' "$TUM_CIKTILAR" || true)" = "0" ]

echo "== ${PASS} geçti · ${FAIL} düştü =="
[ "$FAIL" -eq 0 ]
