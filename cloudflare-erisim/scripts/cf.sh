#!/usr/bin/env bash
# cloudtop · Cloudflare erişim CLI — Access app + DNS işlerini PANELE GİRMEDEN, API ile yap.
# ─────────────────────────────────────────────────────────────────────────────
# NEDEN: Ajan "cloudflare erişimi gereken bir iş" istediğinde her seferinde Sultan'ın
# dashboard'a girip Access app / DNS / token oluşturması ANGARYA. Bu CLI o işi tek-sefer
# giriş + kalıcı-token ile ajana devreder.
#
# GERÇEK KISIT (dürüstlük): Cloudflare'ın "kullanıcı-adı+şifre → token" API'si YOKTUR
# (dashboard girişi 2FA/CAPTCHA arkasında). Kullanılabilir tek "ana giriş" = Global API Key
# (My Profile → API Tokens → Global API Key → View) ya da hazır bir API Token.
#
# AKIŞ (bir kerelik):  login → mint → (artık ajan) → onboard/do-work → save
#   login  : email + Global API Key'i GİZLİ oku, doğrula, env'e yaz (600).
#   mint   : Global Key ile DAR-YETKİLİ token ÜRET (Zone.DNS + Account.Access), token'ı sakla,
#            Global Key'i UNUT (yalnız least-privilege token kalır). "Sen token oluştur" = bu.
#   onboard: <host> için Access self-hosted app + Allow-policy + proxied DNS (tümü idempotent).
#
# Sır-hijyeni: DEĞER asla stdout'a/log'a/geçmişe düşmez; yalnız ~/.config/cortex-access.env (600).
# Kanonik pointer: Nexus/_agents/credentials.yaml. cloudflared GEREKMEZ (saf curl+jq).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

CF_API="https://api.cloudflare.com/client/v4"
ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
CACHE="${CF_CACHE:-$HOME/.cache/cloudflare-access.json}"          # sır DEĞİL (sadece ID'ler)
ZONE_NAME="${CF_ZONE_NAME:-mmepanel.com}"
TUNNEL_NAME="${CF_TUNNEL_NAME:-cloudtop}"
DEFAULT_EMAIL="${CF_ALLOW_EMAIL:-sultanxgokce@gmail.com}"          # Access policy: kime izin
PROTECTED_DNS_ONLY="cloudtop.${ZONE_NAME}"                         # ASLA proxied/route etme (SSH/Mutagen kopar)
MINTED_TOKEN_NAME="${CF_TOKEN_NAME:-cloudtop-agent}"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*"; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl yok"
command -v jq   >/dev/null 2>&1 || die "jq yok"

# ── kimlik yükleme (DEĞERİ EKRANA BASMADAN) ─────────────────────────────────
load_creds(){
  if [ -f "$ENV_FILE" ]; then
    set -a
    # yalnız CLOUDFLARE_* satırlarını source et
    . <(grep -E '^export (CLOUDFLARE_(API_TOKEN|EMAIL|API_KEY)|CF_ACCOUNT_ID)=' "$ENV_FILE" 2>/dev/null) || true
    set +a
  fi
}

have_any_cred(){ [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { [ -n "${CLOUDFLARE_EMAIL:-}" ] && [ -n "${CLOUDFLARE_API_KEY:-}" ]; }; }

# ── curl sarmalayıcı: token > global-key ────────────────────────────────────
api(){  # api <METHOD> <path> [json-data]
  local method="$1" path="$2" data="${3:-}"
  local -a H=(-sS -X "$method" -H "Content-Type: application/json")
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    H+=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
  elif [ -n "${CLOUDFLARE_EMAIL:-}" ] && [ -n "${CLOUDFLARE_API_KEY:-}" ]; then
    H+=(-H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}")
  fi
  if [ -n "$data" ]; then curl "${H[@]}" -d "$data" "${CF_API}${path}"
  else curl "${H[@]}" "${CF_API}${path}"; fi
}
ok(){ echo "$1" | jq -e '.success == true' >/dev/null 2>&1; }
errs(){ echo "$1" | jq -r '.errors[]? | "    - \(.message)\(if .error_chain then " ("+(.error_chain|map(.message)|join("; "))+")" else "" end)"' 2>/dev/null; }

# ── env'e sır yaz (dup'ı çıkar, 600, DEĞER görünmez) ────────────────────────
put_env(){  # put_env KEY VALUE
  local key="$1" val="$2" tmp
  mkdir -p "$(dirname "$ENV_FILE")"; touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  tmp="$(mktemp)"
  grep -v -E "^export ${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  printf 'export %s=%s\n' "$key" "$val" >> "$tmp"
  mv "$tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"
}
del_env(){ local key="$1" tmp; [ -f "$ENV_FILE" ] || return 0; tmp="$(mktemp)"; grep -v -E "^export ${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true; mv "$tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"; }

# ── ID keşfi (zone/account/tunnel) → cache ──────────────────────────────────
discover(){
  load_creds
  have_any_cred || die "kimlik yok. Önce: bash $0 login  (ya da set-token)"
  local z zid="" aid="" t tid=""
  # zone lookup — token'da Zone-Read varsa hem zone_id hem account_id verir.
  z="$(api GET "/zones?name=${ZONE_NAME}")"
  if ok "$z"; then
    zid="$(echo "$z" | jq -r '.result[0].id // empty')"
    aid="$(echo "$z" | jq -r '.result[0].account.id // empty')"
  fi
  # Zone-Read YOKSA (account-scoped token) → account_id'yi env'den al (CF_ACCOUNT_ID; sır değil).
  [ -n "$aid" ] || aid="${CF_ACCOUNT_ID:-}"
  [ -n "$aid" ] || die "account_id çözülemedi — Zone-Read yok. Ver: echo 'export CF_ACCOUNT_ID=<id>' >> $ENV_FILE"
  # tünel (DNS-ensure hedefi) — Tunnel-Read yoksa boş; Access işleri etkilenmez.
  t="$(api GET "/accounts/${aid}/cfd_tunnel?name=${TUNNEL_NAME}&is_deleted=false")"
  ok "$t" && tid="$(echo "$t" | jq -r '.result[0].id // empty')" || tid=""
  ZONE_ID="$zid"; ACCOUNT_ID="$aid"; TUNNEL_ID="$tid"
  jq -n --arg zn "$ZONE_NAME" --arg z "$zid" --arg a "$aid" --arg t "$tid" \
    '{zone_name:$zn, zone_id:$z, account_id:$a, tunnel_id:$t}' > "$CACHE"
  chmod 600 "$CACHE"
}
load_ctx(){
  load_creds
  if [ -f "$CACHE" ]; then
    ZONE_ID="$(jq -r '.zone_id // empty' "$CACHE")"
    ACCOUNT_ID="$(jq -r '.account_id // empty' "$CACHE")"
    TUNNEL_ID="$(jq -r '.tunnel_id // empty' "$CACHE")"
  fi
  [ -n "${ACCOUNT_ID:-}" ] && [ -n "${ZONE_ID:-}" ] || discover
}

# ═══ komutlar ═══════════════════════════════════════════════════════════════

cmd_login(){  # bir-kerelik: email + Global API Key GİZLİ oku → doğrula → kaydet
  echo "Cloudflare Global API Key ile giriş (bir kerelik). Anahtar: dash.cloudflare.com → My Profile"
  echo "→ API Tokens → 'Global API Key' → View. Girdiler GİZLİ (ekrana/geçmişe düşmez)."
  local email key
  read -rp  'Cloudflare e-posta: ' email
  read -rsp 'Global API Key    : ' key; echo
  [ -n "$email" ] && [ -n "$key" ] || die "email/key boş"
  CLOUDFLARE_EMAIL="$email"; CLOUDFLARE_API_KEY="$key"; CLOUDFLARE_API_TOKEN=""
  local u; u="$(api GET "/user")"
  ok "$u" || { red "✗ giriş doğrulanamadı:"; errs "$u"; exit 1; }
  put_env CLOUDFLARE_EMAIL "$email"
  put_env CLOUDFLARE_API_KEY "$key"
  unset key
  grn "✓ giriş doğrulandı: $(echo "$u" | jq -r '.result.email')  → $ENV_FILE (600)"
  echo "  Sıradaki (önerilen):  bash $0 mint    # dar-yetkili token üret, ana anahtarı bırak"
}

cmd_set_token(){  # alternatif: hazır API Token'ı GİZLİ yapıştır
  echo "Hazır Cloudflare API Token yapıştır (gizli). Yoksa 'login' + 'mint' kullan."
  local tok; read -rsp 'API Token: ' tok; echo
  [ -n "$tok" ] || die "boş token"
  put_env CLOUDFLARE_API_TOKEN "$tok"; unset tok
  grn "✓ token kaydedildi → $ENV_FILE (600). Doğrula: bash $0 doctor"
}

cmd_mint(){  # Global Key ile DAR-YETKİLİ token üret → sakla → Global Key'i unut
  load_creds
  [ -n "${CLOUDFLARE_EMAIL:-}" ] && [ -n "${CLOUDFLARE_API_KEY:-}" ] || die "mint için Global API Key gerek (önce: login)"
  discover
  echo "İzin grupları çözülüyor..."
  local pg dns_w acc_w acc_r
  pg="$(api GET "/user/tokens/permission_groups")"
  ok "$pg" || { red "✗ permission_groups alınamadı:"; errs "$pg"; exit 1; }
  dns_w="$(echo "$pg" | jq -r '.result[] | select(.name=="DNS Write") | .id' | head -1)"
  acc_w="$(echo "$pg" | jq -r '.result[] | select(.name=="Access: Apps and Policies Write") | .id' | head -1)"
  acc_r="$(echo "$pg" | jq -r '.result[] | select(.name=="Access: Organizations, Identity Providers, and Groups Read") | .id' | head -1)"
  [ -n "$dns_w" ] || die "'DNS Write' izin grubu bulunamadı (Global Key gerçekten global mi?)"
  [ -n "$acc_w" ] || die "'Access: Apps and Policies Write' izin grubu bulunamadı"
  local body
  body="$(jq -n \
    --arg name "$MINTED_TOKEN_NAME" \
    --arg zone "com.cloudflare.api.account.zone.${ZONE_ID}" \
    --arg acct "com.cloudflare.api.account.${ACCOUNT_ID}" \
    --arg dnsw "$dns_w" --arg accw "$acc_w" --arg accr "$acc_r" '
    { name:$name,
      policies:[
        { effect:"allow", resources:{ ($zone):"*" }, permission_groups:[ {id:$dnsw} ] },
        { effect:"allow", resources:{ ($acct):"*" },
          permission_groups:( [ {id:$accw} ] + (if $accr=="" then [] else [ {id:$accr} ] end) ) }
      ] }')"
  local resp val
  resp="$(api POST "/user/tokens" "$body")"
  ok "$resp" || { red "✗ token üretilemedi:"; errs "$resp"; exit 1; }
  val="$(echo "$resp" | jq -r '.result.value // empty')"
  [ -n "$val" ] || die "token değeri boş döndü"
  put_env CLOUDFLARE_API_TOKEN "$val"; unset val
  # least-privilege: Global Key'i artık sakLAMA (token her işi yapar)
  del_env CLOUDFLARE_API_KEY
  ylw "• Global API Key env'den SİLİNDİ (yalnız dar-yetkili token kalır = güvenli)."
  grn "✓ dar-yetkili token üretildi ve saklandı: '${MINTED_TOKEN_NAME}' → $ENV_FILE (600)"
  # taze token ile bağlamı yeniden çöz
  unset CLOUDFLARE_API_KEY; CLOUDFLARE_API_TOKEN=""; load_creds; discover >/dev/null 2>&1 || true
  echo "  Doğrula: bash $0 doctor"
}

cmd_doctor(){
  load_creds
  if ! have_any_cred; then
    red "✗ Cloudflare kimliği YOK ($ENV_FILE)"
    echo "  Bir kerelik giriş:  bash $0 login   →   bash $0 mint"
    echo "  (Ya da hazır token:  bash $0 set-token)"
    echo "  Token/anahtar Sultan'ın Mac'inde de var: cloudflare-api-token (credentials.yaml:100)."
    exit 1
  fi
  local mode="Global API Key"; [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && mode="scoped API Token"
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    # Account-owned token (cfat_ öneki) → /accounts/{id}/tokens/verify; User token → /user/tokens/verify.
    local vpath="/user/tokens/verify"
    case "$CLOUDFLARE_API_TOKEN" in
      cfat_*) vpath="/accounts/${CF_ACCOUNT_ID:-}/tokens/verify" ;;
    esac
    local v; v="$(api GET "$vpath")"
    ok "$v" && echo "$v" | jq -e '.result.status=="active"' >/dev/null 2>&1 \
      || { red "✗ token aktif değil/geçersiz:"; errs "$v"; exit 1; }
  fi
  grn "✓ kimlik geçerli ($mode)"
  discover
  [ -n "${ZONE_ID:-}" ] && grn "✓ zone   : ${ZONE_NAME}  (${ZONE_ID})" \
    || ylw "• zone   : (Zone-Read yok — Access işleri account_id ile çalışır; DNS'i host'ta setup-tunnel.sh yapar)"
  grn "✓ account: ${ACCOUNT_ID}"
  [ -n "${TUNNEL_ID:-}" ] && grn "✓ tünel  : ${TUNNEL_NAME}  (${TUNNEL_ID})" \
    || ylw "• tünel '${TUNNEL_NAME}' API'de görünmüyor (DNS-ensure için tünel-id gerek; setup-tunnel.sh host'ta)"
  # yetenek probu (best-effort)
  local a; a="$(api GET "/accounts/${ACCOUNT_ID}/access/apps?per_page=1")"
  ok "$a" && grn "✓ Access API: okunuyor (app oluşturma ilk kullanımda doğrulanır)" \
    || ylw "• Access API okunamadı — token 'Access: Apps and Policies' yetkisi eksik olabilir"
  echo; echo "Hazır. Örn:  bash $0 onboard mmex.mmepanel.com"
}

cmd_access_ensure(){  # <hostname> [email] [label]  — idempotent
  local host="${1:-}" email="${2:-$DEFAULT_EMAIL}" label="${3:-}"
  [ -n "$host" ] || die "kullanım: access-ensure <hostname> [email] [label]"
  [ -n "$label" ] || label="$host"
  load_ctx
  local apps app_id
  apps="$(api GET "/accounts/${ACCOUNT_ID}/access/apps")"
  ok "$apps" || { red "✗ Access app listesi alınamadı:"; errs "$apps"; exit 1; }
  app_id="$(echo "$apps" | jq -r --arg d "$host" '.result[]? | select(.domain==$d) | .id' | head -1)"
  if [ -n "$app_id" ]; then
    ylw "• Access app zaten var: $host  ($app_id)"
  else
    local body resp
    body="$(jq -n --arg n "$label" --arg d "$host" \
      '{name:$n, domain:$d, type:"self_hosted", session_duration:"24h", app_launcher_visible:true, auto_redirect_to_identity:false}')"
    resp="$(api POST "/accounts/${ACCOUNT_ID}/access/apps" "$body")"
    ok "$resp" || { red "✗ Access app oluşturulamadı:"; errs "$resp"; exit 1; }
    app_id="$(echo "$resp" | jq -r '.result.id // empty')"
    grn "✓ Access app oluşturuldu: $host  ($app_id)"
  fi
  # Allow-<email> policy var mı?
  local pols hit
  pols="$(api GET "/accounts/${ACCOUNT_ID}/access/apps/${app_id}/policies")"
  hit="$(echo "$pols" | jq -r --arg e "$email" '.result[]? | select(.decision=="allow") | .include[]?.email.email // empty' 2>/dev/null | grep -Fx "$email" || true)"
  if [ -n "$hit" ]; then
    ylw "• Policy zaten var: Allow $email"
  else
    local pbody presp
    pbody="$(jq -n --arg e "$email" '{name:("Allow "+$e), decision:"allow", precedence:1, include:[{email:{email:$e}}]}')"
    presp="$(api POST "/accounts/${ACCOUNT_ID}/access/apps/${app_id}/policies" "$pbody")"
    ok "$presp" || { red "✗ policy eklenemedi:"; errs "$presp"; exit 1; }
    grn "✓ Policy: Allow $email"
  fi
}

cmd_dns_ensure(){  # <hostname>  — proxied CNAME → tünel; idempotent
  local host="${1:-}"
  [ -n "$host" ] || die "kullanım: dns-ensure <hostname>"
  [ "$host" != "$PROTECTED_DNS_ONLY" ] || die "REDDEDİLDİ: $host DNS-only (gri) kalmalı — proxied/route SSH/Mutagen'i koparır."
  load_ctx
  [ -n "${TUNNEL_ID:-}" ] || die "tünel '${TUNNEL_NAME}' id'si yok — doctor çalıştır / tünel host'ta kurulu mu?"
  local target="${TUNNEL_ID}.cfargotunnel.com"
  local recs rid content proxied
  recs="$(api GET "/zones/${ZONE_ID}/dns_records?type=CNAME&name=${host}")"
  ok "$recs" || { red "✗ DNS kaydı sorgulanamadı:"; errs "$recs"; exit 1; }
  rid="$(echo "$recs" | jq -r '.result[0].id // empty')"
  if [ -n "$rid" ]; then
    content="$(echo "$recs" | jq -r '.result[0].content')"
    proxied="$(echo "$recs" | jq -r '.result[0].proxied')"
    if [ "$content" = "$target" ] && [ "$proxied" = "true" ]; then
      ylw "• DNS zaten doğru: $host → tünel (proxied)"
    else
      ylw "• DNS kaydı FARKLI (content=$content, proxied=$proxied) — GÜVENLİK: dokunmuyorum."
      echo "    Elle kontrol et; kasıtlıysa dashboard'dan güncelle."
    fi
  else
    local body resp
    body="$(jq -n --arg n "$host" --arg c "$target" '{type:"CNAME", name:$n, content:$c, proxied:true, ttl:1}')"
    resp="$(api POST "/zones/${ZONE_ID}/dns_records" "$body")"
    ok "$resp" || { red "✗ DNS oluşturulamadı:"; errs "$resp"; exit 1; }
    grn "✓ DNS: $host → tünel (proxied CNAME)"
  fi
}

cmd_onboard(){  # <hostname> [email] — Access app + policy + DNS (asıl iş)
  local host="${1:-}" email="${2:-$DEFAULT_EMAIL}"
  [ -n "$host" ] || die "kullanım: onboard <hostname> [email]"
  cmd_access_ensure "$host" "$email"
  # dns_ensure tünel yoksa die eder → subshell ile izole et (Access app zaten oluştu, onboard sertçe düşmesin).
  ( cmd_dns_ensure "$host" ) || ylw "• DNS adımı atlandı (tünel-id API'de yok → host'ta setup-tunnel.sh route ekler)."
  grn "✓ onboard tamam: $host"
  echo "  ⚠️ Tünel INGRESS (hostname→localhost:PORT) HOST'taki /etc/cloudflared/config.yml'de → setup-tunnel.sh ekler."
}

cmd_list(){
  load_ctx
  echo "Access apps (${ZONE_NAME}):"
  api GET "/accounts/${ACCOUNT_ID}/access/apps" | jq -r '.result[]? | "  • \(.domain)   [\(.name)]   \(.id)"' 2>/dev/null || echo "  (okunamadı)"
}

cmd_help(){ sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-doctor}" in
  login)         cmd_login ;;
  mint)          cmd_mint ;;
  set-token)     cmd_set_token ;;
  doctor|verify) cmd_doctor ;;
  access-ensure) shift; cmd_access_ensure "$@" ;;
  dns-ensure)    shift; cmd_dns_ensure "$@" ;;
  onboard)       shift; cmd_onboard "$@" ;;
  list)          cmd_list ;;
  help|-h|--help) cmd_help ;;
  *) die "bilinmeyen komut: $1  (login|mint|set-token|doctor|onboard <host>|access-ensure|dns-ensure|list)" ;;
esac
