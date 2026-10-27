#!/usr/bin/env bash
# kisi-kur.sh sınavı — KUM HAVUZU (--kok): gerçek sistemde kullanıcı/grup/dizin YARATMAZ. Kuru kip hiçbir şeyi değiştirmemeli.
set -u; D="$(cd "$(dirname "$0")" && pwd)"; G=0; K=0
ok() { if [ "$2" = 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → $3"; fi; }
export TTYD_BIN=/usr/bin/true   # sahte ttyd: sınav makinesinde ttyd olmayabilir
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
ok "Q7 soket dizini 3770 (ayse ttyd soketini açabilsin, koprusu.sock'a dokunamasın)" "$([ "$(stat -c %a "$T/run/kisi")" = 3770 ] && echo 0 || echo 1)" "$(stat -c %a "$T/run/kisi" 2>&1)"
ok "Q8 izin iskeleti yazıldı ve JSON" "$(python3 -c "import json,sys;j=json.load(open('$T/config/.terminal-onar/kisi/izin.json'));assert j['kisiler'][0]['kutular']['demo']==[]" 2>/dev/null && echo 0 || echo 1)" ""
echo '{"kisiler":[{"id":"aysenur","kutular":{"demo":["x-ana"]}}]}' > "$T/config/.terminal-onar/kisi/izin.json"
bash "$D/kisi-kur.sh" --kutu demo --kok "$T" --uygula >/dev/null 2>&1
ok "Q9 var olan izin dosyasına DOKUNULMADI (Sultan yazar)" "$(grep -q x-ana "$T/config/.terminal-onar/kisi/izin.json" && echo 0 || echo 1)" ""
ok "Q10 istemci kök sahipli kopya yeri hazır" "$([ -x "$T/opt/kisi/kisi-istemci.py" ] && echo 0 || echo 1)" ""
bash "$D/kisi-kur.sh" --uid 5 >/dev/null 2>&1; ok "Q11 düşük uid reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
bash "$D/kisi-kur.sh" --kullanici 'a b' >/dev/null 2>&1; ok "Q12 geçersiz kullanıcı adı reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
[ "$(id -u)" != 0 ] && { bash "$D/kisi-kur.sh" --kutu demo --uygula >/dev/null 2>&1; ok "Q13 kök olmadan --uygula reddi (rc 2)" "$([ $? = 2 ] && echo 0 || echo 1)" ""; }
# Q10-Q12: ttyd TAM yolu (26 Eki: medigate'te ttyd yalnız /config/.local/bin'de; çıplak ad `ayse` PATH'inde yok → ekran hiç başlamazdı)
ok "Q10 ttyd komutu çözülen TAM yolla yazılır" "$(grep -q -- '/usr/bin/true -i /run/kisi/ayse-ttyd.sock' "$T/kuru" && echo 0 || echo 1)" "$(grep ttyd-kisi -A1 "$T/kuru" | tail -1 | cut -c1-160)"
TTYD_BIN=/yok/ttyd bash "$D/kisi-kur.sh" --kutu demo >"$T/y" 2>&1; rc=$?
ok "Q11 ttyd bulunamazsa rc 3, 'ttyd bulunamadı', hiçbir adım basılmadı" "$([ "$rc" = 3 ] && grep -q 'ttyd bulunamadı' "$T/y" && ! grep -q '^ADIM' "$T/y" && echo 0 || echo 1)" "rc=$rc $(head -2 "$T/y")"
PUB="$(mktemp -d)"; chmod 755 "$PUB"; trap 'rm -rf "$T" "$PUB"' EXIT
printf '#!/bin/sh\n' > "$PUB/ozel-ttyd"; chmod 700 "$PUB/ozel-ttyd"
TTYD_BIN="$PUB/ozel-ttyd" bash "$D/kisi-kur.sh" --kutu demo >"$T/o" 2>&1; rc=$?
ok "Q12 ttyd dosyası başkalarına çalıştırılabilir değilse rc 3 (ayse çalıştıramaz)" "$([ "$rc" = 3 ] && grep -q 'çalıştırılabilir/geçilebilir değil' "$T/o" && echo 0 || echo 1)" "rc=$rc $(head -2 "$T/o")"
chmod 755 "$PUB/ozel-ttyd"; mkdir "$PUB/kapali"; cp "$PUB/ozel-ttyd" "$PUB/kapali/ttyd"; chmod 700 "$PUB/kapali"
TTYD_BIN="$PUB/kapali/ttyd" bash "$D/kisi-kur.sh" --kutu demo >"$T/d" 2>&1; rc=$?
ok "Q14 dosya açık ama ÜST DİZİN kapalıysa rc 3 (geçiş izni yok)" "$([ "$rc" = 3 ] && grep -q 'çalıştırılabilir/geçilebilir değil' "$T/d" && echo 0 || echo 1)" "rc=$rc $(head -2 "$T/d")"
( cd "$PUB" && TTYD_BIN=./ozel-ttyd bash "$D/kisi-kur.sh" --kutu demo >"$T/g" 2>&1 ); rc=$?
ok "Q15 göreli TTYD_BIN reddedilir (komuta mutlak yol yazılır)" "$([ "$rc" = 3 ] && grep -q 'mutlak yol olmalı' "$T/g" && echo 0 || echo 1)" "rc=$rc $(head -2 "$T/g")"
ln -s "$PUB/ozel-ttyd" "$PUB/bag-ttyd"; TTYD_BIN="$PUB/bag-ttyd" bash "$D/kisi-kur.sh" --kutu demo >"$T/b" 2>&1
ok "Q16 sembolik bağ çözülür: komuta GERÇEK dosyanın yolu yazılır" "$(grep -q -- "$PUB/ozel-ttyd -i /run/kisi" "$T/b" && ! grep -q 'bag-ttyd -i' "$T/b" && echo 0 || echo 1)" "$(grep ttyd-kisi -A1 "$T/b" | tail -1 | cut -c1-200)"
echo; echo "$G geçti, $K kaldı"; [ "$K" = 0 ]
