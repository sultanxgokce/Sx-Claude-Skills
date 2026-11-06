#!/usr/bin/env bash
# kos.sh [istisna|once|gecersiz] — on-goz.test.sh'i HEAD'in on-goz.py kopyasıyla (ya da mutantıyla) koşar.
#   istisna: yalnız-kanıt farkı istisnası kalkar (S3 düşmeli) · once: 'once' muafiyeti kalkar (S3b) · gecersiz: geçersiz ilan süzgeci kalkar (S6)
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" show HEAD:yazilim-fabrikasi/scripts/on-goz.py > "$T/on-goz.py" || exit 3
cp "$R/yazilim-fabrikasi/scripts/kanit.py" "$T/" 2>/dev/null   # on-goz.py etkin_kayitlar'ı yanındaki kanit.py'den alır
if [ -n "${1:-}" ]; then python3 - "$T/on-goz.py" "$1" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,m=sys.argv[1:]; s=open(p,encoding='utf-8').read()
a,b={"istisna":('kod = [f for f in fark.splitlines() if f and not KANIT_DESEN.match(f)]','kod = [f for f in fark.splitlines() if f]'),
     "once":('if not oc or k.get("asama") == "once":','if not oc:'),
     "gecersiz":('if k.get("etkin_renk") not in ("gecersiz", "ilan")]','if True]')}[m]
assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
echo "mutant: $1"; fi
ON_GOZ="$T/on-goz.py" bash "$R/yazilim-fabrikasi/scripts/on-goz.test.sh" 2>&1; exit $?
