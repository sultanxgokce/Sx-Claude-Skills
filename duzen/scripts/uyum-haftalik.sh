#!/usr/bin/env bash
# uyum-haftalik.sh — haftalık uyum denetimi (Kuzey G30): surum.sh denetle'yi koşar, SAPMAYI Bulgu Havuzu'na yazar ve günlüğe tek satır düşer.
# surum.sh yalnız raporlar; bu betik onu çağırır ve iki şey ekler: (1) sapma havuza girer, (2) hiç kimlik işaretli değilse
# "güncel" DEMEZ, SARI der (işaretsiz depoda surum.sh rc 0 + "güncel" basar — işaretli kimlik yoksa güncellik ölçülmemiştir).
#
# Kullanım:
#   uyum-haftalik.sh [--depo KÖK] [--kurulu DİZİN] [--bulgu-sh YOL] [--gunluk DOSYA] [--kuru]
#     --depo      denetlenecek depo (varsayılan: git kökü)
#     --kurulu    kurulu duzen kopyası (surum.sh'a geçer)
#     --bulgu-sh  havuza yazan betik (varsayılan /config/.claude/skills/bulgu/scripts/bulgu.sh; çağrı: <yol> yaz "<başlık>" --kim … --etiket bug --not …)
#     --gunluk    günlük dosyası (varsayılan $UYUM_GUNLUK ya da /config/.claude/uyum-haftalik.log)
#     --kuru      havuza ve günlüğe YAZMAZ; yalnız hükmü basar
# Günlük satırı:  <ISO zaman> uyum depo=<ad> isaretli=<N> sapma=<N> durum=temiz|sapma|sari|olculemedi
# rc: 0 temiz · 1 sapma var (havuza yazıldı) · 2 kullanım · 3 ölçülemedi (surum.sh rc 3 — "0 sapma" SAYILMAZ) · 4 SARI (hiç kimlik işaretli değil)
#     5 hüküm verildi ama havuza YAZILAMADI (bulgu-sh hata verdi; sebep ekranda)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SURUM="${UYUM_SURUM_SH:-$HERE/surum.sh}"
DEPO=""; KURULU=""; BULGU="${UYUM_BULGU_SH:-/config/.claude/skills/bulgu/scripts/bulgu.sh}"; GUNLUK="${UYUM_GUNLUK:-/config/.claude/uyum-haftalik.log}"; KURU=0
while [ $# -gt 0 ]; do
  case "$1" in
    --depo) [ $# -ge 2 ] || { echo "uyum: --depo değersiz" >&2; exit 2; }; DEPO="$2"; shift 2 ;;
    --kurulu) [ $# -ge 2 ] || { echo "uyum: --kurulu değersiz" >&2; exit 2; }; KURULU="$2"; shift 2 ;;
    --bulgu-sh) [ $# -ge 2 ] || { echo "uyum: --bulgu-sh değersiz" >&2; exit 2; }; BULGU="$2"; shift 2 ;;
    --gunluk) [ $# -ge 2 ] || { echo "uyum: --gunluk değersiz" >&2; exit 2; }; GUNLUK="$2"; shift 2 ;;
    --kuru) KURU=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "uyum: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ARGS=(denetle --depo "$DEPO"); [ -z "$KURULU" ] || ARGS+=(--kurulu "$KURULU")

CIKTI="$(bash "$SURUM" "${ARGS[@]}" 2>&1)"; RC=$?
ISARETLI="$(sed -nE 's/.*ekipc işaretli ([0-9]+).*/\1/p' <<<"$CIKTI" | head -1)"; ISARETLI="${ISARETLI:-0}"
SAPMA="$(grep -cE '(BAYAT|EL-DEĞMİŞ)' <<<"$(grep -v '^SONUÇ' <<<"$CIKTI")")"
AD="$(basename "$DEPO")"

if [ "$RC" -eq 3 ]; then DURUM=olculemedi; SAPMA=0
elif [ "$RC" -eq 1 ] || [ "$SAPMA" -gt 0 ]; then DURUM=sapma
elif [ "$ISARETLI" -eq 0 ]; then DURUM=sari
elif [ "$RC" -eq 0 ]; then DURUM=temiz
else DURUM=olculemedi; fi

SATIR="$(date -Iseconds) uyum depo=$AD isaretli=$ISARETLI sapma=$SAPMA durum=$DURUM"
echo "$CIKTI"; echo "UYUM: $SATIR"

YAZ_RC=0
if [ "$KURU" -eq 0 ]; then
  case "$DURUM" in
    sapma) BASLIK="Düzen uyumu: $AD deposunda $SAPMA kimlik/kopya düzen paketinden sapmış"; ETIKET=bug ;;
    sari) BASLIK="Düzen uyumu SARI: $AD deposunda hiçbir kimlik işaretli değil — güncellik ölçülemiyor"; ETIKET=ozellik ;;
    *) BASLIK="" ;;
  esac
  if [ -n "$BASLIK" ]; then
    bash "$BULGU" yaz "$BASLIK" --kim "${AGENT_NAME:-MİRAHUR}" --etiket "$ETIKET" --not "$(grep -v '^SONUÇ' <<<"$CIKTI" | head -20)" </dev/null || YAZ_RC=$?
    [ "$YAZ_RC" -eq 0 ] || echo "uyum: havuza YAZILAMADI (bulgu-sh rc $YAZ_RC)" >&2
  fi
  mkdir -p "$(dirname "$GUNLUK")" 2>/dev/null; printf '%s\n' "$SATIR" >> "$GUNLUK" || echo "uyum: günlüğe yazılamadı ($GUNLUK)" >&2
fi

[ "$YAZ_RC" -eq 0 ] || exit 5
case "$DURUM" in temiz) exit 0 ;; sapma) exit 1 ;; sari) exit 4 ;; *) exit 3 ;; esac
