#!/usr/bin/env bash
# mucit-karne.sh — "MUCİT iyi bir eleyici mi?" (ADR-025 K6, KAŞİF karnesinin ikizi).
#
# MUCİT'in işi acımasız elemektir. Ama iki yönde de bozulabilir:
#   · fazla GEVŞEK → her şeyi aday yapar, havuz Sultan'ın önünde yığılır (canlı kanıt: 100 taslak/0 terfi)
#   · fazla SIKI   → hiçbir şeyi geçirmez, hat sessizce durur (canlı kanıt: 8 gündür bulgu işlenmemiş)
# Karne bu iki uçtan hangisine kaydığını gösterir.
#
# ⛔ ADET ÖLÇÜLMEZ — yalnız ORAN. "Bu ay 12 aday üretti" demek MUCİT'i gevşemeye teşvik eder;
#   ölçtüğün şeyi üretirsin. (KAŞİF karnesiyle aynı ilke.)
#
# DÜRÜSTLÜK KAPISI: yeterli karar yoksa karne VERİLMEZ. SALT-OKUR.
# Kullanım: mucit-karne.sh [--gun N] (default 30)
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
    *) echo "kullanım: mucit-karne.sh [--gun N]" >&2; exit 0 ;;
  esac
done

DEFTER="${MUCIT_DEFTER:-$(hat_yolu mucit-defteri 2>/dev/null || true)}"
HAVUZ="${MUCIT_HAVUZ:-$(hat_yolu bulgu-havuzu 2>/dev/null || true)}"
[ -n "${DEFTER:-}" ] || { echo "karne verilemedi: proje klasörü bulunamadı" >&2; exit 0; }

ESIK="$(date -u -d "-${GUN} days" +%Y-%m-%d 2>/dev/null || echo "0000-00-00")"
ASGARI="${MUCIT_KARNE_ASGARI:-5}"

KARAR=0
[ -s "$DEFTER" ] && KARAR="$(jq -rs --arg e "$ESIK" \
  '[ .[] | select((.tarih // "") >= $e and (.verdikt // "") != "dogum") ] | length' "$DEFTER" 2>/dev/null || echo 0)"

echo "📋 MUCİT karnesi — son $GUN gün"
echo ""

if [ "${KARAR:-0}" -lt "$ASGARI" ]; then
  echo "   ⏳ Henüz karne verilemez: bu pencerede $KARAR karar var, en az $ASGARI gerekiyor."
  echo "      Az gözlemle 'gevşek/sıkı' demek ölçüm değil tahmin olur."
  exit 0
fi

# ── 1) GEÇİRME ORANI — elemenin sıkılığı ──────────────────────────────────────────────────
# Ne çok yüksek ne çok düşük olmalı. Sağlıklı bant deneyimle oturacak; bugün referans yok,
# o yüzden karne yorum YAPMAZ, yalnız sayıyı verir ve yönü söyler.
jq -rs --arg e "$ESIK" '
  [ .[] | select((.tarih // "") >= $e and (.verdikt // "") != "dogum") ] as $k |
  ($k | length) as $t |
  ([ $k[] | select((.verdikt // "") | test("aday")) ] | length) as $a |
  if $t == 0 then empty
  else "   geçirme oranı : %\(($a * 100 / $t) | floor)   (\($a)/\($t) karar aday oldu)"
  end' "$DEFTER" 2>/dev/null

# ── 2) GEREKÇE DİSİPLİNİ — eleme kararı kanıtlı mı ────────────────────────────────────────
# Gerekçesiz eleme, üç hafta sonra aynı analizi tekrar yapmaya mahkûm eder (brifing onu okuyamaz).
jq -rs --arg e "$ESIK" '
  [ .[] | select((.tarih // "") >= $e and (.verdikt // "") == "elendi") ] as $e2 |
  ($e2 | length) as $t |
  ([ $e2[] | select(((.not // "") | gsub("\\s";"") | length) > 0) ] | length) as $g |
  if $t == 0 then empty
  else "   gerekçe oranı : %\(($g * 100 / $t) | floor)   (\($g)/\($t) elemede niçin yazılı)"
  end' "$DEFTER" 2>/dev/null

# ── 3) HAVUZ SİNDİRİMİ — getirileni işleyebiliyor muyum ───────────────────────────────────
# Düşükse hat tıkanıyor demektir: KAŞİF üretiyor, MUCİT yetişemiyor, malzeme bayatlıyor.
if [ -n "${HAVUZ:-}" ] && [ -s "$HAVUZ" ]; then
  jq -rs '
    (length) as $t |
    ([ .[] | select((.durum // "ham") != "ham") ] | length) as $i |
    if $t == 0 then empty
    else "   havuz sindirimi: %\(($i * 100 / $t) | floor)   (\($i)/\($t) malzeme işlenmiş — kalan \($t - $i) bekliyor)"
    end' "$HAVUZ" 2>/dev/null
fi

# ── 4) TAZELİK — en eski işlenmemiş malzeme kaç günlük ────────────────────────────────────
if [ -n "${HAVUZ:-}" ] && [ -s "$HAVUZ" ]; then
  BUGUN="$(date -u +%s)"
  jq -rs --argjson bugun "$BUGUN" '
    [ .[] | select((.durum // "ham") == "ham") | .tarih // empty ] | min // empty' "$HAVUZ" 2>/dev/null \
  | while IFS= read -r en_eski; do
      [ -n "$en_eski" ] || continue
      t="$(date -u -d "$en_eski" +%s 2>/dev/null || echo "")"
      [ -n "$t" ] || continue
      echo "   tazelik        : en eski bekleyen malzeme $(( (BUGUN - t) / 86400 )) günlük ($en_eski)"
    done
fi

echo ""
echo "   Nasıl okunur: gerekçe oranı %100'e YAKIN olmalı — gerekçesiz eleme, aynı analizi tekrar"
echo "   yaptırır. Havuz sindirimi düşerse hat tıkanıyor demektir (KAŞİF üretir, MUCİT yetişemez)."
echo "   Geçirme oranı için sağlıklı bant henüz belirlenmedi — hafta hafta karşılaştır, tek koşuya bakma."
echo "   Not: 'kaç aday üretti' bilerek ölçülmez — ölçtüğün şeyi üretirsin, eşik gevşer."
exit 0
