#!/usr/bin/env bash
# gercek-zil-olcer.sh <betik-dizini> — GERÇEK aile-notify ile: denetçiyi koşturan koltuğa (kendi penceresi) giden zil düşüyor mu?
#   kontrol: aile-notify'ı çağıranın TMUX kimliğiyle doğrudan çağır (eski yol) → self-loop'ta atlanır mı
#   asıl:    denetci.sh'ın kendi zili (sahte denetçi, gerçek zil aracı) → atla(self) yok, sinyal deftere düştü mü
# Hedef = ölçeni koşturan koltuk (AGENT_NAME), yani kimse rahatsız edilmez. HEZARFEN 20:38 bulgusunun ölçümü.
set -uo pipefail
S="$(cd "$1" && pwd)"; AN=/config/projects/Nexus/scripts/aile-notify.sh; KIM="${AGENT_NAME:?AGENT_NAME gerekli}"
[ -n "${TMUX:-}" ] || { echo "ÖLÇÜLEMEDİ: bu ölçüm bir tmux penceresinden koşmalı (self-loop yalnız orada oluşur)"; exit 4; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
printf '#!/usr/bin/env bash\nprintf "tmux=%%s\\n" "${TMUX:-yok}" >> "%s/an.log"; bash "%s" "$@" >> "%s/an.log" 2>&1\n' "$T" "$AN" "$T" > "$T/an.sh"; chmod +x "$T/an.sh"
echo "── kontrol · eski yol (TMUX kimliğiyle doğrudan çağrı)"
bash "$AN" --done --amir "$KIM" "ölçüm (kontrol): gercek-zil-olcer eski yol" > "$T/k.log" 2>&1
grep -q "atla(self)" "$T/k.log" && echo "  atla(self): VAR — zil kendi koltuğuna düşmedi" || echo "  atla(self): YOK"
D="$T/depo"; mkdir -p "$D"; git -C "$D" init -q -b main; cd "$D"
export KANIT_DEPO="$D" FABRIKA_AILE_NOTIFY="$T/an.sh"
bash "$S/kart.sh" ac is-g --is x --istedi "$KIM" --aldi "$KIM" --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$S/kanit.sh" olcum is-g olc --asama tek -- true >/dev/null 2>&1
printf '#!/usr/bin/env bash\nprintf "%%s" "{\\"kod_puani\\":5,\\"dogru_sey\\":\\"E\\",\\"ozet\\":\\"o\\",\\"bulgular\\":[],\\"kanit_gorusu\\":\\"k\\"}"\n' > "$T/hizli.sh"; chmod +x "$T/hizli.sh"
printf 'diff --git a/x b/x\n+s\n' > "$T/d.patch"
echo "── asıl · denetci.sh'ın kendi zili (gerçek aile-notify)"
DENETCI_KOMUT="$T/hizli.sh" bash "$S/denetci.sh" is-g --diff "$T/d.patch" >/dev/null 2>&1; echo "  denetçi rc $?"
sed 's/^/  | /' "$T/an.log"
y=0; grep -qx "tmux=yok" "$T/an.log" && ! grep -q "atla(self)" "$T/an.log" && grep -q "sinyal:.*deftere yazıldı" "$T/an.log" && y=1
echo "── SONUÇ: kendi koltuğuna giden zil $([ $y = 1 ] && echo 'DÜŞTÜ ✓ (defterde; meşgulse kuyrukta)' || echo 'DÜŞMEDİ ✗')"
[ $y = 1 ] && exit 0
exit 1
