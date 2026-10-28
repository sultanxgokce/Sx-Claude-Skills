#!/usr/bin/env bash
# kapi-yenile.sh — kutu kapısının pano.js'ini BAĞLANTI DÜŞÜRMEDEN tazeler (2.12.0 · SERDAR 00:5x).
#
# Niçin: pano köprüsü (genel/pano.js) kapı açılışında belleğe alınır. Yeni sürüm diske inince canlı kapı eskiyi sunmaya
# devam eder; eski tek yol `onar.sh --web-yenile` idi — kapı süreci ölür, Sultan'ın açık web terminali kopar.
# Yol: kapı SIGHUP'ta pano.js'i yeniden okur (sunucu.mjs). Bu betik:
#   1) diskteki pano.js sha'sını ölçer; kapının /giris yanıtındaki x-kapi-pano başlığıyla karşılaştırır → zaten aynıysa biter.
#   2) kapı süreci CANLI ve kapi.pid onunla EŞLEŞİYORSA (yani SIGHUP'ı tanıyan sürüm) SIGHUP gönderir, başlık disk sha'sına
#      dönene dek ≤5 sn bekler → "tazelendi, bağlantı kopmadı".
#   3) Aksi hâlde (kapı yok · eski sürüm: SIGHUP onu öldürürdü · sha dönmedi) `onar.sh --web-yenile`'ye düşer ve bunu SÖYLER
#      (bir kez kopar; sonraki yenilemeler sıcak olur). --kuru: hiçbir şey yapmaz, hangi yola gideceğini basar.
#   0) 2.34.0: önce kapı KODU ölçülür (kapi-eski-mi.sh); kapı diskteki koddan eski çalışıyorsa doğrudan `onar.sh --web-yenile`'ye
#      düşer — SIGHUP yalnız pano.js'i tazeler, yeni uçları (ör. /api/etiket) getirmez. Ölçülemezse (rc 2) aşağıdaki akış aynen sürer.
# RC: 0 tazelendi/zaten güncel · 1 web-yenile'ye düşüldü ve o da düştü · 2 pano.js yok
set -u
. "$(dirname "$0")/ortak.sh" || exit 3   # kutu adı reddi: ortak.sh sebebi tek satır yazdı → DUR, rc 3 (FSZ30; eskiden unbound variable ile çöküyordu)
KURU=0; [ "${1:-}" = "--kuru" ] && KURU=1
PANO="$KAPI_DIZ/genel/pano.js"
[ -f "$PANO" ] || { echo "pano.js yok: $PANO"; exit 2; }
disk=$(sha256sum "$PANO" | cut -c1-12)
baslik() { curl -s -m 4 -D - -o /dev/null "http://127.0.0.1:$KAPI_PORT$TABAN/giris" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="x-kapi-pano:"{print $2}'; }
canli_pid() { pgrep -u "$(id -u)" -f "node $KAPI_DIZ/sunucu.mjs" 2>/dev/null | head -1; }
dus() {  # $1 = sebep → onar.sh --web-yenile (kapı yeniden başlar, bağlantı BİR KEZ kopar)
  gunluk "kapi-yenile: $1 → onar.sh --web-yenile (bağlantı kopar)"
  echo "$1 → onar.sh --web-yenile ile yeniden başlatılıyor (bağlantı bir kez kopar; sonraki yenilemeler sıcak)"
  [ $KURU = 1 ] && exit 0
  exec bash "$BETIK_DIZ/onar.sh" --web-yenile
}
# 2.34.0 (WHRJ · 28 Eki): pano.js'ten ÖNCE kapının KODU ölçülür. Kapı diskteki .mjs'lerden eski çalışıyorsa SIGHUP yetmez (yeni uçlar —
#   /api/etiket, /tty-k/ — bellekte yoktur): tam yeniden başlatmaya düşülür ve söylenir. Ölçülemezse (süreç yok/yaş okunamadı) eski akış sürer.
#   Ölçüldü: 28 Eki 11:33'te 2.33.0 diske indi; 13 kutuda kapı 23–24 Eki'den beri açıktı → Kadro etiket düğmesi yalnız code'da çıktı.
set +e; eski_cikti=$(bash "$BETIK_DIZ/kapi-eski-mi.sh" 2>&1); eski_rc=$?; set -e
if [ "$eski_rc" = 1 ]; then
  dosya=$(printf '%s' "$eski_cikti" | sed -n 's/^⚠ kapı ESKİ kodla çalışıyor: \([^ ]*\) .*/\1/p' | head -1)
  dus "kapı diskteki koddan ESKİ çalışıyor (${dosya:-kod} süreçten yeni; pano SIGHUP'ı yeni uçları getirmez)"
fi
sunulan=$(baslik)
if [ "$sunulan" = "$disk" ]; then echo "kapı zaten güncel pano.js'i sunuyor (sha $disk)"; exit 0; fi
# Pano köprüsü KAPI_PANO=0 ile kapalıysa kapı 'kapali' der: tazelenecek şey yok (bağımsız göz tur 1 — eskiden disk sha'sını kovalar, boşuna --web-yenile'ye düşerdi)
if [ "$sunulan" = "kapali" ]; then echo "pano köprüsü bu kapıda KAPALI (KAPI_PANO=0) — tazelenecek şey yok"; exit 0; fi
pid=$(canli_pid); kayit=$(cat "$DURUM_DIZ/kapi.pid" 2>/dev/null | tr -dc '0-9')
[ -n "$pid" ] || dus "kapı süreci yok"
[ -n "$kayit" ] && [ "$kayit" = "$pid" ] || dus "kapı eski sürüm (kapi.pid ${kayit:-yok} ≠ canlı $pid; SIGHUP onu öldürürdü)"
[ $KURU = 1 ] && { echo "KURU: kapı $pid SIGHUP'la tazelenecek (sunulan ${sunulan:-?} → disk $disk)"; exit 0; }
kill -HUP "$pid" 2>/dev/null || dus "SIGHUP gönderilemedi (pid $pid)"
for i in $(seq 1 20); do
  sleep 0.25; sunulan=$(baslik)
  [ "$sunulan" = "$disk" ] && { gunluk "kapi-yenile: pano.js tazelendi (sha $disk, pid $pid, bağlantı kopmadı)"; echo "kapı pano.js tazelendi (sha $disk) — bağlantı kopmadı"; exit 0; }
  kill -0 "$pid" 2>/dev/null || dus "kapı SIGHUP sonrası öldü (pid $pid)"
done
dus "SIGHUP sonrası 5 sn'de sha dönmedi (sunulan ${sunulan:-?} ≠ disk $disk)"
