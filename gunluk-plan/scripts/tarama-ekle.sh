#!/usr/bin/env bash
# tarama-ekle.sh — kod tabanı + web + endüstri taramasından çıkan BİR işi, ölçülmüş kaynak ve kanıtla mevcut görev defterine ekler
#   (görev 0HC75A dilim (b); SERDAR 26 Eki: "havuza, günde ≤3").
#
# Yeni havuz/defter KURMAZ: yazım bulgu.sh yaz ile (türü özellik). Tarama kayıtları başlıkta "[tarama] " işaretini taşır; günlük tavan bu işaretten SAYILIR.
#   Ölçmeden iş yazılmaz (gunluk-plan değişmez 1): --kaynak (dosya:satır ya da https URL) ve --kanit (bu turda ölçülen, ≥ 20 karakter) ZORUNLU.
#   VARSAYILAN KURU: neyi yazacağını basar. Yazmak için --uygula.
#   İDEMPOTENT: aynı başlıkta (normalize) açık ya da bugün kapanmış görev varsa yazılmaz.
#   TAVAN: bir kutuda bugün en çok 3 tarama kaydı (GUNLUK_PLAN_TARAMA_TAVAN ile değişmez, yalnız sınavda düşürülür). Sayım ölçülemezse yazılmaz.
#
#   tarama-ekle.sh --baslik "<tek cümle, Sultan-dilinde>" --kaynak <dosya:satır|https://…> --kanit "<ölçüm>" [--uygula] [--kutu K] [--kim AJAN]
#   rc: 0 tamam (kuru dahil) · 1 yazım hatası · 2 kullanım/ret (eksik kaynak-kanıt, uzun başlık, tavan dolu, kopya) · 3 ölçülemedi
set -uo pipefail
GOREV="${GUNLUK_PLAN_GOREV_SH:-/config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh}"
BULGU="${GUNLUK_PLAN_BULGU_SH:-/config/.claude/skills/bulgu/scripts/bulgu.sh}"
TAVAN="${GUNLUK_PLAN_TARAMA_TAVAN:-3}"
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
UYGULA=0; BASLIK=""; KAYNAK=""; KANIT=""; KUTU="${GUNLUK_PLAN_KUTU:-}"; KIM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --uygula) UYGULA=1; shift ;;
    --baslik) BASLIK="${2:-}"; shift 2 ;;
    --kaynak) KAYNAK="${2:-}"; shift 2 ;;
    --kanit) KANIT="${2:-}"; shift 2 ;;
    --kutu) KUTU="${2:-}"; shift 2 ;;
    --kim) KIM="${2:-}"; shift 2 ;;
    *) echo "tanınmayan argüman: $1" >&2; echo "kullanım: tarama-ekle.sh --baslik \"…\" --kaynak <dosya:satır|https://…> --kanit \"…\" [--uygula] [--kutu K] [--kim AJAN]" >&2; exit 2 ;;
  esac
done
[ -n "$BASLIK" ] || { echo "REDDEDİLDİ: --baslik şart (tek cümle, Sultan-dilinde)" >&2; exit 2; }
[ "${#BASLIK}" -le 160 ] || { echo "REDDEDİLDİ: başlık 160 karakteri aşıyor (başlık değil nottur; ayrıntı --kanit'e)" >&2; exit 2; }
printf '%s' "$KAYNAK" | grep -Eq '^(https://[^ ]+|[^ :]+:[0-9]+)$' || { echo "REDDEDİLDİ: --kaynak 'dosya:satır' ya da https adresi olmalı (ölçmeden iş yazılmaz): '$KAYNAK'" >&2; exit 2; }
[ "${#KANIT}" -ge 20 ] || { echo "REDDEDİLDİ: --kanit en az 20 karakter, bu turda ölçülen şeyi söylemeli (ölçmeden iş yazılmaz)" >&2; exit 2; }
[ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-}}"
[ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ajan kimliği çıkmadı (--kim ver)" >&2; exit 3; }

LISTE="$(bash "$GOREV" liste 2>/dev/null)"; LRC=$?
[ "$LRC" -eq 0 ] && [ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı (rc=$LRC) — tavan sayılamadan yazılmaz" >&2; exit 3; }
if [ -z "$KUTU" ]; then
  KUTU="$(printf '%s\n' "$LISTE" | awk '$1 ~ /^gorev_/ {print $2}' | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}')"
fi
[ -n "$KUTU" ] || { echo "ÖLÇÜLEMEDİ: kutu adı çıkmadı (--kutu ver)" >&2; exit 3; }

# sayım: bu kutuda bugün hareketi olan "[tarama] " kayıtları + kopya denetimi (açık ya da bugün kapanan aynı başlık)
SONUC="$(printf '%s\n' "$LISTE" | python3 -I -c '
import sys,re,unicodedata
kutu,bugun,baslik=sys.argv[1],sys.argv[2],sys.argv[3]
def norm(t):
    t=unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","ı").lower()
    return re.sub(r"\s+"," ",re.sub(r"[^\w\s]","",t)).strip()
hedef=norm(baslik); say=0; kopya=0
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_") or p[1]!=kutu: continue
    m=re.search(r"\(son: (\d{4}-\d{2}-\d{2})",p[6]); son=m.group(1) if m else ""
    b=re.sub(r"\s+\(son:.*$","",p[6])
    if b.startswith("[tarama] ") and son==bugun: say+=1
    kapali=p[2] in ("iptal","bitti","tamam")
    if norm(re.sub(r"^\[tarama\]\s*","",b))==hedef and not (kapali and son!=bugun): kopya=1
print("%d %d"%(say,kopya))
' "$KUTU" "$BUGUN" "$BASLIK")"
[ -n "$SONUC" ] || { echo "ÖLÇÜLEMEDİ: tarama sayımı çıkmadı" >&2; exit 3; }
SAY="${SONUC% *}"; KOPYA="${SONUC#* }"
[ "$KOPYA" -eq 0 ] || { echo "  = atlandı (defterde açık ya da bugün kapanmış): $BASLIK"; exit 2; }
[ "$SAY" -lt "$TAVAN" ] || { echo "REDDEDİLDİ: bugün bu kutuda $SAY tarama kaydı var, günlük tavan $TAVAN — yarına" >&2; exit 2; }

if [ "$UYGULA" -eq 1 ]; then
  [ -f "$BULGU" ] || { echo "ÖLÇÜLEMEDİ: bulgu.sh yok ($BULGU)" >&2; exit 3; }
  if bash "$BULGU" yaz "[tarama] $BASLIK" --kim "$KIM" --etiket ozellik --not "kaynak: $KAYNAK · kanıt: $KANIT" >/dev/null 2>&1; then
    echo "  ✓ yazıldı: [tarama] $BASLIK  (bugün $((SAY+1))/$TAVAN)"
  else echo "  ✗ YAZILAMADI: $BASLIK" >&2; exit 1; fi
else
  echo "  ◻ yazardım: [tarama] $BASLIK  (bugün $((SAY+1))/$TAVAN) · kaynak: $KAYNAK"
  echo "(kuru koşu: deftere yazılmadı — yazmak için --uygula)"
fi
exit 0
