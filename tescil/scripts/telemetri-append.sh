#!/usr/bin/env bash
# telemetri-append.sh — tescil-telemetrisi append (tescil skill'i; DİVAN K5, k0054).
# _agents/tescil/telemetri.jsonl'e {ts, kart, deneme, verdict, sure_sn, g_sayisi,
# oznel_g_sayisi, tip, is_tipi} satırı ekler. --tatbikat → tip=tatbikat (anti-tiyatro sayımı).
# Append-only + flock-güvenli; sır-değer taşımaz. Rubber-stamp alarmı bu dosyadan okunur
# (KALDI-oranı→0 ∧ median-süre→kısa = alarm; report-only, SERDAR haftalık okur).
#
# Kullanım: telemetri-append.sh --file <telemetri.jsonl> --kart <k####> --deneme <n>
#           --verdict <GECTI|KALDI|ESKALASYON|KATMAN2-BEKLIYOR|RED> --sure <sn>
#           --g <sayı> --oznel <sayı> --tip <ui|kod|docs> [--tatbikat]
set -uo pipefail

FILE="" KKART="" DENEME="" VERDICT="" SURE="" GSAYI="" OZNEL="" ISTIPI="" TATBIKAT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file)    FILE="${2:-}"; shift 2 ;;
    --kart)    KKART="${2:-}"; shift 2 ;;
    --deneme)  DENEME="${2:-}"; shift 2 ;;
    --verdict) VERDICT="${2:-}"; shift 2 ;;
    --sure)    SURE="${2:-}"; shift 2 ;;
    --g)       GSAYI="${2:-}"; shift 2 ;;
    --oznel)   OZNEL="${2:-}"; shift 2 ;;
    --tip)     ISTIPI="${2:-}"; shift 2 ;;
    --tatbikat) TATBIKAT=1; shift ;;
    *) echo "telemetri-append: bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$FILE" ] || [ -z "$KKART" ] || [ -z "$DENEME" ] || [ -z "$VERDICT" ]; then
  echo "kullanım: telemetri-append.sh --file <jsonl> --kart <k####> --deneme <n> --verdict <V> [--sure sn] [--g n] [--oznel n] [--tip t] [--tatbikat]" >&2
  exit 2
fi
case "$VERDICT" in GECTI|KALDI|ESKALASYON|KATMAN2-BEKLIYOR|RED) ;; *)
  echo "telemetri-append: geçersiz verdict: $VERDICT" >&2; exit 2 ;; esac
command -v python3 >/dev/null 2>&1 || { echo "telemetri-append: python3 yok" >&2; exit 2; }

mkdir -p "$(dirname "$FILE")"
SATIR="$(python3 -c '
import json, sys
from datetime import datetime, timezone
tat = sys.argv[8] == "1"
print(json.dumps({
    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "kart": sys.argv[1], "deneme": int(sys.argv[2]), "verdict": sys.argv[3],
    "sure_sn": int(sys.argv[4] or 0), "g_sayisi": int(sys.argv[5] or 0),
    "oznel_g_sayisi": int(sys.argv[6] or 0),
    "tip": "tatbikat" if tat else "normal", "is_tipi": sys.argv[7] or None,
}, ensure_ascii=False))
' "$KKART" "$DENEME" "$VERDICT" "${SURE:-0}" "${GSAYI:-0}" "${OZNEL:-0}" "$ISTIPI" "$TATBIKAT")"

# flock-güvenli append (eşzamanlı tescil-koşuları satır karıştırmasın)
exec 9>>"$FILE"
flock 9
printf '%s\n' "$SATIR" >&9
exec 9>&-
echo "telemetri-append: eklendi → $FILE"
