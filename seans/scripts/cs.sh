#!/usr/bin/env bash
# cs — Claude Code seans yöneticisi
# Kullanım: cs [ls|rename|note|resume|info] [ref] [...]

set -euo pipefail

SESSIONS_DIR="/config/.claude/sessions"
PREFS="/config/.agent-dashboard/agent-prefs.json"
NOTES="/config/.agent-dashboard/session-notes.json"
PROJECTS_DIR="/config/.claude/projects"
API="http://127.0.0.1:8390"
# KATMAN-1: SERDAR-ailesi tek-kaynak roster (tmux-adı→rol). Yoksa/parse-fail → sessiz-atla (R2).
AILE_REGISTRY="${AILE_REGISTRY:-/config/projects/Nexus/_agents/handoff/aile-registry.yaml}"
EKIP_TAG="🏛 EKİP"   # resmi-ekip grup-etiketi öneki (grup en-üste pinlenir); byte-aynı grep için TEK kaynak
FEDERE_TAG="🛰 FİLO"  # federe/filo-hücresi grup-etiketi (EKİP'ten SONRA, projelerden ÖNCE pinlenir); byte-aynı grep için TEK kaynak
# KATMAN-2 filo-farkındalık: çok-sancak kanonik kayıt (SANCAK adres-defteri). cs host-side SALT-OKUR okur.
# Yoksa/parse-fail → sessiz-atla (izole-container'da doğru davranış). Kaynak: filo-registry.yaml (Nexus).
FEDERE_REGISTRY="${FEDERE_REGISTRY:-/config/projects/Nexus/_agents/filo/filo-registry.yaml}"
FEDERE_LOCAL_CELL="${FEDERE_LOCAL_CELL:-s01}"   # bu konteyner = ana-sancak → canlı-seansları zaten 🏛 EKİP altında; roster'da tekrarlama
# İ1 META-ONLY: izole-tenant satırları YALNIZCA ad+durum; başlık/transcript/görev-içeriği ASLA (mahremiyet
# fail-closed). İçerik-render dalı bu tenant'lar için YAPISAL olarak kapatılır. Bkz _is_isolated_tenant.
ISOLATED_TENANTS="${ISOLATED_TENANTS:-mmex vekatip medigate huma mihenk}"
# Registry parse cache (tek-koşuda bir kez) — set -u altında ön-init şart.
_registry_loaded=0; _registry_names=""; _registry_aile=""

# Claude launch bayrakları. Aile-ajanları OTONOM-PR yetkisi için bypassPermissions'ta
# başlamalı; --resume orijinal-seans-modunu geri-yükler (settings-default'u ALMAZ) →
# bayrak burada AÇIKÇA geçilmeli. Kapatmak/değiştirmek için: CS_CLAUDE_FLAGS='' cs resume …
# (bypassPermissions non-root gerektirir; root'ta claude bayrağı zaten reddeder.)
CS_CLAUDE_FLAGS="${CS_CLAUDE_FLAGS:---dangerously-skip-permissions}"

# ── L25-W7 ŞERİT (lane) farkındalığı ─────────────────────────────────────────
# Bir seans "kapı şeridinde" (cloudtop-kapi geçidi) doğduysa bu KALICI işaretlenir;
# pencere/tmux/süreç ölse de `cs resume` aynı şeridi geri kurar. İşaret YOKSA cs'in
# davranışı BYTE-AYNI kalır (tüm şerit-dalları erken `return 0` ile no-op'a düşer).
# İşaret evi: session-notes.json → .[<sid>].serit  (kullanıcı notunu KİRLETMEZ).
# Sır (KAPI_MASTER_KEY) işarette TUTULMAZ; her açılışta yerelden çözülür.
#
# 🔴 ŞERİT-AÇISI TEK ELDE (L25-F2): kapı şeridinin ORTAMINI (adres · anahtar ·
# keşif-bayrağı · model) cs KURMAZ — `kapi` başlatıcısına DEVREDER. cs burada
# ANTHROPIC_* gibi bir değişken adı YAZMAZ; `kapi cevre --yaz` 0600 bir dosyaya
# bloğu basar, cs onu source edip siler. Yarın başlatıcıya bir değişken eklenirse
# (`kapi`, `cs`, `ekip-ac`) üçü birden kazanır. Önceki hâlde cs yalnız iki değişken
# yazıyordu; CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY eksikti → `cs` ile açılan
# kapı-seansında `/model` menüsü kapıdaki modelleri HİÇ göstermiyordu (P1).
CS_SERIT="${CS_SERIT:-}"          # 'kapi' → bu koşuda yeni seans kapı şeridinde doğsun
_SERIT_RC=""; _SERIT_AD=""        # _serit_hazirla çıktıları (set -u altında ön-init şart)

# `kapi` başlatıcısının yolu. Sıra: KAPI_BIN → PATH → repo-göreli → kanonik checkout.
_KAPI_BIN_CACHE=""
_kapi_bin() {
  if [ -n "$_KAPI_BIN_CACHE" ]; then printf '%s' "$_KAPI_BIN_CACHE"; return 0; fi
  local c
  for c in "${KAPI_BIN:-}" \
           "$(command -v kapi 2>/dev/null || true)" \
           "$(dirname "$(readlink -f "${BASH_SOURCE[0]:-$0}")")/../../kapi/bin/kapi" \
           "/config/projects/cloudtop/infra/kapi/bin/kapi"; do
    [ -n "$c" ] && [ -x "$c" ] || continue
    _KAPI_BIN_CACHE="$c"; printf '%s' "$c"; return 0
  done
  return 1
}

# Kapı adresi — TEK kaynak başlatıcıdır (`kapi adres`). Başlatıcı yoksa son çare
# sabit; KAPI_BASE_URL tarihsel eşanlamlı olarak hâlâ kabul edilir.
_KAPI_URL_CACHE=""
_kapi_adres() {
  if [ -n "$_KAPI_URL_CACHE" ]; then printf '%s' "$_KAPI_URL_CACHE"; return 0; fi
  local k u=""
  if k=$(_kapi_bin); then u=$("$k" adres 2>/dev/null || true); fi
  [ -n "$u" ] || u="${KAPI_BASE_URL:-${KAPI_URL:-http://cloudtop-kapi:4000}}"
  _KAPI_URL_CACHE="$u"; printf '%s' "$u"
}

# Renkler (sadece TTY'de)
if [ -t 1 ]; then
  Y='\033[1;33m' G='\033[0;32m' C='\033[0;36m' DIM='\033[2m' B='\033[1m' Z='\033[0m'
else
  Y='' G='' C='' DIM='' B='' Z=''
fi

die() { printf 'cs: %s\n' "$*" >&2; exit 1; }
require_jq() { command -v jq >/dev/null 2>&1 || die "jq gerekli (apt install jq)"; }

# JSONL dosya yolu: cwd içindeki / → - olur
jsonl_path() {
  local sid="$1" cwd="$2"
  printf '%s/%s/%s.jsonl' "$PROJECTS_DIR" "$(printf '%s' "$cwd" | sed 's|/|-|g')" "$sid"
}

# Seans dosyasını session_id'den bul (canlı seanslar)
session_file_for_sid() {
  local sid="$1"
  # Tek grep (session json'ları compact: "sessionId":"<uuid>"). jq-per-file döngüsü
  # 8 dosyada ~300ms sürüyordu; bu ~140ms ve birçok sıcak yolda (preview/resolve) kullanılır.
  # Aynı sid için birden çok stale JSON olabilir → en YENİsini (mtime) seç (deterministik;
  # ugrep -l sırasız olabilir). xargs -r: eşleşme yoksa boş çıktı (ls'i tetiklemez).
  grep -lF "\"sessionId\":\"$sid\"" "$SESSIONS_DIR"/*.json 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1
}

# Herhangi bir seans için JSONL dosyasını bul (canlı + kapalı)
find_jsonl_for_sid() {
  local sid="$1"
  local f; f=$(session_file_for_sid "$sid") || true
  if [ -n "$f" ]; then
    local cwd jp; cwd=$(jq -r '.cwd // ""' "$f" 2>/dev/null || true)
    jp=$(jsonl_path "$sid" "$cwd")
    # Hızlı yol: canlı cwd'den hesaplanan konum. Varsa onu kullan. Canlı cwd
    # transcript konumuyla uyuşmuyorsa (farklı dizinden resume edilmiş) → genel aramaya düş.
    [ -f "$jp" ] && { printf '%s' "$jp"; return; }
  fi
  # Kapalı seans (veya hesaplanan yol bulunamadı): tüm proje dizinlerinde ara
  find "$PROJECTS_DIR" -maxdepth 2 -name "${sid}.jsonl" \
    -not -path '*/subagents/*' -not -path '*/tool-results/*' \
    -not -path '*/workflows/*' 2>/dev/null | head -1
}

# ── KATMAN-1: aile-registry (tmux-oturum-adı → resmi-ekip kimliği) ───────────
# Zero-dep (grep/awk; yq/python VARSAYMA). Dosya yoksa/parse-fail → sessiz-boş
# (KATMAN-1 atlanır, KATMAN-0 yine çalışır — izole-container'da doğru davranış). R2.
_load_registry() {
  [ "$_registry_loaded" = 1 ] && return 0
  _registry_loaded=1
  [ -f "$AILE_REGISTRY" ] || return 0
  _registry_aile=$(awk -F: '/^[[:space:]]*aile:/{v=$2; gsub(/[[:space:]"]/,"",v); print v; exit}' \
    "$AILE_REGISTRY" 2>/dev/null || true)
  # Her üye bloğu için:  tmuxbase \t id \t arz_adi   (yorum-güvenli; gerçek anahtarlar '#'siz satırda)
  _registry_names=$(awk '
    function flush(){ if(tmux!=""){ b=tmux; sub(/:.*/,"",b); printf "%s\t%s\t%s\n", b, id, arz } }
    /^[[:space:]]*-[[:space:]]*id:/ { flush(); id=""; arz=""; tmux="";
        v=$0; sub(/^[^:]*:[[:space:]]*/,"",v); gsub(/"/,"",v); sub(/[[:space:]]*#.*/,"",v); gsub(/[[:space:]]+$/,"",v); id=v; next }
    /^[[:space:]]*arz_adi:/ { v=$0; sub(/^[^:]*:[[:space:]]*/,"",v); gsub(/"/,"",v); sub(/[[:space:]]*#.*/,"",v); gsub(/[[:space:]]+$/,"",v); arz=v; next }
    /^[[:space:]]*tmux:/    { v=$0; sub(/^[^:]*:[[:space:]]*/,"",v); gsub(/"/,"",v); sub(/[[:space:]]*#.*/,"",v); gsub(/[[:space:]]+$/,"",v); tmux=v; next }
    END { flush() }
  ' "$AILE_REGISTRY" 2>/dev/null || true)
}

# tmux-oturum-adı → resmi-ekip görünen-adı. Öncelik: arz_adi > (tmux cc-<id> ise) id > tmux-adı.
# Eşleşme yoksa boş döner (= aile-üyesi değil). Değişmez: registry SALT-OKUR.
registry_name_for_tmux() {
  local sess="$1"; [ -n "$sess" ] || return 0
  _load_registry
  [ -n "$_registry_names" ] || return 0
  local line id arz
  line=$(printf '%s\n' "$_registry_names" | awk -F'\t' -v s="$sess" '$1==s{print; exit}')
  [ -n "$line" ] || return 0
  id=$(printf '%s' "$line" | cut -f2); arz=$(printf '%s' "$line" | cut -f3)
  if [ -n "$arz" ]; then printf '%s' "$arz"
  elif printf '%s' "$sess" | grep -qE '^cc-[0-9a-f]{6,}$'; then printf '%s' "$id"
  else printf '%s' "$sess"; fi
}

# Resmi-ekip grup-etiketi (col6 için; '/config/projects' ÖNEKSİZ → tek grup kovası).
_ekip_group_label() { _load_registry; printf '%s · %s' "$EKIP_TAG" "${_registry_aile:-EKİP}"; }

# ── İ1 META-ONLY maske + KATMAN-2 filo-farkındalık ──────────────────────────
# İzole-tenant tespiti (mahremiyet fail-closed): verili metin (cwd/proje/grup) bir izole-tenant'a
# ait mi? 0=izole (→ başlık/transcript render dalı KAPALI, yalnız ad+durum), 1=değil. Word-bounded
# eşleşme (MMEpanel'i mmex sanmaz). ISOLATED_TENANTS boşsa asla eşleşmez (güvenli-varsayılan).
_is_isolated_tenant() {
  local hay="${1:-}"; [ -n "$hay" ] || return 1
  local pat; pat=$(printf '%s' "$ISOLATED_TENANTS" | tr -s ' ' '|'); pat="${pat#|}"; pat="${pat%|}"
  [ -n "$pat" ] || return 1
  # Word-bounded + case-insensitive: "MMEx"/"Vekatip" izole sayılır; "MMEpanel" (mmex-değil) SAYILMAZ.
  printf '%s' "$hay" | grep -qwiE "$pat"
}

# ── KUTU-YEREL GÖRÜNÜRLÜK (mahremiyet kapısı · 2026-07-29, huzur vakası) ────────────
# NİÇİN: transcript'ler (/config/.claude/projects) TÜM kutuların gördüğü ORTAK mount'tadır.
# Tek-insanlı kutuda bu zararsızdı — her şey Sultan'ındı. huzur kutusunda ÜÇ insan çalışıyor
# (Sultan · Ayşenur · Yağmur); orada `cs ls` koşulduğunda TÜM filonun proje ve seans adları
# listeleniyordu (firsthand ölçüm 2026-07-29: huma/medigate/mihenk/mmex/vekatip + akar/nazir/
# s02/tellal/tez/Nexus). İ1 duvarları "kutu başına tek insan" varsayımıyla kurulmuştu; çok-insanlı
# kutuda o varsayım çöküyor.
#
# KURAL — İKİ KUTU SINIFI:
#   (1) KOKPİT kutusu (filo-kaydı görünür = cloudtop-code): filtre YOK, bugünkü davranış AYNEN.
#       Sultan'ın kendi kokpiti; her şey zaten onun, kısıtlamak sadece işini bozar.
#   (2) TENANT kutusu (filo-kaydı yok): YALNIZ bu kutuda proje kökü bulunan seans listelenir.
#
# ⚠️ NİÇİN KUTU-SINIFI ÖLÇÜTÜ (iki başarısız denemeden sonra, hepsi ÖLÇÜLDÜ):
#   1. deneme "cwd dizini var mı" → kokpitte 106 seansın 73'ü kayboldu (silinmiş worktree'ler).
#   2. deneme "proje kökü var mı" → 74 kayboldu; kök-sebep: seansların ÇOĞUNDA cwd kaydı YOK,
#      fail-closed hepsini gizliyordu.
#   Ders: "hiçbir şey değişmez" ölçülmeden söylenemez; iki kez söyledim, iki kez çürüdü.
#   Kutu-sınıfı ölçütü kokpitte bayt-aynılığı TASARIM GEREĞİ garanti eder (dal hiç girilmez).
#
# Sınıf ölçütü olarak filo-kaydı seçildi (proje-dizini sayısı gibi bir eşik DEĞİL): eşik keyfîdir,
# filo-kaydı ise "bu kutu filoyu görür" iddiasının zaten var olan tek kanonik işaretidir.
# FAIL-CLOSED: tenant kutusunda dizin bilinmiyorsa GİZLE — bilinmeyen ≠ güvenli (mahremiyet önce).
_filo_gorus_kutusu() { [ -f "$FEDERE_REGISTRY" ]; }

_kutuda_gorunur_mu() {
  _filo_gorus_kutusu && return 0
  local cwd="${1:-}"
  [ -n "$cwd" ] || return 1
  case "$cwd" in
    /config/projects/*)
      local kok="${cwd#/config/projects/}"; kok="${kok%%/*}"
      [ -n "$kok" ] && [ -d "/config/projects/$kok" ] ;;
    *) return 1 ;;   # /config/projects dışı → bu kutunun işi değil
  esac
}

# Filo-farkındalık roster satırları — load_sessions 7-kolon formatı:
#   idx \t sc \t sid \t name \t status \t group \t note
# İki kaynak: (A) filo-registry sancaklar (yerel ana-sancak HARİÇ) + (B) izole-tenant META-ONLY.
# TÜMÜ ad+durum-only (SALT-OKUR, içerik YOK). sid sentinel'i (__federe_*) resume-DIŞI + preview-maskeli.
# Zero-dep (awk; yq/python VARSAYMA).
#
# 🔒 FİLO-GÖRÜŞ KAPISI (2026-07-29): iki blok da YALNIZ filo-kaydı görünen kutuda basılır.
#    Eskiden (B) koşulsuzdu → izole-tenant adları (mmex/vekatip/…) tenant kutularında da
#    listeleniyordu. Ölçüt olarak tenant-dizini DEĞİL filo-kaydı seçildi: ana kutuda dizin adı
#    'MMEx', listedeki ad 'mmex' → dizin-kontrolü o satırı yanlışlıkla düşürürdü (harf-farkı tuzağı).
_federe_roster_rows() {
  local t
  # Filo-kaydı yoksa bu kutu filo-görüşlü DEĞİLDİR → hiçbir filo satırı basılmaz (fail-closed).
  [ -f "$FEDERE_REGISTRY" ] || return 0
  # (A) filo-registry sancaklar → cell_id \t ad \t durum. Yorum/tırnak-güvenli.
  if [ -f "$FEDERE_REGISTRY" ]; then
    local raw cid ad durum
    raw=$(awk '
      function val(   v){ v=$0; sub(/^[^:]*:[[:space:]]*/,"",v); gsub(/"/,"",v); sub(/[[:space:]]*#.*/,"",v); gsub(/[[:space:]]+$/,"",v); return v }
      function flush(){ if(cid!=""){ printf "%s\t%s\t%s\n", cid, ad, durum } }
      /^[[:space:]]*-[[:space:]]*cell_id:/ { flush(); cid=""; ad=""; durum=""; cid=val(); next }
      /^[[:space:]]*ad:/    { ad=val(); next }
      /^[[:space:]]*durum:/ { durum=val(); next }
      END { flush() }
    ' "$FEDERE_REGISTRY" 2>/dev/null || true)
    printf '%s\n' "$raw" | while IFS=$'\t' read -r cid ad durum; do
      [ -n "$cid" ] || continue
      [ "$cid" = "$FEDERE_LOCAL_CELL" ] && continue   # yerel ana-sancak → 🏛 EKİP altında zaten görünür
      printf '0\t\t__federe_%s__\t%s\t%s\t%s · %s\t\n' "$cid" "$ad" "${durum:-?}" "$FEDERE_TAG" "$cid"
    done
  fi
  # (B) izole-tenant'lar (registry-dışı bilinen konteynerler) — META-ONLY: yalnız ad+durum, içerik ASLA.
  for t in $ISOLATED_TENANTS; do
    printf '0\t\t__federe_%s__\t%s\t%s\t%s · izole\t\n' "$t" "$t" "izole" "$FEDERE_TAG"
  done
}

# ── Canlı-tespit: tmux + süreç tablosu (SIDECAR'DAN BAĞIMSIZ) ─────────────────
# Claude Code v2.1.202 native sidecar'ı (/config/.claude/sessions/<pid>.json) artık
# yazmıyor → cs'in eski canlı-tespiti her yerde kör. Aşağısı gerçek kaynağı (çalışan
# `claude` süreci + onu barındıran tmux oturumu) doğrudan okur. Bu, hem cs ls canlı
# listesini hem `cs resume`'un doğru tmux'a attach etmesini (fork yerine ayna) kurtarır.

# Her canlı `claude` için:  sid \t tmux_oturum(varsa, yoksa boş) \t cwd   (sid başına tek satır)
_live_sessions_raw() {
  command -v tmux >/dev/null 2>&1 || return 0
  local pid pp s args sid anc sess cwd
  declare -A pane2sess ppid_of
  while read -r pid s; do [ -n "$pid" ] && pane2sess[$pid]="$s"; done \
    < <(tmux list-panes -a -F '#{pane_pid} #{session_name}' 2>/dev/null)
  while read -r pid pp; do [ -n "$pid" ] && ppid_of[$pid]="$pp"; done \
    < <(ps -eo pid=,ppid= 2>/dev/null)
  while read -r pid args; do
    case "$args" in
      tmux\ *|*/tmux\ *) continue ;;   # `tmux new-session … claude …` sarmalayıcısını atla (gerçek claude ayrı pid)
      *claude*) ;;
      *) continue ;;
    esac
    # sid'i argv'den çıkar: `cs` ile başlatılan seanslar sid'i HER ZAMAN taşır
    # (cmd_new → `--session-id <uuid>`, cmd_resume → `--resume …/<uuid>.jsonl`).
    # SINIR: elle `claude` yazılarak (cs'siz) açılan seansta sid argv'de/env'de/açık-fd'de
    # yok → dışarıdan güvenilir eşlenemez (heuristik yanlış-attach riski). Çözüm: seansları
    # cs ile başlat. Bu sessizce atlanır (fork riski yerine düz-resume'a düşer).
    sid=""
    if [[ "$args" =~ --session-id[[:space:]]+([0-9a-fA-F-]{36}) ]]; then sid="${BASH_REMATCH[1]}"
    elif [[ "$args" =~ ([0-9a-fA-F-]{36})\.jsonl ]]; then sid="${BASH_REMATCH[1]}"; fi
    [ -n "$sid" ] || continue
    # bu claude pid'inden ppid zinciriyle yukarı çık → bir tmux pane_pid'ine denk gelirse oturumu bulduk
    sess=""; anc="$pid"
    while [ -n "$anc" ] && [ "$anc" -gt 1 ] 2>/dev/null; do
      if [ -n "${pane2sess[$anc]:-}" ]; then sess="${pane2sess[$anc]}"; break; fi
      anc="${ppid_of[$anc]:-}"
    done
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
    printf '%s\t%s\t%s\n' "$sid" "$sess" "$cwd"
  done < <(ps -eo pid=,args= 2>/dev/null) | awk -F'\t' '!seen[$1]++'
}

# $sid'i çalıştıran canlı claude'u barındıran tmux oturum adını yaz (adı ne olursa olsun; yoksa boş).
live_tmux_session_for_sid() {
  local sid="$1"; [ -n "$sid" ] || return 0
  _live_sessions_raw | awk -F'\t' -v s="$sid" '$1==s && $2!=""{print $2; exit}'
}

# $sid şu an bir yerde (tmux'ta VEYA raw terminalde) canlı mı? (0=canlı, 1=değil)
sid_is_live() {
  local sid="$1"; [ -n "$sid" ] || return 1
  _live_sessions_raw | awk -F'\t' -v s="$sid" '$1==s{f=1} END{exit f?0:1}'
}

# Sidecar boş/eksik olduğunda canlı listeyi tmux+ps'den, load_sessions'ın 7-kolon
# formatında üret:  idx \t short_code \t sid \t name \t status \t cwd \t note
_live_sessions_formatted() {
  local prefs notes_json
  prefs=$(cat "$PREFS" 2>/dev/null || printf '{}')
  notes_json=$([ -f "$NOTES" ] && cat "$NOTES" || printf '{}')
  local idx=0 sid sess cwd name gp sc note jp rname
  while IFS=$'\t' read -r sid sess cwd; do
    [ -n "$sid" ] || continue
    idx=$((idx+1))
    jp=$(jsonl_path "$sid" "$cwd")
    [ -f "$jp" ] || jp=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${sid}.jsonl" \
      -not -path '*/subagents/*' -not -path '*/tool-results/*' -not -path '*/workflows/*' 2>/dev/null | head -1)
    # İsim — R1: registry-eşleşme rol-adını DAYATIR (title'ı override); aksi hâlde KATMAN-0
    # yedek-zinciri: custom/ai-title > saved_auto_name > tmux-oturum-adı (aile-dışı seanslar).
    rname=$(registry_name_for_tmux "$sess")
    if [ -n "$rname" ]; then
      name="$rname"
    elif _is_isolated_tenant "$cwd"; then
      # İ1 META-ONLY: izole-tenant → başlık/transcript ASLA okunmaz; yalnız proje-adı (jsonl-title DEĞİL).
      name=$(_group_project "$sid" "$cwd" "${jp:-}"); [ -z "$name" ] && name="$sess"
    else
      name=""
      if [ -n "$jp" ] && [ -f "$jp" ]; then
        name=$(session_meta_from_jsonl "$jp" | cut -f1)
        [ "$name" = "(isimsiz)" ] && name=""
      fi
      [ -z "$name" ] && name=$(printf '%s' "$prefs" | jq -r --arg s "$sid" '.[$s].saved_auto_name // ""' 2>/dev/null || printf '')
      [ -z "$name" ] && name="$sess"
    fi
    # Grup — KATMAN-1: registry-üyesi → "🏛 EKİP · <aile>" (en-üst pinli); izole → "🛰 FİLO · izole"; değilse proje kovası.
    if [ -n "$rname" ]; then
      gp=$(_ekip_group_label)
    elif _is_isolated_tenant "$cwd"; then
      gp="$FEDERE_TAG · izole"
    else
      gp=$(_group_project "$sid" "$cwd" "${jp:-}"); gp="/config/projects/${gp:-(diğer)}"
    fi
    sc=$(printf '%s' "$prefs" | jq -r --arg s "$sid" '.[$s].short_code // ""' 2>/dev/null || printf '')
    note=$(printf '%s' "$notes_json" | jq -r --arg s "$sid" '.[$s].note // ""' 2>/dev/null || printf '')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$sc" "$sid" "$name" "" "$gp" "$note"
  done < <(_live_sessions_raw)
}

# JSONL dosyasından isim+cwd çıkar (tek okuma, TAB ayraçlı çıktı: name\tcwd)
session_meta_from_jsonl() {
  local f="$1"
  # Başından CWD için 2KB, sonundan isim için 8KB oku. tr -d '\0': bazı transcript'ler
  # null byte içerir → "ignored null byte" / "binary file matches" uyarılarını sustur.
  local data; data=$( { head -c 2048 "$f"; echo; tail -c 8192 "$f"; } 2>/dev/null | tr -d '\0')
  local name
  name=$(printf '%s\n' "$data" | grep -aF '"type":"custom-title"' | tail -1 | \
    jq -r '.customTitle // empty' 2>/dev/null || true)
  if [ -z "$name" ]; then
    name=$(printf '%s\n' "$data" | grep -aF '"type":"ai-title"' | tail -1 | \
      jq -r '.aiTitle // empty' 2>/dev/null || true)
  fi
  # Büyük/aktif seansta isim-kaydı 8KB tail penceresinin ötesine kayabilir (canlı-vaka:
  # 8MB dava-seansı, "2026/85" isim-kaydı sondan ~27KB içinde → "(isimsiz)" görünüp
  # cs'te bulunamadı). Hızlı-yol ıskaladıysa VE dosya head+tail (~10KB) penceresinden
  # büyükse tüm-dosyadan tara — tam-tarama maliyeti yalnız bu nadir durumda ödenir
  # (küçük dosyalar head+tail ile zaten tamamen kapsanır → gerçekten isimsiz).
  if [ -z "$name" ]; then
    local fsz; fsz=$(stat -c %s "$f" 2>/dev/null || echo 0)
    if [ "${fsz:-0}" -gt 10240 ]; then
      name=$(grep -aF '"type":"custom-title"' "$f" 2>/dev/null | tail -1 | \
        jq -r '.customTitle // empty' 2>/dev/null || true)
      if [ -z "$name" ]; then
        name=$(grep -aF '"type":"ai-title"' "$f" 2>/dev/null | tail -1 | \
          jq -r '.aiTitle // empty' 2>/dev/null || true)
      fi
    fi
  fi
  local cwd_val
  cwd_val=$(printf '%s\n' "$data" | grep -a '"cwd"' | head -1 | \
    jq -r '.cwd // empty' 2>/dev/null || true)
  printf '%s\t%s' "${name:-(isimsiz)}" "$cwd_val"
}

# Canlı seansları TSV olarak yükle
# Sütunlar: idx \t sc \t sid \t name \t status \t cwd \t note
# Bir seansın GRUP projesi: /config/projects altındaki ilk GERÇEK proje segmenti.
# cwd /config/projects/<X>/... ise X. cwd çıplak /config/projects (cd'siz resume) ya da
# dışarda ise → transcript klasör slug'ından (-config-projects-<proje>) türet + en uzun
# eşleşen gerçek dizini bul (çok-tireli adlar için: MMEpanel-auth-broker vb.).
_group_project() {
  local sid="$1" cwd="$2" jp="${3:-}" rem cand proj=""
  case "$cwd" in
    /config/projects/*) rem="${cwd#/config/projects/}"; rem="${rem%%/*}"
                        [ -n "$rem" ] && { printf '%s' "$rem"; return; } ;;
  esac
  { [ -n "$jp" ] && [ -f "$jp" ]; } || jp=$(jsonl_path "$sid" "$cwd" 2>/dev/null)
  [ -f "$jp" ] || jp=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${sid}.jsonl" \
      -not -path '*/subagents/*' -not -path '*/tool-results/*' -not -path '*/workflows/*' 2>/dev/null | head -1)
  if [ -n "$jp" ]; then
    local slug; slug=$(basename "$(dirname "$jp")")
    case "$slug" in -config-projects-*) rem="${slug#-config-projects-}" ;; *) rem="" ;; esac
    cand="$rem"
    while [ -n "$cand" ]; do
      [ -d "/config/projects/$cand" ] && { proj="$cand"; break; }
      case "$cand" in *-*) cand="${cand%-*}" ;; *) proj="$cand"; break ;; esac
    done
  fi
  printf '%s' "$proj"
}

load_sessions() {
  require_jq
  # ── Canlı ZEMİN = tmux+ps (çalışan gerçek claude; AİLE dahil, sidecar'dan bağımsız). ──
  # KÖK-DÜZELTME (2026-07, cs-EKİP-hijyeni): eski kod SESSIONS_DIR'de .json VARSA yalnız
  # o sidecar-seanslarını canlı sayıyordu → argv-sid'li ama sidecar'sız aile-oturumları
  # (motorSerdar/uiSerdar…) NE canlı NE kapalı görünüyordu (closed-listesi de raw-live_ids ile
  # onları dışlıyor → tamamen kayboluyorlardı). Artık raw ZEMİN; sidecar yalnız (a) status
  # (busy/idle/waiting) ZENGİNLEŞTİRMESİ + (b) raw'da OLMAYAN sidecar-only seansları EKLER.
  # Böylece resmi-ekip her sidecar-durumunda görünür (KATMAN-1 önkoşulu).
  local base; base=$(_live_sessions_formatted)
  # KATMAN-2 filo-farkındalık: federe/izole roster satırlarını ekle (ad+durum-only; İ1 META-ONLY).
  # Tek-nokta enjeksiyon → hem erken-dönüş hem awk-birleştirme yollarını kapsar; final-awk idx'i
  # yeniden-numaralar + sid-dedup eder (federe sid'leri __federe_* → benzersiz, çakışmaz).
  local federe; federe=$(_federe_roster_rows || true)
  [ -n "$federe" ] && base="${base:+$base$'\n'}$federe"

  shopt -s nullglob
  local files=(); [ -d "$SESSIONS_DIR" ] && files=("$SESSIONS_DIR"/*.json)
  if [[ ${#files[@]} -eq 0 ]]; then
    [ -n "$base" ] && printf '%s\n' "$base"
    return 0
  fi

  local prefs notes_json
  prefs=$(cat "$PREFS" 2>/dev/null || printf '{}')
  notes_json=$([ -f "$NOTES" ] && cat "$NOTES" || printf '{}')

  local rawsids; rawsids=$(printf '%s\n' "$base" | awk -F'\t' 'NF>=3 && $3!=""{print $3}')

  # Sidecar tara: status haritası (tümü) + raw'da olmayanlar için tam satır (sidecar-only).
  local statusmap="" extra="" f
  for f in "${files[@]}"; do
    local srow ssid sstat ssc snm scwd snote
    srow=$(jq -r --argjson p "$prefs" --argjson n "$notes_json" '
      .sessionId as $sid |
      [ ($p[$sid].short_code // ""), ($sid // ""), (.name // ""),
        (.status // ""), (.cwd // ""), ($n[$sid].note // "") ] | @tsv' "$f" 2>/dev/null) || continue
    ssid=$(printf '%s' "$srow" | cut -f2); [ -n "$ssid" ] || continue
    # 🔒 Kutu-yerel kapı (sidecar kaydı da ortak mount'ta olabilir — kapalı-seans dalıyla aynı ölçüt).
    _kutuda_gorunur_mu "$(printf '%s' "$srow" | cut -f5)" || continue
    sstat=$(printf '%s' "$srow" | cut -f4)
    # Harita: sid → status + sidecar-adı (ad, raw-zeminde tmux-id yedeğine düşen seansı geri-adlandırır).
    statusmap="${statusmap}${ssid}"$'\t'"${sstat}"$'\t'"$(printf '%s' "$srow" | cut -f3)"$'\n'
    printf '%s\n' "$rawsids" | grep -qxF "$ssid" && continue   # raw zaten kapsıyor
    # sidecar-only (argv-sid'siz canlı) → satır üret. Aile-dışı (raw'da yok) → KATMAN-0 zinciri.
    ssc=$(printf '%s' "$srow" | cut -f1); snm=$(printf '%s' "$srow" | cut -f3)
    scwd=$(printf '%s' "$srow" | cut -f5); snote=$(printf '%s' "$srow" | cut -f6)
    if [ -z "$snm" ] && ! _is_isolated_tenant "$scwd"; then   # İ1: izole-tenant → jsonl-title okuma (META-ONLY)
      local jp; jp=$(jsonl_path "$ssid" "$scwd")
      [ -f "$jp" ] || jp=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${ssid}.jsonl" \
        -not -path '*/subagents/*' -not -path '*/tool-results/*' -not -path '*/workflows/*' 2>/dev/null | head -1)
      [ -n "$jp" ] && [ -f "$jp" ] && { snm=$(session_meta_from_jsonl "$jp" | cut -f1); [ "$snm" = "(isimsiz)" ] && snm=""; }
      [ -z "$snm" ] && snm=$(printf '%s' "$prefs" | jq -r --arg s "$ssid" '.[$s].saved_auto_name // ""' 2>/dev/null || printf '')
    fi
    local gp
    if _is_isolated_tenant "$scwd"; then gp="$FEDERE_TAG · izole"
    else gp=$(_group_project "$ssid" "$scwd"); gp="/config/projects/${gp:-(diğer)}"; fi
    extra="${extra}$(printf '0\t%s\t%s\t%s\t%s\t%s\t%s' "$ssc" "$ssid" "$snm" "$sstat" "$gp" "$snote")"$'\n'
  done

  # Birleştir: raw-status-overlay + sidecar-only → sid-tekilleştir → idx yeniden-numaralandır.
  printf '%s\n%s\n' "$base" "$extra" | grep -v '^$' \
    | awk -F'\t' -v OFS='\t' -v sm="$statusmap" '
        BEGIN{ n=split(sm,a,"\n"); for(i=1;i<=n;i++){ if(a[i]=="")continue; split(a[i],b,"\t");
               if(b[1]!=""){ st[b[1]]=b[2]; nm[b[1]]=b[3] } } }
        NF>=6 && !seen[$3]++ {
          if($5=="" && ($3 in st)) $5=st[$3];                       # status zenginleştir
          if(($4=="" || $4 ~ /^cc-[0-9a-f]{8}$/) && nm[$3]!="") $4=nm[$3];  # tmux-id yedeği → sidecar-adı
          $1=++k; print }'
}

# Kapalı seansları TSV olarak yükle (en son değiştirilenden)
# Sütunlar: proj \t sid \t name \t age \t note
# Canlı seanslar + tmp/scratchpad yolları hariç tutulur
load_closed_sessions() {
  require_jq
  local limit="${1:-25}"

  # Canlı session ID'leri topla
  shopt -s nullglob
  local live_ids=""
  local f
  for f in "$SESSIONS_DIR"/*.json; do
    [ -f "$f" ] || continue
    local s; s=$(jq -r '.sessionId // empty' "$f" 2>/dev/null) || continue
    [ -n "$s" ] && live_ids="${live_ids}${s}"$'\n'
  done
  # Sidecar boş/eksikse tmux+ps'den canlı sid'leri de dışla (yoksa canlı seans "kapalı" listelenir).
  local _ls_sid _ls_rest
  while IFS=$'\t' read -r _ls_sid _ls_rest; do
    [ -n "$_ls_sid" ] && live_ids="${live_ids}${_ls_sid}"$'\n'
  done < <(_live_sessions_raw)

  local notes_json
  notes_json=$([ -f "$NOTES" ] && cat "$NOTES" || printf '{}')
  local now; now=$(date +%s)
  local found=0

  while IFS=$'\t' read -r mtime_raw jsonl_path_found; do
    [ "$found" -ge "$limit" ] && break

    # tmp / scratchpad / worktree seanslarını atla
    if [[ "$jsonl_path_found" == *"/tmp/"* ]] || \
       [[ "$jsonl_path_found" == *"scratchpad"* ]]; then
      continue
    fi

    local mtime="${mtime_raw%%.*}"
    local sid; sid=$(basename "$jsonl_path_found" .jsonl)

    # Canlı seansları atla
    if printf '%s' "$live_ids" | grep -qxF "$sid" 2>/dev/null; then continue; fi

    # Tek okumada isim + CWD
    local meta name cwd_val proj
    meta=$(session_meta_from_jsonl "$jsonl_path_found")
    name=$(printf '%s' "$meta" | cut -f1)
    cwd_val=$(printf '%s' "$meta" | cut -f2)
    # 🔒 Kutu-yerel kapı: başka kutuda koşmuş seans BURADA listelenmez (bkz _kutuda_gorunur_mu).
    _kutuda_gorunur_mu "$cwd_val" || continue
    # Grup projesi: canlı seanslarla AYNI mantık (transcript-projesine göre, çok-tireli ad-güvenli).
    proj=$(_group_project "$sid" "$cwd_val" "$jsonl_path_found")
    [ -z "$proj" ] && proj="(diğer)"
    # İ1 META-ONLY (fail-closed): izole-tenant kapalı-seansı → jsonl-title/görev-içeriği GİZLE;
    # yalnız ad(=tenant)+durum(=yaş) kalır, grup "🛰 FİLO · izole" bandına pinlenir (leak-önleme).
    if _is_isolated_tenant "$proj"; then name="$proj"; proj="$FEDERE_TAG · izole"
    elif _is_isolated_tenant "$cwd_val"; then name=""; proj="$FEDERE_TAG · izole"; fi

    local note; note=$(printf '%s' "$notes_json" | \
      jq -r --arg s "$sid" '.[$s].note // ""' 2>/dev/null || printf '')

    local diff=$(( now - mtime ))
    local age
    if   [ "$diff" -lt   3600 ]; then age="$(( diff / 60 ))dk"
    elif [ "$diff" -lt  86400 ]; then age="$(( diff / 3600 ))s"
    else                              age="$(( diff / 86400 ))g"
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$proj" "$sid" "$name" "$age" "$note"
    found=$(( found + 1 ))
  done < <(find "$PROJECTS_DIR" -maxdepth 2 -name '*.jsonl' \
      -not -path '*/subagents/*' -not -path '*/tool-results/*' \
      -not -path '*/workflows/*' \
      -printf '%T@\t%p\n' 2>/dev/null | sort -rn)
}

# ref → session_id çözümle (canlı + kapalı)
resolve_ref() {
  local ref="$1"

  if [[ "$ref" == "current" || "$ref" == "." ]]; then
    [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || \
      die "CLAUDE_CODE_SESSION_ID ayarlı değil (Claude seansı dışından çalışıyor)"
    printf '%s' "$CLAUDE_CODE_SESSION_ID"
    return
  fi

  local sessions
  sessions=$(load_sessions) || true

  # Sayı: önce short_code, sonra satır sırası (sadece canlı)
  if [[ "$ref" =~ ^[0-9]+$ ]]; then
    local m=""
    [ -n "$sessions" ] && m=$(printf '%s\n' "$sessions" | awk -F'\t' -v r="$ref" '$2 == r')
    [ -z "$m" ] && [ -n "$sessions" ] && \
      m=$(printf '%s\n' "$sessions" | awk -F'\t' -v r="$ref" '$1 == r')
    if [ -n "$m" ]; then
      local cnt; cnt=$(printf '%s\n' "$m" | wc -l | tr -d ' ')
      if [ "$cnt" -gt 1 ]; then
        printf "cs: '%s' birden fazla eşleşti, en yenisi seçildi\n" "$ref" >&2
        m=$(printf '%s\n' "$m" | tail -1)
      fi
      printf '%s\n' "$m" | cut -f3
      return
    fi
  fi

  # UUID öneki: canlı seanslar önce, sonra kapalı JSONL dosyaları
  if [[ "$ref" =~ ^[0-9a-f-]{6,}$ ]]; then
    local m=""
    [ -n "$sessions" ] && m=$(printf '%s\n' "$sessions" | awk -F'\t' -v r="$ref" 'index($3,r)==1' | awk -F'\t' '!seen[$3]++')
    if [ -n "$m" ]; then
      local cnt; cnt=$(printf '%s\n' "$m" | wc -l | tr -d ' ')
      [ "$cnt" -gt 1 ] && die "UUID öneki '$ref' belirsiz — daha fazla karakter girin"
      printf '%s\n' "$m" | cut -f3; return
    fi
    # Kapalı seanslarda ara
    local closed_match
    closed_match=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${ref}*.jsonl" \
      -not -path '*/subagents/*' -not -path '*/tool-results/*' \
      -not -path '*/workflows/*' 2>/dev/null | head -2)
    if [ -n "$closed_match" ]; then
      local cnt; cnt=$(printf '%s\n' "$closed_match" | grep -c .)
      [ "$cnt" -gt 1 ] && die "UUID öneki '$ref' belirsiz — daha fazla karakter girin"
      basename "$closed_match" .jsonl; return
    fi
  fi

  # İsim fuzzy (canlı seanslar, büyük/küçük harf duyarsız)
  if [ -n "$sessions" ]; then
    local m; m=$(printf '%s\n' "$sessions" | awk -F'\t' -v r="${ref}" 'tolower($4) ~ tolower(r)')
    if [ -n "$m" ]; then
      local cnt; cnt=$(printf '%s\n' "$m" | wc -l | tr -d ' ')
      if [ "$cnt" -gt 1 ]; then
        printf "cs: '%s' birden fazla seansla eşleşti:\n" "$ref" >&2
        printf '%s\n' "$m" | awk -F'\t' '{printf "  #%s  %s  (%s)\n", $2, $4, $5}' >&2
        die "Daha spesifik bir ref girin"
      fi
      printf '%s\n' "$m" | cut -f3; return
    fi
  fi

  # İsim fuzzy: kapalı seanslarda da ara (yavaş — UUID bulunamayınca çalışır)
  local closed; closed=$(load_closed_sessions 40) || true
  if [ -n "$closed" ]; then
    local m; m=$(printf '%s\n' "$closed" | awk -F'\t' -v r="${ref}" 'tolower($3) ~ tolower(r)')
    if [ -n "$m" ]; then
      local cnt; cnt=$(printf '%s\n' "$m" | grep -c .)
      if [ "$cnt" -gt 1 ]; then
        printf "cs: '%s' birden fazla kapalı seansla eşleşti:\n" "$ref" >&2
        printf '%s\n' "$m" | awk -F'\t' '{printf "  %s  %s  (%s)\n", substr($2,1,8), $3, $4}' >&2
        die "Daha spesifik bir ref girin"
      fi
      printf '%s\n' "$m" | cut -f2; return
    fi
  fi

  die "Seans bulunamadı: '$ref'"
}

# ── cs ls ────────────────────────────────────────────────────────────────────
cmd_ls() {
  # Canlı seansları L\tproj\tref\tname\tstatus\tnote formatına çevir
  local live_raw; live_raw=$(load_sessions) || true
  local live_fmt=""
  [ -n "$live_raw" ] && live_fmt=$(printf '%s\n' "$live_raw" | awk -F'\t' '{
    n = split($6, a, "/"); proj = a[n]
    ref = ($2 != "") ? $2 : ("[" $1 "]")
    print "L\t" proj "\t" ref "\t" $4 "\t" $5 "\t" $7
  }')

  # Kapalı seansları C\tproj\tref8\tname\tage\tnote formatına çevir
  local closed_raw; closed_raw=$(load_closed_sessions 20) || true
  local closed_fmt=""
  [ -n "$closed_raw" ] && closed_fmt=$(printf '%s\n' "$closed_raw" | awk -F'\t' '{
    print "C\t" $1 "\t" substr($2,1,8) "\t" $3 "\t" $4 "\t" $5
  }')

  local all_data=""
  [ -n "$live_fmt" ]   && all_data="${live_fmt}"$'\n'
  [ -n "$closed_fmt" ] && all_data="${all_data}${closed_fmt}"$'\n'

  if [ -z "$all_data" ]; then
    printf 'Seans yok.\n'; return
  fi

  printf "${B}%-8s %-22s %-8s %s${Z}\n" "REF" "İSİM" "DURUM" "NOT"

  # Proje adına göre sırala, her projede canlılar (L) önce, kapalılar (C) sonra
  # sort: -k2 proj, -k1 type (C<L → reverse ile L önce)
  # KATMAN-1/2 çoklu-grup pin (deterministik, locale-bağımsız): 🏛 EKİP en-üstte → 🛰 FİLO (federe/izole)
  # → gerisi proj'e göre. Üç-bant grep: sırasız-locale-etkisiz sabit-öncelik.
  { printf '%s\n' "$all_data" | grep -v '^$' | grep -aF "$EKIP_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
    printf '%s\n' "$all_data" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -aF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
    printf '%s\n' "$all_data" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -avF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true; } | \
    awk -v Y="$Y" -v G="$G" -v C="$C" -v DIM="$DIM" -v B="$B" -v Z="$Z" \
    -F'\t' 'NF >= 5 {
      type=$1; proj=$2; ref=$3; name=$4; info=$5; note=$6

      if (proj != last_proj) {
        printf "\n%s── %s%s\n", B, proj, Z
        last_proj = proj
      }

      name_s = substr(name, 1, 22)
      note_s = (length(note) > 0) ? substr(note, 1, 40) : "—"
      if (length(note) > 40) note_s = substr(note, 1, 39) "…"

      if (type == "L") {
        color = (info == "busy") ? Y : (info == "idle") ? G : (info == "waiting") ? C : ""
        printf "  ● %-6s %-22s %s%-8s%s %s\n", ref, name_s, color, info, Z, note_s
      } else {
        printf "  %s○ %-6s %-22s %-8s %s%s\n", DIM, ref, name_s, info, note_s, Z
      }
    }'
  printf '\n'
}

# ── cs rename <ref> <yeni-isim> ──────────────────────────────────────────────
cmd_rename() {
  local ref="${1:-}"
  [ -z "$ref" ] && die "Kullanım: cs rename <ref> <yeni-isim>"
  shift
  local name="$*"
  [ -z "$name" ] && die "İsim boş olamaz"

  local sid; sid=$(resolve_ref "$ref")
  local jsonl; jsonl=$(find_jsonl_for_sid "$sid")

  if [ -n "$jsonl" ] && [ -f "$jsonl" ]; then
    jq -nc --arg n "$name" --arg s "$sid" \
      '{type: "custom-title", customTitle: $n, sessionId: $s}' >> "$jsonl"
    printf '  JSONL güncellendi: %s\n' "$jsonl"
  else
    printf '  Uyarı: JSONL bulunamadı — claude --resume ile çalışmayabilir\n' >&2
  fi

  local payload; payload=$(jq -nc --arg v "$name" '{value: $v}')
  local http_code="000"
  http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
    -X POST "$API/api/agents/$sid/nickname" \
    -H 'Content-Type: application/json' \
    -d "$payload" 2>/dev/null) || true
  http_code="${http_code:-000}"
  if [ "$http_code" = "200" ]; then
    printf '  Dashboard güncellendi\n'
  else
    printf '  Uyarı: Dashboard API (HTTP %s) — sadece transcript güncellendi\n' "$http_code" >&2
  fi

  # tmux PENCERE adını da güncelle. NİÇİN: kullanıcının adı sürekli gördüğü tek yer alt
  # çubuktur; liste komutu çalıştırmadıkça isim hiçbir yerde görünmüyordu ve "oldu mu, ben
  # nerede göreceğim?" diye sorulmak zorunda kalınıyordu (firsthand 2026-07-30, Sultan).
  # Oturum ADI (cc-<id8>) DEĞİŞMEZ — o, başka cihazdan attach için kimliğe bağlı sabit tutamak.
  _tmux_pencere_adlandir "$sid" "$name"

  printf "İsim değiştirildi → '%s'\n" "$name"
}

# sid → o seansın tmux penceresini yeni adla etiketle. Yapamazsa SESSİZ GEÇMEZ: ne olduğunu
# söyler (ölçemedim ≠ yaptım).
_tmux_pencere_adlandir() {
  local sid="$1" name="$2"
  command -v tmux >/dev/null 2>&1 || { printf '  (tmux yok — alt çubuk etiketlenemedi)\n'; return 0; }
  local hedef=""
  if [ -n "${TMUX:-}" ]; then
    hedef="$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null || true)"
  else
    # Oturum adı sid'e deterministik bağlı (cc-<id8>) — dışarıdan da bulunabilir.
    local ts="cc-${sid:0:8}"
    tmux has-session -t "$ts" 2>/dev/null && hedef="${ts}:0"
  fi
  [ -n "$hedef" ] || { printf '  (tmux penceresi bulunamadı — alt çubuk etiketlenmedi)\n'; return 0; }
  if tmux rename-window -t "$hedef" "$name" 2>/dev/null; then
    printf '  Alt çubuk etiketlendi: %s\n' "$name"
  else
    printf '  (alt çubuk etiketlenemedi: %s)\n' "$hedef"
  fi
}

# ── cs note <ref> [metin] ────────────────────────────────────────────────────
cmd_note() {
  local ref="${1:-}"
  [ -z "$ref" ] && die "Kullanım: cs note <ref> [metin]  (boş = notu sil)"
  shift
  local note="$*"

  local sid; sid=$(resolve_ref "$ref")
  local f; f=$(session_file_for_sid "$sid") || true
  local name=""; [ -n "$f" ] && name=$(jq -r '.name // ""' "$f")

  local existing ts tmp
  existing=$([ -f "$NOTES" ] && cat "$NOTES" || printf '{}')
  ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  tmp=$(mktemp /config/.agent-dashboard/.notes.tmp.XXXXXX)

  if [ -z "$note" ]; then
    # L25-W7: notu sil AMA şerit-işaretini (varsa) KORU — yoksa "notu sildim" derken
    # seansın kapı-şeridi de sessizce uçardı. Şerit yoksa eski davranış (kaydı komple sil).
    printf '%s\n' "$existing" | jq --arg s "$sid" \
      'del(.[$s].note) | if ((.[$s] // {}) | has("serit")) then . else del(.[$s]) end' > "$tmp"
    mv "$tmp" "$NOTES"
    printf "Not silindi: '%s'\n" "${name:-$sid}"
  else
    # L25-W7: kaydı EZME, birleştir — aksi hâlde not yazmak şerit-işaretini siliyordu.
    # Şeritsiz kayıtta sonuç {note,updated_at} → eski çıktıyla byte-aynı.
    printf '%s\n' "$existing" | jq --arg s "$sid" --arg n "$note" --arg t "$ts" \
      '.[$s] = ((.[$s] // {}) + {note: $n, updated_at: $t})' > "$tmp"
    mv "$tmp" "$NOTES"
    printf "Not kaydedildi (%s): %s\n" "${name:-$sid}" "$note"
  fi
}

# ── L25-W7 · ŞERİT motoru ────────────────────────────────────────────────────
# SIZINTI: kapı şeridinde doğan bir seansın ANTHROPIC_BASE_URL/AUTH_TOKEN'ı yalnız o
# claude sürecinin env'inde yaşıyordu. Pencere ölünce `cs resume` yeni bir claude'u
# BOŞ env ile doğuruyor → sessizce varsayılan Anthropic şeridine dönüyor, kota yanıyor.
# Çözüm: doğum-anında kalıcı işaret + resume-anında işareti okuyup şeridi geri kurma.

# sid → şerit adı ('kapi' | '') ; işaretsizde boş döner.
_serit_get() {
  local sid="$1"
  [ -f "$NOTES" ] || return 0
  jq -r --arg s "$sid" '.[$s].serit.ad // ""' "$NOTES" 2>/dev/null || printf ''
}

# sid + alan adı → şerit alan değeri ('' yoksa).
_serit_field() {
  local sid="$1" k="$2"
  [ -f "$NOTES" ] || return 0
  jq -r --arg s "$sid" --arg k "$k" '.[$s].serit[$k] // ""' "$NOTES" 2>/dev/null || printf ''
}

# İşareti yaz. Kullanıcı notunu ve diğer alanları KORUR (birleştirme, ezme değil).
# Sır YAZILMAZ — yalnız adres/ad/kaynak/zaman.
_serit_set() {
  local sid="$1" ad="$2" url="$3" model="$4" kaynak="$5"
  require_jq
  mkdir -p /config/.agent-dashboard 2>/dev/null || true
  local existing ts tmp
  existing=$([ -f "$NOTES" ] && cat "$NOTES" || printf '{}')
  ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  tmp=$(mktemp /config/.agent-dashboard/.notes.tmp.XXXXXX) || return 1
  printf '%s\n' "$existing" | jq --arg s "$sid" --arg a "$ad" --arg u "$url" \
      --arg m "$model" --arg k "$kaynak" --arg t "$ts" \
    '.[$s] = ((.[$s] // {}) + {serit: {ad:$a, base_url:$u, model:$m, kaynak:$k, at:$t}})' > "$tmp"
  mv "$tmp" "$NOTES"
}

# İşareti kaldır. Kayıtta başka anlamlı alan kalmadıysa kaydı komple sil (yetim bırakma).
_serit_temizle() {
  local sid="$1" tmp
  require_jq
  [ -f "$NOTES" ] || return 0
  tmp=$(mktemp /config/.agent-dashboard/.notes.tmp.XXXXXX) || return 1
  jq --arg s "$sid" \
    'del(.[$s].serit)
     | if ((.[$s] // {}) | with_entries(select(.key != "updated_at")) | length) == 0
       then del(.[$s]) else . end' "$NOTES" > "$tmp"
  mv "$tmp" "$NOTES"
}

# Kapı ayakta mı? (açılış-anı kararları bunu kullanır)
# TEK SÖZLEŞME (P2-a): `kapi saglik` → rc=0 ayakta / rc=1 değil. Türkçe rapor-metni
# grep'lemek YASAK (metin değişince sessizce herkesi varsayılan şeride düşürürdü).
# Başlatıcı bu makinede yoksa eski curl probu son çare olarak kalır.
_kapi_saglikli() {
  local url="${1:-$(_kapi_adres)}" code k
  if k=$(_kapi_bin); then KAPI_URL="$url" "$k" saglik >/dev/null 2>&1; return $?; fi
  command -v curl >/dev/null 2>&1 || return 1
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "$url/health/liveliness" 2>/dev/null || printf '000')
  [ "$code" = "200" ]
}

# Menü etiketi için 30sn önbellekli sağlık (her menü açılışında curl beklemeyelim).
_kapi_saglik_cached() {
  local cf=/config/.agent-dashboard/.kapi-health age
  if [ -f "$cf" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cf" 2>/dev/null || printf '0') ))
    if [ "$age" -lt 30 ]; then [ "$(cat "$cf" 2>/dev/null)" = "1" ]; return $?; fi
  fi
  mkdir -p /config/.agent-dashboard 2>/dev/null || true
  if _kapi_saglikli "$(_kapi_adres)"; then printf '1' > "$cf" 2>/dev/null || true; return 0; fi
  printf '0' > "$cf" 2>/dev/null || true; return 1
}

# Şerit ortamını taşıyan 0600 geçici rc dosyasını ÜRETTİR.
# İçeriği cs YAZMAZ — `kapi cevre --yaz` yazar (tek yazar; bkz. başlık notu).
# Ampirik (tmux 3.4): `export VAR` tmux new-session'a GEÇMEZ (komut tmux SUNUCUSUNUN
# env'iyle koşar) → açık taşıma şart. `-e VAR=deger` sırrı argv'ye (ps'e) düşürürdü;
# bu yüzden komut-dizesinde yalnız DOSYA YOLU geçer, içerik source edilip anında silinir.
# RC=1 → anahtar yok / başlatıcı yok → çağıran varsayılan şeride düşer (sessiz bozulma yok).
_serit_rc_yaz() {
  local url="$1" model="${2:-}" rc k
  k=$(_kapi_bin) || {
    printf '⚠ kapı başlatıcısı (kapi) bu makinede bulunamadı → VARSAYILAN şerit.\n' >&2
    printf '  Çözüm: bash infra/kapi/setup-kapi.sh\n' >&2
    return 1
  }
  mkdir -p /config/.agent-dashboard 2>/dev/null || true
  # yarım kalmış (açılmayan seans) rc'leri süpür — sır diskte sürünmesin
  find /config/.agent-dashboard -maxdepth 1 -name '.kapi.rc.*' -mmin +60 -delete 2>/dev/null || true
  rc=$(mktemp /config/.agent-dashboard/.kapi.rc.XXXXXX) || return 1
  chmod 600 "$rc" 2>/dev/null || true
  if [ -n "$model" ]; then
    KAPI_URL="$url" "$k" cevre --yaz "$rc" --model "$model" || { rm -f "$rc"; return 1; }
  else
    KAPI_URL="$url" "$k" cevre --yaz "$rc" || { rm -f "$rc"; return 1; }
  fi
  printf '%s' "$rc"
}

# İşaretli seans için şerit-ortamını hazırla.
#   RC=0 → _SERIT_RC/_SERIT_AD dolu; çağıran KAPI şeridinde exec etmeli
#   RC=1 → işaret yok VEYA sağlık/anahtar kapısı kırmızı → çağıran VARSAYILAN akışa devam
# SAĞLIK KAPISI: kapı yoksa/anahtar yoksa sessizce kırık oturum açmak YASAK → uyar + düş.
_serit_hazirla() {
  local sid="$1" ad url
  _SERIT_RC=""; _SERIT_AD=""
  command -v jq >/dev/null 2>&1 || return 1
  ad=$(_serit_get "$sid")
  [ -n "$ad" ] || return 1                      # işaretsiz → BYTE-AYNI eski davranış
  [ "$ad" = "varsayilan" ] && return 1
  if [ "$ad" != "kapi" ]; then
    printf '⚠ Bilinmeyen şerit işareti (%s) → varsayılan şeritte devam.\n' "$ad" >&2
    return 1
  fi
  url=$(_serit_field "$sid" base_url); [ -n "$url" ] || url="$(_kapi_adres)"
  if ! _kapi_saglikli "$url"; then
    printf '⚠ Kapı yanıt vermiyor (%s) → bu açılış VARSAYILAN şeritte.\n' "$url" >&2
    printf '  İşaret duruyor; kapı dönünce sonraki devam-ediş kendiliğinden kapıya döner.\n' >&2
    return 1
  fi
  # Devam-edişte model VERİLMEZ: `--resume` önceki oturumun modelini geri yükler.
  # Ortamdaki keşif-bayrağı yine gelir → `/model` menüsünde kapı modelleri GÖRÜNÜR.
  _SERIT_RC=$(_serit_rc_yaz "$url") || {
    printf '⚠ Kapı ortamı hazırlanamadı (anahtar?) → bu açılış VARSAYILAN şeritte.\n' >&2
    return 1
  }
  _SERIT_AD="$ad"
  return 0
}

# resume · tmux dalı: işaret varsa kapı şeridinde exec eder (DÖNMEZ); yoksa no-op.
_serit_resume_tmux() {
  local sid="$1" jsonl="$2" title="$3" tsess="$4"
  _serit_hazirla "$sid" || return 0
  printf 'Devam (🚪 kapı şeridi · kendi tmux oturumunda): %s\n' "$title"
  exec tmux new-session -s "$tsess" -n "🚪 $title" \
    "exec sh -c '. $_SERIT_RC; rm -f $_SERIT_RC; export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1; exec claude $CS_CLAUDE_FLAGS --resume \"$jsonl\"'"
}

# resume · düz dal (zaten tmux içinde ya da tmux yok): burada `export` GEÇERLİ —
# aynı sürece exec ediyoruz, tmux sunucusu araya girmiyor.
_serit_resume_plain() {
  local sid="$1" jsonl="$2" title="$3"
  _serit_hazirla "$sid" || return 0
  printf 'Devam ediliyor (🚪 kapı şeridi): %s\n' "$title"
  set_session_title "🚪 $title"
  # shellcheck disable=SC1090
  . "$_SERIT_RC"; rm -f "$_SERIT_RC"
  exec env CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude $CS_CLAUDE_FLAGS --resume "$jsonl"
}

# new · kapı şeridinde YENİ seans. İşaret ancak sid'i BİZ ürettiğimizde yazılabilir →
# uuid üretilemezse kapı şeridini REDDET (işaretsiz kapı-seansı = yarınki sızıntı).
_serit_new_kapi() {
  local dir="$1" base="$2" url rc newid
  url="$(_kapi_adres)"
  command -v jq >/dev/null 2>&1 || { printf '⚠ jq yok → kapı-işareti yazılamaz; VARSAYILAN şeritte açılıyor.\n' >&2; return 1; }
  if ! _kapi_saglikli "$url"; then
    printf '⚠ Kapı yanıt vermiyor (%s) → yeni seans VARSAYILAN şeritte açılıyor.\n' "$url" >&2
    return 1
  fi
  newid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || true)
  if [ -z "$newid" ]; then
    printf '⚠ session-id üretilemedi → kapı-işareti kalıcı yazılamaz; VARSAYILAN şeritte açılıyor.\n' >&2
    return 1
  fi
  # YENİ seansta model AÇIKÇA verilir (rc dosyasındaki KAPI_MODEL). Verilmezse
  # Claude varsayılan Anthropic modelini ister ve kapı 400 döner.
  # CS_KAPI_MODEL ile kısa ad seçilebilir (glm · kimi · minimax …); boşsa kapı varsayılanı.
  rc=$(_serit_rc_yaz "$url" "${CS_KAPI_MODEL:-}") || {
    printf '⚠ Kapı ortamı hazırlanamadı (anahtar?) → yeni seans VARSAYILAN şeritte açılıyor.\n' >&2
    return 1
  }
  _serit_set "$newid" kapi "$url" "" cs-new
  printf 'Şerit: 🚪 kapı — yeni seans açılıyor…\n'
  if [ -z "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -s "cc-${newid:0:8}" -n "🚪 $base" \
      "exec sh -c '. $rc; rm -f $rc; exec claude $CS_CLAUDE_FLAGS \${KAPI_MODEL:+--model \"\$KAPI_MODEL\"} --session-id $newid'"
  fi
  set_session_title "🚪 $base"
  # shellcheck disable=SC1090
  . "$rc"; rm -f "$rc"
  exec claude $CS_CLAUDE_FLAGS ${KAPI_MODEL:+--model "$KAPI_MODEL"} --session-id "$newid"
}

# ── cs serit <ref> [kapi|varsayilan] ─────────────────────────────────────────
cmd_serit() {
  require_jq
  local ref="${1:-}" ad="${2:-}"
  [ -n "$ref" ] || die "Kullanım: cs serit <ref> [kapi|varsayilan]"
  local sid; sid=$(resolve_ref "$ref")
  if [ -z "$ad" ]; then
    local cur; cur=$(_serit_get "$sid")
    printf 'Şerit: %s\n' "${cur:-varsayılan (işaretsiz)}"
    return 0
  fi
  case "$ad" in
    kapi)
      _serit_set "$sid" kapi "$(_kapi_adres)" "" cs-serit
      printf 'İşaretlendi: 🚪 kapı şeridi — bundan sonraki her devam-edişte geri kurulur.\n'
      _kapi_saglikli "$(_kapi_adres)" || printf '⚠ Not: kapı şu an yanıt vermiyor.\n' >&2 ;;
    varsayilan|default)
      _serit_temizle "$sid"; printf 'İşaret kaldırıldı → varsayılan şerit.\n' ;;
    *) die "Bilinmeyen şerit: '$ad'  (kapi | varsayilan)" ;;
  esac
}

# Menü/fzf yolu: seansı kapı şeridinde işaretle, sonra normal resume'a devret.
cmd_resume_kapi() {
  local sid="${1:-}"
  [ -n "$sid" ] || return 0
  case "$sid" in __hdr__|__federe_*) exec cs menu ;; esac
  require_jq
  _serit_set "$sid" kapi "$(_kapi_adres)" "" cs-menu
  cmd_resume "$sid"
}

# ── Başlık yardımcıları (sekme + tmux durum çubuğu) ──────────────────────────
# sid → görünür ad. Bu, cs ls'teki İSİM ile birebir aynı (custom-title/ai-title).
# NOT: "5-CortexEvrim" gibi baştaki numara ADIN PARÇASI — ayrıca short_code önekı
# EKLENMEZ (yoksa "7-5-CortexEvrim" gibi çift önek olur). İsimsizse kısa-kod/sid.
session_display_name() {
  local sid="$1" name="" f jsonl sc
  # NOT: session_file_for_sid eşleşme yoksa exit 1 döner; DÜZ bağlamda (cmd_name)
  # `set -e`'yi tetikler → `|| true` şart (find_jsonl_for_sid hep $(...) içinde çağrılır).
  f=$(session_file_for_sid "$sid") || true
  [ -n "$f" ] && name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
  if [ -z "$name" ]; then
    jsonl=$(find_jsonl_for_sid "$sid")
    [ -n "$jsonl" ] && name=$(session_meta_from_jsonl "$jsonl" | cut -f1)
  fi
  name=$(printf '%s' "${name:-}" | tr -d '\n\r\t')
  if [ -n "$name" ] && [ "$name" != "(isimsiz)" ]; then
    printf '%s' "$name"; return
  fi
  # İsimsiz seans: kısa kod, yoksa sid öneki (sekmede "(isimsiz)" yazmasın)
  sc=$(jq -r --arg s "$sid" '.[$s].short_code // ""' "$PREFS" 2>/dev/null || true)
  printf '%s' "${sc:-${sid:0:8}}"
}

# sid/jsonl → seansın çalışma dizini (cwd). Canlıda session dosyasından, kapalıda
# transcript'ten çekilir. session_meta'nın 2KB penceresi ilk kayıt büyükse cwd'yi
# kaçırabildiği için burada daha geniş bir pencereden ham çıkarım yapıyoruz.
session_cwd_for() {
  local sid="$1" jsonl="$2" f cwd=""
  f=$(session_file_for_sid "$sid") || true
  [ -n "$f" ] && cwd=$(jq -r '.cwd // empty' "$f" 2>/dev/null || true)
  if [ -z "$cwd" ] && [ -n "$jsonl" ] && [ -f "$jsonl" ]; then
    # İlk "cwd" alanına kadar oku (grep -m1 ilk eşleşmede durur → büyük başlıklı
    # transcript'lerde de bulur; sabit 16KB pencere bazılarını kaçırıyordu).
    cwd=$(grep -aom1 '"cwd":"[^"]*"' "$jsonl" 2>/dev/null | sed 's/.*"cwd":"//; s/"$//')
  fi
  printf '%s' "$cwd"
}

# Başlığı ayarla: VSCode sekmesi (OSC 2) + tmux içindeysek durum çubuğu pencere adı.
# tmux YOKSA (her terminalde tmux çalışmıyor) doğrudan OSC 2 yollanır.
set_session_title() {
  local title="$1"
  title=$(printf '%s' "$title" | tr -d '\n\r\t')
  [ -z "$title" ] && return 0
  if [ -n "${TMUX:-}" ]; then
    # tmux durum çubuğu: pencere adı = seans adı → sekme sıfırlansa da hep görünür.
    tmux rename-window "$title" 2>/dev/null || true
    tmux set-window-option automatic-rename off 2>/dev/null || true
    # VSCode sekmesi: OSC 2'yi tmux passthrough zarfında dış terminale ilet
    # (allow-passthrough on → .tmux.conf). \033 ikiye katlanır (tmux kuralı).
    printf '\033Ptmux;\033\033]2;%s\007\033\\' "$title"
  else
    # tmux yok: doğrudan OSC 2 → xterm.js / VSCode sekmesi.
    printf '\033]2;%s\007' "$title"
  fi
}

# ── cs resume [ref] ──────────────────────────────────────────────────────────
cmd_resume() {
  local ref="${1:-}"

  if [ -z "$ref" ]; then
    cmd_ls
    printf "\n${B}Aç${Z} (isim/UUID  ·  yeni seans: ${B}+proje${Z} ör. +Nexus  ·  q=çık): "
    read -r ref || exit 0
    [[ "$ref" == "q" || "$ref" == "Q" ]] && exit 0
  fi

  # Yeni (sıfır) seans kısayolu: "+Nexus" / "yeni Nexus" / "new Nexus" (argümansız = mevcut dizin)
  case "$ref" in
    "+"*)             cmd_new "${ref#+}"; return ;;
    "yeni "*|"new "*) cmd_new "${ref#* }"; return ;;
    yeni|new)         cmd_new ""; return ;;
  esac

  [ "$ref" = "__hdr__" ] && exec cs menu   # grup başlığı seçildi → picker'a dön (no-op)
  case "$ref" in __federe_*) printf 'cs: federe/izole birim — bu konteynerden resume edilemez (META-ONLY).\n' >&2; exec cs menu ;; esac
  local sid; sid=$(resolve_ref "$ref")
  case "$sid" in __federe_*) printf 'cs: federe/izole birim — bu konteynerden resume edilemez (META-ONLY).\n' >&2; exec cs menu ;; esac
  local jsonl; jsonl=$(find_jsonl_for_sid "$sid")
  [ -n "$jsonl" ] && [ -f "$jsonl" ] || die "Transcript bulunamadı (sid: $sid)"

  # Sekme + tmux durum çubuğu başlığını seans adına ayarla
  local title; title=$(session_display_name "$sid")
  set_session_title "$title"

  # Seansın KENDİ dizinine geç → claude doğru proje kökünde açılsın (cwd = proje kökü).
  # Dizin yoksa (silinmiş proje) uyarıp mevcut dizinde devam et.
  local scwd; scwd=$(session_cwd_for "$sid" "$jsonl")
  if [ -n "$scwd" ] && [ -d "$scwd" ]; then
    cd "$scwd" || true
  elif [ -n "$scwd" ]; then
    printf 'Uyarı: seans dizini yok (%s) — mevcut dizinde açılıyor\n' "$scwd" >&2
  fi

  # Model B: tmux DIŞINDAYSAK (varsayılan 'session' profili cs'i düz bash'te açar) →
  #   (a) bu sid'i çalıştıran canlı claude HANGİ tmux oturumundaysa (adı ne olursa olsun —
  #       legacy '2025/42', cc-<id8>, sabit-isim… fark etmez) ona ATTACH → gerçek ayna, FORK YOK.
  #       Sidecar'a bağlı DEĞİL; canlıyı tmux+ps'den bulur (v2.1.202 regresyonuna dayanıklı).
  #   (b) hızlı yol / geriye uyum: deterministik cc-<id8>.
  #   (c) canlı ama tmux DIŞINDA (raw terminal) → resume FORK olur, reddet.
  #   (d) kapalı → kendi cc-<id8> tmux oturumunda resume → sonraki cihaz attach bulur.
  # Zaten tmux içindeysek / tmux yoksa: aşağıdaki eski düz exec (regresyon yok).
  if [ -z "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    local tsess="cc-${sid:0:8}"
    local live_sess; live_sess=$(live_tmux_session_for_sid "$sid")
    if [ -n "$live_sess" ]; then
      printf 'Canlı seansa bağlanılıyor (ayna): %s\n' "$title"
      exec tmux attach -t "=$live_sess"
    fi
    if tmux has-session -t "=$tsess" 2>/dev/null; then
      printf 'Canlı seansa bağlanılıyor (ayna): %s\n' "$title"
      exec tmux attach -t "$tsess"
    fi
    if sid_is_live "$sid"; then
      # canlı ama hiçbir tmux oturumunda değil = raw terminal → buradan resume FORK olur.
      printf '⚠ "%s" şu an tmux DIŞINDA bir raw terminalde canlı → buradan devam FORK oluşturur.\n' "$title"
      printf '  Doğru yol: o raw terminali KAPAT, sonra burada tekrar devam et (temiz, tek süreç).\n'
      return 1
    fi
    # L25-W7 ŞERİT: seans kapı şeridinde doğduysa aynı şeritte yeniden doğ (exec, dönmez).
    # İşaretsizse / kapı kırmızıysa no-op → aşağıdaki eski akış BYTE-AYNI çalışır.
    _serit_resume_tmux "$sid" "$jsonl" "$title" "$tsess"
    printf 'Devam (kendi tmux oturumunda): %s\n' "$title"
    exec tmux new-session -s "$tsess" -n "$title" \
      "exec env CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude $CS_CLAUDE_FLAGS --resume '$jsonl'"
  fi
  _serit_resume_plain "$sid" "$jsonl" "$title"   # L25-W7 ŞERİT (işaretsizde no-op)
  printf 'Devam ediliyor: %s  (%s)\n' "$title" "${scwd:-$PWD}"
  # CLAUDE_CODE_DISABLE_TERMINAL_TITLE: claude kendi başlığını yazıp adı ezmesin
  # (claude başlığı tmux passthrough ile yolluyor → kapatmazsak bizimkini ezer).
  exec env CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude $CS_CLAUDE_FLAGS --resume "$jsonl"
}

# ── cs name [ref] ────────────────────────────────────────────────────────────
# Mevcut (ya da verilen) seansın görünür adını yazdır — "tab adı neydi?" için.
cmd_name() {
  local ref="${1:-}"
  if [ -z "$ref" ] || [ "$ref" = "current" ] || [ "$ref" = "." ]; then
    # tmux içindeysek pencere adı = seans adı (cs resume ayarladı) — en güvenilir,
    # CLAUDE_CODE_SESSION_ID set olmayan düz pane'lerde de çalışır.
    if [ -n "${TMUX:-}" ]; then
      local wn; wn=$(tmux display-message -p '#{window_name}' 2>/dev/null || true)
      case "$wn" in
        ""|bash|node|tmux|sh|zsh|fish|claude) ;;   # otomatik/anlamsız ad → atla
        *) printf '%s\n' "$wn"; return ;;
      esac
    fi
    ref="current"
  fi
  local sid; sid=$(resolve_ref "$ref")
  session_display_name "$sid"; printf '\n'
}

# ── cs info [ref] ────────────────────────────────────────────────────────────
cmd_info() {
  local ref="${1:-current}"
  local sid; sid=$(resolve_ref "$ref")

  local f; f=$(session_file_for_sid "$sid") || true
  local jsonl; jsonl=$(find_jsonl_for_sid "$sid")

  if [ -n "$f" ]; then
    local name status cwd started
    name=$(jq -r '.name // ""' "$f")
    status=$(jq -r '.status // ""' "$f")
    cwd=$(jq -r '.cwd // ""' "$f")
    started=$(jq -r '.startedAt // 0' "$f")
    local started_h; started_h=$(date -d "@$((started / 1000))" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%s' "$started")
    local sc; sc=$(jq -r --arg s "$sid" '.[$s].short_code // "-"' "$PREFS" 2>/dev/null || printf '-')
    local target; target=$(jq -r --arg s "$sid" '.[$s].target // "-"' "$PREFS" 2>/dev/null || printf '-')

    printf "${B}Seans:${Z}   %s\n" "$name"
    printf "${B}Durum:${Z}   %s\n" "$status"
    printf "${B}Kısa #:${Z}  %s\n" "$sc"
    printf "${B}Hedef:${Z}   %s\n" "$target"
    printf "${B}CWD:${Z}     %s\n" "$cwd"
    printf "${B}Başladı:${Z} %s\n" "$started_h"
  else
    local name; name=$([ -n "$jsonl" ] && session_meta_from_jsonl "$jsonl" | cut -f1 || printf '?')
    local mtime; mtime=$(stat -c %Y "$jsonl" 2>/dev/null || printf '0')
    local mtime_h; mtime_h=$(date -d "@$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '?')
    printf "${B}Seans:${Z}   %s\n" "$name"
    printf "${B}Durum:${Z}   kapalı\n"
    printf "${B}Son değişim:${Z} %s\n" "$mtime_h"
  fi

  local note; note=$([ -f "$NOTES" ] && jq -r --arg s "$sid" '.[$s].note // ""' "$NOTES" 2>/dev/null || printf '')
  printf "${B}ID:${Z}      %s\n" "$sid"
  printf "${B}JSONL:${Z}   %s\n" "${jsonl:-(bulunamadı)}"
  printf "${B}Not:${Z}     %s\n" "${note:-(yok)}"
  # L25-W7: şerit bloku YALNIZ işaretli seanslarda basılır → işaretsiz çıktı byte-aynı.
  local serit; serit=$(_serit_get "$sid")
  if [ -n "$serit" ]; then
    printf "${B}Şerit:${Z}   🚪 %s  (%s)\n" "$serit" "$(_serit_field "$sid" base_url)"
    # İkincil kanıt: transcript'teki son model — işaretle uyuşmazlık sızıntıyı ele verir.
    if [ -n "${jsonl:-}" ] && [ -f "$jsonl" ]; then
      local mdl; mdl=$(tail -c 200000 "$jsonl" 2>/dev/null | grep -ao '"model":"[^"]*"' | tail -1 | sed 's/.*"model":"//; s/"$//')
      [ -n "$mdl" ] && printf "${DIM}Son model:${Z} %s\n" "$mdl"
    fi
  fi
}

# ── cs new [proje|yol] ───────────────────────────────────────────────────────
# Proje adı → tam dizin yolu. Çok kaynak: /config/projects/<ad> · canlı seans
# cwd'leri · transcript dizin adlarını çözme ('-config-projects-X' → '/config/projects/X').
project_dir_for() {
  local name="$1" d=""
  [ -d "/config/projects/$name" ] && { printf '%s' "/config/projects/$name"; return; }
  local sessions; sessions=$(load_sessions) || true
  if [ -n "$sessions" ]; then
    d=$(printf '%s\n' "$sessions" | awk -F'\t' -v n="$name" \
      '$6!="" {k=split($6,a,"/"); if(a[k]==n){print $6; exit}}')
    [ -n "$d" ] && [ -d "$d" ] && { printf '%s' "$d"; return; }
  fi
  local cand decoded
  for cand in "$PROJECTS_DIR"/*/; do
    cand=$(basename "${cand%/}")
    case "$cand" in
      -*) decoded="/${cand#-}"; decoded=${decoded//-//}
          [ "$(basename "$decoded")" = "$name" ] && [ -d "$decoded" ] && \
            { printf '%s' "$decoded"; return; } ;;
    esac
  done
  printf ''
}

# Yeni (sıfır) Claude seansı başlat — verilen projenin/dizinin içinde.
# Model B: base'den tmux-güvenli, ÇAKIŞMAYAN oturum adı üret (cc-safe).
# tmux oturum adı '.'/'\:'/boşluk içeremez → sanitize; çakışırsa -2,-3… ekle.
_tmux_session_name() {
  local base; base=$(printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')
  [ -z "$base" ] && base=cc
  local name="$base" n=2
  while tmux has-session -t "=$name" 2>/dev/null; do name="${base}-${n}"; n=$((n+1)); done
  printf '%s' "$name"
}

cmd_new() {
  # --ad "<isim>": `yenisession`ın sorduğu ad BURAYA gelir. Eskiden ad soruluyor ama
  # KULLANILMIYORDU: "şunu çalıştır" diye bir satır basılıp devredilirdi, o satır Claude
  # açılınca ekrandan kaybolurdu → kullanıcı adı yazar, hiçbir yere gitmezdi (firsthand
  # 2026-07-30, Sultan). Ad verilmezse davranış BİREBİR eskisi gibi kalır (proje adı).
  local CS_YENI_AD=""
  if [ "${1:-}" = "--ad" ]; then CS_YENI_AD="${2:-}"; shift 2; fi
  local ref="${1:-}" dir
  if [ -z "$ref" ]; then
    dir="$PWD"
  elif [ -d "$ref" ]; then
    dir="$ref"
  else
    dir=$(project_dir_for "$ref")
    [ -n "$dir" ] || die "Proje bulunamadı: '$ref' (tam yol da verebilirsin: cs new /config/projects/X)"
  fi
  cd "$dir" || die "cd başarısız: $dir"
  printf 'Yeni seans → %s\n' "$dir"
  local base; base=$(basename "$dir")
  local pencere="${CS_YENI_AD:-$base}"   # alt çubukta ve sekmede görünecek etiket
  # L25-W7 ŞERİT: `cs new --serit kapi` / menü "🚪 Kapı şeridinde yeni seans".
  # Başarılıysa exec eder (dönmez). Kapı/anahtar yoksa uyarıp aşağıdaki eski akışa düşer.
  [ "${CS_SERIT:-}" = "kapi" ] && { _serit_new_kapi "$dir" "$base" || true; }
  # Model B: her claude KENDİ tmux oturumunda + BİLİNEN session-id ile yaşasın → tmux oturum
  # adı (cc-<id8>) sid'e DETERMİNİSTİK bağlanır → başka cihazdan `cs resume` bunu attach eder
  # (gerçek ayna, fork yok). Zaten tmux içindeysek olduğumuz oturumda aç (eski davranış).
  if [ -z "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    local newid; newid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || true)
    # NOT: tmux stdin'i GERÇEK pts olmalı (ttyname→/dev/pts/N). /dev/tty'ye redirect ETME —
    # ttyname "/dev/tty" döner → tmux "can't use /dev/tty" (ampirik doğrulandı). Düz exec yeter.
    if [ -n "$newid" ]; then
      exec tmux new-session -s "cc-${newid:0:8}" -n "$pencere" "exec claude $CS_CLAUDE_FLAGS --session-id $newid"
    fi
    exec tmux new-session -s "$(_tmux_session_name "$base")" -n "$pencere" "exec claude $CS_CLAUDE_FLAGS"
  fi
  # İlk ipucu olarak proje adını sekme/pencereye yaz; claude kendi başlığını yazınca güncellenir.
  set_session_title "$pencere"
  exec claude $CS_CLAUDE_FLAGS
}

# ── cs clean [--force] ───────────────────────────────────────────────────────
# İSİMSİZ KAPALI seansları temizler. Canlı (●) seanslara ASLA dokunmaz.
# Varsayılan: çöpe taşı (geri alınabilir). --force: kalıcı sil.
TRASH_DIR="/config/.claude/sessions-trash"
cmd_clean() {
  require_jq
  local force=0
  [ "${1:-}" = "--force" ] && { force=1; shift; }

  printf 'İsimsiz kapalı seanslar taranıyor…\n' >&2
  local closed; closed=$(load_closed_sessions 100000) || true
  local targets=""
  [ -n "$closed" ] && targets=$(printf '%s\n' "$closed" | awk -F'\t' '$3 == "(isimsiz)"')
  if [ -z "$targets" ]; then
    printf 'Temizlenecek isimsiz kapalı seans yok — temiz.\n'; return
  fi

  local cnt; cnt=$(printf '%s\n' "$targets" | grep -c .)
  printf "\n${B}Temizlenecek isimsiz kapalı seanslar (%s):${Z}\n" "$cnt"
  printf '%s\n' "$targets" | awk -F'\t' \
    '{printf "  %s  %-12s  %s%s\n", substr($2,1,8), $1, $4, ($5!=""?"  ["$5"]":"")}'

  if [ "$force" = "1" ]; then
    printf "\n${Y}KALICI SİLİNECEK — geri dönüş YOK.${Z} Onaylıyorsan 'EVET' yaz: "
    local ans; read -r ans || { printf 'İptal.\n'; return 0; }
    [ "$ans" = "EVET" ] || { printf 'İptal.\n'; return; }
  else
    printf "\n→ Çöpe taşınacak: %s\nDevam? (e/H): " "$TRASH_DIR"
    local ans; read -r ans || { printf 'İptal.\n'; return 0; }
    [[ "$ans" =~ ^[eEyY]$ ]] || { printf 'İptal.\n'; return; }
    mkdir -p "$TRASH_DIR"
  fi

  local sid jsonl done=0 cleaned_sids=""
  while IFS=$'\t' read -r proj sid name age note; do
    [ -n "$sid" ] || continue
    jsonl=$(find_jsonl_for_sid "$sid")
    [ -n "$jsonl" ] && [ -f "$jsonl" ] || continue
    if [ "$force" = "1" ]; then
      rm -f "$jsonl"
    else
      mv -f "$jsonl" "$TRASH_DIR/${sid}.jsonl" 2>/dev/null || rm -f "$jsonl"
    fi
    cleaned_sids="${cleaned_sids}${sid}"$'\n'
    done=$(( done + 1 ))
  done <<< "$targets"

  # Yetim notları (session-notes.json) temizle
  if [ -f "$NOTES" ] && [ -n "$cleaned_sids" ]; then
    local ids_json tmp
    ids_json=$(printf '%s' "$cleaned_sids" | grep -v '^$' | jq -R . | jq -s .)
    tmp=$(mktemp /config/.agent-dashboard/.notes.tmp.XXXXXX)
    jq --argjson ids "$ids_json" 'delpaths([$ids[] | [.]])' "$NOTES" > "$tmp" 2>/dev/null \
      && mv "$tmp" "$NOTES" || rm -f "$tmp"
  fi

  if [ "$force" = "1" ]; then
    printf "\n%s isimsiz seans kalıcı silindi.\n" "$done"
  else
    printf "\n%s isimsiz seans çöpe taşındı → %s\n" "$done" "$TRASH_DIR"
    printf "(Geri almak: ilgili .jsonl'i %s'ten /config/.claude/projects/<proje>/ altına taşı.)\n" "$TRASH_DIR"
  fi
}

# ── cs sil <ref> — tek seansı çöpe at (canlıya dokunmaz) ─────────────────────
cmd_delete() {
  local ref="${1:-}"
  [ -n "$ref" ] || { printf 'Kullanım: sil <ref>\n' >&2; return 1; }
  local sid; sid=$(resolve_ref "$ref")          # bulunamazsa die (hub subshell'de yakalar)
  local f; f=$(session_file_for_sid "$sid") || true
  if [ -n "$f" ]; then
    printf "Uyarı: '%s' CANLI seans — silinmedi (önce kapat).\n" "$(session_display_name "$sid")" >&2
    return 1
  fi
  local jsonl; jsonl=$(find_jsonl_for_sid "$sid")
  [ -n "$jsonl" ] && [ -f "$jsonl" ] || { printf 'Transcript bulunamadı.\n' >&2; return 1; }
  local nm; nm=$(session_display_name "$sid")
  printf "Çöpe atılacak: %s\nOnay (e/H): " "$nm"
  local ans; read -r ans || { printf 'İptal.\n'; return 0; }
  [[ "$ans" =~ ^[eEyY]$ ]] || { printf 'İptal.\n'; return 0; }
  mkdir -p "$TRASH_DIR"
  mv -f "$jsonl" "$TRASH_DIR/${sid}.jsonl" 2>/dev/null || rm -f "$jsonl"
  if [ -f "$NOTES" ]; then
    local tmp; tmp=$(mktemp /config/.agent-dashboard/.notes.tmp.XXXXXX)
    jq --arg s "$sid" 'del(.[$s])' "$NOTES" > "$tmp" 2>/dev/null && mv "$tmp" "$NOTES" || rm -f "$tmp"
  fi
  printf "Çöpe atıldı: %s → %s\n" "$nm" "$TRASH_DIR"
}

# ── cs gc [--dry-run|--yes] [--age <gün>] — idle canlı seansları topla ───────
# cs clean/sil'in AKSİNE bu CANLI tmux+claude seanslarını KAPATIR (bellek baskısı
# düşürme). "idle" = tmux son-aktivite (attached bayrağı değil — ölü client
# aldatıyor). Koruma katmanları: mevcut seans · CS_GC_KEEP regex (altyapı+aile) ·
# pinned/mobile_pinned (prefs target'ından seans adı) · idle < eşik.
# Varsayılan --dry-run (önce göster). Gerçekten kapatmak için --yes.
# Eşik env ile ayarlanabilir: CS_GC_AGE (gün) · CS_GC_KEEP (regex).
CS_GC_KEEP="${CS_GC_KEEP:-Serdar|^dash|^dashproxy\$|^dashwatch\$|^imglistener\$|^imgproxy\$|^cloudtop\$}"
cmd_gc() {
  command -v tmux >/dev/null 2>&1 || die "tmux gerekli"
  require_jq
  local apply=0 age_days="${CS_GC_AGE:-3}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y)      apply=1 ;;
      --dry-run|-n)  apply=0 ;;
      --age)         shift; age_days="${1:-3}" ;;
      --age=*)       age_days="${1#--age=}" ;;
      *)             die "gc: bilinmeyen argüman '$1' (kullanım: gc [--dry-run|--yes] [--age <gün>])" ;;
    esac
    shift
  done
  local now age_sec; now=$(date +%s)
  age_sec=$(awk -v d="$age_days" 'BEGIN{printf "%d", d*86400}')

  # Kendini kapatma: cs'in içinde çalıştığı tmux seansı
  local self_sess=""; [ -n "${TMUX:-}" ] && self_sess=$(tmux display-message -p '#S' 2>/dev/null || true)

  # Pinned seans adları: prefs target'ından (sid canlı-eşleşmesine bağlı DEĞİL → sağlam)
  declare -A is_pinned
  local pn
  while IFS= read -r pn; do [ -n "$pn" ] && is_pinned["$pn"]=1; done < <(
    jq -r 'to_entries[] | select(.value.pinned or .value.mobile_pinned) | (.value.target // "") | split(":")[0]' \
      "$PREFS" 2>/dev/null | grep -v '^$')

  local kill_list="" rows="" sess act idle idle_d keep reason
  while IFS='|' read -r sess act; do
    [ -n "$sess" ] && [ -n "$act" ] || continue
    idle=$(( now - act )); idle_d=$(awk -v i="$idle" 'BEGIN{printf "%.1f", i/86400}')
    keep=""; reason=""
    if [ "$sess" = "$self_sess" ]; then keep=1; reason="mevcut"
    elif printf '%s' "$sess" | grep -qE "$CS_GC_KEEP"; then keep=1; reason="korumalı"
    elif [ -n "${is_pinned[$sess]:-}" ]; then keep=1; reason="pinned"
    elif [ "$idle" -lt "$age_sec" ]; then keep=1; reason="aktif(<${age_days}g)"
    fi
    if [ -n "$keep" ]; then
      rows="${rows}$(printf '  %-16s idle=%-6s KORU (%s)' "$sess" "${idle_d}g" "$reason")"$'\n'
    else
      rows="${rows}$(printf '  %-16s idle=%-6s ✅ KAPAT' "$sess" "${idle_d}g")"$'\n'
      kill_list="${kill_list}${sess}"$'\n'
    fi
  done < <(tmux list-sessions -F '#{session_name}|#{session_activity}' 2>/dev/null | sort -t'|' -k2 -n)

  printf '%s' "$rows"
  local cnt; cnt=$(printf '%s' "$kill_list" | grep -c . || true)
  if [ "$cnt" -eq 0 ]; then
    printf '\ncs gc: %sg+ idle kapatılacak seans yok — temiz.\n' "$age_days"; return 0
  fi
  if [ "$apply" = "0" ]; then
    printf '\n%bcs gc:%b %s idle seans KAPATILABİLİR (✅). Gerçekten kapat: %bcs gc --yes --age %s%b\n' \
      "$Y" "$Z" "$cnt" "$B" "$age_days" "$Z"
    return 0
  fi
  printf '\n%s idle seans kapatılıyor…\n' "$cnt"
  local s
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    tmux kill-session -t "$s" 2>/dev/null && printf '  ✓ %s kapatıldı\n' "$s" || printf '  ⚠ %s kapatılamadı\n' "$s"
  done <<< "$kill_list"
}

# ── Saf-bash OK-TUŞLU menü çekirdeği (bağımlılıksız, /dev/tty üzerinden) ──────
# Girdi globalleri: MENU_LABEL[] (görünen satır) · MENU_SEL[] (1=seçilebilir,0=başlık)
#   · MENU_VAL[] (seçilince dönecek değer) · MENU_TITLE · MENU_FOOT (opsiyonel).
# Çıktı: MENU_IDX (seçili index).  Dönüş: 0=Enter ile seçildi · 1=iptal (q/Esc).
clear_tty() { printf '\033[H\033[2J' >/dev/tty 2>/dev/null || true; }
pause()     { printf "${DIM}↵ devam…${Z}" >/dev/tty; read -r _ </dev/tty 2>/dev/null || true; }

tui_menu() {
  local n=${#MENU_LABEL[@]} i cur=-1 top=0 rows view key extra
  for ((i=0; i<n; i++)); do [ "${MENU_SEL[i]}" = 1 ] && { cur=$i; break; }; done
  [ "$cur" -lt 0 ] && { MENU_IDX=-1; return 1; }
  rows=$(tput lines 2>/dev/null </dev/tty || echo 40)
  view=$(( rows - 3 )); [ "$view" -lt 4 ] && view=4
  printf '\033[?25l' >/dev/tty
  while true; do
    [ "$cur" -lt "$top" ] && top=$cur
    [ "$cur" -ge "$(( top + view ))" ] && top=$(( cur - view + 1 ))
    clear_tty
    [ -n "${MENU_TITLE:-}" ] && printf '%b\n' "$MENU_TITLE" >/dev/tty
    for ((i=top; i<top+view && i<n; i++)); do
      if [ "$i" = "$cur" ]; then
        printf '\033[7m▶ %s\033[0m\n' "${MENU_LABEL[i]}" >/dev/tty
      else
        printf '  %b\n' "${MENU_LABEL[i]}" >/dev/tty
      fi
    done
    [ -n "${MENU_FOOT:-}" ] && printf '%b' "$MENU_FOOT" >/dev/tty
    IFS= read -rsn1 key </dev/tty || { printf '\033[?25h' >/dev/tty; MENU_IDX=-1; return 1; }
    if [ "$key" = $'\033' ]; then read -rsn2 -t 0.02 extra </dev/tty 2>/dev/null || true; key="$key$extra"; fi
    case "$key" in
      $'\033[A'|$'\033OA'|k) for ((i=cur-1; i>=0;  i--)); do [ "${MENU_SEL[i]}" = 1 ] && { cur=$i; break; }; done ;;
      $'\033[B'|$'\033OB'|j) for ((i=cur+1; i<n;   i++)); do [ "${MENU_SEL[i]}" = 1 ] && { cur=$i; break; }; done ;;
      ''|$'\n'|$'\r')        printf '\033[?25h' >/dev/tty; MENU_IDX=$cur; return 0 ;;
      q|Q|$'\033')           printf '\033[?25h' >/dev/tty; MENU_IDX=-1; return 1 ;;
    esac
  done
}

# Ana menü verisini topla → MENU_LABEL/MENU_SEL/MENU_VAL (üst aksiyonlar + gruplu seanslar + çık).
build_main_menu() {
  MENU_LABEL=(); MENU_SEL=(); MENU_VAL=()
  MENU_LABEL+=("${G}➕  Yeni seans başlat…${Z}");        MENU_SEL+=(1); MENU_VAL+=("__new__")
  # L25-W7 · SAĞLIK KAPISI: kapı kırmızıysa satır seçilemez ve NEDENİNİ söyler.
  if _kapi_saglik_cached; then
    MENU_LABEL+=("${G}🚪  Kapı şeridinde yeni seans…${Z}"); MENU_SEL+=(1); MENU_VAL+=("__kapinew__")
  else
    MENU_LABEL+=("${DIM}🚪  Kapı şeridi — kapı yanıt vermiyor (kullanılamaz)${Z}"); MENU_SEL+=(0); MENU_VAL+=("")
  fi
  MENU_LABEL+=("${DIM}🧹  İsimsiz seansları temizle${Z}"); MENU_SEL+=(1); MENU_VAL+=("__clean__")
  MENU_LABEL+=("");                                       MENU_SEL+=(0); MENU_VAL+=("")

  local live_raw closed_raw all="" sorted
  live_raw=$(load_sessions) || true
  closed_raw=$(load_closed_sessions 60) || true
  [ -n "$live_raw" ]   && all+="$(printf '%s\n' "$live_raw" | awk -F'\t' \
    '{nn=split($6,a,"/");proj=a[nn];ref=($2!=""?$2:"["$1"]"); print "L\t"proj"\t"ref"\t"$4"\t"$5"\t"$3}')"$'\n'
  [ -n "$closed_raw" ] && all+="$(printf '%s\n' "$closed_raw" | awk -F'\t' \
    '{print "C\t"$1"\t"substr($2,1,8)"\t"$3"\t"$4"\t"$2}')"$'\n'
  # KATMAN-1/2 çoklu-grup pin: 🏛 EKİP → 🛰 FİLO → gerisi proj'e göre (set -e güvenli).
  sorted=$( { printf '%s\n' "$all" | grep -v '^$' | grep -aF "$EKIP_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
              printf '%s\n' "$all" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -aF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
              printf '%s\n' "$all" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -avF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true; } )

  # L25-W7: şerit-işaretli sid kümesini TEK jq ile al (satır-başı jq = 70+ seansta yavaşlık).
  local serit_ids=""
  [ -f "$NOTES" ] && serit_ids=$(jq -r 'to_entries[] | select(.value.serit.ad // "" != "") | .key' "$NOTES" 2>/dev/null || printf '')

  local lastproj="" type proj ref name info sid dot
  while IFS=$'\037' read -r type proj ref name info sid; do
    [ -z "$proj" ] && continue
    if [ "$proj" != "$lastproj" ]; then
      MENU_LABEL+=("${B}── $proj${Z}"); MENU_SEL+=(0); MENU_VAL+=(""); lastproj="$proj"
    fi
    [ "$type" = L ] && dot="${G}●${Z}" || dot="${DIM}○${Z}"
    [ -z "$name" ] && name="—"
    # L25-W7: 🚪 rozeti yalnız şerit-işaretli satıra (işaretsiz satır eskisiyle aynı).
    case $'\n'"$serit_ids"$'\n' in *$'\n'"$sid"$'\n'*) dot="${dot}🚪" ;; esac
    MENU_LABEL+=("$(printf '%s %-7s %-24.24s %s' "$dot" "$ref" "$name" "$info")")
    MENU_SEL+=(1); MENU_VAL+=("$sid")
  done < <(printf '%s\n' "$sorted" | tr '\t' '\037')

  MENU_LABEL+=("");           MENU_SEL+=(0); MENU_VAL+=("")
  MENU_LABEL+=("✕  Çık");     MENU_SEL+=(1); MENU_VAL+=("__quit__")
}

# Proje seçici (yeni seans için).
menu_new() {
  MENU_LABEL=(); MENU_SEL=(); MENU_VAL=()
  local d label
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    label=$(basename "$d")
    MENU_LABEL+=("📁  $label   ${DIM}$d${Z}"); MENU_SEL+=(1); MENU_VAL+=("$d")
  done < <( ls -d /config/projects/*/ 2>/dev/null | sed 's:/*$::' | sort )
  MENU_LABEL+=(""); MENU_SEL+=(0); MENU_VAL+=("")
  MENU_LABEL+=("←  Geri"); MENU_SEL+=(1); MENU_VAL+=("__back__")
  local _t="Yeni seans · proje seç"
  [ "${CS_SERIT:-}" = "kapi" ] && _t="🚪 Kapı şeridinde yeni seans · proje seç"
  MENU_TITLE="${B}${_t}${Z}   ${DIM}↑/↓ · Enter · q geri${Z}\n"; MENU_FOOT=""
  tui_menu || return
  local v="${MENU_VAL[$MENU_IDX]}"
  [ "$v" = "__back__" ] && return
  clear_tty; cmd_new "$v"          # tam yol → cd + exec claude
}

# Seçili seans için aksiyon menüsü.
menu_session() {
  local sid="$1"
  case "$sid" in __federe_*) return ;; esac   # federe/izole roster satırı → aksiyon yok (resume-dışı, META-ONLY)
  while true; do
    local nm f live; nm=$(session_display_name "$sid")
    f=$(session_file_for_sid "$sid") || true
    [ -n "$f" ] && live="${G}● CANLI${Z}" || live="${DIM}○ kapalı${Z}"
    # L25-W7: kapı satırı + başlıkta mevcut şerit rozeti. Kapı kırmızıysa satır seçilemez.
    local kapi_lbl kapi_sel
    if _kapi_saglik_cached; then kapi_lbl="🚪  Kapı şeridinde devam et"; kapi_sel=1
    else kapi_lbl="${DIM}🚪  Kapı şeridi — kapı yanıt vermiyor${Z}"; kapi_sel=0; fi
    local cur_serit; cur_serit=$(_serit_get "$sid")
    MENU_LABEL=("▶  Devam et (resume)" "$kapi_lbl" "✎  Adlandır" "✐  Not ekle/düzenle" "🗑  Sil (çöpe at)" "ℹ  Bilgi" "←  Geri")
    MENU_SEL=(1 "$kapi_sel" 1 1 1 1 1); MENU_VAL=(resume resume_kapi rename note delete info back)
    MENU_TITLE="${B}» $nm${Z}   $live${cur_serit:+   ${C}🚪 $cur_serit${Z}}   ${DIM}↑/↓ · Enter · q geri${Z}\n"; MENU_FOOT=""
    tui_menu || return
    case "${MENU_VAL[$MENU_IDX]}" in
      resume) clear_tty; cmd_resume "$sid" ;;                       # exec
      resume_kapi) clear_tty; cmd_resume_kapi "$sid" ;;             # exec (🚪 kapı şeridi)
      rename) clear_tty; printf 'Yeni isim: ' >/dev/tty; local nn; IFS= read -r nn </dev/tty
              [ -n "$nn" ] && ( cmd_rename "$sid" "$nn" ) || printf 'Boş — iptal.\n' >/dev/tty; pause; return ;;
      note)   clear_tty; printf 'Not (boş = sil): ' >/dev/tty; local nt; IFS= read -r nt </dev/tty
              ( cmd_note "$sid" "$nt" ); pause; return ;;
      delete) clear_tty; ( cmd_delete "$sid" ); pause; return ;;
      info)   clear_tty; ( cmd_info "$sid" ); pause ;;
      back)   return ;;
    esac
  done
}

# ── fzf picker motoru (varsa cilalı arayüz; yoksa tui_menu fallback) ─────────
have_fzf() { command -v fzf >/dev/null 2>&1; }

# fzf girdi satırları: SID \t <görünür>  (tek tab; --with-nth=2.. ile sid gizlenir, {1}=sid).
# Görünür blok: ●/○ ref isim durum proje not  (renkler --ansi ile). Reload da bunu kullanır.
cmd_feed() {
  require_jq
  # KALABALIK KAPISI (Sultan, 2026-07-30): "kapanan sohbete dön deyince çok karmaşık bir
  # cümbüşün içine düşüyorum". Ölçtüm: listenin 104 satırının 80'i KAPALI geçmişti — %88'i
  # tarih, canlı iş 11 satır. Varsayılan artık son 15 kapalı; gerisi ^A ile açılır.
  # ⚠️ SESSİZ KIRPMA YOK: gizlenen sayı listenin SONUNDA yazılır (aksi hâlde "hepsi bu"
  # sanılır — bugün tam bu sınıftan üç arıza çıktı).
  local TAM=0
  [ "${1:-}" = "--hepsi" ] && TAM=1
  local KAPALI_VARSAYILAN="${CS_KAPALI_LIMIT:-15}" KAPALI_TAM=80
  local limit="$KAPALI_VARSAYILAN"; [ "$TAM" = "1" ] && limit="$KAPALI_TAM"
  local live_raw closed_raw all="" sorted
  live_raw=$(load_sessions) || true
  closed_raw=$(load_closed_sessions "$limit") || true
  local kapali_tum kapali_gosterilen gizli=0
  kapali_tum=$(load_closed_sessions "$KAPALI_TAM" 2>/dev/null | grep -c . || printf '0')
  kapali_gosterilen=$(printf '%s' "$closed_raw" | grep -c . || printf '0')
  gizli=$(( kapali_tum - kapali_gosterilen )); [ "$gizli" -lt 0 ] && gizli=0
  [ -n "$live_raw" ]   && all+="$(printf '%s\n' "$live_raw" | awk -F'\t' \
    '{nn=split($6,a,"/");proj=a[nn];ref=($2!=""?$2:"["$1"]"); print "L\t"proj"\t"ref"\t"$4"\t"$5"\t"$7"\t"$3}')"$'\n'
  [ -n "$closed_raw" ] && all+="$(printf '%s\n' "$closed_raw" | awk -F'\t' \
    '{print "C\t"$1"\t"substr($2,1,8)"\t"$3"\t"$4"\t"$5"\t"$2}')"$'\n'
  # KATMAN-1/2 çoklu-grup pin: 🏛 EKİP → 🛰 FİLO → gerisi proj'e göre (set -e güvenli).
  sorted=$( { printf '%s\n' "$all" | grep -v '^$' | grep -aF "$EKIP_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
              printf '%s\n' "$all" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -aF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true
              printf '%s\n' "$all" | grep -v '^$' | grep -avF "$EKIP_TAG" | grep -avF "$FEDERE_TAG" | sort -t$'\t' -k2,2 -k1,1r || true; } )
  # L25-W7: şerit-işaretli sid'ler (sid<TAB>ad). İşaretsizde harita boş → satırlar byte-aynı.
  local serit_map=""
  [ -f "$NOTES" ] && serit_map=$(jq -r 'to_entries[] | select(.value.serit.ad // "" != "") | "\(.key)\t\(.value.serit.ad)"' "$NOTES" 2>/dev/null || printf '')
  printf '%s\n' "$sorted" | awk -F'\t' \
      -v G="$(printf '\033[0;32m')" -v Y="$(printf '\033[1;33m')" \
      -v C="$(printf '\033[0;36m')" -v D="$(printf '\033[2m')" -v Z="$(printf '\033[0m')" \
      -v B="$(printf '\033[1;36m')" -v SERIT="$serit_map" '
    BEGIN { sn=split(SERIT, SL, "\n")
            for (si=1; si<=sn; si++) { split(SL[si], SP, "\t"); if (SP[1] != "") SMAP[SP[1]]=SP[2] } }
    NF>=7 {
      type=$1; proj=$2; ref=$3; name=$4; info=$5; note=$6; sid=$7
      # Projeye göre GRUPLAMA: proje değişince başlık satırı (sid=__hdr__, seçilemez/no-op).
      if (proj != lastproj) { printf "__hdr__\t%s┄┄ %s ┄┄┄┄┄┄┄┄┄┄┄┄┄┄%s\n", B, (proj==""?"(diğer)":proj), Z; lastproj=proj }
      if (type=="L") { dot=G"●"Z; col=(info=="busy"?Y:(info=="idle"?G:(info=="waiting"?C:""))) }
      else          { dot=D"○"Z; col=D }
      if (name=="") name="—"
      # 🚪 rozeti YALNIZ işaretli satıra eklenir → işaretsiz satır eski çıktıyla byte-aynı.
      if (sid in SMAP) dot = dot "🚪"
      printf "%s\t  %s %-7s %-30.30s %s%-8s%s %s\n", \
        sid, dot, ref, name, col, info, Z, note
    }'
  # Gizlenen kapalı seansları AÇIKÇA söyle — seçilemez başlık satırı olarak (no-op).
  if [ "$gizli" -gt 0 ]; then
    printf '__hdr__\t%s  … %s kapalı seans daha var — ^A ile hepsini göster%s\n' \
      "$(printf '\033[2m')" "$gizli" "$(printf '\033[0m')"
  fi
}

# Önizleme paneli: seans özeti + transcript kuyruğu (son mesajlar). Argüman: sid.
# Hız önemli (fzf her ok hareketinde çağırır) → session_file_for_sid'i TEK kez çağır,
# jsonl/cwd'yi ondan türet (session_display_name + ekstra aramalardan kaçın).
cmd_preview() {
  local sid="${1:-}"; [ -n "$sid" ] || return 0
  [ "$sid" = "__hdr__" ] && return 0   # grup başlığı satırı → önizleme yok
  local B0 Z0 D0 GR; B0=$(printf '\033[1m'); Z0=$(printf '\033[0m'); D0=$(printf '\033[2m'); GR=$(printf '\033[0;32m')
  case "$sid" in                       # İ1: federe/izole roster satırı → resume-dışı, YALNIZ META (içerik ASLA)
    __federe_*) local _ft="${sid#__federe_}"; _ft="${_ft%__}"
      printf '%b%s · %s%b\n' "$B0" "$FEDERE_TAG" "$_ft" "$Z0"
      printf '%bTür:%b federe/izole birim (bu konteynerden erişilemez)\n' "$B0" "$Z0"
      printf '%bGörünürlük:%b META-ONLY — başlık/transcript/görev-içeriği gösterilmez\n' "$B0" "$Z0"
      return 0 ;;
  esac
  local f jsonl cwd nm
  f=$(session_file_for_sid "$sid") || true
  if [ -n "$f" ]; then
    cwd=$(jq -r '.cwd // ""' "$f" 2>/dev/null || true)
    jsonl=$(jsonl_path "$sid" "$cwd"); [ -f "$jsonl" ] || jsonl=""
  fi
  if [ -z "${jsonl:-}" ]; then
    jsonl=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${sid}*.jsonl" \
      -not -path '*/subagents/*' -not -path '*/tool-results/*' -not -path '*/workflows/*' 2>/dev/null | head -1)
    [ -z "${cwd:-}" ] && [ -n "$jsonl" ] && cwd=$(grep -aom1 '"cwd":"[^"]*"' "$jsonl" 2>/dev/null | sed 's/.*"cwd":"//; s/"$//')
  fi
  # İ1 META-ONLY fail-closed: cwd bir izole-tenant'a aitse başlık/transcript render dalını KAPAT.
  local iso=0; _is_isolated_tenant "${cwd:-}" && iso=1
  nm=""; [ "$iso" != 1 ] && [ -n "$jsonl" ] && [ -f "$jsonl" ] && nm=$(session_meta_from_jsonl "$jsonl" | cut -f1)
  [ "$nm" = "(isimsiz)" ] && nm=""; [ -z "$nm" ] && nm="${sid:0:8}"
  printf '%b%s%b\n' "$B0" "$nm" "$Z0"
  if [ -n "$f" ]; then
    printf '%bDurum:%b %s   %b● CANLI%b\n' "$B0" "$Z0" "$(jq -r '.status//"?"' "$f" 2>/dev/null)" "$GR" "$Z0"
  else
    printf '%bDurum:%b ○ kapalı\n' "$B0" "$Z0"
  fi
  [ -n "${cwd:-}" ] && printf '%bDizin:%b %s\n' "$B0" "$Z0" "$cwd"
  local note; note=$([ -f "$NOTES" ] && jq -r --arg s "$sid" '.[$s].note // ""' "$NOTES" 2>/dev/null || printf '')
  [ -n "$note" ] && printf '%bNot:%b %s\n' "$B0" "$Z0" "$note"
  # L25-W7: şerit + transcript'ten türetilen son model (yalnız işaretliyse/varsa basılır).
  local serit; serit=$([ -f "$NOTES" ] && jq -r --arg s "$sid" '.[$s].serit.ad // ""' "$NOTES" 2>/dev/null || printf '')
  if [ -n "$serit" ]; then
    printf '%bŞerit:%b 🚪 %s\n' "$B0" "$Z0" "$serit"
    if [ "$iso" != 1 ] && [ -n "${jsonl:-}" ] && [ -f "$jsonl" ]; then
      local mdl; mdl=$(tail -c 200000 "$jsonl" 2>/dev/null | grep -ao '"model":"[^"]*"' | tail -1 | sed 's/.*"model":"//; s/"$//')
      [ -n "$mdl" ] && printf '%bSon model:%b %s\n' "$D0" "$Z0" "$mdl"
    fi
  fi
  printf '%bID:%b %s\n' "$D0" "$Z0" "$sid"
  if [ "$iso" = 1 ]; then
    printf '\n%b🛰 İZOLE TENANT — META-ONLY%b\nBaşlık/transcript gizli (mahremiyet, fail-closed).\n' "$B0" "$Z0"
  elif [ -n "$jsonl" ] && [ -f "$jsonl" ]; then
    printf '\n%bSon mesajlar:%b\n' "$B0" "$Z0"
    tail -c 200000 "$jsonl" 2>/dev/null | tr -d '\0' \
      | grep -aE '"role":"(user|assistant)"|"type":"(user|assistant)"' | tail -5 \
      | while IFS= read -r line; do
          printf '%s' "$line" | jq -r '
            (.message.role // .type // "?") as $r |
            ((.message.content) as $c |
               if ($c|type)=="array" then ([$c[]|select(.type=="text")|.text]|join(" "))
               elif ($c|type)=="string" then $c else "" end) as $t |
            ($t|gsub("[\\s]+";" ")) as $t |
            (if $r=="user" then "▸ sen: " else "◂ claude: " end) as $p |
            if ($t|length)>0 then $p + ($t[0:220]) else empty end' 2>/dev/null
        done
  fi
}

# ctrl-e (adlandır): fzf execute() içinde tam-ekran; tty'den yeni ismi okur.
cmd_rename_prompt() {
  local sid="${1:-}"; [ -n "$sid" ] || return 0
  printf 'Yeni isim (%s): ' "$(session_display_name "$sid")"
  local n; IFS= read -r n || return 0
  [ -n "$n" ] && cmd_rename "$sid" "$n"
}

# ctrl-n (yeni seans): fzf ile proje seç → cmd_new (exec). İptalde menüye dön.
cmd_newpick() {
  local dir
  # Yalnız /config/projects ALTINDAKİ proje klasörleri (alt-klasör/cwd kirliliği yok).
  dir=$( ls -d /config/projects/*/ 2>/dev/null | sed 's:/*$::' | sort \
        | fzf --ansi --height=100% --layout=reverse --prompt='yeni seans · proje » ' \
              --header='Enter: bu projede yeni seans · ESC: iptal' ) || dir=""
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    # AD SOR (Sultan, 2026-07-30): "rastgele açtığım sessionlarda onun amacı/adı istenmeli".
    # Eskiden ^N adsız açıyordu → liste "—" ile doluyordu ve hangisi olduğu bilinmiyordu.
    # Kardeş kapı `yenisession` bunu zaten soruyor; motor da `new --ad` kabul ediyor →
    # yeni mekanizma İCAT EDİLMEDİ, var olan uç kullanıldı (ikinci gerçek doğmaz).
    local ad=""
    if [ -r /dev/tty ]; then
      printf 'Bu sohbetin adı ne olsun? (boş bırakabilirsin): ' > /dev/tty
      read -r ad < /dev/tty || ad=""
    fi
    if [ -n "$ad" ]; then cmd_new --ad "$ad" "$dir"; else cmd_new "$dir"; fi
  else exec cs menu; fi
}

# Ana fzf menüsü: tek picker tüm aksiyonları barındırır (--bind), sağda önizleme.
cmd_menu_fzf() {
  # KÖK FIX: 'become(cs resume)' fzf'in alt-ekran/raw terminalini tmux'a bozuk devrediyordu
  # → "open terminal failed: can't use /dev/tty". Bunun yerine fzf SEÇİMİ döndürsün; tmux'u
  # fzf TAM ÇIKTIKTAN SONRA (terminal restore edilmiş, temiz) kabuktan exec edelim.
  # rename/sil/temizle hâlâ execute() (fzf'e döner) — onlar tmux başlatmıyor, sorun yok.
  local out key sid hdr
  # L25-W7: kapı kısayolları + SAĞLIK KAPISI — kapı kırmızıysa başlık UYARIR (sessiz-kırık yok).
  if _kapi_saglik_cached; then
    hdr=$'Enter devam · ^N yeni · ^A tüm geçmiş · ^K 🚪kapıda devam · ^G 🚪kapıda yeni · ^E adlandır · ^X sil · ^T temizle · ESC çık'
  else
    hdr=$'Enter devam · ^N yeni · ^A tüm geçmiş · ^E adlandır · ^X sil · ^T temizle · ESC çık\n⚠ Kapı yanıt vermiyor → 🚪 şerit şu an kullanılamaz, varsayılan şeride düşülür'
  fi
  out=$(fzf --ansi --delimiter=$'\t' --with-nth='2..' \
      --height='100%' --layout=reverse --info=inline --cycle \
      --prompt='cs » ' --pointer='▶' \
      --header="$hdr" \
      --preview='cs _preview {1}' --preview-window='right,52%,wrap,border-left' \
      --expect='ctrl-n,ctrl-k,ctrl-g' \
      --bind='ctrl-e:execute(cs _rename {1})+reload(cs _feed)' \
      --bind='ctrl-x:execute(cs sil {1})+reload(cs _feed)' \
      --bind='ctrl-t:execute(cs clean)+reload(cs _feed)' \
      --bind='ctrl-a:reload(cs _feed --hepsi)' \
      --bind='ctrl-/:toggle-preview' \
      < <(cmd_feed)) || true
  key=$(printf '%s\n' "$out" | sed -n 1p)
  sid=$(printf '%s\n' "$out" | sed -n 2p | cut -f1)
  case "$key" in
    ctrl-n) cmd_newpick ;;                          # yeni seans (exec tmux — temiz terminal)
    ctrl-g) CS_SERIT=kapi; cmd_newpick ;;           # 🚪 kapı şeridinde yeni seans
    ctrl-k) [ -n "$sid" ] && cmd_resume_kapi "$sid" ;;  # 🚪 kapı şeridinde devam et
    *)      [ -n "$sid" ] && cmd_resume "$sid" ;;   # devam/attach (exec tmux — temiz terminal)
  esac
}

# ── cs (argümansız) — İNTERAKTİF OK-TUŞLU MENÜ ───────────────────────────────
cmd_menu() {
  # TTY yoksa düz listeye düş (pipe/script bağlamı).
  if [ ! -t 0 ] || [ ! -t 1 ]; then cmd_ls; return; fi
  # fzf varsa cilalı picker; yoksa elle TUI (fallback — recreate sonrası IaC öncesi de çalışır).
  if have_fzf; then cmd_menu_fzf; return; fi
  trap 'printf "\033[?25h\033[0m" >/dev/tty 2>/dev/null' INT
  while true; do
    build_main_menu
    MENU_TITLE="${B}cs · Claude Seans Yöneticisi${Z}   ${DIM}↑/↓ gez · Enter seç · q çık${Z}\n"; MENU_FOOT=""
    tui_menu || break
    case "${MENU_VAL[$MENU_IDX]}" in
      __new__)   menu_new ;;
      __kapinew__) CS_SERIT=kapi; menu_new; CS_SERIT="" ;;   # L25-W7 · 🚪 kapı şeridinde yeni seans
      __clean__) clear_tty; ( cmd_clean ); pause ;;
      __quit__)  break ;;
      "")        : ;;                       # başlık seçilemez (olmaz ama garanti)
      *)         menu_session "${MENU_VAL[$MENU_IDX]}" ;;
    esac
  done
  clear_tty
}

# ── Ana komut dağıtıcı ───────────────────────────────────────────────────────
case "${1:-menu}" in
  menu)           cmd_menu ;;
  ls|list)        cmd_ls ;;
  rename|r)       shift; cmd_rename "$@" ;;
  note|n)         shift; cmd_note "$@" ;;
  resume|re)      shift 2>/dev/null || true
                  if [ "${1:-}" = "--serit" ]; then CS_SERIT="${2:-}"; shift 2 2>/dev/null || shift $# ; fi
                  # --serit kapi ile devam: önce işaretle, sonra normal akış (kalıcı olur).
                  if [ "${CS_SERIT:-}" = "kapi" ]; then
                    [ -n "${1:-}" ] || die "Kullanım: cs resume --serit kapi <ref>  (ref zorunlu)"
                    cmd_resume_kapi "$(resolve_ref "$1")"
                  else cmd_resume "${1:-}"; fi ;;
  new|yeni)       shift
                  if [ "${1:-}" = "--serit" ]; then CS_SERIT="${2:-}"; shift 2 2>/dev/null || shift $# ; fi
                  if [ "${1:-}" = "--ad" ]; then cmd_new --ad "${2:-}" "${3:-}"; else cmd_new "${1:-}"; fi ;;
  serit|lane)     shift; cmd_serit "$@" ;;
  name|whoami)    shift; cmd_name "${1:-}" ;;
  clean|temizle)  shift; cmd_clean "$@" ;;
  gc|topla)       shift; cmd_gc "$@" ;;
  sil|delete)     shift; cmd_delete "${1:-}" ;;
  info|i)         shift; cmd_info "${1:-}" ;;
  _feed)          shift; cmd_feed "$@" ;;            # (iç) fzf girdisi (--hepsi: tüm kapalı geçmiş)
  _preview)       shift; cmd_preview "${1:-}" ;;   # (iç) fzf önizleme paneli
  _rename)        shift; cmd_rename_prompt "${1:-}" ;;  # (iç) fzf ctrl-e
  _newpick)       cmd_newpick ;;                   # (iç) fzf ctrl-n
  _serit)         shift; cmd_serit "$@" ;;         # (iç) şerit işareti oku/yaz
  help|-h|--help)
    printf '%s\n' \
      "cs — Claude Code Seans Yöneticisi" "" \
      "  cs                       İNTERAKTİF MENÜ (seç→devam/adlandır/not/sil · +proje · temizle)" \
      "" \
      "Doğrudan komutlar:" \
      "  cs ls                    Tüm seansları listele (canlı + kapalı)" \
      "  cs resume [ref]          Seansa devam et" \
      "  cs new [proje|yol]       Yeni (sıfır) seans başlat (proje dizininde)" \
      "  cs rename <ref> <isim>   Seans ismini değiştir" \
      "  cs note <ref> [metin]    Not ekle/güncelle (boş = sil)" \
      "  cs sil <ref>             Seansı çöpe at (canlıya dokunmaz)" \
      "  cs clean [--force]       İsimsiz KAPALI seansları temizle (çöpe taşı; --force=sil)" \
      "  cs gc [--yes] [--age N]  IDLE CANLI seansları kapat (bellek boşalt; vars. --dry-run, eşik 3g)" \
      "  cs name [ref]            Görünür adı yazdır (ref yoksa: mevcut seans)" \
      "  cs info [ref]            Seans detayları (ref yoksa: mevcut seans)" \
      "" \
      "🚪 Şerit (hangi model-kapısı):" \
      "  cs serit <ref>              Seansın şeridini göster" \
      "  cs serit <ref> kapi         Kapı şeridinde işaretle (her devam-edişte geri kurulur)" \
      "  cs serit <ref> varsayilan   İşareti kaldır (varsayılan Anthropic şeridi)" \
      "  cs resume --serit kapi <ref>  Kapı şeridinde devam et (+ kalıcı işaretle)" \
      "  cs new --serit kapi [proje]   Kapı şeridinde yeni seans" \
      "  Menüde: ^K kapıda devam · ^G kapıda yeni  (fzf) — kapı kırmızıysa satır uyarır" \
      "" \
      "<ref>: kısa kod (1,2..) · UUID öneki · 'current'/'.' · isim parçası"
    ;;
  *)
    die "Bilinmeyen komut: '${1}'. Yardım için: cs help"
    ;;
esac
