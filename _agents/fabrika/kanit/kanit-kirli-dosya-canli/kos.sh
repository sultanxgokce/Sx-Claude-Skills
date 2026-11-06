#!/usr/bin/env bash
# kos.sh [rev] [mutant] — rev'i (varsayılan HEAD) BÜTÜN depoyla geçici dizine çıkarır; isteğe bağlı mutant; kanit-olculen-commit.test.sh'ı koşar.
#   mutant 'dosya' : cmd_dosya'daki kirli_kapisi çağrısı silinir → K9 düşmeli
#   mutant 'canli' : cmd_canli'daki kirli_kapisi çağrısı silinir → K10 düşmeli
#   SINAV_KAYNAK verilirse sınav dosyası onunla değiştirilir (önce: eski kanit.py + yeni sınav).
set -u; REV="${1:-HEAD}"; M="${2:-}"; R="$(git rev-parse --show-toplevel)"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive "$REV" | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"; [ -n "${SINAV_KAYNAK:-}" ] && cp "$SINAV_KAYNAK" "$S/kanit-olculen-commit.test.sh"
deg(){ python3 - "$S/kanit.py" "$1" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,a=sys.argv[1:]; s=open(p,encoding="utf-8").read(); assert s.count(a)==1, s.count(a); open(p,"w",encoding="utf-8").write(s.replace(a,"pass"))
PY
}
case "$M" in
  dosya) deg 'kirli_kapisi(a, dz)   # 0.9.0: dosya kaydı da kirli ağaçta DURUR (--kirli-izin ile gerekçeli geçer)' ;;
  canli) deg 'kirli_kapisi(a, dz)   # 0.9.0: canlı kaydı da kirli ağaçta DURUR (--kirli-izin ile gerekçeli geçer)' ;;
  '') ;; *) echo "bilinmeyen mutant"; exit 2 ;;
esac
[ -n "$M" ] && { python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$S/kanit.py" || exit 3; echo "mutant: $M"; }
echo "rev: $(git -C "$R" rev-parse --short "$REV")"
bash "$S/kanit-olculen-commit.test.sh" 2>&1 | grep -E 'K9|K1[01]|✗|SONUÇ'; exit "${PIPESTATUS[0]}"
