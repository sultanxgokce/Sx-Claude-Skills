#!/usr/bin/env bash
# baglam-karti.test.sh — hermetik: geçici dizin + sahte Görev Defteri (yerel python sunucusu, her isteği kaydeder). Ağ dışı yok.
# Ölçülür: geçerli istek/cevap tek adım yazar (doğru uç, jeton başlıkta) · karar cümlesi ve kart metni kayda/ekrana DÜŞMEZ ·
# biçim kapıları rc 2 ve deftere istek GİTMEZ · jeton yok / defter düştü / defter reddetti → rc 1 (kart dönmez) ·
# aynı adım ikinci kez → rc 0 "zaten yazılı" · kuru koşum deftere dokunmaz · jeton değeri hiçbir çıktıda yok.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$D/baglam-karti.sh"; T="$(mktemp -d)"
gecen=0; kalan=0; kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }

# ── sahte defter: PATCH /kayit/<id> → kod dosyasındaki HTTP kodu; gövdedeki adım daha önce geldiyse degisti=false
cat > "$T/sunucu.py" <<'PY'
import http.server, json, sys, os
T = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_PATCH(self):
        g = self.rfile.read(int(self.headers.get("content-length", 0))).decode()
        with open(os.path.join(T, "istekler"), "a") as f:
            f.write(json.dumps({"yol": self.path, "jeton": self.headers.get("x-defter-jeton"), "govde": g}, ensure_ascii=False) + "\n")
        kip = open(os.path.join(T, "kod")).read().strip(); kod = int(kip.split(":")[0])
        adim = json.loads(g)["adimlar"][0]; gor = os.path.join(T, "gorulen")
        eski = open(gor).read().splitlines() if os.path.exists(gor) else []
        open(gor, "a").write(adim + "\n")
        y = json.dumps({"degisti": adim not in eski, "kayit": {"adimlar": eski + [adim]}} if kod == 200 else {"hata": "yasak"}).encode()
        if kip == "200:bos": y = b"{}"
        elif kip == "200:bozuk": y = b"<html>"
        elif kip == "200:adimsiz": y = json.dumps({"degisti": True, "kayit": {"adimlar": []}}).encode()
        self.send_response(kod); self.send_header("content-type", "application/json"); self.end_headers(); self.wfile.write(y)
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(os.path.join(T, "port"), "w").write(str(s.server_port)); s.serve_forever()
PY
echo 200 > "$T/kod"
python3 "$T/sunucu.py" "$T" & SP=$!
trap 'kill $SP 2>/dev/null; rm -r "$T"' EXIT
for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done
JETON="gizli-jeton-7f3a9c"; printf '%s\n' "$JETON" > "$T/jeton"
export DEFTER_UC="http://127.0.0.1:$(cat "$T/port")" DEFTER_JETON_YOL="$T/jeton" BAGLAM_KARTI_GOREV="gorev_01TEST"
M="$T/m"; mkdir -p "$M"
KARAR="Bu hafta yeni bir satış görüşmesi alınsın mı?"
KART="Bu hafta tempo düşük tutulursa iyi olur. Yeni görüşme yerine mevcutları kapatmak şu yönde."
istek() { printf 'HEDEF: enis\nKOPYA: muavin\n\n# SERDAR → ENİS · bağlam kartı isteği 1\n\nKarar:   %s\nUfuk:    %s\nSon an:  %s\n' "$KARAR" "$1" "$2" > "$M/$3"; }
cevap() { local h=merkez; case "$4" in ENIS-MAISET-*) h=maiset ;; esac
  printf 'HEDEF: %s\nKOPYA: muavin\n\n# ENİS → isteyen · bağlam kartı 1\n\nDurum:  %s\nKart:   %s\nKapı:   %s\n' "${HEDEF_ZORLA:-$h}" "$1" "$2" "$3" > "$M/$4"; }
say() { [ -f "$T/istekler" ] && wc -l < "$T/istekler" | tr -d ' ' || echo 0; }
K() { bash "$S" kaydet "$@" 2>&1; }

echo "── İ · istek"
istek "bu hafta" "2026-10-20 18:00" SERDAR-ENIS-baglam-karti-20261018-1.md
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-1.md")"; rc=$?
son="$(tail -1 "$T/istekler")"
kapi "İ1 geçerli istek rc 0, deftere TEK istek" "0|1" "$rc|$(say)"
kapi "İ2 doğru uç: PATCH /kayit/<görev>" "/kayit/gorev_01TEST" "$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["yol"])' "$son")"
kapi "İ3 adım metni şablon §3 biçiminde (karar cümlesi YOK)" "istek 20261018-1 · SERDAR · ufuk bu hafta · son an 2026-10-20 18:00" \
  "$(python3 -c 'import json,sys;print(json.loads(json.loads(sys.argv[1])["govde"])["adimlar"][0])' "$son")"
kapi "İ4 jeton başlıkta gider" "$JETON" "$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["jeton"])' "$son")"
kapi "İ5 karar cümlesi ne deftere ne ekrana düşer" "0|0" "$(grep -c "satış görüşmesi" "$T/istekler")|$(grep -c "satış görüşmesi" <<<"$out")"
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-1.md")"; rc=$?
kapi "İ6 aynı istek ikinci kez: rc 0, 'zaten yazılı'" "0|1" "$rc|$(grep -c 'zaten yazılıydı' <<<"$out")"

n0=$(say)
istek "yarın" "2026-10-20 18:00" SERDAR-ENIS-baglam-karti-20261018-2.md
K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md" >/dev/null; r1=$?
istek "bugün" "20 Ekim 18:00" SERDAR-ENIS-baglam-karti-20261018-3.md
K "$M/SERDAR-ENIS-baglam-karti-20261018-3.md" >/dev/null; r2=$?
printf 'HEDEF: enis\n\nUfuk: bugün\nSon an: 2026-10-20 18:00\n' > "$M/MAISET-ENIS-baglam-karti-20261018-4.md"
K "$M/MAISET-ENIS-baglam-karti-20261018-4.md" >/dev/null; r3=$?
istek "bugün" "2026-10-20 18:00" MENZIL-ENIS-baglam-karti-20261018-5.md
K "$M/MENZIL-ENIS-baglam-karti-20261018-5.md" >/dev/null; r4=$?
sed 's/^HEDEF: enis/HEDEF: maiset/' "$M/SERDAR-ENIS-baglam-karti-20261018-1.md" > "$M/SERDAR-ENIS-baglam-karti-20261018-6.md"
K "$M/SERDAR-ENIS-baglam-karti-20261018-6.md" >/dev/null; r5=$?
printf 'Karar: başka\n' >> "$M/SERDAR-ENIS-baglam-karti-20261018-1.md"
K "$M/SERDAR-ENIS-baglam-karti-20261018-1.md" >/dev/null; r6=$?
kapi "İ7 biçim kapıları rc 2: ufuk · son an · karar yok · izinsiz isteyen · HEDEF · çift alan" "2|2|2|2|2|2" "$r1|$r2|$r3|$r4|$r5|$r6"
kapi "İ8 biçim hatasında deftere istek GİTMEZ" "$n0" "$(say)"

echo "── C · cevap"
cevap "verildi" "$KART" "geçti (dis-raf-kapi.sh rc=0)" ENIS-SERDAR-baglam-karti-20261018-1.md
out="$(K "$M/ENIS-SERDAR-baglam-karti-20261018-1.md")"; rc=$?
kapi "C1 verildi + kapı geçti: rc 0, adım şablon biçiminde" "0|cevap 20261018-1 · SERDAR · durum verildi · kapı geçti" \
  "$rc|$(python3 -c 'import json,sys;print(json.loads(json.loads(sys.argv[1])["govde"])["adimlar"][0])' "$(tail -1 "$T/istekler")")"
kapi "C2 kart metni ne deftere ne ekrana düşer" "0|0" "$(grep -c "tempo düşük" "$T/istekler")|$(grep -c "tempo düşük" <<<"$out")"
n0=$(say)
cevap "verildi" "$KART" "—" ENIS-SERDAR-baglam-karti-20261018-2.md
K "$M/ENIS-SERDAR-baglam-karti-20261018-2.md" >/dev/null; r1=$?
cevap "verildi" "" "geçti" ENIS-SERDAR-baglam-karti-20261018-3.md
K "$M/ENIS-SERDAR-baglam-karti-20261018-3.md" >/dev/null; r2=$?
cevap "kapalı" "$KART" "—" ENIS-SERDAR-baglam-karti-20261018-4.md
K "$M/ENIS-SERDAR-baglam-karti-20261018-4.md" >/dev/null; r3=$?
cevap "belki" "" "—" ENIS-MAISET-baglam-karti-20261018-5.md
K "$M/ENIS-MAISET-baglam-karti-20261018-5.md" >/dev/null; r4=$?
HEDEF_ZORLA=merkez cevap "kapalı" "" "—" ENIS-MAISET-baglam-karti-20261018-8.md
K "$M/ENIS-MAISET-baglam-karti-20261018-8.md" >/dev/null; r5=$?
HEDEF_ZORLA=maiset cevap "verildi" "$KART" "geçti" ENIS-SERDAR-baglam-karti-20261018-10.md
K "$M/ENIS-SERDAR-baglam-karti-20261018-10.md" >/dev/null; r6=$?
kapi "C3 kapıdan geçmemiş kart · boş kart · kapalıda kart metni · bilinmeyen durum · yanlış kutuya HEDEF (×2) → rc 2" "2|2|2|2|2|2" "$r1|$r2|$r3|$r4|$r5|$r6"
kapi "C4 bu hatalarda deftere istek GİTMEZ" "$n0" "$(say)"
cevap "kapalı" "" "—" ENIS-MAISET-baglam-karti-20261018-6.md
out="$(K "$M/ENIS-MAISET-baglam-karti-20261018-6.md")"; rc=$?
cevap "dayanak yok" "" "" ENIS-SERDAR-baglam-karti-20261018-7.md
K "$M/ENIS-SERDAR-baglam-karti-20261018-7.md" >/dev/null; rc2=$?
kapi "C5 kapalı ve dayanak yok: rc 0, kapı '—'" "0|0|cevap 20261018-7 · SERDAR · durum dayanak yok · kapı —" \
  "$rc|$rc2|$(python3 -c 'import json,sys;print(json.loads(json.loads(sys.argv[1])["govde"])["adimlar"][0])' "$(tail -1 "$T/istekler")")"

echo "── F · fail-closed (kayıt yazılamazsa kart dönmez)"
istek "bugün" "2026-10-18 20:00" SERDAR-ENIS-baglam-karti-20261018-9.md
n0=$(say)
out="$(DEFTER_JETON_YOL="$T/yok" K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md")"; rc=$?
kapi "F1 jeton yok → rc 1, deftere istek yok" "1|$n0" "$rc|$(say)"
echo 500 > "$T/kod"
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md")"; rc=$?
kapi "F2 defter reddetti (http 500) → rc 1, 'kart dönmez'" "1|1" "$rc|$(grep -c 'kart dönmez' <<<"$out")"
echo 200 > "$T/kod"
out="$(DEFTER_UC="http://127.0.0.1:1" K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md")"; rc=$?
kapi "F3 defter ulaşılamaz → rc 1" "1" "$rc"
for kip in bos bozuk adimsiz; do echo "200:$kip" > "$T/kod"; K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md" >/dev/null; eval "r_$kip=\$?"; done
echo 200 > "$T/kod"
kapi "F6 defter 200 ama gövde boş · bozuk · adım kayıtta yok → rc 1 (kayıt doğrulanamadı, kart dönmez)" "1|1|1" "$r_bos|$r_bozuk|$r_adimsiz"
n0=$(say)
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md" --kuru)"; rc=$?
kapi "F4 kuru koşum: rc 3 (taşıma izni değil), adımı basar, deftere dokunmaz" "3|1|$n0" "$rc|$(grep -c 'istek 20261018-9 · SERDAR · ufuk bugün' <<<"$out")|$(say)"
K "$M/yok.md" >/dev/null; r1=$?; K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md" --gorev 'x;rm' >/dev/null; r2=$?
kapi "F5 mektup yok · biçimsiz görev kimliği → rc 2" "2|2" "$r1|$r2"

echo "── G · jeton hijyeni"
hepsi="$(for f in "$M"/*.md; do K "$f" 2>&1; done; K "$M/SERDAR-ENIS-baglam-karti-20261018-9.md" --kuru)"
kapi "G1 jeton değeri hiçbir çıktıda yok" "0" "$(grep -c "$JETON" <<<"$hepsi")"

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
