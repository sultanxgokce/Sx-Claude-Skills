#!/usr/bin/env bash
# wa-gonder — filo WhatsApp geçidine mesaj gönder (L23).
#
# NE-DİR: Her kutudan çalışan TEK komut. Kutu tarafında yapılandırma YOK — geçit iç ağda
#         `cloudtop-wa` adıyla duruyor, kutu yalnız ona sesleniyor.
#
# NE YAPMAZ: numara bilmez (alıcı ADI gönderir, numaraya çözümü geçit yapar) · oturum tutmaz ·
#            WhatsApp'a doğrudan bağlanmaz. Tek sıcak bağlantı geçittedir.
#
# Kullanım:
#   wa-gonder.sh "mesaj"                      → varsayılan alıcıya (Sultan) metin
#   wa-gonder.sh --kime Sultan "mesaj"        → adlandırılmış alıcıya
#   wa-gonder.sh --dosya /yol/rapor.pdf [--not "açıklama"]
#   wa-gonder.sh --durum                      → geçit ayakta mı, oturum açık mı
#
# Çıkış: 0 gönderildi · 2 kullanım · 3 geçide ulaşılamıyor · 4 geçit reddetti (gövdede neden)
set -uo pipefail

GECIT="${WA_GECIT:-http://cloudtop-wa:8790}"
KIME="Sultan"; METIN=""; DOSYA=""; NOT=""; MOD="metin"

while [ $# -gt 0 ]; do
  case "$1" in
    --kime)  KIME="${2:-}"; shift 2 ;;
    --dosya) DOSYA="${2:-}"; MOD="dosya"; shift 2 ;;
    --not)   NOT="${2:-}"; shift 2 ;;
    --durum) MOD="durum"; shift ;;
    -h|--yardim) sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "bilinmeyen seçenek: $1" >&2; exit 2 ;;
    *) METIN="$1"; shift ;;
  esac
done

_cagir() { # _cagir <yol> [gövde]
  if [ -n "${2:-}" ]; then
    curl -s -m 30 -o /tmp/.wa-yanit -w '%{http_code}' \
      -X POST -H 'content-type: application/json' -d "$2" "$GECIT$1" 2>/dev/null
  else
    curl -s -m 15 -o /tmp/.wa-yanit -w '%{http_code}' "$GECIT$1" 2>/dev/null
  fi
}

command -v curl >/dev/null || { echo "HATA: curl yok — kutuya kurulmalı." >&2; exit 2; }

if [ "$MOD" = "durum" ]; then
  KOD=$(_cagir /saglik) || true
  if [ -z "${KOD:-}" ] || [ "$KOD" = "000" ]; then
    echo "🔴 geçide ULAŞILAMIYOR ($GECIT) — kutu iç ağda mı, geçit ayakta mı?"; exit 3
  fi
  cat /tmp/.wa-yanit; echo
  # Dürüstlük: 200 'servis sağlam' demek; oturum kapalıysa gövdede yazar, yeşil sayma.
  grep -q '"baglanti":"open"' /tmp/.wa-yanit \
    && echo "🟢 gönderime hazır" \
    || echo "🟡 servis ayakta ama OTURUM AÇIK DEĞİL — şu an gönderemez"
  exit 0
fi

if [ "$MOD" = "dosya" ]; then
  [ -f "$DOSYA" ] || { echo "HATA: dosya yok: $DOSYA" >&2; exit 2; }
  GOVDE=$(python3 -c '
import json,sys
print(json.dumps({"alici":sys.argv[1],"tur":"dosya","dosya":sys.argv[2],"aciklama":sys.argv[3]}))' \
    "$KIME" "$DOSYA" "$NOT" 2>/dev/null) || { echo "HATA: gövde üretilemedi (python3 yok?)" >&2; exit 2; }
else
  [ -n "$METIN" ] || { echo "HATA: mesaj boş. Kullanım: $0 \"mesaj\"" >&2; exit 2; }
  GOVDE=$(python3 -c '
import json,sys
print(json.dumps({"alici":sys.argv[1],"tur":"metin","metin":sys.argv[2]}))' \
    "$KIME" "$METIN" 2>/dev/null) || { echo "HATA: gövde üretilemedi (python3 yok?)" >&2; exit 2; }
fi

KOD=$(_cagir /gonder "$GOVDE") || true
if [ -z "${KOD:-}" ] || [ "$KOD" = "000" ]; then
  echo "🔴 geçide ULAŞILAMIYOR ($GECIT) — mesaj GİTMEDİ."; exit 3
fi
if [ "$KOD" = "200" ]; then
  echo "🟢 gönderildi → $KIME"
  exit 0
fi
echo "🔴 geçit reddetti (http=$KOD):"; cat /tmp/.wa-yanit; echo
exit 4
