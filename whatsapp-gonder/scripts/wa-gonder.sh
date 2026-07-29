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

# Yanıt gövdesi HER ÇAĞRIDA taze, sürece özel bir dosyaya yazılır.
# ⚠️ SABİT YOL KULLANMA (ör. /tmp/.wa-yanit): dosya başka bir kullanıcının koşusundan kalmışsa
#    curl üzerine YAZAMAZ (rc=23), sessizce başarısız olur ve betik BAYAT gövdeyi okur.
#    Bayat gövdede "open" yazıyorsa oturum kapalıyken YEŞİL basılır — sahte-yeşil.
#    (tez-MOTOR firsthand buldu, 2026-07-29: root'a ait bayat dosya, curl_rc=23.)
YANIT="$(mktemp "${TMPDIR:-/tmp}/wa-yanit.XXXXXX")" || { echo "HATA: gecici dosya acilamadi" >&2; exit 2; }
trap 'rm -f "$YANIT"' EXIT

_cagir() { # _cagir <yol> [gövde] → http kodunu basar; curl düşerse "000"
  local kod rc
  if [ -n "${2:-}" ]; then
    kod=$(curl -s -m 30 -o "$YANIT" -w '%{http_code}' \
      -X POST -H 'content-type: application/json' -d "$2" "$GECIT$1" 2>/dev/null); rc=$?
  else
    kod=$(curl -s -m 15 -o "$YANIT" -w '%{http_code}' "$GECIT$1" 2>/dev/null); rc=$?
  fi
  # curl'ün kendi hatası (yazma/ağ) sessiz geçmez — "000" fail-closed sinyalidir.
  [ "$rc" -eq 0 ] || { echo "000"; return 0; }
  echo "$kod"
}

command -v curl >/dev/null || { echo "HATA: curl yok — kutuya kurulmalı." >&2; exit 2; }

if [ "$MOD" = "durum" ]; then
  KOD=$(_cagir /saglik) || true
  if [ -z "${KOD:-}" ] || [ "$KOD" = "000" ]; then
    echo "🔴 geçide ULAŞILAMIYOR ($GECIT) — kutu iç ağda mı, geçit ayakta mı?"; exit 3
  fi
  cat "$YANIT"; echo
  # Dürüstlük: 200 'servis sağlam' demek; oturum kapalıysa gövdede yazar, yeşil sayma.
  grep -q "\"baglanti\":\"open\"" "$YANIT" \
    && echo "🟢 gönderime hazır" \
    || echo "🟡 servis ayakta ama OTURUM AÇIK DEĞİL — şu an gönderemez"
  exit 0
fi

if [ "$MOD" = "dosya" ]; then
  [ -f "$DOSYA" ] || { echo "HATA: dosya yok: $DOSYA" >&2; exit 2; }
  # ⚠️ İÇERİĞİ GÖNDER, YOLU DEĞİL. Geçit ayrı bir konteynerdir ve senin dosya ağacını
  #    GÖRMEZ — yol yollamak "bulunamadı" ile döner (canlı vaka 2026-07-29).
  #    İçeriği gövdede taşımak ayrıca hiçbir dosya sistemi bağı kurmaz (mahremiyet duvarı sağlam).
  BOYUT=$(wc -c < "$DOSYA" | tr -d ' ')
  if [ "$BOYUT" -gt 17000000 ]; then
    echo "HATA: dosya çok büyük ($BOYUT bayt) — geçit tavanı ~17MB. Küçült ya da parçala." >&2; exit 2
  fi
  GOVDE=$(python3 -c '
import json,sys,base64,os
p=sys.argv[2]
with open(p,"rb") as f: ham=f.read()
print(json.dumps({"alici":sys.argv[1],"tur":"dosya",
                  "dosya_adi":os.path.basename(p),
                  "icerik_b64":base64.b64encode(ham).decode(),
                  "aciklama":sys.argv[3]}))' \
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
echo "🔴 geçit reddetti (http=$KOD):"; cat "$YANIT"; echo
exit 4
