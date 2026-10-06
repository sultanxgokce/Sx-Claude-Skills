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
# JPEG kılığında JUMBF (tek biçime bakan okuyucu 'temiz' der)
open(f"{T}/uretilmis/e.jpg","wb").write(b"\xff\xd8\xff\xe0"+b"\x00"*20+b"jumb"+b"c2pa"+URET+b"\xff\xd9")
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
kapi "K12 JPEG'de de köken bulunur (tek biçime bakan okuyucu 'temiz' der)" \
     "$(grep -c 'ÜRETİLMİŞ' <<<"$O")" "1"

# ── MUTASYON · pozitif kontrol kırılınca hüküm ÜRETİLMEZ (rc=3), 'temiz' DEMEZ
M="$TMP/koken-mutant.py"; sed 's/^KOKEN_PARCA = {"caBX"}/KOKEN_PARCA = {"yokBX"}/' "$A" > "$M"
python3 "$M" "$TMP/uretilmis/a.png" >/dev/null 2>"$TMP/e4"; r=$?
kapi "K13 MUTASYON: okuyucu körleştirilince rc=3 ÖLÇEMEDİM (temiz DEĞİL)" \
     "$r/$(grep -c 'ÖLÇEMEDİM' "$TMP/e4")" "3/1"
echo; echo "SONUÇ: $G geçti · $K kaldı"
[ "$K" -eq 0 ]
