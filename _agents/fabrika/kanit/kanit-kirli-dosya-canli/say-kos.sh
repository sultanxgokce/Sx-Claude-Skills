#!/usr/bin/env bash
# say-kos.sh [mutant] — HEAD'i BÜTÜN depoyla geçici dizine çıkarır; isteğe bağlı mutant; kanit-kirli-say.test.sh'ı koşar.
#   mutant 'damga' : sayım kapı damgasını (kirli_kurali) süzgeç yapar → K1 dosya/canli satırları düşmeli
#   mutant 'tur'   : yalnız olcum/ekran sayılır (ilk kapanışın hatası) → K1 dosya/canli satırları düşmeli
set -u; M="${1:-}"; R="$(git rev-parse --show-toplevel)"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"
deg(){ python3 - "$S/kanit-kirli-say.py" "$1" "$2" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding="utf-8").read(); assert s.count(a)==1, s.count(a); open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
}
case "$M" in
  damga) deg 'if k.get("olculen_kirli") is True:' 'if k.get("olculen_kirli") is True and k.get("kirli_kurali"):' ;;
  tur) deg 'TURLER = ("olcum", "ekran", "dosya", "canli")' 'TURLER = ("olcum", "ekran")' ;;
  '') ;; *) echo "bilinmeyen mutant"; exit 2 ;;
esac
[ -n "$M" ] && { python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$S/kanit-kirli-say.py" || exit 3; echo "mutant: $M"; }
echo "rev: $(git -C "$R" rev-parse --short HEAD)"
bash "$S/kanit-kirli-say.test.sh" 2>&1; exit $?
