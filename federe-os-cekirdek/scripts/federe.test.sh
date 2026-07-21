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

echo "-- T17: dinle ACK-409'da batch ÖLMEZ (kalan işlenir + RC=1 + uyarı) --"
INB="$TMPD/inbox.md"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok FEDERE_TETIK_INBOX="$INB" bash "$SUT" dinle 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "dinle kısmi-ACK RC=1" || no "dinle RC yanlış (rc=$RC)"
echo "$OUT" | grep -q "ACK düşmedi: t1" && ok "ACK-hata uyarısı basıldı (ölü-kod değil)" || no "ACK-uyarı yok"
[ -f "$INB" ] && [ "$(grep -c '^- \[' "$INB")" -eq 2 ] && ok "batch tamamı inbox'a düştü (2/2)" || no "inbox eksik ($(grep -c '^- \[' "$INB" 2>/dev/null || echo 0)/2)"
echo "$OUT" | grep -q "1 ok · 1 düşmedi" && ok "kısmi-ACK özeti dürüst" || no "özet-satırı yanlış"

echo "-- T18: nabiz 201 kontrat --"
OUT="$(FEDERE_API_BASE="http://127.0.0.1:$MPORT" FEDERE_TETIK_TOKEN=dummytok bash "$SUT" nabiz "mock-nabız" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "cell=s09" && ok "nabiz kontrat-parse RC=0" || no "nabiz mock yanlış (rc=$RC)"

echo "== T19: bash -n sözdizimi =="
bash -n "$SUT" && ok "sözdizimi temiz" || no "sözdizimi hatası"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
