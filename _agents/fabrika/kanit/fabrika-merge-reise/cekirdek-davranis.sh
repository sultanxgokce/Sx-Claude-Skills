#!/usr/bin/env bash
# cekirdek-davranis.sh <dal|main|ikisi> — sınıflı kartta çekirdek kuralı (0.21.0) geçici depoda ölçer; beklenenden sapma varsa rc 1.
#   dal  = bu dalın kart.sh/izin.py'si · main = origin/main'deki eski araç · ikisi = ÖNCE (main) + SONRA (dal) yan yana, rc = dalın rc'si
#   MUTANT=bitti-veto-citi → dalın kopyasında bitti'deki veto çiti kaldırılır (mutasyon ölçümü: rc 1 = sınav yakaladı)
set -u
if [ "${1:-}" = ikisi ]; then
  echo "── ÖNCE (origin/main kart.sh) — sapma beklenir:"; bash "$0" main; echo "   (önce rc $?)"
  echo "── SONRA (bu dal):"; bash "$0" dal; exit $?
fi
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)" || exit 3
T="$(mktemp -d)"; trap 'find "$T" -delete' EXIT; D="$T/arac"; mkdir -p "$D"
case "${1:-}" in
  dal)  cp "$KOK"/yazilim-fabrikasi/scripts/*.py "$KOK"/yazilim-fabrikasi/scripts/*.sh "$D/" ;;
  main) git -C "$KOK" archive origin/main yazilim-fabrikasi/scripts | tar -x -C "$T" && cp "$T"/yazilim-fabrikasi/scripts/* "$D/" ;;
  *) echo "kullanım: $0 dal|main"; exit 3 ;;
esac
if [ "${MUTANT:-}" = bitti-veto-citi ]; then
  python3 - "$D/kart.sh" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding="utf-8").read(); a='if cmd=="bitti" and iz in ("dur","olculemedi"):'
assert s.count(a)==1, "çapa yok"; open(p,"w",encoding="utf-8").write(s.replace(a,"if False:"))
PY
  echo "MUTANT: bitti'deki veto çiti kaldırıldı"
fi
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/tetik.sh"; chmod +x "$T/tetik.sh"
mkdir -p "$T/depo" && git -C "$T/depo" init -q -b main
export KANIT_DEPO="$T/depo" FABRIKA_TETIK="$T/tetik.sh"; KT="$D/kart.sh"; KJ="$T/depo/_agents/fabrika/kartlar"; sapma=0
bak() { if [ "$2" = "$3" ]; then echo "✓ $1: $2"; else echo "✗ $1: $2 (beklenen $3)"; sapma=$((sapma+1)); fi; }
SNF="--istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e"
( cd "$T/depo" && bash "$KT" ac k-odasiz --is "odasız sınıflı iş" $SNF >/dev/null 2>&1 ); [ -f "$KJ/k-odasiz.json" ] && v=var || v=yok
bak "sınıflı kart --oda yokken" "kart $v" "kart yok"
( cd "$T/depo" && bash "$KT" ac k1 --is "sınıflı iş" $SNF --oda oda >/dev/null 2>&1 )
( cd "$T/depo" && bash "$KT" reis-dedi k1 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce" >/dev/null 2>&1 ); bak "sınıflı karta reis-dedi" "rc $?" "rc 0"
( cd "$T/depo" && bash "$KT" sultan-dedi k1 --karar dur --oturum o --soz "durun" --beyan MUAVIN >/dev/null 2>&1 )
( cd "$T/depo" && bash "$KT" reis-dedi k1 --karar devam --reis MUAVIN --oturum r --gerekce "yirmi karakterden uzun bir gerekce" >/dev/null 2>&1 ); bak "Sultan dur sonrası reis-dedi" "rc $?" "rc 1"
( cd "$T/depo" && bash "$KT" bitti k1 --pr 1 >/dev/null 2>&1 ); bak "Sultan dur sonrası bitti" "rc $?" "rc 1"
python3 -c "import json,sys;k=json.load(open(sys.argv[1]));print('birlestirme_karari', 'var' if k.get('birlestirme_karari') else 'yok', k.get('durum'))" "$KJ/k1.json"
echo "sapma: $sapma"
[ "$sapma" -eq 0 ]
