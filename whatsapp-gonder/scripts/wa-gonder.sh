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

# ── Kutu jetonu (kimlik) ─────────────────────────────────────────────────────
# Geçit 2026-07-29'dan beri kimlik istiyor; jetonsuz istek 401 {"hata":"jeton_yok"} döner.
# ⚠️ DEĞER-SINIFI: jeton bir SIRDIR — ekrana/loga/hata mesajına ASLA basılmaz.
_jeton_oku() {
  [ -n "${WA_JETON:-}" ] && { printf '%s' "$WA_JETON"; return 0; }
  [ -r /config/.wa-jeton ] && { head -1 /config/.wa-jeton | tr -d '\r\n'; return 0; }
  return 1
}
JETON="$(_jeton_oku)" || JETON=""

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
  local kod rc govde_dosya=""
  if [ -n "${2:-}" ]; then
    # GÖVDE DOSYADAN GİDER, argüman olarak DEĞİL. NİÇİN: `-d "$2"` gövdeyi komut satırı
    # argümanı yapıyordu; ~230 KB'lık bir dosya eki base64'lendiğinde kabuğun ARG_MAX
    # sınırı aşılıyor ve curl exec() aşamasında HİÇ BAŞLAMADAN rc=126 ile ölüyordu.
    # Script bunu ağ hatası sanıp "geçide ulaşılamıyor" diyordu — yanlış teşhis, çünkü
    # geçit ayaktaydı ve /saglik 200 dönüyordu (firsthand: cloudtop-tez, 2026-07-30,
    # 44 sayfalık PDF 3 kez üst üste "gönderilemedi"). Dosya yolu sabit uzunlukta olduğu
    # için argüman listesi büyümez; gövde boyutu ARG_MAX'a tabi değildir.
    govde_dosya="$(mktemp "${TMPDIR:-/tmp}/wa-govde.XXXXXX")" || {
      echo "000"; printf 'wa-gonder: geçici dosya açılamadı (gövde yazılamadı)\n' >&2; return 0; }
    printf '%s' "$2" > "$govde_dosya"
    kod=$(curl -s -m 30 -o "$YANIT" -w '%{http_code}' \
      -X POST -H 'content-type: application/json' -H "x-wa-jeton: $JETON" \
      -d "@$govde_dosya" "$GECIT$1" 2>/dev/null); rc=$?
    rm -f "$govde_dosya"
  else
    kod=$(curl -s -m 15 -o "$YANIT" -w '%{http_code}' -H "x-wa-jeton: $JETON" "$GECIT$1" 2>/dev/null); rc=$?
  fi
  # curl'ün kendi hatası sessiz geçmez — "000" fail-closed sinyalidir. AMA NEDENİ DE
  # SÖYLENİR: eskiden her rc≠0 "ağ" gibi görünüyordu; 126/127 ağ değil, curl'ün hiç
  # çalışamamasıdır ve bambaşka bir remediation ister (ölçemedim ≠ ulaşamadım).
  if [ "$rc" -ne 0 ]; then
    case "$rc" in
      126|127) printf 'wa-gonder: curl ÇALIŞTIRILAMADI (rc=%s) — bu bir ağ hatası DEĞİL; komut/argüman sorunu.\n' "$rc" >&2 ;;
      28)      printf 'wa-gonder: curl zaman aşımı (rc=28) — geçit yanıt vermedi.\n' >&2 ;;
      *)       printf 'wa-gonder: curl düştü (rc=%s) — geçide ulaşılamadı.\n' "$rc" >&2 ;;
    esac
    echo "000"; return 0
  fi
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
