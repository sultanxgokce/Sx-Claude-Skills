#!/usr/bin/env bash
# mucit-durum-yaz.sh — MUCİT'in elek-kararlarını bulgu-havuzundaki `durum` alanına işleyen
# TEK BOĞAZ (uc-elek-suzme-DESIGN §3.3 · Değişmez-13 "tek-boğaz durum-flip" deseni).
#
# ⚠️ NİÇİN VAR: bugüne kadar süzme kararının hiçbir mekanik hafızası yoktu. Bir bulgu elenince de,
#   aday olup karta dönüşünce de havuzdaki `durum` alanı `ham` kalıyordu; bir sonraki koşuda hepsi
#   yeniden T1'e giriyordu. Ölçüm (2026-07-28): 29 bulgu yeniden süzmeye girdi, içinde zaten
#   aday-arzı olmuş b0022 (kart k0142) vardı. Bu script o köprüyü kurar — kararı OLGUYA çevirir.
#
# NE YAPAR: mucit-defteri'ni okur, YALNIZ "kapatıcı" sınıf kararları için havuzdaki `durum`u
#   günceller. Öteki hiçbir alana dokunmaz; satır sırası ve tüm mevcut alanlar korunur.
#
# GEÇİŞ TABLOSU (§3.3 — bunun DIŞINDA hiçbir yazma yoktur):
#   verdikt=aday-arzi                         → durum=aday-onerildi  (+ kart alanı defterden taşınır)
#   verdikt=elendi ∧ not "zaten-var|zaten-planli" → durum=elendi-kalici
#   verdikt=mihenk-alani                      → DEĞİŞMEZ (havuzda kalır, MİHENK-listesine düşer)
#   preview · cap-ertelendi · düşük-değer elendi → DEĞİŞMEZ (pencereli; yeniden girebilir)
#
# 🔒 İKİ KAPI (fail-closed):
#   1. `MUCIT_DURUM_YAZ=1` yoksa HİÇBİR ŞEY yazılmaz — bayrak kapalıyken script salt-rapordur.
#   2. `--uygula` verilmezse yazılmaz (varsayılan = kuru-koşu, planı basar).
#   İkisi birden gerekir. Böylece "yanlışlıkla koştu" ile "bilinçli göç" ayrılır.
#
# İDEMPOTENT: zaten doğru `durum`a sahip bulgu "değişmedi" sayılır; ikinci koşu 0 değişiklik yapar.
# İ1: yalnız BU odanın defter/havuz dosyalarını okur-yazar; ağ/ssh YOK, sır basmaz.
#
# Kullanım: mucit-durum-yaz.sh [--uygula] [--havuz <yol>] [--defter <yol>]
# Çıkış: 0=tamam (kuru-koşu da 0) · 2=ortam/kullanım hatası · 4=bayrak kapalı ama --uygula istendi
set -euo pipefail

UYGULA=0
HAVUZ="${MUCIT_HAVUZ:-}"
DEFTER="${MUCIT_DEFTER:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --uygula) UYGULA=1 ;;
    --havuz)  HAVUZ="${2:?}"; shift ;;
    --defter) DEFTER="${2:?}"; shift ;;
    *) echo "kullanım: mucit-durum-yaz.sh [--uygula] [--havuz <yol>] [--defter <yol>]" >&2; exit 2 ;;
  esac; shift
done

command -v jq >/dev/null 2>&1 || { echo "HATA: jq yok" >&2; exit 2; }

# yol-çözümü: t1 ile AYNI kütüphane (paket-içi; hucre-baglam PAKETE GİRMEZ — İ1)
if [ -z "$HAVUZ" ] || [ -z "$DEFTER" ]; then
  PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
  [ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
  # shellcheck source=/dev/null
  source "$HAT_LIB"
  [ -n "$HAVUZ" ]  || { HAVUZ="$(hat_yolu bulgu-havuzu)" || exit 2; }
  [ -n "$DEFTER" ] || { DEFTER="$(hat_yolu mucit-defteri)" || exit 2; }
fi

[ -f "$HAVUZ" ]  || { echo "HATA: havuz yok: $HAVUZ" >&2; exit 2; }
[ -f "$DEFTER" ] || { echo "HATA: defter yok: $DEFTER" >&2; exit 2; }
jq empty "$HAVUZ"  2>/dev/null || { echo "HATA: havuz bozuk-JSONL — fail-closed: $HAVUZ" >&2; exit 2; }
jq empty "$DEFTER" 2>/dev/null || { echo "HATA: defter bozuk-JSONL — fail-closed: $DEFTER" >&2; exit 2; }

if [ "$UYGULA" = "1" ] && [ "${MUCIT_DURUM_YAZ:-0}" != "1" ]; then
  echo "🔒 BAYRAK KAPALI: MUCIT_DURUM_YAZ=1 verilmeden yazma yapılmaz (fail-closed)." >&2
  echo "   Kuru-koşu için bayrağa gerek yok: mucit-durum-yaz.sh   (planı basar, dosyaya dokunmaz)" >&2
  exit 4
fi

# ── defterden HEDEF durum haritası (bulgu_id → durum · kart) ────────────────────────────────
# Son karar kazanır: defter append-only, aynı bulgu için birden çok satır olabilir.
HEDEF="$(jq -sc '
  [ .[]
    | select(.bulgu_id != null)
    | if   (.verdikt == "aday-arzi")
      then {id: .bulgu_id, durum: "aday-onerildi", kart: (.kart // null)}
      elif (.verdikt == "elendi" and ((.not // "") | test("^(zaten-var|zaten-planli)")))
      then {id: .bulgu_id, durum: "elendi-kalici", kart: null}
      else empty end
  ] | INDEX(.id)
' "$DEFTER")"

SAYI_HEDEF=$(jq 'length' <<<"$HEDEF")
if [ "$SAYI_HEDEF" = "0" ]; then
  echo "· defterde kapatıcı karar yok — yapılacak bir şey yok."
  exit 0
fi

# ── plan: neyin değişeceği (idempotent — zaten doğru olanlar 'aynı' sayılır) ─────────────────
PLAN="$(jq -sc --argjson h "$HEDEF" '
  [ .[] | . as $b | ($h[$b.id] // empty) as $t
    | select($t != null and (($b.durum // "ham") != $t.durum))
    | {id: $b.id, eski: ($b.durum // "ham"), yeni: $t.durum, kart: $t.kart, baslik: ($b.baslik // "")} ]
' "$HAVUZ")"
SAYI_PLAN=$(jq 'length' <<<"$PLAN")

echo "🧠 MUCİT durum-yazıcı  ·  defter: $(basename "$DEFTER")  ·  havuz: $(basename "$HAVUZ")"
echo "   defterde kapatıcı karar : $SAYI_HEDEF bulgu"
echo "   havuzda değişecek       : $SAYI_PLAN bulgu"
if [ "$SAYI_PLAN" != "0" ]; then
  jq -r '.[] | "     \(.id)  \(.eski) → \(.yeni)\(if .kart then "  (kart \(.kart))" else "" end)  \(.baslik[0:60])"' <<<"$PLAN"
fi

if [ "$UYGULA" != "1" ]; then
  echo ""
  echo "   KURU-KOŞU — hiçbir şey yazılmadı."
  [ "$SAYI_PLAN" != "0" ] && echo "   uygulamak için: MUCIT_DURUM_YAZ=1 $(basename "${BASH_SOURCE[0]}") --uygula"
  exit 0
fi

if [ "$SAYI_PLAN" = "0" ]; then
  echo "   ✓ havuz zaten güncel (idempotent) — yazma yapılmadı."
  exit 0
fi

# ── yaz: atomik (tmp + mv), satır sırası ve tüm öteki alanlar korunur ────────────────────────
TMP="$(mktemp "${HAVUZ}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
# ⚠️ `// null` (`// empty` DEĞİL): empty tüm ifadeyi susturur → eşleşmeyen satır çıktıya HİÇ
#    düşmezdi (sessiz veri-kaybı). Aşağıdaki kayıt-sayısı bekçisi bunu yakaladı (2→1).
jq -c --argjson h "$HEDEF" '
  . as $b | ($h[$b.id] // null) as $t
  | if $t == null then $b
    else $b + {durum: $t.durum} + (if ($t.kart != null and ($b.kart // null) == null) then {kart: $t.kart} else {} end)
    end
' "$HAVUZ" > "$TMP"

# fail-closed doğrulama: satır sayısı korunmalı, çıktı geçerli JSONL olmalı
ESKI_N=$(jq -s 'length' "$HAVUZ"); YENI_N=$(jq -s 'length' "$TMP")
[ "$ESKI_N" = "$YENI_N" ] || { echo "HATA: kayıt sayısı değişti ($ESKI_N→$YENI_N) — yazma İPTAL." >&2; exit 2; }
jq empty "$TMP" 2>/dev/null || { echo "HATA: üretilen havuz bozuk-JSONL — yazma İPTAL." >&2; exit 2; }

mv "$TMP" "$HAVUZ"
trap - EXIT
echo ""
echo "   ✓ $SAYI_PLAN bulgu damgalandı → $HAVUZ"
echo "   Bundan sonra bu bulgular hiçbir eleğe girmez (MUCIT_ELEK_HAFIZA=1 ile T1 de görür)."
