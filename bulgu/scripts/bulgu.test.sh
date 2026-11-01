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
        if self.headers.get("x-defter-jeton")=="eski-defter-jeton" and b.get("gorev_durumu")=="havuz": self.send_response(400); self.end_headers(); self.wfile.write(json.dumps({"ok":False,"hata":"alan_degeri_gecersiz","ek":{"alan":"gorev_durumu","bekleniyor":"gorev_durumu: acik|sira-bende|bekliyor|calisiliyor|onay-bekliyor|bitti|iptal"}},ensure_ascii=False).encode()); return
        if self.headers.get("x-defter-jeton")!="sinav-jeton-ABC": self.send_response(401); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"jeton_gecersiz"}'); return
        if b.get("etiket")=="kirmizi": self.send_response(400); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"alan_degeri_gecersiz","bekleniyor":"etiket: bug|ozellik"}'); return
        if b.get("dugum_acar")=="mmex:gorev_KAPANMIS00000001": self.send_response(400); self.end_headers(); self.wfile.write(b'{"ok":false,"hata":"dugum_hedefi_gecersiz","bekleniyor":"dugum_acar: kapanmis"}'); return
        if b.get("dugum_acar")=="mmex:gorev_KAPANMIS00000002": self.send_response(409); self.end_headers(); self.wfile.write(json.dumps({"ok":False,"hata":"bag_hedefi_yok","alan":"dugum_acar","hedef":"mmex:gorev_KAPANMIS00000002","yerine":"bekleyen görev kapanmış; açık bir görevi göster","neden":"kapanmis"},ensure_ascii=False).encode()); return
        cv={"kutu":"maiset","etiket":b.get("etiket"),"kaynak_kim":b.get("kaynak_kim")}; ek={}
        if b.get("dugum_acar"): cv["dugum_acar"]=b["dugum_acar"]; ek["dugum_bekleyen"]={"id":b["dugum_acar"].split(":",1)[1],"yazildi":True}
        if b.get("dugum_acar")=="mmex:gorev_KILITLI000000001": ek["dugum_bekleyen"]={"id":"gorev_KILITLI000000001","yazildi":False,"sebep":"yazma_yetkisi_yok"}
        self.send_response(201); self.end_headers()
        self.wfile.write(json.dumps({"ok":True,"kayit":{"id":"gorev_SINAV0000000001","ekleyen_kutu":"maiset","adlar":[{"deger":b["adlar"][0]}],"canli":cv},**ek}).encode())
    def do_GET(self):
        with open(os.path.join(T,"get.log"),"a") as f: f.write(self.path+"\n")
        if self.path=="/gorevler" and self.headers.get("x-defter-jeton")=="bozuk-yanit-jeton": self.send_response(200); self.end_headers(); self.wfile.write(b'{"ok":true}'); return
        if self.path=="/gorevler" and self.headers.get("x-defter-jeton")=="sozluk-yanit-jeton": self.send_response(200); self.end_headers(); self.wfile.write(b'{"ok":true,"gorevler":{}}'); return
        if self.path=="/gorevler" and self.headers.get("x-defter-jeton")=="bozuk-oge-jeton":
            self.send_response(200); self.end_headers(); self.wfile.write(json.dumps({"ok":True,"gorevler":["metin",{"canli":{"etiket":"bug"},"adlar":[{"deger":"kimliksiz"}]},{"id":"gorev_X","canli":"bozuk"},{"id":"gorev_Y","canli":{"etiket":"bug"},"adlar":"metin"},{"id":"gorev_Z","canli":{"etiket":"bug"},"adlar":[{"deger":"adim bozuk"}],"adimlar":["metin"]},{"id":"gorev_IYI000000000000001","olusturma":"2026-10-22T00:00:00Z","adlar":[{"deger":"sağlam bulgu"}],"canli":{"gorev_durumu":"havuz","etiket":"bug","kaynak_nereden":"bulgu komutu"},"adimlar":[]}]},ensure_ascii=False).encode()); return
        if self.headers.get("x-defter-jeton")!="sinav-jeton-ABC": self.send_response(401); self.end_headers(); self.wfile.write(b'{"ok":false}'); return
        if self.path=="/gorevler":   # havuz-cek fikstürü: canlı /gorevler biçimi (adlar[].deger · canli{} · adimlar[].deger · olusturma)
            G=lambda i,ad,c,ad_=None,t="2026-10-22T09:24:09.195Z": {"id":i,"olusturma":t,"ekleyen_kutu":"code","adlar":[{"deger":ad}] if ad else [],"canli":c,"adimlar":ad_ or []}
            L=[G("gorev_HAVUZ0000000000001","Denetçi kaydı PR'a yetişmiyor",{"gorev_durumu":"havuz","kutu":"code","etiket":"bug","kaynak_kim":"BASİRET","kaynak_nereden":"bulgu komutu"},[{"deger":"[atandı → X] y"},{"deger":"[kanıt] iki vaka: #1146 #1151"}]),
               G("gorev_GOC00000000000001","Fatura ekranı donuyor",{"gorev_durumu":"bitti","kutu":"code","etiket":"bug","kaynak_kim":"MUAVIN","kaynak_nereden":"AKAR Bulgu Defteri","eski_no":"S-4 (code)"},None,"2026-10-14T10:00:00Z"),
               G("gorev_ISOLMAYAN000000001","Kokpit ekranı yenilensin",{"gorev_durumu":"acik","kutu":"code","kaynak_nereden":"gorev komutu"}),
               G("gorev_CATISMA0000000001","Çatışmalı durum",{"gorev_durumu":["acik","bitti"],"kutu":"mmex","etiket":"ozellik","kaynak_kim":"BÂNİ"}),
               G("gorev_ADSIZ000000000001",None,{"gorev_durumu":"havuz","etiket":"bug","kaynak_nereden":"bulgu komutu"})]
            self.send_response(200); self.end_headers(); self.wfile.write(json.dumps({"ok":True,"adet":len(L),"gorevler":L},ensure_ascii=False).encode()); return
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
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "uyum kaydı" --kim X --kaynak uyum 2>&1); r=$?
ok "K1e2 --kaynak uyum → defter kaydında kaynak_nereden 'uyum'; --kaynak yokken 'bulgu komutu' (K1b)" '[ $r -eq 0 ] && python3 -c "import json,sys; assert json.load(open(sys.argv[1]))[\"govde\"][\"kaynak_nereden\"]==\"uyum\"" "$T/gelen.json"'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X --kaynak "Kötü Ad" 2>&1); r=$?
ok "K1e3 geçersiz --kaynak rc 2, hiçbir yere gitmez" '[ $r -eq 2 ] && [[ "$o" == *"--kaynak"* ]]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X --etiket kusur 2>&1); r=$?
ok "K1f bilinmeyen etiket rc 2, hiçbir yere gitmez" '[ $r -eq 2 ] && [[ "$o" == *"bug ya da ozellik"* ]]'
printf 'yanlis-jeton\n' > "$T/jeton2"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton2" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X 2>&1); r=$?
ok "K1g merkez reddederse rc 1 + http kodu/sebep; eski deftere DÜŞMEZ" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=401"* ]] && [[ "$o" != *ARGV* ]]'
# ── ODA (0.6.3, görev …GZF89Z): Meşveret seansı maddeyi --oda ile geçirir; bulgu tanımadığı için kayıt REDDEDİLİYORDU ──
odaal(){ python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['govde'].get('oda','YOK'))" "$T/gelen.json"; }
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "Meşveret Seansı mes_x · madde 1" --kim SERDAR --oda agentic-os 2>&1); r=$?
ok "OD1 --oda merkez gövdesine 'oda' alanı olarak gider (gorev.sh ac --oda ile aynı alan), rc 0" '[ $r -eq 0 ] && [ "$(odaal)" = agentic-os ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "odasız" --kim X 2>&1); r=$?
ok "OD2 --oda verilmezse varsayılan oda agentic-os yazılır ve SÖYLENİR (0.6.5: odasız kayıt doğmaz)" '[ $r -eq 0 ] && [ "$(odaal)" = agentic-os ] && [[ "$o" == *"varsayılan oda agentic-os"* ]]'
KAYIT="$T/ekip.yaml"; printf -- '- id: BILGE\n  oda: mesajlasma\n- id: DIGER\n  oda: kuzey\n' > "$KAYIT"
o=$(GOREV_EKIP_KAYDI="$KAYIT" AGENT_NAME=bilge BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "koltuk odası" --kim X 2>&1); r=$?
ok "OD5 --oda yoksa yazanın ekip kaydındaki odası kullanılır (AGENT_NAME)" '[ $r -eq 0 ] && [ "$(odaal)" = mesajlasma ]'
o=$(GOREV_ODA=kuzey GOREV_EKIP_KAYDI="$KAYIT" AGENT_NAME=BILGE BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "env oda" --kim X 2>&1); r=$?
ok "OD6 GOREV_ODA kayıttan önce gelir; açık --oda her ikisinden önce" '[ $r -eq 0 ] && [ "$(odaal)" = kuzey ]'
once=$(md5sum < "$T/gelen.json")
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "uzun özet" --kim X --gorev --ozet "$(printf 'a%.0s' $(seq 1 80))" 2>&1); r=$?
ok "OZ1 80 harflik özet reddedilir (rc 2), deftere HİÇ gidilmez" '[ $r -eq 2 ] && [[ "$o" == *"80 harften KISA"* ]] && [ "$(md5sum < "$T/gelen.json")" = "$once" ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "sınırda özet" --kim X --gorev --ozet "$(printf 'a%.0s' $(seq 1 79))" 2>&1); r=$?
ok "OZ2 79 harflik özet geçer" '[ $r -eq 0 ]'
once=$(md5sum < "$T/gelen.json")
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X --oda 2>&1); r=$?
ok "OD3 --oda değersiz rc 2, deftere HİÇ gidilmez (son gelen gövde değişmedi)" '[ $r -eq 2 ] && [[ "$o" == *"--oda değersiz"* ]] && [ "$(md5sum < "$T/gelen.json")" = "$once" ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "jetonsuz odalı" --kim X --oda agentic-os 2>&1); r=$?
ok "OD4 jetonsuz kutuda kayıt eski deftere yazılır, oda YAZILMADI diye SÖYLENİR (sessiz düşme yok)" '[ $r -eq 0 ] && [[ "$o" == *"ARGV:yeni|--baslik|jetonsuz odalı"* ]] && [[ "$o" != *"--oda"*"agentic-os|"* ]] && [[ "$o" == *"oda alanı tanımıyor"* ]] && [[ "$o" == *"YAZILMADI"* ]]'
# ── DÜĞÜM (0.4.0): --dugum → dugum_acar; çıplak kimlikte kutu defterden; jetonsuz kutuda RED ──
M="BULGU_KOK=$T/kok DEFTER_JETON_YOL=$T/jeton DEFTER_UC=http://127.0.0.1:$PORT"
alan(){ python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['govde'].get('dugum_acar','YOK'))" "$T/gelen.json"; }
ok "D0 --dugum verilmezse gövdede dugum_acar YOK (eski yol aynen)" '[ "$(alan)" = YOK ]'
rm -f "$T/get.log"
o=$(env $M bash "$B" yaz "mmex bekleyen işin parçası" --kim BASIRET --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_HEDEF000000001 2>&1); r=$?
ok "D1 kutulu biçim olduğu gibi dugum_acar olur; defterden okuma YAPILMAZ; düğüm + bekleyen sonucu söylenir" '[ $r -eq 0 ] && [ "$(alan)" = "mmex:gorev_HEDEF000000001" ] && [ ! -f "$T/get.log" ] && [[ "$o" == *"⛓ düğüm: mmex:gorev_HEDEF000000001"* ]] && [[ "$o" == *"⛓ bekleyen gorev_HEDEF000000001: bekliyor notu yazıldı"* ]]'
o=$(env $M bash "$B" yaz "kilitli bekleyen" --kim BASIRET --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_KILITLI000000001 2>&1); r=$?
ok "D1b kayıt yazıldı ama bekleyen notu YAZILAMADIYSA rc 4 (0 değil, 1 değil) + defterin sebebi" '[ $r -eq 4 ] && [[ "$o" == *"📌 gorev_SINAV0000000001"* ]] && [[ "$o" == *"⛓ bekleyen gorev_KILITLI000000001: NOT YAZILMADI — yazma_yetkisi_yok"* ]]'
o=$(env $M bash "$B" yaz "çıplak kimlikle düğüm" --kim BASIRET --gorev --ozet "sebep → yapılacak → sonuç" --dugum gorev_BEKLEYEN00000001 2>&1); r=$?
ok "D2 çıplak kimlik: kutu defterden okunur (canlı kutu mmex, ekleyen akar DEĞİL) → mmex:gorev_BEKLEYEN00000001" '[ $r -eq 0 ] && [ "$(alan)" = "mmex:gorev_BEKLEYEN00000001" ] && grep -qx "/kayit/gorev_BEKLEYEN00000001" "$T/get.log"'
ok "D2b jeton değeri çıktıda YOK (okuma yolu da --config ile)" '[[ "$o" != *sinav-jeton-ABC* ]]'
rm -f "$T/gelen.json"
o=$(env $M bash "$B" yaz "görünmeyen düğüm" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum gorev_YOK0000000000001 2>&1); r=$?
ok "D3 çıplak kimlik defterde görünmüyorsa rc 1 + '<kutu>:… biçimiyle ver'; kayıt YAZILMADI" '[ $r -eq 1 ] && [[ "$o" == *"görünmüyor (http 404)"* ]] && [ ! -f "$T/gelen.json" ]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "jetonsuz düğüm" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_HEDEF000000001 2>&1); r=$?
ok "D4 🔴 jetonsuz kutuda --dugum RED (rc 2): eski deftere bağsız DÜŞMEZ, yazıcı çağrılmadı" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]] && [[ "$o" == *"yalnız merkezî Görev Defteri"* ]]'
o=$(timeout 5 env $M bash "$B" yaz "b" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum 2>&1); r=$?
ok "D5 --dugum değersiz (son argüman) rc 2, döngü yok" '[ $r -eq 2 ] && [[ "$o" == *"--dugum değersiz"* ]]'
o=$(env $M bash "$B" yaz "b" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum "" 2>&1); r=$?
ok "D5b --dugum boş dize rc 2 (bağ sessizce düşmez)" '[ $r -eq 2 ] && [[ "$o" == *"--dugum değersiz"* ]] && [ ! -f "$T/gelen.json" ]'
rm -f "$T/get.log"
o=$(env $M bash "$B" yaz "b" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum "gorev_../../saglik" 2>&1); r=$?
ok "D6 çıplak kimlik biçim dışıysa rc 2; defter adresine HİÇ gidilmez (yol kaçışı yok)" '[ $r -eq 2 ] && [ ! -f "$T/get.log" ] && [ ! -f "$T/gelen.json" ]'
o=$(env $M bash "$B" yaz "kapanmış işe düğüm" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_KAPANMIS00000001 2>&1); r=$?
ok "D7 defter düğümü reddederse rc 1 + defterin sebebi aynen (kural defterde, burada kopya yok)" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=400 · dugum_hedefi_gecersiz · dugum_acar: kapanmis"* ]]'
o=$(env $M bash "$B" yaz "kapanmış işe düğüm (canlı biçim)" --kim X --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_KAPANMIS00000002 2>&1); r=$?
ok "D7b defter bağ reddinde (canlı 409 bag_hedefi_yok biçimi: neden/yerine ÜST düzeyde — 21 Eki canlıdan alındı) neden + yapılacak basılır, rc 1" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=409 · bag_hedefi_yok"* ]] && [[ "$o" == *"neden: kapanmis · yapılacak: bekleyen görev kapanmış; açık bir görevi göster"* ]]'
# ── HAVUZ (0.5.0, Sultan D1 21 Eki): bulgu varsayılan 'havuz' (Sırada'ya düşmez); --gorev → acik; --dugum → acik ──
o=$(env $M bash "$B" yaz "Havuz bulgusu" --kim BASIRET 2>&1); r=$?
ok "HV1 varsayılan gorev_durumu 'havuz' + kaynak_sinif 'ajan' açıkça gövdede (0.5.0)" '[ $r -eq 0 ] && python3 -c "import json,sys; b=json.load(open(sys.argv[1]))[\"govde\"]; assert b[\"gorev_durumu\"]==\"havuz\" and b[\"kaynak_sinif\"]==\"ajan\", b" "$T/gelen.json"'
o=$(env $M bash "$B" yaz "Doğrudan iş" --kim BASIRET --gorev --ozet "sebep → yapılacak → sonuç" 2>&1); r=$?
ok "HV2 --gorev → gorev_durumu 'acik' (doğrudan İŞ, Sırada'ya düşer)" '[ $r -eq 0 ] && python3 -c "import json,sys; assert json.load(open(sys.argv[1]))[\"govde\"][\"gorev_durumu\"]==\"acik\"" "$T/gelen.json"'
o=$(env $M bash "$B" yaz "Düğüm açan" --kim BASIRET --dugum mmex:gorev_BEKLEYEN00000001 2>&1); r=$?
ok "HV3 --dugum --gorev'siz RED (rc 2, 'havuzda bekleyemez'): sessizce acik'a çevrilmez, deftere gitmez" '[ $r -eq 2 ] && [[ "$o" == *"havuzda bekleyemez"* ]] && [[ "$o" == *"--gorev ver"* ]] && ! grep -q "Düğüm açan" "$T/gelen.json" 2>/dev/null'
o=$(env $M bash "$B" yaz "Düğüm açan iş" --kim BASIRET --gorev --ozet "sebep → yapılacak → sonuç" --dugum mmex:gorev_BEKLEYEN00000001 2>&1); r=$?
ok "HV3b --dugum --gorev → acik + dugum_acar (tek istisna --gorev)" '[ $r -eq 0 ] && python3 -c "import json,sys; b=json.load(open(sys.argv[1]))[\"govde\"]; assert b[\"gorev_durumu\"]==\"acik\" and b[\"dugum_acar\"]==\"mmex:gorev_BEKLEYEN00000001\", b" "$T/gelen.json"'
# ── 0.6.1: --ozet (defter 'acik' açılışta Sultan özeti ister) ──
rm -f "$T/gelen.json"; o=$(env $M bash "$B" yaz "özetli iş" --kim X --gorev --ozet "sebep → yapılacak → sonuç" 2>&1); r=$?
ok "O1 --gorev --ozet: gövdede ozet_sultan aynen gider, durum acik" '[ $r -eq 0 ] && python3 -c "import json,sys; b=json.load(open(sys.argv[1]))[\"govde\"]; assert b[\"ozet_sultan\"]==\"sebep → yapılacak → sonuç\" and b[\"gorev_durumu\"]==\"acik\", b" "$T/gelen.json"'
rm -f "$T/gelen.json"; o=$(env $M bash "$B" yaz "özetsiz iş" --kim X --gorev 2>&1); r=$?
ok "O2 🔴 --gorev özetsiz: rc 2, sebep '--ozet' söyler, deftere HİÇ gidilmez" '[ $r -eq 2 ] && [[ "$o" == *"--ozet"* ]] && [ ! -e "$T/gelen.json" ]'
rm -f "$T/gelen.json"; o=$(env $M bash "$B" yaz "boşluk özet" --kim X --gorev --ozet "   " 2>&1); r=$?
ok "O2b boşluktan ibaret özet de özetsizdir: rc 2, deftere gidilmez" '[ $r -eq 2 ] && [ ! -e "$T/gelen.json" ]'
rm -f "$T/gelen.json"; o=$(env $M bash "$B" yaz "havuz bulgusu" --kim X 2>&1); r=$?
ok "O3 havuz (varsayılan) özetsiz geçer; gövdede ozet_sultan YOK (eski yol aynen)" '[ $r -eq 0 ] && python3 -c "import json,sys; b=json.load(open(sys.argv[1]))[\"govde\"]; assert \"ozet_sultan\" not in b, b" "$T/gelen.json"'
o=$(timeout 5 env $M bash "$B" yaz "b" --kim X --gorev --ozet 2>&1); r=$?
ok "O4 --ozet son argüman ve değersiz: rc 2, döngü yok" '[ $r -eq 2 ] && [[ "$o" == *"değersiz"* ]]'

o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" yaz "jetonsuz bulgu" --kim X 2>&1); r=$?
ok "HV4 jetonsuz eski yolda havuz UYGULANMAZ ve bu SÖYLENİR (eski defter havuzu bilmez; sessiz değil)" '[ $r -eq 0 ] && [[ "$o" == *"havuz yalnız merkezî defterde"* ]] && [[ "$o" == *"ARGV:yeni|--baslik|jetonsuz bulgu"* ]]'
printf 'eski-defter-jeton\n' > "$T/jeton-eski"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-eski" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "eski deftere havuz" --kim X 2>&1); r=$?
ok "HV5 defter 'havuz'u tanımıyorsa (1.18.0 öncesi 400 alan_degeri_gecersiz) rc 1 + sebep + sıra; acik'a DÜŞÜLMEZ, eski deftere gitmez" '[ $r -eq 1 ] && [[ "$o" == *"reddetti http=400"* ]] && [[ "$o" == *"havuz durumunu tanımıyor"* ]] && [[ "$o" == *"YAZILMADI"* ]] && [[ "$o" != *ARGV* ]]'
# ── HAVUZ-ÇEK (4FDVE5): defterdeki bulgular eski havuz biçiminde; ölçemezse rc 3 (sessiz boş liste YOK) ──
o=$(env $M bash "$B" havuz-cek 2>"$T/hc.err"); r=$?
ok "HC1 havuz-cek: bulgu kayıtları (bulgu komutu YA DA etiket bug/ozellik) gelir, bulgu olmayan görev ve adsız kayıt GELMEZ; sayı stderr'de" '[ $r -eq 0 ] && [ "$(printf "%s\n" "$o" | python3 -c "import sys,json;print(\" \".join(json.loads(l)[\"id\"][6:12] for l in sys.stdin if l.strip()))")" = "HAVUZ0 GOC000 CATISM" ] && grep -q "defterden 3 bulgu kaydı (5 görev tarandı)" "$T/hc.err"'
ok "HC2 eşleme: havuz → durum 'ham' (defter_durumu havuz) · ilk [kanıt] adımı kanit/detay/gercek · tarih · bulan · kutu · sinif YOK · kaynak defter" 'printf "%s\n" "$o" | head -n1 | python3 -c "
import sys,json; k=json.loads(sys.stdin.read())
assert k[\"durum\"]==\"ham\" and k[\"defter_durumu\"]==\"havuz\" and k[\"kanit\"]==k[\"detay\"]==k[\"gercek\"]==\"iki vaka: #1146 #1151\", k
assert k[\"tarih\"]==\"2026-10-22\" and k[\"bulan\"]==\"BASİRET\" and k[\"kutu\"]==\"code\" and \"sinif\" not in k and k[\"kaynak\"]==\"defter\", k"'
ok "HC3 göç kaydı eski_no taşır (tüketici kutu defteriyle iki kez saymasın); havuz dışı durum aynen kalır; çatışmalı durum listesi → son değer" 'printf "%s\n" "$o" | python3 -c "
import sys,json; L=[json.loads(l) for l in sys.stdin if l.strip()]
assert L[1][\"eski_no\"]==\"S-4 (code)\" and L[1][\"durum\"]==\"bitti\" and L[0][\"eski_no\"]==\"\", L[1]
assert L[2][\"durum\"]==\"bitti\" and L[2][\"kutu\"]==\"mmex\", L[2]"'
ok "HC4 jeton değeri çıktıda YOK" '[[ "$o$(cat "$T/hc.err")" != *sinav-jeton-ABC* ]]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton-yok" bash "$B" havuz-cek 2>&1); r=$?
ok "HC5 jetonsuz kutu: rc 3 + ÖLÇÜLEMEDİ (boş liste 'bulgu yok' sanılmaz)" '[ $r -eq 3 ] && [[ "$o" == *"ÖLÇÜLEMEDİ"* ]] && [[ "$o" != *\{* ]]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton2" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" havuz-cek 2>&1); r=$?
ok "HC6 defter reddederse (401) rc 3 + http kodu" '[ $r -eq 3 ] && [[ "$o" == *"http 401"* ]]'
printf 'bozuk-yanit-jeton\n' > "$T/jeton3"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton3" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" havuz-cek 2>&1); r=$?
ok "HC7 yanıtta gorevler listesi yoksa rc 3 (0 kayıt 'temiz' sayılmaz)" '[ $r -eq 3 ] && [[ "$o" == *"yanıtı bozuk"* ]]'
printf 'sozluk-yanit-jeton\n' > "$T/jeton4"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton4" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" havuz-cek 2>&1); r=$?
ok "HC7b gorevler LİSTE değilse ({}) rc 3 + ÖLÇÜLEMEDİ (Python hatası/rc 1 değil — göz #431 tur 1)" '[ $r -eq 3 ] && [[ "$o" == *"yanıtı bozuk"* ]] && [[ "$o" != *Traceback* ]]'
printf 'bozuk-oge-jeton\n' > "$T/jeton5"
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton5" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" havuz-cek 2>"$T/hc5.err"); r=$?
ok "HC7c bozuk öğeler (metin · kimliksiz · canli/adlar/adimlar yanlış tür) çökertmez: sağlam kayıt gelir, '5 BOZUK kayıt atlandı' söylenir" '[ $r -eq 0 ] && [ "$(printf "%s\n" "$o" | grep -c gorev_IYI)" = 1 ] && grep -q "defterden 1 bulgu kaydı (6 görev tarandı) · 5 BOZUK kayıt atlandı" "$T/hc5.err" && ! grep -q Traceback "$T/hc5.err"'
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
o=$(env $M bash "$B" havuz-cek 2>&1); r=$?
ok "HC8 defter ulaşılamazsa rc 3" '[ $r -eq 3 ] && [[ "$o" == *"ulaşılamadı"* ]]'
o=$(BULGU_KOK="$T/kok" DEFTER_JETON_YOL="$T/jeton" DEFTER_UC="http://127.0.0.1:$PORT" bash "$B" yaz "x" --kim X 2>&1); r=$?
ok "K1h merkeze ulaşılamazsa rc 1, kayıt HİÇBİR yere yazılmaz ve söylenir" '[ $r -eq 1 ] && [[ "$o" == *"ulaşılamadı"* ]] && [[ "$o" != *ARGV* ]]'
echo "bulgu.test: $g geçti · $k kaldı"; [ $k -eq 0 ]
