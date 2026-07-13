#!/usr/bin/env bash
# seyir-defteri — keşif-günlüğü + döngü-refleksiyon (GLOBAL-skill · MİMSERDAR-SPEC v2 · 2026-07-10).
# Yan-keşifler (aslında-şöyleymiş / bug / risk / fırsat) rapora gömülüp KAYBOLMASIN diye append-only defter.
# ÇEKİRDEK (her-ekip): yaz · oku · isaretle · durum   ·   RİTÜEL (opsiyonel): refleksiyon   ·   migrate.
#
#   seyir-defteri "<metin>" [--sev=kritik|onemli|bilgi] [--tur=bug|iyilestirme|varsayim-curudu|risk|soru|firsat|oneri|gozlem]
#                           [--baglam=dosya:satır] [--dongu=<n>] [--sir-onay]
#   seyir-defteri oku       [--sev=] [--tur=] [--durum=acik|okundu|sonraki-donguye|kapatildi] [--kim=] [--dongu=]
#   seyir-defteri isaretle  <id> <acik|okundu|sonraki-donguye|kapatildi>
#   seyir-defteri durum     → özet-sayaç (açık · kritik-açık · güncel-döngü)
#   seyir-defteri refleksiyon [<n>]                       → döngü-ritüeli (oku+4-soru+işaretleme-rehberi+özet-iste)
#   seyir-defteri refleksiyon --ne="…" --siradaki="…" [--dongu=<n>]  → döngü-özet YAZ (ozet-event + sayaç-ilerler)
#   seyir-defteri migrate   <eski-md>                     → [KEŞİF]-md → jsonl (idempotent, eski arşivlenir)
#
# Store = <git-kök>/seyir-defteri.jsonl (env-override SEYIR_DEFTERI). append-only 3-event (not/disp/ozet),
# disposition ayrı-event (reader son-disp-per-id KATLAR) → satır-edit YOK, flock-güvenli. Kimlik uydurma-YOK.
# Sır-değer serbest-metne YAZILMAZ (sk-…/token=/password= deseni → uyar+onay-iste). Render deterministik/LLM-yok.
set -uo pipefail

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq yok (seyir-defteri jq gerektirir)"

# ── store çöz (git-kök; env-override; proje-agnostik) ────────────────────────────────────
_store(){
  if [ -n "${SEYIR_DEFTERI:-}" ]; then printf '%s' "$SEYIR_DEFTERI"; return 0; fi
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] || die "git-repo değil (git-kök bulunamadı) — SEYIR_DEFTERI env ile yol ver"
  printf '%s/seyir-defteri.jsonl' "$root"
}
STORE="$(_store)"

# ── kimlik (erisim.sh emsali · uydurma-YOK) ──────────────────────────────────────────────
_kim(){
  if [ -n "${EKIP_UYE:-}" ]; then printf '%s' "$EKIP_UYE"; return; fi
  if [ -n "${AGENT_NAME:-}" ]; then printf '%s' "$AGENT_NAME"; return; fi
  printf '%s:%s' "$(hostname 2>/dev/null || echo host)" "$(basename "$(pwd 2>/dev/null || echo '?')")"
}

_now(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

VALID_SEV="kritik onemli bilgi"
VALID_TUR="bug iyilestirme varsayim-curudu risk soru firsat oneri gozlem"
VALID_DURUM="acik okundu sonraki-donguye kapatildi"
_in(){ local x="$1"; shift; local w; for w in $*; do [ "$w" = "$x" ] && return 0; done; return 1; }

# ── güncel-döngü-no = son ozet.dongu + 1 (durable, transkript-bağımsız); ozet yoksa 1 ────
_current_dongu(){
  local last=""
  [ -f "$STORE" ] && last="$(jq -r 'select(.tip=="ozet") | .dongu' "$STORE" 2>/dev/null | sort -n | tail -1)"
  if [ -n "$last" ]; then printf '%s' "$((last+1))"; else printf '1'; fi
}

# ── flock-korumalı satır-append (self-contained; Nexus-scripts bağımlılığı YOK) ──────────
_locked_append(){  # _locked_append <jsonl-satırı>
  local line="$1"
  if command -v flock >/dev/null 2>&1; then
    { flock 9; printf '%s\n' "$line" >> "$STORE"; } 9>>"$STORE"
  else
    printf '%s\n' "$line" >> "$STORE"
  fi
}

# ── sır-desen uyarısı (H · uyar+onay; non-TTY & onaysız → yazMA) ──────────────────────────
_sir_uyari(){  # _sir_uyari <metin> <sir_onay(0/1)>
  local metin="$1" onay="$2"
  if printf '%s' "$metin" | grep -qiE 'sk-[a-z0-9]|token=|password=|passwd=|secret=|api[_-]?key='; then
    ylw "⚠️  Metinde SIR-DESENİ saptandı (sk-…/token=/password=/secret=/api_key=)."
    ylw "    Seyir-defteri İÇGÖRÜ günlüğüdür — sır DEĞERİ buraya YAZILMAZ (konum/ad yaz, değer değil)."
    if [ "$onay" = "1" ]; then
      ylw "    → --sir-onay verildi: yine de yazılıyor (sorumluluk sende)."
      return 0
    fi
    if [ -t 0 ]; then
      local c; read -rp "    Yine de yazılsın mı? (e/H): " c
      case "$c" in e|E|evet|E*) return 0 ;; *) die "iptal — sır-değer yazılmadı" ;; esac
    fi
    die "sır-deseni saptandı, yazılmadı — teyit için: --sir-onay (değer-yazmak önerilmez)"
  fi
  return 0
}

# ═══ YAZ (not-event) ═════════════════════════════════════════════════════════════════════
cmd_yaz(){
  local metin="" sev="bilgi" tur="gozlem" baglam="" dongu="" sir_onay=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --sev=*)    sev="${1#--sev=}" ;;
      --tur=*)    tur="${1#--tur=}" ;;
      --baglam=*) baglam="${1#--baglam=}" ;;
      --dongu=*)  dongu="${1#--dongu=}" ;;
      --sir-onay) sir_onay=1 ;;
      --sev|--tur|--baglam|--dongu) die "bayrak '$1' = biçimini kullan (ör: --sev=onemli)" ;;
      --*) die "bilinmeyen bayrak: $1" ;;
      *) [ -z "$metin" ] && metin="$1" || die "birden çok metin verildi (tırnakla: \"…\")" ;;
    esac
    shift
  done
  [ -n "$metin" ] || die "kullanım: seyir-defteri \"<metin>\" [--sev=] [--tur=] [--baglam=] [--dongu=]"

  # ALIAS: --sev=firsat → --tur=firsat (sev=bilgi'ye düşer) — MMEx kas-hafızası korunur.
  if [ "$sev" = "firsat" ]; then tur="firsat"; sev="bilgi"; fi

  _in "$sev" "$VALID_SEV" || die "geçersiz sev '$sev' (geçerli: $VALID_SEV · alias: firsat→tur)"
  _in "$tur" "$VALID_TUR" || die "geçersiz tur '$tur' (geçerli: $VALID_TUR)"
  [ -z "$dongu" ] && dongu="$(_current_dongu)"
  case "$dongu" in ''|*[!0-9]*) die "dongu sayı olmalı: '$dongu'";; esac

  _sir_uyari "$metin" "$sir_onay"

  local kim ts; kim="$(_kim)"; ts="$(_now)"
  # id flock-İÇİNDE hesaplanır → eşzamanlı-yazımda çift-id/satır-kaybı olmaz.
  local id
  if command -v flock >/dev/null 2>&1; then
    exec 9>>"$STORE"
    flock 9
  fi
  id="$(_seq_next_id)"
  local line; line="$(jq -nc \
    --arg id "$id" --arg ts "$ts" --arg kim "$kim" --arg sev "$sev" --arg tur "$tur" \
    --arg metin "$metin" --arg baglam "$baglam" --argjson dongu "$dongu" \
    '{v:1,tip:"not",id:$id,ts:$ts,kim:$kim,sev:$sev,tur:$tur,metin:$metin}
     + (if $baglam=="" then {} else {baglam:$baglam} end) + {dongu:$dongu}')"
  printf '%s\n' "$line" >> "$STORE"
  if command -v flock >/dev/null 2>&1; then flock -u 9; exec 9>&-; fi

  grn "✓ kaydedildi: $id  [$sev · $tur${baglam:+ · $baglam}]  (döngü $dongu · $kim)"
}
_seq_next_id(){  # son not-id + 1 → s<seq4>  (çağıran lock tutar)
  local n=0 last=""
  [ -f "$STORE" ] && last="$(jq -r 'select(.tip=="not") | .id' "$STORE" 2>/dev/null | sed -E 's/^s0*//' | grep -E '^[0-9]+$' | sort -n | tail -1)"
  [ -n "$last" ] && n="$last"
  printf 's%04d' "$((n+1))"
}

# ── disp-fold: her not-id için son-disp durumu (yoksa acik) → JSON map ────────────────────
_fold_json(){  # stdout: filtrelenmiş+katlanmış not-event dizisi (JSON)
  local f_sev="$1" f_tur="$2" f_durum="$3" f_kim="$4" f_dongu="$5"
  [ -f "$STORE" ] || { printf '[]'; return; }
  jq -s \
    --arg sev "$f_sev" --arg tur "$f_tur" --arg durum "$f_durum" --arg kim "$f_kim" --arg dongu "$f_dongu" '
    (map(select(.tip=="disp")) | group_by(.not_id)
      | map({key:.[0].not_id, value:(sort_by(.ts)|last.durum)}) | from_entries) as $d
    | map(select(.tip=="not") | . + {durum: ($d[.id] // "acik")})
    | map(select($sev=="" or .sev==$sev))
    | map(select($tur=="" or .tur==$tur))
    | map(select($durum=="" or .durum==$durum))
    | map(select($kim=="" or .kim==$kim))
    | map(select($dongu=="" or (.dongu|tostring)==$dongu))
    | sort_by(.ts)
  ' "$STORE"
}

# ── render (deterministik; emoji yalnız-burada; değer-basmaz) ─────────────────────────────
_emoji_sev(){ case "$1" in kritik) printf '🔴';; onemli) printf '🟡';; *) printf '🟢';; esac; }
_durum_txt(){ case "$1" in okundu) printf 'okundu';; sonraki-donguye) printf '→sonraki';; kapatildi) printf 'kapatıldı';; *) printf 'açık';; esac; }
_rel(){  # <ts> → kısa göreli-zaman (Ndk/Ns/Ng)
  local then now d; then="$(date -d "$1" +%s 2>/dev/null || echo 0)"; now="$(date +%s)"
  [ "$then" = 0 ] && { printf '?'; return; }
  d=$((now-then)); [ "$d" -lt 0 ] && d=0
  if   [ "$d" -lt 3600 ];  then printf '%ddk' "$((d/60))"
  elif [ "$d" -lt 86400 ]; then printf '%ds'  "$((d/3600))"
  else printf '%dg' "$((d/86400))"; fi
}
_render(){  # stdin: not-event JSON dizisi → satır satır render
  local rows; rows="$(jq -c '.[]' 2>/dev/null)"
  [ -n "$rows" ] || { echo "  (kayıt yok)"; return; }
  local o id sev tur kim ts metin baglam durum turlbl
  while IFS= read -r o; do
    id="$(printf '%s' "$o"     | jq -r '.id')"
    sev="$(printf '%s' "$o"    | jq -r '.sev')"
    tur="$(printf '%s' "$o"    | jq -r '.tur')"
    kim="$(printf '%s' "$o"    | jq -r '.kim')"
    ts="$(printf '%s' "$o"     | jq -r '.ts')"
    metin="$(printf '%s' "$o"  | jq -r '.metin')"
    baglam="$(printf '%s' "$o" | jq -r '.baglam // ""')"
    durum="$(printf '%s' "$o"  | jq -r '.durum')"
    turlbl="$tur"; [ "$tur" = "firsat" ] && turlbl="⭐firsat"
    printf '[%s %s · %s · %s · %s] %s%s ⟨%s⟩\n' \
      "$(_emoji_sev "$sev")" "$id" "$turlbl" "$kim" "$(_rel "$ts")" \
      "$metin" "${baglam:+ → $baglam}" "$(_durum_txt "$durum")"
  done <<< "$rows"
}

# ═══ OKU ═════════════════════════════════════════════════════════════════════════════════
cmd_oku(){
  local f_sev="" f_tur="" f_durum="" f_kim="" f_dongu=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sev=*)   f_sev="${1#--sev=}" ;;
      --tur=*)   f_tur="${1#--tur=}" ;;
      --durum=*) f_durum="${1#--durum=}" ;;
      --kim=*)   f_kim="${1#--kim=}" ;;
      --dongu=*) f_dongu="${1#--dongu=}" ;;
      *) die "bilinmeyen oku-bayrağı: $1" ;;
    esac; shift
  done
  _fold_json "$f_sev" "$f_tur" "$f_durum" "$f_kim" "$f_dongu" | _render
}

# ═══ İŞARETLE (disp-event) ═══════════════════════════════════════════════════════════════
cmd_isaretle(){
  local id="${1:-}" durum="${2:-}"
  [ -n "$id" ] && [ -n "$durum" ] || die "kullanım: seyir-defteri isaretle <id> <$VALID_DURUM>"
  _in "$durum" "$VALID_DURUM" || die "geçersiz durum '$durum' (geçerli: $VALID_DURUM)"
  [ -f "$STORE" ] && jq -e --arg id "$id" 'select(.tip=="not" and .id==$id)' "$STORE" >/dev/null 2>&1 \
    || die "not bulunamadı: $id (önce 'seyir-defteri oku')"
  local line; line="$(jq -nc --arg id "$id" --arg durum "$durum" --arg ts "$(_now)" --arg kim "$(_kim)" \
    '{v:1,tip:"disp",not_id:$id,durum:$durum,ts:$ts,kim:$kim}')"
  _locked_append "$line"
  grn "✓ $id → ⟨$(_durum_txt "$durum")⟩"
}

# ═══ DURUM (özet-sayaç) ══════════════════════════════════════════════════════════════════
cmd_durum(){
  if [ ! -f "$STORE" ]; then echo "seyir-defteri: (boş) · döngü $(_current_dongu)"; return; fi
  local acik krit
  acik="$(_fold_json "" "" "acik" "" "" | jq 'length')"
  krit="$(_fold_json "kritik" "" "acik" "" "" | jq 'length')"
  local toplam; toplam="$(jq -s 'map(select(.tip=="not"))|length' "$STORE" 2>/dev/null || echo 0)"
  printf 'seyir-defteri: %s not · %s açık · %s KRİTİK-açık · güncel-döngü %s\n' \
    "$toplam" "$acik" "$krit" "$(_current_dongu)"
}

# ═══ REFLEKSİYON (döngü-ritüeli · opsiyonel-katman) ══════════════════════════════════════
cmd_refleksiyon(){
  local n="" ne="" siradaki="" dongu=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --ne=*)       ne="${1#--ne=}" ;;
      --siradaki=*) siradaki="${1#--siradaki=}" ;;
      --dongu=*)    dongu="${1#--dongu=}" ;;
      --*) die "bilinmeyen refleksiyon-bayrağı: $1" ;;
      *) [ -z "$n" ] && n="$1" || die "fazla argüman: $1" ;;
    esac; shift
  done

  # YAZ-MODU: --ne verildiyse döngü-özet event'i yaz + sayaç ilerlet.
  if [ -n "$ne" ]; then
    [ -n "$siradaki" ] || die "özet için --siradaki= de gerekli"
    [ -z "$dongu" ] && dongu="${n:-$(_current_dongu)}"
    case "$dongu" in ''|*[!0-9]*) die "dongu sayı olmalı: '$dongu'";; esac
    local line; line="$(jq -nc --argjson dongu "$dongu" --arg ts "$(_now)" --arg kim "$(_kim)" \
      --arg ne "$ne" --arg sira "$siradaki" \
      '{v:1,tip:"ozet",dongu:$dongu,ts:$ts,kim:$kim,ne_yapildi:$ne,siradaki:$sira}')"
    _locked_append "$line"
    grn "✓ döngü $dongu özeti yazıldı → sonraki notlar döngü $((dongu+1))'e düşer."
    echo
    ylw "🧠 HAFIZA-KÖPRÜSÜ (öneri — skill YAZMAZ, sen kendi memory/'ne ekleyebilirsin):"
    echo "   Döngü $dongu · $(_kim): ne-yapıldı=$ne · sıradaki=$siradaki"
    return 0
  fi

  # GÖSTER-MODU: ritüel rehberi (oku + 4-soru + işaretleme + özet-iste).
  local hedef="${n:-$(_current_dongu)}"
  echo "════ DÖNGÜ-REFLEKSİYONU (döngü ${hedef}) ════"
  echo "1) Açık + bu-döngü keşifleri (kritik-önce):"
  _fold_json "" "" "acik" "" "" \
    | jq -c 'sort_by(if .sev=="kritik" then 0 elif .sev=="onemli" then 1 else 2 end)' | _render
  echo
  echo "2) 4-SORU (plan-refleksiyonu · medigate-kanonu):"
  echo "   • ne-yaptık?      • önümüzde-ne-var?"
  echo "   • doğru-yolda-mıyız?   • planı-nasıl-güçlendiririz?"
  echo
  echo "3) Her açık-not → dispozisyon bağla:"
  echo "     seyir-defteri isaretle <id> <okundu|sonraki-donguye|kapatildi>"
  echo
  echo "4) Döngüyü kapat (özet + sayaç ilerler + hafıza-köprü önerisi):"
  echo "     seyir-defteri refleksiyon ${hedef} --ne=\"<ne yapıldı>\" --siradaki=\"<sıradaki>\""
}

# ═══ MİGRATE ([KEŞİF]-md → jsonl · idempotent) ═══════════════════════════════════════════
_mig_field(){  # <satır> <etiket> → 'etiket: değer' ('|'-ayrılı segmentten), yoksa boş
  printf '%s' "$1" | tr '|' '\n' | sed -n -E "s/^[[:space:]]*$2:[[:space:]]*//p" | head -1 | sed -E 's/[[:space:]]+$//'
}
cmd_migrate(){
  local md="${1:-}"
  [ -n "$md" ] || die "kullanım: seyir-defteri migrate <eski-md>"
  [ -f "$md" ] || die "dosya yok: $md"
  local yeni=0 atlanan=0 kim_def; kim_def="$(_kim)"
  # mevcut migrate-hash'leri (idempotent dedupe)
  local seen; seen="$( [ -f "$STORE" ] && jq -r 'select(.mig_hash) | .mig_hash' "$STORE" 2>/dev/null || true)"
  while IFS= read -r satir; do
    case "$satir" in *'[KEŞİF]'*|*'[KESIF]'*) : ;; *) continue ;; esac
    local ne tur nerede oneri kim dongu metin hash
    ne="$(printf '%s' "$satir" | sed -E 's/.*\[KE[Şş]?[İIi]?F\][[:space:]]*//; s/[[:space:]]*\|.*//')"
    tur="$(_mig_field "$satir" 'tür')";     [ -z "$tur" ] && tur="$(_mig_field "$satir" 'tur')"
    nerede="$(_mig_field "$satir" 'nerede')"
    oneri="$(_mig_field "$satir" 'öneri')"; [ -z "$oneri" ] && oneri="$(_mig_field "$satir" 'oneri')"
    dongu="$(_mig_field "$satir" 'döngü')"; [ -z "$dongu" ] && dongu="$(_mig_field "$satir" 'dongu')"
    kim="$(_mig_field "$satir" 'kim')";     [ -z "$kim" ] && kim="$kim_def"
    _in "$tur" "$VALID_TUR" || tur="gozlem"
    case "$dongu" in ''|*[!0-9]*) dongu=0;; esac
    metin="$ne"; [ -n "$oneri" ] && metin="$ne — öneri: $oneri"
    hash="$(printf '%s|%s|%s' "$ne" "$nerede" "$dongu" | (sha256sum 2>/dev/null || shasum -a256) | cut -c1-16)"
    if printf '%s\n' "$seen" | grep -qxF "$hash"; then atlanan=$((atlanan+1)); continue; fi
    local ts line; ts="$(_now)"
    line="$(jq -nc --arg ts "$ts" --arg kim "$kim" --arg tur "$tur" --arg metin "$metin" \
      --arg baglam "$nerede" --argjson dongu "$dongu" --arg hash "$hash" '
      {v:1,tip:"not",id:"_mig",ts:$ts,kim:$kim,sev:"bilgi",tur:$tur,metin:$metin,dongu:$dongu,mig_hash:$hash}
      + (if $baglam=="" then {} else {baglam:$baglam} end)')"
    # gerçek-id flock-içinde ata (id="_mig" placeholder'ı değiştir)
    if command -v flock >/dev/null 2>&1; then exec 9>>"$STORE"; flock 9; fi
    local id; id="$(_seq_next_id)"
    printf '%s\n' "$(printf '%s' "$line" | jq -c --arg id "$id" '.id=$id')" >> "$STORE"
    if command -v flock >/dev/null 2>&1; then flock -u 9; exec 9>&-; fi
    seen="$(printf '%s\n%s' "$seen" "$hash")"
    yeni=$((yeni+1))
  done < "$md"

  # eski-md arşiv-başlığı (bir kez; silme-YOK)
  if ! head -1 "$md" | grep -q 'MİGRE-EDİLDİ'; then
    local tmp; tmp="$(mktemp)"
    { printf '> → MİGRE-EDİLDİ (seyir-defteri.jsonl · %s) — arşiv, silinmedi.\n\n' "$(_now)"; cat "$md"; } > "$tmp"
    mv "$tmp" "$md"
  fi
  grn "✓ migrate: $yeni yeni · $atlanan atlanan (idempotent-dedupe) → $STORE"
}

# ═══ ana yönlendirme ═════════════════════════════════════════════════════════════════════
cmd="${1:-help}"
case "$cmd" in
  oku)         shift; cmd_oku "$@" ;;
  isaretle)    shift; cmd_isaretle "$@" ;;
  durum)       cmd_durum ;;
  refleksiyon) shift; cmd_refleksiyon "$@" ;;
  migrate)     shift; cmd_migrate "$@" ;;
  help|-h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           cmd_yaz "$@" ;;   # ilk-arg komut değilse → not-metni (yaz)
esac
