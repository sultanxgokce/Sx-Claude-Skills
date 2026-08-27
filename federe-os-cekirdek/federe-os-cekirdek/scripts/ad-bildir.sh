#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ad-bildir.sh — kutu kendi ÜYE ADLARINI merkeze bildirir (L64 · K3)
#
# NİÇİN VAR: Merkezdeki künye 9 kutuda `uyeler:` alanını doldurmuyor → o
#   kutulardaki ajanlar ad-tekilliği taramasının DIŞINDA. Ölçüldü: aynı ad üç
#   ayrı kutuda habersiz doğdu. Merkez bunu kendi başına çözemez: İ1 gereği
#   izole kutunun içine OTOMATİK OKUMA YOK. Çözüm çekme değil İTME yönünde.
#
# 🔴 İ1 SÖZLEŞMESİ — YALNIZ AD GİDER. Bu betik gövdeye SADECE üye adlarını
#   koyar. Rol · görev · session_id · token · cwd · inbox · dosya içeriği ·
#   log · sır: HİÇBİRİ. Kanon zaten "persona-adı meta'dır" diyor
#   (federe-birimler.yaml); bu betik o iznin fiilen taşınmasıdır, yeni bir
#   izin DEĞİL. Sultan onayı: K3, 2026-08-08.
#
# 🔴 KUTU KODUNU BETİK BEYAN ETMEZ. Hangi kutudan geldiğini sunucu token'dan
#   TÜRETİR (`cellIdFromBearer`). Yani bir kutu başka kutu adına ad bildiremez —
#   kimlik yapısal olarak korunur, betiğin dürüstlüğüne bağlı değildir.
#
# 🔴 SALT-OKUR: yerel ekip kaydını okur, hiçbir dosyaya yazmaz.
#
# KULLANIM:
#   ad-bildir.sh              # PROVA — ne göndereceğini basar, GÖNDERMEZ
#   ad-bildir.sh --gonder     # gerçekten gönderir (federe kanalı, hedef s01)
# ÇIKIŞ: 0 tamam · 2 ortam/girdi hatası · 3 prova (gönderilmedi)
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEDERE="${AD_BILDIR_FEDERE:-$HERE/federe.sh}"
KOK="${AD_BILDIR_KOK:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HEDEF="${AD_BILDIR_HEDEF:-s01}"

GONDER=0
for a in "$@"; do case "$a" in
  --gonder) GONDER=1 ;;
  *) echo "HATA: tanınmayan bayrak: $a  (geçerli: --gonder)" >&2; exit 2 ;;
esac; done

# ── ekip kaydını bul: kutular arasında iki yerleşim var, ikisi de meşru
ADAYLAR="
$KOK/_agents/ekip-os/ekip-registry.yaml
$KOK/_agents/handoff/ekip-registry.yaml
$KOK/_agents/handoff/aile-registry.yaml
"
KAYIT=""
for y in $ADAYLAR; do [ -f "$y" ] && { KAYIT="$y"; break; }; done
if [ -z "$KAYIT" ]; then
  echo "HATA: bu kutuda ekip kaydı bulunamadı." >&2
  echo "      Bakılan yerler:$ADAYLAR" >&2
  echo "      Kayıt yoksa bildirilecek ad da yoktur — uydurma YAPILMAZ." >&2
  exit 2
fi

# ── YALNIZ AD alanını çek. Başka hiçbir alan okunmaz; okunsa bile taşınmaz.
ADLAR="$(sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*id:[[:space:]]*"\{0,1\}\([A-Za-zÇĞİÖŞÜçğıöşü0-9_-]\{1,\}\)"\{0,1\}.*/\1/p' "$KAYIT" \
        | awk '!g[$0]++' | paste -sd, -)"

if [ -z "$ADLAR" ]; then
  echo "HATA: kayıtta ad bulunamadı: $KAYIT" >&2
  echo "      BOŞ bildirim gönderilmez — 'ölçemedim' ile 'kimse yok' aynı şey değildir." >&2
  exit 2
fi

# Kanal sınırı: not ≤500. Aşarsa KIRPMAYIZ — kırpılmış liste eksik listedir ve
# eksikliği görünmez kılar. Bölerek göndermek de sıralama garantisi ister.
# Dürüst davranış: reddet ve söyle.
UZUNLUK=${#ADLAR}
if [ "$UZUNLUK" -gt 480 ]; then
  echo "HATA: ad listesi çok uzun ($UZUNLUK karakter, sınır ~480)." >&2
  echo "      KIRPILMADI — kırpılmış liste, eksikliği gizlerdi. SERDAR'a bildir." >&2
  exit 2
fi

BASLIK="uye-adlari"
NOT="$ADLAR"

if [ "$GONDER" -eq 0 ]; then
  echo "🔎 PROVA — hiçbir şey gönderilmedi"
  echo "   kaynak kayıt : $KAYIT"
  echo "   hedef        : $HEDEF (merkez)"
  echo "   başlık       : $BASLIK"
  echo "   gövde (YALNIZ ADLAR): $NOT"
  echo ""
  echo "   Gövdede ad DIŞINDA hiçbir şey yok — rol/görev/oturum/yol/içerik taşınmaz (İ1)."
  echo "   Göndermek için: ad-bildir.sh --gonder"
  exit 3
fi

[ -x "$FEDERE" ] || [ -f "$FEDERE" ] || { echo "HATA: federe.sh yok: $FEDERE" >&2; exit 2; }
bash "$FEDERE" gonder "$HEDEF" "$BASLIK" "" "$NOT"
