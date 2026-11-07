#!/usr/bin/env bash
# kos.sh <kip> — denetci-on-goz.test.sh'ı becerinin tam arşiv kopyasında koşar (kart on-goz-bos-fark).
#   once: HEAD becerisi + origin/main denetci.sh (yeni sınav eski koda karşı) · sonra: HEAD · mut-<ad>: HEAD denetci.sh'in geçici bozulmuş hâli
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; kip="${1:?kip}"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$K" archive HEAD yazilim-fabrikasi | tar -x -C "$T"; S="$T/yazilim-fabrikasi/scripts"
case "$kip" in
  once) git -C "$K" show origin/main:yazilim-fabrikasi/scripts/denetci.sh > "$S/denetci.sh" ;;
  sonra) ;;
  mut-*) python3 - "$S/denetci.sh" "${kip#mut-}" <<'PY'
import sys
p, ad = sys.argv[1:]; s = open(p, encoding="utf-8").read()
M = {
  "uygulanamaz-yok": ('''      if [ -n "$_bos_dosyalar" ] && ! grep -qv '^_agents/fabrika/kanit/' <<<"$_bos_dosyalar"; then''', '''      if false; then'''),
  "liste-bakilmaz": ('''      if [ -n "$_bos_dosyalar" ] && ! grep -qv '^_agents/fabrika/kanit/' <<<"$_bos_dosyalar"; then''', '''      if [ ! -s "$DALGIC_DIFF" ]; then'''),
  "dalgica-gider": ('''        return 0
      fi
      DALGIC_NOTES=''', '''      fi
      DALGIC_NOTES='''),
}
a, b = M[ad]; assert s.count(a) == 1, (ad, s.count(a)); open(p, "w", encoding="utf-8").write(s.replace(a, b))
PY
  ;;
  *) echo "bilinmeyen kip: $kip" >&2; exit 2 ;;
esac
bash "$S/denetci-on-goz.test.sh"
