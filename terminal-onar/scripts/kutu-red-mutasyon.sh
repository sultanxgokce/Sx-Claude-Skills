#!/usr/bin/env bash
# kutu-red.test.sh mutasyon turu — kopyada koşar; her mutant sınavı KIRMIZI yapmalı.
set -u
W="$1"; E="$(mktemp -d)"; gecti=0; dusen=0
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
dene() { # ad dosya eski yeni
  sil "$E/m"; mkdir -p "$E/m"; cp -r "$W/terminal-onar" "$E/m/"
  python3 - "$E/m/terminal-onar/scripts/$2" "$3" "$4" <<'PY' || { echo "  ✗ $1 — desen tutmadı"; dusen=$((dusen+1)); return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding="utf-8").read()
if s.count(a)!=1: sys.exit(1)
open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
  if bash "$E/m/terminal-onar/scripts/kutu-red.test.sh" >/dev/null 2>&1; then echo "  ✗ $1 — sınav YEŞİL kaldı"; dusen=$((dusen+1)); else echo "  ✓ $1 — sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
dene "M1 bekci.sh koruması kalktı" bekci.sh '. "$(dirname "$0")/ortak.sh" || exit 3' '. "$(dirname "$0")/ortak.sh"'
dene "M2 compact.sh koruması kalktı (FSZ30 geri gelir)" compact.sh '. "$D/ortak.sh" || exit 3' '. "$D/ortak.sh"'
dene "M3 rc 3 yerine rc 1" koltuk-ac.sh 'ortak.sh" || exit 3' 'ortak.sh" || exit 1'
dene "M4 ortak.sh makine kimliği reddi kalktı (pozitif: red ölçülüyor mu)" ortak.sh '  ????????????) echo' '  ????????????XX) echo'
# M5: korumasız YENİ bir çağıran eklenince kapsam kapısı (R10) yakalar
sil "$E/m"; mkdir -p "$E/m"; cp -r "$W/terminal-onar" "$E/m/"
printf '#!/usr/bin/env bash\nset -u\n. "$(dirname "$0")/ortak.sh"\necho "$DURUM_DIZ"\n' > "$E/m/terminal-onar/scripts/yeni-betik.sh"
if bash "$E/m/terminal-onar/scripts/kutu-red.test.sh" >/dev/null 2>&1; then echo "  ✗ M5 korumasız yeni çağıran — sınav YEŞİL"; dusen=$((dusen+1)); else echo "  ✓ M5 korumasız yeni çağıran — kapsam kapısı KIRMIZI"; gecti=$((gecti+1)); fi
sil "$E"; echo "MUTASYON: gecti=$gecti dusen=$dusen"; [ "$dusen" -eq 0 ]
