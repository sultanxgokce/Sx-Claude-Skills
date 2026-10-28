#!/usr/bin/env bash
# denetci-duzeltme-farki.test.sh — düzeltme turu yalnız yeni farkı görür + istem tavanı 100 KB (gorev_01M5JF5768X01SKG4QA11SYV3F).
#
# NİÇİN AYRI DOSYA: kurulum gerçek bir çıplak origin, iki klon ve ana hattın ilerleyip dala birleşmesini ister (denetci.test.sh
# origin'siz tek depo); denetci.test.sh de 900 sn kabuk tavanına yakın (ölçüldü 23 Eki: bu dosya 34 sn). Onu ÇAĞIRAN CI lint'idir:
# "Kabuk sınamaları" adımı depodaki her *.test.sh'ı find ile türetir — denetci.test.sh'a bağlanmadı ki o tavanı aşmasın.
# HERMETİK: denetçi DENETCI_KOMUT ile sahte betik (istemi diske bırakır, SAHTE_JSON basar); zil kapalı.
# Mutant kipi: MUTANT_D=<bozuk denetci.sh> ile koşunca kapılar o dosyayı sınar.
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >"$KOK/son.out" 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren() { if grep -qF -- "$2" "$3" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $1"; else DUSEN=$((DUSEN+1)); echo "  ✗ $1 ('$2' $3 içinde yok)"; fi; }
icermeyen() { if grep -qF -- "$2" "$3" 2>/dev/null; then DUSEN=$((DUSEN+1)); echo "  ✗ $1 ('$2' var, olmamalı)"; else GECEN=$((GECEN+1)); echo "  ✓ $1"; fi; }
dogru() { if python3 -c "$2" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $1"; else DUSEN=$((DUSEN+1)); echo "  ✗ $1"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
git init -q --bare -b main "$KOK/o.git"
git clone -q "$KOK/o.git" "$KOK/w" 2>/dev/null; git clone -q "$KOK/o.git" "$KOK/baska" 2>/dev/null
for r in w baska; do git -C "$KOK/$r" config user.email t@t; git -C "$KOK/$r" config user.name t; done
echo taban > "$KOK/w/a.txt"; git -C "$KOK/w" add a.txt; git -C "$KOK/w" commit -q -m taban; git -C "$KOK/w" push -q origin main 2>/dev/null
git -C "$KOK/w" remote set-head origin main >/dev/null 2>&1
printf 'İŞ: düzeltme farkı\nSINIF: yok\n' > "$KOK/kart.md"
SAHTE="$KOK/sahte.sh"; printf '#!/usr/bin/env bash\ncp "$1" "$SAHTE_ISTEM_KOPYA"; printf %%s "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
export DENETCI_KOMUT="$SAHTE" SAHTE_ISTEM_KOPYA="$KOK/istem.md"
J4='{"kod_puani":4,"dogru_sey":"E","ozet":"o","bulgular":[{"ne":"sinir-kontrolu-eksik","kanit":"k","konum":"kod.txt:1","agirlik":"uygulama"},{"ne":"canli-kurulum-yok","kanit":"k","konum":"host","agirlik":"kutu-disi","kutu_disi_yuzey":"cloudtop host"}],"kanit_gorusu":"k"}'
J5='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
kanitla() { KANIT_DEPO="$KOK/w" bash "$K" olcum "$1" o --asama tek -- true >/dev/null 2>&1; }
den() { local is="$1" js="$2"; shift 2; ( cd "$KOK/w" && SAHTE_JSON="$js" KANIT_DEPO="$KOK/w" bash "$D" "$is" --kart "$KOK/kart.md" "$@" < /dev/null ); }
kayit() { echo "$KOK/w/_agents/fabrika/kanit/$1/DENETIM-$2.json"; }
yap() { local dal="$1"; git -C "$KOK/w" checkout -q -b "$dal" origin/main 2>/dev/null
  printf 'degismeyen-dosya-icerigi\n' > "$KOK/w/eski-$dal.txt"; printf 'ilk-satir\n' > "$KOK/w/kod-$dal.txt"
  git -C "$KOK/w" add "eski-$dal.txt" "kod-$dal.txt"; git -C "$KOK/w" commit -q -m "ilk $dal"; }

echo "════ D1 · tur 1: tam fark gider, kayıt incelediği başı (bas) yazar ════"
yap d1; kanitla d1; A1="$(git -C "$KOK/w" rev-parse HEAD)"; : > "$KOK/istem.md"
kapi "D1a tur 1 koştu (4/E → rc 1)" 1 den d1 "$J4"
iceren "D1b istemde değişmeyecek dosya var (tam fark)" "degismeyen-dosya-icerigi" "$KOK/istem.md"
dogru "D1c DENETIM-1.bas = incelenen baş" "import json;d=json.load(open('$(kayit d1 1)'));assert d['bas']=='$A1' and d['duzeltme_farki'] is None"

echo "════ D2 · tur 2 (yeni commit + ana hat dala birleşti): yalnız A..B farkı, PR dosyalarıyla sınırlı; önceki bulgular sayılı ════"
git -C "$KOK/baska" pull -q origin main 2>/dev/null; echo baskasinin-icerigi > "$KOK/baska/baskasinin.txt"
git -C "$KOK/baska" add baskasinin.txt; git -C "$KOK/baska" commit -q -m baska; git -C "$KOK/baska" push -q origin main 2>/dev/null
git -C "$KOK/w" fetch -q origin 2>/dev/null; git -C "$KOK/w" merge -q --no-edit origin/main 2>/dev/null
printf 'ilk-satir\nduzeltme-satiri\n' > "$KOK/w/kod-d1.txt"; git -C "$KOK/w" commit -q -am duzeltme; B1="$(git -C "$KOK/w" rev-parse HEAD)"
: > "$KOK/istem.md"
kapi "D2a tur 2 koştu (5/E → rc 0)" 0 den d1 "$J5"
iceren "D2b ekranda DÜZELTME TURU satırı" "DÜZELTME TURU: göze yalnız ${A1:0:8}..${B1:0:8}" "$KOK/son.out"
iceren "D2c istemde düzeltme notu" "[NOT: DÜZELTME TURU" "$KOK/istem.md"
iceren "D2d istemde yeni satır var" "+duzeltme-satiri" "$KOK/istem.md"
icermeyen "D2e değişmeyen dosya istemde YOK (yalnız yeni fark)" "degismeyen-dosya-icerigi" "$KOK/istem.md"
icermeyen "D2f ana hattan gelen başkasının dosyası farka girmedi" "baskasinin-icerigi" "$KOK/istem.md"
iceren "D2g önceki bulgu ayrı satırda sayıldı" "B1. [uygulama] sinir-kontrolu-eksik" "$KOK/istem.md"
iceren "D2i kutu-dışı önceki bulgu da sayıldı, sınıfıyla (göz #436 tur 2)" "B2. [kutu-disi] canli-kurulum-yok" "$KOK/istem.md"
dogru "D2h DENETIM-2: bas=B, duzeltme_farki.onceki_bas=A, dosya=1" "import json;d=json.load(open('$(kayit d1 2)'));f=d['duzeltme_farki'];assert d['bas']=='$B1' and f['onceki_bas']=='$A1' and f['dosya']==1 and f['tam_bayt']>f['bayt']>0"

echo "════ D3 · baş değişmedi → fark BOŞ gider, istem bunu söyler (göz #436 tur 1: boş kümede tam farka dönülmez) ════"
yap d3; kanitla d3; den d3 "$J4" >/dev/null 2>&1; : > "$KOK/istem.md"
kapi "D3a tur 2 aynı başla koştu" 0 den d3 "$J5"
iceren "D3b ekranda: YENİ DEĞİŞİKLİK YOK → fark BOŞ" "YENİ DEĞİŞİKLİK YOK → fark BOŞ gider" "$KOK/son.out"
icermeyen "D3c 🔴 tam fark GİTMEDİ" "degismeyen-dosya-icerigi" "$KOK/istem.md"
iceren "D3d istem farkın BOŞ olduğunu ve niçin söylüyor" "YENİ DEĞİŞİKLİK YOK, bu yüzden aşağıdaki fark BOŞTUR" "$KOK/istem.md"
iceren "D3e önceki bulgu yine sayıldı" "B1. [uygulama] sinir-kontrolu-eksik" "$KOK/istem.md"
dogru "D3f kayıt: duzeltme_farki.dosya=0" "import json;d=json.load(open('$(kayit d3 2)'));f=d['duzeltme_farki'];assert f and f['dosya']==0 and f['bayt']==0"

echo "════ D3x · yeni commit var ama yalnız PR DIŞI dosyada (ana hat birleşmesi) → fark BOŞ ════"
yap d3x; kanitla d3x; den d3x "$J4" >/dev/null 2>&1
git -C "$KOK/baska" pull -q origin main 2>/dev/null; echo d3x-baskasi > "$KOK/baska/d3x-baska.txt"
git -C "$KOK/baska" add d3x-baska.txt; git -C "$KOK/baska" commit -q -m d3xb; git -C "$KOK/baska" push -q origin main 2>/dev/null
git -C "$KOK/w" fetch -q origin 2>/dev/null; git -C "$KOK/w" merge -q --no-edit origin/main 2>/dev/null; : > "$KOK/istem.md"
kapi "D3xa tur 2 koştu" 0 den d3x "$J5"
iceren "D3xb ekranda YENİ DEĞİŞİKLİK YOK" "YENİ DEĞİŞİKLİK YOK" "$KOK/son.out"
icermeyen "D3xc ne tam fark ne başkasının dosyası gitti" "degismeyen-dosya-icerigi" "$KOK/istem.md"

echo "════ D4 · önceki kayıt bas taşımıyor (eski kayıt) → tam fark, sebebi ekranda ════"
yap d4; kanitla d4; den d4 "$J4" >/dev/null 2>&1
python3 -c "import json;p='$(kayit d4 1)';d=json.load(open(p));d.pop('bas',None);json.dump(d,open(p,'w'))"
printf 'ilk-satir\nyeni\n' > "$KOK/w/kod-d4.txt"; git -C "$KOK/w" commit -q -am d4b; : > "$KOK/istem.md"
kapi "D4a tur 2 koştu" 0 den d4 "$J5"
iceren "D4b sebep: eski kayıt" "eski kayıt" "$KOK/son.out"
iceren "D4c tam fark gitti" "degismeyen-dosya-icerigi" "$KOK/istem.md"

echo "════ D4x · eski kayıt (bas yok) ama kaydı bir commit ekledi → baş atadan türetilir, yalnız yeni fark gider (gorev …DCX24C) ════"
yap d4x; kanitla d4x; AX="$(git -C "$KOK/w" rev-parse HEAD)"; den d4x "$J4" >/dev/null 2>&1
python3 -c "import json;p='$(kayit d4x 1)';d=json.load(open(p));d.pop('bas',None);json.dump(d,open(p,'w'))"
git -C "$KOK/w" add "_agents/fabrika/kanit/d4x/DENETIM-1.json"; git -C "$KOK/w" commit -q -m "docs: d4x göz tur 1 kaydı"
printf 'ilk-satir\nduzeltme-d4x\n' > "$KOK/w/kod-d4x.txt"; git -C "$KOK/w" commit -q -am d4xb; BX="$(git -C "$KOK/w" rev-parse HEAD)"; : > "$KOK/istem.md"
kapi "D4xa tur 2 koştu" 0 den d4x "$J5"
iceren "D4xb ekranda türetme söylendi" "incelenen baş ${AX:0:8} olarak türetildi" "$KOK/son.out"
iceren "D4xc yalnız yeni fark gitti" "+duzeltme-d4x" "$KOK/istem.md"
icermeyen "D4xd 🔴 değişmeyen dosya (tam fark) GİTMEDİ" "degismeyen-dosya-icerigi" "$KOK/istem.md"
dogru "D4xe kayıt: duzeltme_farki.onceki_bas=türetilen baş" "import json;d=json.load(open('$(kayit d4x 2)'));f=d['duzeltme_farki'];assert f and f['onceki_bas']=='$AX' and f['dosya']>=1"

echo "════ D5 · --diff kipi: baş ölçülemez → bas boş ════"
printf 'diff --git a/x b/x\n+satir\n' > "$KOK/d.patch"; kanitla d5
kapi "D5a --diff ile koştu" 0 den d5 "$J5" --diff "$KOK/d.patch"
dogru "D5b DENETIM-1.bas = null" "import json;d=json.load(open('$(kayit d5 1)'));assert d['bas'] is None"

echo "════ D6 · istem 100 KB'ı aşınca HER denetçide gönderim durur (sahte denetçi, eşik dikişi YOK) ════"
yap d6; python3 -c "open('$KOK/w/buyuk-d6.txt','w').write(''.join('satir-%05d-%s\n'%(i,'b'*80) for i in range(1100)))"
git -C "$KOK/w" add buyuk-d6.txt; git -C "$KOK/w" commit -q -m buyuk; kanitla d6; : > "$KOK/istem.md"
unset DENETCI_KIRP_ESIK DENETCI_ISTEM_TAVAN
kapi "D6a ~100 KB üstü istem → rc 1 (İŞİ BÖL)" 1 den d6 "$J5"
iceren "D6b sınır 100000 olarak söyleniyor" "> 100000 (istem tavanı" "$KOK/son.out"
[ ! -e "$(kayit d6 1)" ] && [ ! -s "$KOK/istem.md" ] && { GECEN=$((GECEN+1)); echo "  ✓ D6c tur yakılmadı, denetçiye istem gitmedi"; } || { DUSEN=$((DUSEN+1)); echo "  ✗ D6c tur yandı ya da istem gitti"; }
kapi "D6e 🔴 ayıklama KAPALIYKEN de durur (göz #436 tur 1)" 1 env DENETCI_KANIT_AYIKLA=0 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" d6 --kart "$4" < /dev/null' _ "$KOK/w" "$J5" "$D" "$KOK/kart.md"
DENETCI_ISTEM_TAVAN=200000 kapi "D6d DENETCI_ISTEM_TAVAN=200000 ile aynı iş denetlenir (rc 0)" 0 den d6 "$J5"

echo "════ D7 · boşluklu + Türkçe harfli dosya adı: git'in kaçışladığı yol düzeltme farkına girer (göz #436 tur 2) ════"
yap d7; printf 'ilk\n' > "$KOK/w/çok özel ad.txt"; git -C "$KOK/w" add "çok özel ad.txt"; git -C "$KOK/w" commit -q -m d7ozel
kanitla d7; den d7 "$J4" >/dev/null 2>&1
printf 'ilk\nozel-ad-duzeltmesi\n' > "$KOK/w/çok özel ad.txt"; git -C "$KOK/w" commit -q -am d7duz; : > "$KOK/istem.md"
kapi "D7a tur 2 koştu" 0 den d7 "$J5"
iceren "D7b 🔴 özel adlı dosyanın değişikliği göze gitti" "+ozel-ad-duzeltmesi" "$KOK/istem.md"
dogru "D7c kayıt: duzeltme_farki.dosya=1 (boş fark sanılmadı)" "import json;d=json.load(open('$(kayit d7 2)'));assert d['duzeltme_farki']['dosya']==1"

echo "════ D9 · düzeltme commit'i bir PR dosyasını ana dal hâline TAMAMEN geri alırsa o geri alma göze gider (göz #436 tur 3) ════"
yap d9; printf 'geri-alinacak-satir\n' >> "$KOK/w/a.txt"; git -C "$KOK/w" commit -q -am d9ek; kanitla d9; den d9 "$J4" >/dev/null 2>&1
git -C "$KOK/w" show origin/main:a.txt > "$KOK/w/a.txt"; git -C "$KOK/w" commit -q -am d9gerial; : > "$KOK/istem.md"
kapi "D9a tur 2 koştu" 0 den d9 "$J5"
iceren "D9b 🔴 geri alma (silinen satır) göze gitti" "-geri-alinacak-satir" "$KOK/istem.md"
dogru "D9c kayıt: duzeltme_farki.dosya=1" "import json;d=json.load(open('$(kayit d9 2)'));assert d['duzeltme_farki']['dosya']==1"

echo "════ D8 · MUTASYON: her kapı kaldırılınca bir D kapısı düşer; kontrol D1a geçer ════"
if [ -z "${MUTANT_D:-}" ]; then
  mut() { local ad="$1" eski="$2" yeni="$3" kapi_adi="$4"; local P="$KOK/mutpkg-$ad"; mkdir -p "$P"; cp -p "$HERE"/* "$P/" 2>/dev/null
    python3 - "$HERE/denetci.sh" "$P/denetci.sh" "$eski" "$yeni" <<'PY'
import sys; s,d,e,y=sys.argv[1:]; t=open(s,encoding='utf-8').read(); assert e in t, "desen yok: "+e; open(d,'w',encoding='utf-8').write(t.replace(e,y,1))
PY
    local O; O="$(MUTANT_D="$P/denetci.sh" bash "$HERE/denetci-duzeltme-farki.test.sh" 2>/dev/null)"
    if grep -q "✗ $kapi_adi" <<<"$O" && grep -q "✓ D1a" <<<"$O"; then
      GECEN=$((GECEN+1)); echo "  ✓ mutant '$ad' → $kapi_adi düştü, kontrol D1a geçti"
    else DUSEN=$((DUSEN+1)); echo "  ✗ mutant '$ad' → $kapi_adi düşmedi ya da kontrol D1a da düştü (geçersiz mutant)"; fi; }
  mut duzeltme-yok 'if [ "$TUR" -gt 1 ] && [ -n "$BAS" ]; then' 'if false; then' "D2e"
  mut dosya-siniri-yok 'git -C "$DEPO" --literal-pathspecs diff "$_ob" "$BAS" -- "${_pd[@]}"' 'git -C "$DEPO" diff "$_ob" "$BAS"' "D2f"
  # iki ucun İKİSİ de NUL'suz (kaçışlı) okunur: tek ucu bozmak öbür uç aynı yolu getirdiği için örtülürdü (göz #436 tur 3)
  YOL_E="$(cat <<'MUTE'
--name-only -z "$_mb" "$BAS" && git -C "$DEPO" diff --no-renames --name-only -z "$(git -C "$DEPO" merge-base "$_ana" "$_ob")" "$_ob"; } 2>/dev/null | sort -zu)
MUTE
)"; YOL_Y="$(cat <<'MUTY'
--name-only "$_mb" "$BAS" && git -C "$DEPO" diff --no-renames --name-only "$(git -C "$DEPO" merge-base "$_ana" "$_ob")" "$_ob"; } 2>/dev/null | sort -u | tr '\n' '\0')
MUTY
)"
  mut yol-kacisli-okunur "$YOL_E" "$YOL_Y" "D7b"
  mut geri-alinan-dosya-duser ' && git -C "$DEPO" diff --no-renames --name-only -z "$(git -C "$DEPO" merge-base "$_ana" "$_ob")" "$_ob"; }' '; }' "D9b"
  mut kutu-disi-ayiklanir 'b=list(s.get("bulgular") or [])' 'b=[x for x in (s.get("bulgular") or []) if x.get("agirlik")!="kutu-disi"]' "D2i"
  mut bas-yazilmaz '"bas":(bas or None),' '"bas":None,' "D1c"
  mut onceki-bulgu-sayilmaz 'for i,x in enumerate(b,1): print(' 'for i,x in []: print(' "D2g"
  mut tavan-yalniz-codex 'if [ "$ISTEM_BAYT" -gt "$BOL_SINIR" ]; then' 'if { [ "$DENETCI" = "codex" ] || [ -n "${DENETCI_KIRP_ESIK:-}" ]; } && [ "$ISTEM_BAYT" -gt "$KIRP_TETIK" ]; then' "D6a"
  mut tavan-ayiklamaya-bagli 'if [ "$ISTEM_BAYT" -gt "$BOL_SINIR" ]; then' 'if [ "${DENETCI_KANIT_AYIKLA:-1}" != "0" ] && [ "$ISTEM_BAYT" -gt "$BOL_SINIR" ]; then' "D6e"
  mut bos-farkta-tam-fark '      DUZ_ONCEKI_BAS="$_ob"; mv "$TMP/diff-duz.patch" "$TMP/diff.patch"' '      [ "$DUZ_DOSYA" -eq 0 ] && DUZ_ONCEKI_BAS="" || { DUZ_ONCEKI_BAS="$_ob"; mv "$TMP/diff-duz.patch" "$TMP/diff.patch"; }' "D3c"
  mut tavan-120k 'ISTEM_TAVAN="${DENETCI_ISTEM_TAVAN:-100000}"' 'ISTEM_TAVAN="${DENETCI_ISTEM_TAVAN:-200000}"' "D6a"
fi

echo ""; echo "── SONUÇ (düzeltme-farkı): $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
