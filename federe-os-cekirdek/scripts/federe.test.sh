#!/usr/bin/env bash
# federe.test.sh — çekirdek-istemci offline golden'ları (C3/D7 · k0180). AĞ'A ÇIKMAZ:
# validation-yolları curl'den ÖNCE kesilir; token-file testi sahte BASE'e çarpıp RC=1 döner
# (kaynak-çözümü kanıtı). Canlı-E2E = GO-1 token-provizyonu sonrası (FAZ-3).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$DIR/federe.sh"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

# Ağ-koruması + tam env-izolasyon: sahte BASE, tüm token-kaynakları kapalı.
export FEDERE_API_BASE="http://127.0.0.1:1"
export DEFTER_ENV_FILE="/yok/boyle/env"
export FEDERE_TOKEN_FILE="/yok/boyle/token"
export FEDERE_TETIK_INBOX="$(mktemp -d)/inbox.md"
unset FEDERE_TETIK_TOKEN 2>/dev/null || true

echo "== T1: komut-yok → 2 (usage) =="
bash "$SUT" >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage RC=2" || no "usage RC yanlış"

echo "== T2: bilinmeyen komut → 2 =="
bash "$SUT" ucur >/dev/null 2>&1; [ $? -eq 2 ] && ok "bilinmeyen-komut RC=2" || no "kaçtı"

echo "== T3: gonder bozuk-hedef → 2 (curl'e inmeden) =="
bash "$SUT" gonder kutu-4 "test" >/dev/null 2>&1; [ $? -eq 2 ] && ok "hedef-format reddi" || no "hedef-format kaçtı"

echo "== T4: gonder başlıksız → 2 =="
bash "$SUT" gonder s04 "" >/dev/null 2>&1; [ $? -eq 2 ] && ok "boş-başlık reddi" || no "boş-başlık kaçtı"

echo "== T5: gonder 121-char başlık → 2 =="
b="$(printf 'a%.0s' $(seq 1 121))"
bash "$SUT" gonder s04 "$b" >/dev/null 2>&1; [ $? -eq 2 ] && ok "başlık-uzunluk reddi" || no "uzunluk kaçtı"

echo "== T5b: gonder --tetikli GEREKÇESİZ → 2 (gerekçesiz zil yok — L42/MABEYN F0.4) =="
bash "$SUT" gonder --tetikli "" s04 "başlık" >/dev/null 2>&1; [ $? -eq 2 ] && ok "tetikli-gerekçe reddi" || no "gerekçesiz zil kaçtı"

echo "== T5c: gonder --tetikli argüman-kayması — hedef/başlık doğru okunur (curl'e inmeden format-kapısı) =="
# gerekçe verilmiş ama hedef bozuk → hedef-format reddi (RC=2) = kayma YOK kanıtı
bash "$SUT" gonder --tetikli "MÜDÜR sessiz" kutu-4 "başlık" >/dev/null 2>&1; [ $? -eq 2 ] && ok "tetikli-sonrası hedef-format kapısı" || no "argüman kayması var"

echo "== T5d: gonder --tetikli sır-desenli gerekçe → 2 (yerel ön-kapı) =="
zfs="sk-$(printf 'B%.0s' $(seq 1 20))"
bash "$SUT" gonder --tetikli "$zfs" s04 "başlık" >/dev/null 2>&1; [ $? -eq 2 ] && ok "tetikli sır-desen reddi" || no "tetikli sır-desen kaçtı"

echo "== T6: gelen enum-dışı durum → 2 =="
bash "$SUT" gelen yanlis >/dev/null 2>&1; [ $? -eq 2 ] && ok "durum-enum reddi" || no "enum kaçtı"

echo "== T7: token-kaynağı yok → 2 (dürüst, değer-sızmadan) =="
OUT="$(bash "$SUT" gonder s04 "test-başlık" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q "token kaynağı yok" && ok "token-yokluğu dürüst RC=2" || no "token-yolu yanlış (rc=$RC)"

echo "== T8: gonder sır-desenli not → 2 (yerel ön-kapı) =="
fs="sk-$(printf 'A%.0s' $(seq 1 20))"
bash "$SUT" gonder s04 "başlık" "" "$fs" >/dev/null 2>&1; [ $? -eq 2 ] && ok "sır-desen reddi (gonder)" || no "sır-desen kaçtı (gonder)"

echo "== T9: token-file çözümü → ağ-katına iner (RC=1) + değer sızmaz =="
TF="$(mktemp -d)/token"; printf 'TESTTOKEN-abc123\n' > "$TF"
OUT="$(FEDERE_TOKEN_FILE="$TF" bash "$SUT" gonder s04 "test-başlık" 2>&1)"; RC=$?
if [ "$RC" -eq 1 ]; then ok "token-file kaynağı kullanıldı (ağ-hatası RC=1)"; else no "token-file çözümü yanlış (rc=$RC)"; fi
echo "$OUT" | grep -q "TESTTOKEN-abc123" && no "TOKEN DEĞERİ SIZDI" || ok "token değeri çıktıya sızmadı"

echo "== T10: nabiz özet-siz → 2 =="
bash "$SUT" nabiz "" >/dev/null 2>&1; [ $? -eq 2 ] && ok "boş-özet reddi" || no "boş-özet kaçtı"

echo "== T11: nabiz 201-char özet → 2 =="
o="$(printf 'a%.0s' $(seq 1 201))"
bash "$SUT" nabiz "$o" >/dev/null 2>&1; [ $? -eq 2 ] && ok "özet-uzunluk reddi" || no "özet-uzunluk kaçtı"

echo "== T12: nabiz sır-desenli özet → 2 =="
bash "$SUT" nabiz "$fs" >/dev/null 2>&1; [ $? -eq 2 ] && ok "sır-desen reddi (nabiz)" || no "sır-desen kaçtı (nabiz)"

echo "== T13: nabiz skor enum-dışı (150 · abc) → 2 =="
bash "$SUT" nabiz "özet" 150 >/dev/null 2>&1; R1=$?
bash "$SUT" nabiz "özet" abc >/dev/null 2>&1; R2=$?
[ "$R1" -eq 2 ] && [ "$R2" -eq 2 ] && ok "skor-sınır reddi" || no "skor-sınır kaçtı ($R1/$R2)"

echo "== T14: durum tokensız → RC=0 + DOĞRULANAMADI (sahte-yeşil yok) =="
OUT="$(bash "$SUT" durum 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "DOĞRULANAMADI" && ok "durum dürüst-3-durum" || no "durum probe yanlış (rc=$RC)"

echo "== T15: durum token-file'lı → API KIRMIZI (ağ yok) + RC=0 + değer sızmaz =="
OUT="$(FEDERE_TOKEN_FILE="$TF" bash "$SUT" durum 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "KIRMIZI" && ok "durum kırmızıyı dürüst raporlar" || no "durum kırmızı-yolu yanlış (rc=$RC)"
echo "$OUT" | grep -q "TESTTOKEN-abc123" && no "TOKEN DEĞERİ SIZDI (durum)" || ok "durum çıktısında değer yok"

echo "== T16-T18: [mock-API 127.0.0.1] kontrat + ACK-dayanıklılık golden'ları =="
TMPD="$(mktemp -d)"
cat > "$TMPD/mock.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header('Content-Type','application/json')
        self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith('/api/filo/tetik'):
            self._send(200, {"adet":2,"tetikler":[
                {"id":"t1","durum":"bekliyor","kaynakCell":"s01","hedefCell":"s09","tip":"tetik","baslik":"is-1","kartRef":"k0001"},
                {"id":"t2","durum":"bekliyor","kaynakCell":"s01","hedefCell":"s09","tip":"tetik","baslik":"is-2","kartRef":None}]})
        else: self._send(404, {"error":"yok"})
    def do_PATCH(self):
        n = int(self.headers.get('Content-Length','0'))
        body = json.loads(self.rfile.read(n) or b'{}')
        if body.get('id') == 't1': self._send(409, {"error":"eszamanli degisiklik"})
        else: self._send(200, {"ok":True})
    def do_POST(self):
        n = int(self.headers.get('Content-Length','0')); self.rfile.read(n)
        if self.path == '/api/filo/tetik': self._send(200, {"ok":True,"id":"t9","kaynak_cell":"s01","hedef_cell":"s04"})
        elif self.path == '/api/filo/nabiz': self._send(201, {"ok":True,"id":"n1","cell":"s09","skor":None})
        else: self._send(404, {"error":"yok"})
HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
PY
MPORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
python3 "$TMPD/mock.py" "$MPORT" & MPID=$!
trap 'kill "$MPID" 2>/dev/null' EXIT
for _i in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:$MPORT/" && break; sleep 0.1; done

echo "-- T16: gonder yanıt-parse (snake kaynak_cell/hedef_cell) --"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok bash "$SUT" gonder s04 "test-başlık" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "s01→s04" && ok "gonder kontrat-parse RC=0" || no "gonder mock yanlış (rc=$RC)"

echo "-- T17: dinle --ack · ACK-409'da batch ÖLMEZ (kalan işlenir + RC=1 + uyarı) --"
# NOT: ACK artık VARSAYILAN DEĞİL (L37-F0). Bu kapı geriye-uyum yolunu (`--ack`) sınar.
INB="$TMPD/inbox.md"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok FEDERE_TETIK_INBOX="$INB" \
       FEDERE_GORULEN="$TMPD/gorulen-t17.txt" bash "$SUT" dinle --ack 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "dinle --ack kısmi-ACK RC=1" || no "dinle RC yanlış (rc=$RC)"
echo "$OUT" | grep -q "ACK düşmedi: t1" && ok "ACK-hata uyarısı basıldı (ölü-kod değil)" || no "ACK-uyarı yok"
[ -f "$INB" ] && [ "$(grep -c '^- \[' "$INB")" -eq 2 ] && ok "batch tamamı inbox'a düştü (2/2)" || no "inbox eksik ($(grep -c '^- \[' "$INB" 2>/dev/null || echo 0)/2)"
echo "$OUT" | grep -q "1 ok · 1 düşmedi" && ok "kısmi-ACK özeti dürüst" || no "özet-satırı yanlış"

echo "-- T17b: TESLİMAT ≠ ÜSTLENME — varsayılan dinle ACK BASMAZ (L37-F0 sahte-makbuz panzehiri) --"
# Bu kapının VAR OLMA sebebi: eski `dinle` koşulsuz `alindi` damgalıyordu → gönderen
# "üstlenildi" sanıyordu. Ölçülen sonuç: 7 talep 8 gün 20 saat "teslim alındı" damgalı bekledi
# ve kuyruk hiç iş yapılmasa bile TEMİZ görünüyordu.
INB2="$TMPD/inbox-noack.md"; GOR2="$TMPD/gorulen-noack.txt"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok FEDERE_TETIK_INBOX="$INB2" \
       FEDERE_GORULEN="$GOR2" bash "$SUT" dinle 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "varsayılan dinle RC=0" || no "varsayılan dinle rc=$RC"
echo "$OUT" | grep -q "SAHİPSİZ" && ok "çıktı sahipsizliği AÇIKÇA söylüyor" || no "sahipsizlik bildirilmiyor"
echo "$OUT" | grep -q "teslim-alındı" && no "hâlâ 'teslim-alındı' diyor (sahte-makbuz geri geldi)" || ok "'teslim-alındı' iddiası YOK"
echo "$OUT" | grep -q "ACK düşmedi" && no "varsayılan yolda ACK denendi" || ok "varsayılan yolda ACK HİÇ denenmedi"
[ "$(grep -c '^- \[' "$INB2")" -eq 2 ] && ok "teslimat yine yapıldı (2/2 inbox'a düştü)" || no "teslimat kayboldu"
echo "$OUT" | grep -q "2 yeni" && ok "yeni-sayısı bildirildi" || no "yeni-sayısı yok"

echo "-- T17c: mükerrer-yazım YOK — ikinci poll aynı tetikleri tekrar yazmaz --"
# ACK basılmadığı için sunucu aynı tetikleri tekrar döndürür; gelen-kutusu şişmemeli.
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok FEDERE_TETIK_INBOX="$INB2" \
       FEDERE_GORULEN="$GOR2" bash "$SUT" dinle 2>&1)"
[ "$(grep -c '^- \[' "$INB2")" -eq 2 ] && ok "ikinci poll mükerrer yazmadı (hâlâ 2)" || no "inbox şişti ($(grep -c '^- \[' "$INB2"))"
echo "$OUT" | grep -q "0 yeni" && ok "ikinci poll '0 yeni' dedi" || no "yeni-sayısı yanlış"
echo "$OUT" | grep -q "2 bekleyen" && ok "toplam bekleyen sayısı gerçeği söylüyor" || no "toplam yanlış"

echo "-- T18: nabiz 201 kontrat --"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok bash "$SUT" nabiz "mock-nabız" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "cell=s09" && ok "nabiz kontrat-parse RC=0" || no "nabiz mock yanlış (rc=$RC)"

echo "== T24: K4 --tip kapalı küme — enum-dışı RC=2 (curl'e inmeden) =="
OUT="$(bash "$SUT" gonder --tip yanlis s04 "baslik" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "--tip enum-dışı RC=2" || no "--tip enum kaçtı (rc=$RC)"
echo "$OUT" | grep -q "mesaj | is | devir" && ok "geçerli tip listesi basılıyor" || no "tip listesi yok"
bash "$SUT" gonder --tip s04 "baslik" >/dev/null 2>&1; [ $? -eq 2 ] && ok "--tip değersiz RC=2 (kayma yok)" || no "--tip değersiz kaçtı"

echo "== T25-T26: [mock-API gövde-kaydeden] K4 tip gönderimi + K5 geri-al ters-kayıt =="
BLOG="$TMPD/post-govdeleri.log"; : > "$BLOG"
cat > "$TMPD/mock2.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
LOG = sys.argv[2]
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header('Content-Type','application/json')
        self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if 'yon=giden' in self.path:
            self._send(200, {"adet":3,"tetikler":[
                {"id":"d1","durum":"alindi","kaynakCell":"s01","hedefCell":"s04","tip":"devir","baslik":"devir-isi","kartRef":None},
                {"id":"m1","durum":"bekliyor","kaynakCell":"s01","hedefCell":"s04","tip":"tetik","baslik":"mesaj-isi","kartRef":None},
                {"id":"e1","durum":"bekliyor","kaynakCell":"s01","hedefCell":"s04","baslik":"tip-alani-yok","kartRef":None}]})
        else: self._send(200, {"adet":0,"tetikler":[]})
    def do_POST(self):
        n = int(self.headers.get('Content-Length','0')); b = self.rfile.read(n)
        open(LOG,'ab').write(b + b'\n')
        self._send(200, {"ok":True,"id":"t9","kaynak_cell":"s01","hedef_cell":"s04"})
HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
PY
M2PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
python3 "$TMPD/mock2.py" "$M2PORT" "$BLOG" & M2PID=$!
trap 'kill "$MPID" "$M2PID" 2>/dev/null' EXIT
for _i in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:$M2PORT/" && break; sleep 0.1; done
m2() { FEDERE_API_BASE="http://127.0.0.1:$M2PORT" FEDERE_TETIK_TOKEN=dummytok bash "$SUT" "$@"; }

echo "-- T25: --tip gövdeye yazılır; BAYRAKSIZ gövdede tip alanı YOK (bayt-aynı davranış) --"
m2 gonder --tip devir s04 "devir-basligi" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "gonder --tip devir RC=0" || no "gonder --tip devir rc=$RC"
tail -1 "$BLOG" | grep -q '"tip":"devir"' && ok "gövdede tip:devir var" || no "gövdede tip yok"
m2 gonder s04 "bayraksiz-baslik" >/dev/null 2>&1
tail -1 "$BLOG" | grep -q '"tip"' && no "bayraksız gövdeye tip SIZDI (bayt-davranış bozuldu)" || ok "bayraksız gövdede tip alanı YOK"

echo "-- T25b: okuma-uyumu — tip alanı olmayan kayıt 'mesaj' sayılır --"
OUT="$(m2 giden all 2>&1)"
echo "$OUT" | grep -q "tip-alani-yok" && echo "$OUT" | grep "e1" | grep -q "mesaj" \
  && ok "tip'siz kayıt listede 'mesaj' olarak basıldı" || no "tip'siz kayıt okuma-uyumu yanlış"

echo "-- T26: K5 geri-al — ters kayıt ekler, silmez; yalnız tip=devir --"
m2 geri-al d1 --gerekce "yanlis odaya devredilmisti" >"$TMPD/geri.out" 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "geri-al devir-kaydında RC=0" || no "geri-al rc=$RC"
grep -q "ters kayıt yazıldı" "$TMPD/geri.out" && ok "çıktı ters-kayıt diyor" || no "ters-kayıt çıktısı yok"
grep -q "SİLİNMEDİ" "$TMPD/geri.out" && ok "silinmediği açıkça söyleniyor" || no "silme-yokluğu söylenmiyor"
tail -1 "$BLOG" | grep -q '"tip":"devir"' && tail -1 "$BLOG" | grep -q 'GERİ-AL' && tail -1 "$BLOG" | grep -q '"kart_ref":"d1"' \
  && ok "ters kayıt gövdesi doğru (devir + GERİ-AL + kart_ref=d1)" || no "ters-kayıt gövdesi eksik: $(tail -1 "$BLOG")"

m2 geri-al m1 --gerekce "x y z" >/dev/null 2>&1; [ $? -eq 2 ] && ok "tip≠devir geri-al RC=2" || no "mesaj-kaydı geri-al kaçtı"
m2 geri-al yok9 --gerekce "x y z" >/dev/null 2>&1; [ $? -eq 2 ] && ok "olmayan id RC=2" || no "olmayan id kaçtı"
bash "$SUT" geri-al d1 >/dev/null 2>&1; [ $? -eq 2 ] && ok "gerekçesiz geri-al RC=2 (curl'e inmeden)" || no "gerekçesiz geri-al kaçtı"
fs26="sk-$(printf 'C%.0s' $(seq 1 20))"
bash "$SUT" geri-al d1 --gerekce "$fs26" >/dev/null 2>&1; [ $? -eq 2 ] && ok "sır-desenli gerekçe RC=2" || no "sır-desen kaçtı (geri-al)"

echo "== T20: BAYRAK KAPISI — taninmayan bayrak sessizce yutulmaz (2026-08-08, 14 oda) =="
# Regresyon: eski `gonder` YALNIZ 2. konumdaki --tetikli'yi tanirdi; baska her --xyz
# sessizce KONUMSAL METIN olurdu. Canli vaka: `--tip tetik --baslik "..."` -> baslik
# "--tip" oldu, mesaj BIR SAAT kuyrukta bekledi ve hedefi hic bulmadi.
OUT="$(bash "$SUT" gonder --tipx s04 "baslik" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "taninmayan bayrak RC=2" || no "taninmayan bayrak RC=$RC (2 bekleniyordu)"
echo "$OUT" | grep -q "tanınmayan bayrak" && ok "hata mesaji bayragi soyluyor" || no "hata mesaji bayragi sylemiyor"
echo "$OUT" | grep -q -- "--tetikli" && ok "gecerli bayrak listesi basiliyor" || no "gecerli bayrak listesi yok"
# Bayrak ASLA hedef/baslik olarak SIZMAMALI (asil zarar buydu)
echo "$OUT" | grep -qi "hedef sNN formatında" && no "bayrak konumsal-metin olarak sizdi" || ok "bayrak konumsal-metne SIZMIYOR"

echo "== T21: geriye-uyum — --tetikli aynen calisir, gerekcesiz hala reddedilir =="
OUT="$(bash "$SUT" gonder --tetikli s04 "baslik" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "--tetikli gerekcesiz RC=2 (degismedi)" || no "--tetikli gerekce kapisi bozuldu (rc=$RC)"

echo "== T22: durum KAPI MODU — kirmizi ekrana yaziliyordu ama exit=0 idi (MUAVIN olcumu) =="
# Kok kusur: `durum` probu KIRMIZI basip exit 0 donuyordu -> insan gorur, makine/cron goremez.
# Varsayilan report-only KORUNUR; --kapi sonucu cikis-koduna da yazar.
OUT="$(bash "$SUT" durum 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "bayraksiz durum exit=0 (geriye-uyum bozulmadi)" || no "bayraksiz durum exit=$RC (0 bekleniyordu)"
echo "$OUT" | grep -q "kapı:" && no "bayraksiz koşuda kapı-satiri sizdi" || ok "bayraksiz cikti degismedi (kapi-satiri yok)"

# token YOK + --kapi -> dogrulanamadi (3). "olculemedi != 0" fail-loud kurali.
OUT="$(bash "$SUT" durum --kapi 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && ok "tokensiz --kapi exit=3 (dogrulanamadi)" || no "tokensiz --kapi exit=$RC (3 bekleniyordu)"
echo "$OUT" | grep -q "DOĞRULANAMADI (exit=3)" && ok "kapi-satiri dogrulanamadi diyor" || no "kapi-satiri yok/yanlis"

# token VAR ama API erisilemez (sahte BASE) -> KIRMIZI (1). Asil kusurun kanidi.
TF2="$(mktemp -d)/token"; printf 'TESTTOKEN-xyz789\n' > "$TF2"
OUT="$(FEDERE_TOKEN_FILE="$TF2" bash "$SUT" durum --kapi 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "erisilemez API + --kapi exit=1 (kirmizi)" || no "kirmizi --kapi exit=$RC (1 bekleniyordu)"
echo "$OUT" | grep -q "KIRMIZI (exit=1)" && ok "kapi-satiri kirmizi diyor" || no "kirmizi kapi-satiri yok"
# AYNI kosu bayraksizken hala 0 donmeli (varsayilan report-only degismedi)
FEDERE_TOKEN_FILE="$TF2" bash "$SUT" durum >/dev/null 2>&1
[ $? -eq 0 ] && ok "ayni kirmizi durum bayraksiz hala exit=0" || no "varsayilan davranis bozuldu"
# Sir-sizmasi: token degeri hicbir kosuda basilmaz
echo "$OUT" | grep -q "TESTTOKEN-xyz789" && no "TOKEN DEGERI SIZDI" || ok "token degeri sizmiyor"

echo "== T23: durum taninmayan bayrak → 2 (kullanim; 3 ile karismaz) =="
OUT="$(bash "$SUT" durum --kapii 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "durum taninmayan bayrak RC=2" || no "durum bayrak-kapisi RC=$RC"
echo "$OUT" | grep -q -- "--kapi" && ok "gecerli bayrak listeleniyor" || no "gecerli bayrak listelenmiyor"

echo "== T19: bash -n sözdizimi =="
bash -n "$SUT" && ok "sözdizimi temiz" || no "sözdizimi hatası"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
