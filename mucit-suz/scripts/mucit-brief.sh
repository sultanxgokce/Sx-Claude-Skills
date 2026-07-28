#!/usr/bin/env bash
# mucit-brief.sh — MUCİT'in SÜZME-ÖNCESİ brifingi (ADR-025 K6, KAŞİF'in ikizi).
#
# NİÇİN: MUCİT'in defteri vardı ama **okuyanı yoktu** (`mucit-suz/SKILL.md`'de "geçmişini oku" satırı
#   0 eşleşme — ölçüldü 2026-07-28). Somut sonucu: MUCİT bir fikri eleyip "bu zaten var" diyor, deftere
#   yazıyor, ve **üç hafta sonra aynı fikir gelince sıfırdan araştırıyor.** Kendi dünkü kararını bilmiyor.
#
#   ADR-025 K6: "Bir birime verilen hafıza yüzeyi kardeş birimlere de verilir." KAŞİF'e F6/F7'de verilen
#   (defter + brifing + karne) buraya da veriliyor; bu dosya o simetrinin okuma ucudur.
#
# ⛔ ÇIKTI TAVANI 40 SATIR — kayıt sayısından BAĞIMSIZ. Brifing her süzme turunun başında context'e
#   giriyor; büyürse asıl işi (muhakeme) sıkıştırır. Ham JSONL **asla** basılmaz.
#
# SESSİZ-BAŞLANGIÇ: defter yoksa hiçbir şey basmaz, rc=0. SALT-OKUR: hiçbir dosyaya yazmaz.
#
# Kullanım: mucit-brief.sh [--gun N]   (N = geriye kaç gün, default 30 — süzme KAŞİF'ten seyrek koşar)
set -uo pipefail

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || exit 0
# shellcheck source=/dev/null
source "$HAT_LIB" 2>/dev/null || exit 0
command -v jq >/dev/null 2>&1 || exit 0

GUN=30
while [ $# -gt 0 ]; do
  case "$1" in
    --gun) GUN="${2:-30}"; shift 2 ;;
    *) echo "kullanım: mucit-brief.sh [--gun N]" >&2; exit 0 ;;
  esac
done

DEFTER="${MUCIT_DEFTER:-$(hat_yolu mucit-defteri 2>/dev/null || true)}"
HAVUZ="${MUCIT_HAVUZ:-$(hat_yolu bulgu-havuzu 2>/dev/null || true)}"
[ -n "${DEFTER:-}" ] && [ -s "$DEFTER" ] || exit 0

ESIK="$(date -u -d "-${GUN} days" +%Y-%m-%d 2>/dev/null || echo "0000-00-00")"

echo "🧭 MUCİT brifingi — son $GUN gün"

# ── 1) Nabız: en son ne zaman süzdüm, ne çıktı ────────────────────────────────────────────
jq -rs --arg e "$ESIK" '
  [ .[] | select((.tarih // "") >= $e and (.verdikt // "") != "dogum") ] as $s |
  ( [ .[] | .tarih // empty ] | max // "—" ) as $son |
  ( $s | length ) as $t |
  ( [ $s[] | select((.verdikt // "") == "aday-arzi") ] | length ) as $aday |
  ( [ $s[] | select((.verdikt // "") == "elendi") ] | length ) as $eldi |
  if $t == 0 then "   (bu pencerede süzme kaydı yok — son işlem: \($son))"
  else "   son süzme: \($son)  ·  \($t) karar  ·  \($aday) aday çıktı  ·  \($eldi) elendi"
  end' "$DEFTER" 2>/dev/null

# ── 2) NİÇİN ELEDİM — en sık eleme gerekçeleri ────────────────────────────────────────────
# MUCİT'in asıl birikimi budur: "bu tür fikirler bende hep düşüyor". Bunu bilirse hem tutarlı
# eler hem de aynı analizi tekrar yapmaz. (İleride KAŞİF'e geri beslenecek olan sinyal de bu.)
e="$(jq -rs --arg e "$ESIK" '[ .[] | select((.tarih // "") >= $e and (.verdikt // "") == "elendi") ] | length' "$DEFTER" 2>/dev/null || echo 0)"
if [ "${e:-0}" != "0" ]; then
  echo ""
  echo "⛔ elediklerim (aynı analizi tekrar yapma):"
  jq -rs --arg e "$ESIK" '
    [ .[] | select((.tarih // "") >= $e and (.verdikt // "") == "elendi") ]
    | sort_by(.tarih) | reverse | .[0:6][]
    | "   \(.tarih // "?")  \((.baslik // "?")[0:44])  —  \((.not // "gerekçe yok")[0:40])"' \
    "$DEFTER" 2>/dev/null
fi

# ── 3) ADAY OLANLAR — ne tür fikirler geçiyor (kalibrasyon) ───────────────────────────────
a="$(jq -rs --arg e "$ESIK" '[ .[] | select((.tarih // "") >= $e and ((.verdikt // "") | test("aday"))) ] | length' "$DEFTER" 2>/dev/null || echo 0)"
if [ "${a:-0}" != "0" ]; then
  echo ""
  echo "✅ aday yaptıklarım (eşiğim burada):"
  jq -rs --arg e "$ESIK" '
    [ .[] | select((.tarih // "") >= $e and ((.verdikt // "") | test("aday"))) ]
    | sort_by(.tarih) | reverse | .[0:4][]
    | "   \(.tarih // "?")  \((.baslik // "?")[0:52])\(if .kart then "  · kart \(.kart)" else "" end)"' \
    "$DEFTER" 2>/dev/null
fi

# ── 4) ÖNÜMDEKİ İŞ — havuzda kaç ham malzeme bekliyor ─────────────────────────────────────
if [ -n "${HAVUZ:-}" ] && [ -s "$HAVUZ" ]; then
  jq -rs '
    ([ .[] | select((.durum // "ham") == "ham") ] | length) as $ham |
    (length) as $t |
    if $ham == 0 then "\n📥 havuzda bekleyen ham malzeme yok — süzecek bir şey olmayabilir"
    else "\n📥 havuzda \($ham) ham malzeme bekliyor (toplam \($t) kayıt)"
    end' "$HAVUZ" 2>/dev/null
fi

echo ""
echo "   (tam defter: _agents/handoff/mucit-defteri.jsonl — bu özet 40 satırı geçmez)"
exit 0
