#!/usr/bin/env bash
# deftere-yaz.sh — günün planındaki açık maddeleri kutunun GÖREV DEFTERİNE yazar (Sultan 26 Eki: "kutular görev defterini kullanmıyor";
#   ölçüm: filo görev üretiminin %93'ü merkezde, 10+ kutu bir haftada deftere hiç yazmamış).
#
# Kaynak çıpadır (cipa.sh oku): '- [ ] madde' satırları. Yeni defter/havuz KURMAZ; yazım gorev.sh ekle ile, kutunun kendi jetonuyla.
#   VARSAYILAN KURU: neyi yazacağını basar. Yazmak için --uygula (mektup/yazım bir eylemdir).
#   İDEMPOTENT: aynı başlıkta açık bir görev zaten varsa yazılmaz (normalize eşleşme); ikinci koşu aynı sonucu verir.
#   GÖREV KİMLİKLİ MADDE (1.16.0, görev …GJRBF1T8 · Sultan 29 Eki "sırada bekleyen işlerden görev numarasını alıp 'şu görev tamamlanacak' yaz"):
#     maddede gorev_<tam kimlik> ya da 'görev …XXXXXX' (son 5+ karakter) varsa YENİ kayıt AÇILMAZ; o kayda "bugünün planında" adımı yazılır
#     (gorev.sh adim). Kimlik defterde yoksa / son-ek birden çok kayda uyuyorsa ✗ hata (tahmin yok). Kimliksiz maddede açık bir kayıtla kelime
#     örtüşmesi ≥ %60 ise İKİZ uyarısı: yazılmaz, rc 1 (29 Eki: 5 maddenin 4'ü sırada duran işin ikizi olarak açıldı — birebir başlık eşleşmesi yetmedi).
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
  KUTU="$(printf '%s\n' "$LISTE" | bash "$KOK/kutu-bul.sh" --kim "$KIM" --cozulmus --liste /dev/stdin 2>/dev/null)" || KUTU=""
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
# açık kayıtların kimlik + normalize başlık tablosu (ikiz ölçümü ve kimlik çözümü için): id<TAB>normbaşlık<TAB>durum
ACIK_TABLO="$(printf '%s\n' "$LISTE" | python3 -c '
import sys,re,unicodedata
def n(t):
    t=unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","ı").lower()
    t=t.translate(str.maketrans("âîûüöçşğı","aiuuocsgi"))   # aksan katlanır: ikiz ölçümü 'klasör' ile 'klasor'u aynı kelime sayar
    return re.sub(r"\s+"," ",re.sub(r"[^\w\s]","",t)).strip()
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_"): continue
    print("%s\t%s\t%s" % (p[0], n(re.sub(r"\s+\(son:.*$","",p[6])), p[2]))
')"
# maddedeki görev kimliği: gorev_<tam> ya da 'görev …<son-ek>' → defterdeki TEK kayıt; yoksa/çoksa boş + sebep (stderr)
_kimlik() { printf '%s\n' "$ACIK_TABLO" | python3 -c '
import sys,re
m=sys.argv[1]; tablo=[l.split("\t") for l in sys.stdin.read().splitlines() if l]
tam=re.findall(r"gorev_[A-Za-z0-9]{10,40}", m); kisa=re.findall(r"görev\s*…\s*([A-Za-z0-9]{5,40})", m)
if not tam and not kisa: sys.exit(0)
ids={t[0] for t in tablo}
if tam:
    for g in tam:
        if g not in ids: print("KİMLİK DEFTERDE YOK: "+g, file=sys.stderr); sys.exit(1)
    print(tam[0]); sys.exit(0)
ek=kisa[0]; es=[t[0] for t in tablo if t[0].endswith(ek)]
if len(es)==1: print(es[0]); sys.exit(0)
print(("KİMLİK DEFTERDE YOK: görev …" if not es else "SON-EK BİRDEN ÇOK KAYDA UYUYOR (%d): görev …" % len(es))+ek, file=sys.stderr); sys.exit(1)' "$1"; }
# ikiz ölçümü: maddenin kelimelerinin açık (bitti/iptal olmayan) bir kaydın kelimeleriyle örtüşmesi ≥ %60 → o kaydın kimliği (yoksa boş)
_ikiz() { printf '%s\n' "$ACIK_TABLO" | python3 -c '
import sys,re
n=sys.argv[1].translate(str.maketrans("âîûüöçşğı","aiuuocsgi")); a=set(w for w in n.split() if len(w)>2)   # tablo da katlanmış
if len(a)<3: sys.exit(0)   # üç anlamlı kelimeden az: ölçüm anlamsız, ikiz denmez
for l in sys.stdin.read().splitlines():
    p=l.split("\t")
    if len(p)<3 or p[2] in ("bitti","iptal","tamam"): continue
    b=set(w for w in p[1].split() if len(w)>2)
    if not b: continue
    ortusme=len(a&b)/min(len(a),len(b))
    if ortusme>=0.6: print("%s\t%d" % (p[0], round(ortusme*100))); sys.exit(0)' "$1"; }

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

yazilan=0; atlanan=0; reddedilen=0; hata=0; say=0; bagli=0; ikiz=0
while IFS= read -r sat; do
  m="$(printf '%s' "$sat" | sed -n 's/^- \[ \][[:space:]]*//p' | sed 's/^[0-9]\{1,2\}[).][[:space:]]*//')"   # "1) madde" sıra numarası başlığa girmez
  [ -n "$m" ] || continue
  say=$((say+1))
  if [ "${#m}" -gt 200 ]; then echo "  ✗ reddedildi (200 karakter üstü, başlık değil not): ${m:0:60}…"; reddedilen=$((reddedilen+1)); continue; fi
  n="$(_norm "$m")"
  # 1) KİMLİKLİ madde: yeni kayıt açılmaz, var olan kayda "bugünün planında" adımı
  if KIM_HATA="$(_kimlik "$m" 2>&1 >/dev/null)"; GID="$(_kimlik "$m" 2>/dev/null)"; [ -n "$GID$KIM_HATA" ]; then
    if [ -n "$KIM_HATA" ]; then echo "  ✗ görev kimliği çözülemedi: $m"; echo "      sebep: $KIM_HATA"; hata=$((hata+1)); continue; fi
    if [ "$UYGULA" -eq 1 ]; then
      if CIKTI="$(bash "$GOREV" adim "$GID" "bugünün planında ($KIM, $BUGUN): $m" 2>&1)"; then echo "  ↪ plana bağlandı (yeni kayıt yok): $m → $GID"; bagli=$((bagli+1))
      else echo "  ✗ ADIM YAZILAMADI: $m → $GID"; echo "      sebep: $(printf '%s' "$CIKTI" | tr '\n' ' ' | cut -c1-300)"; hata=$((hata+1)); fi
    else echo "  ↪ bağlardım (yeni kayıt yok): $m → $GID"; bagli=$((bagli+1)); fi
    continue
  fi
  if printf '%s' "$ACIK_N" | grep -qxF -- "$n"; then echo "  = atlandı (defterde açık): $m"; atlanan=$((atlanan+1)); continue; fi
  # 2) KİMLİKSİZ madde, benzer başlıklı açık kayıt var mı? (kelime örtüşmesi ≥ %60) → İKİZ: yazılmaz, kimliğiyle yazılması istenir
  if IK="$(_ikiz "$n")" && [ -n "$IK" ]; then
    echo "  ✗ İKİZ OLABİLİR (örtüşme %${IK#*	}): $m ↔ ${IK%%	*} — yazılmadı; maddeyi 'görev …${IK%%	*}' kimliğiyle yaz (…$(printf '%s' "${IK%%	*}" | tail -c 6))"
    echo "      sebep: 29 Eki — 5 maddenin 4'ü sırada duran işin ikizi olarak açıldı; birebir başlık eşleşmesi yetmedi"; ikiz=$((ikiz+1)); continue
  fi
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
printf 'kutu=%s kim=%s %s: yazılan=%d bağlanan=%d atlanan=%d ikiz=%d reddedilen=%d hata=%d plan-imzası=%s\n' "$KUTU" "$KIM" "$([ "$UYGULA" -eq 1 ] && echo uygula || echo kuru)" "$yazilan" "$bagli" "$atlanan" "$ikiz" "$reddedilen" "$hata" "$PLAN_IMZA"
[ "$hata" -eq 0 ] && [ "$reddedilen" -eq 0 ] && [ "$ikiz" -eq 0 ] || exit 1
exit 0
