#!/usr/bin/env bash
# kapsam.test.sh — hermetik: merkez/kutu ayrımı sahte filo.sh ile; soru yalnız merkezde ve yalnız argümansız; tanınmayan argüman rc 2.
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'rm -r -- "$T"' EXIT
printf '#!/bin/bash\necho sahte-filo "$@"\n' > "$T/filo.sh"; chmod +x "$T/filo.sh"
g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
K="$H/kapsam.sh"; M(){ GUNLUK_PLAN_FILO_SH="$T/filo.sh" bash "$K" "$@"; }; U(){ GUNLUK_PLAN_FILO_SH="$T/yok.sh" bash "$K" "$@"; }
o=$(M 2>&1); r=$?; ok "K1 merkezde argümansız → SOR (tek soru, iki şık, önerim tüm filo)" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=SOR"* ]] && [[ "$o" == *"SORU=Bu kutu mu, tüm filo mu?"* ]] && [[ "$o" == *"tüm filo (önerim)|bu kutu"* ]]'
o=$(U 2>&1); r=$?; ok "K2 kutuda argümansız → kutu, SORU YOK" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=kutu"* ]] && [[ "$o" != *SORU* ]]'
o=$(M tüm filo 2>&1); r=$?; ok "K3 merkezde 'tüm filo' → filo + üç komut (plan · uygula · özet) filo.sh'a bağlı" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=filo"* ]] && [[ "$o" == *"gunluk-plan --hepsi"* ]] && [[ "$o" == *"--hepsi --uygula"* ]] && [[ "$o" == *"gunluk-plan-ozet"* ]] && [[ "$o" != *SORU* ]]'
o=$(M "Tüm Filo" 2>&1); r=$?; ok "K3b büyük harf de tanınır" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=filo"* ]]'
o=$(M bu kutu 2>&1); r=$?; ok "K4 merkezde 'bu kutu' → kutu, soru yok, filo komutu yok" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=kutu"* ]] && [[ "$o" != *KOMUT* ]]'
o=$(M kapanis 2>&1); r=$?; ok "K4b 'kapanis' → kutu (gün sonu kendi kutusunun işi)" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=kutu"* ]]'
o=$(U tüm filo 2>&1); r=$?; ok "K5 kutuda 'tüm filo' → rc 2, söylenir (filo motoru yok)" '[ $r -eq 2 ] && [[ "$o" == *"yalnız merkezde"* ]]'
o=$(M yarım filo 2>&1); r=$?; ok "K6 tanınmayan argüman → rc 2, kapsam UYDURULMAZ" '[ $r -eq 2 ] && [[ "$o" == *"tanınmayan kapsam"* ]] && [[ "$o" != *KAPSAM=* ]]'
o=$(M --kos tüm filo 2>&1); r=$?; ok "K7 --kos ile filo: karar + PLAN komutu GERÇEKTEN koşar (sahte filo.sh 'gunluk-plan --hepsi' aldı), uygula KOŞMAZ" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=filo"* ]] && [[ "$o" == *"sahte-filo gunluk-plan --hepsi"* ]] && [[ "$o" != *"sahte-filo gunluk-plan --hepsi --uygula"* ]]'
o=$(M --kos 2>&1); r=$?; ok "K7b --kos argümansız merkezde yine SOR (soru koşturulmaz, hiçbir komut gitmez)" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=SOR"* ]] && [[ "$o" != *sahte-filo* ]]'
o=$(M --kos bu kutu 2>&1); r=$?; ok "K7c --kos bu kutu → kutu, filo komutu koşmaz" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=kutu"* ]] && [[ "$o" != *sahte-filo* ]]'
o=$(M --kos --uygula tüm filo 2>&1); r=$?; ok "K8 --kos --uygula ile filo: mektuplar gider (gunluk-plan --hepsi --uygula) ve ilk özet alınır (gunluk-plan-ozet) — kartın tam zinciri" '[ $r -eq 0 ] && [[ "$o" == *"sahte-filo gunluk-plan --hepsi --uygula"* ]] && [[ "$o" == *"sahte-filo gunluk-plan-ozet"* ]]'
o=$(M --uygula --kos tüm filo 2>&1); r=$?; ok "K8b bayrak sırası fark etmez" '[ $r -eq 0 ] && [[ "$o" == *"--hepsi --uygula"* ]]'
o=$(M --uygula tüm filo 2>&1); r=$?; ok "K8c --uygula tek başına (--kos yok) hiçbir şey koşturmaz: yalnız karar" '[ $r -eq 0 ] && [[ "$o" != *sahte-filo* ]] && [[ "$o" == *"KAPSAM=filo"* ]]'
o=$(M --kos --uygula 2>&1); r=$?; ok "K8d argümansız merkezde --uygula olsa da SOR; hiçbir mektup gitmez" '[ $r -eq 0 ] && [[ "$o" == *"KAPSAM=SOR"* ]] && [[ "$o" != *sahte-filo* ]]'
printf '#!/bin/bash\necho sahte-filo "$@"; case "$*" in *ozet*) exit 1;; esac\n' > "$T/filo-ozet-duser.sh"; chmod +x "$T/filo-ozet-duser.sh"
o=$(GUNLUK_PLAN_FILO_SH="$T/filo-ozet-duser.sh" bash "$K" --kos --uygula tüm filo 2>&1); r=$?; ok "K8e uygula geçip ÖZET düşerse zincir rc≠0 ve söylenir (sahte yeşil yok)" '[ $r -ne 0 ] && [[ "$o" == *"tek özet VERİLEMEDİ"* ]]'
echo "kapsam.test: $g geçti · $k kaldı"; [ $k -eq 0 ]
