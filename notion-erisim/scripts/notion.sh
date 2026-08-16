#!/usr/bin/env bash
# cloudtop · Notion erişim CLI — SALT-OKUR. Veritabanı listele/sorgula, sayfa oku, dosya (ruhsat/
# muayene görseli) indir. Panele girmeden, saf API (curl+jq).
# ─────────────────────────────────────────────────────────────────────────────
# KAPSAM (Sultan-onaylı · SİNAN talebi 2026-08-15): YALNIZ OKUMA. Yazma fiili YOKTUR
#   (create/update/delete/append). Notion Sultan'ın kendi çalışma alanı; ajan yazması
#   karışıklık üretir. Yazma gerekirse ayrı bir irade + ayrı sürüm ister.
#   ⚠️ `db-query` bir POST'tur ama Notion'da POST /databases/{id}/query = OKUMA ucudur
#      (filtre/sıralama gövdede taşınır). Tek istisna budur.
#
# GERÇEK KISIT (dürüstlük): Notion internal-integration token'ı PROGRAMATİK ÜRETİLEMEZ —
#   notion.so/profile/integrations sayfasından (Sultan-eli) alınır. Ayrıca token geçerli olsa
#   bile ilgili sayfa/veritabanı entegrasyona PAYLAŞILMAMIŞSA API `object_not_found` döner.
#   Bu skill o iki durumu AYIRT ederek raporlar (uydurma-yeşil YOK).
#
# API KONTRATI (Notion API 2022-06-28):
#   host    = https://api.notion.com
#   auth    = Authorization: Bearer <token>   → stdin `curl -K -` ile verilir (argv'ye DÜŞMEZ)
#   🔴 ZORUNLU: `Notion-Version: 2022-06-28` başlığı. YOKSA 400 döner ve hata mesajı
#      "jeton geçersiz" gibi okunur — saatlerce yanlış yerde aranan tuzak budur.
#   sayfalama = yanıt `has_more` + `next_cursor`; sonraki istek `start_cursor` ile sürer.
#   dosya    = files-tipi alanın `file.url`'i İMZALI ve SÜRELİ (~1 saat). Alındığı anda
#              indirilmeli; diske/loga YAZILMAZ.
#
# Sır-hijyeni: token DEĞERİ stdout/log/geçmiş/ARGV'ye ASLA düşmez. Vault-first:
#   vault-cek get NOTION_TOKEN → cortex-access.env (600) fallback. Vault yoksa sessiz-geç.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
API_HOST="${NOTION_API_HOST:-https://api.notion.com}"
NOTION_VERSION="${NOTION_API_VERSION:-2022-06-28}"   # 🔴 değiştirme: 2022-06-28 kararlı sürüm

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*"; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl yok"
command -v jq   >/dev/null 2>&1 || die "jq yok"

# ── VAULT-FIRST (pcloud-erisim/cf.sh omurgası · değer-basmaz · fail-hard YOK) ────────────────
VAULT_CEK="${VAULT_CEK_BIN:-$HOME/.claude/skills/vault-cek/scripts/vault-cek.sh}"
_vault_refresh(){
  [ -n "${VAULT_CEK_INFLIGHT:-}" ] && return 0
  [ -f "$VAULT_CEK" ] || return 0
  local k
  for k in "$@"; do
    VAULT_CEK_INFLIGHT=1 CORTEX_ACCESS_ENV="$ENV_FILE" bash "$VAULT_CEK" get "$k" >/dev/null 2>&1 || true
  done
}
_vault_status(){
  if [ -n "${VAULT_CEK_INFLIGHT:-}" ]; then printf 'atlandı(re-entrancy)'; return; fi
  [ -f "$VAULT_CEK" ] || { printf 'doğrulanmadı(vault-cek-yok)'; return; }
  if VAULT_CEK_INFLIGHT=1 bash "$VAULT_CEK" doctor >/dev/null 2>&1; then printf 'yeşil'
  else printf 'kırmızı(fallback-aktif)'; fi
}
_vault_parite(){  # _vault_parite <token-durumu>
  local fb="yok"; [ -f "$ENV_FILE" ] && fb="var"
  echo "  vault:$(_vault_status) · env-fallback:${fb} · token-geçerli:${1}"
}

load_creds(){
  _vault_refresh NOTION_TOKEN
  [ -f "$ENV_FILE" ] || return 0
  set -a
  . <(grep -E '^(export )?NOTION_TOKEN=' "$ENV_FILE" 2>/dev/null | sed -E 's/^export //') || true
  set +a
}
have_token(){ [ -n "${NOTION_TOKEN:-}" ]; }

# ── değer-güvenli çağrı: Authorization başlığı ARGV'de DEĞİL, `curl -K -` stdin'inde ─────────
# _api <GET|POST> <yol> [gövde-json]
_api(){
  local m="$1" path="$2" body="${3:-}"
  if [ "$m" = "POST" ]; then
    # 🔴 TUZAK (canlı yakalandı): gövdeyi `printf … | curl --data-binary @-` ile veremezsin —
    #    stdin'i heredoc (`-K -`) tutar, gövde SESSİZCE BOŞ gider: Notion 200 döner ama filtre ve
    #    start_cursor uygulanmaz → sayfalama sonsuz döner. Gövde geçici DOSYADAN verilir (sır değil).
    local bf; bf="$(mktemp)"; printf '%s' "$body" > "$bf"
    curl -sS -K - --data-binary "@${bf}" <<CFG
url = "${API_HOST}${path}"
request = "POST"
header = "Authorization: Bearer ${NOTION_TOKEN}"
header = "Notion-Version: ${NOTION_VERSION}"
header = "Content-Type: application/json"
CFG
    rm -f "$bf"
  else
    curl -sS -K - <<CFG
url = "${API_HOST}${path}"
header = "Authorization: Bearer ${NOTION_TOKEN}"
header = "Notion-Version: ${NOTION_VERSION}"
CFG
  fi
}
n_err(){ echo "$1" | jq -r 'if .object=="error" then "\(.status // "?")/\(.code // "?") \(.message // "")" else "" end' 2>/dev/null; }
n_ok(){  [ -z "$(n_err "$1")" ]; }
_need_token(){
  load_creds
  have_token || { ylw "• Notion kimliği DOĞRULANMADI — token yok."; echo "  Çöz: bash $0 doctor"; exit 2; }
}
# başlık metnini title/rich_text dizisinden düzleştir
_plain(){ jq -r '[.. | objects | select(has("plain_text")) | .plain_text] | join("")' ; }

# ═══ komutlar ════════════════════════════════════════════════════════════════

cmd_doctor(){
  load_creds
  if ! have_token; then
    ylw "• Notion kimliği DOĞRULANMADI — token bulunamadı (uydurma-yeşil YOK)."
    _vault_parite "doğrulanmadı"
    echo "  Bakılan yerler:"
    echo "    - vault-cek get NOTION_TOKEN   (secret/<kiracı>/NOTION_TOKEN)"
    echo "    - $ENV_FILE   (cortex-access.env, 600)"
    echo "  Token programatik ÜRETİLEMEZ → Sultan-eli: notion.so/profile/integrations"
    exit 2
  fi
  local r; r="$(_api GET /v1/users/me)"
  if ! n_ok "$r"; then
    red "✗ kimlik doğrulanamadı — fail: $(n_err "$r")"
    echo "  Not: 400/validation_error genelde EKSİK 'Notion-Version' başlığıdır, geçersiz token DEĞİL."
    _vault_parite "kırmızı"
    exit 1
  fi
  local ad tip
  ad="$(echo "$r"  | jq -r '.name // .bot.owner.type // "(adsız)"')"
  tip="$(echo "$r" | jq -r '.type // "?"')"
  grn "✓ kimlik geçerli (tip=$tip · ad=$ad · API-sürümü=$NOTION_VERSION)"
  # erişilebilir içerik var mı — token geçerli ama HİÇBİR SAYFA PAYLAŞILMAMIŞ olabilir (bilinen tuzak)
  local s n; s="$(_api POST /v1/search '{"page_size":1}')"
  if n_ok "$s"; then
    n="$(echo "$s" | jq -r '.results | length')"
    if [ "$n" -gt 0 ]; then grn "✓ paylaşım: entegrasyona en az 1 nesne paylaşılmış"
    else ylw "• paylaşım: token geçerli ama entegrasyona HİÇBİR sayfa/veritabanı paylaşılmamış"
         ylw "  (Notion'da sayfa → ••• → Connections → entegrasyonu ekle)"; fi
  else
    ylw "• paylaşım durumu doğrulanmadı — search fail: $(n_err "$s")"
  fi
  _vault_parite "yeşil"
  echo; echo "SALT-OKUR. Örn:  bash $0 db-list"
}

cmd_db_list(){  # db-list [--limit N] [--sayfa-tavani N]  — erişilebilen veritabanları (sayfalamalı)
  local limit=200 tavan=20
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit)         limit="${2:-200}"; shift 2 ;;
      --sayfa-tavani)  tavan="${2:-20}";  shift 2 ;;
      *) die "kullanım: db-list [--limit N] [--sayfa-tavani N]" ;;
    esac
  done
  _need_token
  local cursor="" body out toplam=0 sayfa=0 kesildi=""
  local gor cur_gor; gor="$(mktemp)"; cur_gor="$(mktemp)"
  trap 'rm -f "$gor" "$cur_gor"' RETURN
  while :; do
    if [ -n "$cursor" ]; then body="$(jq -nc --arg c "$cursor" '{filter:{property:"object",value:"database"},page_size:100,start_cursor:$c}')"
    else                       body='{"filter":{"property":"object","value":"database"},"page_size":100}'; fi
    out="$(_api POST /v1/search "$body")"
    n_ok "$out" || die "search başarısız — fail: $(n_err "$out")"
    sayfa=$((sayfa+1))
    # dedupe: Notion search sayfalamasında AYNI nesne birden çok sayfada dönebilir (canlı gözlendi)
    local satir id
    while IFS=$'\t' read -r id satir; do
      grep -qxF "$id" "$gor" && continue
      printf '%s\n' "$id" >> "$gor"
      printf '  🗄  %s   [id:%s]\n' "${satir:-(başlıksız)}" "$id"
      toplam=$((toplam+1))
      [ "$toplam" -ge "$limit" ] && break
    done < <(echo "$out" | jq -r '.results[]? | "\(.id)\t\(([.title[]?.plain_text] | join("")))"')
    if [ "$toplam" -ge "$limit" ]; then kesildi="--limit $limit doldu"; break; fi
    [ "$(echo "$out" | jq -r '.has_more')" = "true" ] || break
    cursor="$(echo "$out" | jq -r '.next_cursor')"
    [ -n "$cursor" ] && [ "$cursor" != "null" ] || break
    # imleç-döngüsü kalkanı: aynı imleç ikinci kez gelirse sonsuz-döngü olurdu → dürüstçe kes
    if grep -qxF "$cursor" "$cur_gor"; then kesildi="imleç tekrar etti (Notion search döngüsü)"; break; fi
    printf '%s\n' "$cursor" >> "$cur_gor"
    if [ "$sayfa" -ge "$tavan" ]; then kesildi="sayfa-tavanı $tavan"; break; fi
  done
  grn "✓ $toplam veritabanı (tekil) · $sayfa istek"
  [ -n "$kesildi" ] && ylw "• LİSTE KESİLDİ: $kesildi — tamamı DEĞİL (artır: --limit / --sayfa-tavani)"
  [ "$toplam" -eq 0 ] && ylw "  (0 = sayfa entegrasyona paylaşılmamış olabilir — Connections'ı kontrol et)"
  return 0
}

cmd_db_query(){  # db-query <db_id> [--limit N] [--json]
  local db="" limit=0 asjson=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit) limit="${2:-0}"; shift 2 ;;
      --json)  asjson=1; shift ;;
      *) db="$1"; shift ;;
    esac
  done
  [ -n "$db" ] || die "kullanım: db-query <db_id> [--limit N] [--json]"
  _need_token
  local cursor="" body out n toplam=0 sayfa=0
  local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
  while :; do
    if [ -n "$cursor" ]; then body="$(jq -nc --arg c "$cursor" '{page_size:100,start_cursor:$c}')"
    else                       body='{"page_size":100}'; fi
    out="$(_api POST "/v1/databases/${db}/query" "$body")"
    n_ok "$out" || die "db-query başarısız — fail: $(n_err "$out")   (object_not_found ise: veritabanı entegrasyona paylaşılmamış)"
    echo "$out" | jq -c '.results[]?' >> "$tmp"
    n="$(echo "$out" | jq '.results | length')"; toplam=$((toplam+n)); sayfa=$((sayfa+1))
    if [ "$limit" -gt 0 ] && [ "$toplam" -ge "$limit" ]; then
      if [ "$asjson" -eq 1 ]; then ylw "• --limit $limit uygulandı — sonuç KESİLDİ (tamamı için --limit verme)" >&2
      else                         ylw "• --limit $limit uygulandı — sonuç KESİLDİ (tamamı için --limit verme)"; fi
      break
    fi
    [ "$(echo "$out" | jq -r '.has_more')" = "true" ] || break
    cursor="$(echo "$out" | jq -r '.next_cursor')"
    [ -n "$cursor" ] && [ "$cursor" != "null" ] || break
  done
  if [ "$asjson" -eq 1 ]; then cat "$tmp"; else
    # her satır: başlık-alanı + sayfa-id (alan dökümü page-get ile)
    jq -r '"  • \([.properties[]? | select(.type=="title") | .title[]?.plain_text] | join("") // "(başlıksız)")   [page:\(.id)]"' < "$tmp"
  fi
  # --json modunda özet STDERR'e gider — stdout saf JSONL kalsın (jq'ya boru güvenli)
  if [ "$asjson" -eq 1 ]; then grn "✓ $toplam satır · $sayfa istek (sayfalama: has_more/next_cursor)" >&2
  else                         grn "✓ $toplam satır · $sayfa istek (sayfalama: has_more/next_cursor)"; fi
}

cmd_page_get(){  # page-get <page_id> [--json]
  local pid="${1:-}" asjson="${2:-}"
  [ -n "$pid" ] || die "kullanım: page-get <page_id> [--json]"
  _need_token
  local r; r="$(_api GET "/v1/pages/${pid}")"
  n_ok "$r" || die "page-get başarısız — fail: $(n_err "$r")   (object_not_found ise: sayfa entegrasyona paylaşılmamış)"
  if [ "$asjson" = "--json" ]; then echo "$r" | jq .; return 0; fi
  echo "$r" | jq -r '
    "sayfa : \(.id)",
    "url   : \(.url // "-")",
    "güncel: \(.last_edited_time // "-")",
    "alanlar:",
    (.properties | to_entries[] | "  \(.key) [\(.value.type)] = " + (
      .value |
      if   .type=="title"      then ([.title[]?.plain_text]|join(""))
      elif .type=="rich_text"  then ([.rich_text[]?.plain_text]|join(""))
      elif .type=="date"       then (.date.start // "-")
      elif .type=="select"     then (.select.name // "-")
      elif .type=="multi_select" then ([.multi_select[]?.name]|join(", "))
      elif .type=="number"     then (.number|tostring)
      elif .type=="checkbox"   then (.checkbox|tostring)
      elif .type=="formula"    then ((.formula.string // .formula.number // .formula.boolean // .formula.date.start // "-") | tostring)
      elif .type=="files"      then (([.files[]?.name] | join(", ")) + "  (" + ((.files | length) | tostring) + " dosya)")
      elif .type=="people"     then ([.people[]?.name]|join(", "))
      elif .type=="url"        then (.url // "-")
      else "…" end))'
}

cmd_file_download(){  # file-download <page_id> <alan_adı> <hedef_dizin>
  local pid="${1:-}" alan="${2:-}" dizin="${3:-}"
  [ -n "$pid" ] && [ -n "$alan" ] && [ -n "$dizin" ] || die "kullanım: file-download <page_id> <alan_adı> <hedef_dizin>"
  [ -d "$dizin" ] || mkdir -p "$dizin" || die "hedef dizin açılamadı: $dizin"
  _need_token
  local r; r="$(_api GET "/v1/pages/${pid}")"
  n_ok "$r" || die "sayfa okunamadı — fail: $(n_err "$r")"
  local tip; tip="$(echo "$r" | jq -r --arg a "$alan" '.properties[$a].type // "yok"')"
  [ "$tip" = "yok" ]   && die "böyle bir alan yok: '$alan'   (alanları görmek için: $0 page-get $pid)"
  [ "$tip" = "files" ] || die "'$alan' alanı files tipinde değil (tip=$tip) — indirilecek dosya yok"
  local n; n="$(echo "$r" | jq -r --arg a "$alan" '.properties[$a].files | length')"
  [ "$n" -gt 0 ] || { ylw "• '$alan' alanı boş — indirilecek dosya yok"; return 0; }
  local i ad tip url hedef rc indirilen=0
  for i in $(seq 0 $((n-1))); do
    ad="$(echo "$r"  | jq -r --arg a "$alan" --argjson i "$i" '.properties[$a].files[$i].name // "dosya"')"
    tip="$(echo "$r" | jq -r --arg a "$alan" --argjson i "$i" '.properties[$a].files[$i].type // "?"')"
    # 🔴 file tipi = Notion-barındırmalı İMZALI+SÜRELİ URL (~1 saat): burada alınır, HEMEN indirilir,
    #    diske/loga YAZILMAZ. external tipi = dış CDN (süresiz olabilir) — ikisi de aynı yolla iner.
    url="$(echo "$r" | jq -r --arg a "$alan" --argjson i "$i" '.properties[$a].files[$i] | (.file.url // .external.url // "")')"
    [ -n "$url" ] || { red "  ✗ $ad — URL yok"; continue; }
    # ad bir URL ise yalnız son parçasını kullan (Notion external eklerinde ad=URL olabiliyor)
    case "$ad" in */*) ad="${ad##*/}"; ad="${ad%%\?*}";; esac
    [ -n "$ad" ] || ad="dosya-$i"
    hedef="$dizin/$(printf '%s' "$ad" | tr -c 'A-Za-z0-9._-' '_')"
    curl -sS -f -L -o "$hedef" "$url"; rc=$?
    if [ "$rc" -ne 0 ]; then
      rm -f "$hedef"
      red "  ✗ $ad — indirme başarısız (curl rc=$rc)."
      red "     İmzalı URL süresi (~1sa) dolmuş olabilir: komutu YENİDEN çalıştır (URL taze alınır)."
      continue
    fi
    grn "  ✓ $ad [$tip] → $hedef ($(wc -c <"$hedef") B)"
    indirilen=$((indirilen+1))
  done
  [ "$indirilen" -gt 0 ] || die "hiçbir dosya indirilemedi"
  grn "✓ $indirilen/$n dosya indirildi → $dizin"
}

cmd_fingerprint(){  # tersine-çevrilemez kimlik-teyidi (DEĞER-yok)
  load_creds; have_token || die "token yok"
  printf 'token-fp: %s  (api-sürümü=%s)\n' "$(printf %s "$NOTION_TOKEN" | sha256sum | cut -c1-12)" "$NOTION_VERSION"
}

cmd_help(){ sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-doctor}" in
  doctor|verify)  cmd_doctor ;;
  db-list)        shift; cmd_db_list "$@" ;;
  db-query)       shift; cmd_db_query "$@" ;;
  page-get)       shift; cmd_page_get "$@" ;;
  file-download)  shift; cmd_file_download "$@" ;;
  fingerprint)    cmd_fingerprint ;;
  help|-h|--help) cmd_help ;;
  *) die "bilinmeyen komut: $1  (SALT-OKUR: doctor|db-list|db-query <db_id> [--limit N] [--json]|page-get <page_id> [--json]|file-download <page_id> <alan> <dizin>|fingerprint)" ;;
esac
