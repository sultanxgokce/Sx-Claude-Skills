#!/usr/bin/env bash
# Tek komut: JSON -> PDF+DOCX -> (opsiyonel) Ortak klasör + WhatsApp
set -euo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON=""; KISI=""; WA=0; CIKIS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kisi)   KISI="$2"; shift 2 ;;      # Ayse | Sultan | Fahri -> hub alt-klasörü
    --wa)     WA=1; shift ;;             # WhatsApp'a da gönder
    --cikis)  CIKIS="$2"; shift 2 ;;
    -h|--help) echo "kullanım: dilekce.sh <girdi.json> [--kisi Ayse] [--wa] [--cikis DIZIN]"; exit 0 ;;
    *)        JSON="$1"; shift ;;
  esac
done
[[ -z "$JSON" ]] && { echo "HATA: girdi.json gerekli"; exit 2; }
[[ ! -f "$JSON" ]] && { echo "HATA: bulunamadı: $JSON"; exit 2; }

if [[ -z "$CIKIS" ]]; then
  if [[ -n "$KISI" ]]; then CIKIS="/config/evraklar/$KISI/Gelen"; else CIKIS="$(pwd)"; fi
fi
mkdir -p "$CIKIS"

SONUC="$(python3 "$BURASI/dilekce-uret.py" "$JSON" "$CIKIS")" || { echo "$SONUC"; echo "🔴 üretim/doğrulama BAŞARISIZ"; exit 4; }
echo "$SONUC"
PDF="$(echo "$SONUC"  | python3 -c 'import json,sys;print(json.load(sys.stdin)["pdf"])')"
DOCX="$(echo "$SONUC" | python3 -c 'import json,sys;print(json.load(sys.stdin)["docx"])')"
SAYFA="$(echo "$SONUC"| python3 -c 'import json,sys;print(json.load(sys.stdin)["sayfa"])')"
echo "🟢 üretildi (${SAYFA} sayfa) -> $CIKIS"

if [[ "$WA" == "1" ]]; then
  WAS=/config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh
  if [[ -x "$WAS" ]]; then
    bash "$WAS" --dosya "$PDF"  --not "$(basename "$PDF") — yazdır & imzala" | tail -1
    bash "$WAS" --dosya "$DOCX" --not "$(basename "$DOCX") — düzenlemek için"  | tail -1
  else
    echo "🟡 whatsapp-gonder skill'i yok, gönderim atlandı"
  fi
fi
