#!/usr/bin/env bash
# kapi-eski-mi.test.sh — kapı süreci ⟷ kod dosyası yaşı karşılaştırması GERÇEK node süreciyle ölçülür (sahte yok; ağ/tmux yok).
#   E1 dosyalar süreçten ESKİ → rc 0 "güncel" · E2 sunucu.mjs süreçten sonra değişti → rc 1, dosya adı + onar.sh komutu basılır
#   E3 yalnız *.test.mjs yeni → rc 0 (test dosyası kapı kodu değil) · E4 süreç yok → rc 2 ÖLÇÜLEMEDİ (yeşil değil) · MUTANT: karşılaştırma ters → E1/E2 kırmızı
# ÖLÇÜM: 2026-10-28 10:45 — gerçek node süreci + touch ile dosya yaşı, hermetik geçici kök
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); mkdir -p "$T/calisma/kapi" "$T/durum"; PID=""
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null; rm -r -- "$T"' EXIT
cp -r "$KOK/scripts" "$T/calisma/"
printf 'setInterval(function(){}, 1000);\n' > "$T/calisma/kapi/sunucu.mjs"
printf 'export const x = 1;\n' > "$T/calisma/kapi/yol.mjs"
printf 'export const t = 1;\n' > "$T/calisma/kapi/yol.test.mjs"
touch -d '2 hours ago' "$T/calisma/kapi/sunucu.mjs" "$T/calisma/kapi/yol.mjs" "$T/calisma/kapi/yol.test.mjs"
kos() { env -i PATH="/usr/bin:/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T" TO_DURUM_DIZ="$T/durum" TO_BECERI_KOK="$T/calisma" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" bash "${1:-$T/calisma/scripts/kapi-eski-mi.sh}" 2>&1; }

echo "── E4 süreç yok → ÖLÇÜLEMEDİ"
c=$(kos); r=$?; kapi "E4 kapı süreci yok → rc 2 ve 'ÖLÇÜLEMEDİ'" "2/1" "$r/$(echo "$c" | grep -c 'ÖLÇÜLEMEDİ')"

node "$T/calisma/kapi/sunucu.mjs" >/dev/null 2>&1 & PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -u "$(id -u)" -f "node $T/calisma/kapi/sunucu.mjs" >/dev/null && break; sleep 0.3; done
sleep 2
echo "── E1 dosyalar süreçten eski"
c=$(kos); r=$?; kapi "E1 kod dosyaları süreçten eski → rc 0 'kapı güncel'" "0/1" "$r/$(echo "$c" | grep -c 'kapı güncel')"
echo "── E3 yalnız test dosyası yeni"
touch "$T/calisma/kapi/yol.test.mjs"
c=$(kos); r=$?; kapi "E3 yalnız *.test.mjs süreçten yeni → rc 0 (kapı kodu sayılmaz)" "0" "$r"
echo "── E5 pano.js (sıcak tazelenen) süreçten yeni → kapı ESKİ sayılmaz"
sleep 1; printf 'var pano = 1;\n' > "$T/calisma/kapi/pano.js"   # süreç başlayalı >3 sn: dosya GERÇEKTEN süreçten yeni (aynı-saniye muğlaklığı yok)
c=$(kos); r=$?; kapi "E5 yalnız pano.js (+ test dosyası) yeni → rc 0 (pano.js kod yaşına girmez)" "0" "$r"
echo "── E2 sunucu.mjs süreçten sonra değişti"
sleep 1; touch "$T/calisma/kapi/sunucu.mjs"
c=$(kos); r=$?; kapi "E2 sunucu.mjs süreçten yeni → rc 1 · dosya adı ve onar.sh komutu basılır" "1/1/1" "$r/$(echo "$c" | grep -c 'sunucu.mjs')/$(echo "$c" | grep -c 'onar.sh --web-yenile')"

echo "── MUTANT: karşılaştırma ters ('-gt' → '-lt') → E1/E2 kırmızıya dönmeli"
sed 's/\[ "\$dosya_an" -gt "\$basla" \]/[ "$dosya_an" -lt "$basla" ]/' "$T/calisma/scripts/kapi-eski-mi.sh" > "$T/calisma/scripts/kapi-eski-mi-mutant.sh"
grep -q -- '-lt "\$basla"' "$T/calisma/scripts/kapi-eski-mi-mutant.sh" || { kalan=$((kalan+1)); echo "  ✗ mutant üretilemedi (çapa tutmadı)"; }
cm=$(kos "$T/calisma/scripts/kapi-eski-mi-mutant.sh"); rm_=$?
kapi "MUTANT ters karşılaştırma E2 senaryosunda rc 1 VERMEZ (sınav kırmızıya dönerdi — mutant yakalandı)" "yakalandi" "$([ "$rm_" != 1 ] && echo yakalandi || echo kacti)"

# M2: pano.js dışlaması kalkarsa ('*.mjs' → '*.mjs' VEYA '*.js') E5 senaryosunda ölçer yanlış 'ESKİ' der → sınav kırmızıya dönmeli
rm -f "$T/calisma/kapi/sunucu-yeni" ; touch -d '2 hours ago' "$T/calisma/kapi/sunucu.mjs"
sed "s/-name '\*.mjs'/\\( -name '*.mjs' -o -name '*.js' \\)/" "$T/calisma/scripts/kapi-eski-mi.sh" > "$T/calisma/scripts/kapi-eski-mi-m2.sh"
grep -q -- "-o -name '\*.js'" "$T/calisma/scripts/kapi-eski-mi-m2.sh" || { kalan=$((kalan+1)); echo "  ✗ M2 mutantı üretilemedi (çapa tutmadı)"; }
cm2=$(kos "$T/calisma/scripts/kapi-eski-mi-m2.sh"); rm2=$?
kapi "MUTANT M2 pano.js dışlaması kalkınca E5 senaryosunda ölçer rc 0 VERMEZ (sınav kırmızıya dönerdi — mutant yakalandı)" "yakalandi" "$([ "$rm2" != 0 ] && echo yakalandi || echo kacti)"

echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
