#!/usr/bin/env bash
# butce.sh — Sultan'dan tık ya da karar isteyen isteklere GÜNLÜK BÜTÇE (günde en çok 4) + taşan isteğin kuyruğu.
#   butce.sh harca --tur kart|onay|soru|wa --ad "<istek adı>" --sahip <ajan> [--tavan N]
#        rc 0  → bütçeden düştü, istek şimdi gidebilir ("geçti n/4")
#        rc 10 → bütçe dolu: istek KUYRUĞA yazıldı, çağıran göndermez; sahibine "kuyrukta" bilgisi basılır
#   butce.sh acil --ad "<ne>" --sahip <ajan>
#        yalnız sultan-alarmi acili (hat durdu · para kaybı · canlı kesinti): tavanı aşar, günde en çok 1. rc 0 geçti · rc 10 acil hakkı da bitti → kuyruk
#   butce.sh durum                 bugünkü harcama, kalan, kuyruk
#   butce.sh ozet [--isle]         kuyruktaki isteklerin TEK özet metni (09:00 paketine); --isle satırları 'özete girdi' yapar
# Gün = İstanbul günü. Sayılan: kart · onay-bekliyor görevi · soru mektubu · WhatsApp sorusu. Bilgi satırı SAYILMAZ (çağıran harca çağırmaz).
# Aynı gün aynı tür+ad istek ikinci kez bütçeden düşmez (tekrar çağrı = aynı sonuç). Acil böyle değil: her çağrı hakkı düşer.
# SINIR (dürüstçe): defter dosya-yereldir (konteyner başına); kutular arası tek sayaç yoktur. Ortak sayaç ancak ortak serviste olur.
set -uo pipefail
DIZIN="${SULTAN_BUTCE_DIZIN:-${SULTAN_ALARMI_DIZIN:-${HOME:-/tmp}/.cache/sultan-alarmi}}"
DEFTER="$DIZIN/butce.jsonl"; KILIT="$DIZIN/butce.kilit"
TAVAN="${SULTAN_BUTCE_TAVAN:-4}"; ACIL_TAVAN="${SULTAN_BUTCE_ACIL_TAVAN:-1}"
SIMDI="${SULTAN_BUTCE_SIMDI:-$(date +%s)}"
kullanim(){ sed -n 2,11p "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
CMD="${1:-}"; [ -n "$CMD" ] && shift || kullanim
TUR=""; AD=""; SAHIP=""; ISLE=0
while [ $# -gt 0 ]; do case "$1" in
  --tur|--ad|--sahip|--tavan) [ $# -ge 2 ] || { echo "değer eksik: $1" >&2; exit 2; }
     case "$1" in --tur) TUR="$2" ;; --ad) AD="$2" ;; --sahip) SAHIP="$2" ;; --tavan) TAVAN="$2" ;; esac; shift 2 ;;
  --isle) ISLE=1; shift ;;
  *) echo "bilinmeyen: $1" >&2; kullanim ;;
esac; done
case "$TAVAN$ACIL_TAVAN" in *[!0-9]*|"") echo "tavan sayı olmalı" >&2; exit 2 ;; esac
GUN="$(TZ=Europe/Istanbul date -d "@$SIMDI" +%F)"
mkdir -p "$DIZIN" || { echo "butce: dizin açılamadı: $DIZIN" >&2; exit 2; }
touch "$DEFTER"

# python tek yerde: okuma-karar-yazma aynı kilitte (iki eşzamanlı istek 5. kapıyı açmasın)
karar(){ # karar <mod> → stdout: SONUC|n|kalan  (mod harca|acil)
  python3 - "$DEFTER" "$1" "$GUN" "$SIMDI" "$TUR" "$AD" "$SAHIP" "$TAVAN" "$ACIL_TAVAN" <<'PY'
import sys,json
p,mod,gun,ts,tur,ad,sahip,tavan,acil=sys.argv[1:10]; tavan=int(tavan); acil=int(acil)
kay=[]
for l in open(p,encoding='utf-8'):
    try: kay.append(json.loads(l))
    except Exception: pass
bugun=[k for k in kay if k.get('gun')==gun]
for k in (bugun if mod=='harca' else []):   # tekrar çağrı: aynı istek → aynı sonuç, ikinci düşüş yok (acil HER çağrıda düşer: günde 1 telefon)
    if k.get('mod')==mod and k.get('tur')==tur and k.get('ad')==ad and k.get('durum') in ('harcandi','kuyruk'):
        n=sum(1 for x in bugun if x.get('mod')=='harca' and x.get('durum')=='harcandi')
        print(("GECTI" if k['durum']=='harcandi' else "KUYRUK")+"|%d|%d"%(n,max(0,tavan-n))); sys.exit(0)
if mod=='harca':
    n=sum(1 for x in bugun if x.get('mod')=='harca' and x.get('durum')=='harcandi'); lim=tavan
else:
    n=sum(1 for x in bugun if x.get('mod')=='acil' and x.get('durum')=='harcandi'); lim=acil
durum='harcandi' if n<lim else 'kuyruk'
open(p,'a',encoding='utf-8').write(json.dumps({"gun":gun,"ts":int(ts),"mod":mod,"tur":tur,"ad":ad,"sahip":sahip,"durum":durum},ensure_ascii=False)+"\n")
if durum=='harcandi': n+=1
print(("GECTI" if durum=='harcandi' else "KUYRUK")+"|%d|%d"%(n,max(0,lim-n)))
PY
}

alan_denetle(){
  case "$AD" in ""|*$'\n'*) echo "RED: --ad dolu ve tek satır olmalı" >&2; return 2 ;; esac
  [ "${#AD}" -le 160 ] || { echo "RED: --ad 160 karakteri aşıyor" >&2; return 2; }
  [ -n "$SAHIP" ] || { echo "RED: --sahip gerekli (kuyruğa girerse kime haber verilecek)" >&2; return 2; }
}

case "$CMD" in
harca)
  case "$TUR" in kart|onay|soru|wa) ;; *) echo "RED: --tur kart|onay|soru|wa (bilgi satırı bütçeye girmez, harca çağırma)" >&2; exit 2 ;; esac
  alan_denetle || exit 2
  exec 9>>"$KILIT"; flock 9; S="$(karar harca)"; flock -u 9
  IFS='|' read -r SON N KALAN <<<"$S"
  if [ "$SON" = GECTI ]; then echo "butce: geçti ($N/$TAVAN bugün, kalan $KALAN)"; exit 0; fi
  echo "butce: KUYRUKTA — Sultan'a günlük $TAVAN istek doldu; '$AD' ($SAHIP) yarın 09:00 özetinde tek satır olarak gider. Şimdi gönderme."
  exit 10 ;;
acil)
  TUR=acil; alan_denetle || exit 2
  exec 9>>"$KILIT"; flock 9; S="$(karar acil)"; flock -u 9
  IFS='|' read -r SON N KALAN <<<"$S"
  if [ "$SON" = GECTI ]; then echo "butce: ACİL geçti ($N/$ACIL_TAVAN bugün)"; exit 0; fi
  echo "butce: acil hakkı bugün bitti; '$AD' ($SAHIP) yarın 09:00 özetine yazıldı."; exit 10 ;;
durum)
  python3 - "$DEFTER" "$GUN" "$TAVAN" "$ACIL_TAVAN" <<'PY'
import sys,json
p,gun,tavan,acil=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
kay=[json.loads(l) for l in open(p,encoding='utf-8') if l.strip()]
b=[k for k in kay if k.get('gun')==gun]
h=sum(1 for k in b if k['mod']=='harca' and k['durum']=='harcandi'); a=sum(1 for k in b if k['mod']=='acil' and k['durum']=='harcandi')
q=[k for k in kay if k['durum']=='kuyruk']
print("bugün %s: istek %d/%d · acil %d/%d · kuyrukta %d"%(gun,h,tavan,a,acil,len(q)))
PY
  ;;
ozet)
  exec 9>>"$KILIT"; flock 9
  python3 - "$DEFTER" "$ISLE" <<'PY'
import sys,json
p,isle=sys.argv[1],sys.argv[2]=='1'
kay=[json.loads(l) for l in open(p,encoding='utf-8') if l.strip()]
q=[k for k in kay if k['durum']=='kuyruk']
if not q: print("kuyrukta istek yok"); sys.exit(0)
print("Dün kuyruğa giren %d istek (sahibi, ne, ne zaman):"%len(q))
for k in q: print("- %s · %s · %s (%s)"%(k.get('sahip'),k.get('ad'),k.get('tur'),k.get('gun')))
if isle:
    for k in kay:
        if k['durum']=='kuyruk': k['durum']='ozete-girdi'
    open(p,'w',encoding='utf-8').write(''.join(json.dumps(k,ensure_ascii=False)+"\n" for k in kay))
PY
  ;;
*) kullanim ;;
esac
