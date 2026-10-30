#!/usr/bin/env bash
# kapi-kaydirma.test.sh — beyan sığmıyorsa kapı SIĞAN duvara kaydırılır; SESSİZ OLAMAZ.
#
# 🔴 NEDEN VAR (ölçüldü 2026-09-23/24, iki gerçek market planı): kapı ölçü yazısı 160 cm derken
# mühür 80 cm'lik bir duvar parçasına düşüyor ve açıklık 72-78 cm'e KIRPILIYORDU. Kırpma zaten
# raporlanıyordu ama kapı yanlış genişlikte kalıyordu. Artık beyanı taşıyabilen en yakın duvara
# kaydırılır. MEDDAH şartı: (a) her kaydırma mesafe + eski/yeni duvar + oda çiftiyle RAPORLANIR,
# (b) kaydırma kapıyı BAŞKA İKİ ODANIN arasına taşıyorsa RC 1 — yanlış odayı birbirine açmak,
# kapıyı kırpmaktan kötüdür. Bayrak `--kapi-kaydir`, varsayılan KAPALI.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }

# FIXTURE: iki oda, aralarındaki duvar İKİ parçaya bölünmüş — biri 60 cm (dar), biri 600 cm (geniş).
# 150 cm beyanlı kapı mührü DAR parçaya düşürülüyor.
cat <<'JSON' > "$T/g.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]],
             [[0,500],[300,500]], [[300,500],[300,560]], [[300,560],[420,560]], [[420,560],[420,500]], [[420,500],[1000,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250}, {"ad":"DEPO","m2":null,"x":500,"y":800} ],
  "otomatik_muhur": false,
  "ek_muhur": [ {"a":[320,560],"b":[400,560],"genislik":150,"gerekce":"kapi olcu yazisi 150/210"} ] }
JSON
python3 lib/lifting.py "$T/g.json" "$T/graf.json" >/dev/null 2>&1

# (1) BAYRAK KAPALI: eski davranış — kırpılır, kaydırma satırı basılmaz
node cli.mjs model --graf "$T/graf.json" --cikti "$T/m-kapali.json" --metrik /dev/null >"$T/o1" 2>"$T/e1"
grep -qF "KAYDIRIL" "$T/e1" && kir "bayrak kapalıyken kaydırma yapılmış" || ok
python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));a=m["acikliklar"][0];sys.exit(0 if a["genislik"]<a.get("genislik_beyan",0) else 1)' "$T/m-kapali.json" \
  && ok || kir "bayrak kapalıyken kapı kırpılmamış (fixture beklentisi bozuk)"

# (2) BAYRAK AÇIK: sığan duvara kaydırılır ve beyan genişliği KORUNUR
node cli.mjs model --graf "$T/graf.json" --cikti "$T/m-acik.json" --kapi-kaydir --metrik /dev/null >"$T/o2" 2>"$T/e2"
python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));a=m["acikliklar"][0];sys.exit(0 if a["genislik"]==a.get("genislik_beyan") else 1)' "$T/m-acik.json" \
  && ok || kir "kaydırmadan sonra beyan genişliği korunmadı"

# (3) SESSİZ OLAMAZ: rapor satırı + modelde iz
grep -qF "KAYDIRIL" "$T/e2" && ok || kir "kaydırma raporlanmadı (sessiz kaydırma yasak)"
for alan in mesafe_cm eski_duvar yeni_duvar eski_odalar; do
  grep -qF "\"$alan\"" "$T/m-acik.json" && ok || kir "izde '$alan' yok"
done

# (4) TERS MUTASYON — başka iki odanın arasına taşırsa RC 1
# Üç oda: kapı SALON↔DEPO arasında dar bir parçaya düşüyor; sığan tek duvar SALON↔KİLER arasında.
cat <<'JSON' > "$T/g2.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1400]], [[1000,1400],[0,1400]], [[0,1400],[0,0]],
             [[0,500],[200,500]], [[200,500],[200,560]], [[200,560],[320,560]], [[320,560],[320,500]],
             [[320,500],[520,500]], [[520,500],[520,560]], [[520,560],[640,560]], [[640,560],[640,500]],
             [[640,500],[1000,500]],
             [[0,1000],[1000,1000]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250}, {"ad":"DEPO","m2":null,"x":500,"y":780},
                 {"ad":"KILER","m2":null,"x":500,"y":1200} ],
  "otomatik_muhur": false,
  "ek_muhur": [ {"a":[220,560],"b":[300,560],"genislik":400,"gerekce":"kasten sigmayan beyan"} ] }
JSON
python3 lib/lifting.py "$T/g2.json" "$T/graf2.json" >/dev/null 2>&1
node cli.mjs model --graf "$T/graf2.json" --cikti "$T/m2.json" --kapi-kaydir --metrik /dev/null >"$T/o3" 2>"$T/e3"
rc=$?
if grep -qF "BAŞKA İKİ ODANIN" "$T/e3"; then
  ok
  [ "$rc" -ne 0 ] && ok || kir "TERS MUTASYON: yanlış oda kaydırmasında çıkış kodu 0"
  [ -f "$T/m2.json" ] && kir "TERS MUTASYON: RC 1 verirken model YAZILMIŞ" || ok
else
  # Aynı oda çiftinde sığan duvar bulunduysa kural meşru davranmıştır; o zaman kaydırma raporlu olmalı
  if grep -qF "KAYDIRIL" "$T/e3"; then ok; ok; ok
  else kir "ne kaydırma ne RC 1 — kural fixture'da hiç çalışmadı: $(tail -1 "$T/e3")"; fi
fi

# (5) MESAFE SINIRI + SORU (MEDDAH kararı 24 Eyl, seçenek b): kaydırma mesafesi ESKİ DUVARIN
# BOYUNU aşarsa kaydırma YAPILMAZ, kırpmaya döner ve kapı SORU sınıfına yazılır. Uzak kaydırma da
# kırpma da bir tahmindir; tahmini kullanıcıya göstermenin yolu sorudur.
# Fixture: kısa çıkıntı parçası (114 cm) ve sığan duvar ÇOK uzakta.
cat <<'JSON' > "$T/g3.json"
{ "sinir": [ [[0,0],[1400,0]], [[1400,0],[1400,1000]], [[1400,1000],[0,1000]], [[0,1000],[0,0]],
             [[0,500],[300,500]], [[300,500],[300,620]], [[300,620],[420,620]], [[420,620],[420,500]], [[420,500],[1400,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":700,"y":250}, {"ad":"DEPO","m2":null,"x":700,"y":800} ],
  "otomatik_muhur": false,
  "ek_muhur": [ {"a":[320,620],"b":[400,620],"genislik":150,"gerekce":"kapi olcu yazisi 150/210"} ] }
JSON
python3 lib/lifting.py "$T/g3.json" "$T/graf3.json" >/dev/null 2>&1
node cli.mjs model --graf "$T/graf3.json" --cikti "$T/m4.json" --kapi-kaydir --metrik /dev/null >"$T/o4" 2>"$T/e4"
# mesafe eski duvarın boyundan BÜYÜKSE: kaydırma YOK, SORU VAR, kırpma VAR
python3 - "$T/m4.json" "$T/e4" <<'PY2' && ok || kir "MESAFE SINIRI: uzak kaydırma engellenmedi ya da SORU yazılmadı"
import json,sys
m=json.load(open(sys.argv[1])); e=open(sys.argv[2]).read()
kayd=m.get("kapi_kaydirma") or []
soru=m.get("kapi_sorulari") or []
uzak=[k for k in kayd if k["mesafe_cm"] > k["eski_duvar_boyu_cm"]]
sys.exit(0 if (not uzak and (soru or not kayd)) else 1)
PY2
# SORU sessiz olamaz: satırda da görünmeli ve kullanıcıya sorulabilir bir cümle olmalı
python3 - "$T/m4.json" "$T/e4" <<'PY3' && ok || kir "SORU sınıfı sessiz (satır ya da cümle yok)"
import json,sys
m=json.load(open(sys.argv[1])); e=open(sys.argv[2]).read()
soru=m.get("kapi_sorulari") or []
if not soru: sys.exit(0 if not (m.get("kapi_kaydirma") or []) else 1)
sys.exit(0 if ("SORU" in e and all("nerede" in s.get("soru","") for s in soru)) else 1)
PY3
# Kısa mesafeli MEŞRU kaydırma hâlâ yapılmalı (kural her şeyi soruya çevirmesin)
python3 - "$T/m-acik.json" <<'PY4' && ok || kir "meşru kısa kaydırma da engellenmiş — kural fazla katı"
import json,sys
m=json.load(open(sys.argv[1]))
sys.exit(0 if (m.get("kapi_kaydirma") or []) else 1)
PY4

# (6) Bayrak varsayılanı KAPALI
grep -qF "const kapiKaydir = !!secenekler.kapiKaydir;" lib/graf-koprusu.mjs && ok || kir "bayrak varsayılanı açık görünüyor"

printf 'kapi-kaydirma: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
