#!/usr/bin/env bash
# gun-sonu.test.sh — hermetik: sahte depo + sahte defterler + sahte GÖREV defteri (jeton kapılı http, D1–D8); GERÇEK deftere dokunmaz.
# Ağırlık merkezi: SAAT KAYMASI. Defterler dünya saatiyle damgalanır, süzgeç yerel günle
# çalışır; aradaki fark her gün 3 saatlik KÖR PENCERE açıyordu (ölçülmüş canlı vaka:
# 7 Ekim yerel 00:55 ve 01:11'deki iki kapı kaçışı 7 Ekim özetinde HİÇ görünmedi).
set -uo pipefail

# 🔴 SAAT DİLİMİ ÇİVİLENİR — ve bunu bir kez CI'da düşerek öğrendim.
#   Bu sınav SAAT KAYMASINI ölçüyor; kayma ancak yerel saat ile dünya saati FARKLIYSA
#   vardır. CI dünya saatinde koşuyor; orada ikisi aynı olduğu için senaryo hiç kurulmuyor
#   ve sınav kendi fikstürünü kuramadığı için kırmızı yanıyordu. Yani sonuç ORTAMA bağlıydı
#   — oysa sonucu ortama bağlı olan bir şey ölçüm değildir, bu filoda ölçülmüş bir derstir.
#   Çözüm: dilimi SINAV seçer, ortamdan devralmaz. (Onarımın kendisi dilimden bağımsızdır;
#   çivilenen yalnız fikstürün koşullarıdır.)
export TZ="${GUN_SONU_SINAV_TZ:-Europe/Istanbul}"
_ofs="$(date +%z)"
if [ "$_ofs" = "+0000" ]; then
  echo "ATLANDI: seçilen dilim ($TZ) dünya saatiyle aynı ofsette — kayma senaryosu kurulamaz."
  echo "  (Bu bir YEŞİL DEĞİLDİR: ölçüm yapılmadı. Dilim verisi kurulu mu bakın.)"
  exit 3
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="${MUTANT:-$HERE/gun-sonu.sh}"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; GUN="$(date +%F)"
export DEFTER_JETON_YOL="$T/jeton-yok"   # görev defteri bölümü (0.18.0 #422) varsayılan jetonla GERÇEK defteri okur; Ö-sınavları ona dokunmasın (D-sınavları kendi sahte defterini verir)
mkdir -p "$T/_agents/fabrika/kartlar" "$T/pkg"; cp "$HERE"/*.py "$T/pkg/"   # mutantlar TAM kopyada koşar (izin.py kardeş; 0.19.0)
( cd "$T" && git init -q -b olcum . ) >/dev/null 2>&1
cat > "$T/_agents/fabrika/kartlar/sinav.json" <<KART
{"is":"sinav","cumle":"sınav kartı","istedi":"sinav","aldi":"sinav",
 "zaman":"${GUN}T10:00:00+03:00","sinif_cevaplari":{},"siniflar":[],"sultan":false,
 "durum":"bitti","bitis":"${GUN}T11:00:00+03:00","gecmis":[],"pr":"","puan":null,"kanit_var":false}
KART

# YEREL bir saati DÜNYA damgasına çevirir — dilim ortamdan gelir, ÇİVİLENMEZ.
dunya() { python3 -c "
import datetime,sys
print(datetime.datetime.fromisoformat(sys.argv[1]+'T'+sys.argv[2]).astimezone()
      .astimezone(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$GUN" "$1"; }
ozet() { ( cd "$T" && bash "$G" --gun "$GUN" 2>&1 ); }
say() { printf '%s' "$1" | sed -n "s/^## $2 (\([0-9]*\)).*/\1/p" | head -1; }

GECE="$(dunya 01:11:00)"; GUNDUZ="$(dunya 14:30:00)"
echo "════ Ö0 · senaryo kurulabiliyor mu (tautoloji panzehiri) ════"
[ "${GECE:0:10}" != "$GUN" ]; g $? "Ö0 yerel gece saati FARKLI dünya-gününe düşüyor — dilim çivili, her ortamda aynı"

echo "════ Ö1 · YEREL GECE olayı o günün özetinde GÖRÜNÜR ════"
printf '%s | KAPISIZ | gece-kacisi | komut-A\n' "$GECE"   > "$T/_agents/fabrika/kacis-defteri.log"
printf '%s | TAVAN-ACILDI | is=x tur=4 | gece-tavani\n' "$GECE" > "$T/_agents/fabrika/tavan-defteri.log"
O="$(ozet)"
[ "$(say "$O" 'Kapı kaçışları')" = 1 ]; g $? "Ö1a gece kaçışı sayılıyor"
[ "$(say "$O" 'Tavan açılışları')" = 1 ]; g $? "Ö1b gece tavan açılışı sayılıyor"
grep -q 'gece-kacisi' <<<"$O"; g $? "Ö1c gerekçesi basılıyor"
# A268 (8 Eki): reis açılışı Sultan açılışından AYIRT EDİLEREK görünür; ikisi de sayılır
printf '%s | TAVAN-ACILDI-REIS | is=y tur=4 | reis-gerekcesi-uzun\n' "$GECE" >> "$T/_agents/fabrika/tavan-defteri.log"
O="$(ozet)"
[ "$(say "$O" 'Tavan açılışları')" = 2 ]; g $? "Ö1d reis açılışı da sayılıyor (2)"
grep -qE 'is=y tur=4 · reis kararı \(sınıfsız iş\) · gerekçe: reis-gerekcesi-uzun' <<<"$O"; g $? "Ö1e reis açılışı 'reis kararı (sınıfsız iş)' etiketiyle basılıyor"
grep -qE 'is=x tur=4 · Sultan kararı · gerekçe: gece-tavani' <<<"$O"; g $? "Ö1f Sultan açılışı 'Sultan kararı' etiketiyle basılıyor (karışmıyor)"
# 0.19.0: sınıflı işte reis açılışı 3. sütundaki sinif= izin= ile ayırt edilir
printf '%s | TAVAN-ACILDI-REIS | is=z tur=4 sinif=para izin=basla | reis-sinifli-gerekce\n' "$GECE" >> "$T/_agents/fabrika/tavan-defteri.log"
O="$(ozet)"
grep -qE 'is=z tur=4 sinif=para izin=basla · reis kararı \(sınıflı iş: para · izin: basla\) · gerekçe: reis-sinifli-gerekce' <<<"$O"; g $? "Ö1g sınıflı işte reis açılışı 'reis kararı (sınıflı iş: para · izin: basla)' etiketiyle (0.19.0)"
grep -q "sınıflı işte de reisin, veto hakkın var" <<<"$O"; g $? "Ö1h tavan başlığı sınıflı işte de reisin olduğunu ve veto hakkını söyler"
printf '%s | TAVAN-ACILDI | is=x tur=4 | gece-tavani\n' "$GECE" > "$T/_agents/fabrika/tavan-defteri.log"; O="$(ozet)"

echo "════ Ö2 · basılan SAAT yerel olmalı (Sultan 01:11'i 22:11 okumamalı) ════"
grep -qE '^- 01:11 · gerekçe' <<<"$O"; g $? "Ö2 saat YEREL basılıyor (01:11) — kaçış satırı (biçimi: saat · gerekçe · komut)"
# tavan satırının biçimi farklıdır (saat · iş/tur · kim · gerekçe) — denetim tur 3: iki satır türü ayrı ayrı sınanır
grep -qE '^- 01:11 · is=x tur=4 · Sultan kararı · gerekçe: gece-tavani' <<<"$O"; g $? "Ö2b tavan satırı da yerel saatle ve karar etiketiyle basılıyor"

echo "════ Ö3 · GÜNDÜZ olayı da görünür (onarım geceyi alıp gündüzü düşürmedi) ════"
printf '%s | KAPISIZ | gunduz-kacisi | komut-B\n' "$GUNDUZ" > "$T/_agents/fabrika/kacis-defteri.log"
O3="$(ozet)"
[ "$(say "$O3" 'Kapı kaçışları')" = 1 ]; g $? "Ö3a gündüz kaçışı sayılıyor"
grep -qE '^- 14:30 · gerekçe' <<<"$O3"; g $? "Ö3b gündüz saati de yerel"

echo "════ Ö4 · BAŞKA GÜNÜN olayı SAYILMAZ (süzgeç hâlâ süzüyor) ════"
DUN="$(date -d "$GUN -1 day" +%F)"
printf '%sT12:00:00Z | KAPISIZ | dunun-kacisi | komut-C\n' "$DUN" > "$T/_agents/fabrika/kacis-defteri.log"
O4="$(ozet)"
[ "$(say "$O4" 'Kapı kaçışları')" = 0 ]; g $? "Ö4a dünün kaçışı bugüne KARIŞMIYOR"
grep -q 'bugün kapı atlanmadı' <<<"$O4"; g $? "Ö4b boş hâli açıkça söyleniyor"

echo "════ Ö5 · ÇÖZÜLEMEYEN damga sessizce DÜŞMEZ (unknown ≠ yok) ════"
printf 'tarihsiz bir satir | KAPISIZ | bozuk | komut-D\n' > "$T/_agents/fabrika/kacis-defteri.log"
O5="$(ozet)"
[ "$(say "$O5" 'Kapı kaçışları')" = 0 ]; g $? "Ö5a bugünkü sayıya girmiyor"
grep -q 'ÇÖZÜLEMEDİ' <<<"$O5"; g $? "Ö5b çözülemediği SÖYLENİYOR (sessiz atlama yok)"
grep -q '1 satırın tarihi' <<<"$O5"; g $? "Ö5c kaç satır olduğu yazılı"

echo "════ Ö6 · DİLİMLİ (yerel) damga da doğru okunur — eski/karışık defter ════"
printf '%sT01:11:00+03:00 | KAPISIZ | dilimli | komut-E\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O6="$(ozet)"
[ "$(say "$O6" 'Kapı kaçışları')" = 1 ]; g $? "Ö6 açık dilimli damga da bugüne sayılıyor"

echo "════ Ö9 · YABANCI DİLİM: saat de çevrilmeli, gün de (göz tur-1) ════"
# 🔴 Fikstür BİLEREK kendi dilimimizden DEĞİL: +03:00 kullanmak açığı örter, çünkü
#    çevrilmemiş saat yerel saatle aynı çıkar. Çevrim gerçekten koşuyor mu, ancak
#    yabancı bir dilimle görünür. +00:00 = yerelde 03:00 (biz +03'teyiz).
printf '%sT00:00:00+00:00 | KAPISIZ | yabanci-dilim | komut-F\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O9="$(ozet)"
BEK="$(python3 -c "
import datetime,sys
t=datetime.datetime.fromisoformat(sys.argv[1]+'T00:00:00+00:00').astimezone()
print(t.strftime('%Y-%m-%d'), t.strftime('%H:%M'))" "$GUN")"
BEK_GUN="${BEK%% *}"; BEK_SAAT="${BEK##* }"
if [ "$BEK_GUN" = "$GUN" ]; then
  [ "$(say "$O9" 'Kapı kaçışları')" = 1 ]; g $? "Ö9a yabancı dilimli damga doğru güne sayılıyor"
  grep -qE "^- $BEK_SAAT · gerekçe" <<<"$O9"; g $? "Ö9b saat YEREL'e çevrilmiş basılıyor ($BEK_SAAT, ham 00:00 değil)"
  grep -qE '^- 00:00 · gerekçe' <<<"$O9"; [ $? -ne 0 ]; g $? "Ö9c ham dilim saati BASILMIYOR"
else
  g 0 "Ö9 ATLANDI: bu dilimde yabancı damga başka güne düşüyor (fikstür kurulamadı)"
fi

echo "════ Ö10 · BOZUK DİLİM özeti ÇÖKERTMEZ (göz tur-1: try kapsamı dardı) ════"
printf '%sT01:11:00+99:00 | KAPISIZ | bozuk-dilim | komut-G\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
O10="$(ozet)"; RC10=$?
[ "$RC10" -eq 0 ]; g $? "Ö10a özet yine üretiliyor (çökmüyor)"
grep -q 'ÇÖZÜLEMEDİ' <<<"$O10"; g $? "Ö10b bozuk satır ÇÖZÜLEMEDİ diye sayılıyor"
[ "$(say "$O10" 'Kapı kaçışları')" = 0 ]; g $? "Ö10c bugüne sayılmıyor"
grep -q 'Açık işler' <<<"$O10"; g $? "Ö10d özetin SONRAKİ bölümleri de üretildi (akış kesilmedi)"

echo "════ Ö14 · 0.19.0: sınıflı kart — 'Sultan'a gidenler — başlama izni / veto', izin etiketi, reisin sınıflı kararları bölümü, içeride bitenlerde sınıflı bitti ════"
cat > "$T/_agents/fabrika/kartlar/sinifli.json" <<KART
{"is":"sinifli","cumle":"para harcayan iş","istedi":"S","aldi":"M","zaman":"${GUN}T10:00:00+03:00","sinif_cevaplari":{},"siniflar":["para"],"sultan":true,
 "durum":"acik","gecmis":[],"pr":"","puan":null,"kanit_var":false,"baslama_izni":{"durum":"dur","oturum":"sohbet-1","soz":"durun","beyan":"M"},
 "reis_kararlari":[{"karar":"devam","reis":"M","oturum":"r","gerekce":"reis-gerekce-uzun-metin","zaman":"${GUN}T11:00:00+03:00","sinifli":true,"izin":"bekliyor"},{"karar":"daralt","reis":"M","oturum":"r","gerekce":"sinifsiz-gibi","zaman":"${GUN}T11:30:00+03:00"}]}
KART
cat > "$T/_agents/fabrika/kartlar/sinifli-bitti.json" <<KART
{"is":"sinifli-bitti","cumle":"dış yüzey işi","istedi":"S","aldi":"M","zaman":"${GUN}T09:00:00+03:00","sinif_cevaplari":{},"siniflar":["dis_yuzey"],"sultan":true,
 "durum":"bitti","bitis":"${GUN}T12:00:00+03:00","gecmis":[],"pr":"41","puan":{"kod":5,"dogru":"E","tur":1},"kanit_var":true,"baslama_izni":{"durum":"basla","oturum":"o","soz":"başla","beyan":"M"},
 "birlestirme_karari":{"karar_veren":"reis","reis":"M","pr":"41","zaman":"${GUN}T12:00:00+03:00","izin":"basla"}}
KART
O14="$(ozet)"
grep -q "## Sultan'a gidenler (2) — başlama izni / veto" <<<"$O14"; g $? "Ö14a başlık öneki korunur + 'başlama izni / veto'"
grep -qE '^\- \[acik\] \*\*sinifli\*\* .* izin: dur ' <<<"$O14"; g $? "Ö14b vetolu kart 'izin: dur'"
grep -qE '^\- \[bitti\] \*\*sinifli-bitti\*\* .* izin: basla .* reis birleştirdi \(PR 41\)' <<<"$O14"; g $? "Ö14c biten sınıflı 'izin: basla · reis birleştirdi (PR 41)'"
[ "$(say "$O14" 'İçeride bitirdiklerimiz')" = 2 ] && grep -qE '^\- \*\*sinifli-bitti\*\* .* sınıf: dis_yuzey · reis birleştirdi · izin: basla · veto yok' <<<"$O14"; g $? "Ö14d içeride bitenler sınıflı bitti'yi de alır (2: sinav + sinifli-bitti), etiketli"
[ "$(say "$O14" 'Reisin sınıflı işlerdeki kararları')" = 1 ] && grep -q "11:00 · \*\*sinifli\*\* · devam · reis M · izin: bekliyor · gerekçe: reis-gerekce-uzun-metin" <<<"$O14"; g $? "Ö14e yeni bölüm: yalnız sinifli:true kayıt sayılır (1), saat · karar · reis · izin · gerekçe"
grep -q "veto hakkın var (reis kararı, Sultan sözü değil)" <<<"$O14"; g $? "Ö14f bölüm başlığı 'reis kararı, Sultan sözü değil' der (A06)"
grep -qE '^\- sinifli — sahip M · açıldı .* · sınıflı · izin: dur$' <<<"$O14"; g $? "Ö14g açık işlerde 'sınıflı · izin: dur' (eski '· SULTAN' yok)"
! grep -q "· SULTAN" <<<"$O14"; g $? "Ö14h 'SULTAN' etiketi hiçbir satırda yok"

echo "════ Ö15 · MUTASYON: izin.py'de dur dalı kalkınca veto görünmez olur (Ö14b kırmızıya döner) ════"
cp "$G" "$T/pkg/mutant-izin.sh"; cp "$T/pkg/izin.py" "$T/pkg/izin.py.asil"; sed -i 's/^        if d == "dur":$/        if False:/' "$T/pkg/izin.py"
if cmp -s "$T/pkg/izin.py" "$T/pkg/izin.py.asil"; then g 1 "Ö15 mutant FARKSIZ (çapa bayat)"; else
  OMI="$( cd "$T" && bash "$T/pkg/mutant-izin.sh" --gun "$GUN" 2>&1 )"
  grep -qE '^\- \[acik\] \*\*sinifli\*\* .* izin: bekliyor ' <<<"$OMI"; g $? "Ö15 MUTASYON: dur dalı ölünce vetolu kart 'bekliyor' görünüyor → Ö14b bu mutantta düşerdi"
fi
cp "$T/pkg/izin.py.asil" "$T/pkg/izin.py"
rm -f "$T/_agents/fabrika/kartlar/sinifli.json" "$T/_agents/fabrika/kartlar/sinifli-bitti.json"

echo "════ Ö7 · MUTASYON: saat çevrimi koparılınca kör pencere GERİ GELİR ════"
M="$T/pkg/mutant.sh"
sed 's@^        return t.astimezone().strftime("%Y-%m-%d")@        return tarih@' "$G" > "$M"
if cmp -s "$M" "$G"; then g 1 "Ö7 mutant orijinalden FARKSIZ — ölçtüğü şey yok"; else
  printf '%s | KAPISIZ | gece-kacisi | komut-A\n' "$GECE" > "$T/_agents/fabrika/kacis-defteri.log"
  OM="$( cd "$T" && bash "$M" --gun "$GUN" 2>&1 )"
  [ "$(say "$OM" 'Kapı kaçışları')" = 0 ]; g $? "Ö7 MUTASYON: çevrim ölünce gece olayı yine KAYBOLUYOR (onarım gerçek)"
fi

echo "════ Ö8 · MUTASYON: 'çözülemedi' uyarısı kaldırılınca Ö5 kırmızıya döner ════"
M2="$T/pkg/mutant2.sh"
sed 's@^            cozulemedi.append(l)@            pass@' "$G" > "$M2"
if cmp -s "$M2" "$G"; then g 1 "Ö8 mutant2 FARKSIZ"; else
  printf 'tarihsiz bir satir | KAPISIZ | bozuk | komut-D\n' > "$T/_agents/fabrika/kacis-defteri.log"
  OM2="$( cd "$T" && bash "$M2" --gun "$GUN" 2>&1 )"
  grep -q 'ÇÖZÜLEMEDİ' <<<"$OM2"; [ $? -ne 0 ]; g $? "Ö8 MUTASYON: uyarı kaldırılınca bozuk satır SESSİZCE düşüyor"
fi

echo "════ Ö11 · MUTASYON: açık-dilim çevrimi koparılınca Ö9 kırmızıya döner ════"
M3="$T/pkg/mutant3.sh"
sed 's@^        if dilim:$@        if False:@' "$G" > "$M3"
if cmp -s "$M3" "$G"; then g 1 "Ö11 mutant3 FARKSIZ (çapa bayat)"; else
  printf '%sT00:00:00+00:00 | KAPISIZ | yabanci-dilim | komut-F\n' "$GUN" > "$T/_agents/fabrika/kacis-defteri.log"
  OM3="$( cd "$T" && bash "$M3" --gun "$GUN" 2>&1 )"
  grep -qE '^- 00:00 · gerekçe' <<<"$OM3"; g $? "Ö11 MUTASYON: çevrim ölünce HAM dilim saati basılıyor"
fi

echo "════ D · GÖREV DEFTERİ bölümü (Z23WS 2-3 · kart gun-sonu-gorev-defteri): gün kapanışı KART defterine değil GÖREV defterine göre ════"
# sahte defter: jeton başlığı şart (403); $T/defter.json → /gorevler; $T/defter.kapali varsa 503. Rastgele kapı (başka sınavla çakışmaz).
cat > "$T/defter.py" <<'PY'
import http.server, json, os, sys
T = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.headers.get("x-defter-jeton") != "gizli-sinav-jetonu":
            self.send_response(403); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"jeton"}'); return
        if os.path.exists(os.path.join(T, "defter.kapali")):
            self.send_response(503); self.end_headers(); self.wfile.write(b'{"ok":false}'); return
        b = open(os.path.join(T, "defter.json"), "rb").read()
        self.send_response(200); self.send_header("content-type", "application/json"); self.end_headers(); self.wfile.write(b)
s = http.server.HTTPServer(("127.0.0.1", 0), H); print(s.server_address[1], flush=True); s.serve_forever()
PY
python3 "$T/defter.py" "$T" > "$T/port" 2>/dev/null & DPID=$!
for i in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
PORT="$(cat "$T/port")"; printf 'gizli-sinav-jetonu\n' > "$T/jeton"
gorev() { printf '{"id":"gorev_01AAAAAAAAAAAAAAAAAAA%s","adlar":[{"deger":"%s"}],"son_adim":"%s","canli":{"kutu":"%s","atanan":"%s","gorev_durumu":"%s"}}' "$1" "$2" "$3" "$4" "$5" "$6"; }
defter_yaz() { printf '{"ok":true,"gorevler":[%s]}' "$(IFS=,; echo "$*")" > "$T/defter.json"; }
ozetd() { ( cd "$T" && DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton" bash "$G" --gun "$GUN" "$@" 2>&1 ); }
# fikstür GERÇEK yazımlardan (defter 22 Eki): BÂNİ çalışılıyor (code) · MİRAHUR çalışılıyor (code) · BERİD açık atanmış (sohbet) · BASİRET sıra-sende · onay bekleyen · bitti · atanmamış açık
defter_yaz "$(gorev 0001 'Görevler paneli ad eşlemesi' "${GUN}T18:49:00Z" code 'BÂNİ' calisiliyor)" "$(gorev 0002 'Bellek bekçisi kurulumu' "${GUN}T10:00:00Z" code 'MİRAHUR' calisiliyor)" \
  "$(gorev 0003 'Sohbet yolu' "${GUN}T09:00:00Z" sohbet 'BERİD' acik)" "$(gorev 0004 'Kadro karesi' "${GUN}T09:00:00Z" code 'BASİRET' sira-bende)" \
  "$(gorev 0005 'Dümen karesi' "${GUN}T09:00:00Z" code 'BÂNİ' onay-bekliyor)" "$(gorev 0006 'Eski iş' "${GUN}T09:00:00Z" code 'BÂNİ' bitti)" "$(gorev 0007 'Sahipsiz açık' "${GUN}T09:00:00Z" code '' acik)"
OD="$(ozetd)"; RCD=$?
grep -q '^## Görev defteri — gün kapanışı buna göre (kart bitti ≠ görev bitti) · bütün kutular' <<<"$OD"; g $? "D1 bölüm başlığı: görev defteri, gün kapanışı buna göre, bütün kutular"
grep -q '^- çalışılıyor \*\*2\*\* · atanmış açık 1 · sıra Sultan'"'"'da 1 · onay bekleyen 1$' <<<"$OD"; g $? "D1b sayılar: çalışılıyor 2 · atanmış açık 1 (sahipsiz açık sayılmaz) · sıra Sultan'da 1 · onay bekleyen 1 (bitti sayılmaz)"
grep -q '^  - A0002 · MİRAHUR · Bellek bekçisi kurulumu · son adım' <<<"$OD" && grep -q '^  - A0001 · BÂNİ · Görevler paneli ad eşlemesi · son adım' <<<"$OD"; g $? "D1c çalışılan işler satır satır: kısa kod · atanan · başlık · son adım (en eski adım önce)"
grep -q 'bu işler bitmeden gün KAPANMAZ' <<<"$OD" && [ "$RCD" -eq 0 ]; g $? "D1d uyarı yazılı; --kapanis YOKKEN rc 0 (cron bozulmaz)"
grep -q '^## Açık işler' <<<"$OD" && grep -q '^## Kapı kaçışları' <<<"$OD"; g $? "D1e eski bölümler (kart defteri) yerinde — iki defter yan yana"
OD2="$(ozetd --kutu sohbet)"
grep -q '· kutu sohbet$' <<<"$OD2" && grep -q '^- çalışılıyor \*\*0\*\* · atanmış açık 1 · sıra Sultan'"'"'da 0 · onay bekleyen 0$' <<<"$OD2" && grep -q 'defterde çalışılan iş yok' <<<"$OD2"; g $? "D2 --kutu sohbet: yalnız o kutunun işleri (çalışılıyor 0, açık 1) ve 'kapanabilir' sözü"
OD3="$(ozetd --kapanis)"; RC3=$?
[ "$RC3" -eq 1 ] && grep -q '^→ GÜN KAPANMAZ: görev defterinde 2 iş çalışılıyor (rc 1)' <<<"$OD3"; g $? "D3 --kapanis: çalışılıyor 2 → rc 1 'GÜN KAPANMAZ' (kart/PR bitmiş olsa da)"
OD4="$(ozetd --kapanis --kutu sohbet)"; RC4=$?
[ "$RC4" -eq 0 ] && grep -q '^→ GÜN KAPANABİLİR' <<<"$OD4"; g $? "D4 --kapanis --kutu sohbet: çalışılıyor 0 → rc 0 'GÜN KAPANABİLİR'"
OD5="$( cd "$T" && DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton-yok" bash "$G" --gun "$GUN" --kapanis 2>&1 )"; RC5=$?
[ "$RC5" -eq 3 ] && grep -q 'ÖLÇÜLEMEDİ: defter jetonu yok' <<<"$OD5" && grep -q 'KAPANIŞ ÖLÇÜLEMEDİ' <<<"$OD5" && ! grep -q 'çalışılıyor \*\*0' <<<"$OD5"; g $? "D5 jeton yok → bölüm 'ÖLÇÜLEMEDİ', --kapanis rc 3 (0 denmez, yeşil değil)"
touch "$T/defter.kapali"; OD6="$(ozetd --kapanis)"; RC6=$?; rm -f "$T/defter.kapali"
[ "$RC6" -eq 3 ] && grep -q 'defter cevap vermedi (HTTP 503)' <<<"$OD6"; g $? "D6 defter 503 → ÖLÇÜLEMEDİ, --kapanis rc 3"
OD7="$( cd "$T" && DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton-yok" bash "$G" --gun "$GUN" 2>&1 )"; RC7=$?
[ "$RC7" -eq 0 ] && grep -q 'ÖLÇÜLEMEDİ: defter jetonu yok' <<<"$OD7" && grep -q '^## Açık işler' <<<"$OD7"; g $? "D7 bayraksız koşuda defter ölçülemese de özet üretilir, rc 0 (cron bozulmaz), eksik yüzey yazılı"
grep -q 'gizli-sinav-jetonu' <<<"$OD$OD2$OD3$OD5"; [ $? -ne 0 ]; g $? "D8 jeton değeri hiçbir çıktıda yok"
echo "════ Ö12 · MUTASYON: çalışılıyor süzgeci gevşeyince sayı şişer (D1b kırmızı) ════"
M4="$T/pkg/mutant4.sh"; sed 's@    if d == "calisiliyor" or d == "onay-bekliyor" or (d in ("acik", "sira-bende") and c.get("atanan")): kova\[d\].append(k)@    if d in kova: kova[d].append(k)@' "$G" > "$M4"
if cmp -s "$M4" "$G"; then g 1 "Ö12 mutant4 FARKSIZ (çapa bayat)"; else
  OM4="$( cd "$T" && DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton" bash "$M4" --gun "$GUN" 2>&1 )"
  grep -q '^## Görev defteri' <<<"$OM4" && ! grep -q '^- çalışılıyor \*\*2\*\* · atanmış açık 1 ·' <<<"$OM4"; g $? "Ö12 MUTASYON: kopya çalıştı (bölüm var) ve sahipsiz açık da sayılınca satır değişiyor (kapı gerçek; çöken kopya yeşil sayılmaz)"
fi
echo "════ Ö13 · MUTASYON: ölçülemeyen defter 'çalışılıyor 0' sayılırsa --kapanis yeşile döner (D5 kırmızı) ════"
M5="$T/pkg/mutant5.sh"; sed 's@    print("#kapanis: olculemedi=1 calisiliyor=-1"); sys.exit(0)@    print("#kapanis: olculemedi=0 calisiliyor=0"); sys.exit(0)@' "$G" > "$M5"
if cmp -s "$M5" "$G"; then g 1 "Ö13 mutant5 FARKSIZ (çapa bayat)"; else
  ( cd "$T" && DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton-yok" bash "$M5" --gun "$GUN" --kapanis >/dev/null 2>&1 ); RCM5=$?
  [ "$RCM5" -ne 3 ]; g $? "Ö13 MUTASYON: ölçülemedi 0 sayılınca rc 3 kayboluyor (kapı gerçek)"
fi
kill "$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null
find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
