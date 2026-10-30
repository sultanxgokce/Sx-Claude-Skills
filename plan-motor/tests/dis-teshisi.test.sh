#!/usr/bin/env bash
# dis-teshisi.test.sh — `--dis-teshis`: karşı yüzü olmayan yüz gerçekten DIŞ DUVAR mı?
#
# 🔴 NEDEN VAR (ölçüldü 2026-09-24, gerçek market planı): köprü `tip`i tek soruyla veriyordu
# (karşı yüzü var mı?) ve yoksa doğrudan dış-duvar VARSAYILANINI yazıyordu. O planda 264 duvarın
# 236'sı `dis` ve 236'sının kalınlığı aynı 20,0 cm — ayar beyanı, ölçüm değil. Eşleştirme süzgeci
# "aynı oda" yüzlerini atladığı için, salonun SARDIĞI gerçek duvar çiftleri de eşleşemiyordu;
# ikisi de uydurma 20 cm alıyor, gövdeler üst üste biniyor ve 3B ölçü kapısı kalınlık sapması
# basıyordu. Bayrak açıkken: aynı-oda çiftleri de ÖLÇÜLÜR, geri kalan yüzler SINIFLANIR.
#
# DEĞİŞMEZLER: fixture sentetik (müşteri dosyası YOK) · bayrak varsayılan KAPALI · eşik uydurulmaz.
# MEDDAH şart 5 (TERS MUTASYON): iki yanında oda olan yüz asla KILÇIK sayılıp düşürülemez.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }
var() { grep -qF -- "$1" "$3" && ok || kir "$2"; }
yok() { grep -qF -- "$1" "$3" && kir "$2" || ok; }

# ── FIXTURE 1: YARIMADA (odanın SARDIĞI duvar) ───────────────────────────────────
# SALON'un içine bir yarımada duvar sokuluyor (x=500 ve x=520 arası, y=0..400). Odanın halkası
# bu yarımadanın ETRAFINDAN dolanır, yani duvarın İKİ YÜZÜ de SALON'a bakar. Eski süzgeç
# "aynı oda" diye atlıyordu → iki yüz de uydurma dış varsayılanını alıyordu. Siirt marketinde
# ölçülen desen bu. DEPO odası ayrıca var: tek odalı fixture ">%75 = kaçak" kuralına takılır.
cat <<'JSON' > "$T/g1.json"
{ "sinir": [
    [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]],
    [[0,700],[1000,700]],
    [[500,0],[500,400]], [[520,0],[520,400]], [[500,400],[520,400]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":200,"y":200}, {"ad":"DEPO","m2":null,"x":500,"y":850} ],
  "otomatik_muhur": false }
JSON
python3 lib/lifting.py "$T/g1.json" "$T/graf1.json" >/dev/null 2>&1 || echo "  ✗ lifting fixture-1 koşmadı"
# (1) BAYRAK KAPALI: eski davranış birebir korunur
node cli.mjs model --graf "$T/graf1.json" --cikti "$T/m-kapali.json" --metrik /dev/null >"$T/o1" 2>"$T/e1"
yok 'dış teşhisi' "bayrak kapalıyken teşhis satırı BASILMAZ (varsayılan değişmedi)" "$T/e1"
yok '"dis_teshis"' "bayrak kapalıyken modele iz YAZILMAZ" "$T/m-kapali.json"
# (2) BAYRAK AÇIK: teşhis koşar ve iz bırakır
node cli.mjs model --graf "$T/graf1.json" --cikti "$T/m-acik.json" --dis-teshis --metrik /dev/null >"$T/o2" 2>"$T/e2"
var 'dış teşhisi (--dis-teshis)' "bayrak açıkken teşhis satırı basılır" "$T/e2"
var '"dis_teshis"' "modelde teşhis izi var" "$T/m-acik.json"
var '"ozet"' "izde özet var" "$T/m-acik.json"
# (3) UYDURMA KALINLIK YERİNE ÖLÇÜM: yarımada çifti eşleşince `ic` sayısı ARTAR
ic_kapali=$(python3 -c 'import json,sys;print(sum(1 for d in json.load(open(sys.argv[1]))["duvarlar"] if d["tip"]=="ic"))' "$T/m-kapali.json")
ic_acik=$(python3 -c 'import json,sys;print(sum(1 for d in json.load(open(sys.argv[1]))["duvarlar"] if d["tip"]=="ic"))' "$T/m-acik.json")
if [ "$ic_acik" -gt "$ic_kapali" ]; then ok; else kir "yarımadanın iki yüzü eşleşmedi (ic $ic_kapali → $ic_acik)"; fi
# (4) MUTASYON: yarımadayı kaldır → aynı-oda eşleşmesi OLMAMALI (kural boşlukta çalışmaz)
python3 - "$T/g1.json" "$T/g1m.json" <<'PY2'
import json,sys
g=json.load(open(sys.argv[1]))
g["sinir"]=[s for s in g["sinir"] if not (s[0][0] in (500,520) or s[1][0] in (500,520))]
json.dump(g,open(sys.argv[2],"w"))
PY2
python3 lib/lifting.py "$T/g1m.json" "$T/graf1m.json" >/dev/null 2>&1
node cli.mjs model --graf "$T/graf1m.json" --cikti "$T/m1m.json" --dis-teshis --metrik /dev/null >"$T/o4" 2>"$T/e4"
ic_m=$(python3 -c 'import json,sys;print(sum(1 for d in json.load(open(sys.argv[1]))["duvarlar"] if d["tip"]=="ic"))' "$T/m1m.json")
if [ "$ic_m" -lt "$ic_acik" ]; then ok; else kir "MUTASYON: yarımada yokken de aynı-oda çifti üretildi (ic $ic_m)"; fi
# (5) Ölçülen kalınlık dış varsayılanına EŞİT DEĞİL (uydurma sayıya geri dönmedik)
python3 - "$T/m-acik.json" <<'PY3' && ok || kir "yarımada kalınlığı ölçülmemiş görünüyor"
import json,sys
m=json.load(open(sys.argv[1]))
ic=sorted({d["kalinlik"] for d in m["duvarlar"] if d["tip"]=="ic"})
sys.exit(0 if len(ic) >= 2 else 1)   # en az iki AYRI ölçülmüş kalınlık: 6 (oda ciftinin) + yarimada
PY3

# ── FIXTURE 2: TERS MUTASYON (MEDDAH şart 5) ──────────────────────────────────────
# İki oda tek çizgiyi ARALIKSIZ paylaşıyor (kalınlık 0). Bu GERÇEK bir bölmedir, kalınlığı
# bilinmez → SORU sınıfına düşmeli, ASLA kılçık sayılıp düşürülmemeli.
cat <<'JSON' > "$T/g2.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]],
             [[0,500],[1000,500]] ],
  "etiketler": [ {"ad":"ODA-A","m2":null,"x":500,"y":250}, {"ad":"ODA-B","m2":null,"x":500,"y":750} ],
  "otomatik_muhur": false }
JSON
python3 lib/lifting.py "$T/g2.json" "$T/graf2.json" >/dev/null 2>&1
node cli.mjs model --graf "$T/graf2.json" --cikti "$T/m2.json" --dis-teshis --metrik /dev/null >"$T/o3" 2>"$T/e3"
# Paylaşılan yüz ya `ic` olarak ÖLÇÜLÜR ya da SORU olur; her iki hâlde de KAYBOLMAZ.
python3 - "$T/m2.json" <<'PY' && ok || kir "TERS MUTASYON: iki oda arasındaki gerçek bölme kayboldu"
import json,sys
m=json.load(open(sys.argv[1]))
t=(m.get("dis_teshis") or {}).get("ozet",{})
kayit=(m.get("dis_teshis") or {}).get("kayit",[])
dusen=[k for k in kayit if k["sinif"]=="kilcik"]
# iki odanın PAYLAŞTIĞI hiçbir yüz kılçık diye düşmemeli
sys.exit(0 if not dusen else 1)
PY
python3 - "$T/m2.json" <<'PY' && ok || kir "iki oda arasındaki sınır modelde duvar olarak yok"
import json,sys
m=json.load(open(sys.argv[1]))
# y=500 hattında duvar var mı (model Y-aşağı çevirir; hattın kendisi korunur)
P=m["noktalar"]
say=0
for d in m["duvarlar"]:
    a,b=P[d["bas"]],P[d["son"]]
    if abs(a[1]-b[1])<1e-6 and 400 < a[1] < 600: say+=1
sys.exit(0 if say else 1)
PY
# (5) SORU sınıfı sessiz olamaz: varsa uyarı satırı basılmalı
python3 - "$T/m2.json" "$T/e3" <<'PY' && ok || kir "SORU sınıfı var ama uyarı satırı basılmadı"
import json,sys
m=json.load(open(sys.argv[1])); e=open(sys.argv[2]).read()
n=(m.get("dis_teshis") or {}).get("ozet",{}).get("soru_paylasilan_yuz",0)
sys.exit(0 if (n==0 or "PAYLAŞTIĞI" in e) else 1)
PY

# ── FIXTURE 3: FAIL-CLOSED ────────────────────────────────────────────────────────
# Teşhis bütün duvarları yutarsa model YAZILMAZ (sessiz boş plan yasak) — kod yolu var mı?
grep -qF 'bütün duvarları düşürdü — model YAZILMADI' lib/graf-koprusu.mjs && ok || kir "fail-closed dalı yok"
# (6) Açıklık taşıyan yüz kılçık bile olsa DÜŞMEZ — kod yolu + iz sınıfı
grep -qF 'kilcik_ama_aciklik_tasiyor' lib/graf-koprusu.mjs && ok || kir "açıklık koruması yok"
# (7) Bayrak varsayılanı KAPALI (SEDİR'in davranışı sessizce değişmesin)
grep -qF "const disTeshis = !!secenekler.disTeshis;" lib/graf-koprusu.mjs && ok || kir "bayrak varsayılanı açık görünüyor"

printf 'dis-teshisi: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
