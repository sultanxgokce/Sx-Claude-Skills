#!/usr/bin/env bash
# istek.test.sh — wa-gonder.sh --istek: Sultan'a giden istek günlük bütçeden düşer, doluysa gitmez. Ağa ÇIKMAZ (geçit adresi ulaşılmaz).
set -uo pipefail
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wa-gonder.sh"; GEC=0; KAL=0
ok(){ if [ "$2" = "$3" ]; then GEC=$((GEC+1)); echo "  ✓ $1"; else KAL=$((KAL+1)); echo "  ✗ $1 (beklenen=$3 gelen=$2)"; fi; }
T="$(mktemp -d)"; trap 'python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"' EXIT
printf '#!/usr/bin/env bash\necho "$*" >> "%s/butce.log"; exit "${FAKE_RC:-0}"\n' "$T" > "$T/butce"; chmod +x "$T/butce"
export WA_GECIT="http://127.0.0.1:9" WA_JETON=x WA_BUTCE_SH="$T/butce" WA_SAHIP=SINAMA
g(){ bash "$W" "$@" >"$T/out" 2>&1; echo $?; }
echo "I1 bütçe varsa mesaj gönderime geçer (geçit ulaşılmaz → rc 3 = gönderim denendi)"
ok "istek geçti, gönderim denendi" "$(FAKE_RC=0 g --istek "kasa sorusu" "Onay verir misin?")" 3
ok "bütçe 'wa' türüyle ve istek adıyla çağrıldı" "$(grep -c 'harca --tur wa --ad kasa sorusu --sahip SINAMA' "$T/butce.log")" 1
echo "I2 bütçe doluysa mesaj GİTMEZ"
ok "rc 0, gönderim denenmedi" "$(FAKE_RC=10 g --istek "ikinci soru" "x")" 0
ok "kuyruk bilgisi basıldı" "$(grep -c 'GİTMEDİ' "$T/out")" 1
echo "I3 --istek taşımayan mesaj bütçeye girmez"
: > "$T/butce.log"; ok "bilgi mesajı gönderime geçer" "$(FAKE_RC=10 g "bilgi satırı")" 3
ok "bütçe çağrılmadı" "$(grep -c . "$T/butce.log")" 0
echo "I4 Sultan dışı alıcıya bütçe uygulanmaz"
ok "başka alıcı gönderime geçer" "$(FAKE_RC=10 g --kime Ayse --istek "x" "mesaj")" 3
ok "bütçe çağrılmadı" "$(grep -c . "$T/butce.log")" 0
echo "I5 bütçe betiği yoksa uyarıyla gider"
ok "betik yok: gönderim denendi" "$(WA_BUTCE_SH=/yok g --istek "x" "mesaj")" 3
ok "uyarı basıldı" "$(grep -c 'bütçe betiği yok' "$T/out")" 1
echo "geçti=$GEC kaldı=$KAL"; [ "$KAL" -eq 0 ]
