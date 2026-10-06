#!/usr/bin/env bash
# koken.test.sh — dördüncü kapının sınavı. HERMETİK: fikstürler $TMP'de üretilir,
# gerçek karelere/deftere DOKUNMAZ. Çift yönlü: kırmızı yüz yakalar, ALTIN yüz geçer.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; A="$D/koken.py"
TMP="$(mktemp -d)"; trap 'find "$TMP" -delete 2>/dev/null' EXIT
G=0; K=0
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
for d in ("uretilmis","temizmis","karma","tanimadik","kumeA","kumeB"): os.makedirs(f"{T}/{d}",exist_ok=True)
png(f"{T}/uretilmis/a.png",[("IHDR",ihdr),("caBX",b"jumbc2pa"+URET+b"gpt-image"+b"c2pa.watermarked"),("IDAT",b"x"),("IEND",b"")])
png(f"{T}/temizmis/b.png",[("IHDR",ihdr),("IDAT",b"x"),("IEND",b"")])
png(f"{T}/karma/c.png",[("IHDR",ihdr),("caBX",b"jumbc2pa"+KARMA),("IDAT",b"x"),("IEND",b"")])
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
jpeg(f"{T}/uretilmis/e.jpg",[(0xEB,b"JP\0\0jumbc2pa"+URET+b"gpt-image"),(0xE0,b"JFIF\0")])
# GERÇEK WebP: RIFF zincirinde C2PA kutusu
def webp(yol, parcalar):
    gov=bytearray(b"WEBP")
    for t,d in parcalar: gov+=t.encode()+struct.pack("<I",len(d))+d+(b"\0" if len(d)&1 else b"")
    open(yol,"wb").write(b"RIFF"+struct.pack("<I",len(gov))+bytes(gov))
os.makedirs(f"{T}/webp",exist_ok=True); webp(f"{T}/webp/f.webp",[("VP8X",b"\0"*10),("C2PA",b"jumbc2pa"+URET)])
# KUTU-DIŞI İZ: beyan metni köken kutusunda DEĞİL, sıradan bir metin parçasında
os.makedirs(f"{T}/disi",exist_ok=True)
png(f"{T}/disi/g.png",[("IHDR",ihdr),("tEXt",b"Not\0"+URET),("IDAT",b"x"),("IEND",b"")])
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
kapi "K4 beyan çelişkisi → RED + çelişen taraf 'insan'" "$r/$(grep -c "insan beyanı" "$TMP/e2")" "1/1"
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
kapi "K9 tanımadık parça 'yok' sayılmaz, kayda geçer (sözlük tuzağı)" "$(grep -c 'zzZZ' <<<"$O")" "1"
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
O="$(python3 "$A" "$TMP/uretilmis/a.png" --json 2>&1)"
kapi "K16 İMZA DOĞRULANMADI dürüstlüğü: her kayıtta yazılı, metinde uyarı basılı" \
     "$(python3 -c "import json,sys;d=json.load(sys.stdin);print(d['imza_dogrulandi']+'/'+d['kayitlar'][0]['imza_dogrulandi'])" <<<"$O")" "hayir/hayir"
O="$(python3 "$A" "$TMP/uretilmis/a.png" 2>&1)"
kapi "K16b metin çıktısı imzanın doğrulanmadığını söyler (overclaim yok)" \
     "$(grep -c 'imza DOĞRULANMADI' <<<"$O")" "1"
O="$(python3 "$A" "$TMP/bozuk/h.png" 2>&1)"
kapi "K17 biçimi ayrıştırılamayan dosya 'temiz' DEĞİL 'okunamadi' sayılır" \
     "$(grep -c 'okunamadi' <<<"$O")/$(grep -c 'ÖLÇEMEDİM' <<<"$O")" "1/1"

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
echo; echo "SONUÇ: $G geçti · $K kaldı"
[ "$K" -eq 0 ]
