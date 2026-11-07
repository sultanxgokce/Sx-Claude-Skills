#!/usr/bin/env bash
# kos.sh [once|<mutant>] — denetci-on-goz.test.sh'i HEAD'in betik dizini kopyasıyla koşar (iş alanındaki kayıtsız dosya ölçüme girmesin).
#   once     : sınav HEAD'den, ürün betikleri ana daldan (origin/main) — özellik yokken sınav KIRMIZI olmalı.
#   <mutant> : sınavın kendi M bölümündeki çapalarla aynı tek değişiklik HEAD kopyasına uygulanır; MUTANT_D ile koşulur (hedef kapı düşmeli):
#              zorunlu-ortam-okunmaz (S9a) · gecis-karta-yazilmaz (S10f) · olculemedi-uyumlu (S11a) · erken-kapi-yok (S9e)
set -u; R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive HEAD yazilim-fabrikasi | tar -x -C "$T" || exit 3
S="$T/yazilim-fabrikasi/scripts"
case "${1:-}" in
  "") exec bash "$S/denetci-on-goz.test.sh" ;;
  once) cp "$S/denetci-on-goz.test.sh" "$T/sinav.sh"; find "$T/yazilim-fabrikasi" -depth -delete
        git -C "$R" archive origin/main yazilim-fabrikasi | tar -x -C "$T" || exit 3
        cp "$T/sinav.sh" "$S/denetci-on-goz.test.sh"; echo "önce: ürün betikleri origin/main ($(git -C "$R" rev-parse --short origin/main))"
        MUTANT_D="$S/denetci.sh" exec bash "$S/denetci-on-goz.test.sh" ;;   # M bölümü atlanır: çapalar eski üründe yok (gürültü olurdu)
esac
case "$1" in
  zorunlu-ortam-okunmaz) f=denetci.sh; a='then ONGOZ_ZORUNLU=ortam'; b='then ONGOZ_ZORUNLU=kapali' ;;
  gecis-karta-yazilmaz) f=kart.sh; a='k.setdefault("on_goz_gecisleri",[]).append(x)'; b='pass' ;;
  olculemedi-uyumlu) f=denetci.sh; a='*olculemedi*) ONGOZ_DURUM=olculemedi ;;'; b='*olculemedi*) ONGOZ_DURUM=uyumlu ;;' ;;
  erken-kapi-yok) f=denetci.sh; a='then _ongoz_kapat uyumsuz; fi'; b='then :; fi' ;;
  *) echo "bilinmeyen mutant: $1"; exit 3 ;;
esac
python3 - "$S/$f" "$a" "$b" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding="utf-8").read()
assert s.count(a)==1; open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
echo "mutant: $1 ($f)"; MUTANT_D="$S/denetci.sh" bash "$S/denetci-on-goz.test.sh"
