#!/usr/bin/env bash
# cloudtop · pCloud erişim CLI — dosya listele/yükle/indir/public-link işlerini PANELE
# GİRMEDEN, saf API (curl+jq) ile yap.
# ─────────────────────────────────────────────────────────────────────────────
# NEDEN: Onlarca ajan pCloud API'sine ihtiyaç duyuyor; her seferinde "credential nerede?"
# sormak ANGARYA. Bu CLI o işi tek-sefer + kalıcı-token ile ajana devreder.
#
# GERÇEK KISIT (dürüstlük): pCloud OAuth access_token'ı PROGRAMATİK ÜRETİLEMEZ — dashboard/
# OAuth-app akışıyla alınır (mint: MMEpanel/docs/pcloud-oauth-token-mint.md; authorize host =
# e.pcloud.com/oauth2/authorize — my.pcloud.com "Invalid client_id" verir, EU-app). Token
# KALICI (expire-yok) + TFA-bağımsız. Bu yüzden doctor token yoksa "doğrulanmadı" der, uydurma-
# yeşil YOKtur; token'ı mint-doc'tan alıp `set-token` ile verirsin.
#
# API KONTRATI (kaynak: MMEpanel/backend/services/integrations/pcloud.py):
#   host   = https://{region}.pcloud.com   (region=eapi EU-default / api US)
#   auth   = QUERY-PARAM (Bearer DEĞİL): OAuth→access_token= , legacy→auth=
#   R7     = Arçelik iç-belgeleri Public-Folder DIŞINDA (getfilelink public-folder'da 2284 döner).
#
# Sır-hijyeni: DEĞER asla stdout'a/log'a/geçmişe/ARGV'ye düşmez. Token query-param olduğundan
# curl'e `--config -` (stdin heredoc) ile geçirilir → `ps`/argv'de görünmez. Store (yerinde-oku,
# kopyalama YOK): ~/.config/cortex-access.env → yoksa /config/projects/MMEpanel/.env.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
MMEPANEL_ENV="${MMEPANEL_ENV:-/config/projects/MMEpanel/.env}"
REGION="${PCLOUD_REGION:-eapi}"                 # load_creds sonrası gerçek değerle güncellenir

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*"; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl yok"
command -v jq   >/dev/null 2>&1 || die "jq yok"

# ── VAULT-FIRST: sırrı ÖNCE merkezî vault'tan tazele (vault-cek seam · değer-basmaz) ────────
# vault-cek get <KEY> → cortex-access.env'e (600) yazar (değer stdout'a DÜŞMEZ); vault yok/erişilemez
# → sessiz-geç, ENV_FILE + MMEpanel/.env fallback zinciri korunur (fail-hard YOK). Re-entrancy-guard:
# vault-cek backbone'u bu skill'i çağırırsa (railway-erisim ↔ vault-cek) sonsuz-döngü olmasın diye kes.
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

# ── kimlik yükleme (DEĞERİ EKRANA BASMADAN, yerinde-oku) ────────────────────
# Önce vault→cortex-access.env, sonra cortex-access.env, token boşsa MMEpanel/.env — yalnız PCLOUD_* source.
load_creds(){
  # VAULT-FIRST: Infisical/vault seam → cortex-access.env tazele (sonra dosya-zinciri source = vault kazanır)
  _vault_refresh PCLOUD_ACCESS_TOKEN PCLOUD_AUTH_TOKEN PCLOUD_REGION PCLOUD_FOLDER_ID PCLOUD_PUBLIC_ID
  local f
  for f in "$ENV_FILE" "$MMEPANEL_ENV"; do
    [ -f "$f" ] || continue
    set -a
    # hem `export KEY=` hem düz `KEY=` biçimini yakala (MMEpanel/.env düz yazar)
    . <(grep -E '^(export )?PCLOUD_(ACCESS_TOKEN|AUTH_TOKEN|REGION|FOLDER_ID|PUBLIC_ID)=' "$f" 2>/dev/null \
          | sed -E 's/^export //') || true
    set +a
    # token bulunduysa daha fazla dosyaya bakma (cortex-access.env önceliği)
    [ -n "${PCLOUD_ACCESS_TOKEN:-}" ] || [ -n "${PCLOUD_AUTH_TOKEN:-}" ] && break
  done
  REGION="${PCLOUD_REGION:-eapi}"
  HOST="https://${REGION}.pcloud.com"
}

have_token(){ [ -n "${PCLOUD_ACCESS_TOKEN:-}" ] || [ -n "${PCLOUD_AUTH_TOKEN:-}" ]; }

# ── auth param (printf builtin → argv'ye düşmez) ────────────────────────────
_auth_pair(){
  if   [ -n "${PCLOUD_ACCESS_TOKEN:-}" ]; then printf 'access_token=%s' "$PCLOUD_ACCESS_TOKEN"
  elif [ -n "${PCLOUD_AUTH_TOKEN:-}"  ]; then printf 'auth=%s'         "$PCLOUD_AUTH_TOKEN"
  fi
}

# ── değer-güvenli GET: token'ı ARGV'ye koymadan --config - stdin'ine göm ────
api(){  # api <method> [k=v ...]
  local m="$1"; shift
  local q kv; q="$(_auth_pair)"
  for kv in "$@"; do q="${q}&${kv}"; done
  curl -sS --config - <<CFG
url = "${HOST}/${m}?${q}"
CFG
}
pc_ok(){  echo "$1" | jq -e '.result == 0' >/dev/null 2>&1; }
pc_err(){ echo "$1" | jq -r '"\(.result) \(.error // "bilinmeyen hata")"' 2>/dev/null; }

# ── env'e sır yaz (dup çıkar, 600, DEĞER görünmez) — cf.sh'ten birebir ──────
put_env(){  # put_env KEY VALUE
  local key="$1" val="$2" tmp
  mkdir -p "$(dirname "$ENV_FILE")"; touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  tmp="$(mktemp)"
  grep -v -E "^export ${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  printf 'export %s=%s\n' "$key" "$val" >> "$tmp"
  mv "$tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"
}

# ═══ komutlar ═══════════════════════════════════════════════════════════════

cmd_doctor(){
  load_creds
  if ! have_token; then
    ylw "• pCloud kimliği DOĞRULANMADI — token bulunamadı."
    _vault_parite "doğrulanmadı"
    echo "  Bakılan store'lar:"
    echo "    - $ENV_FILE   (cortex-access.env)"
    echo "    - $MMEPANEL_ENV   (MMEpanel/.env fallback)"
    echo "  Token'ı gizli-yapıştır:  bash $0 set-token"
    echo "  Token yoksa mint-et    :  MMEpanel/docs/pcloud-oauth-token-mint.md"
    echo "    (authorize host = e.pcloud.com/oauth2/authorize · EU-app · token KALICI)"
    exit 2
  fi
  local mode="OAuth access_token"; [ -n "${PCLOUD_ACCESS_TOKEN:-}" ] || mode="legacy auth token"
  local u; u="$(api userinfo)"
  if ! pc_ok "$u"; then
    red "✗ token geçersiz/doğrulanamadı — fail: $(pc_err "$u")"
    echo "  (region=$REGION · $mode). Yeni token için: bash $0 set-token"
    exit 1
  fi
  # değer-güvenli: yalnız email-domain + quota-sayısı; token/tam-email basma.
  local email dom used quota usedgb totgb
  email="$(echo "$u" | jq -r '.email // ""')"
  dom="${email#*@}"; [ -n "$dom" ] && [ "$dom" != "$email" ] || dom="(gizli)"
  used="$(echo "$u"  | jq -r '.usedquota // 0')"
  quota="$(echo "$u" | jq -r '.quota // 0')"
  usedgb="$(awk -v b="$used"  'BEGIN{printf "%.1f", b/1073741824}')"
  totgb="$(awk  -v b="$quota" 'BEGIN{printf "%.1f", b/1073741824}')"
  grn "✓ kimlik geçerli ($mode · region=$REGION)"
  grn "✓ hesap : …@${dom}"
  grn "✓ kota  : ${usedgb} / ${totgb} GB kullanılıyor"
  _vault_parite "yeşil"
  echo; echo "Hazır. Örn:  bash $0 list 0    (root klasör)"
}

cmd_set_token(){  # OAuth access_token'ı GİZLİ yapıştır → cortex-access.env (600)
  echo "pCloud OAuth access_token yapıştır (gizli; ekrana/geçmişe düşmez)."
  echo "Token yoksa mint: MMEpanel/docs/pcloud-oauth-token-mint.md"
  local tok reg
  read -rsp 'PCLOUD_ACCESS_TOKEN: ' tok; echo
  [ -n "$tok" ] || die "boş token"
  read -rp  'Region [eapi(EU)/api(US), boş=eapi]: ' reg; reg="${reg:-eapi}"
  put_env PCLOUD_ACCESS_TOKEN "$tok"; unset tok
  put_env PCLOUD_REGION "$reg"
  grn "✓ token kaydedildi → $ENV_FILE (600). Doğrula: bash $0 doctor"
}

cmd_list(){  # list <folderid>
  local fid="${1:-}"
  [ -n "$fid" ] || die "kullanım: list <folderid>   (root=0)"
  load_creds; have_token || { cmd_doctor; return 1; }
  local r; r="$(api listfolder "folderid=${fid}")"
  pc_ok "$r" || die "listfolder başarısız — fail: $(pc_err "$r")"
  local n; n="$(echo "$r" | jq '.metadata.contents | length')"
  grn "✓ klasör $fid — $n öğe:"
  echo "$r" | jq -r '.metadata.contents[]? |
    "  \(if .isfolder then "📁" else "📄" end) \(.name)   [id:\(if .isfolder then .folderid else .fileid end)]\(if .isfolder then "" else "   \(.size)B" end)"'
}

cmd_upload(){  # upload <yerel-dosya> <folderid>
  local src="${1:-}" fid="${2:-}"
  [ -n "$src" ] && [ -n "$fid" ] || die "kullanım: upload <yerel-dosya> <folderid>"
  [ -f "$src" ] || die "dosya yok: $src"
  load_creds; have_token || die "token yok — bash $0 doctor"
  # URL+token stdin config'te; dosya-yolu (-F) argv'de (sır değil).
  local q; q="$(_auth_pair)"
  local r; r="$(curl -sS --config - -F "file=@${src}" <<CFG
url = "${HOST}/uploadfile?${q}&folderid=${fid}&renameifexists=1&nopartial=1"
CFG
)"
  pc_ok "$r" || die "upload başarısız — fail: $(pc_err "$r")"
  echo "$r" | jq -r '.metadata[]? | "✓ yüklendi: \(.name)   [fileid:\(.fileid)]   \(.size)B"'
}

cmd_download(){  # download <fileid> <hedef>
  local fid="${1:-}" dest="${2:-}"
  [ -n "$fid" ] && [ -n "$dest" ] || die "kullanım: download <fileid> <hedef>"
  load_creds; have_token || die "token yok — bash $0 doctor"
  local r; r="$(api getfilelink "fileid=${fid}")"
  pc_ok "$r" || die "getfilelink başarısız — fail: $(pc_err "$r")"
  local host path url
  host="$(echo "$r" | jq -r '.hosts[0]')"; path="$(echo "$r" | jq -r '.path')"
  url="https://${host}${path}"                        # geçici indirme linki — sır YOK, argv güvenli
  curl -sS -o "$dest" "$url" || die "indirme başarısız"
  grn "✓ indirildi → $dest ($(wc -c <"$dest") B)"
}

cmd_publink(){  # publink <fileid>
  local fid="${1:-}"
  [ -n "$fid" ] || die "kullanım: publink <fileid>"
  load_creds; have_token || die "token yok — bash $0 doctor"
  ylw "⚠ R7: Arçelik iç-belgeleri Public-Folder DIŞINDA tutulur. Public-Folder içi dosyada"
  ylw "  getpublink '2284' döner (public folder download-link üretemez) — bu normal, yeniden-konumla."
  local r; r="$(api getpublink "fileid=${fid}")"
  if pc_ok "$r"; then
    grn "✓ public link: $(echo "$r" | jq -r '.link // .code')"
  else
    die "getpublink başarısız — fail: $(pc_err "$r")   (2284 ise: dosya public-folder-DIŞINA taşınmalı)"
  fi
}

cmd_fingerprint(){  # tersine-çevrilemez kimlik-teyidi (DEĞER-yok)
  load_creds; have_token || die "token yok"
  local tok; tok="${PCLOUD_ACCESS_TOKEN:-$PCLOUD_AUTH_TOKEN}"
  printf 'token-fp: %s  (region=%s)\n' "$(printf %s "$tok" | sha256sum | cut -c1-12)" "$REGION"
}

cmd_help(){ sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-doctor}" in
  doctor|verify) cmd_doctor ;;
  set-token)     cmd_set_token ;;
  list)          shift; cmd_list "$@" ;;
  upload)        shift; cmd_upload "$@" ;;
  download)      shift; cmd_download "$@" ;;
  publink)       shift; cmd_publink "$@" ;;
  fingerprint)   cmd_fingerprint ;;
  help|-h|--help) cmd_help ;;
  *) die "bilinmeyen komut: $1  (doctor|set-token|list <fid>|upload <f> <fid>|download <fid> <dst>|publink <fid>|fingerprint)" ;;
esac
