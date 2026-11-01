#!/usr/bin/env bash
# gorev-ustlen-baslik.test.sh — hermetik: sahte defter (GET kayıt tablosu · PATCH gövdesini kaydeder). SERDAR 1 Kas 2026 kök iş:
#   ustlen Sultan-dili özeti olmayan kaydı üstlendirmez (rc 2, hiçbir şey yazılmaz; okunamazsa rc 1) · baslik fiili AD EKLER, eski ad kayıtta kalır.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'kill $SP 2>/dev/null; rm -r -- "$T"' EXIT
G="${GOREV_BETIK:-$HERE/gorev.sh}"; g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
printf 'sinav-jeton\n' > "$T/jeton"
python3 - "$T" <<'PY' &
import sys, json, http.server
T=sys.argv[1]
KAYIT={
 "gorev_OZETLI":  {"id":"gorev_OZETLI","baslik":"Önemli dosyalar sayfası","adlar":[{"deger":"Önemli dosyalar sayfası"}],"canli":{"ozet_sultan":"Sayfa canlıya inecek","gorev_durumu":"acik"}},
 "gorev_OZETSIZ": {"id":"gorev_OZETSIZ","baslik":"Sayfa canlıya alınır (yalnız /onemli)","adlar":[{"deger":"Sayfa canlıya alınır (yalnız /onemli)"}],"canli":{"gorev_durumu":"havuz"}},
 "gorev_BOSLUK":  {"id":"gorev_BOSLUK","baslik":"b","adlar":[{"deger":"b"}],"canli":{"ozet_sultan":"   ","gorev_durumu":"havuz"}},
}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _yaz(self,kod,obj):
        self.send_response(kod); self.send_header("content-type","application/json"); self.end_headers(); self.wfile.write(json.dumps(obj).encode())
    def do_GET(self):
        i=self.path.rsplit("/",1)[-1]
        if i=="gorev_BOZUK": return self._yaz(500,{"hata":"sunucu"})
        if i in KAYIT: return self._yaz(200,{"kayit":KAYIT[i]})
        return self._yaz(404,{"hata":"kayit_yok"})
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=self.rfile.read(n) or b"{}"
        open(T+"/gelen.json","wb").write(b); open(T+"/sayi","a").write("x")
        i=self.path.rsplit("/",1)[-1]; kay=dict(KAYIT.get(i,{"id":i,"canli":{}}))
        g=json.loads(b); kay["canli"]=dict(kay.get("canli",{}), **(g.get("yerine") or {}))
        if g.get("adlar"): kay["baslik"]=g["adlar"][-1]
        self._yaz(200,{"kayit":kay,"ok":True})
s=http.server.HTTPServer(("127.0.0.1",0),H); open(T+"/port","w").write(str(s.server_address[1])); s.serve_forever()
PY
SP=$!; for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
E=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton")
yazim(){ [ -f "$T/sayi" ] && wc -c < "$T/sayi" | tr -d ' ' || echo 0; }; sifirla(){ rm -f "$T/sayi" "$T/gelen.json"; }
alan(){ python3 -c "import json,sys; print(json.dumps(json.load(open('$T/gelen.json')).get(sys.argv[1],'YOK'),ensure_ascii=False))" "$1"; }

echo "── ustlen özet geçidi"
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_OZETSIZ --kim HEZARFEN --tahmin 20 2>&1); r=$?
ok "U1 özetsiz kayıt üstlenilemez: rc 2, özeti nasıl yazacağını söyler, hiçbir şey yazılmadı" '[ $r -eq 2 ] && [[ "$o" == *"Sultan-dili özet yok"* ]] && [[ "$o" == *"gorev.sh ozet gorev_OZETSIZ"* ]] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_BOSLUK --kim HEZARFEN --tahmin 20 2>&1); r=$?
ok "U2 yalnız boşluktan oluşan özet de yok sayılır: rc 2, yazım yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_BOZUK --kim HEZARFEN --tahmin 20 2>&1); r=$?
ok "U3 kayıt okunamazsa (sunucu 500) ÜSTLENİLMEZ: rc 1, özetli sayılmaz, yazım yok" '[ $r -eq 1 ] && [[ "$o" == *"üstlenilmedi"* ]] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_OZETLI --kim HEZARFEN --tahmin 20 2>&1); r=$?
ok "U4 özetli kayıt üstlenilir: rc 0, çalışılıyor + atanan yazılır" '[ $r -eq 0 ] && [[ "$o" == *"▶ çalışılıyor"* ]] && [ "$(yazim)" = 1 ] && [ "$(alan yerine)" != YOK ]'
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_OZETSIZ --kim HEZARFEN --tahmin 20 --duraklat gorev_OZETLI 2>&1); r=$?
ok "U5 --duraklat ile de özetsiz kayıt üstlenilemez: rc 2, eski işe de adım yazılmaz" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" ustlen gorev_OZETLI --kim HEZARFEN 2>&1); r=$?
ok "U6 tahmin yine zorunlu (eski kural bozulmadı): rc 2" '[ $r -eq 2 ] && [[ "$o" == *"tahmin ZORUNLU"* ]] && [ "$(yazim)" = 0 ]'

echo "── baslik fiili"
sifirla; o=$("${E[@]}" bash "$G" baslik gorev_OZETSIZ "Sayfa canlıya alınır, yalnız ilgili kişi görür" "başlıktaki yol Sultan-diline çevrildi" 2>&1); r=$?
ok "B1 baslik: rc 0, AD EKLENİR (adlar dizisi), tashih (yerine) KULLANILMAZ — eski ad kapanmaz" '[ $r -eq 0 ] && [ "$(alan adlar)" = "[\"Sayfa canlıya alınır, yalnız ilgili kişi görür\"]" ] && [ "$(alan yerine)" = "\"YOK\"" ] && [ "$(yazim)" = 1 ]'
ok "B2 adım eski ve yeni başlığı birlikte taşır (eski ad kayıtta okunur)" '[[ "$(alan adimlar)" == *"[başlık düzeltildi]"* ]] && [[ "$(alan adimlar)" == *"yalnız /onemli"* ]] && [[ "$(alan adimlar)" == *"yalnız ilgili kişi görür"* ]]'
ok "B3 çıktı yeni başlığı ve eski adın kayıtta kaldığını söyler" '[[ "$o" == *"yalnız ilgili kişi görür"* ]] && [[ "$o" == *"eski ad kayıtta kalır"* ]]'
sifirla; o=$("${E[@]}" bash "$G" baslik gorev_OZETSIZ "Sayfa canlıya alınır (yalnız /onemli)" "aynı başlık" 2>&1); r=$?
ok "B4 yeni başlık mevcutla aynıysa rc 2, yazım yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" baslik gorev_OZETSIZ "Yeni başlık" "kısa" 2>&1); r=$?
ok "B5 gerekçe 5 harften kısaysa rc 2, yazım yok" '[ $r -eq 2 ] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" baslik gorev_OZETSIZ 2>&1); r=$?
ok "B6 eksik argüman rc 2 + kullanım" '[ $r -eq 2 ] && [[ "$o" == *"kullanım: gorev.sh baslik"* ]] && [ "$(yazim)" = 0 ]'
sifirla; o=$("${E[@]}" bash "$G" baslik gorev_YOK "Yeni başlık" "gerekçe yazıldı" 2>&1); r=$?
ok "B7 kayıt yoksa rc 1, yazım yok" '[ $r -eq 1 ] && [ "$(yazim)" = 0 ]'

if [ -z "${GOREV_BETIK:-}" ]; then
  echo "── mutasyon (kapı sökülünce sınav kırmızıya dönmeli)"
  mut() { local M="$HERE/.mutant-gub-$$-$1"; python3 -I - "$G" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 'false'; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4],1); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(GOREV_BETIK="$M" bash "$0" 2>&1)"; rm -f -- "$M"; ok "mutant '$1' → $4 kırmızı" "grep -q '✗ $4 ' <<<\"\$o\"" ; }
  mut ozet-kapisi-yok '[ -n "${OZ// /}" ] ||' ': ||' U1
  mut okunamayan-gecer 'üstlenilmedi — $OZ" >&2; exit 1; }' 'üstlenilmedi — $OZ" >&2; true; }' U3
  mut baslik-tashih-kullanir '{"adlar":[sys.argv[1].strip()],"gerekce"' '{"yerine":{"x":sys.argv[1].strip()},"gerekce"' B1
fi
echo "== $g geçti · $k düştü =="; [ "$k" -eq 0 ]
