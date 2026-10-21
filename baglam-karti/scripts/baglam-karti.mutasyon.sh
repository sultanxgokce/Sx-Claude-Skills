#!/usr/bin/env bash
# baglam-karti.mutasyon.sh <depo kökü> — sekiz mutasyon (kapı denetimi yok · karar cümlesi adıma girer · ulaşılamayan defter rc 0 ·
# cevap HEDEF değeri denetlenmez · kuru koşum rc 0 döner · defter 200 gövdesi doğrulanmaz · adimlar tür denetimi yok · gerçek defterin NESNE biçimi eşleşmez);
# her biri sınavı KIRMIZI yapmalı. Bir mutasyon uygulanamaz ya da sınav yeşil kalırsa rc 1 (ayırt edicilik yok).
W="$1"; kacan=0
for m in 1 2 3 4 5 6 7 8; do
  S="$(mktemp -d)"; cp "$W"/baglam-karti/scripts/baglam-karti.sh "$W"/baglam-karti/scripts/baglam-karti.test.sh "$S"/
  case $m in
    1) sed -i 's/if kapi != "geçti": red/if False: red/' "$S/baglam-karti.sh" ;;
    2) sed -i 's/print("istek %s · %s · ufuk %s · son an %s" % (kimlik, kim, ufuk, son))/print("istek %s · %s · ufuk %s · son an %s · %s" % (kimlik, kim, ufuk, son, karar))/' "$S/baglam-karti.sh" ;;
    3) sed -i 's/kayıt YAZILMADI, kart dönmez" >\&2; exit 1; }/kayıt YAZILMADI, kart dönmez" >\&2; exit 0; }/' "$S/baglam-karti.sh" ;;
    4) sed -i 's/if (hedef or "").lower() != beklenen: red/if not hedef: red/' "$S/baglam-karti.sh" ;;
    5) sed -i 's/(deftere YAZILMADI · taşıma)"; exit 3; fi/(deftere YAZILMADI · taşıma)"; exit 0; fi/' "$S/baglam-karti.sh" ;;
    6) sed -i 's/kayıt doğrulanamadı (gövde bozuk ya da adım kayıtta yok) — kart dönmez", file=sys.stderr); sys.exit(1)/kayıt doğrulanamadı (gövde bozuk ya da adım kayıtta yok) — kart dönmez", file=sys.stderr)/; s/"adım yazıldı" if j\["degisti"\]/"adım yazıldı" if j.get("degisti")/' "$S/baglam-karti.sh" ;;
    7) python3 - "$S/baglam-karti.sh" <<'PY7'
import sys; p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a='yazili=[(x.get("deger") if isinstance(x,dict) else x) for x in k["adimlar"]] if isinstance(k,dict) and isinstance(k.get("adimlar"),list) else None'
b='yazili=(k.get("adimlar") or "") if isinstance(k,dict) else None   # tür denetimi yok: metin olsaydı alt-metin eşleşmesi'
if a in s: open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY7
      ;;
    8) sed -i 's/yazili=\[(x.get("deger") if isinstance(x,dict) else x) for x in k\["adimlar"\]\]/yazili=[x for x in k["adimlar"]]/' "$S/baglam-karti.sh" ;;
  esac
  if cmp -s "$W/baglam-karti/scripts/baglam-karti.sh" "$S/baglam-karti.sh"; then echo "M$m UYGULANMADI"; kacan=$((kacan+1))
  elif bash "$S/baglam-karti.test.sh" >/dev/null 2>&1; then echo "M$m KAÇTI"; kacan=$((kacan+1))
  else echo "M$m yakalandı"; fi
  rm -r -- "$S"
done
echo "mutasyon: $((8-kacan)) yakalandı · $kacan kaçtı"; [ $kacan -eq 0 ]
