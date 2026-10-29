#!/usr/bin/env bash
# el-defteri.sh — bir koltuğun EL DEFTERİNİ tek metin olarak çıkarır (alt ajan istemine eklenecek "sıfır bağlam" paketi).
#
# Niçin: alt ajan boş bağlamla doğar; ÇIRAK emsali (_agents/cirak/cirak-istem.sh) bunu elle yapıyordu, MÜŞAVİR'in
# EL-DEFTERI.md üreticisi hiç yoktu. Bu betik her kutuda aynı biçimi basar: son N not satırı + bugünkü ÇIPA + son KONUM
# + açık işler. Hiçbir satırı UYDURMAZ: kaynak yoksa söyler (rc 3), ölçemediğini "ölçülemedi" diye yazar.
#
# Kullanım:
#   el-defteri.sh [--ajan AD] [--n 25] [--depo KÖK]
#     --ajan  koltuk adı (varsayılan $AGENT_NAME); defter yolu <depo>/_agents/<slug>/NOTES.md
#     --n     son kaç not satırı (varsayılan 25; 1-200)
#     --depo  kutu depo kökü (varsayılan: git toplevel, yoksa cwd)
# Ortam (sınav/elle): DUZEN_GOREV_SH = gorev.sh yolu (yoksa gunluk-plan'ın gorev-yolu.sh'ı sorulur; o da yoksa "ölçülemedi")
#                     DUZEN_SIMDI   = epoch (bugünün tarihini sabitler)
# rc: 0 basıldı · 2 kullanım hatası · 3 el defteri yok (NOTES.md bulunamadı)
# Çıktı tavanı ~40 satır: notlar N + ÇIPA 1 + KONUM 1 + açık iş ≤8 + başlıklar.
set -uo pipefail

AJAN="${AGENT_NAME:-}"; N=25; DEPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ajan) AJAN="${2:-}"; shift 2 ;;
    --n) N="${2:-}"; shift 2 ;;
    --depo) DEPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "el-defteri: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done
[ -n "$AJAN" ] || { echo "el-defteri: koltuk adı yok (--ajan AD ya da AGENT_NAME)" >&2; exit 2; }
[[ "$N" =~ ^[0-9]+$ ]] && [ "$N" -ge 1 ] && [ "$N" -le 200 ] || { echo "el-defteri: --n 1-200 arası sayı olmalı: $N" >&2; exit 2; }
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# slug: BÂNİ → bani (ekipc.sh slug kuralıyla aynı: yalnız [a-z0-9-])
slug() { printf '%s' "$1" | sed 'y/ÇĞİÖŞÜÂÎÛçğıöşüâîû/CGIOSUAIUcgiosuaiu/' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'; }
SLUG="$(slug "$AJAN")"
NOTES="$DEPO/_agents/$SLUG/NOTES.md"
[ -f "$NOTES" ] || { echo "el defteri yok: $NOTES (koltuk '$AJAN' bu kutuda defter tutmuyor — uydurulmadı)" >&2; exit 3; }

AN="${DUZEN_SIMDI:-$(date +%s)}"; GUN="$(date -d "@$AN" +%F)"

echo "# EL DEFTERİ · $AJAN · $GUN · kaynak: ${NOTES#$DEPO/}"
echo
echo "## Bugünkü ÇIPA"
if grep -qx "## ÇIPA $GUN" "$NOTES"; then echo "## ÇIPA $GUN (defterde var)"; else echo "(bugün için ÇIPA başlığı yok)"; fi
echo
echo "## Son KONUM"
KONUM="$(grep -n 'KONUM' "$NOTES" | tail -1 | cut -d: -f2- | cut -c1-400)"
if [ -n "$KONUM" ]; then printf '%s\n' "$KONUM"; else echo "(KONUM satırı yok)"; fi
echo
echo "## Son $N not satırı"
tail -n "$N" "$NOTES" | cut -c1-300
echo
echo "## Açık işler ($AJAN)"
GOREV="${DUZEN_GOREV_SH:-}"
if [ -z "$GOREV" ]; then
  for y in /config/.claude/skills/gunluk-plan/scripts/gorev-yolu.sh "$(dirname "$0")/../../gunluk-plan/scripts/gorev-yolu.sh"; do
    [ -f "$y" ] && { GOREV="$(bash "$y" 2>/dev/null)"; break; }
  done
fi
if [ -n "$GOREV" ] && [ -f "$GOREV" ]; then
  ISLER="$(bash "$GOREV" liste 2>/dev/null | grep -F -- "$AJAN" | grep -Ev '\b(iptal|bitti)\b' | head -8 | cut -c1-200)"
  if [ -n "$ISLER" ]; then printf '%s\n' "$ISLER"; else echo "(defterde $AJAN adına açık iş yok)"; fi
else
  echo "(açık işler ölçülemedi: gorev.sh bulunamadı)"
fi
