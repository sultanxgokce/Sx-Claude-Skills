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

echo "== T5d: BİLİNMEYEN BAYRAK → 2 (canlı vaka 2026-08-06: sessiz yutma, 1 saat kayıp mesaj) =="
# `--tip x --baslik y` eskiden METİN sayılıyordu: başlık '--tip' olup mesaj kuyrukta kayboluyordu.
bash "$SUT" gonder s10 --tip tetik --baslik "gövde" >/dev/null 2>&1; [ $? -eq 2 ] && ok "bilinmeyen-bayrak reddi (başlık yuvası)" || no "bilinmeyen bayrak SESSİZCE yutuldu"
# kart_ref yuvasındaki bayrak da yakalanmalı
bash "$SUT" gonder s10 "gerçek başlık" --kart k0001 >/dev/null 2>&1; [ $? -eq 2 ] && ok "bilinmeyen-bayrak reddi (kart yuvası)" || no "kart yuvasında bayrak kaçtı"
# not yuvasındaki bayrak da yakalanmalı
bash "$SUT" gonder s10 "gerçek başlık" "" --not "gövde" >/dev/null 2>&1; [ $? -eq 2 ] && ok "bilinmeyen-bayrak reddi (not yuvası)" || no "not yuvasında bayrak kaçtı"

echo "== T5e: NEGATİF — meşru çağrı bu kapıya TAKILMAZ (yanlış-pozitif yok) =="
# tire İÇEREN ama bayrak OLMAYAN başlık geçmeli → hedef-format dışında bir kapıya takılmamalı.
# Bozuk hedefle çağırıp RC=2'nin bayrak-kapısından DEĞİL hedef-kapısından geldiğini doğruluyoruz.
_cikti="$(bash "$SUT" gonder kutu-4 "acil-durum: kapı-2 kırmızı" 2>&1)"
echo "$_cikti" | grep -q "bilinmeyen bayrak" && no "yanlış-pozitif: tireli başlık bayrak sanıldı" || ok "tireli başlık bayrak sanılmadı"

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

echo "== T19: bash -n sözdizimi =="
bash -n "$SUT" && ok "sözdizimi temiz" || no "sözdizimi hatası"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
