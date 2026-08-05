#!/usr/bin/env bash
# /erisim — ERİŞİM-ZİNCİRİ dispatcher (Merkezî-Vault E2 · 2026-07-10).
# Ajanın TEK giriş-noktası: zinciri O ezberlemez, dispatcher yürütür. E3-vault-first'ün ÜSTÜNE oturur.
#   erisim <platform> [iş-argümanları…]   platform-erisim skill'i VAR→delege · YOK→Skill-İstek emit
#   erisim <platform> --sir-iste [neden]   skill-VAR ama sır-eksik → F5 Vault-İstek (sır-türü) emit
#   erisim doctor                          dispatcher 3-durum (kurulu-skill · emit-token · NEXUS_URL-reach)
#   erisim help                            bu yardım
#
# Zincir (DESIGN §A):  /erisim <platform>
#   1. <platform>-erisim VAR MI? VAR → script'e delege (skill zaten vault-first: sır-yoksa dürüst-kırmızı).
#                                 YOK → Skill-İstek emit (geçici-konvansiyon key="SKILL:<platform>", tur-alanı
#                                       E1'de gelince migrate) → 'bekliyor'-etiket.
#   2. skill-VAR ama sır-eksik → --sir-iste ile F5 Vault-İstek (key=<ENV_VAR>, path=/shared) emit.
# ⛔ Değer stdout/log/chat'e ASLA · elle-UI-token-alma YASAK · mevcut skill-kontratına dokunmaz.
# Emit uç: POST $NEXUS_URL/api/defter/vault-istek  (Bearer VAULT_ISTEK_TOKEN · body key/path/env/neden/isteyen;
#   DEĞER-alanı guard'lı=400). Token argv'ye DÜŞMEZ (curl --config - stdin).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(dirname "$(dirname "$HERE")")"          # …/.claude/skills
NEXUS_URL="${NEXUS_URL:-https://nexusapp.up.railway.app}"
ISTEK_URL="${NEXUS_URL}/api/defter/vault-istek"

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl yok"
command -v jq   >/dev/null 2>&1 || die "jq yok"

# ── isteyen tespiti (uydurma-kimlik YOK; env→hostname+cwd dürüst-kestirim) ────────────────
_isteyen(){
  if [ -n "${EKIP_UYE:-}" ];   then printf '%s' "$EKIP_UYE";   return; fi
  if [ -n "${AGENT_NAME:-}" ]; then printf '%s' "$AGENT_NAME"; return; fi
  printf 'bilinmiyor(%s:%s)' "$(hostname 2>/dev/null || echo host)" "$(basename "$(pwd 2>/dev/null || echo '?')")"
}

# ── delege-script çöz: <platform>.sh → yoksa tek *.sh fallback (cf.sh≠cloudflare.sh tuzağı) ─
# DELEGATE_SCRIPT global set edilir; 0=bulundu · 1=skill-dizin-yok · 2=script-yok(yarım-kurulu) · 3=belirsiz.
_resolve_delegate(){
  local plat="$1" dir="$SKILLS_ROOT/${1}-erisim"
  DELEGATE_SCRIPT=""
  [ -d "$dir" ] || return 1
  if [ -f "$dir/scripts/${plat}.sh" ]; then DELEGATE_SCRIPT="$dir/scripts/${plat}.sh"; return 0; fi
  local shs=() f
  for f in "$dir"/scripts/*.sh; do [ -f "$f" ] && shs+=("$f"); done
  case "${#shs[@]}" in
    0) return 2 ;;
    1) DELEGATE_SCRIPT="${shs[0]}"; return 0 ;;
    *) return 3 ;;
  esac
}

# ── emit-token çöz (DEĞER basılmaz): env → cortex-access.env → ui/.env ───────────────────
# EMIT_TOKEN + TOKEN_SRC global. 0=bulundu · 1=yok. Token değeri ASLA stdout'a.
_resolve_emit_token(){
  EMIT_TOKEN=""; TOKEN_SRC=""
  if [ -n "${VAULT_ISTEK_TOKEN:-}" ]; then EMIT_TOKEN="$VAULT_ISTEK_TOKEN"; TOKEN_SRC="env"; return 0; fi
  local f v
  for f in "$HOME/.config/cortex-access.env" "${NEXUS_ENV_FILE:-/config/projects/Nexus/ui/.env}"; do
    [ -f "$f" ] || continue
    v="$(grep -E '^(export )?VAULT_ISTEK_TOKEN=' "$f" 2>/dev/null | head -1 \
          | sed -E 's/^(export )?VAULT_ISTEK_TOKEN=//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')"
    if [ -n "$v" ]; then EMIT_TOKEN="$v"; TOKEN_SRC="$f"; return 0; fi
  done
  return 1
}

# ── F5 istek emit (değer-güvenli): token curl --config stdin'inde, argv'de DEĞİL ─────────
# _emit_istek <key> <path> <neden> ; başarı→ISTEK_ID global. body sır-DEĞERİ taşımaz (guard aynen).
_emit_istek(){
  local key="$1" path="$2" neden="$3" isteyen; isteyen="$(_isteyen)"
  ISTEK_ID=""
  if ! _resolve_emit_token; then
    ylw "⏳ istek emit edilemedi — emit-token YOK (bu container'a dağıtılmamış)."
    echo "   SERDAR'a bildir: VAULT_ISTEK_TOKEN bu node'a dağıtılmalı (env / cortex-access.env / ui/.env)."
    return 3
  fi
  local body; body="$(jq -nc --arg k "$key" --arg p "$path" --arg n "$neden" --arg i "$isteyen" \
    '{key:$k, path:$p, env:"prod", neden:$n, isteyen:$i}')"
  # -d/url argv'de (sır YOK) · Authorization header YALNIZ --config stdin (argv/ps-sızıntısı yok).
  local resp; resp="$(curl -sS -m 15 -X POST -H "Content-Type: application/json" -d "$body" \
    --config - "$ISTEK_URL" 2>/dev/null <<CFG
header = "Authorization: Bearer ${EMIT_TOKEN}"
CFG
)" || { red "✗ emit ağ-hatası (NEXUS_URL ulaşılamadı?)"; return 1; }
  if echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
    ISTEK_ID="$(echo "$resp" | jq -r '.id // empty')"
    return 0
  fi
  # dürüst hata-yüzeyi (değer-yok): 401=token-geçersiz · 503=env-yok · 400=guard/validasyon
  local err; err="$(echo "$resp" | jq -r '.error // "bilinmeyen"' 2>/dev/null)"
  red "✗ emit reddedildi: ${err}"
  return 1
}

# ═══ alt-komutlar ═══════════════════════════════════════════════════════════════════════

cmd_doctor(){
  echo "── /erisim dispatcher · 3-durum ──"
  echo "Kurulu erişim-skill'leri:"
  local d name found=0
  for d in "$SKILLS_ROOT"/*-erisim; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"; name="${name%-erisim}"
    if _resolve_delegate "$name"; then grn "  ✓ ${name}   → $(basename "$DELEGATE_SCRIPT")"; found=1
    else ylw "  • ${name}   (script çözülemedi)"; found=1; fi
  done
  [ "$found" = 1 ] || echo "  (kurulu erisim-skill yok)"
  # emit-token 3-durum (değer-OKUMAZ)
  if _resolve_emit_token; then grn "✓ emit-token : var (kaynak=${TOKEN_SRC})"
  else ylw "• emit-token : YOK (bu container'a dağıtılmamış — skill-YOK/sır-eksik emit edemez, SERDAR'a bildir)"; fi
  # NEXUS_URL reach — HTTP-kod (değer-OKUMAZ; 401/200 = erişilebilir, 000 = ulaşılamaz)
  local code; code="$(curl -sS -o /dev/null -w '%{http_code}' -m 8 "$ISTEK_URL" 2>/dev/null || echo 000)"
  if [ "$code" = "000" ]; then ylw "• NEXUS_URL   : ulaşılamadı (${NEXUS_URL})"
  else grn "✓ NEXUS_URL   : erişilebilir (${NEXUS_URL} · HTTP ${code} — 401 cookie-gate beklenir)"; fi
  echo
  echo "Kullanım:  erisim <platform> [iş-arg…]   ·   erisim <platform> --sir-iste [neden]"
}

# skill-VAR ama sır-eksik → F5 Vault-İstek (sır-türü) emit
cmd_sir_iste(){
  local plat="$1"; shift || true
  local neden="${*:-"$plat sırrı eksik (vault+env boş) — Sultan'a sır-isteği"}"
  _resolve_delegate "$plat" || { ylw "• ${plat}-erisim skill YOK — sır-isteği yerine SKILL-İstek uygun (erisim ${plat})."; return 1; }
  # ENV_VAR kestirimi: dispatcher skill-içi ENV_VAR'ı bilmez → key=<PLATFORM> jenerik + path=/shared.
  # (E1 sonrası skill kendi ENV_VAR'ını bildirebilir; şimdilik dürüst-jenerik.)
  local key; key="$(printf '%s' "$plat" | tr '[:lower:]-' '[:upper:]_')"
  if _emit_istek "$key" "/shared" "$neden"; then
    grn "⏳ Sultan'a sır-isteği düştü (id=${ISTEK_ID:-?}) — hazır-olunca 'erisim ${plat}' tekrar dene."
  else
    return 1
  fi
}

# ═══ ana yönlendirme ════════════════════════════════════════════════════════════════════
main(){
  local cmd="${1:-help}"
  case "$cmd" in
    doctor|verify) cmd_doctor; return $? ;;
    help|-h|--help|"") sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
  esac

  # cmd = platform
  local plat="$cmd"; shift
  case "$plat" in *[!a-z0-9-]*) die "platform adı yalnız küçük-harf/rakam/tire: '$plat'";; esac

  # --sir-iste bayrağı? (skill-VAR sır-eksik yolu)
  if [ "${1:-}" = "--sir-iste" ]; then shift; cmd_sir_iste "$plat" "$@"; return $?; fi

  if _resolve_delegate "$plat"; then
    # 1) skill-VAR → delege. Argsız → doctor (dürüst 3-durum). Skill zaten vault-first.
    if [ "$#" -eq 0 ]; then set -- doctor; fi
    bash "$DELEGATE_SCRIPT" "$@"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
      # Skill kendi dürüst-çıktısını bastı (kırmızı/doğrulanmadı). Sır-eksik AYRIMI dispatcher'dan
      # güvenilir yapılamaz (missing≠invalid≠network) → OTO-emit YOK; açık öneri sun (yanlış-emit önle).
      echo
      ylw "• ${plat}-erisim rc=${rc} döndü (kimlik-eksik VEYA geçersiz VEYA ağ)."
      echo "  Sır gerçekten YOKSA istek bırak:  erisim ${plat} --sir-iste \"<neden>\""
    fi
    return "$rc"
  fi
  local drc=$?

  if [ "$drc" = 2 ] || [ "$drc" = 3 ]; then
    die "${plat}-erisim yarım-kurulu (script çözülemedi, rc=$drc) — SERDAR'a bildir (SKILL-İstek emit ETMEDİM)."
  fi

  # 2) skill-YOK → SKILL-İstek emit (geçici-konvansiyon key="SKILL:<platform>", path=/istek).
  local neden="${*:-"ajan ${plat} erişimi istedi (neden belirtilmedi)"}"
  ylw "• ${plat}-erisim skill'i YOK."
  if _emit_istek "SKILL:${plat}" "/istek" "$neden"; then
    grn "⏳ ${plat}-erisim yok — SERDAR'a SKILL-İstek bırakıldı (id=${ISTEK_ID:-?}). Hazır-olunca 'erisim ${plat}' tekrar dene."
    echo "   (geçici-konvansiyon key=\"SKILL:${plat}\"; E1 tur-alanı gelince gerçek tur=skill'e migrate edilir.)"
  else
    return 1
  fi
}

main "$@"
