#!/usr/bin/env bash
# kos.sh [rev] [mutant] — rev'i (varsayılan HEAD) BÜTÜN depoyla geçici dizine çıkarır; isteğe bağlı mutant; kapının sınavını koşar.
#   mutant 'yok'    : iptal_sus girdiyi olduğu gibi döndürür (düzeltme yok) → T20o düşmeli
#   mutant 'gevsek' : bütün CANCELLED kayıtları düşürülür (tek başına iptal de) → T20p düşmeli
#   SINAV_KAYNAK verilirse sınav dosyası onunla değiştirilir (önce: eski kapı + yeni sınav).
set -u; REV="${1:-HEAD}"; M="${2:-}"; R="$(git rev-parse --show-toplevel)"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive "$REV" | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"; [ -n "${SINAV_KAYNAK:-}" ] && cp "$SINAV_KAYNAK" "$S/birlestirme-kapisi.test.sh"
deg(){ python3 - "$S/birlestirme-kapisi.sh" "$1" "$2" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding="utf-8").read(); assert s.count(a)==1, s.count(a); open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
}
case "$M" in
  yok)    deg 'return [(ad, tamam, son) for ad, tamam, son in ogeler if not (tamam and (son or "").upper() == "CANCELLED" and ad in iptalsiz)]' 'return list(ogeler)' ;;
  gevsek) deg 'and ad in iptalsiz)]' ')]' ;;
  '') ;; *) echo "bilinmeyen mutant"; exit 2 ;;
esac
[ -n "$M" ] && { bash -n "$S/birlestirme-kapisi.sh" || exit 3; echo "mutant: $M"; }
echo "rev: $(git -C "$R" rev-parse --short "$REV")"
bash "$S/birlestirme-kapisi.test.sh" 2>&1 | grep -E 'T20[o-r]|✗|SONUÇ'; exit "${PIPESTATUS[0]}"
