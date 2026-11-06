#!/usr/bin/env bash
# gorev-bekle.test.sh — hermetik sahte defter: bekle fiili "[bekliyor] <sebep>" adımı yazar (kart bunu okur); kısa/uzun/eksik sebep yazılmaz.
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
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=self.rfile.read(n) or b"{}"
        open(T+"/gelen.json","wb").write(b); open(T+"/sayi","a").write("x")
        self._yaz(200,{"kayit":{"id":"x","adimlar":[1]},"degisti":True,"ok":True})
s=http.server.HTTPServer(("127.0.0.1",0),H); open(T+"/port","w").write(str(s.server_address[1])); s.serve_forever()
PY
SP=$!; for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
E=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton")
yazim(){ [ -f "$T/sayi" ] && wc -c < "$T/sayi" | tr -d ' ' || echo 0; }; sifirla(){ rm -f "$T/sayi" "$T/gelen.json"; }
echo "── bekle fiili"
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A "Sultan onayını bekliyor" 2>&1); r=$?
ok "K1 sebep yazılır: rc 0, tek istek, adım '[bekliyor] <sebep>' biçiminde" '[ $r -eq 0 ] && [ "$(yazim)" = 1 ] && grep -q "\[bekliyor\] Sultan onayını bekliyor" "$T/gelen.json"'
ok "K2 adım metni kartın okuduğu '[bekliyor] ' önekiyle başlar ve kırpılmış sebebi taşır (kart tarafı: terminal-merkez gorev-ayrinti-tarayici-sinav B5/B9)" 'python3 -c "import json;a=json.load(open(\"$T/gelen.json\"))[\"adimlar\"];assert a==[\"[bekliyor] Sultan onayını bekliyor\"],a"'
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A "kısa" 2>&1); r=$?
ok "K3 5 harften kısa sebep yazılmaz: rc 2, istek yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A "$(printf 'a%.0s' $(seq 121))" 2>&1); r=$?
ok "K4 120 harften uzun sebep yazılmaz: rc 2, istek yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A 2>&1); r=$?
ok "K5 sebepsiz çağrı yazılmaz: rc 2, kullanımı söyler" '[ $r -eq 2 ] && [[ "$o" == *"kullanım"* ]] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A "        " 2>&1); r=$?
ok "K6 yalnız boşluktan oluşan sebep yazılmaz (denetçi tur 1): rc 2, istek yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" bekle gorev_A "   sebep boşluklu kenar   " 2>&1); r=$?
ok "K7 kenar boşlukları kırpılarak yazılır" 'grep -q "\[bekliyor\] sebep boşluklu kenar\"" "$T/gelen.json"'
echo "── $g geçti · $k düştü"; [ $k -eq 0 ]
