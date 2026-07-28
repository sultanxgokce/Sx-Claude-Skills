#!/usr/bin/env bash
# kasif-brief.sh — KAŞİF'in TUR-ÖNCESİ brifingi (L24 F7, okuma ucu).
#
# NE: Taramaya başlamadan önce KAŞİF'in kendi defterini okuyup "dünden bugüne ne biliyorum"
#   özetini basar. Oturum uzmanlaşmaz — uzmanlaşma diskte birikir; bu script o birikimi
#   tur başında geri yükler.
#
# ⛔ ÇIKTI TAVANI 40 SATIR — kayıt sayısından BAĞIMSIZ. Defterde 30 kayıt da olsa 3000 de olsa
#   çıktı aynı boyda kalır. Gerekçe: brifing her turun başında context'e giriyor; büyüdükçe
#   asıl işi (tarama) sıkıştırır. Ham JSONL **asla** basılmaz — yalnız damıtılmış satırlar.
#
# SESSİZ-BAŞLANGIÇ: defter yoksa hiçbir şey basmaz ve rc=0 döner. Yeni kurulan oda "boş brifing"
#   gürültüsü görmez; hafıza biriktikçe brifing kendiliğinden dolar.
#
# SALT-OKUR: hiçbir dosyaya yazmaz, hiçbir şeyi değiştirmez.
#
# Kullanım: kasif-brief.sh [--gun N]     (N = geriye kaç gün bakılacak, default 7)
# Çıkış: 0 (her hâlde — brifing bir kapı değil, bir kolaylıktır)
set -uo pipefail

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || exit 0          # kitaplık yoksa sessizce çık (brifing zorunlu değil)
# shellcheck source=/dev/null
source "$HAT_LIB" 2>/dev/null || exit 0

GUN=7
while [ $# -gt 0 ]; do
  case "$1" in
    --gun) GUN="${2:-7}"; shift 2 ;;
    *) echo "kullanım: kasif-brief.sh [--gun N]" >&2; exit 0 ;;
  esac
done

command -v jq >/dev/null 2>&1 || exit 0

_dir="${KASIF_HAFIZA_DIR:-$(hat_yolu kasif-dir 2>/dev/null || true)}"
[ -n "$_dir" ] || exit 0
SEYIR="${KASIF_SEYIR:-$_dir/seyir.jsonl}"
KAYNAKLAR="${KASIF_KAYNAKLAR:-$_dir/kaynaklar.jsonl}"
TEKRAR="${KASIF_TEKRAR:-$_dir/tekrar.jsonl}"
HAVUZ="${KASIF_HAVUZ:-$(hat_yolu bulgu-havuzu 2>/dev/null || true)}"

# Hiç defter yoksa sessizce çık — "henüz hafıza yok" bile basma (gürültü).
YONTEM="${KASIF_YONTEM_DEFTERI:-$_dir/yontem.jsonl}"

[ -s "$SEYIR" ] || [ -s "$KAYNAKLAR" ] || [ -s "$TEKRAR" ] || [ -s "$YONTEM" ] || exit 0

ESIK="$(date -u -d "-${GUN} days" +%Y-%m-%d 2>/dev/null || echo "0000-00-00")"

echo "🧭 KAŞİF brifingi — son $GUN gün"

# ── 0) KURALLARIM — EN BAŞTA (ADR-025 K5: kayıt pasif, kural aktif) ───────────────────────
# Damıtılmış deneyim brifingin İLK satırlarıdır: aşağıdaki istatistikleri okumadan önce
# davranış kısıtını görürsün. Tavan 6+4 satır — defter büyüse de brifing büyümez.
if [ -s "$YONTEM" ]; then
  _k="$(jq -rs '[.[]|select(.durum=="kural")] | length' "$YONTEM" 2>/dev/null || echo 0)"
  _a="$(jq -rs '[.[]|select(.durum=="aday")]  | length' "$YONTEM" 2>/dev/null || echo 0)"
  if [ "${_k:-0}" != "0" ]; then
    echo ""
    echo "📏 KURALLARIM — bunlara UY (Sultan onayladı, tartışma yok):"
    jq -rs '[.[]|select(.durum=="kural")] | .[0:6][] | "   • \(.kural)"' "$YONTEM" 2>/dev/null
    [ "$_k" -gt 6 ] && echo "   … ve $(( _k - 6 )) kural daha (tümü: kasif-ogren.sh liste)"
  fi
  if [ "${_a:-0}" != "0" ]; then
    echo ""
    echo "🕯️ ADAY kurallar — DİKKATE al, ama seni bağlamaz (henüz onaylanmadı):"
    jq -rs '[.[]|select(.durum=="aday")] | .[0:4][] | "   • \(.kural)"' "$YONTEM" 2>/dev/null
    [ "$_a" -gt 4 ] && echo "   … ve $(( _a - 4 )) aday daha"
  fi
fi

# ── 1) Nabız: en son ne zaman tarandı, kaç tur, kaçı boş ──────────────────────────────────
if [ -s "$SEYIR" ]; then
  jq -rs --arg esik "$ESIK" '
    [ .[] | select((.tarih // "") >= $esik) ] as $son |
    ( [ .[] | .tarih // empty ] | max // "—" ) as $engec |
    ( $son | length ) as $tur |
    ( [ $son[] | select((.eklenen // 0) == 0) ] | length ) as $bos |
    ( [ $son[] | .eklenen // 0 ] | add // 0 ) as $topl |
    "   son tarama: \($engec)  ·  \($tur) tur  ·  \($bos) tur boş döndü  ·  toplam \($topl) yeni malzeme"
  ' "$SEYIR" 2>/dev/null
else
  echo "   (tur günlüğü henüz yok — bu ilk turlardan biri)"
fi

# ── 2) Verimli kaynaklar: buraya gitmeye devam ────────────────────────────────────────────
if [ -s "$KAYNAKLAR" ]; then
  n="$(jq -rs '[ .[] | select((.verim // 0) > 0) ] | length' "$KAYNAKLAR" 2>/dev/null || echo 0)"
  if [ "${n:-0}" != "0" ]; then
    echo ""
    echo "✅ verimli kaynaklar (en iyi 5):"
    jq -rs '[ .[] | select((.verim // 0) > 0) ] | sort_by(-(.verim // 0)) | .[0:5][] |
      "   \(.host // "?")  —  \(.verim) bulgu / \(.ziyaret // 1) ziyaret  ·  son: \(.son // "?")"' \
      "$KAYNAKLAR" 2>/dev/null
  fi

  # ── 3) Boşa giden kaynaklar: BURAYA BİR DAHA GİTME ──
  # Ölçüt ziyaret≥2 ∧ verim=0 — tek boş ziyaret "kısır" demek değildir (o gün sakin olabilir).
  b="$(jq -rs '[ .[] | select((.ziyaret // 0) >= 2 and (.verim // 0) == 0) ] | length' "$KAYNAKLAR" 2>/dev/null || echo 0)"
  if [ "${b:-0}" != "0" ]; then
    echo ""
    echo "⛔ tekrar tekrar boş çıkan kaynaklar (bu tur atla):"
    jq -rs '[ .[] | select((.ziyaret // 0) >= 2 and (.verim // 0) == 0) ] |
      sort_by(-(.ziyaret // 0)) | .[0:5][] |
      "   \(.host // "?")  —  \(.ziyaret) kez bakıldı, hiç bulgu çıkmadı"' "$KAYNAKLAR" 2>/dev/null
  fi
fi

# ── 4) Tekrar sinyalleri: aynı fikri kaç ayrı yerde duyduk ────────────────────────────────
# Bu, dedup'ta düşen adayların BİRİKMİŞ hâli. Yüksek tekrar = güçlenen sinyal (gürültü değil).
if [ -s "$TEKRAR" ]; then
  t="$(jq -rs '[ .[] | select((.kez // 0) >= 2) ] | length' "$TEKRAR" 2>/dev/null || echo 0)"
  if [ "${t:-0}" != "0" ]; then
    echo ""
    echo "🔁 birden çok yerden duyulan fikirler (güçlenen sinyal):"
    jq -rs '[ .[] | select((.kez // 0) >= 2) ] | sort_by(-(.kez // 0)) | .[0:5][] |
      "   \(.kez)× · \((.hostlar // []) | length) ayrı kaynak — \(.baslik // "?" | .[0:64])"' \
      "$TEKRAR" 2>/dev/null
  fi
fi

# ── 5) Dönüşüm: getirdiklerimin kaçı işe yaradı ───────────────────────────────────────────
if [ -n "${HAVUZ:-}" ] && [ -s "$HAVUZ" ]; then
  jq -rs '
    [ .[] | select((.kaynak // "") == "kasif") ] as $k |
    ( $k | length ) as $t |
    ( [ $k[] | select((.durum // "ham") != "ham") ] | length ) as $isle |
    if $t == 0 then empty
    else "\n📊 havuzdaki KAŞİF malzemesi: \($t) kayıt  ·  \($isle) tanesi işlendi/aday oldu"
    end' "$HAVUZ" 2>/dev/null
fi

echo ""
echo "   (tam defter: _agents/kasif/ — bu özet 40 satırı geçmez, ham kayıt buraya basılmaz)"
exit 0
