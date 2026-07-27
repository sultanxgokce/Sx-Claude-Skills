#!/usr/bin/env bash
# kasif-karne.sh — "KAŞİF gerçekten uzmanlaşıyor mu?" (L24 F7).
#
# NE: Hafıza defterlerinden dört ORAN çıkarır. Sultan'ın asıl sorusu buydu: her gün biraz daha
#   iyi çalışan bir personel mi, yoksa aynı yerde sayan bir döngü mü?
#
# ⛔ ADET-BAZLI ÖLÇÜT KARNEYE GİRMEZ — bilinçli tasarım kararı. "Bu ay 50 bulgu getirdi" demek,
#   KAŞİF'i havuzu çöple doldurmaya teşvik eder (ölçtüğün şeyi üretirsin). Karne yalnız ORAN
#   ölçer: getirdiğinin ne kadarı işe yaradı, kaç turu boşa gitti, aynı yere kaç kez gitti.
#
# DÜRÜSTLÜK KAPISI: yeterli veri yoksa karne VERİLMEZ. Üç turluk gözlemle "başarılı/başarısız"
#   demek ölçüm değil temenni olur; script bunu açıkça söyler ve durur.
#
# SALT-OKUR. Kullanım: kasif-karne.sh [--gun N] (default 30) · Çıkış: 0
set -uo pipefail

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "karne verilemedi: yol kitaplığı yok" >&2; exit 0; }
# shellcheck source=/dev/null
source "$HAT_LIB" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || { echo "karne verilemedi: jq yok" >&2; exit 0; }

GUN=30
while [ $# -gt 0 ]; do
  case "$1" in
    --gun) GUN="${2:-30}"; shift 2 ;;
    *) echo "kullanım: kasif-karne.sh [--gun N]" >&2; exit 0 ;;
  esac
done

_dir="${KASIF_HAFIZA_DIR:-$(hat_yolu kasif-dir 2>/dev/null || true)}"
[ -n "$_dir" ] || { echo "karne verilemedi: proje klasörü bulunamadı" >&2; exit 0; }
SEYIR="${KASIF_SEYIR:-$_dir/seyir.jsonl}"
KAYNAKLAR="${KASIF_KAYNAKLAR:-$_dir/kaynaklar.jsonl}"
TEKRAR="${KASIF_TEKRAR:-$_dir/tekrar.jsonl}"
HAVUZ="${KASIF_HAVUZ:-$(hat_yolu bulgu-havuzu 2>/dev/null || true)}"

ESIK="$(date -u -d "-${GUN} days" +%Y-%m-%d 2>/dev/null || echo "0000-00-00")"
ASGARI_TUR="${KASIF_KARNE_ASGARI:-5}"

TUR_SAYISI=0
[ -s "$SEYIR" ] && TUR_SAYISI="$(jq -rs --arg e "$ESIK" '[ .[] | select((.tarih // "") >= $e) ] | length' "$SEYIR" 2>/dev/null || echo 0)"

echo "📋 KAŞİF karnesi — son $GUN gün"
echo ""

if [ "${TUR_SAYISI:-0}" -lt "$ASGARI_TUR" ]; then
  echo "   ⏳ Henüz karne verilemez: bu pencerede $TUR_SAYISI tur var, en az $ASGARI_TUR gerekiyor."
  echo "      Az gözlemle 'iyi/kötü' demek ölçüm değil tahmin olur. Defter doldukça karne kendiliğinden açılır."
  exit 0
fi

# ── 1) DÖNÜŞÜM: getirdiği malzemenin kaçı işe yaradı ──────────────────────────────────────
# Asıl kalite ölçüsü. Düşükse KAŞİF çok gevşek eliyor demektir (havuzu dolduruyor, MUCİT'i yoruyor).
if [ -n "${HAVUZ:-}" ] && [ -s "$HAVUZ" ]; then
  jq -rs '
    [ .[] | select((.kaynak // "") == "kasif") ] as $k |
    ($k | length) as $t |
    ([ $k[] | select((.durum // "ham") != "ham") ] | length) as $i |
    if $t == 0 then "   dönüşüm        : — (henüz KAŞİF malzemesi yok)"
    else "   dönüşüm        : %\(($i * 100 / $t) | floor)   (\($i)/\($t) malzeme işlendi ya da adaya döndü)"
    end' "$HAVUZ" 2>/dev/null
fi

# ── 2) BOŞA-TUR: kaç tur hiçbir şey getirmedi ─────────────────────────────────────────────
# Yüksekse ya kapsam dar ya kaynaklar kısır. SIFIR da şüphelidir: hiç boş dönmüyorsa eleme gevşek olabilir.
jq -rs --arg e "$ESIK" '
  [ .[] | select((.tarih // "") >= $e) ] as $s |
  ($s | length) as $t |
  ([ $s[] | select((.eklenen // 0) == 0) ] | length) as $b |
  if $t == 0 then empty
  else "   boşa geçen tur : %\(($b * 100 / $t) | floor)   (\($b)/\($t) tur eli boş döndü)"
  end' "$SEYIR" 2>/dev/null

# ── 3) KAYNAK İSABETİ: gittiği adreslerin kaçı bir şey verdi ──────────────────────────────
# Öğreniyorsa bu oran ZAMANLA YÜKSELİR: kısır kaynakları eleyip verimlilere yönelir.
if [ -s "$KAYNAKLAR" ]; then
  jq -rs '
    (length) as $t |
    ([ .[] | select((.verim // 0) > 0) ] | length) as $v |
    if $t == 0 then empty
    else "   kaynak isabeti : %\(($v * 100 / $t) | floor)   (\($v)/\($t) adres en az bir bulgu verdi)"
    end' "$KAYNAKLAR" 2>/dev/null
fi

# ── 4) TEKRAR YÜKÜ: aynı fikri kaç kez yeniden getirdi ────────────────────────────────────
# Öğreniyorsa bu oran ZAMANLA DÜŞER. Yüksek kalıyorsa KAŞİF defterini okumuyor demektir.
if [ -s "$TEKRAR" ]; then
  jq -rs --arg e "$ESIK" '
    ([ .[] | (.kez // 0) ] | add // 0) as $tekrar |
    ([ .[] | select((.kez // 0) >= 3) ] | length) as $inatci |
    "   tekrar yükü    : \($tekrar) kez aynı fikir yeniden geldi\(if $inatci > 0 then "  ·  \($inatci) fikir 3+ kez" else "" end)"
  ' "$TEKRAR" 2>/dev/null
fi

echo ""
echo "   Nasıl okunur: dönüşüm ve kaynak-isabeti ZAMANLA YÜKSELMELİ, tekrar yükü DÜŞMELİ."
echo "   Tek koşu bir şey söylemez — bu karne haftadan haftaya karşılaştırmak içindir."
echo "   Not: 'kaç bulgu getirdi' bilerek ölçülmez — ölçtüğün şeyi üretirsin, havuz çöple dolar."
exit 0
