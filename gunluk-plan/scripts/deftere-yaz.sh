#!/usr/bin/env bash
# deftere-yaz.sh — günün planındaki açık maddeleri kutunun GÖREV DEFTERİNE yazar (Sultan 26 Eki: "kutular görev defterini kullanmıyor";
#   ölçüm: filo görev üretiminin %93'ü merkezde, 10+ kutu bir haftada deftere hiç yazmamış).
#
# Kaynak çıpadır (cipa.sh oku): '- [ ] madde' satırları. Yeni defter/havuz KURMAZ; yazım gorev.sh ekle ile, kutunun kendi jetonuyla.
#   VARSAYILAN KURU: neyi yazacağını basar. Yazmak için --uygula (mektup/yazım bir eylemdir).
#   İDEMPOTENT: aynı başlıkta açık bir görev zaten varsa yazılmaz (normalize eşleşme); ikinci koşu aynı sonucu verir.
#   Madde başına 200 karakter üstü kırpılmaz, REDDEDİLİR sayılır (uzun cümle başlık değil nottur) — sessiz kesme yok.
#
#   deftere-yaz.sh [--uygula] [--kutu K] [--kim AJAN] [--aciliyet cok-acil|acil|esnek|rahat]
#   rc: 0 tamam (kuru dahil) · 1 yazım hatası/kısmi · 2 kullanım · 3 ölçülemedi (çıpa ya da defter okunamadı — 'yazılacak bir şey yok' DENMEZ)
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CIPA="${GUNLUK_PLAN_CIPA_SH:-$KOK/cipa.sh}"
GOREV="$(bash "$(dirname "${BASH_SOURCE[0]}")/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"   # yol çözümü tek yerde (gorev-yolu.sh)
UYGULA=0; KUTU="${GUNLUK_PLAN_KUTU:-}"; KIM=""; ACIL="esnek"; ONAY=""
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --uygula) UYGULA=1; shift ;;
    --kutu) KUTU="${2:-}"; shift 2 ;;
    --kim) KIM="${2:-}"; shift 2 ;;
    --aciliyet) ACIL="${2:-}"; shift 2 ;;
    --onay) ONAY="${2:-}"; shift 2 ;;
    *) echo "tanınmayan argüman: $1" >&2; echo "kullanım: deftere-yaz.sh [--uygula] [--kutu K] [--kim AJAN] [--aciliyet cok-acil|acil|esnek|rahat]" >&2; exit 2 ;;
  esac
done
case "$ACIL" in cok-acil|acil|esnek|rahat) ;; *) echo "HATA: --aciliyet geçersiz: $ACIL" >&2; exit 2 ;; esac
[ -x "$GOREV" ] || [ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-}}"
[ -n "$KIM" ] || KIM="$(bash "$CIPA" ajan 2>/dev/null | python3 -c 'import sys; print(sys.stdin.read().strip().upper())')"   # çıpa kimliği dosya adı için KATLANMIŞTIR; İ/Â'lı adlar için --kim ver
[ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ajan kimliği çıkmadı (--kim ver)" >&2; exit 3; }
[ -z "$KIM" ] || KIM="$(bash "$KOK/kimlik-coz.sh" "$KIM")" || { echo "ÖLÇÜLEMEDİ: koltuk adı defter adına çevrilemedi (koltuk-esleme.tsv)" >&2; exit 3; }   # koltuk adı → defter adı (tablo)

CIPA_METNI="$(bash "$CIPA" oku 2>/dev/null)" || { echo "ÖLÇÜLEMEDİ: çıpa okunamadı — önce cipa.sh yaz" >&2; exit 3; }
LISTE="$(bash "$GOREV" liste 2>/dev/null)"; LRC=$?
[ "$LRC" -eq 0 ] && [ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı (rc=$LRC) — 'yazılacak bir şey yok' DENMEZ" >&2; exit 3; }

# kutu: açık ayar > kutu-bul.sh (koltuğa ATANMIŞ işlerin kutusu). Eski "listedeki en sık kutu" kaldırıldı: liste kutuya özel değil, menzilde hep "code" çıktı (1.11.0)
if [ -z "$KUTU" ]; then
  KUTU="$(printf '%s\n' "$LISTE" | bash "$KOK/kutu-bul.sh" --kim "$KIM" --liste /dev/stdin 2>/dev/null)" || KUTU=""
fi
[ -n "$KUTU" ] || { echo "ÖLÇÜLEMEDİ: kutu adı çıkmadı (--kutu ver)" >&2; exit 3; }

_norm() { python3 -c 'import sys,re,unicodedata
t=unicodedata.normalize("NFKC",sys.argv[1]).replace("İ","i").replace("I","ı").lower()
print(re.sub(r"\s+"," ",re.sub(r"[^\w\s]","",t)).strip())' "$1"; }

# engelleyen başlıklar: açıklar (onay-bekleyen dahil) + BUGÜN kapananlar: liste satırı = id kutu durum aciliyet etiket atanan BAŞLIK  (son: …)
ACIK="$(printf '%s\n' "$LISTE" | python3 -c '
import sys,re
bugun=sys.argv[1]
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_"): continue
    m=re.search(r"\(son: (\d{4}-\d{2}-\d{2})",p[6]); son=m.group(1) if m else ""
    # kapanmış görev yalnız BUGÜN kapandıysa aynı başlığı engeller (aynı gün aynı madde ikinci kez yazılmaz); eski kapanış yeni gün için yeniden açılabilir
    # onay-bekliyor AÇIK sayılır: biten iş Sultan onayını beklerken aynı başlıkla ikinci kez açılmaz
    if p[2] in ("iptal","bitti","tamam") and son!=bugun: continue
    print(re.sub(r"\s+\(son:.*$","",p[6]))
' "$BUGUN")"
ACIK_N=""; while IFS= read -r b; do [ -n "$b" ] && ACIK_N+="$(_norm "$b")"$'\n'; done <<<"$ACIK"

# PLAN İMZASI: açık maddelerin (sıra numarasız, sırayla) sha256 ilk 8 hanesi. Kuru koşu basar; onay referansı BU imzayı ve BUGÜNÜN tarihini taşımak zorundadır —
#   böylece onay yalnız gösterilen plana ve o güne bağlanır; çıpa sonradan değişirse onay düşer.
PLAN_IMZA="$(printf '%s\n' "$CIPA_METNI" | sed -n 's/^- \[ \][[:space:]]*//p' | sed 's/^[0-9]\{1,2\}[).][[:space:]]*//' | sha256sum | cut -c1-8)"
# ONAY KAPISI (A06/D1): --uygula, Sultan'ın BU planı BUGÜN onayladığının GÖRÜLDÜĞÜ referansı ister (ajan onay ÜRETMEZ, gördüğünü aktarır). Biçim:
#   YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<≥3 karakter verbatim kırpık>" · beyan:<AJAN> · plan:<imza>)  — tarih bugün, imza mevcut plan olmalı.
if [ "$UYGULA" -eq 1 ]; then
  if ! printf '%s' "$ONAY" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} Sultan: .+ \(sohbet · [^·]+ · "[^"]{3,}" · beyan:[^·)]+ · plan:[0-9a-f]{8}\)$'; then
    echo "REDDEDİLDİ: --uygula için Sultan'ın plan onayı referansı şart (--onay '<YYYY-MM-DD Sultan: onay (sohbet · <oturum-ref> · \"<verbatim kırpık>\" · beyan:AJAN · plan:$PLAN_IMZA)>'). Onaysız plan deftere yazılmaz; kuru koşu onaysız çalışır." >&2
    exit 2
  fi
  _alinti="$(printf '%s' "$ONAY" | sed -n 's/^.* · "\([^"]*\)" · beyan:.*$/\1/p')"
  [ "$(printf '%s' "$_alinti" | wc -w | tr -d ' ')" -le 15 ] || { echo "REDDEDİLDİ: onay alıntısı 15 kelimeyi aşıyor (verbatim KIRPIK istenir)" >&2; exit 2; }
  [ "${ONAY%% *}" = "$BUGUN" ] || { echo "REDDEDİLDİ: onay tarihi bugün ($BUGUN) değil: ${ONAY%% *}" >&2; exit 2; }
  case "$ONAY" in *"plan:$PLAN_IMZA)") ;; *) echo "REDDEDİLDİ: onay bu plana ait değil (şimdiki plan imzası: $PLAN_IMZA) — plan onaydan sonra değişmiş olabilir" >&2; exit 2 ;; esac
fi

yazilan=0; atlanan=0; reddedilen=0; hata=0; say=0
while IFS= read -r sat; do
  m="$(printf '%s' "$sat" | sed -n 's/^- \[ \][[:space:]]*//p' | sed 's/^[0-9]\{1,2\}[).][[:space:]]*//')"   # "1) madde" sıra numarası başlığa girmez
  [ -n "$m" ] || continue
  say=$((say+1))
  if [ "${#m}" -gt 200 ]; then echo "  ✗ reddedildi (200 karakter üstü, başlık değil not): ${m:0:60}…"; reddedilen=$((reddedilen+1)); continue; fi
  n="$(_norm "$m")"
  if printf '%s' "$ACIK_N" | grep -qxF -- "$n"; then echo "  = atlandı (defterde açık): $m"; atlanan=$((atlanan+1)); continue; fi
  if [ "$UYGULA" -eq 1 ]; then
    # --ozet ZORUNLU: geçit Sultan-dili açılış özeti ister (400 ozet_acilista_gerekli); eskiden verilmiyordu, üç madde sessizce yazılamadı (mihenk/s08, 27 Eki)
    OZET="${KIM} günlük planında bugün yapılacak diye yazdı → henüz başlanmadı → yapılınca bu iş defterde kapanır: ${m}"
    if CIKTI="$(bash "$GOREV" ekle "$m" --kutu "$KUTU" --etiket ozellik --aciliyet "$ACIL" --atanan "$KIM" --kaynak-kim "$KIM" --kaynak-nereden "günlük plan" --ozet "$OZET" 2>&1)"; then
      echo "  ✓ yazıldı: $m"; yazilan=$((yazilan+1)); ACIK_N+="$n"$'\n'
    else echo "  ✗ YAZILAMADI: $m"; echo "      sebep: $(printf '%s' "$CIKTI" | tr '\n' ' ' | cut -c1-300)"; hata=$((hata+1)); fi
  else
    echo "  ◻ yazardım: $m"; yazilan=$((yazilan+1))
  fi
done <<<"$CIPA_METNI"

[ "$say" -gt 0 ] || { echo "çıpada açık madde yok (— ya hepsi kapandı ya çıpa boş)"; exit 0; }
printf 'kutu=%s kim=%s %s: yazılan=%d atlanan=%d reddedilen=%d hata=%d plan-imzası=%s\n' "$KUTU" "$KIM" "$([ "$UYGULA" -eq 1 ] && echo uygula || echo kuru)" "$yazilan" "$atlanan" "$reddedilen" "$hata" "$PLAN_IMZA"
[ "$hata" -eq 0 ] && [ "$reddedilen" -eq 0 ] || exit 1
exit 0
