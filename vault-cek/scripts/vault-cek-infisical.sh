#!/usr/bin/env bash
# vault-cek — INFISICAL adaptörü (Merkezî-Vault F2 seam re-point · 2026-07-09).
# Kontrat, Railway adaptörü (vault-cek.sh) ile BİREBİR AYNI → consumer'lar (container/pcloud-erisim)
# YENİDEN-KABLOLANMAZ; yalnız backbone Railway→Infisical değişir (swappable-seam kanıtı):
#   vault-cek doctor            Infisical CLI + identity + proje erişimi (3-durum)
#   vault-cek resolve           proje/env/domain göster (SIR DEĞİL)
#   vault-cek get <KEY>         <KEY>'i çek → cortex-access.env (değer BASILMAZ)
#   vault-cek list [<kaynak>]   <kaynak> folder'ındaki KEY ADLARINI göster (değer DEĞİL; default /shared)
#
# Backbone: Infisical machine-identity (Universal Auth). Değer stdout/log/chat'e ASLA basılmaz
#   (get → yalnız cortex-access.env'e 600; login/get --plain YALNIZ shell-değişkenine capture edilir).
# Auth: ~/.config/infisical/identity.env → INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET
#   (+ INFISICAL_PROJECT_ID). HARDCODE YOK. Cloud/self-host agnostik: INFISICAL_DOMAIN ya da --domain.
# KEY→path eşlemesi (§1/§2 folder-model): `<KAYNAK>__<REST>` → path=/<kaynak-lower> + key=<REST>;
#   `__`-siz → path=/shared + key=<KEY>. cortex-access.env'e ORİJİNAL <KEY> adıyla yazılır.
set -uo pipefail

ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
IDENT_FILE="${INFISICAL_IDENTITY_ENV:-$HOME/.config/infisical/identity.env}"
INF_ENV="${INFISICAL_ENV:-prod}"
DOMAIN="${INFISICAL_DOMAIN:-}"       # boş = US-cloud (CLI default); EU/self-host = https://...
OVR_PATH="${VAULT_PATH:-}"           # KEY-map path override (opsiyonel)

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*" >&2; exit 1; }

# --domain <d> / --path <p> herhangi konumda ayrıştır → kalan pozisyonelleri ARGS'a topla.
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --domain=*) DOMAIN="${1#--domain=}"; shift ;;
    --path) OVR_PATH="${2:-}"; shift 2 ;;
    --path=*) OVR_PATH="${1#--path=}"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"

command -v infisical >/dev/null 2>&1 || die "infisical CLI yok — kur: 'npm i -g @infisical/cli' (F1/F3 kurulum)"

# infisical wrapper — --domain yalnız set ise ekle (US-cloud default'unu bozma).
inf(){ if [ -n "$DOMAIN" ]; then infisical --domain "$DOMAIN" "$@"; else infisical "$@"; fi; }

_load_ident(){   # identity.env'den CID/CSEC/PID yükle (değer basmadan). Yoksa açık remediation.
  [ -f "$IDENT_FILE" ] || die "identity.env yok ($IDENT_FILE) — Sultan machine-identity provision etmeli (§C-9: 600-dosya, CID/CSEC/PROJECT_ID)"
  set -a; . "$IDENT_FILE"; set +a
  : "${INFISICAL_CLIENT_ID:?identity.env icinde INFISICAL_CLIENT_ID yok}"
  : "${INFISICAL_CLIENT_SECRET:?identity.env icinde INFISICAL_CLIENT_SECRET yok}"
  : "${INFISICAL_PROJECT_ID:?identity.env icinde INFISICAL_PROJECT_ID yok - central-vault projectId}"
}

_login(){   # universal-auth → kısa-ömürlü token. Token yalnız $INFISICAL_TOKEN'a (stdout'a BASILMAZ).
  _load_ident
  local tok
  tok=$(inf login --method=universal-auth \
        --client-id="$INFISICAL_CLIENT_ID" --client-secret="$INFISICAL_CLIENT_SECRET" \
        --plain --silent 2>/dev/null) || die "universal-auth login başarısız (CID/CSEC ya da --domain?)"
  [ -n "$tok" ] || die "login token boş (identity/scope?)"
  export INFISICAL_TOKEN="$tok"
}

_map_key(){   # $1=KEY → MAP_PATH, MAP_INFKEY (global). Override: --path/VAULT_PATH.
  local k="$1"
  if [ -n "$OVR_PATH" ]; then
    MAP_PATH="$OVR_PATH"; MAP_INFKEY="$k"
  elif [ "${k%%__*}" != "$k" ]; then
    local src="${k%%__*}" rest="${k#*__}"
    MAP_PATH="/$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')"; MAP_INFKEY="$rest"
  else
    MAP_PATH="/shared"; MAP_INFKEY="$k"
  fi
}

cmd="${1:-help}"
case "$cmd" in
  resolve)
    _login
    grn "✓ central-vault → project=$INFISICAL_PROJECT_ID env=$INF_ENV domain=${DOMAIN:-us-cloud}" ;;

  doctor)
    if ! command -v infisical >/dev/null 2>&1; then die "infisical CLI yok (npm i -g @infisical/cli)"; fi
    if [ ! -f "$IDENT_FILE" ]; then ylw "• infisical CLI var; identity.env YOK ($IDENT_FILE) — Sultan provision (§C-9)"; exit 4; fi
    _login || exit 4
    # /shared erişimini prob et (değer-basmadan; -o dotenv → çıktı /dev/null'a, yalnız exit-code).
    if inf secrets --projectId "$INFISICAL_PROJECT_ID" --env "$INF_ENV" --path "/shared" -o dotenv --silent >/dev/null 2>&1; then
      grn "✓ vault erişimi HAZIR (central-vault · $INFISICAL_PROJECT_ID · env=$INF_ENV · domain=${DOMAIN:-us-cloud})"
    else
      ylw "• login OK ama /shared okunamadı (identity path-scope ya da env=$INF_ENV yanlış?)"; exit 4
    fi ;;

  list)
    _login
    src="${2:-}"
    if [ -n "$OVR_PATH" ]; then P="$OVR_PATH"
    elif [ -n "$src" ]; then P="/$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')"
    else P="/shared"; fi
    # -o dotenv → KEY=VALUE satırları; YALNIZ KEY-adı basılır (değer '=' sonrası pipe'ta kalır, ekrana ÇIKMAZ).
    out="$(inf secrets --projectId "$INFISICAL_PROJECT_ID" --env "$INF_ENV" --path "$P" -o dotenv --silent 2>/dev/null)" \
      || die "list başarısız ($P · env=$INF_ENV) — path/scope?"
    names="$(printf '%s\n' "$out" | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | sort)"
    n="$(printf '%s' "$names" | grep -c . || true)"
    grn "Vault KEY adları [$P] ($n):"
    if [ "$n" -gt 0 ]; then printf '  • %s\n' $names; else printf '  (boş)\n'; fi ;;

  get)
    KEY="${2:-}"; [ -n "$KEY" ] || die "kullanım: get <KEY>"
    _map_key "$KEY"
    _login
    # secrets get <infkey> --plain → YALNIZ değer (tek-satır); shell-değişkenine capture, ekrana BASILMAZ.
    VAL=$(inf secrets get "$MAP_INFKEY" --projectId "$INFISICAL_PROJECT_ID" --env "$INF_ENV" \
          --path "$MAP_PATH" --plain --silent 2>/dev/null) || VAL=""
    if [ -z "$VAL" ]; then die "$KEY yok (path=$MAP_PATH key=$MAP_INFKEY env=$INF_ENV) — Sultan Infisical'a eklemeli"; fi
    # Idempotent yaz: ORİJİNAL <KEY> adıyla (consumer rewire-yok), shlex-quote, 600. Değer python-stdin (argv-YOK).
    LEN=$(KEY="$KEY" ENVF="$ENV_FILE" VAL="$VAL" python3 -c '
import os,re,shlex
k=os.environ["KEY"]; envf=os.environ["ENVF"]; val=os.environ["VAL"]
lines=[l for l in open(envf).read().splitlines() if not re.match(r"^export "+re.escape(k)+"=",l)] if os.path.exists(envf) else []
lines.append("export %s=%s"%(k, shlex.quote(val)))
open(envf,"w").write("\n".join(lines)+"\n"); os.chmod(envf,0o600)
print(len(val))')
    grn "✓ $KEY alındı → cortex-access.env (${LEN} krk, değer basılmadı · $MAP_PATH/$MAP_INFKEY)" ;;

  *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
