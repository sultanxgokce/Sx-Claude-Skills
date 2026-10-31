#!/usr/bin/env bash
# postaci-kutu.sh — POSTANE postacısının BU KUTUDAKİ kurulumu (cron + açma bayrağı). KURU varsayılan.
#
#   bash postaci-kutu.sh                 KURU: ön kontroller + dar yetki ölçümü + kuru tur; hiçbir şey kurmaz/yazmaz
#   bash postaci-kutu.sh --uygula        ön kontrol YEŞİL ve jeton DAR ise cron satırını yükler (+ kalıcı kopya) ve açma bayrağını yazar
#   bash postaci-kutu.sh --kapat         açma bayrağını siler → cron satırı anında no-op
#
# Kaynak: cloudtop infra/postane (postaci.mjs · postane.mjs · ajan-adlari.mjs · ulid.mjs birebir kopya; KAYNAK.sha256). Değişiklik oradan yapılır, buraya taşınır.
# Sınır (KODLA): kutu izinli listeden (18 ekip kutusu) biri olmalı VE kutu jetonu BAŞKA kutunun ajan kuyruğunu okuyamamalı (SERDAR kuyruğu 403).
#   Jeton genişse (200) --uygula REDDEDİLİR: izin dosyasında bu kutunun jetonuna ajanlar:[kendi ajanları] verilmeden postacı kurulmaz.
# Sır değeri basmaz (jeton yalnız dosya adıyla anılır). Test kancaları (yalnız ortam): POSTACI_JETON · OTURUM_DIZIN · POSTANE_URL · NODE · BAYRAK · CRONTAB_KOMUT · KALICI_CRON · FLOCK_DOSYA
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS="$HERE/postaci.mjs"
BAYRAK="${BAYRAK:-/config/.postaci-acik}"
JETON="${POSTACI_JETON:-/config/defter-jeton}"
OTURUM_DIZIN="${OTURUM_DIZIN:-/config/.claude/sessions}"
POSTANE_URL="${POSTANE_URL:-http://cloudtop-postane:8797}"
export POSTACI_JETON="$JETON" OTURUM_DIZIN POSTANE_URL
# node yolu GÖMÜLMEZ, ölçülür: ortamdaki node (>= 22.13) → yoksa nvm'deki en yeni sürüm. Cron satırına mutlak yol yazılır (cron PATH'i dardır).
nodeBul() {
  local a c
  for c in "$(command -v node 2>/dev/null)" $(ls -d "${NVM_DIZIN:-/config/.nvm/versions/node}"/v*/bin/node 2>/dev/null | sort -V -r); do
    [ -n "$c" ] && [ -x "$c" ] && "$c" -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=13)?0:1)' 2>/dev/null && { echo "$c"; return 0; }
  done
  return 1
}
NODE="${NODE:-$(nodeBul || echo node)}"
NODE_MUTLAK="$(command -v "$NODE" 2>/dev/null || echo "$NODE")"
CRONTAB="${CRONTAB_KOMUT:-crontab}"
KALICI="${KALICI_CRON:-/config/crontabs/abc}"
LOCK="${FLOCK_DOSYA:-/config/.filo/postaci.lock}"
IZINLI_KUTULAR="akar code enis huma huzur maiset medigate menzil mihenk mmex munavebe nazir nova revak sedir tellal tez vekatip"   # sabit; kutu eklemek = bu satırı değiştiren ayrı, sınıflı PR
PILOT_KUTU="code"   # tek istisna: pilot kutunun jetonu merkez yetkilidir (izin dosyasında merkez:true)
OLCUM_AJANI="SERDAR"   # merkez ajanı: hiçbir ekip kutusunun kuyruğu değil; dar jeton bunu OKUYAMAZ
SATIR_ISARET="# POSTANE postacısı (Sx postane-postaci)"
MOD=kuru
case "${1:-}" in --uygula) MOD=uygula ;; --kapat) MOD=kapat ;; "") ;; *) echo "kullanım: postaci-kutu.sh [--uygula|--kapat]" >&2; exit 2 ;; esac

if [ "$MOD" = kapat ]; then
  rm -f "$BAYRAK" && echo "✓ postacı KAPATILDI (bayrak silindi: $BAYRAK) — cron satırı bir sonraki dakikadan itibaren no-op"
  exit 0
fi

hata=0
adim() { local ad="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  ✓ $ad"; else echo "  ✗ $ad"; hata=1; fi; }
echo "── postacı ön kontrol ($MOD) ──"
adim "node >= 22.13 (node:sqlite)" "$NODE" -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=13)?0:1)'
adim "postaci.mjs var" test -f "$JS"
adim "flock var" command -v flock
adim "crontab komutu var" command -v "$CRONTAB"
adim "defter jetonu okunur ($JETON)" test -r "$JETON"
adim "postane sağlıklı ($POSTANE_URL/saglik)" "$NODE" -e 'fetch(process.env.POSTANE_URL+"/saglik").then(r=>process.exit(r.status===200?0:1)).catch(()=>process.exit(1))'
KUTU_ADI="$(JETON_DOSYA="$JETON" "$NODE" -e 'const fs=require("fs");fetch(process.env.POSTANE_URL+"/ben",{headers:{"x-defter-jeton":fs.readFileSync(process.env.JETON_DOSYA,"utf8").trim()}}).then(r=>r.json()).then(j=>console.log(j.kutu||"")).catch(()=>console.log(""))' 2>/dev/null)"
if [ -n "$KUTU_ADI" ] && [[ " $IZINLI_KUTULAR " == *" $KUTU_ADI "* ]]; then echo "  ✓ izinli kutu (jeton kutusu = $KUTU_ADI)"; else echo "  ✗ izinli kutu DEĞİL (jeton kutusu: '${KUTU_ADI:-bilinmiyor}')"; hata=1; fi
# DAR YETKİ ölçümü: jeton merkez ajanının kuyruğunu okuyabiliyor mu
DAR="$(JETON_DOSYA="$JETON" OLC="$OLCUM_AJANI" "$NODE" -e 'const fs=require("fs");fetch(process.env.POSTANE_URL+"/kutu/"+encodeURIComponent(process.env.OLC)+"?durum=gonderildi",{headers:{"x-defter-jeton":fs.readFileSync(process.env.JETON_DOSYA,"utf8").trim()}}).then(r=>console.log(r.status)).catch(()=>console.log("yok"))' 2>/dev/null)"
case "$DAR" in
  403) echo "  ✓ dar yetki ($OLCUM_AJANI kuyruğu 403)" ;;
  200) if [ "$KUTU_ADI" = "$PILOT_KUTU" ]; then echo "  ✓ pilot kutu ($PILOT_KUTU): jeton bilerek merkez yetkili — dar yetki şartı bu kutuya uygulanmaz"; else echo "  ✗ jeton GENİŞ ($OLCUM_AJANI kuyruğu 200) — izin dosyasında bu kutunun jetonuna ajanlar:[kendi ajanları] verilmeli"; hata=1; fi ;;
  *)   echo "  ✗ dar yetki ÖLÇÜLEMEDİ ($OLCUM_AJANI kuyruğu: ${DAR:-boş}) — ölçülemeyen yeşil sayılmaz"; hata=1 ;;
esac
adim "oturum kayıt dizini okunur ($OTURUM_DIZIN)" test -r "$OTURUM_DIZIN"
KURU_CIKTI="$("$NODE" --disable-warning=ExperimentalWarning "$JS" --kuru 2>&1)"; KURU_RC=$?
if [ "$KURU_RC" -eq 0 ]; then echo "  ✓ kuru tur (eşleşme + bekleyen, hiçbir şey iletilmedi)"; else echo "  ✗ kuru tur (rc=$KURU_RC)"; hata=1; fi
printf '%s\n' "$KURU_CIKTI" | sed 's/^/      /'

if [ "$hata" -ne 0 ]; then echo "✗ ön kontrol KIRMIZI — kurulum yapılmadı"; exit 1; fi
SATIR="* * * * * sleep 12 && [ -f $BAYRAK ] && mkdir -p /config/.filo && flock -n $LOCK $NODE_MUTLAK --disable-warning=ExperimentalWarning $JS >> /config/.filo/postaci-cron.log 2>&1 || true"
if [ "$MOD" = kuru ]; then
  echo "KURU: ön kontroller yeşil. --uygula şunu yapar: crontab'a tek satır ekler (idempotent; $SATIR_ISARET) + kalıcı kopyayı ($KALICI) günceller + bayrak yazar ($BAYRAK). Şu an HİÇBİR ŞEY değişmedi."
  exit 0
fi
# --uygula: mevcut crontab + (işaretli eski blok varsa çıkar) + yeni blok; geri okuyup doğrula
MEVCUT="$($CRONTAB -l 2>/dev/null || true)"
YENI="$(printf '%s\n' "$MEVCUT" | awk -v i="$SATIR_ISARET" '$0==i{atla=2} atla>0{atla--; next} {print}')"
YENI="$(printf '%s\n%s\n%s\n' "$YENI" "$SATIR_ISARET" "$SATIR" | sed '/./,$!d')"
geri_al() {   # bayrak ÖNCE silinir (cron satırı no-op olur); sonra eski crontab geri yüklenir ve GERİ OKUNARAK doğrulanır
  rm -f "$BAYRAK"
  local beklenen; beklenen="$(printf '%s\n' "$MEVCUT" | grep -cF "$JS")"
  if printf '%s\n' "$MEVCUT" | $CRONTAB - 2>/dev/null && [ "$($CRONTAB -l 2>/dev/null | grep -cF "$JS")" -eq "$beklenen" ]; then echo "  ↩ önceki crontab geri yüklendi ve doğrulandı (kısmi kurulum bırakılmadı)"
  else echo "  ✗ GERİ ALMA BAŞARISIZ — cron satırı crontab'ta kalmış olabilir; bayrak silindi (satır no-op); elle: crontab -e ($JS satırını sil)"; fi
}
printf '%s\n' "$YENI" | $CRONTAB - || { echo "✗ crontab yüklenemedi — bayrak YAZILMADI"; exit 1; }
if [ "$($CRONTAB -l 2>/dev/null | grep -cF "$JS")" -ne 1 ]; then geri_al; echo "✗ crontab geri okumada satır bir kez bulunamadı — bayrak YAZILMADI"; exit 1; fi
mkdir -p "$(dirname "$KALICI")" && printf '%s\n' "$YENI" > "$KALICI" || { geri_al; echo "✗ kalıcı kopya yazılamadı ($KALICI) — bayrak YAZILMADI"; exit 1; }
: > "$BAYRAK" && echo "✓ postacı AÇIK (bayrak: $BAYRAK) · günlük: /config/.filo/postaci-cron.log · durdurmak: bash $0 --kapat"
