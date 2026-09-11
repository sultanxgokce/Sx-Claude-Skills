#!/usr/bin/env bash
# yt-transkript — YouTube videosunun TAM konuşma metnini getirir.
#
# 🔴 NİÇİN VAR (ölçüldü, 11 Eylül 2026 · MUAVİN):
#   Sultan bir videoyu okumamı istedi. ÜÇ ayrı yoldan denendi, üçü de düştü:
#     yt-dlp (oynatıcı API)  → "Sign in to confirm you're not a bot"
#     timedtext ucu (ayrı)   → RequestBlocked ("IP'nizden gelen istekler engelli")
#     düz sayfa çekimi       → 200 döner AMA captionTracks=0, 14 bot/onay işareti
#   Yani engel YÖNTEMDE değil, BU SUNUCUNUN IP'SİNDE. Bu yüzden Playwright, Chrome
#   eklentisi ya da başka bir tarayıcı da çözmez — tarayıcı değiştirmek IP değiştirmez.
#   (Sultan'ın Playwright önerisi mantıklıydı; ölçüm onu çürüttü, tahmin değil.)
#
#   Çözüm: isteği KENDİ sunucusundan yapan bir servis → bizim IP hiç devreye girmez.
#   Supadata seçildi (ölçüm: ücretsiz 100/ay · 1 video = 1 kredi · birim fiyat AÇIK).
#   Rakibi birim fiyatını yayımlamıyordu — ölçülemeyen birim seçilmez.
#
# 🔴 ANAHTAR argv'ye DÜŞMEZ (`ps` görmesin) — dosyadan okunup başlığa konur.
#    Değer hiçbir koşulda stdout'a basılmaz.
set -uo pipefail

ANAHTAR_DOSYA="${SUPADATA_ENV:-/config/.config/supadata.env}"
DIL="${2:-tr}"
URL="${1:-}"

kullanim() {
  cat <<'K'
kullanım: yt-transkript.sh <youtube-url> [dil]     → tam metin stdout'a
          yt-transkript.sh --durum                 → anahtar + kota yoklaması

çıkış kodları: 0 tamam · 2 kullanım · 3 anahtar yok · 4 servis reddetti · 5 altyazı yok
K
}

[ "$URL" = "--yardim" ] || [ "$URL" = "-h" ] && { kullanim; exit 0; }

[ -r "$ANAHTAR_DOSYA" ] || {
  echo "ÖLÇÜLEMEDİ: anahtar dosyası okunamadı ($ANAHTAR_DOSYA) — altyazı YOK değil, BİLİNMİYOR" >&2
  exit 3
}
# shellcheck disable=SC1090
set -a; . "$ANAHTAR_DOSYA"; set +a
[ -n "${SUPADATA_API_KEY:-}" ] || { echo "ÖLÇÜLEMEDİ: SUPADATA_API_KEY boş" >&2; exit 3; }

if [ "$URL" = "--durum" ]; then
  k=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -H "x-api-key: $SUPADATA_API_KEY" \
      "https://api.supadata.ai/v1/transcript?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ&text=true")
  case "$k" in
    200|206) echo "🟢 anahtar geçerli · servis yanıt veriyor" ; exit 0 ;;
    401|403) echo "🔴 anahtar REDDEDİLDİ (HTTP $k)" >&2 ; exit 4 ;;
    *)       echo "🟡 ÖLÇÜLEMEDİ: beklenmeyen yanıt (HTTP $k) — geçerli DEĞİL, bilinmiyor" >&2 ; exit 4 ;;
  esac
fi

[ -n "$URL" ] || { kullanim >&2; exit 2; }
case "$URL" in
  http*youtube.com/watch*|http*youtu.be/*) ;;
  *) echo "kullanım: geçerli bir YouTube adresi ver" >&2; exit 2 ;;
esac

KACIK="$(printf '%s' "$URL" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))')"
GECICI="$(mktemp)"; trap 'rm -f "$GECICI"' EXIT

KOD="$(curl -s -m 180 -o "$GECICI" -w '%{http_code}' \
   -H "x-api-key: $SUPADATA_API_KEY" \
   "https://api.supadata.ai/v1/transcript?url=${KACIK}&lang=${DIL}&text=true")"

case "$KOD" in
  200) ;;
  401|403) echo "servis REDDETTİ (HTTP $KOD) — anahtar ya da kota" >&2; exit 4 ;;
  404) echo "bu videoda altyazı YOK (HTTP 404)" >&2; exit 5 ;;
  *)   echo "ÖLÇÜLEMEDİ: HTTP $KOD — altyazı yok DEĞİL, bilinmiyor" >&2; exit 4 ;;
esac

python3 - "$GECICI" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
t=d.get("content","")
if not t.strip():
    sys.stderr.write("servis 200 döndü ama METİN BOŞ — sessiz başarı değil, hata\n"); sys.exit(5)
sys.stderr.write("dil=%s · karakter=%d · kelime=%d\n" % (d.get("lang","?"), len(t), len(t.split())))
print(t)
PY
