#!/usr/bin/env bash
# butce.test.sh — butce.sh sınavı. Gerçek ~/.cache'e DOKUNMAZ (SULTAN_BUTCE_DIZIN geçici).
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/butce.sh"
T="$(mktemp -d)"; trap 'python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"' EXIT
export SULTAN_BUTCE_DIZIN="$T"
GEC=0; KAL=0
ok(){ if [ "$2" = "$3" ]; then GEC=$((GEC+1)); echo "  ✓ $1"; else KAL=$((KAL+1)); echo "  ✗ $1 (beklenen=$3 gelen=$2)"; fi; }
S0=1793900000   # sabit an
run(){ SULTAN_BUTCE_SIMDI="${SIM:-$S0}" bash "$B" "$@" >"$T/out" 2>&1; echo $?; }

echo "B1 dört istek geçer, beşinci kuyruğa"
for i in 1 2 3 4; do ok "istek $i geçti" "$(run harca --tur kart --ad "k$i" --sahip BENNA)" 0; done
ok "beşinci rc 10" "$(run harca --tur onay --ad k5 --sahip BENNA)" 10
ok "kuyruk metni sahibine 'KUYRUKTA' der" "$(grep -c 'KUYRUKTA' "$T/out")" 1
ok "kuyruk metni 09:00 der" "$(grep -c '09:00' "$T/out")" 1

echo "B2 aynı tür+ad ikinci kez düşmez"
ok "k1 tekrar geçer" "$(run harca --tur kart --ad k1 --sahip BENNA)" 0
ok "durumda hâlâ 4/4" "$(SULTAN_BUTCE_SIMDI=$S0 bash "$B" durum | grep -c 'istek 4/4')" 1
ok "k5 tekrar yine kuyruk" "$(run harca --tur onay --ad k5 --sahip BENNA)" 10

echo "B3 acil: bütçe dolu olsa da geçer, günde 1"
ok "acil 1 geçti" "$(run acil --ad "hat durdu" --sahip SERDAR)" 0
ok "acil 2 kuyruk" "$(run acil --ad "başka kesinti" --sahip SERDAR)" 10
ok "acil istek sayacını artırmadı" "$(SULTAN_BUTCE_SIMDI=$S0 bash "$B" durum | grep -c 'istek 4/4 · acil 1/1')" 1

ok "aynı acil adı ikinci kez hak düşer, kuyruk" "$(run acil --ad "hat durdu" --sahip SERDAR)" 10

echo "B4 ertesi gün sayaç sıfırlanır (İstanbul günü)"
SIM=$((S0 + 86400)); ok "ertesi gün yeni istek geçer" "$(run harca --tur soru --ad yeni --sahip BENNA)" 0; unset SIM
echo "B5 gün sınırı İstanbul'a göre (UTC değil)"
TZ_GUN="$(TZ=Europe/Istanbul date -d "@$S0" +%F)"
# İstanbul gece yarısından hemen önce ve sonra: iki farklı gün sayılmalı
G0="$(TZ=Europe/Istanbul date -d "$TZ_GUN 23:59:00" +%s)"; G1="$(TZ=Europe/Istanbul date -d "$TZ_GUN 00:01:00 +1 day" +%s)"
T2="$(mktemp -d)"
for i in 1 2 3 4; do SULTAN_BUTCE_DIZIN="$T2" SULTAN_BUTCE_SIMDI=$G0 bash "$B" harca --tur kart --ad "g$i" --sahip X >/dev/null 2>&1; done
ok "23:59 beşinci kuyruk" "$(SULTAN_BUTCE_DIZIN="$T2" SULTAN_BUTCE_SIMDI=$G0 bash "$B" harca --tur kart --ad g5 --sahip X >/dev/null 2>&1; echo $?)" 10
ok "00:01 yeni gün geçer" "$(SULTAN_BUTCE_DIZIN="$T2" SULTAN_BUTCE_SIMDI=$G1 bash "$B" harca --tur kart --ad g6 --sahip X >/dev/null 2>&1; echo $?)" 0
python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T2"

echo "B6 özet: kuyruğu tek metin yapar, --isle temizler"
OZ="$(SULTAN_BUTCE_SIMDI=$S0 bash "$B" ozet)"
ok "özet k5'i taşır" "$(printf '%s' "$OZ" | grep -c 'k5')" 1
ok "özet ikinci acili taşır" "$(printf '%s' "$OZ" | grep -c 'başka kesinti')" 1
SULTAN_BUTCE_SIMDI=$S0 bash "$B" ozet --isle >/dev/null
ok "isle sonrası kuyruk boş" "$(SULTAN_BUTCE_SIMDI=$S0 bash "$B" ozet | grep -c 'kuyrukta istek yok')" 1

echo "B7 girdi kapıları"
ok "bilinmeyen tür rc 2 (bilgi satırı bütçeye girmez)" "$(run harca --tur bilgi --ad x --sahip A)" 2
ok "sahip yoksa rc 2" "$(run harca --tur kart --ad x)" 2
ok "boş ad rc 2" "$(run harca --tur kart --ad "" --sahip A)" 2

echo "B8 eşzamanlı 8 istek: tam 4 geçer"
T3="$(mktemp -d)"
for i in 1 2 3 4 5 6 7 8; do ( SULTAN_BUTCE_DIZIN="$T3" SULTAN_BUTCE_SIMDI=$S0 bash "$B" harca --tur kart --ad "p$i" --sahip A >/dev/null 2>&1; echo $? >"$T3/rc$i" ) & done; wait
ok "geçen sayısı" "$(cat "$T3"/rc? | grep -c '^0$')" 4
ok "kuyruk sayısı" "$(cat "$T3"/rc? | grep -c '^10$')" 4
python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T3"

echo "geçti=$GEC kaldı=$KAL"; [ "$KAL" -eq 0 ]
