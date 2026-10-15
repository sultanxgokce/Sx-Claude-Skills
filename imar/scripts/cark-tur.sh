#!/usr/bin/env bash
# cark-tur.sh — ÇARK'ın zamanlayıcı ucu. Her yuvada koşar, GÜN EMRİNE bakar, kotayı aşmaz.
#
# NİÇİN BÖYLE: Sultan "günde 3 tur ama gün başında ayarlanabilsin" dedi. Cron'u her gün elle
# düzenlemek yerine cron SABİT üç yuvada koşar; kaç tur dönüleceğini gun-emri.json söyler.
# "tur: 1" ise yalnız ilk yuva çalışır, ötekiler kotayı dolu bulup çıkar.
#
# Kullanım: bash scripts/cark-tur.sh [--kuru]
# Çıkış: 0 tur koştu ya da kota dolu (ikisi de normal) · 3 ÖLÇÜLEMEDİ · 1 tur düştü
set -uo pipefail

# ——— 🔴 CRON DAR ORTAMDA KOŞAR (ölçüldü 3 Ekim): ilk otomatik yuva ateşledi ama tur
# "claude komutu yok" diye düştü — cron'un varsayılan PATH'i nvm'in kurduğu yeri görmüyor.
# "Zamanlayıcı ateşledi" ile "iş bitti" ayrı şeylerdir; aradaki fark bu satırdı.
for _d in "$HOME"/.nvm/versions/node/*/bin; do
  [ -x "$_d/claude" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH";; esac
done
export PATH

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMIR="$REPO/_agents/spec/agentic-sistem/gun-emri.json"
SAYAC_DIZIN="/tmp/cark-sayac"; mkdir -p "$SAYAC_DIZIN"
BUGUN="$(date +%F)"; SAYAC="$SAYAC_DIZIN/$BUGUN"
LOG="$REPO/hafiza/cark-kosu.log"
KURU=0; ALARM_SINAVI=0
case "${1:-}" in
  --kuru) KURU=1;;
  --alarm-sinavi) ALARM_SINAVI=1;;   # alarmı tur düşürmeden sına (iddia ≠ ölçüm)
esac

# --kuru: gerçek kütüğe YAZMAZ (ölçüldü 9 Ekim: sınav koşuları "yuva atlandı" satırı düşürüp karneyi kirletti)
_log(){ [ "$KURU" = "1" ] && { printf '[kuru] %s\n' "$*" >&2; return 0; }; printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG"; }
_bildir(){ # sessiz ölüm panzehiri — ve 🔴 PANZEHİRİN KENDİSİ SESSİZCE ÖLÜYDÜ (ölçüldü 3 Ekim):
  # doğrudan gönderim 403 döndü; ntfy yayın JETONU istiyor, bu kutuda jeton YOK
  # (vault: "secret/ntfy/PUBLISH_TOKEN yok"). Eskiden hata "|| true" ile yutuluyordu — yani
  # alarm hiç gitmiyordu ve kimse bilmiyordu. Artık: jeton varsa gönderilir, YOKSA kütüğe
  # DÜRÜST satır yazılır. Alarmın gitmediğini de bir yere yazmak zorundayız.
  # 🔴 TEŞHİS DÜZELDİ (MUAVİN ölçtü, 8 Ekim akşamı): 403'ün sebebi jeton DEĞİL, yanlış ADRESTİ.
  # ~/.claude/ntfy-topic'teki üretilmiş konu adı sunucunun izin tablosunda hiç yok; sunucu tanımadığı
  # her konuya 403 veriyor (pozitif kontrol: uydurma konu da 403). Filo düzeni: her kutunun KENDİ ADIYLA
  # bir konusu var, kimliksiz yazılabiliyor ve Sultan hepsine abone. Jeton, kasa, kullanıcı GEREKMİYOR.
  # Kabul ölçütü de düzeldi: "200 döndü" yetmez — "Sultan'ın cihazına düştü" gerekir (kimsenin abone
  # olmadığı bir konuya 200 almak yeşil görünen arızadır).
  # 🔴 KANAL DEĞİŞTİ (Sultan, 9 Ekim): ntfy 200 dönüyordu ama iki sınav da Sultan'ın cihazına düşmedi
  # ("neden ntfy kullanıyorsun"). Sultan WhatsApp'ı seçti — zaten baktığı yer. Birincil kanal: filo
  # WhatsApp geçidi (whatsapp-gonder; numara kutuda durmaz, alıcı adı gider). ntfy ikincil olarak
  # yine yazılır (kütük izi), ama "gönderildi" yalnız WhatsApp geçidi kabul edince denir.
  local konu kod wa wrc
  # 🔴 PROFİLE BAĞLANDI (gözün tur-1 bulgusu): küresel yol varsayılan KALIR ama profil onu
  #    ezebilir; kuruluş yeri kutudan kutuya değişiyorsa alarm sessizce gitmez olurdu.
  wa="${IMAR_WA_GONDER:-/config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh}"
  if [ -x "$wa" ] || [ -r "$wa" ]; then
    bash "$wa" --kime Sultan "$1" >/dev/null 2>&1; wrc=$?
    case "$wrc" in
      0) _log "alarm gönderildi (WhatsApp geçidi kabul etti) — ulaştığının kanıtı Sultan'ın cihazıdır";;
      3) _log "🔴 ALARM GİTMEDİ: WhatsApp geçidine ulaşılamadı (rc=3)";;
      4) _log "🔴 ALARM GİTMEDİ: WhatsApp geçidi reddetti (rc=4)";;
      *) _log "🔴 ALARM GİTMEDİ: WhatsApp rc=$wrc";;
    esac
  else
    _log "🔴 ALARM GİTMEDİ: whatsapp-gonder betiği yok ($wa)"
  fi
  # ikincil: ntfy (kütük izi; Sultan abone değil, cihaza düşmez — 8 Ekim ölçümü)
  konu="${NTFY_KONU:-$(basename "$REPO")}"
  kod="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
    -H "Title: ${IMAR_KUTU:-?} ÇARK" -d "$1" "${NTFY_TABAN:-http://cloudtop-ntfy:80}/$konu" 2>/dev/null)"
  _log "ikincil ntfy: http ${kod:-cevapsız} (konu=$konu; cihaz teyidi yok)"
}

if [ "$ALARM_SINAVI" = "1" ]; then
  _bildir "🧪 ${IMAR_KUTU:-?}: ÇARK alarm sınavı — tur düşmedi, yalnız bildirim yolu ölçülüyor."
  echo "alarm sınavı koştu — sonucu kütükte: $LOG"; tail -1 "$LOG"; exit 0
fi

# ——— ⛩️ İMAR ŞALTERİ (M13 · Sultan 5 Ekim): "kapalıyken hiçbir şey kendiliğinden koşmasın."
# Gün emrinden ÖNCE bakılır: kapalıysa kota, emir, hiçbir şey okunmaz; yuva atlanır ve bu
# kütüğe düşer. Şalter yok/bozuksa da KAPALI sayılır (fail-closed) — belirsizlikte koşmayız.
IMAR_HUKUM="$(bash "$REPO/scripts/imar.sh" acik-mi 2>&1)"; IMAR_RC=$?
if [ "$IMAR_RC" -ne 0 ]; then
  echo "⛩️ İMAR kapalı — bu yuva atlandı ($IMAR_HUKUM)"
  _log "yuva atlandı: ⛩️ İMAR kapalı (rc=$IMAR_RC · $IMAR_HUKUM)"
  exit 0
fi

[ -r "$EMIR" ] || { echo "ÖLÇÜLEMEDİ: gün emri yok ($EMIR)" >&2; _log "ÖLÇÜLEMEDİ: gün emri yok"; exit 3; }
KOTA="$(python3 -c "import json,sys;print(json.load(open('$EMIR')).get('tur',0))" 2>/dev/null)" || KOTA=""
[ -n "$KOTA" ] || { echo "ÖLÇÜLEMEDİ: gün emri okunamadı" >&2; _log "ÖLÇÜLEMEDİ: emir bozuk"; exit 3; }

KOSAN="$(cat "$SAYAC" 2>/dev/null || echo 0)"
if [ "$KOSAN" -ge "$KOTA" ]; then
  echo "kota dolu: bugün $KOSAN/$KOTA tur koştu — bu yuva atlandı"
  _log "yuva atlandı (kota $KOSAN/$KOTA)"
  exit 0
fi

if [ "$KURU" = "1" ]; then
  echo "KURU: kota $KOSAN/$KOTA · bu yuva KOŞARDI · emir: $EMIR"; exit 0
fi

# kaynak=cron|el — karne "insansız mı" sorusunu buradan okur. Ortamdan TAHMİN edilmez (TERM bash tarafından kurulabiliyor, ölçüldü); cron satırı değişkeni açıkça verir.
KAYNAK="${CARK_KAYNAK:-el}"   # cron satırı CARK_KAYNAK=cron verir; başka her çağrı "el"
_log "tur başlıyor ($((KOSAN+1))/$KOTA) kaynak=$KAYNAK"
bash "$REPO/scripts/muneccim-kos.sh" >> "$LOG" 2>&1; RC=$?
if [ "$RC" -eq 0 ]; then
  echo $((KOSAN+1)) > "$SAYAC"
  _log "tur bitti ($((KOSAN+1))/$KOTA) kaynak=$KAYNAK"
  echo "✅ tur koştu ($((KOSAN+1))/$KOTA)"
  # ——— M9: bağımsız ikinci göz — üretenin dersini ayrı süreç/ayrı model çürütmeye çalışır.
  # Hüküm yeşil üretmez; göz koşamazsa ÖLÇÜLEMEDİ yazılır, ayakta sayılmaz.
  TUR_DOSYA="$(ls -1t "${IMAR_SERI:?IMAR_SERI yok — profil çözülmedi}/gunluk/"*-tur.md 2>/dev/null | head -1)"
  if [ -n "$TUR_DOSYA" ] && [ -x "$REPO/scripts/imar-ikinci-goz.sh" ]; then
    GOZ_CIKTI="$(bash "$REPO/scripts/imar-ikinci-goz.sh" "$TUR_DOSYA" 2>&1)"; GRC=$?
    # kütük satır-başına okunur (karne): çok satırlı çıktı (ör. Python hata izi) kütüğü KİRLETMEZ —
    # tam çıktı yan dosyaya, kütüğe yalnız son anlamlı satır (ölçüldü 10-11 Ekim: iki hata izi düştü)
    printf '%s\n' "$GOZ_CIKTI" > "$(dirname "$TUR_DOSYA")/../goz/$(basename "$TUR_DOSYA" .md).goz.log" 2>/dev/null
    GOZ_CIKTI="$(printf '%s\n' "$GOZ_CIKTI" | grep -v '^[[:space:]]*$' | tail -1 | cut -c1-400)"
    case "$GRC" in
      0) _log "ikinci göz: ayakta — $GOZ_CIKTI";;
      1) _log "ikinci göz: 🔴 ÇÜRÜYEN DERS VAR — $GOZ_CIKTI";;
      *) _log "ikinci göz: ÖLÇÜLEMEDİ (rc=$GRC) — $GOZ_CIKTI";;
    esac
  else
    _log "ikinci göz: ÖLÇÜLEMEDİ — tur dosyası ya da göz betiği yok"
  fi
elif [ "$RC" -eq 4 ]; then
  _log "kilit meşgul — tur atlandı"; echo "kilit meşgul, atlandı"
elif [ "$RC" -eq 5 ]; then
  # konu kapalı (8 Ekim): arıza değil bekleme — sayaç artmaz, alarm çalmaz, karne "atlandı" sayar
  _log "yuva atlandı (konu kapalı — yeni konu bekleniyor)"; echo "konu kapalı, atlandı"
else
  _log "TUR DÜŞTÜ rc=$RC"
  _bildir "🛞 ${IMAR_KUTU:-?}: ÇARK turu DÜŞTÜ (rc=$RC) — defter: hafiza/cark-kosu.log"
  echo "TUR DÜŞTÜ (rc=$RC)" >&2; exit 1
fi
