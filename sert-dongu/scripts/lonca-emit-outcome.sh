#!/usr/bin/env bash
# lonca-emit-outcome.sh — /sert-döngü STOP-emit (Lonca KEYSTONE-köprü sürücü-ucu · FAZ-5B-2b).
#
# Döngü-yürütücü HER STOP'ta (🎯 F3-RC0 · ⛔ max_iter · 🔁 dönme · ❌ RC2 · 🕳️ apparat) curated
# KABUL-özetini POST /api/lonca/outcome'a yollar → lonca_acceptance → huni "Kabul" aşaması dolar.
# /orkestra FAZ-5B-2a emsalinin (Nexus .claude/skills/orkestra) sert-döngü portu — gövde birebir,
# yalnız başlık/semantik uyarlandı (source çağırandan gelir: "sert-dongu").
#
# INERT: LONCA_BRIDGE_TOKEN yoksa sessiz no-op (exit 0) → byte-identical, döngü-akışı bozulmaz.
#
# ── KURULUM / YAPILANDIRMA (git-clone turnkey) ──
#   LONCA_BRIDGE_TOKEN : köprü-token'ı (secret; kanonik _agents/credentials.yaml → lonca-bridge).
#                        YOKSA emit KAPALI (INERT). `vault-cek get NEXUS__LONCA_BRIDGE_TOKEN`
#                        koşulmuşsa cortex-access.env'den OTOMATİK türetilir.
#   LONCA_BRIDGE_URL   : hedef taban-URL (default https://nexusapp.up.railway.app = prod).
#   Bağımlılık: bash + python3 + curl — EK-KURULUM YOK. Script skill-paketi İÇİNDE (git-tracked).
#
# ── DEĞİŞMEZLER ──
#   value-safe : token DEĞERİ echo/log edilmez (yalnız header). Yalnız curated argümanlar POST edilir —
#                HAM senaryo/kanıt/log metni bu script'e GİRMEZ (redaksiyon = çağıran STOP-adımının işi).
#   fail-safe  : token-yok / eksik-arg / curl-hata / non-2xx → exit 0 (STOP-akışını ASLA bozmaz).
set -uo pipefail

# Vault-first token çözümü (value-safe): env yoksa kanonik vault-dosyasından türet.
if [ -z "${LONCA_BRIDGE_TOKEN:-}" ] && [ -f "$HOME/.config/cortex-access.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/cortex-access.env" 2>/dev/null || true
  : "${LONCA_BRIDGE_TOKEN:=${NEXUS__LONCA_BRIDGE_TOKEN:-}}"
fi

# INERT-kapı: token yoksa hiç POST yok (byte-identical davranış).
[ -z "${LONCA_BRIDGE_TOKEN:-}" ] && exit 0

SOURCE="" GOAL="" ACCEPTED="false" ITER="0" RC="" AGENT="" FIXER="" DETAIL="" META="{}"
while [ $# -gt 0 ]; do
  case "$1" in
    --source)      SOURCE="${2:-}"; shift 2 ;;
    --goal)        GOAL="${2:-}"; shift 2 ;;
    --accepted)    ACCEPTED="${2:-false}"; shift 2 ;;
    --iterations)  ITER="${2:-0}"; shift 2 ;;
    --rc)          RC="${2:-}"; shift 2 ;;
    --agent)       AGENT="${2:-}"; shift 2 ;;
    --fixer-audit) FIXER="${2:-}"; shift 2 ;;
    --detail)      DETAIL="${2:-}"; shift 2 ;;
    --metadata)    META="${2:-{}}"; shift 2 ;;
    *)             shift ;;
  esac
done

# source+goal zorunlu (endpoint aksi halde 400); eksikse sessiz-skip (STOP'u bozma).
if [ -z "$SOURCE" ] || [ -z "$GOAL" ]; then exit 0; fi

URL="${LONCA_BRIDGE_URL:-https://nexusapp.up.railway.app}/api/lonca/outcome"

# JSON-gövde python3 ile GÜVENLİ-encode (elle-escape tuzağı yok). rc="" / "-" → null. metadata bozuksa {}.
BODY="$(python3 - "$SOURCE" "$GOAL" "$ACCEPTED" "$ITER" "$RC" "$AGENT" "$FIXER" "$DETAIL" "$META" <<'PY'
import json, sys
source, goal, accepted, it, rc, agent, fixer, detail, meta = sys.argv[1:10]
def as_int(x, d=0):
    try: return int(x)
    except Exception: return d
def maybe_int(x):
    if x in ("", "-", "null", "None"): return None
    try: return int(x)
    except Exception: return None
try:
    m = json.loads(meta) if meta else {}
    if not isinstance(m, dict): m = {}
except Exception:
    m = {}
body = {
    "source": source,
    "goalSlug": goal,
    "accepted": accepted.lower() == "true",
    "iterations": as_int(it),
    "rc": maybe_int(rc),
    "agentId": agent or None,
    "fixerAudit": fixer or None,
    "detail": detail or None,
    "metadata": m,
}
print(json.dumps(body))
PY
)" || exit 0

# POST — fail-safe: hata/timeout/non-2xx (-f) → exit 0. Token yalnız header'da (echo edilmez).
curl -sf -m 5 -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Lonca-Token: ${LONCA_BRIDGE_TOKEN}" \
  --data "$BODY" >/dev/null 2>&1 || exit 0

exit 0
