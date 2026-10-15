#!/usr/bin/env bash
# imar-kur.sh — ⛩️ İMAR'ı BİR KUTUYA kurar: profili ölçer, dizinleri açar, parça parça rapor eder.
#
# NİÇİN BÖYLE: reçete "sırayla şu adımları yap" diyordu ve her adımın kabul kapısı METİNDEYDİ.
# Metindeki kapı koşmaz. Bu betik aynı adımları KOŞAR ve her birinin sonucunu basar; ölçemediğine
# yeşil demez.
#
# 🔴 ŞALTER KAPALI DOĞAR. Kurulum hiçbir şeyi çalıştırmaz, yalnız kurar.
#
# Kullanım: imar-kur.sh <profil.json> [--kuru]
# rc: 0 kuruldu · 1 profil/kurulum kusuru · 3 ölçülemedi
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFIL="${1:-}"; KURU=0
[ "${2:-}" = "--kuru" ] && KURU=1
[ -n "$PROFIL" ] || { echo "kullanım: imar-kur.sh <profil.json> [--kuru]" >&2; exit 1; }

echo "⛩️  İMAR kurulumu · profil: $PROFIL${KURU:+ (kuru koşu)}"

# 1 · profil — ölçülmeden hiçbir dizin açılmaz
if ! python3 "$HERE/imar-profil.py" dogrula "$PROFIL"; then
  echo "✗ kurulum DURDU: profil geçerli değil (yukarıdaki kusurlar)" >&2; exit 1
fi
COZUM="$(python3 "$HERE/imar-profil.py" cozumle "$PROFIL")" || { echo "✗ profil çözülemedi" >&2; exit 3; }
eval "$COZUM"
echo "  ✓ profil geçerli · kutu=$IMAR_KUTU ajan=$IMAR_AJAN"

# 2 · dizinler
DIZINLER=("$(dirname "$IMAR_DURUM")" "$(dirname "$IMAR_KUTUK")" "$(dirname "$IMAR_MEZARLIK")" "$IMAR_SERI" "$IMAR_SERI/gunluk")
for d in "${DIZINLER[@]}"; do
  if [ "$KURU" = 1 ]; then echo "  · (kuru) açılacak: $d"; continue; fi
  mkdir -p "$d" 2>/dev/null && echo "  ✓ dizin: $d" || { echo "  ✗ dizin açılamadı: $d" >&2; exit 1; }
done

# 3 · şalter KAPALI doğar
if [ "$KURU" = 1 ]; then echo "  · (kuru) şalter KAPALI doğacak"; else
  if IMAR_REPO="$IMAR_REPO" IMAR_DURUM="$IMAR_DURUM" IMAR_KUTUK="$IMAR_KUTUK" IMAR_SERI="$IMAR_SERI" \
     bash "$HERE/imar.sh" kur >/dev/null 2>&1; then echo "  ✓ şalter kuruldu (KAPALI doğdu)"
  else echo "  ✗ şalter kurulamadı" >&2; exit 1; fi
  if IMAR_REPO="$IMAR_REPO" IMAR_DURUM="$IMAR_DURUM" IMAR_KUTUK="$IMAR_KUTUK" IMAR_SERI="$IMAR_SERI" \
     bash "$HERE/imar.sh" acik-mi >/dev/null 2>&1; then
    echo "  ✗ şalter AÇIK doğdu — değişmez ihlali (kapalı doğmalıydı)" >&2; exit 1
  else echo "  ✓ şalter kapalı doğdu (değişmez)"; fi
fi

# 4 · Bulgu Defteri — yoksa hâl zinciri ÖLÇÜLEMEDİ der, uydurmaz
if [ -f "$IMAR_DEFTER_YAZ" ]; then echo "  ✓ Bulgu Defteri yazıcısı: $IMAR_DEFTER_YAZ"
else echo "  ⏭️  Bulgu Defteri yazıcısı YOK ($IMAR_DEFTER_YAZ) — hâl zinciri ve fikir kapısı ÖLÇÜLEMEDİ der, uydurmaz"; fi

# 5 · alarm — cihaz teyidi profilde zorunlu, burada yalnız HATIRLATILIR
echo "  ✓ alarm konusu beyan edildi · cihaz teyidi: $IMAR_ALARM_TEYIT"
echo "     🔴 'geçit 200 döndü' alarmın çalıştığını kanıtlamaz; teyit Sultan'ın cümlesidir."

# 6 · zamanlayıcı satırı ÜRETİLİR, kurulmaz (kalıcı değişiklik → Sultan onayı)
echo
echo "  Zamanlayıcı satırı (crontab'a SULTAN ONAYIYLA eklenir — bu betik crontab'a DOKUNMAZ):"
echo "    0 8,13,18 * * * flock -n /tmp/cark-yuva.lock env CARK_KAYNAK=cron IMAR_PROFIL=$PROFIL bash $HERE/cark-tur.sh >> $(dirname "$IMAR_KUTUK")/cark-kosu.log 2>&1  # cark-tur"
echo
echo "  Sonraki adım: KONU.md gerekçeli yazılır → /imar-ac (Sultan kararı)."
echo "✓ kurulum bitti · şalter KAPALI"
