#!/usr/bin/env bash
# koltuk-kimlik.test.sh — AD DIŞI KİMLİK (2.24.0 · P4GT2W): kabuk (koltuk-adi.sh koltuk_kimlik) ile kapı (kapi/koltuk-kimlik.mjs)
# AYNI adı AYNI kimliğe çevirir mi; tuz kutuya özel, gizli (0600), yarışta tek mi. HERMETİK: tuz geçici dizinde, gerçek $HOME'a dokunmaz.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
ok()  { GECEN=$((GECEN+1)); echo "  ✓ $1"; }
bad() { DUSEN=$((DUSEN+1)); echo "  ✗ $1 — $2"; }
S="$(mktemp -d)"; trap 'rm -r -f -- "$S" 2>/dev/null' EXIT
MJS="$(cd ../kapi && pwd)/koltuk-kimlik.mjs"
kb() { ( . ./koltuk-adi.sh; koltuk_kimlik "$1" ); }
kn() { node -e 'import(process.argv[1]).then(m=>{const k=m.koltukKimlik(process.argv[2]);process.stdout.write(k===null?"NULL":k)})' "$MJS" "$1"; }

echo "E · iki dil eşdeğer"
export KOLTUK_TUZ="$S/t1/tuz"; mkdir -p "$S/t1"
ilk=$(kn BASIRET)
[ -s "$KOLTUK_TUZ" ] && [ "$(stat -c %a "$KOLTUK_TUZ")" = 600 ] && [[ "$(cat "$KOLTUK_TUZ")" =~ ^[0-9a-f]{32}$ ]] && ok "E0 tuz yoksa kapı yaratır: 32 onaltılık, kip 600" || bad E0 "kip=$(stat -c %a "$KOLTUK_TUZ" 2>&1)"
for ad in BASIRET '2026/85' 'Ayşe Yılmaz' 'a b' 'ş😀x' '-x' 'k0123456789abcdef' "$(printf 'x%.0s' {1..200})"; do
  b=$(kb "$ad"); n=$(kn "$ad")
  [ "$b" = "$n" ] && [[ "$b" =~ ^k[0-9a-f]{16}$ ]] && ok "E1 aynı kimlik: '${ad:0:14}'" || bad "E1 ${ad:0:14}" "kabuk=$b kapı=$n"
done
[ "$(kn BASIRET)" = "$ilk" ] && ok "E2 kararlı: aynı tuz + aynı ad → aynı kimlik" || bad E2 "değişti"
[ "$(kb 'Ayşe Yılmaz')" != "$(kb 'Ayse Yilmaz')" ] && ok "E3 harf farkı ayrı kimlik verir" || bad E3 "çakıştı"

echo "T · tuz kutuya özel ve gizli"
export KOLTUK_TUZ="$S/t2/tuz"; mkdir -p "$S/t2"
[ "$(kb BASIRET)" != "$ilk" ] && ok "T1 başka tuz → başka kimlik (ad listesiyle tahmin edilemez)" || bad T1 "aynı"
[ "$(stat -c %a "$KOLTUK_TUZ")" = 600 ] && ok "T2 kabuk da tuzu 600 kipte yaratır" || bad T2 "kip=$(stat -c %a "$KOLTUK_TUZ")"
for i in 1 2 3 4 5; do
  export KOLTUK_TUZ="$S/y$i/tuz"; mkdir -p "$S/y$i"
  kb Q > "$S/y$i/a" & kn Q > "$S/y$i/b" & kb Q > "$S/y$i/c" & wait
  [ "$(cat "$S/y$i/a")" = "$(cat "$S/y$i/b")" ] && [ "$(cat "$S/y$i/a")" = "$(cat "$S/y$i/c")" ] && ok "T3 yarış $i: aynı anda üç yaratıcı tek tuz okur" || bad "T3 $i" "a=$(cat "$S/y$i/a") b=$(cat "$S/y$i/b") c=$(cat "$S/y$i/c")"
  [ "$(ls "$S/y$i" | grep -c '^tuz\.')" = 0 ] && ok "T4 yarış $i: geçici tuz dosyası kalmaz" || bad "T4 $i" "$(ls "$S/y$i")"
done
export KOLTUK_TUZ="$S/yok/dizin/tuz"
[ "$(kn BASIRET)" = NULL ] && ok "T5 kapı: tuz yaratılamazsa kimlik NULL (uydurulmaz)" || bad T5 "$(kn BASIRET)"
kb BASIRET >/dev/null 2>&1; [ $? = 1 ] && ok "T6 kabuk: tuz yaratılamazsa rc 1" || bad T6 "rc≠1"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
