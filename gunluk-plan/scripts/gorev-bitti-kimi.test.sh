#!/usr/bin/env bash
# gorev-bitti-kimi.test.sh — hermetik sahte defter: bitti onay bekleyen işe bekleyen_kimi=sultan ve eylem=onay da yazar (bekçi "Sultan'da görünmüyor" zili atmasın).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'kill $SP 2>/dev/null; rm -r -- "$T"' EXIT
G="${GOREV_BETIK:-$HERE/gorev.sh}"; g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
printf 'sinav-jeton\n' > "$T/jeton"
python3 - "$T" <<'PY' &
import sys, json, http.server
T=sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _yaz(self,kod,obj):
        self.send_response(kod); self.send_header("content-type","application/json"); self.end_headers(); self.wfile.write(json.dumps(obj).encode())
    def do_GET(self):
        self._yaz(404,{})
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=self.rfile.read(n) or b"{}"
        open(T+"/gelen.json","wb").write(b); open(T+"/sayi","a").write("x")
        self._yaz(200,{"kayit":{"id":"x","adimlar":[1]},"degisti":True,"ok":True})
s=http.server.HTTPServer(("127.0.0.1",0),H); open(T+"/port","w").write(str(s.server_address[1])); s.serve_forever()
PY
SP=$!; for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
E=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton")
yazim(){ [ -f "$T/sayi" ] && wc -c < "$T/sayi" | tr -d ' ' || echo 0; }; sifirla(){ rm -f "$T/sayi" "$T/gelen.json"; }
echo "── bitti kimi+eylem"
sifirla; o=$("${E[@]}" bash "$G" bitti gorev_A --kim MÜZEHHİP --olcum "önce=5 sonra=3" 2>&1); r=$?
ok "B1 bitti: rc 0, tek istek" '[ $r -eq 0 ] && [ "$(yazim)" = 1 ]'
ok "B2 tek istekte durum onay-bekliyor + bekleyen_kimi sultan + eylem onay" 'python3 -c "import json;y=json.load(open(\"$T/gelen.json\"))[\"yerine\"];assert y[\"gorev_durumu\"]==\"onay-bekliyor\" and y[\"bekleyen_kimi\"]==\"sultan\" and y[\"eylem\"]==\"onay\""'
sifirla; o=$("${E[@]}" bash "$G" bitti gorev_A --kim MÜZEHHİP 2>&1); r=$?
ok "B3 kanıt sınıfsız bitti yine reddedilir: rc 2, istek yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
echo "── $g geçti · $k düştü"; [ $k -eq 0 ]
