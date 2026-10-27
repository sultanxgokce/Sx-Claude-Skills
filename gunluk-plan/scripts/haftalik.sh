#!/usr/bin/env bash
# haftalik.sh — kutunun SON 7 GÜNÜNÜ görev defterinden ölçer; zayıf noktaları ve merkeze bildirilecekleri Sultan-dilinde yazar
#   (görev 0HC75A (c): "kutunun son bir haftasını değerlendirip zayıf noktaları ve merkeze bildirilmesi gerekenleri bildirsin").
#
# Kaynak tek: gorev.sh liste (kutunun kendi jetonuyla yalnız kendi görevleri). Yeni defter/havuz KURMAZ.
#   VARSAYILAN KURU: raporu basar, kimseye mektup göndermez. --uygula: raporu merkeze (varsayılan SERDAR) ULAK ile gönderir.
#   Ölçemezse (liste okunamadı / boş) 'sorun yok' DENMEZ: rc=3.
#
#   haftalik.sh [--uygula] [--kutu K] [--kim AJAN] [--hedef AD] [--gun N]
#   rc: 0 tamam (kuru dahil) · 1 gönderim hatası · 2 kullanım · 3 ölçülemedi
#
# Zayıf nokta kuralları (eşikler sayıdır, kural değil — --gun ile değişir):
#   Z1 hiç kapanış yok: son N günde bitti/tamam 0 ve açık iş var
#   Z2 hareketsiz açık: açık/bekliyor/sira-bende durumunda, son hareketi N günden eski iş var (başlıkla listelenir, en çok 5)
#   Z3 bekleyen yığını: bekliyor durumundaki iş sayısı çalışılıyor+açık sayısından büyük
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GOREV="$(bash "$(dirname "${BASH_SOURCE[0]}")/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"   # yol çözümü tek yerde (gorev-yolu.sh)
ULAK="${GUNLUK_PLAN_ULAK_SH:-/config/projects/Nexus/scripts/ulak.sh}"
UYGULA=0; KUTU="${GUNLUK_PLAN_KUTU:-}"; KIM=""; HEDEF="SERDAR"; GUN=7
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --uygula) UYGULA=1; shift ;;
    --kutu) KUTU="${2:-}"; shift 2 ;;
    --kim) KIM="${2:-}"; shift 2 ;;
    --hedef) HEDEF="${2:-}"; shift 2 ;;
    --gun) GUN="${2:-}"; shift 2 ;;
    *) echo "tanınmayan argüman: $1" >&2; echo "kullanım: haftalik.sh [--uygula] [--kutu K] [--kim AJAN] [--hedef AD] [--gun N]" >&2; exit 2 ;;
  esac
done
case "$GUN" in ''|*[!0-9]*) echo "HATA: --gun sayı olmalı: $GUN" >&2; exit 2 ;; esac
[ "$GUN" -ge 1 ] && [ "$GUN" -le 90 ] || { echo "HATA: --gun 1-90 arası olmalı: $GUN" >&2; exit 2; }
[ -n "$HEDEF" ] || { echo "HATA: --hedef boş" >&2; exit 2; }
[ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }

LISTE="$(bash "$GOREV" liste 2>/dev/null)"; LRC=$?
[ "$LRC" -eq 0 ] && [ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı (rc=$LRC) — 'sorun yok' DENMEZ" >&2; exit 3; }

RAPOR="$(printf '%s\n' "$LISTE" | python3 -I -c '
import sys,re,datetime
bugun=datetime.date.fromisoformat(sys.argv[1]); gun=int(sys.argv[2]); kutu_arg=sys.argv[3]
sat=[]
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_"): continue
    m=re.search(r"\(son: (\d{4}-\d{2}-\d{2})",p[6])
    if not m: continue
    son=datetime.date.fromisoformat(m.group(1))
    sat.append((p[1],p[2],re.sub(r"\s+\(son:.*$","",p[6]),(bugun-son).days))
if not sat: print("OLCULEMEDI"); sys.exit(0)
kutu=kutu_arg or max(set(k for k,_,_,_ in sat),key=[k for k,_,_,_ in sat].count)
sat=[x for x in sat if x[0]==kutu]
if not sat: print("OLCULEMEDI"); sys.exit(0)   # var olmayan/görevsiz kutu: sıfır sayıyla "ZAYIF yok" DENMEZ
kapali=("bitti","tamam"); acik=("acik","sira-bende","bekliyor","calisiliyor","onay-bekliyor")
kapanan=[x for x in sat if x[1] in kapali and 0<=x[3]<=gun]
iptal=[x for x in sat if x[1]=="iptal" and 0<=x[3]<=gun]
cal=[x for x in sat if x[1]=="calisiliyor"]
bek=[x for x in sat if x[1]=="bekliyor"]
ac=[x for x in sat if x[1] in ("acik","sira-bende")]
hareketsiz=sorted([x for x in sat if x[1] in ("acik","sira-bende","bekliyor") and x[3]>gun],key=lambda x:-x[3])
acik_n=len([x for x in sat if x[1] in acik])
print("KUTU="+kutu)
print("SAYI kapanan=%d iptal=%d calisiliyor=%d bekliyor=%d acik=%d hareketsiz=%d"%(len(kapanan),len(iptal),len(cal),len(bek),len(ac),len(hareketsiz)))
z=[]
if not kapanan and acik_n>0: z.append("Z1 son %d günde hiç iş kapanmadı, defterde %d açık iş var"%(gun,acik_n))
if hareketsiz:
    z.append("Z2 %d iş %d günden uzundur hareketsiz: "%(len(hareketsiz),gun)+"; ".join("%s (%d gün)"%(x[2][:70],x[3]) for x in hareketsiz[:5]))
if len(bek)>len(cal)+len(ac): z.append("Z3 bekleyen iş (%d) yürüyen ve açık işlerden (%d) fazla"%(len(bek),len(cal)+len(ac)))
for x in z: print("ZAYIF "+x)
if not z: print("ZAYIF yok")
' "$BUGUN" "$GUN" "$KUTU")"
[ -n "$RAPOR" ] && [ "$RAPOR" != "OLCULEMEDI" ] || { echo "ÖLÇÜLEMEDİ: listede tarihli görev satırı yok" >&2; exit 3; }

KUTU_AD="$(printf '%s\n' "$RAPOR" | sed -n 's/^KUTU=//p')"
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-$KUTU_AD}}"
SAYI="$(printf '%s\n' "$RAPOR" | sed -n 's/^SAYI //p')"
ZAYIF="$(printf '%s\n' "$RAPOR" | sed -n 's/^ZAYIF //p')"
MESAJ="Haftalık değerlendirme · kutu $KUTU_AD · son $GUN gün · $SAYI"$'\n'"Zayıf noktalar:"$'\n'"$ZAYIF"
printf '%s\n' "$MESAJ"
if [ "$UYGULA" -eq 1 ]; then
  [ -f "$ULAK" ] || { echo "ÖLÇÜLEMEDİ: ulak.sh yok ($ULAK) — gönderilemedi" >&2; exit 3; }
  if bash "$ULAK" gonder "$HEDEF" "$MESAJ" >/dev/null 2>&1; then echo "gönderildi → $HEDEF"; else echo "✗ GÖNDERİLEMEDİ → $HEDEF" >&2; exit 1; fi
else
  echo "(kuru koşu: $HEDEF'e gönderilmedi — göndermek için --uygula)"
fi
exit 0
