#!/usr/bin/env bash
# Mutasyon (gunluk-plan-kapsam): kapsam.sh korumalarını tek tek boz → kapsam.test.sh KIRMIZI olmalı. Kopya dizinde; pozitif kontrol + desen kapısı.
K="$(cd "$(dirname "$0")/../../../.." && pwd)"; W="$(mktemp -d)"; trap 'rm -r "$W"' EXIT; r=0
kopya() { mkdir -p "$W/s"; cp -r "$K/gunluk-plan" "$W/s/"; }
uygula() { python3 -c '
import sys; p,a,b=sys.argv[1:4]; s=open(p,encoding="utf-8").read()
sys.exit(1) if a not in s else open(p,"w",encoding="utf-8").write(s.replace(a,b,1))' "$1" "$2" "$3"; }
kopya; if (cd "$W/s" && bash gunluk-plan/scripts/kapsam.test.sh) >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: bozulmamış kopyada YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI"; r=1; fi; rm -r "$W/s"
kopya; if uygula "$W/s/gunluk-plan/scripts/kapsam.sh" 'BU_DESEN_YOK' 'x'; then echo "  ✗ öz-sınav: olmayan desen uygulandı sayıldı"; r=1; else echo "  ✓ öz-sınav: olmayan desen reddedildi"; fi; rm -r "$W/s"
mut() { kopya; if ! uygula "$W/s/gunluk-plan/scripts/kapsam.sh" "$2" "$3"; then echo "  ✗ $1 → UYGULANAMADI (desen yok)"; r=1; rm -r "$W/s"; return; fi
  if (cd "$W/s" && bash gunluk-plan/scripts/kapsam.test.sh) >/dev/null 2>&1; then echo "  ✗ $1 → sınav YEŞİL kaldı"; r=1; else echo "  ✓ $1 → sınav kırmızı"; fi; rm -r "$W/s"; }
mut "M1 merkezde soru sorulmaz (varsayılan filo)" '"") if [ $merkez = 1 ]; then k=SOR; else k=kutu; fi ;;' '"") if [ $merkez = 1 ]; then k=filo; else k=kutu; fi ;;'
mut "M2 kutuda da soru sorulur" '"") if [ $merkez = 1 ]; then k=SOR; else k=kutu; fi ;;' '"") k=SOR ;;'
mut "M3 kutuda tüm filo kabul edilir" 'if [ "$k" = filo ] && [ $merkez = 0 ]; then' 'if false; then'
mut "M4 tanınmayan argüman kutu sayılır (uydurma kapsam)" '" >&2; exit 2 ;;' '" >&2; k=kutu ;;'
mut "M5 filo seçiminde özet komutu verilmez" 'echo "KOMUT_OZET=bash $FILO_SH gunluk-plan-ozet"' 'true'
echo; [ $r = 0 ] && echo "MUTASYON: hepsi ölçüldü" || echo "MUTASYON: en az biri ölçülmedi/yeşil kaldı"; exit $r
