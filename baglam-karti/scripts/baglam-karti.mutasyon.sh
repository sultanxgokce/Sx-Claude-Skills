#!/usr/bin/env bash
# baglam-karti.mutasyon.sh <depo kökü> — üç mutasyon (kapı denetimi yok · karar cümlesi adıma girer · ulaşılamayan defter rc 0);
# her biri sınavı KIRMIZI yapmalı. Bir mutasyon uygulanamaz ya da sınav yeşil kalırsa rc 1 (ayırt edicilik yok).
W="$1"; kacan=0
for m in 1 2 3; do
  S="$(mktemp -d)"; cp "$W"/baglam-karti/scripts/baglam-karti.sh "$W"/baglam-karti/scripts/baglam-karti.test.sh "$S"/
  case $m in
    1) sed -i 's/if kapi != "geçti": red/if False: red/' "$S/baglam-karti.sh" ;;
    2) sed -i 's/print("istek %s · %s · ufuk %s · son an %s" % (kimlik, kim, ufuk, son))/print("istek %s · %s · ufuk %s · son an %s · %s" % (kimlik, kim, ufuk, son, karar))/' "$S/baglam-karti.sh" ;;
    3) sed -i 's/kayıt YAZILMADI, kart dönmez" >\&2; exit 1; }/kayıt YAZILMADI, kart dönmez" >\&2; exit 0; }/' "$S/baglam-karti.sh" ;;
  esac
  if cmp -s "$W/baglam-karti/scripts/baglam-karti.sh" "$S/baglam-karti.sh"; then echo "M$m UYGULANMADI"; kacan=$((kacan+1))
  elif bash "$S/baglam-karti.test.sh" >/dev/null 2>&1; then echo "M$m KAÇTI"; kacan=$((kacan+1))
  else echo "M$m yakalandı"; fi
  rm -r -- "$S"
done
echo "mutasyon: $((3-kacan)) yakalandı · $kacan kaçtı"; [ $kacan -eq 0 ]
