#!/usr/bin/env bash
# gorev-yolu.sh — günlük planın görev betiğini (gorev.sh) BULAN tek yer; çözülen yolu basar, bulamazsa rc 3 (ölçülemedi).
# Niçin: üç betik cloudtop yolunu çivilemişti; o depoyu görmeyen 9 kutuda plan maddeleri deftere yazılamıyordu (MUAVİN ölçümü, 27 Eki, 0HC75A).
# Sıra: GUNLUK_PLAN_GOREV_SH (sınav/elle) → cloudtop'taki kanonik betik (code kutusu: her zaman en yeni) → BU BECERİNİN kendi kopyası
#   (scripts/gorev.sh + dugum-bak.py; cloudtop'u görmeyen kutuda geçerli yol) → PATH'teki gorev.sh → /config/.local/bin/gorev.sh.
#   Kutu yerel kopyası EN SONDA: nova'daki eski sarmalayıcı '--ozet' bayrağını tanımıyordu (görev açılamıyordu); paketlenmiş kopya ondan önce gelir.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Açıkça verilen yol KESİNDİR (yoksa çağıran "ölçülemedi" der; sessizce başka betiğe düşülmez — sınav hermetik kalır).
[ -n "${GUNLUK_PLAN_GOREV_SH:-}" ] && { printf '%s\n' "$GUNLUK_PLAN_GOREV_SH"; exit 0; }
for y in "${GUNLUK_PLAN_CLOUDTOP_GOREV:-/config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh}" "$HERE/gorev.sh" "$(command -v gorev.sh 2>/dev/null)" /config/.local/bin/gorev.sh; do
  [ -n "$y" ] && [ -f "$y" ] && { printf '%s\n' "$y"; exit 0; }
done
echo "gorev-yolu: gorev.sh hiçbir yerde yok" >&2; exit 3
