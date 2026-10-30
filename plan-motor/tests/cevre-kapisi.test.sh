#!/usr/bin/env bash
# cevre-kapisi.test.sh — ÇEPER (dış hat) kapısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN VAR: gerçek bir market çiziminde (2026-09-16) dış çeper HİÇBİR katmanda kapalı
# çizili değildi; lifting doğru olarak durdu ama yalnız "sınır kapalı değil" dedi. Bu cümle
# kullanıcıya hedefli soru ürettirmez. Kapı artık NEREDE açık olduğunu (kenar + aralık)
# basar, ve çeper BEYANI (ek_cevre) ile kapatılabilir. Beyan ölçüm değildir: çıktıya iz düşer.
#
# DEĞİŞMEZ: bu betik TELLAL reposuna bağlı DEĞİL ve müşteri dosyası KULLANMAZ — fixture sentetik.
# Kullanım: bash tests/cevre-kapisi.test.sh   ·   Exit: 0 tuttu · 1 kırıldı
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }
bek_rc() { local b="$1" ad="$2"; shift 2; "$@" >"$T/o" 2>"$T/e"; local r=$?; [ "$r" -eq "$b" ] && ok || kir "$ad (beklenen RC=$b, gelen $r)"; }
bek_metin() { local m="$1" ad="$2" d="$3"; grep -qF -- "$m" "$d" && ok || kir "$ad — '$m' yok: $(tail -2 "$d" | tr '\n' ' ')"; }

# Fixture: 1000×1000 cm, ortadan bölünmüş İKİ oda (motorun "%75'ten büyük bölge = kaçak"
# sezgisi tek odalı fixture'ı kaçak sanır; gerçek çizim de çok odalıdır). GÜNEY kenarında
# SALON altında x=400..540 arası 140 cm AĞIZ açık; MUTFAK kapalı.
kare_json() {  # $1 = ek_cevre bloğu (boş olabilir)
  cat <<JSON
{ "sinir": [
    [[0,0],[400,0]], [[540,0],[1000,0]],
    [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]],
    [[0,500],[1000,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250}, {"ad":"MUTFAK","m2":null,"x":500,"y":750} ]$1 }
JSON
}
kare_json "" > "$T/acik.json"
kare_json ', "ek_cevre": [[0,0],[1000,0],[1000,1000],[0,1000]], "ek_cevre_gerekce": "guney vitrin agzi; cephe hatti musteri beyani"' > "$T/beyanli.json"
kare_json ', "ek_cevre": [[0,0],[10,0],[10,10],[0,10]], "ek_cevre_gerekce": "yanlis yerde beyan"' > "$T/yanlis-beyan.json"
kare_json ', "ek_cevre": [[0,0],[1000,0]]' > "$T/eksik-beyan.json"

# 1) Açık çeper: fail-closed + NEREDE açık olduğu
bek_rc 1 "açık çeper RC=1" python3 lib/lifting.py "$T/acik.json" "$T/acik-out.json"
python3 lib/lifting.py "$T/acik.json" "$T/acik-out.json" >/dev/null 2>"$T/e1"
bek_metin "çeper taraması" "tarama başlığı basılıyor" "$T/e1"
bek_metin "GUNEY" "açık kenarın ADI basılıyor" "$T/e1"
# Aralık ızgara payıyla (±4 cm) okunur: 140 cm'lik ağız 132..148 arasında ölçülmeli
_uz=$(grep -oE 'GUNEY.*\(([0-9]+) cm\)' "$T/e1" | grep -oE '\(([0-9]+) cm\)' | head -1 | tr -dc 0-9)
[ -n "${_uz:-}" ] && [ "$_uz" -ge 132 ] && [ "$_uz" -le 148 ] && ok || kir "açık ARALIK uzunluğu 140±8 cm okunmalı (gelen: '${_uz:-yok}')"
bek_metin "x=" "aralık EKSENLİ basılıyor" "$T/e1"
bek_metin "özet: 4 kenarın 1'inde" "yalnız GÜNEY açık — özet doğru sayıyor" "$T/e1"
bek_metin "ek_cevre" "kapatma yolu söyleniyor" "$T/e1"
bek_rc 1 "açık çeperde çıktı dosyası YAZILMAZ" test -s "$T/acik-out.json"

# 2) Çeper beyanı ile kapanır ve BEYAN olduğu çıktıya düşer
bek_rc 0 "ek_cevre ile kapanır RC=0" python3 lib/lifting.py "$T/beyanli.json" "$T/beyan-out.json"
bek_metin '"kaynak": "ek_cevre"' "çıktıda beyanın KAYNAĞI var" "$T/beyan-out.json"
bek_metin "cephe hatti musteri beyani" "beyanın GEREKÇESİ kayda geçer" "$T/beyan-out.json"
bek_metin '"ad": "MUTFAK"' "beyanla kapanınca İKİ oda da çıkar" "$T/beyan-out.json"

# 3) MUTASYON: beyan tek başına kapıyı kandıramaz
bek_rc 1 "yanlış yerde beyan kapıyı KANDIRMAZ" python3 lib/lifting.py "$T/yanlis-beyan.json" "$T/y-out.json"
bek_rc 1 "2 köşeli ek_cevre REDDEDİLİR" python3 lib/lifting.py "$T/eksik-beyan.json" "$T/e-out.json"

# 4) Kutu dışı etiket (başlık bloğu notu) çökme değil UYARI + atlama
kare_json ', "ek_cevre": [[0,0],[1000,0],[1000,1000],[0,1000]]' | sed 's/{"ad":"MUTFAK"/{"ad":"NOT","m2":null,"x":9000,"y":9000}, {"ad":"MUTFAK"/' > "$T/disarida.json"
bek_rc 0 "kutu dışı etiket ÇÖKERTMEZ, RC=0" python3 lib/lifting.py "$T/disarida.json" "$T/d-out.json"
python3 lib/lifting.py "$T/disarida.json" "$T/d-out.json" >/dev/null 2>"$T/e4"
bek_metin "kutu dışında atlandı" "kutu dışı etiket UYARIYLA sayılır" "$T/e4"
bek_rc 1 "kutu dışı etiket odaya DÖNÜŞMEZ" grep -q '"ad": "NOT"' "$T/d-out.json"

# 5) İÇ BÖLME BEYANI (ek_bolme): kapalı çeper içinde oda AYIRIR, iz bırakır, kandırılamaz
cat <<JSON > "$T/bolme.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":300,"y":500}, {"ad":"DEPO","m2":null,"x":800,"y":500} ],
  "ek_bolme": [ {"a":[600,0],"b":[600,1000]} ], "ek_bolme_gerekce": "insan mudahalesi: karisik katman" }
JSON
bek_rc 0 "ek_bolme iki odayı AYIRIR, RC=0" python3 lib/lifting.py "$T/bolme.json" "$T/b-out.json"
bek_metin '"kaynak": "ek_bolme"' "bölme beyanı çıktıya iz bırakır" "$T/b-out.json"
bek_metin "insan mudahalesi" "bölme beyanının gerekçesi kayda geçer" "$T/b-out.json"
sed 's/\[600,0\],"b":\[600,1000\]/[900,0],"b":[900,300]/' "$T/bolme.json" > "$T/bolme-yanlis.json"
bek_rc 1 "MUTASYON: odaları ayırmayan bölme beyanı kapıyı KANDIRMAZ" python3 lib/lifting.py "$T/bolme-yanlis.json" "$T/by-out.json"

# 6) OTOMATİK MÜHÜR ANAHTARI: kapalıyken ağız yalnız beyandan gelir
cat <<JSON > "$T/oto.json"
{ "sinir": [ [[0,0],[400,0]], [[540,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]], [[0,500],[1000,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250}, {"ad":"MUTFAK","m2":null,"x":500,"y":750} ], "otomatik_muhur": false }
JSON
bek_rc 1 "otomatik mühür KAPALI + beyan yok → açık ağız sızdırır (RC 1)" python3 lib/lifting.py "$T/oto.json" "$T/oto-out.json"
python3 lib/lifting.py "$T/oto.json" "$T/oto-out.json" >/dev/null 2>"$T/e6o"
bek_metin "otomatik mühür KAPALI" "anahtarın kapalı olduğu kayda geçer" "$T/e6o"
sed 's/"otomatik_muhur": false/"otomatik_muhur": false, "ek_muhur": [{"a":[400,0],"b":[540,0],"gerekce":"kapi beyani"}]/' "$T/oto.json" > "$T/oto2.json"
bek_rc 0 "otomatik KAPALI + beyan edilen ağız → oda çıkar" python3 lib/lifting.py "$T/oto2.json" "$T/oto2-out.json"

printf 'cevre-kapisi: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
