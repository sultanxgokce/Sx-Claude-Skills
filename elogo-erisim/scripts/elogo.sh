#!/usr/bin/env bash
# cloudtop · e-Logo erişim CLI — e-Fatura/e-Arşiv işlerini PANELE GİRMEDEN, WS API ile yap.
# ─────────────────────────────────────────────────────────────────────────────
# NEDEN: Ajan "e-Logo'dan fatura çek/durum sorgula" istediğinde her seferinde Sultan'ın
# giriş bilgisi vermesi ANGARYA. Bu CLI o işi tek-sefer gizli-giriş + kalıcı-kimlik ile devreder.
#
# GERÇEK KISIT (dürüstlük): e-Logo'nun "şifre → API token" akışı YOK. Web Servisi doğrudan
# kullanıcı-adı+şifre ile Login → sessionID döndürür. Least-privilege = e-Logo portalında
# ÖZEL bir "Bağlantı (Web Servis) Kullanıcısı" (alt-kullanıcı) açıp SADECE onu kullanmak
# (ör. 3840044863mmexclaude). Ana portal (insan) şifresini WS'e KOYMA.
#
# KUYRUK-GÜVENLİ: bu CLI YALNIZ salt-okur ops sunar (status/get/xml). "alındı-işaretleyen"
# GetDocument/receiveInvoiceDone gibi KUYRUK-TÜKETEN çağrı YOK → eski prod'un B2B senkron
# kuyruğunu bozmaz (CLAUDE.md §3 YASAK sınırına uyumlu).
#
# Sır-hijyeni: parola asla stdout'a/log'a/geçmişe/argv'ye düşmez; yalnız ~/.config/cortex-access.env (600).
# Kanonik pointer: Nexus/_agents/credentials.yaml → [SIR: … → elogo-ws-*].
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
WSDL_DEFAULT="https://pb.elogo.com.tr/PostBoxService.svc?wsdl"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYHELP="$HERE/elogo_ws.py"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*"; exit 1; }

# ── uv/python runtime (root-suz /config/.local) ─────────────────────────────
setup_runtime(){
  [ -f /config/.local/bin/env ] && . /config/.local/bin/env 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
  command -v uv >/dev/null 2>&1 || die "uv yok (runtime bootstrap eksik)"
}
run_py(){ uv run --with zeep --with lxml python3 "$PYHELP" "$@"; }

# ── VAULT-FIRST: sırrı ÖNCE merkezî vault'tan tazele (vault-cek seam · değer-basmaz) ────────
# vault-cek get <KEY> → cortex-access.env'e (600) yazar (değer stdout'a DÜŞMEZ); vault yok/erişilemez
# → sessiz-geç, ENV_FILE fallback korunur (fail-hard YOK). Re-entrancy-guard: vault-cek backbone'u bu
# skill'i çağırırsa (railway-erisim ↔ vault-cek) sonsuz-döngü olmasın diye VAULT_CEK_INFLIGHT ile kes.
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
_vault_parite(){  # _vault_parite <kimlik-durumu>  — vault-dahil 3-durum parite satırı
  local fb="yok"; [ -f "$ENV_FILE" ] && fb="var"
  echo "  vault:$(_vault_status) · env-fallback:${fb} · token-geçerli:${1}"
}

# ── kimlik yükleme (DEĞERİ EKRANA BASMADAN) ─────────────────────────────────
load_creds(){
  # VAULT-FIRST: Infisical/vault seam → cortex-access.env tazele (sonra dosyadan source = vault kazanır)
  _vault_refresh ELOGO_WS_USER ELOGO_WS_PASSWORD ELOGO_WS_WSDL
  if [ -f "$ENV_FILE" ]; then
    set -a
    . <(grep -E '^export ELOGO_WS_(USER|PASSWORD|WSDL)=' "$ENV_FILE" 2>/dev/null) || true
    set +a
  fi
  export ELOGO_WS_WSDL="${ELOGO_WS_WSDL:-$WSDL_DEFAULT}"
}
have_creds(){ [ -n "${ELOGO_WS_USER:-}" ] && [ -n "${ELOGO_WS_PASSWORD:-}" ]; }

# ── env'e sır yaz (dup'ı çıkar, 600, DEĞER görünmez) ────────────────────────
put_env(){  # put_env KEY VALUE
  local key="$1" val="$2" tmp
  mkdir -p "$(dirname "$ENV_FILE")"; touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  tmp="$(mktemp)"
  grep -v -E "^export ${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  printf 'export %s=%q\n' "$key" "$val" >> "$tmp"
  mv "$tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"
}

# ═══ komutlar ═══════════════════════════════════════════════════════════════

cmd_login(){  # bir-kerelik: WS kullanıcı + şifre GİZLİ oku → doğrula → kaydet
  cat <<'EOF'
e-Logo Web Servis kullanıcısı ile giriş (bir kerelik).
ÖNERİ: Portalda özel bir alt-kullanıcı aç (efatura.elogo.com.tr → Ayarlar →
Bağlantı (Web Servis) Kullanıcısı → Yeni Ekle), ana insan-şifreni WS'e KOYMA.
Girdiler GİZLİ okunur (ekrana/geçmişe/argv'ye düşmez).
EOF
  local user pw
  read -rp  'WS Kullanıcı Kodu : ' user
  read -rsp 'WS Şifre          : ' pw; echo
  [ -n "$user" ] && [ -n "$pw" ] || die "kullanıcı/şifre boş"
  setup_runtime
  ELOGO_WS_USER="$user" ELOGO_WS_PASSWORD="$pw" ELOGO_WS_WSDL="${ELOGO_WS_WSDL:-$WSDL_DEFAULT}" \
    run_py doctor >/dev/null 2>&1 \
    || { red "✗ giriş doğrulanamadı (kullanıcı/şifre hatalı ya da WSDL erişilemedi)"; exit 1; }
  put_env ELOGO_WS_USER "$user"
  put_env ELOGO_WS_PASSWORD "$pw"
  put_env ELOGO_WS_WSDL "${ELOGO_WS_WSDL:-$WSDL_DEFAULT}"
  unset pw
  grn "✓ giriş doğrulandı → $ENV_FILE (600)"
  echo "  Kanonik pointer öner: Nexus/_agents/credentials.yaml → [SIR: … → elogo-ws-user/pass]"
}

cmd_doctor(){  # 3-durum: yeşil (geçerli) / kırmızı (fail) / doğrulanmadı
  setup_runtime; load_creds
  have_creds || { ylw "• doğrulanmadı — kimlik yok. Önce: bash $0 login"; _vault_parite "doğrulanmadı"; exit 4; }
  if run_py doctor >/dev/null 2>&1; then
    grn "✓ e-Logo WS erişimi GEÇERLİ (kullanıcı: ${ELOGO_WS_USER})"
    _vault_parite "yeşil"
    exit 0
  else
    red "✗ e-Logo WS girişi BAŞARISIZ (şifre değişmiş/rotate olmuş olabilir). Yenile: bash $0 login"
    _vault_parite "kırmızı"
    exit 1
  fi
}

need_creds(){ setup_runtime; load_creds; have_creds || die "kimlik yok. Önce: bash $0 login"; }

cmd_status(){ need_creds; [ -n "${1:-}" ] || die "kullanım: $0 status <ETTN>"; run_py status "$1"; }

cmd_get(){    # get <ETTN> [out.pdf] — kesilmiş e-Arşiv PDF'ini indir (salt-okur)
  need_creds; [ -n "${1:-}" ] || die "kullanım: $0 get <ETTN> [out.pdf]"
  local out="${2:-fatura-$1.pdf}"
  run_py get "$1" "$out"
}

cmd_xml(){    # xml <ETTN> [out.xml] — UBL XML indir (salt-okur)
  need_creds; [ -n "${1:-}" ] || die "kullanım: $0 xml <ETTN> [out.xml]"
  local out="${2:-fatura-$1.xml}"
  run_py xml "$1" "$out"
}

usage(){ cat <<EOF
e-Logo erişim CLI — salt-okur, kuyruk-güvenli.
  $0 login            Bir-kerelik gizli giriş (WS kullanıcı+şifre → doğrula → kaydet)
  $0 doctor           3-durum sağlık kontrolü (yeşil/kırmızı/doğrulanmadı)
  $0 status <ETTN>    Fatura durumu (getInvoiceStatus)
  $0 get <ETTN> [f]   Kesilmiş e-Arşiv PDF'ini indir
  $0 xml <ETTN> [f]   UBL XML indir
Not: TASLAK (kesilmemiş) faturalar WS'te YOKTUR → get/xml 'NOTFOUND' döner.
EOF
}

case "${1:-}" in
  login)  cmd_login ;;
  doctor) cmd_doctor ;;
  status) shift; cmd_status "$@" ;;
  get)    shift; cmd_get "$@" ;;
  xml)    shift; cmd_xml "$@" ;;
  ""|-h|--help|help) usage ;;
  *) red "bilinmeyen komut: $1"; usage; exit 1 ;;
esac
