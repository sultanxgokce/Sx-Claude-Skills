#!/usr/bin/env bash
# koken.test.sh — dördüncü kapının sınavı. HERMETİK: fikstürler $TMP'de üretilir,
# gerçek karelere/deftere DOKUNMAZ. Çift yönlü: kırmızı yüz yakalar, ALTIN yüz geçer.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; A="$D/koken.py"
TMP="$(mktemp -d)"; trap 'find "$TMP" -delete 2>/dev/null' EXIT
G=0; K=0; ATLANAN=""
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  🟢 %s\n' "$1"; else K=$((K+1)); printf '  🔴 %s — beklenen [%s] görülen [%s]\n' "$1" "$3" "$2"; fi; }

python3 - "$TMP" <<'PY'
import struct, sys, os
T=sys.argv[1]
def png(yol, parcalar):
    out=bytearray(b"\x89PNG\r\n\x1a\n")
    for t,d in parcalar: out+=struct.pack(">I",len(d))+t.encode()+d+b"\0\0\0\0"
    open(yol,"wb").write(bytes(out))
ihdr=struct.pack(">IIBBBBB",1,1,8,2,0,0,0)
URET=b"trainedAlgorithmicMedia"; KARMA=b"compositeWithTrainedAlgorithmicMedia"
ANAH=b'digitalSourceType":"http://cv.iptc.org/newscodes/digitalsourcetype/'
def iddia(deger): return b"jumbc2pa"+ANAH+deger+b'"'   # anahtara BAĞLI iddia
for d in ("uretilmis","temizmis","karma","tanimadik","kumeA","kumeB"): os.makedirs(f"{T}/{d}",exist_ok=True)
png(f"{T}/uretilmis/a.png",[("IHDR",ihdr),("caBX",iddia(URET)+b"gpt-image"+b"c2pa.watermarked"),("IDAT",b"x"),("IEND",b"")])
png(f"{T}/temizmis/b.png",[("IHDR",ihdr),("IDAT",b"x"),("IEND",b"")])
png(f"{T}/karma/c.png",[("IHDR",ihdr),("caBX",iddia(KARMA)),("IDAT",b"x"),("IEND",b"")])
png(f"{T}/tanimadik/d.png",[("IHDR",ihdr),("zzZZ",b"bilinmeyen"),("IDAT",b"x"),("IEND",b"")])
# ikizlik: aynı bayt iki KÜMEDE + aynı küme içinde iki kez
png(f"{T}/kumeA/x.png",[("IHDR",ihdr),("IDAT",b"ayni"),("IEND",b"")])
open(f"{T}/kumeA/x2.png","wb").write(open(f"{T}/kumeA/x.png","rb").read())
open(f"{T}/kumeB/x.png","wb").write(open(f"{T}/kumeA/x.png","rb").read())
# GERÇEK JPEG: APP11 segmenti (uzunluk alanıyla) — kılık değil, zincirde yürünebilir
def jpeg(yol, segmentler):
    out=bytearray(b"\xff\xd8")
    for m,d in segmentler: out+=bytes([0xFF,m])+struct.pack(">H",len(d)+2)+d
    open(yol,"wb").write(bytes(out+b"\xff\xd9"))
jpeg(f"{T}/uretilmis/e.jpg",[(0xEB,b"JP\0\0"+iddia(URET)+b"gpt-image"),(0xE0,b"JFIF\0")])
# GERÇEK WebP: RIFF zincirinde C2PA kutusu
def webp(yol, parcalar):
    gov=bytearray(b"WEBP")
    for t,d in parcalar: gov+=t.encode()+struct.pack("<I",len(d))+d+(b"\0" if len(d)&1 else b"")
    open(yol,"wb").write(b"RIFF"+struct.pack("<I",len(gov))+bytes(gov))
os.makedirs(f"{T}/webp",exist_ok=True); webp(f"{T}/webp/f.webp",[("VP8X",b"\0"*10),("C2PA",iddia(URET))])
# KUTU-DIŞI İZ: beyan metni köken kutusunda DEĞİL, sıradan bir metin parçasında
os.makedirs(f"{T}/disi",exist_ok=True)
png(f"{T}/disi/g.png",[("IHDR",ihdr),("tEXt",b"Not\0"+URET),("IDAT",b"x"),("IEND",b"")])
# KUTUDA BAĞSIZ İZ: dizi köken kutusunda ama digitalSourceType anahtarına bağlı DEĞİL
os.makedirs(f"{T}/bagsiz",exist_ok=True)
png(f"{T}/bagsiz/i.png",[("IHDR",ihdr),("caBX",b'jumbc2pa"description":"'+URET+b'"'),("IDAT",b"x"),("IEND",b"")])
# BİÇİM AYRIŞTIRILAMAZ: adı .png ama gövdesi değil
os.makedirs(f"{T}/bozuk",exist_ok=True); open(f"{T}/bozuk/h.png","wb").write(b"bu bir goruntu degil")
PY

O="$(python3 "$A" "$TMP/uretilmis/a.png" 2>&1)"; r=$?
kapi "K1 pozitif kontrol geçti (okuyucu kör değil) · üretilmiş görüldü" \
     "$r/$(grep -c 'ÜRETİLMİŞ' <<<"$O")" "0/1"
python3 "$A" "$TMP/uretilmis/a.png" --kullanim vitrin >/dev/null 2>"$TMP/e1"; r=$?
kapi "K2 üretilmiş + iddia taşıyan yüzey → RED (rc=1)" "$r/$(grep -c 'iddia taşıyan' "$TMP/e1")" "1/1"
python3 "$A" "$TMP/uretilmis/a.png" --kullanim doku-zemin >/dev/null 2>&1; r=$?
kapi "K3 üretilmiş + iddiasız yüzey → GEÇER (K2 tautoloji değil)" "$r" "0"
python3 "$A" "$TMP/uretilmis/a.png" --beyan gercek --beyan-sahibi insan >/dev/null 2>"$TMP/e2"; r=$?
kapi "K4 beyan çelişkisi GÖRÜLÜR ve çelişen taraf 'insan' yazılır" "$(grep -c "insan beyanı" "$TMP/e2")" "1"
python3 "$A" "$TMP/uretilmis/a.png" --beyan uretilmis >/dev/null 2>&1; r=$?
kapi "K5 beyan dosyayla uyuşuyorsa GEÇER (K4 tautoloji değil)" "$r" "0"
python3 "$A" "$TMP/uretilmis/a.png" --beyan gercek --beyan-sahibi ajan >/dev/null 2>"$TMP/e3"; r=$?
kapi "K6 ajan beyanı çelişkisi 'ajan' diye işaretlenir (insan SORULUR, ajan DÜZELTİLİR)" \
     "$(grep -c "ajan beyanı" "$TMP/e3")" "1"
O="$(python3 "$A" "$TMP/temizmis/b.png" 2>&1)"
kapi "K7 köken yoksa 'temiz' DEMEZ · 'bilinmiyor' + sunulamaz uyarısı basar" \
     "$(grep -c 'temiz. DEĞİL' <<<"$O")/$(grep -ci 'SUNULAMAZ' <<<"$O")/$(grep -ci 'hic-yok' <<<"$O")" "1/1/1"
python3 "$A" "$TMP/temizmis/b.png" --kullanim vitrin >/dev/null 2>&1; r=$?
kapi "K8 köken YOKLUĞU tek başına RED üretmez (yokluk kanıt değildir)" "$r" "0"
O="$(python3 "$A" "$TMP/tanimadik/d.png" 2>&1)"
kapi "K9 tanımadık parça 'yok' SAYILMAZ: hem kayda geçer hem sınıfı 'belirsiz-tasiyici' olur" \
     "$(grep -c 'zzZZ' <<<"$O")/$(grep -c 'belirsiz-tasiyici' <<<"$O")" "1/1"
O="$(python3 "$A" "$TMP/karma/c.png" 2>&1)"
kapi "K10 'gerçek+iyileştirme' üretilmişten AYRI okunur" \
     "$(grep -c 'ÜRETİLMİŞ' <<<"$O")" "0"
O="$(python3 "$A" "$TMP/kumeA" "$TMP/kumeB" --json 2>&1)"
kapi "K11 ikiz: küme içi 2 · kümeler arası 1 AYRI sayılır" \
     "$(python3 -c "import json,sys;d=json.load(sys.stdin);print(str(d['ikiz_ici'])+'/'+str(d['ikiz_arasi']))" <<<"$O")" "2/1"
O="$(python3 "$A" "$TMP/uretilmis/e.jpg" 2>&1)"
kapi "K12 GERÇEK JPEG APP11 segmentinden köken okunur (kılık değil, zincir yürünür)" \
     "$(grep -c 'ÜRETİLMİŞ' <<<"$O")" "1"

O="$(python3 "$A" "$TMP/webp/f.webp" 2>&1)"
kapi "K14 GERÇEK WebP RIFF zincirindeki C2PA kutusundan köken okunur" \
     "$(grep -c 'ÜRETİLMİŞ' <<<"$O")" "1"
O="$(python3 "$A" "$TMP/disi/g.png" --json 2>&1)"
kapi "K15 kutu DIŞINDAKİ beyan metni HÜKÜM DEĞİL, kayıttır (sahte-pozitif kapısı)" \
     "$(python3 -c "import json,sys;d=json.load(sys.stdin);k=d['kayitlar'][0];print(str(k['kaynak_turu'])+'/'+str(k['parca_disi_iz'])+'/'+k['koken_durumu'])" <<<"$O")" \
     "None/True/meta-var"
python3 "$A" "$TMP/disi/g.png" --kullanim vitrin >/dev/null 2>&1; r=$?
kapi "K15b kutu-dışı iz iddia taşıyan yüzeyde RED ÜRETMEZ (yanlış-kırmızı yok)" "$r" "0"
O="$(KOKEN_IMZA=kapali python3 "$A" "$TMP/uretilmis/a.png" 2>&1)"
kapi "K16 imzasız kipte metin çıktısı doğrulanmadığını SÖYLER (overclaim yok)" \
     "$(grep -c 'imza DOĞRULANMADI' <<<"$O")" "1"
O="$(python3 "$A" "$TMP/bozuk/h.png" 2>&1)"
kapi "K17 biçimi ayrıştırılamayan dosya 'temiz' DEĞİL 'okunamadi' sayılır" \
     "$(grep -c 'okunamadi' <<<"$O")/$(grep -c 'ÖLÇEMEDİM' <<<"$O")" "1/1"

O="$(python3 "$A" "$TMP/bagsiz/i.png" --json 2>&1)"
kapi "K20 kutuda BAĞSIZ dizi iddia sayılmaz (açıklama metnine konan sözcük hüküm vermez)" \
     "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(str(k['kaynak_turu'])+'/'+k['koken_durumu'])" <<<"$O")" \
     "None/koken-kutusu-var"
O="$(KOKEN_IMZA=kapali python3 "$A" "$TMP/uretilmis/a.png" --json 2>&1)"
kapi "K21 imza kipi KAYITTA: kütüphane kapatılınca 'kapali' + imza 'olculemedi'" \
     "$(python3 -c "import json,sys;d=json.load(sys.stdin);print(d['imza_kipi']+'/'+d['kayitlar'][0]['imza_dogrulandi']+'/'+d['kayitlar'][0]['okuma_yolu'])" <<<"$O")" \
     "kapali/olculemedi/kutu-govdesi"
O="$(KOKEN_IMZA=kapali python3 "$A" "$TMP/uretilmis/a.png" 2>&1)"
kapi "K21b SESSİZ DÜŞÜŞ YOK: kip her koşuda ÇIKTIDA yazılı" \
     "$(grep -c 'imza kapısı: KAPALI' <<<"$O")" "1"
KOKEN_IMZA=kapali python3 "$A" "$TMP/uretilmis/a.png" --beyan gercek --beyan-sahibi insan >/dev/null 2>"$TMP/e7"; r=$?
kapi "K22 imza doğrulanmamışsa ÇELİŞKİ kapı KESMEZ, uyarır (insanı yanlış suçlama zararın ağır tarafı)" \
     "$r/$(grep -c 'kapı kesmiyor, SORULMALI' "$TMP/e7")" "0/1"

O="$(python3 "$A" "$TMP/bagsiz/i.png" --json 2>&1)"
kapi "K28 İÇİ OKUNAMAYAN köken kutusu 'kanıt olabilir' DAMGASI ALMAZ (sahte-yeşil kapısı)" \
     "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(k['kanit_olabilir']+'/'+k['iddia_guveni'])" <<<"$O")" \
     "bilinmiyor/yok"
python3 - "$TMP" <<'FIX'
import struct, sys
T=sys.argv[1]
def png(yol,parcalar):
    out=bytearray(b"\x89PNG\r\n\x1a\n")
    for t,d in parcalar: out+=struct.pack(">I",len(d))+t.encode()+d+b"\0\0\0\0"
    open(yol,"wb").write(bytes(out))
ihdr=struct.pack(">IIBBBBB",1,1,8,2,0,0,0)
ANAH=b'digitalSourceType":"http://cv.iptc.org/newscodes/digitalsourcetype/'
import os; os.makedirs(f"{T}/olumlu",exist_ok=True)
png(f"{T}/olumlu/m.png",[("IHDR",ihdr),("caBX",b"jumbc2pa"+ANAH+b'digitalCapture"'),("IDAT",b"x"),("IEND",b"")])
FIX
O="$(python3 "$A" "$TMP/olumlu/m.png" --json 2>&1)"
kapi "K29 İMZASIZ 'gerçek fotoğrafım' iddiası DÜŞÜRÜLÜR (olumlu iddia doğrulanmadan kabul edilmez)" \
     "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(str(k['kaynak_turu'])+'/'+str(k.get('dusurulen_iddia'))+'/'+k['kanit_olabilir'])" <<<"$O")" \
     "None/gercek/bilinmiyor"
O="$(python3 "$A" "$TMP/olumlu/m.png" 2>&1)"
kapi "K29b düşürülen iddia SESSİZ değil, çıktıda söylenir" \
     "$(grep -c 'iddia DÜŞÜRÜLDÜ' <<<"$O")" "1"

# ── GERÇEK İMZALI FİKSTÜR (hermetik: kendi sınav sertifikasını üretir, ağ YOK)
#    Niçin: "imza doğrulanırsa çelişki keser" kuralının RED yüzü, imzasız fikstürle
#    ÖLÇÜLEMEZ. Sertifikayı sınav kendisi üretir; dışarıdan hiçbir şey indirilmez.
IMZALI=0
if command -v openssl >/dev/null 2>&1 && python3 -c "import c2pa" >/dev/null 2>&1; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 30 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -subj "/CN=koken-sinav/O=Nexus Sinav" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=emailProtection" \
    -addext "basicConstraints=critical,CA:FALSE" >/dev/null 2>&1 && \
  python3 "$D/koken-imzali-fikstur.py" "$TMP" >/dev/null 2>&1 && IMZALI=1
fi
if [ "$IMZALI" = "1" ]; then
  O="$(python3 "$A" "$TMP/imzali/j.png" --json 2>&1)"
  kapi "K23 GERÇEK imzalı dosyada imza DOĞRULANIR, iddia ŞEMADAN okunur (bayt arama değil)" \
       "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(k['imza_dogrulandi']+'/'+str(k['kaynak_turu'])+'/'+k['okuma_yolu'])" <<<"$O")" \
       "evet/uretilmis/c2pa-yapisal"
  python3 "$A" "$TMP/imzali/j.png" --beyan gercek --beyan-sahibi insan >/dev/null 2>"$TMP/e8"; r=$?
  kapi "K24 imza DOĞRULANMIŞSA çelişki RED (K22 tautoloji değil — iki yüz ayrı ölçüldü)" \
       "$r/$(grep -c 'çelişki çözülmeden yayın YOK' "$TMP/e8")" "1/1"
  python3 "$A" "$TMP/imzali/j.png" --kullanim vitrin >/dev/null 2>&1; r=$?
  kapi "K25 imzalı üretilmiş kare iddia taşıyan yüzeye GİREMEZ" "$r" "1"
  O="$(python3 "$A" "$TMP/imzali/k-gercek.png" --json 2>&1)"
  kapi "K30 İMZALI 'gerçek makine karesi' iddiası KABUL EDİLİR (K29 tautoloji değil)" \
       "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(str(k['kaynak_turu'])+'/'+k['kanit_olabilir']+'/'+k['iddia_guveni'])" <<<"$O")" \
       "gercek/evet/dogrulanmis-imza"

else
  echo "  ◻ K23/K24/K25/K30 ATLANDI — imzalı fikstür üretilemedi (openssl ya da c2pa yok)."
  echo "     Bu 'geçti' DEĞİL: imza kapısının RED yüzü bu makinede ÖLÇÜLMEDİ."
  ATLANAN=3
fi

# ── MUTASYON · pozitif kontrol kırılınca hüküm ÜRETİLMEZ (rc=3), 'temiz' DEMEZ
M="$TMP/koken-mutant.py"; sed 's/^KOKEN_PARCA = {"caBX"}/KOKEN_PARCA = {"yokBX"}/' "$A" > "$M"
python3 "$M" "$TMP/uretilmis/a.png" >/dev/null 2>"$TMP/e4"; r=$?
kapi "K13 MUTASYON: okuyucu körleştirilince rc=3 ÖLÇEMEDİM (temiz DEĞİL)" \
     "$r/$(grep -c 'ÖLÇEMEDİM' "$TMP/e4")" "3/1"
M2="$TMP/koken-mutant2.py"; sed 's/if t == "APP11" and any/if t == "APP99" and any/' "$A" > "$M2"
python3 "$M2" "$TMP/uretilmis/a.png" >/dev/null 2>"$TMP/e5"; r=$?
kapi "K18 MUTASYON: JPEG kolu körleştirilince de rc=3 (pozitif kontrol üç biçimi kapsar)" \
     "$r/$(grep -c 'ÖLÇEMEDİM' "$TMP/e5")" "3/1"
M3="$TMP/koken-mutant3.py"; sed 's/^    disi = (URETIM in ham or KARMA in ham)/    disi = False and (URETIM in ham or KARMA in ham)/' "$A" > "$M3"
python3 "$M3" "$TMP/uretilmis/a.png" >/dev/null 2>"$TMP/e6"; r=$?
kapi "K19 MUTASYON: kutu-dışı iz kaydı susturulunca pozitif kontrol düşer (kayıt süs değil)" \
     "$r/$(grep -c 'ÖLÇEMEDİM' "$TMP/e6")" "3/1"
M4="$TMP/koken-mutant4.py"; sed 's/if celisen and imza_ok:/if celisen:/' "$A" > "$M4"
KOKEN_IMZA=kapali python3 "$M4" "$TMP/uretilmis/a.png" --beyan gercek --beyan-sahibi insan >/dev/null 2>&1; r=$?
kapi "K26 MUTASYON: imza-şartı kaldırılınca doğrulanmamış çelişki RED'e döner (şart süs değil)" "$r" "1"
if [ "$IMZALI" = "1" ]; then
  M5="$TMP/koken-mutant5.py"; sed 's/^    im = imzali_oku(yol)/    im = None/' "$A" > "$M5"
  O="$(python3 "$M5" "$TMP/imzali/j.png" --json 2>&1)"
  kapi "K27 MUTASYON: yapısal kol koparılınca imzalı dosya 'olculemedi'ye düşer (kol gerçekten okuyor)" \
       "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(k['imza_dogrulandi']+'/'+k['okuma_yolu'])" <<<"$O")" \
       "olculemedi/kutu-govdesi"
fi
M6="$TMP/koken-mutant6.py"; sed 's/^OLUMLU_IDDIA = {"gercek"}/OLUMLU_IDDIA = set()/' "$A" > "$M6"
O="$(python3 "$M6" "$TMP/olumlu/m.png" --json 2>&1)"
kapi "K31 MUTASYON: olumlu-iddia şartı kaldırılınca imzasız 'gerçek' iddiası kabul edilir (şart süs değil)" \
     "$(python3 -c "import json,sys;k=json.load(sys.stdin)['kayitlar'][0];print(str(k['kaynak_turu'])+'/'+k['kanit_olabilir'])" <<<"$O")" \
     "gercek/bilinmiyor"
echo; echo "SONUÇ: $G geçti · $K kaldı${ATLANAN:+ · $ATLANAN atlandı (ölçülmedi)}"
[ "$K" -eq 0 ]
