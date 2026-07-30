#!/usr/bin/env bash
# argmax.test.sh — büyük gövde gerçekten gidiyor mu, ve düşerse doğru sebebi mi söylüyor?
#
# NİÇİN VAR: gövde komut satırı argümanı olarak veriliyordu; ~230 KB'ta kabuğun ARG_MAX
# sınırı aşılıyor, curl exec() aşamasında rc=126 ile ölüyor, script bunu AĞ hatası sanıp
# "geçide ulaşılamıyor" diyordu. Geçit ayaktaydı — yanlış teşhis kullanıcıyı saatlerce
# yanlış yere baktırdı (cloudtop-tez, 2026-07-30, 44 sayfalık PDF).
#
# Yöntem: gerçek geçit çağrılmaz. PATH'e sahte bir `curl` konur; o curl argümanlarını ve
# ARG_MAX'ı GERÇEKÇE taklit eder — argüman uzunluğu eşiği aşarsa 126 döner.
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$BURASI/wa-gonder.sh"
gecici="$(mktemp -d -t argmax-XXXXXX)"
temizle() { [ -d "$gecici" ] && find "$gecici" -mindepth 1 -delete 2>/dev/null; rmdir "$gecici" 2>/dev/null; }
trap temizle EXIT
gecen=0; kalan=0
g() { if [ "$1" = 0 ]; then echo "  ✓ $2"; gecen=$((gecen+1)); else echo "  ✗ $2"; kalan=$((kalan+1)); fi; }

mkdir -p "$gecici/bin"
# Sahte curl: tüm argümanları uzunluk olarak ölçer. SAHTE_ARGMAX'ı aşarsa gerçek kabuğun
# yaptığını yapar (rc=126, hiç çalışmadan). Aşmazsa 200 basar ve gövdeyi kaydeder.
cat > "$gecici/bin/curl" <<'C'
#!/usr/bin/env bash
hepsi="$*"
if [ "${#hepsi}" -gt "${SAHTE_ARGMAX:-100000}" ]; then exit 126; fi
printf '%s' "$hepsi" > "$ARG_LOG"
# -d @dosya verildiyse gövde boyutunu da kaydet (gerçekten dosyadan mı okunuyor?)
for a in "$@"; do case "$a" in @*) wc -c < "${a#@}" > "$GOVDE_BOYUT" 2>/dev/null ;; esac; done
printf '200'
C
chmod +x "$gecici/bin/curl"

echo "── Büyük gövde: argüman listesi ŞİŞMEMELİ ──"
# ⚠ Gövdeyi iç kabuğa ARGÜMAN olarak geçirmiyoruz — bu testin ilk hâli tam o yüzden
# "Argument list too long" ile düştü, yani test kendi ölçtüğü bug'a düştü. Dosyadan okutuyoruz.
head -c 250000 /dev/zero | tr '\0' 'A' > "$gecici/buyuk.txt"
ARG_LOG="$gecici/arg.txt" GOVDE_BOYUT="$gecici/boyut.txt" SAHTE_ARGMAX=100000 \
  BUYUK_DOSYA="$gecici/buyuk.txt" PATH="$gecici/bin:$PATH" \
  bash -c '
    YANIT="'"$gecici"'/yanit"; GECIT="http://sahte"
    source <(sed -n "/^_cagir()/,/^}/p" "'"$S"'")
    govde="$(cat "$BUYUK_DOSYA")"
    kod="$(_cagir /gonder "$govde" 2>"'"$gecici"'/err.txt")"; echo "$kod" > "'"$gecici"'/kod.txt"
  '
[ "$(cat "$gecici/kod.txt")" = "200" ]; g $? "250 KB gövde GİTTİ (eskiden rc=126 ile ölüyordu)"
[ "$(wc -c < "$gecici/arg.txt")" -lt 500 ]; g $? "argüman listesi küçük kaldı ($(wc -c < "$gecici/arg.txt") bayt)"
[ "$(tr -d ' ' < "$gecici/boyut.txt" 2>/dev/null)" = "250000" ]; g $? "gövde dosyadan okundu, tam boyut (250000)"
grep -q '@' "$gecici/arg.txt"; g $? "curl '-d @dosya' biçimiyle çağrıldı"

echo "── Geçici dosya arkada bırakılmıyor ──"
[ "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'wa-govde.*' 2>/dev/null | wc -l)" = 0 ]
g $? "wa-govde.* geçici dosyası kalmadı"

echo "── Düşerse DOĞRU sebebi söylüyor (ölçemedim ≠ ulaşamadım) ──"
cat > "$gecici/bin/curl" <<'C'
#!/usr/bin/env bash
exit "${SAHTE_RC:-1}"
C
chmod +x "$gecici/bin/curl"
dene() { # rc → stderr metni
  SAHTE_RC="$1" bash -c '
    YANIT="'"$gecici"'/yanit"; GECIT="http://sahte"
    source <(sed -n "/^_cagir()/,/^}/p" "'"$S"'")
    _cagir /gonder "kisa" 2>&1 >/dev/null
  ' 2>&1
}
PATH="$gecici/bin:$PATH"
printf '%s' "$(dene 126)" | grep -q 'ağ hatası DEĞİL'; g $? "rc=126 → 'ağ hatası değil' diyor"
printf '%s' "$(dene 28)"  | grep -q 'zaman aşımı';     g $? "rc=28 → zaman aşımı diyor"
printf '%s' "$(dene 7)"   | grep -q 'ulaşılamadı';     g $? "rc=7 → geçide ulaşılamadı diyor"
# Sözleşme korunuyor: her hâlde "000" basılır (çağıranlar buna bakıyor).
k="$(SAHTE_RC=126 bash -c '
  YANIT="'"$gecici"'/yanit"; GECIT="http://sahte"
  source <(sed -n "/^_cagir()/,/^}/p" "'"$S"'")
  _cagir /gonder "kisa" 2>/dev/null')"
[ "$k" = "000" ]; g $? "sözleşme korundu: düşünce yine '000' (çağıranlar kırılmadı)"

echo ""
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" = 0 ] || exit 1
