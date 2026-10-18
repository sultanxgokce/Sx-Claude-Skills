#!/usr/bin/env bash
# bekci-gecikme.test.sh — dakikalık bekçi satırı kutuya özgü SABİT gecikmeyle yazılır (hermetik).
#
# Niçin (18 Eki 2026, kart terminal-onar-bekci-gecikme · SERDAR 15:28): 17 kutunun bekçisi her dakikanın :00'ında aynı anda
# kalkıyordu; host'ta dakika başı çalışma kuyruğu 179-191'e çıkıyordu (filo yavaşladı). Gecikme kutu adından türer
# (cksum % 50 + 5), kurulumda hesaplanır, satıra DÜZ RAKAM olarak girer (crontab'da '%' satır sonudur). Sahte crontab;
# gerçek crontab'a DOKUNULMAZ.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
mkdir -p "$T/bin" "$T/proje" "$T/durum"
CT="$T/crontab.txt"
printf '#!/usr/bin/env bash\ncase "$1" in -l) cat "%s" 2>/dev/null;; -) cat > "%s";; esac\nexit 0\n' "$CT" "$CT" > "$T/bin/crontab"
chmod +x "$T/bin/crontab"
# ortak.sh PATH'in başına /usr/bin koyar → sahteler kopyanın sonunda öne alınır (bekci-iz.test.sh dersi)
M="$T/calisma"; mkdir -p "$M"; cp -r "$KOK/scripts" "$M/"
printf '\nexport PATH="$TO_SAHTE_BIN:$PATH"\n' >> "$M/scripts/ortak.sh"
kos() { # $1 kutu · $2 kabuk kodu (ortak.sh kaynaklanır) · $3 beceri kökü (vars. çalışma kopyası)
  env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU="$1" TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" \
    TO_CRONTAB="$T/bin/crontab" TO_BECERI_KOK="${3:-$M}" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" \
    bash -c ". \"\$TO_BECERI_KOK/scripts/ortak.sh\" >/dev/null 2>&1; $2"
}
gecikme() { kos "$1" 'printf %s "$BEKCI_SATIR"' "${2:-$M}" | sed -nE 's/^\* \* \* \* \* sleep ([0-9]+) && .*/\1/p'; }

echo "── G formül: kutu adından sabit gecikme, satıra düz rakam"
kapi "G1 code → 10 sn (cloudtop crontab-abc ile aynı sayı)" "10" "$(gecikme code)"
kapi "G1b akar → 7 · huma → 33 · nova → 5" "7 33 5" "$(gecikme akar) $(gecikme huma) $(gecikme nova)"
kapi "G1c aynı kutu iki kurulumda aynı sayı (rastgele değil)" "$(gecikme mihenk)" "$(gecikme mihenk)"
B="$(kos code 'printf %s "$BEKCI_SATIR"')"
kapi "G2 satırda '%' YOK (crontab'da satır sonu demektir)" "0" "$(printf '%s' "$B" | grep -c '%')"
kapi "G2b önek 'sleep N && ' (';' değil: canlılık envanteri ilk ';'den keser)" "1" "$(printf '%s' "$B" | grep -cE '^\* \* \* \* \* sleep [0-9]+ && if \[ -x ')"
kapi "G2c satır işaretle bitiyor (bekci_kurulu eşleşir)" "0" "$(kos code 'bekci_kurulu; echo $?' >/dev/null; printf '%s\n' "$B" > "$CT"; kos code 'bekci_kurulu; echo $?')"

echo "── G 17 kutu: aralık ve dağılım"
KUTULAR="akar enis huma huzur maiset medigate menzil mihenk mmex nazir nova revak sedir tellal tez vekatip code"
sayilar=""; for k in $KUTULAR; do sayilar="$sayilar $(gecikme "$k")"; done
kapi "G3 17 kutunun hepsinde sayı var" "17" "$(printf '%s\n' $sayilar | grep -c .)"
kapi "G3b hepsi 5-54 sn aralığında" "0" "$(printf '%s\n' $sayilar | awk '$1<5 || $1>54' | grep -c .)"
kapi "G3c tek saniyede en çok 2 kutu (eskiden 17'si :00'da)" "1" "$(printf '%s\n' $sayilar | sort | uniq -c | awk '{ if ($1>m) m=$1 } END { print (m<=2) }')"

echo "── G eski gecikmesiz satır kurulumda yenisine çevrilir"
ESKI="* * * * * $(kos code '_cron_komut bekci.sh')  # terminal-onar-bekci"
printf 'PATH=/usr/bin:/bin\n%s\n0 3 * * * echo gece\n' "$ESKI" > "$CT"
out="$(kos code 'bekci_kur "$TO_PROJE/.oda/cron" canli')"
kapi "G4 eski satır kalmadı" "0" "$(grep -cxF -- "$ESKI" "$CT")"
kapi "G4b yeni (gecikmeli) satır TEK" "1" "$(grep -cxF -- "$B" "$CT")"
kapi "G4c öteki satırlar korundu" "2" "$(grep -cE '^(PATH=|0 3 )' "$CT")"
kapi "G4d 'canlı crontab düzeltildi' dedi" "1" "$(printf '%s' "$out" | grep -c 'canlı crontab düzeltildi')"
out="$(kos code 'bekci_kur "$TO_PROJE/.oda/cron" canli')"
kapi "G4e ikinci kurulum hiçbir şey değiştirmez (kararlı)" "0" "$(printf '%s' "$out" | grep -c 'canlı crontab düzeltildi')"
kapi "G5 açılış satırı gecikme önekini ALMADI" "1" "$(grep -cE '^@reboot sleep 15; .*# terminal-onar-acilis$' "$T/proje/.oda/cron")"

echo "── mutasyon (kopya üstünde)"
mut() { # $1 ad · $2 sed · $3 ısırması beklenen kapı (0 = geçti → mutant yaşıyor)
  local MM="$T/mut"; python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$MM"; cp -r "$M" "$MM"
  sed -i "$2" "$MM/scripts/ortak.sh"
  if cmp -s "$MM/scripts/ortak.sh" "$M/scripts/ortak.sh"; then kalan=$((kalan+1)); echo "  ✗ $1: sed hiçbir şeyi değiştirmedi"; return; fi
  if eval "$3"; then kalan=$((kalan+1)); echo "  ✗ $1: mutant YAŞIYOR"; else gecen=$((gecen+1)); echo "  ✓ $1: mutant ısırıldı"; fi
}
mut "M1 gecikme öneki yok (eski satır)" 's/sleep \$BEKCI_GECIKME && //' '[ "$(gecikme code "$T/mut")" = 10 ]'
mut "M2 '&&' yerine ';'" 's/sleep \$BEKCI_GECIKME && /sleep $BEKCI_GECIKME; /' \
  'kos code "printf %s \"\$BEKCI_SATIR\"" "$T/mut" | grep -qE "^\* \* \* \* \* sleep [0-9]+ && "'
mut "M3 formül kutu adını kullanmıyor (her kutu aynı saniye)" 's/printf .%s. "\$KUTU" | cksum/printf x | cksum/' \
  '[ "$(gecikme akar "$T/mut") $(gecikme huma "$T/mut")" = "7 33" ]'

echo; echo "GECEN=$gecen DUSEN=$kalan"
[ "$kalan" -eq 0 ]
