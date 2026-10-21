#!/usr/bin/env bash
# gonderen-olcer.sh <betik-dizini> — denetçi zili aile-notify'a gönderen adını geçiriyor mu? (SERDAR 23:22: 'BILINMEYEN iş-bitti')
#   Sahte aile-notify ortamdaki AILE_KIMDEN'i ve çıkış koduyla rc 3'ü (kuyruk) taklit eder; denetçinin stderr'i de ölçülür.
set -uo pipefail
S="$(cd "$1" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
D="$T/depo"; mkdir -p "$D"; git -C "$D" init -q -b main; cd "$D"
printf '#!/usr/bin/env bash\nprintf "%%s · kimden=%%s\\n" "$1" "${AILE_KIMDEN:-YOK}" >> "%s/zil.log"; exit 3\n' "$T" > "$T/an.sh"; chmod +x "$T/an.sh"
export KANIT_DEPO="$D" FABRIKA_AILE_NOTIFY="$T/an.sh"
bash "$S/kart.sh" ac is-g --is x --istedi SERDAR --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$S/kanit.sh" olcum is-g olc --asama tek -- true >/dev/null 2>&1
printf '#!/usr/bin/env bash\nprintf "%%s" "{\\"kod_puani\\":5,\\"dogru_sey\\":\\"E\\",\\"ozet\\":\\"o\\",\\"bulgular\\":[],\\"kanit_gorusu\\":\\"k\\"}"\n' > "$T/goz.sh"; chmod +x "$T/goz.sh"
printf 'diff --git a/x b/x\n+g\n' > "$T/p"
DENETCI_KOMUT="$T/goz.sh" bash "$S/denetci.sh" is-g --diff "$T/p" >/dev/null 2>"$T/err"
echo "── zil: $(cat "$T/zil.log")"
echo "── denetçinin zil hakkındaki sözü: $(grep -E 'zil' "$T/err" | head -1)"
ad=0; grep -q "kimden=MUAVIN" "$T/zil.log" && ad=1
dil=0; grep -q "kuyrukta" "$T/err" && ! grep -q "gönderilemedi" "$T/err" && dil=1
echo "── SONUÇ: gönderen adı $([ $ad = 1 ] && echo '✓ (MUAVIN)' || echo '✗ (yok → BILINMEYEN)') · rc 3 dili $([ $dil = 1 ] && echo '✓ kuyrukta' || echo '✗ gönderilemedi diyor')"
[ $ad = 1 ] && [ $dil = 1 ] && exit 0
exit 1
