#!/usr/bin/env bash
# sirada-bak.sh — /gunluk-plan'ın İLK defter adımı (1.11.0 · görev …VNB2E9, Sultan 27 Eki): plan yazmadan ÖNCE kutunun defterdeki Sırada listesine bak.
#   sirada-bak.sh [--kutu K] [--kim AJAN] [--esik N] [--bak] [--taze-gun N]
#   KARAR=BAS  → Sırada ≥ eşik: en üstteki iş(ler) listelenir ve EN ÜSTTEKİ iş `gorev.sh ustlen` ile çalışılıyor yapılır (varsayılan; --bak = yalnız bak, başlama)
#   KARAR=SOR  → Sırada < eşik: Sultan'a TEK soru, üç şık (1 Sultan'la sohbet · 2 reis kendi başına: ADIM 0-d tarama-ekle · 3 Seanslı Hasat: havuz kayıt kayıt sorulur, 1.17.0)
#                + ZORUNLU=ADIM 0-d satırı (cevap beklenmez, 1.13.0)
#   TAZELIK=   → her koşuda havuz tazeliği (1.17.0): VAR · KURU (Meşveret seansı önerilir) · ÖLÇÜLEMEDİ; pencere --taze-gun N (varsayılan 7)
#   HASAT=    → ilk aday HAVUZ kaydıysa hasat kapısı (1.19.0, hasat.sh durum): OLUR değilse üstlenilmez, BASLAMADI + ZORUNLU=HASAT KAPISI basılır
#   rc: 0 karar verildi · 2 kullanım · 3 ölçülemedi (defter okunamadı / kutu çıkmadı) — "Sırada 0" DENMEZ, ölçülemeyen SORU değil ÖLÇÜLEMEDİ'dir
# Sırada = ekranın tanımı: aynı kutuda gorev_durumu acik ya da sira-bende (havuz/tasarlaniyor/bekliyor/calisiliyor/onay-bekliyor/bitti/iptal SAYILMAZ).
# 🔴 "Bugüne al" Sultan'ındır: bugun_plani alanını geçit YALNIZ Sultan ekranına yazdırır (A06) — bu betik onu YAZMAZ, yalnız ÖNERİR.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GOREV="$(bash "$KOK/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"
KUTU=""; KIM=""; ESIK="${GUNLUK_PLAN_SIRA_ESIK:-3}"; BASLA=1; TAHMIN="${GUNLUK_PLAN_TAHMIN_DK:-30}"; TAZE_GUN="${GUNLUK_PLAN_TAZE_GUN:-7}"
# 1.18.0 (MUAVİN Madde 4, 30 Eki · NOVA): kimlik ortamda yokken TÜRETİLİR (ulak.sh #1416 deseni, bu betiğin kendi yoluna uydurulmuş):
#   --kim → GUNLUK_PLAN_AJAN → AGENT_NAME → AILE_KIMDEN → $TMUX içindeyse tmux oturumu ('#S:#I' tam, yoksa '#S') ↔ aile-registry 'tmux:' alanı
#   (TEK eşleşme; yol GUNLUK_PLAN_REGISTRY, vars. <depo kökü>/_agents/handoff/aile-registry.yaml). Eskiden KIM boşken betik yine koşuyor,
#   koltuğa atanmış işleri "başkasının" sayıp Sultan'a "iş çıkaralım mı" diye sevk ediyordu. Türetilemezse ÖLÇÜLEMEDİ rc 3; kimlik UYDURULMAZ.
kimlik_tmux() {
  [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1 || return 0
  local hedef=() tam ses reg
  [ -n "${TMUX_PANE:-}" ] && hedef=(-t "$TMUX_PANE")
  tam="$(tmux display-message -p "${hedef[@]}" '#S:#I' 2>/dev/null || true)"; ses="${tam%%:*}"
  reg="${GUNLUK_PLAN_REGISTRY:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/_agents/handoff/aile-registry.yaml}"
  [ -n "$ses" ] && [ -r "$reg" ] || return 0
  python3 - "$reg" "$tam" "$ses" <<'PYKOD' 2>/dev/null || true
import re, sys
reg, tam, ses = sys.argv[1:4]; uye, cift = None, []
for s in open(reg, encoding="utf-8", errors="replace"):
    m = re.match(r'^\s*-\s*id:\s*["\']?([^"\'#\s]+)', s)
    if m: uye = m.group(1); continue
    m = re.match(r'^\s*tmux:\s*["\']?([^"\'#\s]+)', s)
    if m and uye: cift.append((uye, m.group(1)))
tamlar = sorted({u for u, t in cift if t == tam})
sesler = sorted({u for u, t in cift if t.split(":")[0] == ses})
secim = tamlar if tamlar else sesler
if len(secim) == 1: print(secim[0])   # birden çok eşleşme = belirsiz → türetilmez
PYKOD
}
while [ $# -gt 0 ]; do
  case "$1" in
    --kutu) KUTU="${2:-}"; shift 2 ;; --kim) KIM="${2:-}"; shift 2 ;; --esik) ESIK="${2:-}"; shift 2 ;; --bak) BASLA=0; shift ;; --taze-gun) TAZE_GUN="${2:-}"; shift 2 ;;
    *) echo "kullanım: sirada-bak.sh [--kutu K] [--kim AJAN] [--esik N] [--bak] [--taze-gun N]" >&2; exit 2 ;;
  esac
done
case "$ESIK" in ''|*[!0-9]*) echo "HATA: --esik pozitif tam sayı olmalı (verilen: '$ESIK')" >&2; exit 2 ;; esac
[ "$ESIK" -ge 1 ] || { echo "HATA: --esik en az 1" >&2; exit 2; }
case "$TAZE_GUN" in ''|*[!0-9]*) echo "HATA: --taze-gun pozitif tam sayı olmalı (verilen: '$TAZE_GUN')" >&2; exit 2 ;; esac
[ "$TAZE_GUN" -ge 1 ] || { echo "HATA: --taze-gun en az 1" >&2; exit 2; }
[ -x "$GOREV" ] || [ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-${AILE_KIMDEN:-}}}"
[ -n "$KIM" ] || KIM="$(kimlik_tmux)"
[ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ajan kimliği yok — GUNLUK_PLAN_AJAN/AGENT_NAME/AILE_KIMDEN ayarla ya da --kim ver (tmux oturumu aile-registry 'tmux:' alanıyla TEK eşleşmedi); kimlik uydurulmaz, iş 'başkasının' sayılmaz" >&2; exit 3; }
[ -z "$KIM" ] || KIM="$(bash "$KOK/kimlik-coz.sh" "$KIM")" || { echo "ÖLÇÜLEMEDİ: koltuk adı defter adına çevrilemedi (koltuk-esleme.tsv)" >&2; exit 3; }   # koltuk adı → defter adı (tablo)
LISTE="$(bash "$GOREV" liste 2>/dev/null)"; LRC=$?
[ "$LRC" -eq 0 ] && [ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı (rc=$LRC) — 'Sırada 0' DENMEZ" >&2; exit 3; }
if [ -z "$KUTU" ]; then
  KUTU="$(printf '%s\n' "$LISTE" | bash "$KOK/kutu-bul.sh" ${KIM:+--kim "$KIM" --cozulmus} --liste /dev/stdin 2>/dev/null)" || { echo "ÖLÇÜLEMEDİ: kutu adı çıkmadı (--kutu ver)" >&2; exit 3; }
fi
# Durum kümesi argümandır: Sırada = acik + sira-bende (ekranın tanımı); HAVUZ = havuz (1.14.0, SERDAR 29 Eki "havuz da iştir").
PY='
import sys
import unicodedata
def n(t): return unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","i").replace("ı","i").lower().replace("â","a").replace("î","i").replace("û","u").replace("ü","u").replace("ö","o").replace("ç","c").replace("ş","s").replace("ğ","g")
kutu=sys.argv[1]; kim=n(sys.argv[2]); oncel={"cok-acil":0,"acil":1,"esnek":2,"rahat":3}; r=[]
for i,s in enumerate(sys.stdin):
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_"): continue   # id kutu durum aciliyet etiket atanan BAŞLIK
    if p[1]!=kutu or p[2] not in sys.argv[3].split(","): continue
    ben="1" if (p[5]=="-" or (kim and n(p[5])==kim)) else "0"   # başlatma adayı: koltuğa atanmış ya da sahipsiz; başkasına atanmış iş ÜSTLENİLMEZ
    r.append((oncel.get(p[3],4),i,p[0],p[3],p[6].split("  (son:")[0],ben))
for o,i,gid,ac,b,ben in sorted(r): print("%s\t%s\t%s\t%s"%(gid,ac,b,ben))
'
SIRA="$(printf '%s\n' "$LISTE" | python3 -c "$PY" "$KUTU" "$KIM" "acik,sira-bende")"
HAVUZ="$(printf '%s\n' "$LISTE" | python3 -c "$PY" "$KUTU" "$KIM" "havuz")"
N=0; [ -n "$SIRA" ] && N=$(printf '%s\n' "$SIRA" | wc -l)
# 1.14.0 (SERDAR 29 Eki, Sultan "ilerleme durdu"): HAVUZ da iştir. Sırada eşiğin altında kalsa bile bu koltuğa atanmış ya da sahipsiz HAVUZ işi varsa
#   Sultan'a "iş çıkaralım mı" SORULMAZ: iş vardır, sormadan başlanır. Sırada sayısı (ekranın tanımı) DEĞİŞMEZ; havuz ayrı sayılır (HAVUZDA=).
H=0; [ -n "$HAVUZ" ] && H=$(printf '%s\n' "$HAVUZ" | awk -F'\t' '$4=="1"' | wc -l)
NB="$N"; HAVUZDAN=0
echo "KUTU=$KUTU"; echo "SIRADA=$N"; echo "HAVUZDA=$H"; echo "ESIK=$ESIK"
# 1.17.0 (Kuzey Yıldızı 1.5/1.8 · Sultan 29 Eki "havuzda hasat etmek için yeterli yeni kayıt yoksa, her şey bayatsa, bunu da bir kontrol
#   mekanizması olmalı"): HAVUZ TAZELİĞİ. Kutunun havuzundaki her kaydın liste satırındaki "(son: <tarih>)" damgası okunur (son adım = açılış ya da
#   son hareket). Taze = son TAZE_GUN gün içinde (varsayılan 7, --taze-gun N). Havuz boş ya da taze kayıt yok → TAZELIK=KURU + Meşveret seansı önerisi.
#   Tarihi okunamayan kayıt varken taze de yoksa ÖLÇÜLEMEDİ: "KURU" da "VAR" da UYDURULMAZ. Kutu düzeyinde sayılır (HAVUZDA= koltuk düzeyinde kalır).
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
TZ_PY='
import sys, re, datetime
kutu=sys.argv[1]; bugun=sys.argv[2]; gun=int(sys.argv[3])
try: bg=datetime.date.fromisoformat(bugun)
except Exception: print("OLCULEMEDI\t0\t0\t0\t0\t-"); sys.exit(0)
top=taze=bayat=tarihsiz=0; eneski=None
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_") or p[1]!=kutu or p[2]!="havuz": continue
    top+=1
    m=re.search(r"\(son: (\d{4}-\d{2}-\d{2})", p[6])
    try: t=datetime.date.fromisoformat(m.group(1)) if m else None
    except Exception: t=None
    if t is None: tarihsiz+=1; continue
    yas=(bg-t).days
    if yas<0: tarihsiz+=1; continue   # gelecek tarihli damga (saat kayması / bozuk veri) güvenilmez: taze SAYILMAZ, okunamayan gibi işlenir (göz tur 1)
    if eneski is None or yas>eneski: eneski=yas
    if yas<=gun: taze+=1
    else: bayat+=1
if top==0: d="KURU"
elif taze>0: d="VAR"
elif tarihsiz>0: d="OLCULEMEDI"
else: d="KURU"
print("%s\t%d\t%d\t%d\t%d\t%s"%(d,top,taze,bayat,tarihsiz,"-" if eneski is None else eneski))
'
IFS=$'\t' read -r TZ_D HT HTZ HB HTS HEE < <(printf '%s\n' "$LISTE" | python3 -c "$TZ_PY" "$KUTU" "$BUGUN" "$TAZE_GUN")
[ -n "${TZ_D:-}" ] || { TZ_D="COKTU"; HT="-"; HTZ="-"; HB="-"; HTS="-"; HEE="-"; }   # python çıktı vermedi: sayılar UYDURULMAZ, "-" basılır
echo "HAVUZ_TOPLAM=$HT"; echo "HAVUZ_TAZE=$HTZ"; echo "HAVUZ_BAYAT=$HB"; echo "HAVUZ_TARIHSIZ=$HTS"; echo "HAVUZ_EN_ESKI_GUN=$HEE"; echo "TAZE_GUN=$TAZE_GUN"
case "$TZ_D" in
  COKTU) echo "TAZELIK=ÖLÇÜLEMEDİ"; echo "TAZELIK_NEDEN=tazelik hesabı çıktı vermedi (python3 çöktü ya da bulunamadı) — ne bayat ne taze DENİR; python3 ve liste biçimini kontrol et" ;;
  VAR) echo "TAZELIK=VAR" ;;
  KURU) echo "TAZELIK=KURU · ÖNERİ=Meşveret seansı (yeni bulgu toplanmalı)"
        if [ "$HT" -eq 0 ]; then echo "TAZELIK_NEDEN=havuz boş — hasat edecek kayıt yok; günlük plana 'Meşveret seansı' maddesi koy, taze kayıt ekle (bulgu.sh yaz / tarama-ekle.sh)"
        else echo "TAZELIK_NEDEN=havuzdaki $HT kaydın hiçbiri son $TAZE_GUN günde açılmadı/hareket görmedi (en eskisi $HEE gün) — hepsi bayat; günlük plana 'Meşveret seansı' maddesi koy, taze kayıt ekle"; fi ;;
  *) echo "TAZELIK=ÖLÇÜLEMEDİ"
     if [ "$HTS" -eq 0 ]; then echo "TAZELIK_NEDEN=bugünün tarihi okunamadı (GUNLUK_PLAN_TARIH='$BUGUN') — tazelik hesaplanamaz, bayat da taze de DENMEZ"
     else echo "TAZELIK_NEDEN=havuzdaki $HTS kaydın tarihi okunamadı ya da gelecekte, taze kayıt da görünmüyor — bayat DENMEZ, ekranda (son:) damgasını kontrol et"; fi ;;
esac
if [ "$N" -lt "$ESIK" ] && [ "$H" -ge 1 ]; then
  HAVUZDAN=1; SIRA="$(printf '%s\n%s\n' "$SIRA" "$HAVUZ" | sed '/^$/d')"; NB=$(printf '%s\n' "$SIRA" | wc -l)
fi
if [ "$N" -ge "$ESIK" ] || [ "$HAVUZDAN" -eq 1 ]; then
  echo "KARAR=BAS"
  [ "$HAVUZDAN" -eq 0 ] || echo "NEDEN=Sırada $N iş var (eşik $ESIK) ama havuzda sana düşen $H iş var — havuz da iştir: Sultan'a SORMADAN başla (iş çıkarma seansı gerekmez)"
  printf '%s\n' "$SIRA" | head -5 | awk -F'\t' '{printf "ISI=%s · %s · %s\n",$1,$2,$3}'
  # 1.16.0 (GJRBF1T8 · Sultan 29 Eki): aynı işler doğrudan PLAN MADDESİ biçiminde — çıpaya kopyalanır, deftere-yaz kimliği görür ve ikiz açmaz.
  #   Biçim: görev …<son 6> tamamlanacak: <başlık> (sahip: <atanan | sen>)  — kimlik son-ek olarak taşınır, deftere-yaz tam kimliğe çözer.
  printf '%s\n' "$SIRA" | head -5 | awk -F'\t' -v kim="${KIM:-sen}" '{printf "MADDE=görev …%s tamamlanacak: %s (sahip: %s)\n", substr($1,length($1)-5), $3, ($4=="1" ? kim : "başkası")}'
  ILK="$(printf '%s\n' "$SIRA" | awk -F'\t' '$4=="1" {print $1; exit}')"
  # 1.19.0 (Meşveret 30 Eki madde 9 · görev …ZM3PWD): HASAT KAPISI. İlk aday HAVUZ kaydıysa (havuz da iştir yolu) kayıt göreve çevrilmeden
  #   önce "sorun hâlâ var mı" ölçülmüş olmalı: hasat.sh durum → OLUR değilse ÜSTLENİLMEZ; doğrulama komutu basılır. Tazelik (1.17) kaydın
  #   yaşına bakar, bu kapı sorunun yaşadığına. Kapı ölçemezse (eski gorev.sh, kayıt okunamadı) da başlanmaz: "olur" uydurulmaz.
  HASAT_ILK=0; [ -z "$ILK" ] || [ -z "$HAVUZ" ] || HASAT_ILK=$(printf '%s\n' "$HAVUZ" | awk -F'\t' -v i="$ILK" '$1==i' | wc -l)
  if [ "$HASAT_ILK" -ge 1 ]; then
    HK="$(bash "$KOK/hasat.sh" durum "$ILK" --taze-gun "$TAZE_GUN" 2>&1)"; HKRC=$?
    HASAT_D="$(printf '%s\n' "$HK" | sed -n 's/^HASAT=//p' | head -1)"; HASAT_N="$(printf '%s\n' "$HK" | sed -n 's/^NEDEN=//p' | head -1)"
    echo "HASAT=${HASAT_D:-ÖLÇÜLEMEDİ} · $ILK"
    if [ "${HASAT_D:-}" != OLUR ]; then
      echo "BASLAMADI=$ILK (hasat kapısı: ${HASAT_N:-kapı ölçemedi, rc $HKRC} — havuz kaydı ölçülmeden göreve çevrilmez)"
      echo "ZORUNLU=HASAT KAPISI: önce ölç ve kayda yaz → bash $KOK/hasat.sh dogrula $ILK --sonuc var|duzelmis|olculemedi --olcum \"<komut ya da dosya>\" [--kapandi \"PR #N\"] ; 'var' ise bash $KOK/hasat.sh ac $ILK \"<gerekçe>\" (ya da sirada-bak'ı yeniden koş)"
      exit 0
    fi
  fi
  if [ -z "$ILK" ]; then
    echo "BASLAMADI=yok (sıradaki $NB işin hiçbiri bu koltuğa atanmış ya da sahipsiz değil — başkasının işi üstlenilmez)"
    echo "ONERI=Sultan'a: 'Sırada $NB iş var ama hepsi başka koltuklara atanmış; bana atanmış ya da sahipsiz iş yok. Kendimize iş çıkarma seansı yapalım mı?'"
  elif [ "$BASLA" -eq 1 ]; then
    [ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ustlen için ajan kimliği yok (--kim ver ya da --bak)" >&2; exit 3; }
    if bash "$GOREV" ustlen "$ILK" --kim "$KIM" --tahmin "$TAHMIN" >/dev/null 2>&1; then echo "BASLADI=$ILK (çalışılıyor yapıldı · tahmin ${TAHMIN} dk)"; else echo "BASLAMADI=$ILK (ustlen reddedildi — defter durumunu kendin oku)" >&2; exit 1; fi
    echo "ONERI=Sultan'a: 'Sırada $NB iş var; en üstteki $ILK ile başladım. Bugüne almak ister misin?' — üstlenmek ajanın işiydi (yapıldı); bugüne alma tıkı Sultan'ın (ekranda), işi geciktirmez"
  else
    echo "ONERI=Sırada $NB iş var; en üstteki $ILK. --bak yalnız baktı, BAŞLANMADI: üstlenmek senin (ajanın) işi, izin beklemez → gorev.sh ustlen $ILK ile başla. Sultan'ın tıkı yalnız 'bugüne al' (öncelik işareti) içindir; başlamanı geciktirmez"
  fi
else
  echo "KARAR=SOR"
  if [ "$N" -eq 0 ]; then echo "SORU=Bu kutuda planlanmış görev yok. Kendimize iş çıkarma seansı yapalım mı?"
  else echo "SORU=Bu kutuda sırada yalnız $N iş var (başlamak için en az $ESIK gerek). Kendimize iş çıkarma seansı yapalım mı?"; fi
  # 1.17.0 (Kuzey Yıldızı 1.8): üçüncü şık SEANSLI HASAT — reis havuz kaydını Sultan'a tek tek sunar ("… kodlu kayıttan … içerikli görevi açıyorum, olur mu?"),
  #   üç cevap: kabul · başka sun · düzeltmeyle kabul. Havuz boşsa hasat edilecek bir şey yoktur; şık bunu söyler, Meşveret seansına yönlendirir.
  if [ "$HT" = 0 ]; then SIK3="Havuzdan süzelim: Seanslı Hasat — havuz BOŞ, önce Meşveret seansı (yeni bulgu toplanmalı)"
  else SIK3="Havuzdan süzelim: Seanslı Hasat (kayıt kayıt sorarım, 3 cevap: kabul · başka sun · düzeltmeyle kabul)"; fi
  echo "SIKLAR=Sultan'la sohbet ederek|Reis kendi başına tarasın (önerim)|$SIK3"
  # 1.19.0 HASAT KAPISI (Meşveret madde 9): Seanslı Hasat'ta her kayıt göreve çevrilmeden önce "hâlâ var mı" ölçülür — ezbere iş açılmaz.
  [ "$HT" = 0 ] || echo "HASAT_KAPI=her havuz kaydı göreve çevrilmeden ÖNCE ölçülür: bash $KOK/hasat.sh durum <gorev_id> → OLUR değilse bash $KOK/hasat.sh dogrula <gorev_id> --sonuc var|duzelmis|olculemedi --olcum \"<komut>\" (düzelmiş → --kapandi \"PR #N\" ile kendiliğinden kapanır); $TAZE_GUN günden eski ya da yüzeyde birleşme görmüş doğrulama yeniden ölçülür; açılış: bash $KOK/hasat.sh ac <gorev_id> \"<gerekçe>\""
  # 1.13.0 (HC75A, SERDAR 28 Eki): eşik altında ADIM 0-d ZORUNLU — Sultan'ın cevabı beklenmez; sıra boşken kutu defterine açılış üretir. Tarama-ekle kuru varsayılan kalır, günlük 3 tavanı onun kapısıdır.
  echo "ZORUNLU=ADIM 0-d tarama: Sultan'ın cevabını BEKLEMEDEN bir ölçülmüş iş ekle (günde en çok 3): bash $KOK/tarama-ekle.sh --baslik \"<tek cümle>\" --kaynak <dosya:satır|https://…> --kanit \"<bu turda ölçtüğün>\" --uygula"
fi
