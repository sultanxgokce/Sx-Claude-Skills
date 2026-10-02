#!/usr/bin/env bash
# komut.sh — /terminal-onar'ın tek giriş kapısı.
#   durum [--json]         beş parçayı ölç
#   onar [--web-yenile]    kademe 0 (betik) — sıfırdan inşa da budur
#   merdiven [--arka]      K0 → K1 başsız Claude → K2 kurtarıcı → K3 Sultan'a haber
#   duraklat "<sebep>"     bekçiyi durdur (bilerek kapatırken) · devam  bekçiyi aç
#   gunluk [N]             son N satır (varsayılan 30)
set -u
D="$(cd "$(dirname "$0")" && pwd)"; . "$D/ortak.sh"
case "${1:-durum}" in
  durum)    shift; exec bash "$D/durum.sh" "$@" ;;
  onar)     shift; exec bash "$D/onar.sh" "$@" ;;
  merdiven) shift; exec bash "$D/kademe.sh" --kaynak "${TO_KAYNAK:-elle}" "$@" ;;
  duraklat) printf '%s · %s\n' "$(date '+%F %T')" "${2:-sebep yazılmadı}" > "$DURUM_DIZ/duraklat"; gunluk "bekçi duraklatıldı: ${2:-}"; echo "bekçi duraklatıldı" ;;
  devam)    rm -f "$DURUM_DIZ/duraklat"; gunluk "bekçi yeniden açık"; echo "bekçi açık" ;;
  gunluk)   tail -n "${2:-30}" "$GUNLUK" 2>/dev/null || echo "günlük boş" ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
