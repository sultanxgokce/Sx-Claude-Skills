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

echo "B9 sabah özeti: dünkü kuyruk tek WhatsApp mesajı, gidince işlenir"
T4="$(mktemp -d)"
cat > "$T4/wa" <<EOW
#!/usr/bin/env bash
echo CAGRI >> "$T4/cagri.log"; printf '%s\n' "\$*" >> "$T4/metin.log"; exit "\${WA_RC:-0}"
EOW
chmod +x "$T4/wa"; : > "$T4/cagri.log"
cagri(){ grep -c CAGRI "$T4/cagri.log" || true; }
B9(){ SULTAN_BUTCE_DIZIN="$T4" SULTAN_BUTCE_WA="$T4/wa" SULTAN_BUTCE_SIMDI="${SIM9:-$S0}" bash "$B" "$@" >"$T4/out" 2>&1; echo $?; }
for i in 1 2 3 4; do B9 harca --tur kart --ad "s$i" --sahip A >/dev/null; done; B9 harca --tur onay --ad s5 --sahip BERID >/dev/null
B9 sabah >/dev/null; ok "aynı gün sabah özeti göndermez (yalnız dünkü)" "$(cagri)" 0
SIM9=$((S0 + 86400)); ok "ertesi sabah özet gider rc 0" "$(B9 sabah)" 0
ok "tek mesaj gitti" "$(cagri)" 1
ok "mesaj s5'i taşır" "$(grep -c 's5' "$T4/metin.log")" 1
ok "işlendi: kuyruk boş" "$(SULTAN_BUTCE_DIZIN="$T4" SULTAN_BUTCE_SIMDI=$SIM9 bash "$B" ozet | grep -c 'kuyrukta istek yok')" 1
B9 sabah >/dev/null; ok "ikinci koşu mesaj atmaz" "$(cagri)" 1
for i in 7 8 9 10 11; do B9 harca --tur kart --ad "s$i" --sahip A >/dev/null; done
SIM9=$((S0 + 2*86400)); ok "geçit düşerse rc 3" "$(WA_RC=4 B9 sabah)" 3
ok "gitmeyen özet kuyruğu korur" "$(SULTAN_BUTCE_DIZIN="$T4" SULTAN_BUTCE_SIMDI=$SIM9 bash "$B" ozet --onceki | grep -c 's11')" 1
python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T4"

echo "geçti=$GEC kaldı=$KAL"; [ "$KAL" -eq 0 ]
