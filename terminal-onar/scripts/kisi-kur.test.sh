#!/usr/bin/env bash
# kisi-kur.sh sınavı — KUM HAVUZU (--kok): gerçek sistemde kullanıcı/grup/dizin YARATMAZ. Kuru kip hiçbir şeyi değiştirmemeli.
set -u; D="$(cd "$(dirname "$0")" && pwd)"; G=0; K=0
ok() { if [ "$2" = 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → $3"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$D/kisi-kur.sh" --kutu demo --kok "$T" >"$T/cikti" 2>&1; rc=$?
ok "Q1 kuru kip rc 0" "$rc" "rc=$rc"
ok "Q2 kuru kipte hiçbir dizin/dosya oluşmadı" "$([ -z "$(find "$T" -mindepth 1 -not -name cikti | head -1)" ] && echo 0 || echo 1)" "$(find "$T" -mindepth 1 -not -name cikti)"
ok "Q3 çıktı KURU KİP diyor ve 5+ adım sayıyor" "$(grep -q 'KURU KİP' "$T/cikti" && [ "$(grep -c '^ADIM' "$T/cikti")" -ge 6 ] && echo 0 || echo 1)" "$(grep -c '^ADIM' "$T/cikti")"
bash "$D/kisi-kur.sh" --kutu demo >"$T/kuru" 2>&1   # kum havuzsuz KURU kip: yalnız basar (süreç başlatma komutlarını görmek için)
ok "Q4 ttyd-kisi YAZILABİLİR (-W) ve sabit komut" "$(grep -q -- '-a -W python3 /opt/kisi/kisi-istemci.py' "$T/kuru" && echo 0 || echo 1)" ""
ok "Q5 abc'yi kişi grubuna EKLEMİYOR (usermod/gpasswd yok)" "$(grep -qE 'usermod|gpasswd|adduser abc' "$T/kuru" && echo 1 || echo 0)" ""
bash "$D/kisi-kur.sh" --kutu demo --kok "$T" --uygula >"$T/c2" 2>&1; rc=$?
ok "Q6 --uygula (kum havuzu) rc 0" "$rc" "$(tail -3 "$T/c2")"
ok "Q6b kum havuzunda süreç başlatılmadı, gerçek yola yazılmadı" "$([ ! -e /tmp/ttyd-kisi.log ] && grep -c 'süreç başlatma atlandı' "$T/c2" | grep -qx 2 && echo 0 || echo 1)" "$(ls /tmp/ttyd-kisi.log 2>&1)"
ok "Q7 soket dizini 0750" "$([ "$(stat -c %a "$T/run/kisi")" = 750 ] && echo 0 || echo 1)" "$(stat -c %a "$T/run/kisi" 2>&1)"
ok "Q8 izin iskeleti yazıldı ve JSON" "$(python3 -c "import json,sys;j=json.load(open('$T/config/.terminal-onar/kisi/izin.json'));assert j['kisiler'][0]['kutular']['demo']==[]" 2>/dev/null && echo 0 || echo 1)" ""
echo '{"kisiler":[{"id":"aysenur","kutular":{"demo":["x-ana"]}}]}' > "$T/config/.terminal-onar/kisi/izin.json"
bash "$D/kisi-kur.sh" --kutu demo --kok "$T" --uygula >/dev/null 2>&1
ok "Q9 var olan izin dosyasına DOKUNULMADI (Sultan yazar)" "$(grep -q x-ana "$T/config/.terminal-onar/kisi/izin.json" && echo 0 || echo 1)" ""
ok "Q10 istemci kök sahipli kopya yeri hazır" "$([ -x "$T/opt/kisi/kisi-istemci.py" ] && echo 0 || echo 1)" ""
bash "$D/kisi-kur.sh" --uid 5 >/dev/null 2>&1; ok "Q11 düşük uid reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
bash "$D/kisi-kur.sh" --kullanici 'a b' >/dev/null 2>&1; ok "Q12 geçersiz kullanıcı adı reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
[ "$(id -u)" != 0 ] && { bash "$D/kisi-kur.sh" --kutu demo --uygula >/dev/null 2>&1; ok "Q13 kök olmadan --uygula reddi (rc 2)" "$([ $? = 2 ] && echo 0 || echo 1)" ""; }
echo; echo "$G geçti, $K kaldı"; [ "$K" = 0 ]
