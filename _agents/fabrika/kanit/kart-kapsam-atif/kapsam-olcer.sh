#!/usr/bin/env bash
# kapsam-olcer.sh <kart.sh> — 20 Eki'nin GERÇEK kart cümleleri: hangisi "ÇOK GÜNLÜK KAPSAM" uyarısı alıyor?
# Geçici depo; kart.sh ac koşar (uyarı yalnız ekrana + karta). Satır: <beklenen> · <gelen> · cümle
set -uo pipefail
K="$1"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
( cd "$T" && git init -q -b main ) >/dev/null 2>&1; export KANIT_DEPO="$T"
n=0; yanlis=0
olc() {   # olc <beklenen: UYARIR|SESSİZ> <cümle>
  n=$((n+1)); o="$(bash "$K" ac "is-$n" --is "$2" --istedi SERDAR --aldi HENDESE --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h 2>&1)"
  if grep -q "ÇOK GÜNLÜK KAPSAM" <<<"$o"; then g=UYARIR; else g=SESSİZ; fi
  [ "$g" = "$1" ] && i="✓" || { i="✗"; yanlis=$((yanlis+1)); }
  printf '%s beklenen %-6s · gelen %-6s · %s\n' "$i" "$1" "$g" "$(cut -c1-90 <<<"$2")"
}
echo "── 20 Eki'nin yanlış alarmları (atıf, kapsam değil) ──"
olc SESSİZ "birleştirme kancası CI'ı HER birleştirmede ölçsün (yalnız FABRIKA_KAPISIZ kaçışında değil): kırmızı, beklemede, kontrolsüz ya da okunamayan CI → ret; -R ile başka depo birleştirilirken CI o depodan okunsun (gorev_01M506PY0B6X92R0NEK0NSPCR7 + hafta raporu E3)"
olc SESSİZ "denetçi ölçüm çıktısını keserken sonunu da versin: 60 satırı aşan ölçüm dosyasında baş + atlanan satır sayısı + stdout'un son satırları (sonuç satırı) + stderr'in sonu; kısa dosya aynen; fabrika 0.10.6 (gorev_01M5890SCNMSR4DFTGHVWEJEC3, retro W42 HENDESE Ö1)"
olc SESSİZ "kart.sh ac iş cümlesinde iki depo görürse uyarsın (retro W42 ders M2)"
olc SESSİZ "hafta kapısı D13 PR gövdesinde retro işaretini arasın"
olc SESSİZ "W42 retrosu için kutu dosyasını doldur"
echo "── gerçek çok günlük kapsam (uyarmaya devam etmeli) ──"
olc UYARIR "HENDESE kütüphanesi 1. hafta: günlük tur kayıtları (depo/web/video) + örnek vaka kartları, kaynaklı"
olc UYARIR "W42 boyunca her gün tur kaydı"
olc UYARIR "haftalık rapor üretimi kur ve her gün koştur"
olc UYARIR "bu hafta tüm kutuların retrosunu topla"
olc UYARIR "3 gün sürecek göç"
echo "toplam $n · yanlış $yanlis"
