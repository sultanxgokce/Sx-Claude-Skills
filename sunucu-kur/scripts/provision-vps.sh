#!/usr/bin/env bash
# provision-vps.sh — docker-servis tipi Hetzner VPS provizyon toolkit (SERDAR-ailesi · sunucu-kur skill).
#
# Sürtünme-prone + value-safe MEKANİK adımları saran subcommand'lı yardımcı. Servise-özel yapıştırma
# (lift-shift/compose) runbook'ta kalır; bu script "gotcha" adımlarını idempotent + değer-güvenli yapar.
#
# DEĞİŞMEZLER:
#   • Sır DEĞERİ stdout/argv/chat/log'a ASLA düşmez (infisical → shell-var → ssh-pipe; yalnız anahtar-adı+uzunluk basılır).
#   • Sunucu OLUŞTURMA = YIKICI → `create` yalnız `--apply` ile; default reddeder (Sultan-gate).
#   • hcloud token argv'ye ASLA (gizli-stdin / context). vault-cek get KULLANMA (container'da uv yok → sessiz-fail).
#
# Kanon: Nexus/_agents/runbooks/vps-provizyon.md · known-errors "VPS-Provizyon Sürtünmeleri".
set -euo pipefail

IDENT="${INFISICAL_IDENTITY_ENV:-$HOME/.config/infisical/identity.env}"
SSH_KEY_FILE="${PROVISION_SSH_KEY:-$HOME/.ssh/nexus_vps}"
INF_ENV="${INFISICAL_ENV:-prod}"
PID=""

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
log(){ printf '  %s\n' "$*"; }
die(){ printf '\033[31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

_need(){ command -v "$1" >/dev/null 2>&1 || die "gerekli araç yok: $1"; }

_infisical_login(){   # universal-auth → INFISICAL_TOKEN + PID (değer basmadan). Idempotent.
  [ -n "$PID" ] && return 0
  _need infisical
  [ -f "$IDENT" ] || die "identity.env yok ($IDENT) — Sultan machine-identity provision etmeli"
  set -a; . "$IDENT"; set +a
  PID="${INFISICAL_PROJECT_ID:?identity.env icinde INFISICAL_PROJECT_ID yok}"
  : "${INFISICAL_CLIENT_ID:?identity.env icinde INFISICAL_CLIENT_ID yok}"
  : "${INFISICAL_CLIENT_SECRET:?identity.env icinde INFISICAL_CLIENT_SECRET yok}"
  local tok
  tok=$(infisical login --method=universal-auth --client-id="$INFISICAL_CLIENT_ID" \
        --client-secret="$INFISICAL_CLIENT_SECRET" --plain --silent 2>/dev/null) \
        || die "infisical universal-auth login başarısız (CID/CSEC?)"
  [ -n "$tok" ] || die "infisical login token boş"
  export INFISICAL_TOKEN="$tok"
}

_vault_get(){   # <KEY> <folder> → değeri STDOUT'a (ÇAĞIRAN shell-var'a capture eder, ekrana basmaz)
  _infisical_login
  infisical secrets get "$1" --projectId "$PID" --env "$INF_ENV" --path "/$2" --plain --silent 2>/dev/null
}

# ── preflight ────────────────────────────────────────────────────────────────
cmd_preflight(){
  _need hcloud
  if hcloud server list >/dev/null 2>&1; then grn "✓ hcloud erişimi CANLI (context+token)"; return 0
  else ylw "• hcloud context/token YOK — 'context-ensure' koş"; return 4; fi
}

# ── context-ensure — token vault /nexus'tan (fix: 1Password-only değil) ──────
cmd_context_ensure(){
  _need hcloud
  hcloud server list >/dev/null 2>&1 && { grn "✓ hcloud context zaten canlı"; return 0; }
  local tok; tok=$(_vault_get HETZNER_API_TOKEN nexus) || true
  [ -n "$tok" ] || die "vault /nexus'ta HETZNER_API_TOKEN yok/boş — Sultan deposit etmeli"
  printf '%s\n' "$tok" | hcloud context create "${HCLOUD_CONTEXT:-nexus}" >/dev/null 2>&1 \
    || die "hcloud context create başarısız (aynı-ad var olabilir; 'hcloud context list' bak)"
  hcloud server list >/dev/null 2>&1 || die "context kuruldu ama erişim doğrulanamadı"
  grn "✓ hcloud context '${HCLOUD_CONTEXT:-nexus}' kuruldu (token vault/nexus, değer-basılmadı)"
}

# ── sshkey-ensure <ad> [pubfile] — Hetzner'e register (fix-d, idempotent) ────
cmd_sshkey_ensure(){
  local name="${1:?kullanım: sshkey-ensure <ad> [pubfile]}" pub="${2:-$SSH_KEY_FILE.pub}"
  _need hcloud
  [ -f "$pub" ] || die "pubkey yok: $pub"
  if hcloud ssh-key describe "$name" >/dev/null 2>&1; then grn "✓ ssh-key '$name' zaten kayıtlı"
  else hcloud ssh-key create --name "$name" --public-key-from-file "$pub" >/dev/null; grn "✓ ssh-key '$name' kaydedildi"; fi
}

# ── create — çakışma-guard + Sultan-gate (--apply) ───────────────────────────
cmd_create(){   # --name X --type cx23 --location hel1 --image ubuntu-24.04 --ssh-key ad --cloud-init file [--apply]
  local name="" type="cx23" loc="hel1" image="ubuntu-24.04" key="" ci="" apply=0
  while [ $# -gt 0 ]; do case "$1" in
    --name) name="$2"; shift 2;; --type) type="$2"; shift 2;; --location) loc="$2"; shift 2;;
    --image) image="$2"; shift 2;; --ssh-key) key="$2"; shift 2;; --cloud-init) ci="$2"; shift 2;;
    --apply) apply=1; shift;; *) die "bilinmeyen bayrak: $1";; esac; done
  _need hcloud
  [ -n "$name" ] || die "--name şart"; [ -n "$key" ] || die "--ssh-key şart"
  [ -n "$ci" ] && { [ -f "$ci" ] || die "cloud-init dosyası yok: $ci"; }
  # çakışma-guard (idempotent): aynı-ad varsa create-ETME
  if hcloud server describe "$name" >/dev/null 2>&1; then
    local ip; ip=$(hcloud server ip "$name" 2>/dev/null || echo "?")
    grn "✓ sunucu '$name' ZATEN VAR (IP=$ip) → create atlandı (idempotent)"; echo "$ip"; return 0
  fi
  # Sultan-gate: create = yıkıcı/masraflı
  if [ "$apply" != 1 ]; then
    ylw "⧗ DRY-RUN: oluşturulacak → name=$name type=$type loc=$loc image=$image ssh-key=$key cloud-init=${ci:-<yok>}"
    ylw "  gerçekten oluşturmak için --apply ekle (YIKICI/masraflı — Sultan-onayı sonrası)."
    return 3
  fi
  local args=(--name "$name" --type "$type" --location "$loc" --image "$image" --ssh-key "$key")
  [ -n "$ci" ] && args+=(--user-data-from-file "$ci")
  hcloud server create "${args[@]}"
  local ip; ip=$(hcloud server ip "$name")
  grn "✓ sunucu '$name' oluştu IP=$ip"; echo "$ip"
}

# ── env-inject — value-safe /etc/*.env üret (fix-b: infisical-direct, uv-yok) ─
cmd_env_inject(){   # <ip> <remote-path> <folder> <KEY1,KEY2,...> [extra-config-file]
  local ip="${1:?kullanım: env-inject <ip> <remote-path> <folder> <keys> [extra-config-file]}"
  local dst="${2:?remote-path}" folder="${3:?folder}" keys="${4:?keys}" extra="${5:-}"
  local content="" k v; IFS=',' read -ra KA <<< "$keys"
  for k in "${KA[@]}"; do
    v=$(_vault_get "$k" "$folder") || true
    [ -n "$v" ] || die "vault /$folder'da $k yok/boş"
    content+="$k=$v"$'\n'
    printf '    fetched %s (len=%d)\n' "$k" "${#v}" >&2    # YALNIZ uzunluk — değer değil
  done
  [ -n "$extra" ] && { [ -f "$extra" ] || die "extra-config yok: $extra"; content+="$(cat "$extra")"$'\n'; }
  # değer $content'te → ssh-pipe (stdout'a ASLA); remote 600+root
  printf '%s' "$content" | ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=accept-new root@"$ip" \
    "umask 077; cat > '$dst' && chmod 600 '$dst' && chown root:root '$dst' && \
     printf 'yazıldı: %s anahtar\n' \"\$(grep -cE '^[A-Za-z_]+=' '$dst')\" && \
     grep -oE '^[A-Za-z_]+=' '$dst' | tr -d = | tr '\n' ' ' && echo"
  grn "✓ $dst yazıldı (değer basılmadı, 600, root)"
}

# ── healthz — servis-sağlığı doğrula ─────────────────────────────────────────
cmd_healthz(){   # <ip> [port] [path]
  local ip="${1:?kullanım: healthz <ip> [port] [path]}" port="${2:-8000}" path="${3:-/healthz}"
  local code
  code=$(ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=accept-new root@"$ip" \
        "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:$port$path" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then grn "✓ healthz 200 ($ip:$port$path)"; return 0
  else ylw "• healthz=$code ($ip:$port$path) — servis hazır değil / log incele"; return 4; fi
}

usage(){ cat <<'EOF'
provision-vps.sh — Hetzner docker-servis VPS provizyon toolkit (value-safe, idempotent)

  preflight                         hcloud erişimi canlı mı (3-durum)
  context-ensure                    token vault/nexus → hcloud context (yoksa)
  sshkey-ensure <ad> [pubfile]      pubkey'i Hetzner'e register (idempotent)
  create --name X --ssh-key ad [--type cx23] [--location hel1]
         [--image ubuntu-24.04] [--cloud-init file] [--apply]
                                    sunucu oluştur (çakışma-guard; --apply YIKICI, Sultan-gate)
  env-inject <ip> <remote-path> <folder> <KEY1,KEY2,...> [extra-config-file]
                                    /etc/*.env value-safe üret (600, değer basmaz)
  healthz <ip> [port] [path]        servis-sağlığı doğrula

Değişmez: sır-değer ASLA basılmaz · create yalnız --apply · token argv'ye ASLA.
Tam akış: Nexus/_agents/runbooks/vps-provizyon.md
EOF
}

case "${1:-help}" in
  preflight) shift; cmd_preflight "$@";;
  context-ensure) shift; cmd_context_ensure "$@";;
  sshkey-ensure) shift; cmd_sshkey_ensure "$@";;
  create) shift; cmd_create "$@";;
  env-inject) shift; cmd_env_inject "$@";;
  healthz) shift; cmd_healthz "$@";;
  help|-h|--help) usage;;
  *) usage; exit 1;;
esac
