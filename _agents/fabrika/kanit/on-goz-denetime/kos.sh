#!/usr/bin/env bash
# kos.sh [once|<mutant>] — denetci-on-goz.test.sh'i HEAD'in betik dizini kopyasıyla koşar (iş alanındaki kayıtsız dosya ölçüme girmesin).
#   once     : sınav HEAD'den, ürün betikleri ana daldan (origin/main) — özellik yokken sınav KIRMIZI olmalı.
#   <mutant> : sınavın kendi M bölümündeki çapalarla aynı tek değişiklik HEAD kopyasına uygulanır; MUTANT_D ile koşulur (hedef kapı düşmeli):
#              erken-kapi-yok (S9e) · zorunlu-ortam-okunmaz (S9a) · gec-kapisi-yok (S10a) · ana-dal-bayragi-yok (S9g) · gecis-karta-yazilmaz (S10f) · olculemedi-uyumlu (S11a) · dalgic-sayilmaz (B1) · sinav-disi-yok (D2) · dis-zorunlu-deler (D3) · esik-21 (S10k) · diste-dalgic-kosar (D2b) · karne-alansiz (S12f)
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
  erken-kapi-yok) f=denetci.sh; a='then _ongoz_kapat uyumsuz; fi'; b='then :; fi' ;;   # hedef S9e
  zorunlu-ortam-okunmaz) f=denetci.sh; a='then ONGOZ_ZORUNLU=ortam'; b='then ONGOZ_ZORUNLU=kapali' ;;   # hedef S9a
  gec-kapisi-yok) f=denetci.sh; a='[ "${_gn:-0}" -ge 20 ] ||'; b='true ||' ;;   # hedef S10a
  ana-dal-bayragi-yok) f=denetci.sh; a='elif git -C "$DEPO" cat-file -e'; b='elif false && git -C "$DEPO" cat-file -e' ;;   # hedef S9g
  gecis-karta-yazilmaz) f=kart.sh; a='k.setdefault("on_goz_gecisleri",[]).append(x)'; b='pass' ;;   # hedef S10f
  olculemedi-uyumlu) f=denetci.sh; a='*olculemedi*) ONGOZ_DURUM=olculemedi ;;'; b='*olculemedi*) ONGOZ_DURUM=uyumlu ;;' ;;   # hedef S11a
  dalgic-sayilmaz) f=denetci.sh; a='case "$ONGOZ_A/${DALGIC_DURUM:-}" in'; b='case "$ONGOZ_A/" in' ;;   # hedef B1
  sinav-disi-yok) f=denetci.sh; a='&& [ "${ON_GOZ_SINAV:-0}" != 1 ] &&'; b='&& false &&' ;;   # hedef D2
  dis-zorunlu-deler) f=denetci.sh; a='&& [ "$ONGOZ_ZORUNLU" = kapali ] && [ "$ONGOZ_GEC_VERILDI" != 1 ]; then'; b='; then' ;;   # hedef D3
  esik-21) f=denetci.sh; a='[ "${_gn:-0}" -ge 20 ] ||'; b='[ "${_gn:-0}" -ge 21 ] ||' ;;   # hedef S10k
  diste-dalgic-kosar) f=denetci.sh; a='DALGIC_DURUM="sinav-kapali"; ONGOZ_DURUM="sinav-kapali"'; b='_dalgic_kos; ONGOZ_DURUM="sinav-kapali"' ;;   # hedef D2b
  karne-alansiz) f=karne.sh; a='"on_goz":(d.get("on_goz") or {})'; b='"on_goz_yok":(d.get("on_goz") or {})' ;;   # hedef S12f
  *) echo "bilinmeyen mutant: $1"; exit 3 ;;
esac
python3 - "$S/$f" "$a" "$b" <<'PY' || { echo "mutant uygulanamadı"; exit 3; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding="utf-8").read()
assert s.count(a)==1; open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
echo "mutant: $1 ($f)"; MUTANT_D="$S/denetci.sh" bash "$S/denetci-on-goz.test.sh"
