#!/usr/bin/env bash
# bulgu.test.sh — hermetik: sahte defter yazıcısı (argv'yi kaydeder); gerçek deftere dokunmaz.
# Kapılar: hal komutu doğru argümanla yazıcıya gider · onaylandi reddedilir (A06) · kötü numara/hâl/eksik alan rc 2 · defter yoksa rc 3.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'rm -r -- "$T"' EXIT
mkdir -p "$T/kok/bulgu-defteri"; printf '#!/usr/bin/env python3\nimport sys; print("ARGV:" + "|".join(sys.argv[1:]))\n' > "$T/kok/defter-yaz.py"
echo '{"bulgular":[],"sonSayi":0}' > "$T/kok/bulgu-defteri/bulgular.json"
g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
B="$HERE/bulgu.sh"
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-12 uygulandi --kim MUAVİN --gerekce "PR #1 birleşti" 2>&1); r=$?
ok "H1 hal: yazıcıya 'hal S-12 --hal uygulandi --gerekce … --kim MUAVİN --kok' gider, rc 0" '[ $r -eq 0 ] && [[ "$o" == "ARGV:hal|S-12|--hal|uygulandi|--gerekce|PR #1 birleşti|--kim|MUAVİN|--kok|"* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-12 onaylandi --kim MUAVİN --gerekce x 2>&1); r=$?
ok "H2 🔴 'onaylandi' ajan tarafından yazılamaz (A06): rc 2, yazıcı ÇAĞRILMADI" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]] && [[ "$o" == *A06* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal 12 canli --kim X --gerekce y 2>&1); r=$?
ok "H3 numara S-N değilse rc 2" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 bitti --kim X --gerekce y 2>&1); r=$?
ok "H4 bilinmeyen hâl rc 2" '[ $r -eq 2 ]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 canli --gerekce y 2>&1); r=$?
ok "H5 --kim eksik rc 2" '[ $r -eq 2 ] && [[ "$o" == *"--kim zorunlu"* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 canli --kim X 2>&1); r=$?
ok "H6 --gerekce eksik rc 2" '[ $r -eq 2 ] && [[ "$o" == *"--gerekce zorunlu"* ]]'
o=$(BULGU_KOK="$T/yok" bash "$B" hal S-1 canli --kim X --gerekce y 2>&1); r=$?
ok "H7 defter kurulu değilse rc 3, hiçbir şey yazılmaz" '[ $r -eq 3 ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "deneme başlık" --kim X 2>&1); r=$?
ok "H8 eski 'yaz' yolu (jetonsuz kutu) değişmedi (yazıcıya 'yeni --baslik … --kim X --kok')" '[ $r -eq 0 ] && [[ "$o" == *"ARGV:yeni|--baslik|deneme başlık|--kim|X|--kok|"* ]]'
o=$(timeout 5 env BULGU_KOK="$T/kok" bash "$B" hal S-1 canli --gerekce y --kim 2>&1); r=$?
ok "H9 🔴 --kim son argüman ve DEĞERSİZ: rc 2, sonsuz döngü YOK (5 sn zaman aşımı değil), yazıcı çağrılmadı" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]] && [[ "$o" == *"değersiz"* ]]'
o=$(timeout 5 env BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "b" --kim X --not 2>&1); r=$?
ok "H9b yaz: --not değersiz → rc 2, döngü yok" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]]'
# ── K1 (0.3.0): jeton varsa MERKEZE, yoksa eski deftere ──
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "jetonsuz" --kim X 2>&1); r=$?
ok "K1a jeton yoksa eski yol + 'jetonu yok' uyarısı" '[ $r -eq 0 ] && [[ "$o" == *"ARGV:yeni|--baslik|jetonsuz"* ]] && [[ "$o" == *"jetonu yok"* ]]'
printf 'sinav-jeton-ABC\n' > "$T/jeton"
python3 - "$T" <<'PY' &
import sys, json, http.server, socketserver, os
T=sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_POST(self):
        n=int(self.headers.get("content-length") or 0); b=json.loads(self.rfile.read(n) or b"{}")
        open(os.path.join(T,"gelen.json"),"w").write(json.dumps({"yol":self.path,"jeton":self.headers.get("x-defter-jeton"),"govde":b}))
        if self.headers.get("x-defter-jeton")!="sinav-jeton-ABC": self.send_response(401); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"jeton_gecersiz"}'); return
        if b.get("etiket")=="kirmizi": self.send_response(400); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"alan_degeri_gecersiz","bekleniyor":"etiket: bug|ozellik"}'); return
        if b.get("dugum_acar")=="mmex:gorev_KAPANMIS00000001": self.send_response(400); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"dugum_hedefi_gecersiz","bekleniyor":"dugum_acar: kapanmis"}'); return
        cv={"kutu":"maiset","etiket":b.get("etiket"),"kaynak_kim":b.get("kaynak_kim")}; ek={}
        if b.get("dugum_acar"): cv["dugum_acar"]=b["dugum_acar"]; ek["dugum_bekleyen"]={"id":b["dugum_acar"].split(":",1)[1],"yazildi":True}
        if b.get("dugum_acar")=="mmex:gorev_KILITLI000000001": ek["dugum_bekleyen"]={"id":"gorev_KILITLI000000001","yazildi":False,"sebep":"yazma_yetkisi_yok"}
        self.send_response(201); self.end_headers()
        self.wfile.write(json.dumps({"ok":True,"kayit":{"id":"gorev_SINAV0000000001","ekleyen_kutu":"maiset","adlar":[{"deger":b["adlar"][0]}],"canli":cv},**ek}).encode())
    def do_GET(self):
        with open(os.path.join(T,"get.log"),"a") as f: f.write(self.path+"\n")
        if self.headers.get("x-defter-jeton")!="sinav-jeton-ABC": self.send_response(401); self.end_headers(); self.wfile.write(b'{"ok":false}'); return
        if self.path=="/kayit/gorev_BEKLEYEN00000001":
            self.send_response(200); self.end_headers(); self.wfile.write(b'{"ok":true,"kayit":{"id":"gorev_BEKLEYEN00000001","ekleyen_kutu":"akar","canli":{"kutu":"mmex"}}}'); return
        self.send_response(404); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"yok"}')
with socketserver.TCPServer(("127.0.0.1",0),H) as s:
    open(os.path.join(T,"port"),"w").write(str(s.server_address[1])); s.serve_forever()
PY
SRV=$!; for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "$T/port" ] && break; sleep 0.2; done; PORT=$(cat "$T/port")
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "Fatura ekranı donuyor" --kim BASIRET --not "3 kez ölçüldü" 2>&1); r=$?
ok "K1b jeton varsa MERKEZE yazar: tür gorev · etiket bug · kaynak_kim · kaynak_nereden 'bulgu komutu' · kanıt adımı; tek-format cevap" '[ $r -eq 0 ] && [[ "$o" == *"📌 gorev_SINAV0000000001 · maiset · bug — Fatura ekranı donuyor (açan: BASIRET) · Görev Defteri"* ]] && python3 -c "
import json,sys; g=json.load(open(sys.argv[1])); b=g[\"govde\"]
assert g[\"yol\"]==\"/kayit\" and b[\"tur\"]==\"gorev\" and b[\"etiket\"]==\"bug\" and b[\"kaynak_kim\"]==\"BASIRET\" and b[\"kaynak_nereden\"]==\"bulgu komutu\" and b[\"adimlar\"]==[\"[kanıt] 3 kez ölçüldü\"] and \"kutu\" not in b" "$T/gelen.json"'
ok "K1c eski kutu yazıcısı ÇAĞRILMADI (tek defter, ikilik yok)" '[[ "$o" != *ARGV* ]]'
ok "K1d jeton değeri çıktıda YOK" '[[ "$o" != *sinav-jeton-ABC* ]]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "fikir" --kim X --etiket ozellik 2>&1); r=$?
ok "K1e --etiket ozellik geçer" '[ $r -eq 0 ] && python3 -c "import json,sys; assert json.load(open(sys.argv[1]))[\"govde\"][\"etiket\"]==\"ozellik\"" "$T/gelen.json"'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X --etiket kusur 2>&1); r=$?
ok "K1f bilinmeyen etiket rc 2, hiçbir yere gitmez" '[ $r -eq 2 ] && [[ "$o" == *"bug ya da ozellik"* ]]'
printf 'yanlis-jeton\n' > "$T/jeton2"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton2" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X 2>&1); r=$?
ok "K1g merkez reddederse rc 1 + http kodu/sebep; eski deftere DÜŞMEZ" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=401"* ]] && [[ "$o" != *ARGV* ]]'
# ── DÜĞÜM (0.4.0): --dugum → dugum_acar; çıplak kimlikte kutu defterden; jetonsuz kutuda RED ──
M="BULGU_KOK=$T/kok DEFTER_JETON_YOL=$T/jeton DEFTER_UC=http://127.0.0.1:$PORT"
alan(){ python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['govde'].get('dugum_acar','YOK'))" "$T/gelen.json"; }
ok "D0 --dugum verilmezse gövdede dugum_acar YOK (eski yol aynen)" '[ "$(alan)" = YOK ]'
rm -f "$T/get.log"
o=$(env $M bash "$B" yaz "mmex bekleyen işin parçası" --kim BASIRET --dugum mmex:gorev_HEDEF000000001 2>&1); r=$?
ok "D1 kutulu biçim olduğu gibi dugum_acar olur; defterden okuma YAPILMAZ; düğüm + bekleyen sonucu söylenir" '[ $r -eq 0 ] && [ "$(alan)" = "mmex:gorev_HEDEF000000001" ] && [ ! -f "$T/get.log" ] && [[ "$o" == *"⛓ düğüm: mmex:gorev_HEDEF000000001"* ]] && [[ "$o" == *"⛓ bekleyen gorev_HEDEF000000001: bekliyor notu yazıldı"* ]]'
o=$(env $M bash "$B" yaz "kilitli bekleyen" --kim BASIRET --dugum mmex:gorev_KILITLI000000001 2>&1); r=$?
ok "D1b kayıt yazıldı ama bekleyen notu YAZILAMADIYSA rc 4 (0 değil, 1 değil) + defterin sebebi" '[ $r -eq 4 ] && [[ "$o" == *"📌 gorev_SINAV0000000001"* ]] && [[ "$o" == *"⛓ bekleyen gorev_KILITLI000000001: NOT YAZILMADI — yazma_yetkisi_yok"* ]]'
o=$(env $M bash "$B" yaz "çıplak kimlikle düğüm" --kim BASIRET --dugum gorev_BEKLEYEN00000001 2>&1); r=$?
ok "D2 çıplak kimlik: kutu defterden okunur (canlı kutu mmex, ekleyen akar DEĞİL) → mmex:gorev_BEKLEYEN00000001" '[ $r -eq 0 ] && [ "$(alan)" = "mmex:gorev_BEKLEYEN00000001" ] && grep -qx "/kayit/gorev_BEKLEYEN00000001" "$T/get.log"'
ok "D2b jeton değeri çıktıda YOK (okuma yolu da --config ile)" '[[ "$o" != *sinav-jeton-ABC* ]]'
rm -f "$T/gelen.json"
o=$(env $M bash "$B" yaz "görünmeyen düğüm" --kim X --dugum gorev_YOK0000000000001 2>&1); r=$?
ok "D3 çıplak kimlik defterde görünmüyorsa rc 1 + '<kutu>:… biçimiyle ver'; kayıt YAZILMADI" '[ $r -eq 1 ] && [[ "$o" == *"görünmüyor (http 404)"* ]] && [ ! -f "$T/gelen.json" ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "jetonsuz düğüm" --kim X --dugum mmex:gorev_HEDEF000000001 2>&1); r=$?
ok "D4 🔴 jetonsuz kutuda --dugum RED (rc 2): eski deftere bağsız DÜŞMEZ, yazıcı çağrılmadı" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]] && [[ "$o" == *"yalnız merkezî Görev Defteri"* ]]'
o=$(timeout 5 env $M bash "$B" yaz "b" --kim X --dugum 2>&1); r=$?
ok "D5 --dugum değersiz (son argüman) rc 2, döngü yok" '[ $r -eq 2 ] && [[ "$o" == *"--dugum değersiz"* ]]'
o=$(env $M bash "$B" yaz "b" --kim X --dugum "" 2>&1); r=$?
ok "D5b --dugum boş dize rc 2 (bağ sessizce düşmez)" '[ $r -eq 2 ] && [[ "$o" == *"--dugum değersiz"* ]] && [ ! -f "$T/gelen.json" ]'
rm -f "$T/get.log"
o=$(env $M bash "$B" yaz "b" --kim X --dugum "gorev_../../saglik" 2>&1); r=$?
ok "D6 çıplak kimlik biçim dışıysa rc 2; defter adresine HİÇ gidilmez (yol kaçışı yok)" '[ $r -eq 2 ] && [ ! -f "$T/get.log" ] && [ ! -f "$T/gelen.json" ]'
o=$(env $M bash "$B" yaz "kapanmış işe düğüm" --kim X --dugum mmex:gorev_KAPANMIS00000001 2>&1); r=$?
ok "D7 defter düğümü reddederse rc 1 + defterin sebebi aynen (kural defterde, burada kopya yok)" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=400 · dugum_hedefi_gecersiz · dugum_acar: kapanmis"* ]]'
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X 2>&1); r=$?
ok "K1h merkeze ulaşılamazsa rc 1, kayıt HİÇBİR yere yazılmaz ve söylenir" '[ $r -eq 1 ] && [[ "$o" == *"ulaşılamadı"* ]] && [[ "$o" != *ARGV* ]]'
echo "bulgu.test: $g geçti · $k kaldı"; [ $k -eq 0 ]
