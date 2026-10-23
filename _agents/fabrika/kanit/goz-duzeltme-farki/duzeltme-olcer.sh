#!/usr/bin/env bash
# duzeltme-olcer.sh <kod kaynağı: git ref | "agac"> — SYV3F: düzeltme turunda göze ne gidiyor, şişkin istem gönderiliyor mu?
#   Verilen kaynaktaki yazilim-fabrikasi/scripts geçici dizine alınır; geçici çıplak origin + klonda bir iş iki tur denetlenir
#   (tur 1: 4/E bir bulgu; arada tek satırlık düzeltme commit'i), sahte denetçi istemi diske bırakır. Ölçülen:
#   (1) tur 2 istemindeki FARK bölümünün baytı · değişmeyen dosya istemde mi · önceki bulgu ayrı satırda mı;
#   (2) ~110 KB'lık istem (100-120 KB arası) eşik dikişi olmadan sahte denetçiye GÖNDERİLİYOR mu.
#   Çıkış 0 = tur 2 yalnız yeni farkı görüyor VE 110 KB istem gönderilmiyor · 1 = değil.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s"
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"; mkdir -p "$T/adimlar"; cp -a "$R/yazilim-fabrikasi/adimlar/." "$T/adimlar/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts yazilim-fabrikasi/adimlar | tar -x -C "$T" --strip-components=1; mv "$T/scripts/"* "$T/s/"; fi
export FABRIKA_AILE_NOTIFY=-
git init -q --bare -b main "$T/o.git"; git clone -q "$T/o.git" "$T/w" 2>/dev/null
git -C "$T/w" config user.email t@t; git -C "$T/w" config user.name t
echo taban > "$T/w/a.txt"; git -C "$T/w" add a.txt; git -C "$T/w" commit -q -m taban; git -C "$T/w" push -q origin main 2>/dev/null
git -C "$T/w" remote set-head origin main >/dev/null 2>&1
printf 'İŞ: ölçüm\nSINIF: yok\n' > "$T/kart.md"
printf '#!/usr/bin/env bash\ncp "$1" "$SAHTE_ISTEM_KOPYA"; printf %%s "$SAHTE_JSON"\n' > "$T/sahte.sh"; chmod +x "$T/sahte.sh"
export DENETCI_KOMUT="$T/sahte.sh"
J4='{"kod_puani":4,"dogru_sey":"E","ozet":"o","bulgular":[{"ne":"sinir-kontrolu-eksik","kanit":"k","konum":"kod.txt:1","agirlik":"uygulama"}],"kanit_gorusu":"k"}'
J5='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
den() { ( cd "$T/w" && SAHTE_ISTEM_KOPYA="$3" SAHTE_JSON="$2" KANIT_DEPO="$T/w" bash "$T/s/denetci.sh" "$1" --kart "$T/kart.md" < /dev/null 2>&1 ); }
# (1) iki tur: büyük değişmeyen dosya (8 KB) + küçük kod dosyası; tur arası tek satır düzeltme
git -C "$T/w" checkout -q -b olc origin/main 2>/dev/null
python3 -c "open('$T/w/degismeyen.txt','w').write(''.join('degismeyen-%04d\n'%i for i in range(500)))"; printf 'ilk\n' > "$T/w/kod.txt"
git -C "$T/w" add degismeyen.txt kod.txt; git -C "$T/w" commit -q -m ilk
(cd "$T/w" && KANIT_DEPO="$T/w" bash "$T/s/kanit.sh" olcum olc o --asama tek -- true >/dev/null 2>&1)
den olc "$J4" "$T/i1.md" >/dev/null
printf 'ilk\nduzeltme\n' > "$T/w/kod.txt"; git -C "$T/w" commit -q -am duz
O2="$(den olc "$J5" "$T/i2.md")"
fark_bayt() { python3 -c "import sys;s=open(sys.argv[1],encoding='utf-8').read();a=s.find('===== DEĞİŞİKLİK (diff) =====');b=s.find('\n\n=====',a+10);print(len((s[a:b] if b>0 else s[a:]).encode()) if a>=0 else -1)" "$1"; }
F1="$(fark_bayt "$T/i1.md")"; F2="$(fark_bayt "$T/i2.md")"
grep -q "degismeyen-0499" "$T/i2.md" && DEG=evet || DEG=hayır
grep -qF "B1. [uygulama] sinir-kontrolu-eksik" "$T/i2.md" && BUL=evet || BUL=hayır
echo "kod kaynağı: $1"
echo "(1) tur 1 fark bölümü: $F1 bayt · tur 2 fark bölümü: $F2 bayt · tur 2'de değişmeyen dosya: $DEG · önceki bulgu ayrı satırda: $BUL"
printf '%s\n' "$O2" | grep -E "DÜZELTME TURU|düzeltme farkı" | sed 's/^/   /'
# (2) ~110 KB istem, eşik dikişi yok
git -C "$T/w" checkout -q -b buyuk origin/main 2>/dev/null
python3 -c "open('$T/w/buyuk.txt','w').write(''.join('satir-%05d-%s\n'%(i,'b'*80) for i in range(1100)))"
git -C "$T/w" add buyuk.txt; git -C "$T/w" commit -q -m buyuk
(cd "$T/w" && KANIT_DEPO="$T/w" bash "$T/s/kanit.sh" olcum buyuk o --asama tek -- true >/dev/null 2>&1)
: > "$T/i3.md"; O3="$(env -u DENETCI_KIRP_ESIK -u DENETCI_ISTEM_TAVAN bash -c "cd '$T/w' && SAHTE_ISTEM_KOPYA='$T/i3.md' SAHTE_JSON='$J5' KANIT_DEPO='$T/w' bash '$T/s/denetci.sh' buyuk --kart '$T/kart.md' < /dev/null 2>&1")"; RC3=$?
[ -s "$T/i3.md" ] && GIT="gönderildi ($(wc -c < "$T/i3.md") bayt)" || GIT="gönderilmedi"
echo "(2) ~110 KB istem → rc=$RC3 · denetçiye: $GIT"
printf '%s\n' "$O3" | grep -E "İŞİ BÖL" | sed 's/^/   /'
[ "$DEG" = hayır ] && [ "$BUL" = evet ] && [ "$F2" -lt "$F1" ] && [ "$RC3" = 1 ] && [ ! -s "$T/i3.md" ]
