#!/usr/bin/env bash
# cloudtop · Railway erişim CLI — proje/servis/DB işlerini PANELE GİRMEDEN, GraphQL API ile yap.
# ─────────────────────────────────────────────────────────────────────────────
# NEDEN: Ajan "Railway erişimi gereken bir iş" (proje/servis listesi, DATABASE_URL alma, deploy
# durumu, ham GraphQL) istediğinde her seferinde Sultan'ın dashboard'a girmesi ANGARYA. Bu CLI o
# işi tek-sefer token girişi + kalıcı env ile ajana devreder.
#
# GERÇEK KISIT (dürüstlük): Railway'in "kullanıcı-adı+şifre → token" API'si YOKTUR. Kalıcı token'lar
# YALNIZ dashboard'da (railway.com/account/tokens, login+2FA arkasında) elle üretilir; geniş kimlikten
# dar token türeten belgelenmiş public mutation da YOK → skill token ÜRETEMEZ/DARALTAMAZ, doğru-kapsamlı
# token'ı kullanıcıdan BİR KEZ hazır alır. (`railway login --browserless` bir device-pairing akışıdır →
# taşınabilir API token değil, CLI yerel oturum anahtarı üretir; headless'ta işe yaramaz.)
#
# TOKEN TÜRLERİ (least-privilege dardan genişe):
#   PROJECT   → tek proje+ortam · header `Project-Access-Token` · env RAILWAY_TOKEN
#   WORKSPACE → tek workspace'in tüm projeleri · header `Authorization: Bearer` · env RAILWAY_API_TOKEN
#   ACCOUNT   → tüm workspace+kaynaklar · header `Authorization: Bearer` · env RAILWAY_API_TOKEN
# Bu skill'in ağırlığı ham GraphQL API işi → WORKSPACE/ACCOUNT (Bearer) ana yol; PROJECT ikincil.
# (İkisini birlikte export ETME — öncelik belirsiz → set-token her zaman diğerini siler.)
#
# Sır-hijyeni: DEĞER asla stdout'a/log'a/geçmişe düşmez; yalnız ~/.config/cortex-access.env (600).
# Kanonik pointer: Nexus/_agents/credentials.yaml. railway CLI GEREKMEZ (saf curl+jq).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

RAILWAY_GQL="${RAILWAY_GQL_ENDPOINT:-https://backboard.railway.com/graphql/v2}"
ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*"; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl yok"
command -v jq   >/dev/null 2>&1 || die "jq yok"

# ── VAULT-FIRST: sırrı ÖNCE merkezî vault'tan tazele (vault-cek seam · değer-basmaz) ────────
# vault-cek get <KEY> → cortex-access.env'e (600) yazar (değer stdout'a DÜŞMEZ); vault yok/erişilemez
# → sessiz-geç, ENV_FILE fallback korunur (fail-hard YOK). ⚠️ KRİTİK re-entrancy-guard: vault-cek'in
# Railway-backbone'u BU skill'i (railway.sh gql) çağırır → VAULT_CEK_INFLIGHT olmadan sonsuz-döngü olur.
# Guard set iken _vault_refresh no-op → iç-çağrı düz dosya-fallback'e düşer (bootstrap-token'ı yine okur).
VAULT_CEK="${VAULT_CEK_BIN:-$HOME/.claude/skills/vault-cek/scripts/vault-cek.sh}"
_vault_refresh(){  # _vault_refresh KEY...  — her KEY'i vault'tan ENV_FILE'a tazele (non-fatal)
  [ -n "${VAULT_CEK_INFLIGHT:-}" ] && return 0
  [ -f "$VAULT_CEK" ] || return 0
  local k
  for k in "$@"; do
    VAULT_CEK_INFLIGHT=1 CORTEX_ACCESS_ENV="$ENV_FILE" bash "$VAULT_CEK" get "$k" >/dev/null 2>&1 || true
  done
}
_vault_status(){  # doctor 3-durum: yeşil|kırmızı|doğrulanmadı (değer-OKUMAZ)
  if [ -n "${VAULT_CEK_INFLIGHT:-}" ]; then printf 'atlandı(re-entrancy)'; return; fi
  [ -f "$VAULT_CEK" ] || { printf 'doğrulanmadı(vault-cek-yok)'; return; }
  if VAULT_CEK_INFLIGHT=1 bash "$VAULT_CEK" doctor >/dev/null 2>&1; then printf 'yeşil'
  else printf 'kırmızı(fallback-aktif)'; fi
}
_vault_parite(){  # _vault_parite <token-durumu>  — vault-dahil 3-durum parite satırı
  local fb="yok"; [ -f "$ENV_FILE" ] && fb="var"
  echo "  vault:$(_vault_status) · env-fallback:${fb} · token-geçerli:${1}"
}

# ── kimlik yükleme (DEĞERİ EKRANA BASMADAN) ─────────────────────────────────
load_creds(){
  # VAULT-FIRST: Infisical/vault seam → cortex-access.env tazele (guard iç-çağrıda döngüyü keser)
  _vault_refresh RAILWAY_API_TOKEN RAILWAY_TOKEN
  if [ -f "$ENV_FILE" ]; then
    set -a
    # yalnız RAILWAY_* token satırlarını source et
    . <(grep -E '^export (RAILWAY_API_TOKEN|RAILWAY_TOKEN)=' "$ENV_FILE" 2>/dev/null) || true
    set +a
  fi
}
have_any_cred(){ [ -n "${RAILWAY_API_TOKEN:-}" ] || [ -n "${RAILWAY_TOKEN:-}" ]; }

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

# ── GraphQL sarmalayıcı: RAILWAY_API_TOKEN (Bearer) > RAILWAY_TOKEN (Project-Access-Token) ──
# Token curl argv'sine YAZILMAZ; env'den okunur (ps/history sızıntısı yok).
gql(){  # gql '<query>' '[vars-json]'
  local q="$1" vars="${2:-}"
  # ⚠️ ${2:-{}} KULLANMA: bash, $2 setliyse sonuna fazla '}' ekler → bozuk JSON. Böyle güvenli:
  [ -n "$vars" ] || vars='{}'
  local -a H=(-sS -H "Content-Type: application/json")
  if [ -n "${RAILWAY_API_TOKEN:-}" ]; then
    H+=(-H "Authorization: Bearer ${RAILWAY_API_TOKEN}")
  elif [ -n "${RAILWAY_TOKEN:-}" ]; then
    H+=(-H "Project-Access-Token: ${RAILWAY_TOKEN}")
  fi
  local body
  body="$(jq -n --arg q "$q" --argjson v "$vars" '{query:$q, variables:$v}' 2>/dev/null)" \
    || { echo '{"errors":[{"message":"vars gecersiz JSON (tek-tirnak icinde gecerli JSON ver)"}]}'; return 0; }
  curl "${H[@]}" -d "$body" "$RAILWAY_GQL"
}
# GraphQL başarı = errors yok VE data null değil.
gql_ok(){ echo "$1" | jq -e '(.errors|not) and (.data != null)' >/dev/null 2>&1; }
gql_errs(){ echo "$1" | jq -r '.errors[]?.message | "    - \(.)"' 2>/dev/null; }

# ═══ komutlar ═══════════════════════════════════════════════════════════════

cmd_set_token(){  # [api|project] — hazır Railway token'ı GİZLİ yapıştır (programatik üretilemez)
  local kind="${1:-api}"
  case "$kind" in
    api|account|workspace) kind="api" ;;
    project|proj)          kind="project" ;;
    *) die "kullanım: set-token [api|project]  (api=account/workspace Bearer · project=Project-Access-Token)" ;;
  esac
  echo "Railway token yapıştır (gizli — ekrana/geçmişe düşmez). Üret: railway.com/account/tokens"
  echo "  · api     → Account/Workspace token (Authorization: Bearer) — GraphQL API işleri (bu skill'in ağırlığı)"
  echo "  · project → Project token (Project-Access-Token) — tek proje+ortam (railway.sh set-token project)"
  local tok; read -rsp "Railway ${kind} token: " tok; echo
  [ -n "$tok" ] || die "boş token"
  if [ "$kind" = "api" ]; then
    put_env RAILWAY_API_TOKEN "$tok"; del_env RAILWAY_TOKEN
    grn "✓ token kaydedildi (RAILWAY_API_TOKEN · Bearer) → $ENV_FILE (600)"
  else
    put_env RAILWAY_TOKEN "$tok"; del_env RAILWAY_API_TOKEN
    grn "✓ token kaydedildi (RAILWAY_TOKEN · Project-Access-Token) → $ENV_FILE (600)"
  fi
  unset tok
  echo "  Doğrula: bash $0 doctor"
}

cmd_doctor(){
  load_creds
  if ! have_any_cred; then
    red "✗ Railway kimliği YOK ($ENV_FILE)"
    _vault_parite "doğrulanmadı"
    echo "  Bir kerelik: railway.com/account/tokens → 'Create Token' → kopyala → bash $0 set-token"
    echo "  (⚠️ Token programatik ÜRETİLEMEZ — Railway'de yalnız dashboard'da üretilir; bu skill token isteyip saklar.)"
    echo "  Least-privilege: tek proje → PROJECT token (set-token project) · çok-proje/API işi → WORKSPACE/ACCOUNT (set-token)."
    exit 1
  fi
  if [ -n "${RAILWAY_API_TOKEN:-}" ]; then
    # ACCOUNT mı WORKSPACE mı? 'me' SADECE account token ile çalışır → önce onu dene, olmazsa 'projects'.
    local r; r="$(gql 'query { me { name email } }')"
    if gql_ok "$r" && [ -n "$(echo "$r" | jq -r '.data.me.email // empty')" ]; then
      grn "✓ kimlik geçerli (ACCOUNT token · Bearer)  → $(echo "$r" | jq -r '.data.me.email')"
    else
      local r2; r2="$(gql 'query { projects { edges { node { name } } } }')"
      if gql_ok "$r2"; then
        local n; n="$(echo "$r2" | jq -r '[.data.projects.edges[]?] | length')"
        grn "✓ kimlik geçerli (WORKSPACE token · Bearer) — ${n} proje görünür"
      else
        red "✗ Bearer token doğrulanamadı (aktif/geçerli mi?):"; gql_errs "$r2"; exit 1
      fi
    fi
  else
    # PROJECT token — 'me'/'projects' project-scope'ta çalışmayabilir; probu best-effort yap.
    ylw "• PROJECT token kayıtlı (RAILWAY_TOKEN · Project-Access-Token)."
    local r; r="$(gql 'query { projects { edges { node { name } } } }')"
    if gql_ok "$r"; then
      grn "✓ token API'ye bağlanıyor (proje-kapsamlı sorgular çalışır)"
    else
      ylw "• 'me'/'projects' project-scope'ta çalışmaz → asıl doğrulama ilk gerçek proje sorgusunda (services/pg-url)."
      ylw "  (unknown ≠ fail: token kayıtlı, HENÜZ doğrulanmadı — çalıştırıp gör.)"
    fi
  fi
  _vault_parite "yeşil"
  echo; echo "Hazır. Örn:  bash $0 projects   ·   bash $0 services <projectId>"
}

cmd_projects(){  # workspace/account token'ın gördüğü projeler
  load_creds; have_any_cred || die "kimlik yok — önce: bash $0 set-token"
  local r; r="$(gql 'query { projects { edges { node { id name } } } }')"
  gql_ok "$r" || { red "✗ projeler alınamadı:"; gql_errs "$r"; exit 1; }
  echo "Projeler:"
  echo "$r" | jq -r '.data.projects.edges[]?.node | "  • \(.name)   \(.id)"' 2>/dev/null \
    || echo "  (proje yok / okunamadı)"
}

cmd_services(){  # <projectId> — proje ortamları + servisleri (id'ler pg-url için)
  local pid="${1:-}"; [ -n "$pid" ] || die "kullanım: services <projectId>  (id'ler: bash $0 projects)"
  load_creds; have_any_cred || die "kimlik yok — önce: bash $0 set-token"
  local vars r
  vars="$(jq -n --arg id "$pid" '{id:$id}')"
  r="$(gql 'query($id: String!) { project(id: $id) { name environments { edges { node { id name } } } services { edges { node { id name } } } } }' "$vars")"
  gql_ok "$r" || { red "✗ servisler alınamadı:"; gql_errs "$r"; exit 1; }
  echo "proje: $(echo "$r" | jq -r '.data.project.name // "?"')   ($pid)"
  echo "environments (eid):"
  echo "$r" | jq -r '.data.project.environments.edges[]?.node | "  • \(.name)   \(.id)"' 2>/dev/null
  echo "services (sid):"
  echo "$r" | jq -r '.data.project.services.edges[]?.node | "  • \(.name)   \(.id)"' 2>/dev/null
  echo
  echo "→ DATABASE_URL almak için:  bash $0 pg-url $pid <eid> <sid> [ENV_ADI]"
}

cmd_pg_url(){  # <projectId> <environmentId> <serviceId> [ENV_ADI=DATABASE_URL]
  # DATABASE_URL'i ENV'e YAZAR; DEĞERİ ASLA stdout'a BASMAZ (sızıntı yasağı).
  local pid="${1:-}" eid="${2:-}" sid="${3:-}" envkey="${4:-DATABASE_URL}"
  [ -n "$pid" ] && [ -n "$eid" ] && [ -n "$sid" ] \
    || die "kullanım: pg-url <projectId> <environmentId> <serviceId> [ENV_ADI]  (id'ler: bash $0 services <pid>)"
  case "$envkey" in *[!A-Za-z0-9_]*) die "ENV_ADI yalnız harf/rakam/alt-çizgi: '$envkey'";; esac
  load_creds; have_any_cred || die "kimlik yok — önce: bash $0 set-token"
  local vars r url
  vars="$(jq -n --arg p "$pid" --arg e "$eid" --arg s "$sid" '{projectId:$p, environmentId:$e, serviceId:$s}')"
  r="$(gql 'query($projectId: String!, $environmentId: String!, $serviceId: String!) { variables(projectId: $projectId, environmentId: $environmentId, serviceId: $serviceId) }' "$vars")"
  gql_ok "$r" || { red "✗ değişkenler alınamadı:"; gql_errs "$r"; exit 1; }
  # variables → {KEY:VALUE,...}. DATABASE_URL (yoksa yaygın alternatifler). DEĞERİ YAKALA, BASMA.
  url="$(echo "$r" | jq -r '.data.variables.DATABASE_URL // .data.variables.DATABASE_PRIVATE_URL // .data.variables.PG_DATABASE_URL // empty')"
  if [ -z "$url" ]; then
    red "✗ DATABASE_URL bu serviste bulunamadı."
    echo "  Tanımlı değişken ADLARI (değersiz — sır basılmaz):"
    echo "$r" | jq -r '.data.variables | keys[]?' 2>/dev/null | sed 's/^/    - /'
    exit 1
  fi
  put_env "$envkey" "$url"; unset url
  grn "✓ DATABASE_URL alındı → $ENV_FILE içinde '$envkey' (600). DEĞER stdout'a BASILMADI."
  echo "  Kullan:  set -a; . $ENV_FILE; set +a   →  \$$envkey"
}

cmd_gql(){  # '<query>' '[vars-json]' — ham GraphQL kaçış-kapısı (çıktı stdout'a düşer → sır çekme)
  local q="${1:-}" vars="${2:-}"
  [ -n "$q" ] || die "kullanım: gql '<query>' '[vars-json]'   (ör: gql 'query { me { email } }')"
  load_creds; have_any_cred || die "kimlik yok — önce: bash $0 set-token"
  # ⚠️ Bu ham çıktıyı log/transkripte DÖKME: sorgu sır (variables{}) çekerse değeri düz-metin gelir.
  gql "$q" "$vars"
  echo
}

cmd_help(){ sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-doctor}" in
  set-token)      shift; cmd_set_token "$@" ;;
  doctor|verify)  cmd_doctor ;;
  projects)       cmd_projects ;;
  services)       shift; cmd_services "$@" ;;
  pg-url)         shift; cmd_pg_url "$@" ;;
  gql)            shift; cmd_gql "$@" ;;
  help|-h|--help) cmd_help ;;
  *) die "bilinmeyen komut: $1  (set-token [api|project] | doctor | projects | services <pid> | pg-url <pid> <eid> <sid> [ENV] | gql '<q>' '[vars]')" ;;
esac
