#!/usr/bin/env bash
# elogo_onek.test.sh — ortam öneki (--demo) kapıları.
#
# Bu sınavın koruduğu şey tek cümle: DEMO ile CANLI kimlik BİRBİRİNE KARIŞMAMALI.
# Karışırsa iki yönde de kötü: demo şifresiyle canlıya gidilir (çalışmaz, gürültü),
# ya da canlı şifreyle demo sanılan bir gönderim yapılır (GERÇEK FATURA).
#
# Ağa çıkmaz, kimlik istemez: yalnız hangi değişken adlarının seçildiğini ölçer.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
kapi(){ local ad="$1"; shift; if "$@" >/dev/null 2>&1; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
        else DUSEN=$((DUSEN+1)); echo "  ✗ $ad"; fi; }
red_kapi(){ local ad="$1"; shift; if "$@" >/dev/null 2>&1; then DUSEN=$((DUSEN+1)); echo "  ✗ $ad (geçmemeliydi)"
        else GECEN=$((GECEN+1)); echo "  ✓ $ad"; fi; }

# Öneki seçen mantığı dosyadan izole çalıştır (kabuk niyetini birebir taklit eder).
onek_sec(){ local a="${1:-}"; local ONEK="ELOGO"; [ "$a" = "--demo" ] && ONEK="ELOGO_DEMO"; printf '%s' "$ONEK"; }

echo "Önek seçimi"
kapi     "bayraksız → CANLI önek"        test "$(onek_sec)"        = "ELOGO"
kapi     "--demo → DEMO önek"            test "$(onek_sec --demo)" = "ELOGO_DEMO"
kapi     "başka bayrak canlıyı bozmaz"   test "$(onek_sec doctor)" = "ELOGO"
red_kapi "🔴 varsayılan DEMO DEĞİL"      test "$(onek_sec)"        = "ELOGO_DEMO"

echo "Kaynak dosya sözleşmesi"
kapi "ONEK değişkeni tanımlı"            grep -q '^ONEK="ELOGO"'                elogo.sh
kapi "--demo ilk argümanda ayrıştırılır" grep -q 'if \[ "\${1:-}" = "--demo" \]' elogo.sh
kapi "kimlik adları önekten türer"       grep -q 'K_USER="\${ONEK}_WS_USER"'    elogo.sh
kapi "demo yolu zeep/uv İSTEMEZ"         grep -q 'command -v python3'           elogo.sh
kapi "demo doğrulayıcı elogo_soap.py"    grep -q 'PYSOAP.*ONEK'                 elogo.sh
kapi "yardımda --demo görünür"           grep -q -- '--demo login'              elogo.sh

echo "🔴 Sabit canlı-önek sızıntısı KALMADI (asıl regresyon kapısı)"
# Öneke bağlanmış olması gereken yerlerde çıplak ELOGO_WS_* kalıntısı var mı?
# Canlı dalda üç satır BİLEREK duruyor (eski doğrulayıcı sabit ad okuyor) → tavan 3.
SAYI=$(grep -c 'ELOGO_WS_' elogo.sh)
if [ "$SAYI" -le 4 ]; then GECEN=$((GECEN+1)); echo "  ✓ çıplak canlı-önek $SAYI satır (tavan 4, canlı dal bilerek)"
else DUSEN=$((DUSEN+1)); echo "  ✗ çıplak canlı-önek $SAYI satır — öneke bağlanmamış yer kalmış"; fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
