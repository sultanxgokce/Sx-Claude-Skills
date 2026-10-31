#!/usr/bin/env bash
# yazici-kapisi.test.sh — hermetik: sahte defter (POST/PATCH gövdesini kaydeder). Kapılar (görev …9ABX5): kayıt odasız doğmaz · 80 harf ve üstü özet reddedilir.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'kill $SP 2>/dev/null; rm -r -- "$T"' EXIT
G="$HERE/gorev.sh"; g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
printf 'sinav-jeton\n' > "$T/jeton"; printf -- '- id: BILGE\n  oda: mesajlasma\n' > "$T/ekip.yaml"
python3 - "$T" <<'PY' &
import sys, json, http.server
T=sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _k(self):
        n=int(self.headers.get("content-length") or 0); b=self.rfile.read(n) or b"{}"
        open(T+"/gelen.json","wb").write(b); open(T+"/sayi","a").write("x")
        self.send_response(200 if self.command=="PATCH" else 201); self.send_header("content-type","application/json"); self.end_headers()
        self.wfile.write(json.dumps({"kayit":{"id":"gorev_X","canli":{"kutu":"k","adlar":["b"],"ozet_sultan":"o"},"adlar":["b"]},"ok":True}).encode())
    do_POST=_k; do_PATCH=_k
    def do_GET(self):
        self.send_response(200); self.send_header("content-type","application/json"); self.end_headers(); self.wfile.write(b'{"sinif":"ajan"}')
s=http.server.HTTPServer(("127.0.0.1",0),H); open(T+"/port","w").write(str(s.server_address[1])); s.serve_forever()
PY
SP=$!; for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
E=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton" GOREV_EKIP_KAYDI="$T/ekip.yaml" GOREV_KOLTUK=)
alan(){ python3 -c "import json,sys; print(json.load(open('$T/gelen.json')).get(sys.argv[1],'YOK'))" "$1"; }
uzun="$(printf 'a%.0s' $(seq 1 80))"; kisa="$(printf 'a%.0s' $(seq 1 79))"
o=$("${E[@]}" bash "$G" ekle "odasız ekle" --kutu k --ozet "$kisa" 2>&1); r=$?
ok "E1 ekle: oda verilmedi, koltuk da yok → agentic-os yazılır ve söylenir" '[ $r -eq 0 ] && [ "$(alan oda)" = agentic-os ] && [[ "$o" == *"varsayılan oda agentic-os"* ]]'
o=$("${E[@]}" GOREV_KOLTUK=BILGE bash "$G" ekle "koltuk odası" --kutu k --ozet "$kisa" 2>&1); r=$?
ok "E2 ekle: koltuğun ekip kaydındaki odası kullanılır" '[ $r -eq 0 ] && [ "$(alan oda)" = mesajlasma ]'
o=$("${E[@]}" bash "$G" ekle "açık oda" --kutu k --ozet "$kisa" --oda kuzey 2>&1); r=$?
ok "E3 ekle: açık --oda her şeyden önce" '[ $r -eq 0 ] && [ "$(alan oda)" = kuzey ]'
: > "$T/sayi"
o=$("${E[@]}" bash "$G" ekle "uzun özet" --kutu k --ozet "$uzun" 2>&1); r=$?
ok "E4 ekle: 80 harflik özet rc 2, deftere HİÇ gidilmez" '[ $r -eq 2 ] && [[ "$o" == *"80 harften KISA"* ]] && [ ! -s "$T/sayi" ]'
o=$("${E[@]}" bash "$G" ac "odasız ac" --kutu k --ozet "$kisa" 2>&1); r=$?
ok "A1 ac: oda verilmedi → agentic-os" '[ $r -eq 0 ] && [ "$(alan oda)" = agentic-os ]'
o=$("${E[@]}" bash "$G" ac "uzun ac" --kutu k --ozet "$uzun" 2>&1); r=$?
ok "A2 ac: 80 harflik özet rc 2" '[ $r -eq 2 ] && [[ "$o" == *"80 harften KISA"* ]]'
o=$("${E[@]}" bash "$G" bulgu "odasız bulgu" --kim X 2>&1); r=$?
ok "B1 bulgu: oda verilmedi → agentic-os" '[ $r -eq 0 ] && [ "$(alan oda)" = agentic-os ]'
: > "$T/sayi"
o=$("${E[@]}" bash "$G" ozet gorev_X "$uzun" 2>&1); r=$?
ok "Z1 ozet tashih: 80 harf rc 2, deftere gidilmez" '[ $r -eq 2 ] && [ ! -s "$T/sayi" ]'
o=$("${E[@]}" bash "$G" ozet gorev_X "$kisa" 2>&1); r=$?
ok "Z2 ozet tashih: 79 harf geçer" '[ $r -eq 0 ]'
echo "yazici-kapisi.test: $g geçti · $k kaldı"; [ "$k" -eq 0 ]
