#!/usr/bin/env bash
# once-sonra.sh <kart.sh yolu> — W42'nin gerçek kartlarını geçici depoda açar; uyarı satırlarını ve kart alanını basar.
set -uo pipefail
KT="$1"; T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
export KANIT_DEPO="$T" FABRIKA_TETIK=/nonexistent
ac() { bash "$KT" ac "$1" --is "$2" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h 2>&1; echo "   rc=$?"; }
echo "── hendese-kutuphane-h1 (W42, haftalık yazıldı · günlük teslim edildi)"
ac h1 "HENDESE kütüphanesi 1. hafta: günlük tur kayıtları (depo/web/video) + örnek vaka kartları, kaynaklı"
echo "── iki depolu örnek"
ac ikid "Nexus wait-ci --repo bayrağını tanısın ve cloudtop zili aynı kuralla bildirsin"
echo "── düz cümle"
ac duz "buton ekle"
for k in h1 ikid duz; do printf '   %s.kapsam_uyarilari = %s\n' "$k" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("kapsam_uyarilari","(alan yok)"))' "$T/_agents/fabrika/kartlar/$k.json")"; done
