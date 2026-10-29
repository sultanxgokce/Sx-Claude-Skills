#!/usr/bin/env bash
# jeton-kutusu.sh — bu kutunun defter jetonu HANGİ kutuya yazar? Geçidin /ben ucunu sorar, kutu adını basar (görev …NMAGXX8C).
# Niçin: tarama-ekle --kutu X deyip jetonu Y olan kutudan koşulunca kayıt Y'ye yazılıyor, tavan X'te sayılıyordu; ret yazımdan SONRA geliyordu.
#   Yazmadan önce sormak için tek yer burası. gorev.sh ile aynı ortam: DEFTER_UC · DEFTER_JETON_YOL. Jeton değeri çıktıya/hataya YAZILMAZ.
# rc 0 = kutu basıldı · rc 3 = ölçülemedi (jeton yok, geçit cevap vermedi, cevapta kutu yok) — çağıran "aynı kutu" SAYMAZ.
set -u
UC="${DEFTER_UC:-http://cloudtop-defter:8791}"; JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"
[ -r "$JY" ] || { echo "ÖLÇÜLEMEDİ: defter jetonu okunamıyor ($JY)" >&2; exit 3; }
C="$(curl -sS -m 10 -H "x-defter-jeton: $(tr -d '\n' < "$JY")" "$UC/ben" -w '\n%{http_code}' 2>/dev/null)" || { echo "ÖLÇÜLEMEDİ: geçit cevap vermedi ($UC/ben)" >&2; exit 3; }
K="$(printf '%s' "$C" | python3 -c '
import sys,json
t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g)
except Exception: sys.exit(3)
k=j.get("kutu") if isinstance(j,dict) else None
if kod!="200" or not isinstance(k,str) or not k.strip(): sys.exit(3)
print(k.strip())' 2>/dev/null)" || { echo "ÖLÇÜLEMEDİ: /ben cevabında kutu yok" >&2; exit 3; }
printf '%s\n' "$K"
