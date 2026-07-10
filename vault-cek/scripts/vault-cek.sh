#!/usr/bin/env bash
# vault-cek — Railway "Vault" projesinden (shared-var, namespace'li) sır çeker → cortex-access.env.
# On-demand vault (SERDAR+SİNAN mimarisi 2026-07-09): Sultan sırları bir kez Vault'a koyar,
# her container bunu RAILWAY_API_TOKEN ile self-servis çeker. Değer stdout/log/chat'e ASLA basılmaz.
#   vault-cek doctor            RAILWAY + Vault-projesi erişimi (3-durum)
#   vault-cek resolve           Vault proje/env id'lerini göster (sır değil)
#   vault-cek get <KEY>         <KEY>'i çek → cortex-access.env (ör: CLOUDFLARE_API_TOKEN, VEKATIP__DATABASE_URL)
#   vault-cek list              Vault'taki KEY ADLARINI göster (değer değil)
# Env: RAILWAY_VAULT_PROJECT (default 'Vault')
set -uo pipefail
ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
VAULT_PROJECT="${RAILWAY_VAULT_PROJECT:-Vault}"
RAILWAY="$HOME/.claude/skills/railway-erisim/scripts/railway.sh"
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*" >&2; exit 1; }
[ -x "$RAILWAY" ] || die "railway-erisim yok ($RAILWAY)"

_ids(){  # stdout: "<projectId> <envId>"  — Vault projesini adıyla çöz (production env)
  local q='query{ projects{ edges{ node{ id name environments{ edges{ node{ id name } } } } } } }'
  VP="$VAULT_PROJECT" bash "$RAILWAY" gql "$q" 2>/dev/null | VP="$VAULT_PROJECT" uv run --no-project python3 -c '
import sys,json,os
name=os.environ["VP"]; d=json.load(sys.stdin)
for e in (d.get("data",{}).get("projects",{}).get("edges") or []):
    n=e["node"]
    if n["name"]==name:
        envs={x["node"]["name"]:x["node"]["id"] for x in (n.get("environments",{}).get("edges") or [])}
        print(n["id"], envs.get("production") or (next(iter(envs.values())) if envs else "")); break
'
}
_vars_json(){  # <pid> <eid> → {KEY:VALUE} JSON (çağıran capture eder; basmaz)
  local q='query($p:String!,$e:String!){ variables(projectId:$p, environmentId:$e, unrendered:true) }'
  bash "$RAILWAY" gql "$q" "$(printf '{"p":"%s","e":"%s"}' "$1" "$2")" 2>/dev/null
}

cmd="${1:-help}"
case "$cmd" in
  resolve)
    read -r PID EID < <(_ids); [ -n "${PID:-}" ] || die "Vault projesi '$VAULT_PROJECT' bulunamadı (Sultan açtı mı?)"
    grn "✓ $VAULT_PROJECT → project=$PID env=$EID" ;;
  doctor)
    bash "$RAILWAY" doctor >/dev/null 2>&1 || die "RAILWAY_API_TOKEN yok/geçersiz — railway-erisim set-token"
    read -r PID EID < <(_ids)
    if [ -n "${PID:-}" ]; then grn "✓ vault erişimi HAZIR ($VAULT_PROJECT · $PID)"; else
      ylw "• RAILWAY tamam ama '$VAULT_PROJECT' projesi yok (Sultan boş Vault projesini açmalı)"; exit 4; fi ;;
  list)
    read -r PID EID < <(_ids); [ -n "${PID:-}" ] || die "Vault projesi yok"
    _vars_json "$PID" "$EID" | uv run --no-project python3 -c '
import sys,json
d=json.load(sys.stdin); ks=sorted((d.get("data",{}).get("variables") or {}).keys())
print("Vault KEY adları (%d):"%len(ks)); [print("  •",k) for k in ks] or print("  (boş)")' ;;
  get)
    KEY="${2:-}"; [ -n "$KEY" ] || die "kullanım: get <KEY>"
    read -r PID EID < <(_ids); [ -n "${PID:-}" ] || die "Vault projesi '$VAULT_PROJECT' yok"
    RES=$(_vars_json "$PID" "$EID" | KEY="$KEY" ENVF="$ENV_FILE" uv run --no-project python3 -c '
import sys,json,os,re,shlex
d=json.load(sys.stdin); V=(d.get("data",{}).get("variables") or {}); k=os.environ["KEY"]
val=V.get(k)
if val is None: print("MISS"); sys.exit(0)
envf=os.environ["ENVF"]
lines=[l for l in open(envf).read().splitlines() if not re.match(r"^export "+re.escape(k)+"=",l)] if os.path.exists(envf) else []
lines.append("export %s=%s"%(k, shlex.quote(val)))
open(envf,"w").write("\n".join(lines)+"\n"); os.chmod(envf,0o600)
print("OK %d"%len(val))')
    set -- $RES
    if [ "${1:-}" = "OK" ]; then grn "✓ $KEY alındı → cortex-access.env (${2} krk, değer basılmadı)"; else die "$KEY Vault'ta yok"; fi ;;
  *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
