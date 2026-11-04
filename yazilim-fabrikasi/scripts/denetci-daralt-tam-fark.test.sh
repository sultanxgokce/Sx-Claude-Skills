#!/usr/bin/env bash
# denetci-daralt-tam-fark.test.sh — kart daraltıldıktan sonraki İLK denetim turu PR'ın TAMAMINI görür (gorev_01M67TF3J5GZ80RWP484CMJHBB).
# Ölçülmüş kusur: denetci.sh tur>1 olunca farkı önceki turun başına göre kuruyordu; daraltmadan sonra önceki tur eski cümleye aitti,
# göz yeni cümlenin kapsadığı kodu görmeden puanlıyordu. Düzeltme: artımlı fark yalnız TUR > tur_sifir+1.
# Sahte denetçi (DENETCI_KOMUT) istemi diske bırakır; ön göz kapalı; zil kapalı. Mutant: MUTANT_D=<bozuk denetci.sh>.
# kabuk-testleri: sure=120
set -uo pipefail
export DALGIC_KAPALI=1 KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=-
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >"$KOK/son.out" 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren() { if grep -qF -- "$2" "$3" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $1"; else DUSEN=$((DUSEN+1)); echo "  ✗ $1 ('$2' $3 içinde yok)"; fi; }
icermeyen() { if grep -qF -- "$2" "$3" 2>/dev/null; then DUSEN=$((DUSEN+1)); echo "  ✗ $1 ('$2' var, olmamalı)"; else GECEN=$((GECEN+1)); echo "  ✓ $1"; fi; }
KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
git init -q --bare -b main "$KOK/o.git"; git clone -q "$KOK/o.git" "$KOK/w" 2>/dev/null
git -C "$KOK/w" config user.email t@t; git -C "$KOK/w" config user.name t
echo taban > "$KOK/w/a.txt"; git -C "$KOK/w" add a.txt; git -C "$KOK/w" commit -q -m taban; git -C "$KOK/w" push -q origin main 2>/dev/null
git -C "$KOK/w" remote set-head origin main >/dev/null 2>&1
printf 'İŞ: daralt tam fark\nSINIF: yok\n' > "$KOK/kart.md"
SAHTE="$KOK/sahte.sh"; printf '#!/usr/bin/env bash\ncp "$1" "$SAHTE_ISTEM_KOPYA"; printf %%s "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
export DENETCI_KOMUT="$SAHTE" SAHTE_ISTEM_KOPYA="$KOK/istem.md"
J4='{"kod_puani":4,"dogru_sey":"E","ozet":"o","bulgular":[{"ne":"sinir-kontrolu-eksik","kanit":"k","konum":"kod.txt:1","agirlik":"uygulama"}],"kanit_gorusu":"k"}'
J5='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
kanitla() { KANIT_DEPO="$KOK/w" bash "$K" olcum "$1" o --asama tek -- true >/dev/null 2>&1; }
den() { local is="$1" js="$2"; shift 2; local kz=(--kart "$KOK/kart.md")
  [ -f "$KOK/w/_agents/fabrika/kartlar/$is.json" ] && kz=()   # birincil kart varken --kart yasak (kart TEK kaynak)
  ( cd "$KOK/w" && SAHTE_JSON="$js" KANIT_DEPO="$KOK/w" bash "$D" "$is" "${kz[@]}" "$@" < /dev/null ); }
git -C "$KOK/w" checkout -q -b d1 origin/main 2>/dev/null
printf 'degismeyen-dosya-icerigi\n' > "$KOK/w/eski.txt"; printf 'ilk-satir\n' > "$KOK/w/kod.txt"
git -C "$KOK/w" add eski.txt kod.txt; git -C "$KOK/w" commit -q -m ilk; kanitla d1
echo "════ E1 · tur 1: tam fark ════"
kapi "E1a tur 1 koştu (4/E → rc 1)" 1 den d1 "$J4"
echo "════ E2 · kart daraltıldı (tur_sifir=1) + yeni commit: tur 2 = daraltmadan SONRAKİ ilk tur → TAM fark ════"
mkdir -p "$KOK/w/_agents/fabrika/kartlar"
printf '{"is":"d1","cumle":"daraltilmis cumle","daraltmalar":[{"tur_sifir":1,"kalan_kart":"d1-kalan"}],"sinif":{}}\n' > "$KOK/w/_agents/fabrika/kartlar/d1.json"
printf 'ilk-satir\nduzeltme-1\n' > "$KOK/w/kod.txt"; git -C "$KOK/w" commit -q -am duz1; kanitla d1; : > "$KOK/istem.md"
kapi "E2a tur 2 koştu (5/E → rc 0)" 0 den d1 "$J5"
icermeyen "E2b DÜZELTME TURU satırı YOK (daralma sonrası ilk tur artımlı değil)" "DÜZELTME TURU" "$KOK/son.out"
iceren "E2c istemde değişmeyen dosya VAR (PR bütünü gitti)" "degismeyen-dosya-icerigi" "$KOK/istem.md"
echo "════ E3 · aynı daraltılmış cümlede ikinci tur (tur 3): artımlı fark geri gelir ════"
printf 'ilk-satir\nduzeltme-1\nduzeltme-2\n' > "$KOK/w/kod.txt"; git -C "$KOK/w" commit -q -am duz2; kanitla d1; : > "$KOK/istem.md"
kapi "E3a tur 3 koştu (5/E → rc 0)" 0 den d1 "$J5"
iceren "E3b DÜZELTME TURU satırı VAR" "DÜZELTME TURU" "$KOK/son.out"
icermeyen "E3c değişmeyen dosya istemde YOK (yalnız yeni fark)" "degismeyen-dosya-icerigi" "$KOK/istem.md"
echo "SONUÇ: $GECEN geçti, $DUSEN düştü"; [[ $DUSEN -eq 0 ]]
