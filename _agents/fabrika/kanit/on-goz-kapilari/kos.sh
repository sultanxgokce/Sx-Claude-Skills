#!/usr/bin/env bash
# kos.sh [istisna|once|gecersiz|upstream|altdize] — on-goz.test.sh'i HEAD'in on-goz.py kopyasıyla (ya da mutantıyla) koşar.
#   istisna: yalnız-kanıt farkı istisnası kalkar (S3 düşmeli) · once: 'once' muafiyeti kalkar (S3b) · gecersiz: geçersiz ilan süzgeci kalkar (S6) · upstream: origin yerine izlenen uzak (S4r) · altdize: yol bileşeni yerine alt dize (S10c)
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi/scripts | tar -x -C "$T" || exit 3   # on-goz.py kanit.py/kanit.sh'ı kendi dizininden alır: dizinin tamamı
S="$T/yazilim-fabrikasi/scripts"
if [ -n "${1:-}" ]; then python3 - "$S/on-goz.py" "$1" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,m=sys.argv[1:]; s=open(p,encoding='utf-8').read()
a,b={"istisna":('kod = [f for f in fark.splitlines() if f and not KANIT_DESEN.match(f)]','kod = [f for f in fark.splitlines() if f]'),
     "once":('if not oc or k.get("asama") == "once":','if not oc:'),
     "gecersiz":('if k.get("etkin_renk") not in ("gecersiz", "ilan")]','if True]'),
     "upstream":('up = git(depo, "rev-parse", "--verify", "-q", f"refs/remotes/origin/{dal}") if dal else None','up = git(depo, "rev-parse", "--verify", "-q", "@{u}")'),
     "altdize":('for y in yasak if yol_eslesir(f, y)})','for y in yasak if y in f})')}[m]
assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
echo "mutant: $1"; fi
bash "$S/on-goz.test.sh" 2>&1; exit $?
