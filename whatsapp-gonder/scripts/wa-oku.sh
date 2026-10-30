#!/usr/bin/env bash
# wa-oku — filo WhatsApp geçidinden GELEN mesajları oku (L23 F4 istemcisi).
#
# NE-DİR: Her kutudan çalışan TEK okuma komutu. Kutu tarafında yapılandırma YOK — geçit
#         iç ağda `cloudtop-wa` adıyla durur, kutu yalnız ona seslenir. Kutu YALNIZ kendi
#         scope'una düşen mesajları görür (İ1-süzme geçitte; burada süzme YOKTUR ve OLAMAZ).
#
# NE YAPMAZ: numara bilmez · oturum tutmaz · WhatsApp'a doğrudan bağlanmaz · süzmez
#            (süzgeç geçittedir; istemcideki süzgeç güven-sınırı sayılmaz).
#
# Kullanım:
#   wa-oku.sh                → imleçten (kaldığın yerden) yeni mesajlar; imleç ilerletilir
#   wa-oku.sh --bastan       → imleci yok say (depodaki görünür her şey; imleç yine ilerletilir)
#   wa-oku.sh --sayi 20      → en çok 20 kayıt (varsayılan 50, tavan 100 geçitte)
#   wa-oku.sh --kuru         → imleci İLERLETME (aynı mesajlar sonraki turda yine gelir)
#
# Çıkış: 0 okundu (0 mesaj da meşru) · 2 kullanım/ortam · 3 geçide ulaşılamadı · 4 geçit reddetti
set -uo pipefail

GECIT="${WA_GECIT:-http://cloudtop-wa:8790}"
IMLEC_YOLU="${WA_IMLEC:-/config/.wa-gelen-imlec}"
SAYI=50; BASTAN=0; KURU=0

# ── Kutu jetonu (kimlik) ─────────────────────────────────────────────────────
# ⚠️ DEĞER-SINIFI: jeton bir SIRDIR — ekrana/loga/hata mesajına ASLA basılmaz.
_jeton_oku() {
  [ -n "${WA_JETON:-}" ] && { printf '%s' "$WA_JETON"; return 0; }
  [ -r /config/.wa-jeton ] && { head -1 /config/.wa-jeton | tr -d '\r\n'; return 0; }
  return 1
}
JETON="$(_jeton_oku)" || JETON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bastan) BASTAN=1; shift ;;
    --kuru)   KURU=1; shift ;;
    --sayi)   SAYI="${2:-}"; shift 2 ;;
    -h|--yardim) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done
case "$SAYI" in ''|*[!0-9]*) echo "HATA: --sayi sayı olmalı" >&2; exit 2 ;; esac

command -v curl >/dev/null || { echo "HATA: curl yok — kutuya kurulmalı." >&2; exit 2; }
command -v python3 >/dev/null || { echo "HATA: python3 yok — kutuya kurulmalı." >&2; exit 2; }

SONRA=0
if [ "$BASTAN" = "0" ] && [ -r "$IMLEC_YOLU" ]; then
  SONRA="$(head -1 "$IMLEC_YOLU" | tr -d '[:space:]')"
  case "$SONRA" in ''|*[!0-9]*) SONRA=0 ;; esac
fi

# Yanıt gövdesi sürece özel taze dosyaya — sabit yol bayat-gövde/sahte-yeşil üretir
# (wa-gonder.sh'taki canlı vaka, 2026-07-29: root'a ait bayat dosya + curl rc=23).
YANIT="$(mktemp "${TMPDIR:-/tmp}/wa-oku.XXXXXX")" || { echo "HATA: geçici dosya açılamadı" >&2; exit 2; }
trap 'rm -f "$YANIT"' EXIT

GOVDE="{\"sonra\": $SONRA, \"sayi\": $SAYI}"
KOD=$(curl -s -m 20 -o "$YANIT" -w '%{http_code}' \
  -X POST -H 'content-type: application/json' -H "x-wa-jeton: $JETON" \
  -d "$GOVDE" "$GECIT/gelen-oku" 2>/dev/null) || KOD="000"

if [ -z "${KOD:-}" ] || [ "$KOD" = "000" ]; then
  echo "🔴 geçide ULAŞILAMIYOR ($GECIT) — okunamadı."; exit 3
fi
if [ "$KOD" != "200" ]; then
  echo "🔴 geçit reddetti (http=$KOD):"; cat "$YANIT"; echo
  exit 4
fi

# Gösterim + imleç tek geçişte; python3 yalnız stdlib. Mesaj gövdesi kutunun EKRANINA
# basılır (kutu zaten görme yetkisindekini aldı) — ama İMLEÇ dosyasına metin yazılmaz.
SON_SIRA=$(python3 - "$YANIT" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(-1); raise SystemExit
if not d.get("ok"):
    print(-1); raise SystemExit
m = d.get("mesajlar") or []
for k in m:
    kim = k.get("gonderen_adi") or k.get("gonderen") or "?"
    yon = "→ (benden)" if k.get("benden") else f"← {kim}"
    grup = " [grup]" if k.get("grup") else ""
    print(f'#{k.get("sira")} · {k.get("ts","")} · {k.get("sohbet","?")}{grup} {yon}')
    print(f'   {k.get("metin","")}')
print(f'── {d.get("sayi",0)} mesaj · imleç {d.get("son_sira",0)}')
print(d.get("son_sira", 0))
PY
) || { echo "HATA: yanıt çözülemedi" >&2; exit 4; }

# Son satır = imleç; öncekiler ekrana
GOSTER="$(printf '%s\n' "$SON_SIRA" | head -n -1)"
IMLEC="$(printf '%s\n' "$SON_SIRA" | tail -1)"
[ -n "$GOSTER" ] && printf '%s\n' "$GOSTER"
if [ "$IMLEC" = "-1" ]; then echo "🔴 geçit gövdesi ok değil:"; cat "$YANIT"; echo; exit 4; fi

if [ "$KURU" = "0" ] && [ "$IMLEC" -gt 0 ] 2>/dev/null; then
  printf '%s\n' "$IMLEC" > "$IMLEC_YOLU" && chmod 600 "$IMLEC_YOLU" 2>/dev/null || true
fi
exit 0
