#!/usr/bin/env bash
# sirada-bak.sh — /gunluk-plan'ın İLK defter adımı (1.11.0 · görev …VNB2E9, Sultan 27 Eki): plan yazmadan ÖNCE kutunun defterdeki Sırada listesine bak.
#   sirada-bak.sh [--kutu K] [--kim AJAN] [--esik N] [--bak]
#   KARAR=BAS  → Sırada ≥ eşik: en üstteki iş(ler) listelenir ve EN ÜSTTEKİ iş `gorev.sh ustlen` ile çalışılıyor yapılır (varsayılan; --bak = yalnız bak, başlama)
#   KARAR=SOR  → Sırada < eşik: Sultan'a TEK soru, iki şık (1 Sultan'la sohbet · 2 reis kendi başına: ADIM 0-d tarama-ekle)
#   rc: 0 karar verildi · 2 kullanım · 3 ölçülemedi (defter okunamadı / kutu çıkmadı) — "Sırada 0" DENMEZ, ölçülemeyen SORU değil ÖLÇÜLEMEDİ'dir
# Sırada = ekranın tanımı: aynı kutuda gorev_durumu acik ya da sira-bende (havuz/tasarlaniyor/bekliyor/calisiliyor/onay-bekliyor/bitti/iptal SAYILMAZ).
# 🔴 "Bugüne al" Sultan'ındır: bugun_plani alanını geçit YALNIZ Sultan ekranına yazdırır (A06) — bu betik onu YAZMAZ, yalnız ÖNERİR.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GOREV="$(bash "$KOK/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"
KUTU=""; KIM=""; ESIK="${GUNLUK_PLAN_SIRA_ESIK:-3}"; BASLA=1; TAHMIN="${GUNLUK_PLAN_TAHMIN_DK:-30}"
while [ $# -gt 0 ]; do
  case "$1" in
    --kutu) KUTU="${2:-}"; shift 2 ;; --kim) KIM="${2:-}"; shift 2 ;; --esik) ESIK="${2:-}"; shift 2 ;; --bak) BASLA=0; shift ;;
    *) echo "kullanım: sirada-bak.sh [--kutu K] [--kim AJAN] [--esik N] [--bak]" >&2; exit 2 ;;
  esac
done
case "$ESIK" in ''|*[!0-9]*) echo "HATA: --esik pozitif tam sayı olmalı (verilen: '$ESIK')" >&2; exit 2 ;; esac
[ "$ESIK" -ge 1 ] || { echo "HATA: --esik en az 1" >&2; exit 2; }
[ -x "$GOREV" ] || [ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-}}"
[ -z "$KIM" ] || KIM="$(bash "$KOK/kimlik-coz.sh" "$KIM")" || { echo "ÖLÇÜLEMEDİ: koltuk adı defter adına çevrilemedi (koltuk-esleme.tsv)" >&2; exit 3; }   # koltuk adı → defter adı (tablo)
LISTE="$(bash "$GOREV" liste 2>/dev/null)"; LRC=$?
[ "$LRC" -eq 0 ] && [ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı (rc=$LRC) — 'Sırada 0' DENMEZ" >&2; exit 3; }
if [ -z "$KUTU" ]; then
  KUTU="$(printf '%s\n' "$LISTE" | bash "$KOK/kutu-bul.sh" ${KIM:+--kim "$KIM" --cozulmus} --liste /dev/stdin 2>/dev/null)" || { echo "ÖLÇÜLEMEDİ: kutu adı çıkmadı (--kutu ver)" >&2; exit 3; }
fi
SIRA="$(printf '%s\n' "$LISTE" | python3 -c '
import sys
import unicodedata
def n(t): return unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","i").replace("ı","i").lower().replace("â","a").replace("î","i").replace("û","u")
kutu=sys.argv[1]; kim=n(sys.argv[2]); oncel={"cok-acil":0,"acil":1,"esnek":2,"rahat":3}; r=[]
for i,s in enumerate(sys.stdin):
    p=s.rstrip("\n").split(None,6)
    if len(p)<7 or not p[0].startswith("gorev_"): continue   # id kutu durum aciliyet etiket atanan BAŞLIK
    if p[1]!=kutu or p[2] not in ("acik","sira-bende"): continue
    ben="1" if (p[5]=="-" or (kim and n(p[5])==kim)) else "0"   # başlatma adayı: koltuğa atanmış ya da sahipsiz; başkasına atanmış iş ÜSTLENİLMEZ
    r.append((oncel.get(p[3],4),i,p[0],p[3],p[6].split("  (son:")[0],ben))
for o,i,gid,ac,b,ben in sorted(r): print("%s\t%s\t%s\t%s"%(gid,ac,b,ben))
' "$KUTU" "$KIM")"
N=0; [ -n "$SIRA" ] && N=$(printf '%s\n' "$SIRA" | wc -l)
echo "KUTU=$KUTU"; echo "SIRADA=$N"; echo "ESIK=$ESIK"
if [ "$N" -ge "$ESIK" ]; then
  echo "KARAR=BAS"
  printf '%s\n' "$SIRA" | head -5 | awk -F'\t' '{printf "ISI=%s · %s · %s\n",$1,$2,$3}'
  ILK="$(printf '%s\n' "$SIRA" | awk -F'\t' '$4=="1" {print $1; exit}')"
  if [ -z "$ILK" ]; then
    echo "BASLAMADI=yok (sıradaki $N işin hiçbiri bu koltuğa atanmış ya da sahipsiz değil — başkasının işi üstlenilmez)"
    echo "ONERI=Sultan'a: 'Sırada $N iş var ama hepsi başka koltuklara atanmış; bana atanmış ya da sahipsiz iş yok. Kendimize iş çıkarma seansı yapalım mı?'"
  elif [ "$BASLA" -eq 1 ]; then
    [ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ustlen için ajan kimliği yok (--kim ver ya da --bak)" >&2; exit 3; }
    if bash "$GOREV" ustlen "$ILK" --kim "$KIM" --tahmin "$TAHMIN" >/dev/null 2>&1; then echo "BASLADI=$ILK (çalışılıyor yapıldı · tahmin ${TAHMIN} dk)"; else echo "BASLAMADI=$ILK (ustlen reddedildi — defter durumunu kendin oku)" >&2; exit 1; fi
    echo "ONERI=Sultan'a: 'Sırada $N iş var; en üstteki $ILK ile başladım. Bugüne almak ister misin?' — bugüne alma tıkı Sultan'ın (ekranda)"
  else
    echo "ONERI=Sultan'a: 'Sırada $N iş var; en üstteki $ILK. Başlayıp bugüne alayım mı?' — henüz BAŞLANMADI (--bak); bugüne alma tıkı Sultan'ın (ekranda)"
  fi
else
  echo "KARAR=SOR"
  if [ "$N" -eq 0 ]; then echo "SORU=Bu kutuda planlanmış görev yok. Kendimize iş çıkarma seansı yapalım mı?"
  else echo "SORU=Bu kutuda sırada yalnız $N iş var (başlamak için en az $ESIK gerek). Kendimize iş çıkarma seansı yapalım mı?"; fi
  echo "SIKLAR=Sultan'la sohbet ederek|Reis kendi başına tarasın (önerim)"
fi
