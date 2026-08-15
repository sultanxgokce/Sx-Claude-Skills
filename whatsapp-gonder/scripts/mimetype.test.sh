#!/usr/bin/env bash
# mimetype.test.sh — gönderilen gövde dosyanın TÜRÜNÜ bildiriyor mu?
#
# NİÇİN VAR (canlı vaka 2026-08-15, 13+ kutu): gövdede `mimetype` yoktu. Geçidin altındaki
# kütüphane tür bildirilmeyince kendi varsayılanını koyuyor ve o varsayılan
# "application/pdf". Dosya adı `foto.png` kalsa bile TÜR "pdf" dediği için WhatsApp ve macOS
# türe inanıp dosyayı yeniden adlandırıyordu → PNG karşıya PDF olarak düşüyor, AÇILMIYOR.
# Kullanıcı uzantıyı elle .png yapınca açılıyordu.
#
# Yöntem: gerçek geçit çağrılmaz. PATH'e sahte bir `curl` konur; gönderilen gövde dosyasını
# kaydeder ve 200 basar. Sonra gövdenin İÇİNE bakılır — "200 aldım" kanıt sayılmaz.
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$BURASI/wa-gonder.sh"
gecici="$(mktemp -d -t wamime-XXXXXX)"
temizle() { [ -d "$gecici" ] && find "$gecici" -mindepth 1 -delete 2>/dev/null; rmdir "$gecici" 2>/dev/null; }
trap temizle EXIT
gecen=0; kalan=0
g() { if [ "$1" = 0 ]; then echo "  ✓ $2"; gecen=$((gecen+1)); else echo "  ✗ $2"; kalan=$((kalan+1)); fi; }

command -v python3 >/dev/null || { echo "❌ python3 YOK — bu sınama sessizce atlanamaz."; exit 1; }

mkdir -p "$gecici/bin"
# Sahte curl: -d @dosya ile verilen gövdeyi olduğu gibi saklar, 200 basar.
cat > "$gecici/bin/curl" <<'C'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in @*) cp "${a#@}" "$GOVDE_KOPYA" 2>/dev/null ;; esac; done
printf '200'
C
chmod +x "$gecici/bin/curl"
export PATH="$gecici/bin:$PATH"
export GOVDE_KOPYA="$gecici/govde.json"
export WA_JETON="sahte-jeton"

# Gövdeden bir alanı oku (yoksa boş basar).
alan() { python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2],""))
except Exception: print("")' "$GOVDE_KOPYA" "$1"; }

kos() { rm -f "$GOVDE_KOPYA"; bash "$S" "$@" >/dev/null 2>&1; }

echo "── D: dosya gönderiminde tür bildirimi"
printf 'sahte-png' > "$gecici/foto.png"
kos --dosya "$gecici/foto.png"
[ "$(alan mimetype)" = "image/png" ]; g $? "D1 png → mimetype=image/png"
[ "$(alan tur)" = "dosya" ];          g $? "D2 varsayılan tür 'dosya' DEĞİŞMEDİ (geriye uyum)"
[ "$(alan dosya_adi)" = "foto.png" ]; g $? "D3 dosya adı korunuyor"
[ -n "$(alan icerik_b64)" ];          g $? "D4 içerik hâlâ gövdede taşınıyor"

printf 'sahte-pdf' > "$gecici/rapor.pdf"
kos --dosya "$gecici/rapor.pdf"
[ "$(alan mimetype)" = "application/pdf" ]; g $? "D5 pdf → application/pdf"

printf 'x' > "$gecici/foto.jpg"
kos --dosya "$gecici/foto.jpg"
[ "$(alan mimetype)" = "image/jpeg" ]; g $? "D6 jpg → image/jpeg"

echo "── B: tahmin edilemeyen uzantı ASLA pdf demez"
printf 'x' > "$gecici/dosya.zzz"
kos --dosya "$gecici/dosya.zzz"
[ "$(alan mimetype)" != "application/pdf" ]; g $? "B1 bilinmeyen uzantı pdf DEMİYOR"
# Alan hiç konulmazsa geçit kendi türetimini yapar (octet-stream) — o da doğru davranış.
m="$(alan mimetype)"
[ -z "$m" ] || [ "$m" = "application/octet-stream" ]; g $? "B2 alan ya yok ya da octet-stream"

echo "── G: --gorsel bayrağı"
kos --dosya "$gecici/foto.png" --gorsel
[ "$(alan tur)" = "gorsel" ];         g $? "G1 --gorsel → tur=gorsel"
[ "$(alan mimetype)" = "image/png" ]; g $? "G2 --gorsel türü de bildiriyor"
[ "$(alan dosya_adi)" = "foto.png" ]; g $? "G3 --gorsel dosya adını taşıyor"
bash "$S" --gorsel "merhaba" >/dev/null 2>&1
[ "$?" = 2 ];                         g $? "G4 --gorsel dosyasız kullanım REDDEDİLİR (rc=2)"

echo "── E: eski çağrı biçimleri kırılmadı"
kos "merhaba"
[ "$(alan tur)" = "metin" ] && [ "$(alan metin)" = "merhaba" ]
g $? "E1 düz metin aynen çalışıyor"
kos --kime "SaaS" --dosya "$gecici/rapor.pdf" --not "aylık"
[ "$(alan alici)" = "SaaS" ] && [ "$(alan aciklama)" = "aylık" ]
g $? "E2 --kime + --not aynen çalışıyor"
bash "$S" "bir" "iki" >/dev/null 2>&1; [ "$?" = 2 ]
g $? "E3 çift konumsal argüman hâlâ reddediliyor"

echo ""
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
