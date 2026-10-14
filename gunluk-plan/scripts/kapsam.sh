#!/usr/bin/env bash
# kapsam.sh — /gunluk-plan'ın İLK kararı: bu kutu mu, tüm filo mu? (S-15, Sultan 14 Ekim 2026). Beceri metni bunu çağırır; karar koddadır.
#   bash kapsam.sh [<argüman…>]      → stdout: KAPSAM=filo|kutu|SOR  (+ filo ise koşulacak komutlar)   · rc 0 karar verildi · 2 tanınmayan argüman
# Kural: argüman "tüm filo"|"filo"|"hepsi" → filo · "bu kutu"|"kutu"|"kapanis" → kutu · boş: MERKEZDE → SOR (tek soru: tüm filo (önerim) / bu kutu),
#        kutuda → kutu (soru yok) · başka argüman → rc 2 (uydurma kapsam yok).
# Merkez = filo motorunun bulunduğu kutu: $GUNLUK_PLAN_FILO_SH (varsayılan /config/projects/Nexus/scripts/filo.sh) çalıştırılabilirse.
#   --kos : kararı yalnız YAZMAZ, filo ise PLAN komutunu da koşturur (bash $FILO_SH gunluk-plan --hepsi) — uygula ASLA kendiliğinden değil,
#           o SERDAR'ın açık adımıdır. Beceri metni merkezde bunu --kos ile çağırır; böylece "soru → karar → plan" zinciri tek kapıdan geçer.
set -u
FILO_SH="${GUNLUK_PLAN_FILO_SH:-/config/projects/Nexus/scripts/filo.sh}"
KOS=0; UYG=0
while [ "${1:-}" = "--kos" ] || [ "${1:-}" = "--uygula" ]; do case "$1" in --kos) KOS=1;; --uygula) UYG=1;; esac; shift; done
# --kos --uygula : "tüm filo" kararının TAM zinciri — mektuplar gider (gunluk-plan --hepsi --uygula) ve hemen ilk özet alınır
#                  (gunluk-plan-ozet; dönüşler zille geldikçe özet yeniden koşturulur). --uygula açık bayraktır: mektup göndermek bir eylemdir.
merkez=0; [ -x "$FILO_SH" ] && merkez=1
arg="$(printf '%s' "$*" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')"
case "$arg" in
  "tüm filo"|"tum filo"|filo|hepsi) k=filo ;;
  "bu kutu"|kutu|kapanis) k=kutu ;;
  "") if [ $merkez = 1 ]; then k=SOR; else k=kutu; fi ;;
  *) echo "⛔ tanınmayan kapsam: '$*' — 'tüm filo' ya da 'bu kutu' (argümansız: merkezde sorulur)" >&2; exit 2 ;;
esac
if [ "$k" = filo ] && [ $merkez = 0 ]; then echo "⛔ 'tüm filo' yalnız merkezde (filo motoru yok: $FILO_SH) — bu kutuda yalnız kendi planın" >&2; exit 2; fi
echo "KAPSAM=$k"
case "$k" in
  SOR)  echo "SORU=Bu kutu mu, tüm filo mu?"; echo "SIKLAR=tüm filo (önerim)|bu kutu" ;;
  filo) echo "KOMUT_PLAN=bash $FILO_SH gunluk-plan --hepsi"; echo "KOMUT_UYGULA=bash $FILO_SH gunluk-plan --hepsi --uygula"; echo "KOMUT_OZET=bash $FILO_SH gunluk-plan-ozet"
        if [ $KOS = 1 ] && [ $UYG = 1 ]; then
          echo "── UYGULA (mektuplar reislere gidiyor) ──"; bash "$FILO_SH" gunluk-plan --hepsi --uygula; rc=$?
          echo "── İLK ÖZET (dönüşler geldikçe yeniden: KOMUT_OZET) ──"; bash "$FILO_SH" gunluk-plan-ozet; exit $rc
        elif [ $KOS = 1 ]; then echo "── PLAN (koşturuldu, hiçbir mektup gitmedi; göndermek: --kos --uygula) ──"; bash "$FILO_SH" gunluk-plan --hepsi; exit $?; fi ;;
esac
