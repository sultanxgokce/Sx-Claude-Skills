#!/usr/bin/env bash
# kisi-sok.sh sınavı — KUM HAVUZU (--kok): gerçek sistemde kullanıcı/grup/dizin SİLMEZ. Kuru kip hiçbir şeyi değiştirmemeli.
set -u; D="$(cd "$(dirname "$0")" && pwd)"; G=0; K=0
ok() { if [ "$2" = 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → $3"; fi; }
T="$(mktemp -d)"; O="$(mktemp -d)"; DEKOY=""
temizle() { [ -n "$DEKOY" ] && kill "$DEKOY" 2>/dev/null; find "$T" "${T2:-/nonexistent}" "$O" -mindepth 0 -delete 2>/dev/null; }
trap temizle EXIT
bash "$D/kisi-kur.sh" --kutu demo --kok "$T" --uygula >/dev/null 2>&1
echo '{"kisiler":[{"id":"aysenur","kutular":{"demo":["x-ana"]}}]}' > "$T/config/.terminal-onar/kisi/izin.json"
touch "$T/run/kisi/koprusu.sock" "$T/run/kisi/ayse-ttyd.sock"
imza() { (cd "$T" && find . | sort | xargs -d '\n' stat -c '%n %a %s' 2>/dev/null | sha256sum); }
once="$(imza)"
bash "$D/kisi-sok.sh" --kutu demo --kok "$T" >"$O/k" 2>&1; rc=$?
ok "S1 kuru kip rc 0" "$rc" "rc=$rc"
ok "S2 kuru kipte hiçbir şey değişmedi" "$([ "$once" = "$(imza)" ] && echo 0 || echo 1)" ""
ok "S3 kuru çıktı KURU KİP diyor ve 4 adım sayıyor" "$(grep -q 'KURU KİP' "$O/k" && [ "$(grep -c '^ADIM' "$O/k")" = 4 ] && echo 0 || echo 1)" "$(grep -c '^ADIM' "$O/k")"
bash "$D/kisi-sok.sh" --kutu demo --kok "$T" --uygula >"$O/u" 2>&1; rc=$?
ok "S4 --uygula (kum havuzu) rc 0" "$rc" "$(tail -3 "$O/u")"
ok "S5 soketler, /run/kisi, istemci kopyası ve /opt/kisi kalktı" "$([ ! -e "$T/run/kisi" ] && [ ! -e "$T/opt/kisi" ] && echo 0 || echo 1)" "$(ls "$T/run" "$T/opt" 2>&1)"
ok "S6 izin dosyası DOKUNULMADI (Sultan verisi)" "$(grep -q x-ana "$T/config/.terminal-onar/kisi/izin.json" && echo 0 || echo 1)" ""
ok "S7 çıktı izin dosyasının dokunulmadığını söylüyor" "$(grep -q 'DOKUNULMADI (Sultan verisi)' "$O/u" && echo 0 || echo 1)" ""
bash "$D/kisi-sok.sh" --kutu demo --kok "$T" --uygula >"$O/u2" 2>&1; rc=$?
ok "S8 ikinci koşu İDEMPOTENT (rc 0, 'zaten yok')" "$([ "$rc" = 0 ] && grep -q 'zaten yok' "$O/u2" && echo 0 || echo 1)" "rc=$rc"
bash "$D/kisi-sok.sh" --uid 5 >/dev/null 2>&1; ok "S9 düşük uid reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
bash "$D/kisi-sok.sh" --kullanici 'a b' >/dev/null 2>&1; ok "S10 geçersiz kullanıcı adı reddi" "$([ $? = 1 ] && echo 0 || echo 1)" ""
[ "$(id -u)" != 0 ] && { bash "$D/kisi-sok.sh" --kutu demo --uygula >/dev/null 2>&1; ok "S11 kök olmadan --uygula reddi (rc 2)" "$([ $? = 2 ] && echo 0 || echo 1)" ""; }
bash "$D/kisi-sok.sh" --kutu demo --kullanici daemon --uid 2001 >"$O/b" 2>&1; rc=$?
ok "S12 kullanıcı BAŞKA uid ile varsa DURUR (rc 3, kuru kipte bile)" "$([ "$rc" = 3 ] && grep -q 'başkasının hesabı silinmez' "$O/b" && echo 0 || echo 1)" "rc=$rc"
bash -c 'exec -a "ttyd -i /run/kisi/ayse-ttyd.sock -U ayse:abc" sleep 60' & DEKOY=$!; sleep 0.3
bash "$D/kisi-sok.sh" --kutu demo >"$O/s" 2>&1
ok "S13 süreç eşleme: kuru kip sahte ttyd-kisi sürecini 'kill' olarak LİSTELER" "$(grep -qE "^  \\$ kill .*\\b$DEKOY\\b" "$O/s" && echo 0 || echo 1)" "$(grep -A1 'ADIM 1' "$O/s")"
ok "S14 kuru kip süreci ÖLDÜRMEDİ" "$(kill -0 "$DEKOY" 2>/dev/null && echo 0 || echo 1)" ""
ok "S15 betik kendi kabuğunu 'kill' listesine katmıyor" "$(grep -E '^  \$ kill' "$O/s" | grep -qE "\\b$$\\b" && echo 1 || echo 0)" ""
# S16: komut satırında yalnız METİN olarak ad geçiren süreç eşleşmez (bash -c "…koltuk-koprusu.py…" tuzağı)
bash -c 'sleep 60; echo "koltuk-koprusu.py ttyd -i /run/kisi/ayse-ttyd.sock"' & TUZAK=$!; sleep 0.3   # son komut yerleşik: bash exec etmez, komut satırı metni korunur
ok "S16a tuzak sürecin komut satırı gerçekten metni taşıyor (fikstür geçerli)" "$(tr '\\0' ' ' < /proc/$TUZAK/cmdline | grep -q 'koltuk-koprusu.py ttyd -i' && echo 0 || echo 1)" "$(tr '\\0' ' ' < /proc/$TUZAK/cmdline)"
bash "$D/kisi-sok.sh" --kutu demo >"$O/t" 2>&1
ok "S16 adı yalnız metinde geçen süreç 'kill' listesine GİRMEZ" "$(grep -E '^  \$ kill' "$O/t" | grep -qE "\b$TUZAK\b" && echo 1 || echo 0)" "$(grep -A2 'ADIM 1' "$O/t")"
kill "$TUZAK" 2>/dev/null
# S17: kullanıcı beklenen uid ile VAR ve çalışan süreci var → DURUR (rc 3, silmez). PATH gölgeleri: getent/id/pgrep/userdel taklidi
SH="$O/golge"; mkdir -p "$SH"
printf '#!/bin/sh\n[ "$1" = passwd ] && { echo "ayse:x:2001:2001::/:/usr/sbin/nologin"; exit 0; }\nexec /usr/bin/getent "$@"\n' > "$SH/getent"
printf '#!/bin/sh\n[ "$1" = -u ] && [ "$2" = ayse ] && { echo 2001; exit 0; }\nexec /usr/bin/id "$@"\n' > "$SH/id"
printf '#!/bin/sh\n[ "$1" = -u ] && [ "$2" = ayse ] && exit 0\nexec /usr/bin/pgrep "$@"\n' > "$SH/pgrep"
printf '#!/bin/sh\necho userdel-CAGRILDI >> "%s/userdel.log"\n' "$O" > "$SH/userdel"
chmod +x "$SH"/*
PATH="$SH:$PATH" bash "$D/kisi-sok.sh" --kutu demo >"$O/c" 2>&1; rc=$?
ok "S17 çalışan süreci olan kullanıcı SİLİNMEZ (rc 3, userdel çağrılmadı)" "$([ "$rc" = 3 ] && grep -q 'çalışan süreci var' "$O/c" && [ ! -e "$O/userdel.log" ] && echo 0 || echo 1)" "rc=$rc $(tail -2 "$O/c")"
printf '#!/bin/sh\n[ "$1" = -u ] && [ "$2" = ayse ] && exit 1\nexec /usr/bin/pgrep "$@"\n' > "$SH/pgrep"
PATH="$SH:$PATH" bash "$D/kisi-sok.sh" --kutu demo >"$O/c2" 2>&1; rc=$?
ok "S17b süreci yoksa kuru kip 'userdel' adımını LİSTELER (çalıştırmaz)" "$([ "$rc" = 0 ] && grep -qE '^  \$ userdel ayse' "$O/c2" && [ ! -e "$O/userdel.log" ] && echo 0 || echo 1)" "rc=$rc $(tail -3 "$O/c2")"
# S18: uygulamada komut hatası YUTULMAZ — rm başarısızsa rc 4, "TAMAMLANAMADI", "bitti" yok, "zaten yok" yalanı yok
T2="$(mktemp -d)"; bash "$D/kisi-kur.sh" --kutu demo --kok "$T2" --uygula >/dev/null 2>&1; touch "$T2/run/kisi/koprusu.sock"
SH2="$O/golge2"; mkdir -p "$SH2"; printf '#!/bin/sh\nexit 1\n' > "$SH2/rm"; chmod +x "$SH2/rm"
PATH="$SH2:$PATH" bash "$D/kisi-sok.sh" --kutu demo --kok "$T2" --uygula >"$O/h" 2>&1; rc=$?
ok "S18 rm başarısız → rc 4, TAMAMLANAMADI, 'bitti' basılmaz" "$([ "$rc" = 4 ] && grep -q 'TAMAMLANAMADI' "$O/h" && ! grep -q 'kisi-sok: bitti' "$O/h" && echo 0 || echo 1)" "rc=$rc $(tail -3 "$O/h")"
ok "S18b başarısız rm 'zaten yok' diye gösterilmez" "$(grep 'koprusu.sock' "$O/h" | grep -q 'zaten yok' && echo 1 || echo 0)" "$(grep koprusu "$O/h")"
# S19: userdel başarısızsa groupdel DENENMEZ (yarım durum bırakılmaz)
SH3="$O/golge3"; mkdir -p "$SH3"
printf '#!/bin/sh\n[ "$1" = passwd ] && { echo "ayse:x:2001:2001::/:/usr/sbin/nologin"; exit 0; }\n[ "$1" = group ] && { echo "ayse:x:2001:"; exit 0; }\nexec /usr/bin/getent "$@"\n' > "$SH3/getent"
printf '#!/bin/sh\n[ "$1" = -u ] && [ -z "$2" ] && { echo 0; exit 0; }\n[ "$1" = -u ] && [ "$2" = ayse ] && { echo 2001; exit 0; }\nexec /usr/bin/id "$@"\n' > "$SH3/id"
printf '#!/bin/sh\n[ "$1" = -u ] && exit 1\nexec /usr/bin/pgrep "$@"\n' > "$SH3/pgrep"
printf '#!/bin/sh\nexit 1\n' > "$SH3/userdel"; printf '#!/bin/sh\necho groupdel-CAGRILDI >> "%s/groupdel.log"\n' "$O" > "$SH3/groupdel"
chmod +x "$SH3"/*
PATH="$SH3:$PATH" bash "$D/kisi-sok.sh" --kutu demo --uygula >"$O/g" 2>&1; rc=$?
ok "S19 userdel başarısız → rc 4 ve groupdel çağrılmadı" "$([ "$rc" = 4 ] && [ ! -e "$O/groupdel.log" ] && grep -q 'grup silinmedi' "$O/g" && echo 0 || echo 1)" "rc=$rc $(tail -3 "$O/g")"
echo; echo "$G geçti, $K kaldı"; [ "$K" = 0 ]
