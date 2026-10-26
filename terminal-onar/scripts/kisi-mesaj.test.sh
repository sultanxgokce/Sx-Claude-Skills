#!/usr/bin/env bash
# kisi-mesaj.sh sınavı — sahte ulak komutuyla (argümanları kaydeder).
set -u; D="$(cd "$(dirname "$0")" && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0; ok() { if [ "$2" = 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → $3"; fi; }
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/arg"\necho ulak_SAHTE-1\n' "$T" > "$T/ulak"; chmod +x "$T/ulak"
export ULAK_BIN="$T/ulak" KISI_HEDEFLER="$T/hedef" KISI_AD="Ayşenur"
out="$(printf 'Merhaba ajan' | bash "$D/kisi-mesaj.sh" medigate-ana aysenur 2>&1)"; rc=$?
ok "S1 rc 0 ve kimlik basıldı" "$([ $rc = 0 ] && [ "$out" = ulak_SAHTE-1 ] && echo 0 || echo 1)" "$rc $out"
a="$(cat "$T/arg")"
ok "S2 alıcı koltuktan türedi (MEDIGATE)" "$(echo "$a" | sed -n 2p | grep -qx MEDIGATE && echo 0 || echo 1)" "$a"
ok "S3 gövde 'insan, Sultan DEĞİL' etiketli" "$(echo "$a" | grep -q 'Sultan DEĞİL' && echo 0 || echo 1)" "$a"
ok "S4 kimden = AYSENUR ve bağ = kisi:aysenur" "$(echo "$a" | grep -qx AYSENUR && echo "$a" | grep -qx 'kisi:aysenur' && echo 0 || echo 1)" "$a"
printf 'medigate-ana=BERID\n' > "$T/hedef"; printf 'x' | bash "$D/kisi-mesaj.sh" medigate-ana aysenur >/dev/null 2>&1
ok "S5 hedef tablosu önceliklidir" "$(sed -n 2p "$T/arg" | grep -qx BERID && echo 0 || echo 1)" "$(cat "$T/arg")"
printf '  \n' | bash "$D/kisi-mesaj.sh" medigate-ana aysenur >/dev/null 2>&1; ok "S6 boş mesaj rc≠0" "$([ $? != 0 ] && echo 0 || echo 1)" ""
printf 'x' | bash "$D/kisi-mesaj.sh" medigate-ana 'a b' >/dev/null 2>&1; ok "S7 geçersiz kişi kimliği rc≠0" "$([ $? != 0 ] && echo 0 || echo 1)" ""
printf 'x' | bash "$D/kisi-mesaj.sh" '../x' aysenur >/dev/null 2>&1; ok "S8 yol ayraçlı koltuk (alıcı) rc≠0" "$([ $? != 0 ] && echo 0 || echo 1)" ""
printf 'x' | ULAK_BIN=/yok bash "$D/kisi-mesaj.sh" medigate-ana aysenur >/dev/null 2>&1; ok "S9 ulak yoksa rc 3 (sessiz geçmez)" "$([ $? = 3 ] && echo 0 || echo 1)" ""
echo; echo "$G geçti, $K kaldı"; [ "$K" = 0 ]
