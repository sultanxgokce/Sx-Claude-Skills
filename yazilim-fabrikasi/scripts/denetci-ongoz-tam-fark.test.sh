#!/usr/bin/env bash
# denetci-ongoz-tam-fark.test.sh — düzeltme turunda ÖN GÖZ (DALGIÇ) PR'ın TAM farkını alır, bağımsız göz artımı (gorev_01M67TF3YGARSRT7052C2GXKMT).
# Ölçülmüş kusur: düzeltme turunda ön göz yalnız artımlı farkı görüp kart cümlesine karşı sahte UYUMSUZ diyordu. Düzeltme: ön göze tam fark (kanıt blokları atılır).
# Sahte denetçi (DENETCI_KOMUT) istemi diske bırakır; ön göz kapalı; zil kapalı. Mutant: MUTANT_D=<bozuk denetci.sh>.
# kabuk-testleri: sure=120
set -uo pipefail
export KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=-
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
SDAL="$KOK/dalgic.sh"; printf '#!/usr/bin/env bash\nwhile [ $# -gt 0 ]; do [ "$1" = --diff ] && cp "$2" "$DALGIC_KOPYA"; shift; done; echo sahte-ongoz; exit 0\n' > "$SDAL"; chmod +x "$SDAL"
export DALGIC_BIN="$SDAL" DALGIC_KOPYA="$KOK/dalgic-fark.txt"
git -C "$KOK/w" checkout -q -b d1 origin/main 2>/dev/null
printf 'degismeyen-dosya-icerigi\n' > "$KOK/w/eski.txt"; printf 'ilk-satir\n' > "$KOK/w/kod.txt"
git -C "$KOK/w" add eski.txt kod.txt; git -C "$KOK/w" commit -q -m ilk; kanitla d1
echo "════ O1 · tur 1: ön göz tam farkı alır ════"
kapi "O1a tur 1 koştu (4/E → rc 1)" 1 den d1 "$J4"
iceren "O1b ön göz farkında değişmeyen dosya var" "degismeyen-dosya-icerigi" "$DALGIC_KOPYA"
echo "════ O2 · tur 2 (düzeltme): göze artım, ön göze TAM fark ════"
printf 'ilk-satir\nduzeltme-1\n' > "$KOK/w/kod.txt"; git -C "$KOK/w" commit -q -am duz1; kanitla d1; : > "$KOK/istem.md"; : > "$DALGIC_KOPYA"
git -C "$KOK/w" add -A _agents 2>/dev/null; git -C "$KOK/w" commit -q -m kanit-kaydi 2>/dev/null   # kanıt blokları tam farkta bulunsun (O2f boş geçmesin)
kapi "O2a tur 2 koştu (5/E → rc 0)" 0 den d1 "$J5"
iceren "O2b göze giden fark artımlı (DÜZELTME TURU)" "DÜZELTME TURU" "$KOK/son.out"
icermeyen "O2c bağımsız göz istemi değişmeyen dosyayı İÇERMEZ" "degismeyen-dosya-icerigi" "$KOK/istem.md"
iceren "O2d ön göz farkında değişmeyen dosya VAR (tam fark)" "degismeyen-dosya-icerigi" "$DALGIC_KOPYA"
iceren "O2e ön göz farkında yeni satır da var" "duzeltme-1" "$DALGIC_KOPYA"
icermeyen "O2f ön göz farkında kanıt dizini bloğu YOK" "_agents/fabrika/kanit/" "$DALGIC_KOPYA"
iceren "O2g ekranda ön göz tam fark bilgisi" "ön göze PR'ın TAM farkı gider" "$KOK/son.out"
echo "SONUÇ: $GECEN geçti, $DUSEN düştü"; [[ $DUSEN -eq 0 ]]
