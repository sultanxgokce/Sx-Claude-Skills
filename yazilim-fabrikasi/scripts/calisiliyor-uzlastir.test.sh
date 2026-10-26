#!/usr/bin/env bash
# calisiliyor-uzlastir.test.sh — uzlaştırma kuralının sınavı (DKYSHH + X666): sahte defter + sahte kart dizinleri, gerçek deftere dokunmaz.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; U="$D/calisiliyor-uzlastir.py"; T="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'kill ${SRV:-0} 2>/dev/null; sil "$T"' EXIT
p=0; f=0; g() { if [ "$1" -eq 0 ]; then p=$((p+1)); echo "PASS  $2"; else f=$((f+1)); echo "FAIL  $2"; fi; }
GIZLI="uzlastir-gizli-jeton-0123"; printf '%s\n' "$GIZLI" > "$T/jeton"
mkdir -p "$T/k1" "$T/k2"
python3 - "$T" <<'PY' &
import sys, json, http.server, socketserver, os
T=sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        if self.headers.get("x-defter-jeton")!="uzlastir-gizli-jeton-0123": self.send_response(401); self.end_headers(); return
        self.send_response(200); self.end_headers(); self.wfile.write(open(os.path.join(T,"gorevler.json"),"rb").read())
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=json.loads(self.rfile.read(n) or b"{}")
        open(os.path.join(T,"yazim.jsonl"),"a").write(json.dumps({"yol":self.path,"govde":b},ensure_ascii=False)+"\n")
        self.send_response(409 if os.path.exists(os.path.join(T,"ret")) else 200); self.end_headers(); self.wfile.write(b"{}")
with socketserver.TCPServer(("127.0.0.1",0),H) as s:
    open(os.path.join(T,"port"),"w").write(str(s.server_address[1])); s.serve_forever()
PY
SRV=$!; for i in $(seq 1 25); do [ -f "$T/port" ] && break; sleep 0.2; done
UC="http://127.0.0.1:$(cat "$T/port")"
gor() { python3 - "$@" <<'PY'   # gor <id> <atanan> <durum> <son>
import sys, json; i,a,d,s=sys.argv[1:5]
print(json.dumps({"id":i,"canli":{"gorev_durumu":d,"atanan":a},"adlar":[{"deger":"iş "+i}],"son_adim":s}))
PY
}
defter() { printf '{"gorevler":[%s]}' "$(IFS=,; echo "$*")" > "$T/gorevler.json"; }
kart() { # kart <dizin> <is> <aldi> <durum> <gorev>
  printf '{"is":"%s","aldi":"%s","durum":"%s","gorev":"%s"}' "$2" "$3" "$4" "$5" > "$1/$2.json"; }
yz() { [ -f "$T/yazim.jsonl" ] && wc -l < "$T/yazim.jsonl" || echo 0; }
kos() { rm -f "$T/yazim.jsonl"; python3 "$U" --ajan "${AJAN:-BERİD}" --defter-uc "${DUC:-$UC}" --jeton-yol "${JY:-$T/jeton}" --kart-kok "$T/k1" --kart-kok "$T/k2" "$@" > "$T/cikti" 2>&1; echo $?; }

echo "════ calisiliyor-uzlastir ════"
# U1: iki kartlı çalışılıyor → azami içinde, dokunulmaz
kart "$T/k1" a BERİD acik gorev_A; kart "$T/k2" b BERID acik gorev_B
defter "$(gor gorev_A BERİD calisiliyor 2026-10-26T10:00)" "$(gor gorev_B BERİD calisiliyor 2026-10-26T09:00)"
RC=$(kos --uygula); [ "$RC" = 0 ] && [ "$(yz)" = 0 ]; g $? "U1 iki kartlı çalışılıyor (azami 2) dokunulmaz, deftere yazım YOK (kart ad yazımı BERID/BERİD eşit sayılır)"
# U2: üç kartlı → en eski bekliyor
kart "$T/k1" c BERİD acik gorev_C
defter "$(gor gorev_A BERİD calisiliyor 2026-10-26T10:00)" "$(gor gorev_B BERİD calisiliyor 2026-10-26T09:00)" "$(gor gorev_C BERİD calisiliyor 2026-10-26T08:00)"
RC=$(kos); [ "$RC" = 0 ] && [ "$(yz)" = 0 ] && grep -q "KURU: gorev_C" "$T/cikti"; g $? "U2 KURU (varsayılan): fazla olan en eski (gorev_C) söylenir, deftere YAZILMAZ"
RC=$(kos --uygula); [ "$RC" = 0 ] && [ "$(yz)" = 1 ] && grep -q '"/kayit/gorev_C"\|/kayit/gorev_C' "$T/yazim.jsonl" && python3 -c "import json;y=json.loads(open('$T/yazim.jsonl').readline())['govde']['yerine'];assert y['gorev_durumu']=='bekliyor' and 'başka işe geçti' in y['not']"; g $? "U2b --uygula: yalnız en eski (gorev_C) bekliyor + 'başka işe geçti' notu (defter notsuz bekliyor'u reddeder)"
# U3: kartı olmayan çalışılıyor (X666)
defter "$(gor gorev_A BERİD calisiliyor 2026-10-26T10:00)" "$(gor gorev_Y BERİD calisiliyor 2026-10-26T10:30)"
RC=$(kos --uygula); [ "$RC" = 0 ] && [ "$(yz)" = 1 ] && grep -q "/kayit/gorev_Y" "$T/yazim.jsonl" && grep -q "açık kartı yok" "$T/yazim.jsonl"; g $? "U3 açık kartı olmayan çalışılıyor görev (gorev_Y) bekliyor'a çekilir, kartlı olan (gorev_A) kalır"
# U4: kart bitmiş/canlı borçlu → kartı yok sayılır
kart "$T/k1" a BERİD canli-borclu gorev_A
defter "$(gor gorev_A BERİD calisiliyor 2026-10-26T10:00)"
RC=$(kos --uygula); [ "$RC" = 0 ] && [ "$(yz)" = 1 ] && grep -q "/kayit/gorev_A" "$T/yazim.jsonl"; g $? "U4 kartı canlı-borçlu/bitti olan görev açık kart sayılmaz (kapanan iş çalışılıyor görünmez)"
kart "$T/k1" a BERİD acik gorev_A
# U5: başkasının görevi, bekliyor/açık görev dokunulmaz
defter "$(gor gorev_Z BASİRET calisiliyor 2026-10-26T10:00)" "$(gor gorev_W BERİD bekliyor 2026-10-26T10:00)" "$(gor gorev_V BERİD acik 2026-10-26T10:00)"
RC=$(kos --uygula); [ "$RC" = 0 ] && [ "$(yz)" = 0 ]; g $? "U5 başka ajanın çalışılıyor işi ve bizim bekliyor/acik işlerimiz dokunulmaz"
# U6: jeton değeri çıktıda yok; jetonsuz rc 4
defter "$(gor gorev_Y BERİD calisiliyor 2026-10-26T10:30)"
RC=$(kos --uygula); ! grep -q "$GIZLI" "$T/cikti" && ! grep -q "$GIZLI" "$T/yazim.jsonl"; g $? "U6 jeton DEĞERİ ne çıktıda ne deftere giden gövdede"
RC=$(JY="$T/yok" kos); [ "$RC" = 4 ] && grep -q "jetonu okunamadı" "$T/cikti"; g $? "U6b jeton yok: rc 4 ve söylenir (sessiz geçmez)"
RC=$(DUC="http://127.0.0.1:1" kos); [ "$RC" = 4 ] && grep -q "okunamadı" "$T/cikti"; g $? "U7 defter erişilemez: rc 4 ve söylenir"
touch "$T/ret"; RC=$(kos --uygula); rm -f "$T/ret"; [ "$RC" = 4 ] && grep -q "çekilemedi" "$T/cikti"; g $? "U8 defter bekliyor'u reddederse (409): rc 4, başarı denmez"
RC=$(kos --azami 0); [ "$RC" = 2 ]; g $? "U9 --azami 0 geçersiz: rc 2"
# U10: azami ayarı
kart "$T/k1" c BERİD acik gorev_C
defter "$(gor gorev_A BERİD calisiliyor 2026-10-26T10:00)" "$(gor gorev_B BERİD calisiliyor 2026-10-26T09:00)" "$(gor gorev_C BERİD calisiliyor 2026-10-26T08:00)"
RC=$(kos --uygula --azami 3); [ "$RC" = 0 ] && [ "$(yz)" = 0 ]; g $? "U10 --azami 3 ile üç kartlı iş dokunulmaz (sayı kuraldan gelir, koda gömülü değil)"
echo "── SONUÇ: PASS=$p FAIL=$f ──"; [ "$f" -eq 0 ]
