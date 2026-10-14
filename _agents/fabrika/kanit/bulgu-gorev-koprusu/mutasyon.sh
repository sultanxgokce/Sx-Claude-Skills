#!/usr/bin/env bash
# Mutasyon (bulgu-gorev-koprusu): her korumayı tek tek boz → bulgu.test.sh KIRMIZI olmalı. Kopya dizinde koşar; önce POZİTİF kontrol, desen yoksa "ölçülmedi".
K="$(cd "$(dirname "$0")/../../../.." && pwd)"; W="$(mktemp -d)"; trap 'rm -r "$W"' EXIT; r=0
kopya() { mkdir -p "$W/s"; cp -r "$K/bulgu" "$W/s/"; }
uygula() { python3 -c '
import sys; p,a,b=sys.argv[1:4]; s=open(p,encoding="utf-8").read()
sys.exit(1) if a not in s else open(p,"w",encoding="utf-8").write(s.replace(a,b,1))' "$1" "$2" "$3"; }
kopya; if (cd "$W/s" && bash bulgu/scripts/bulgu.test.sh) >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: bozulmamış kopyada YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — hükümler sayılmaz"; r=1; fi; rm -r "$W/s"
kopya; if uygula "$W/s/bulgu/scripts/bulgu.sh" 'BU_DESEN_YOK' 'x'; then echo "  ✗ öz-sınav: olmayan desen uygulandı sayıldı"; r=1; else echo "  ✓ öz-sınav: olmayan desen reddedildi"; fi; rm -r "$W/s"
mut() { kopya; if ! uygula "$W/s/bulgu/scripts/bulgu.sh" "$2" "$3"; then echo "  ✗ $1 → UYGULANAMADI (desen yok) — ölçülmedi"; r=1; rm -r "$W/s"; return; fi
  if (cd "$W/s" && bash bulgu/scripts/bulgu.test.sh) >/dev/null 2>&1; then echo "  ✗ $1 → sınav YEŞİL kaldı"; r=1; else echo "  ✓ $1 → sınav kırmızı"; fi; rm -r "$W/s"; }
mut "M1 jeton varken de eski deftere yazar (köprü yok)" '    if [ -r "$JY" ]; then' '    if false; then'
mut "M2 merkez reddedince sessizce 0 döner" 'if kod!="201": print("⛔ merkezî defter reddetti' 'if False: print("⛔ merkezî defter reddetti'
mut "M3 merkeze ulaşılamayınca eski deftere düşer (ikilik)" 'if [ $rc -ne 0 ]; then echo "⛔ merkezî Görev Defteri' 'if [ $rc -ne 0 ]; then python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --kok "$KOK"; echo "⛔ merkezî Görev Defteri'
mut "M4 etiket kapısı kalkar" 'case "$etiket" in bug|ozellik) ;;' 'case "$etiket" in *) ;;'
mut "M5 kaynak_nereden yazılmaz" '"kaynak_nereden":"bulgu komutu",' ''
mut "M6 kanıt adım olmaz" 'if notu.strip(): d["adimlar"]=["[kanıt] "+notu.strip()]' 'pass'
mut "M7 jeton başlığa değil argv'ye düşer" 'printf '"'"'header = "x-defter-jeton: %s"\n'"'"' "$(tr -d '"'"'\n'"'"' < "$JY")" > "$cfg"' 'printf "" > "$cfg"; echo "jeton=$(tr -d "\\n" < "$JY")"'
echo; [ $r = 0 ] && echo "MUTASYON: hepsi ölçüldü" || echo "MUTASYON: en az biri ölçülmedi/yeşil kaldı"; exit $r
