#!/usr/bin/env bash
# mucit-t1.sh — MUCİT $0-mekanik T1 prefilter (DİVAN k0054, doktrin §9 "Fikir-hattı")
#
# MUCİT'in ELİ değil ELEKİ: bulgu-havuzunu ($JSONL) LLM-takdiri OLMADAN mekanik süzer.
# Amaç: T2 (kanıt-kapısı + repo-grep + Sultan-dili aday-yazımı, /mucit-suz skill'inde) yalnız
# HAK EDEN az sayıda bulguyu görsün; acımasız-ele MEKANİK başlar, LLM keyfine bırakılmaz.
#
# NE YAPAR (hepsi deterministik, $0, offline-test-edilebilir):
#   1. UYGUNLUK:  durum ∈ {ham, kart-red} olanları alır (bitti/cozuluyor/aday-onerildi/kart/elendi HARİÇ).
#   2. KANIT-KAPISI (fail-closed): kanit alanı boş bulgu ELENİR — kanıtsız fikir aday olamaz (Değişmez-11 ruhu).
#   3. MİHENK-DENY: ürün/pazar/gelir sınıfı bulgu "mihenk-alani" etiketlenir + aday-havuzundan ÇIKARILIR
#      (taşıma yalnız Sultan; izole-container'a otomatik köprü YOK — doktrin §9).
#   4. KART-DEDUP:  başlık-örtüşmesi mevcut defter-kartlarıyla > eşik → "zaten-var" ELENİR (T1-tarafı; T2 repo-grep tamamlar).
#   5. DÖNEM-TAVAN: bu dönemde üretilmiş GERÇEK aday (defter verdikt=aday-arzi) ≥ tavan → RC=3 (MEKANİK KİLİT).
#      Aksi halde kalan-kota (tavan − üretilen) hesaplanır; T2 bundan FAZLA aday üretemez.
#      Dönem PROFİL'e bağlıdır (L24): divan = ISO-hafta/3 (DİVAN-ANAYASA §8, VARSAYILAN — değişmedi) ·
#      layiha = gün/10 (layiha-fabrikası bandı). Profiller AYRI DEFTER kullanır → layiha üretimi
#      DİVAN'ın haftalık ≤3 kotasını ASLA tüketmez, §8 tavanı zayıflamaz.
#   6. ÖN-SKOR: mekanik tiebreak (kanıt-uzunluğu + kaynak-ağırlığı). ASIL skor (etki×kolaylık×hedef-uyum) T2-takdiri.
#
# ÇIKTI: stdout = JSON {tavan, uretilen, kalan, uygun_sayi, adaylar:[...]} — T2 bunu okur.
#        stderr = eleme-özeti (kaç/neden). DEĞER-GÜVENLİK: sır/token basmaz; salt-okur + hesap.
# RC: 0=başarı (adaylar emit; boş-havuz da 0) · 3=HAFTA-TAVAN dolu (kilit) · 2=kullanım/girdi hatası.
set -euo pipefail

# ── ROL-KAPISI (ADR-025 K4: bulan ≠ eleyen) ─────────────────────────────────────────────────
# İkizi `kasif-tara/scripts/kasif-havuz-ekle.sh`'te. Alt-ajan rolünü `LAYIHA_ROL` ile taşır;
# KAŞİF rolüyle gönderilmiş bir alt-ajan ELEME motorunu koşamaz. Boş = kısıt yok (elle koşu,
# fabrika bandı ve eski çağrılar aynen çalışır).
if [ -n "${LAYIHA_ROL:-}" ] && [ "${LAYIHA_ROL}" != "mucit" ]; then
  echo "HATA: rol-kapısı — bu motor MUCİT'in eleği, alt-ajanın rolü ise '${LAYIHA_ROL}'." >&2
  echo "      ADR-025 K4 (bulan ≠ eleyen): eleme için AYRI bir alt-ajan gönder (LAYIHA_ROL=mucit)." >&2
  exit 2
fi

# ── yol-çözümü (L24 F3: paket-içi) ──────────────────────────────────────────────────────────
# `hucre-baglam.lib.sh` PAKETE GİRMEZ (kökü SCRIPT dizininden hesaplar → ortak-mount'u kök sanar,
# İ1'i deler ve sync'in rmSync'i veriyi siler). Yerine kökü CWD'den çözen `hat-yolu.lib.sh` (L24 F1).
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
# shellcheck source=/dev/null
source "$HAT_LIB"

# ── PROFİL ön-taraması (L24) — bayraklardan ÖNCE, ki --tavan/--defter/--periyot profili EZEBİLSİN ──
# NOT: burada YOL hesaplanmaz, yalnız artefakt-ADI seçilir; gerçek çözüm bayrak-ayrıştırmasından SONRA
# (git-siz dizinde `--defter <yol>` verildiğinde gereksiz yere RC=2 vermemek için — fail-closed sadece
# gerçekten default'a düşüldüğünde devreye girer).
PROFIL="${MUCIT_PROFIL:-divan}"
_prev=""
for _a in "$@"; do [[ "$_prev" == "--profil" ]] && PROFIL="$_a"; _prev="$_a"; done
case "$PROFIL" in
  divan)   _TAVAN_D=3;  _PERIYOT_D=hafta; _DEFTER_ART=mucit-defteri ;;
  layiha)  _TAVAN_D=10; _PERIYOT_D=gun;   _DEFTER_ART=mucit-defteri-layiha ;;
  *) echo "HATA: bilinmeyen profil: $PROFIL (divan|layiha)" >&2; exit 2 ;;
esac

# ── L24 FAZ-D2 kill-switch — YALNIZ layiha-profilinde ──
# KAPSAM-DİSİPLİNİ: bu script DİVAN fikir-hattının da motorudur. Bayrak "layiha-fabrikasını kapat"
# demektir; DİVAN'ı (kendi anayasası olan ayrı program) susturmak YETKİSİ DIŞINDADIR. Guard bu yüzden
# profil=layiha'ya bağlıdır — CRUD'un guard'dan muaf tutulmasıyla aynı dar-kapsam ilkesi.
if [ "$PROFIL" = "layiha" ]; then
  GUARD_LIB="${LAYIHA_GUARD_LIB:-$PAKET/../layiha-fabrikasi/scripts/layiha-fabrika-guard.lib.sh}"
  [ -r "$GUARD_LIB" ] || { echo "HATA: kill-switch guard yok: $GUARD_LIB — 'layiha-fabrikasi' paketi kurulu mu?" >&2; exit 2; }
  # shellcheck source=/dev/null
  source "$GUARD_LIB"
  layiha_fabrika_guard "mucit-t1.sh --profil layiha" || exit 0
fi

# Boş bırakılanlar kanon/​default'tan SONRA doldurulur (bkz "kanon yükle").
HAVUZ="${MUCIT_HAVUZ:-}"
DEFTER="${MUCIT_DEFTER:-}"
TAVAN="${MUCIT_HAFTA_TAVAN:-}"
PERIYOT="${MUCIT_PERIYOT:-}"
KARTLAR_SRC="${MUCIT_KARTLAR:-API}"   # "API" → prod-defter GET; ya da yerel JSON-array dosyası (test-fixture)
BASE="${DEFTER_API_BASE:-}"
DEDUP_ESIK="${MUCIT_DEDUP_ESIK:-0.6}" # başlık-token Jaccard örtüşme eşiği

# ürün/pazar/gelir/BÜYÜME sınıfı — MİHENK-alanı (Sultan-yolu). Geniş-tutucu: yanlış-etiket iş yok etmez, yalnız Sultan'a yönlendirir.
# (B3: büyüme-metrikleri de eklendi — 'pazar/gelir' sözcüğü GEÇMEYEN büyüme-fikri sızmasın: edinim/churn/LTV/huni/funnel...)
MIHENK_DESEN='pazar|müşteri|musteri|gelir|satış|satis|fiyatland|pricing|revenue|monetiz|go[- ]to[- ]market|iş[- ]model|is[- ]model|business.?model|startup|girişim|girisim|pazarlama|lansman|abonelik.?ücret|abonelik.?ucret|edinim|büyüme|buyume|churn|ltv|aktivasyon|huni|funnel|retention|elde.?tutma|kullanıcı.?kazan|kullanici.?kazan|abone.?kazan'

command -v jq >/dev/null 2>&1 || { echo "HATA: jq yok" >&2; exit 2; }

usage() { echo "Kullanım: mucit-t1.sh suz [--profil divan|layiha] [--havuz <path>] [--kartlar API|<file>] [--defter <path>] [--tavan N] [--periyot hafta|gun]" >&2; exit 2; }

# ── argümanlar ──
CMD="${1:-suz}"; shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --havuz)   HAVUZ="${2:?}"; shift ;;
    --kartlar) KARTLAR_SRC="${2:?}"; shift ;;
    --defter)  DEFTER="${2:?}"; shift ;;
    --tavan)   TAVAN="${2:?}"; shift ;;
    --periyot) PERIYOT="${2:?}"; shift ;;
    --profil)  shift ;;   # ön-taramada işlendi
    *) echo "HATA: bilinmeyen bayrak: $1" >&2; usage ;;
  esac; shift
done
[[ "$CMD" == "suz" ]] || usage

# ── KANON + kalan default'lar (L24 F3) ───────────────────────────────────────────────────────
# Nexus'a özgü ne varsa (prod-defter adresi · env-dosyası · profil tavanları · MİHENK-deseni) artık
# KOD'da değil repo-yerel `_agents/mucit/kanon.json`'da yaşar. Dosya YOKSA paket nötr default'larıyla
# çalışır ve `base` BOŞ kalır → **hiçbir ağ çağrısı yapılmaz**: yabancı bir container'ın MUCİT'i
# Nexus'un prod-host'unu yoklamaz (İ1 + en-az-yetki). Kanon yalnız AYAR'dır: okunamazsa iş durmaz;
# VERİ yolları ise fail-closed kalır (aşağıdaki `|| exit 2`).
KANON=""
_mdir="$(hat_yolu mucit-dir 2>/dev/null)" || _mdir=""
if [ -n "$_mdir" ] && [ -r "$_mdir/kanon.json" ]; then
  if jq -e . "$_mdir/kanon.json" >/dev/null 2>&1; then KANON="$_mdir/kanon.json"
  else echo "UYARI: kanon.json bozuk-JSON, yok sayıldı: $_mdir/kanon.json" >&2; fi
fi
_kanon() { [ -n "$KANON" ] || return 0; jq -r --arg p "$1" 'getpath($p|split(".")) // empty' "$KANON" 2>/dev/null || true; }

[ -n "$TAVAN" ]   || TAVAN="$(_kanon "profiller.$PROFIL.tavan")"
[ -n "$TAVAN" ]   || TAVAN="$_TAVAN_D"
[ -n "$PERIYOT" ] || PERIYOT="$(_kanon "profiller.$PROFIL.periyot")"
[ -n "$PERIYOT" ] || PERIYOT="$_PERIYOT_D"
[ -n "$BASE" ]    || BASE="$(_kanon kart_kaynagi.base)"
_MD="$(_kanon mihenk_deseni)"; if [ -n "$_MD" ]; then MIHENK_DESEN="$_MD"; fi
_EF="$(_kanon kart_kaynagi.env_dosyasi)"
[ -n "$HAVUZ" ]  || { HAVUZ="$(hat_yolu bulgu-havuzu)" || exit 2; }
[ -n "$DEFTER" ] || { DEFTER="$(hat_yolu "$_DEFTER_ART")" || exit 2; }

[[ -f "$HAVUZ" ]] || { echo "HATA: havuz yok: $HAVUZ" >&2; exit 2; }

# ── DÖNEM-TAVAN (mekanik kilit) ──
case "$PERIYOT" in
  hafta) DFMT="+%G-W%V"; DONEM_AD="bu hafta" ;;
  gun)   DFMT="+%F";     DONEM_AD="bugün" ;;
  *) echo "HATA: bilinmeyen periyot: $PERIYOT (hafta|gun)" >&2; exit 2 ;;
esac
BU_HAFTA="$(date -u "$DFMT")"
URETILEN=0
if [[ -f "$DEFTER" ]]; then
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    hw="$(date -u -d "$t" "$DFMT" 2>/dev/null || true)"
    [[ "$hw" == "$BU_HAFTA" ]] && URETILEN=$((URETILEN+1))
  done < <(jq -rc 'select(.verdikt=="aday-arzi") | .tarih // empty' "$DEFTER" 2>/dev/null || true)
fi
KALAN=$(( TAVAN - URETILEN ))
if (( KALAN <= 0 )); then
  echo "🔒 DÖNEM-TAVAN dolu [profil=$PROFIL]: $DONEM_AD ($BU_HAFTA) $URETILEN/$TAVAN gerçek-aday üretilmiş — yeni aday MEKANİK reddedilir." >&2
  echo "   (Kalibrasyon-önizleme tavana sayılmaz; yalnız verdikt=aday-arzi sayılır.)" >&2
  exit 3
fi

# ── mevcut kart-başlıkları (dedup kaynağı) ──
KART_BASLIKLAR="[]"
if [[ "$KARTLAR_SRC" == "API" ]] && [[ -z "$BASE" ]]; then
  # Kanon'da kart-kaynağı tanımlı değil (ör. Nexus-dışı bir oda) → ağ çağrısı YOK, T1-dedup atlanır.
  echo "ℹ️ dedup: kart-kaynağı tanımsız (kanon.json → kart_kaynagi.base boş) — T1-dedup atlandı; T2 repo-grep TAMAMLAMALI." >&2
elif [[ "$KARTLAR_SRC" == "API" ]]; then
  ENV_FILE="${DEFTER_ENV_FILE:-}"
  if [ -z "$ENV_FILE" ] && [ -n "$_EF" ]; then
    case "$_EF" in /*) ENV_FILE="$_EF" ;; *) ENV_FILE="$(hat_root)/$_EF" ;; esac
  fi
  TOK=""
  [[ -f "$ENV_FILE" ]] && TOK="$(grep '^DEFTER_SERDAR_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\' || true)"
  if [[ -n "$TOK" ]]; then
    resp="$(curl -sS --max-time 20 --config <(printf 'header = "Authorization: Bearer %s"\n' "$TOK") "$BASE/api/defter" 2>/dev/null || true)"
    KART_BASLIKLAR="$(printf '%s' "$resp" | jq -c '[.kayitlar[]?.goster // empty]' 2>/dev/null || echo '[]')"
  fi
  if [[ "$KART_BASLIKLAR" == "[]" || -z "$KART_BASLIKLAR" ]]; then
    echo "⚠️ dedup: prod-defter kart-başlıkları çekilemedi (offline?) — T1-dedup atlandı; T2 repo-grep TAMAMLAMALI." >&2
    KART_BASLIKLAR="[]"
  fi
elif [[ -f "$KARTLAR_SRC" ]]; then
  KART_BASLIKLAR="$(jq -c '.' "$KARTLAR_SRC" 2>/dev/null || echo '[]')"
else
  echo "HATA: --kartlar dosyası yok: $KARTLAR_SRC" >&2; exit 2
fi

# ── M1: havuz-bütünlük ön-kontrolü (bozuk-JSONL SESSİZCE yutulmasın — fail-closed) ──
# Eski `<(jq '.' "$HAVUZ")` process-sub'ı inner-jq parse-error'unu yutuyordu (RC=0 + eksik-bulgu).
# Doğrudan `jq empty` ile TÜM satırları doğrula; bir satır bozuksa DUR (acımasız-ele = sessiz-eksik'in TERSİ).
if ! jq empty "$HAVUZ" 2>/dev/null; then
  echo "HATA: havuz bozuk-JSONL (parse hatası) — fail-closed durduruldu: $HAVUZ" >&2; exit 2
fi

# ── mekanik süzme (jq): uygunluk + kanıt-kapısı + MİHENK-deny + dedup + ön-skor ──
# not: metin normalize (küçült, noktalama→boşluk, token-set) jq-içinde; Jaccard-örtüşme mevcut kartlarla.
export DEDUP_ESIK MIHENK_DESEN
CIKTI="$(jq -c -n \
  --slurpfile havuz "$HAVUZ" \
  --argjson kartlar "$KART_BASLIKLAR" \
  --arg mihenk "$MIHENK_DESEN" \
  --argjson esik "$DEDUP_ESIK" '
  def trlower: gsub("İ";"i")|gsub("I";"ı")|gsub("Ş";"ş")|gsub("Ğ";"ğ")|gsub("Ç";"ç")|gsub("Ö";"ö")|gsub("Ü";"ü");
  def norm: trlower | ascii_downcase | gsub("[^a-zçğıöşü0-9 ]"; " ") | gsub("  +"; " ") | ltrimstr(" ") | rtrimstr(" ");
  def tokens: norm | split(" ") | map(select(length>2)) | unique;
  def jaccard($a;$b): ($a+$b|unique) as $u | if ($u|length)==0 then 0 else (($a|length)+($b|length)-($u|length)) / ($u|length) end;
  ($kartlar | map(tokens)) as $karttok |
  [ $havuz[] |
    . as $b |
    ($b.kanit // "" | gsub("\\s";"") | length > 0) as $kanitli |
    (["ham","kart-red"] | index($b.durum // "ham")) as $uygun_durum |
    (($b.baslik // "") + " " + ($b.detay // "")) as $metin |
    ($metin | test($mihenk; "i")) as $mihenk_hit |
    ($b.baslik // "" | tokens) as $btok |
    ([ $karttok[] | jaccard($btok; .) ] | max // 0) as $ortusme |
    {
      id: $b.id, kaynak: $b.kaynak, baslik: $b.baslik, detay: $b.detay,
      kanit: $b.kanit, tarih: $b.tarih, durum: ($b.durum // "ham"), kart: $b.kart, not: $b.not,
      _kanitli: $kanitli, _uygun_durum: ($uygun_durum != null),
      _mihenk: $mihenk_hit, _ortusme: $ortusme,
      onskor: ((($b.kanit // "" | length) / 40) + (if ($b.kaynak // "") | test("pilot|firsthand|serdar") then 3 else 1 end))
    }
  ]
' 2>&1)" || { echo "HATA: jq-süzme başarısız: $CIKTI" >&2; exit 2; }

# ── karar: her bulguyu sınıfla, elenenleri stderr'e say, geçenleri adaylara koy ──
ADAYLAR="$(jq -c '[ .[] | select(._uygun_durum and ._kanitli and (._mihenk|not) and (._ortusme < '"$DEDUP_ESIK"')) ]' <<<"$CIKTI")"
E_DURUM=$(jq '[ .[] | select(._uygun_durum|not) ] | length' <<<"$CIKTI")
E_KANIT=$(jq '[ .[] | select(._uygun_durum and (._kanitli|not)) ] | length' <<<"$CIKTI")
E_MIHENK=$(jq '[ .[] | select(._uygun_durum and ._kanitli and ._mihenk) ] | length' <<<"$CIKTI")
E_DEDUP=$(jq '[ .[] | select(._uygun_durum and ._kanitli and (._mihenk|not) and (._ortusme >= '"$DEDUP_ESIK"')) ] | length' <<<"$CIKTI")
MIHENK_LIST=$(jq -c '[ .[] | select(._uygun_durum and ._kanitli and ._mihenk) | {id, baslik} ]' <<<"$CIKTI")
UYGUN_SAYI=$(jq 'length' <<<"$ADAYLAR")

# ön-skora göre sırala + iç-alanları temizle
ADAYLAR_TEMIZ="$(jq -c 'sort_by(-.onskor) | [ .[] | del(._kanitli, ._uygun_durum, ._mihenk, ._ortusme) ]' <<<"$ADAYLAR")"

# ── eleme-özeti (stderr) ──
{
  echo "── MUCİT T1 eleme-özeti (havuz: $(basename "$HAVUZ")) ──"
  echo "   uygun-olmayan durum : $E_DURUM  (bitti/cozuluyor/aday-onerildi/kart/elendi)"
  echo "   kanıtsız (fail-closed): $E_KANIT"
  echo "   MİHENK-alanı (Sultan) : $E_MIHENK  ${MIHENK_LIST}"
  echo "   zaten-var (kart-dedup): $E_DEDUP"
  echo "   ➜ T2'ye geçen aday    : $UYGUN_SAYI   ·   [$PROFIL/$PERIYOT] kota: kalan $KALAN/$TAVAN"
} >&2

# ── stdout: T2-kontratı ──
jq -c -n \
  --argjson tavan "$TAVAN" --argjson uretilen "$URETILEN" --argjson kalan "$KALAN" \
  --argjson uygun "$UYGUN_SAYI" --argjson adaylar "$ADAYLAR_TEMIZ" \
  --argjson mihenk "$MIHENK_LIST" --arg hafta "$BU_HAFTA" \
  --arg profil "$PROFIL" --arg periyot "$PERIYOT" \
  '{hafta:$hafta, donem:$hafta, profil:$profil, periyot:$periyot, tavan:$tavan, uretilen:$uretilen, kalan:$kalan, uygun_sayi:$uygun, mihenk_alani:$mihenk, adaylar:$adaylar}'
exit 0
