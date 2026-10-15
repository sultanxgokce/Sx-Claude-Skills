#!/usr/bin/env bash
# imar.test.sh — ⛩️ İMAR şalterinin hermetik sınavı. Gerçek DURUM.json'a ve kütüğe DOKUNMAZ.
# Kapılar: fail-closed (dosya yok → kapalı) · bozuk dosya → kapalı · ac/kapat geçişleri ·
#          cark-tur.sh kapalıyken yuva atlar · kütük her geçişte satır alır · idempotent kur.
# Çıkış: 0 hepsi geçti · 1 düşen var
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# geçici dizin: kancanın yasakladığı dizgi yerine meşru yol (bileyi/guvenli-sil.sh); araç yoksa
# 'rm -r' ile devam eder (zorlamasız, geçici dizin için yeterli) — ölçüldü 13 Ekim, bekçi sarısı kapandı.
GS="/config/.claude/skills/bileyi/scripts/guvenli-sil.sh"
if [ -r "$GS" ]; then T="$(bash "$GS" --yeni imar-sinav)"; trap 'bash "$GS" "$T" >/dev/null 2>&1' EXIT
else T="$(mktemp -d)"; trap 'rm -r "$T" 2>/dev/null' EXIT; fi
# 🔴 Profil artık ZORUNLU: imar.sh kutuya özel yolu varsayamaz (filo becerisi). Sınav da onu
#    kurar — eski sürümde IMAR_SERI varsayılanı mihenk kutusuna çiviliydi ve sınav farkına varmıyordu.
export IMAR_DURUM="$T/DURUM.json" IMAR_KUTUK="$T/kutuk.log" IMAR_KIM="sinav"
export IMAR_SERI="$T/arastirma-serisi" IMAR_KUTU="sinav-kutusu" IMAR_AJAN="SINAV"
mkdir -p "$IMAR_SERI/gunluk"
S="$REPO/scripts/imar.sh"
GEC=0; DUS=0
kapi(){ # $1 ad · $2 beklenen rc · $3.. komut
  local ad="$1" bek="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" -eq "$bek" ]; then echo "✅ $ad (rc=$rc)"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen rc=$bek, gelen rc=$rc · $out"; DUS=$((DUS+1)); fi
}
icerik(){ # $1 ad · $2 beklenen alt-dizgi · $3.. komut
  local ad="$1" bek="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -q -- "$bek"; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: '$bek' yok · $out"; DUS=$((DUS+1)); fi
}

# 1) dosya yok → ölçülemedi (3) ve cark-tur yuva atlar
kapi  "dosya yokken acik-mi=3 (fail-closed)" 3 bash "$S" acik-mi
icerik "dosya yokken cark-tur yuva atlar" "İMAR kapalı" bash "$REPO/scripts/cark-tur.sh" --kuru
# 2) bozuk dosya → 3
echo '{"acik": "evet"}' > "$IMAR_DURUM"
kapi  "bozuk dosya acik-mi=3" 3 bash "$S" acik-mi
echo 'bu json değil' > "$IMAR_DURUM"
kapi  "json olmayan dosya acik-mi=3" 3 bash "$S" acik-mi
rm -f "$IMAR_DURUM"
# 3) kur → kapalı (1); ikinci kur dokunmaz
kapi  "kur rc=0" 0 bash "$S" kur
kapi  "kur sonrası kapalı (1)" 1 bash "$S" acik-mi
bash "$S" ac >/dev/null
icerik "ikinci kur var olanı ezmez" "zaten var" bash "$S" kur
kapi  "kur sonrası hâlâ açık" 0 bash "$S" acik-mi
# 4) kapat/ac geçişleri + kütük
kapi  "kapat rc=0" 0 bash "$S" kapat --not "sınav"
kapi  "kapat sonrası acik-mi=1" 1 bash "$S" acik-mi
icerik "kapalıyken cark-tur yuva atlar" "İMAR kapalı" bash "$REPO/scripts/cark-tur.sh" --kuru
kapi  "ac rc=0" 0 bash "$S" ac
kapi  "ac sonrası acik-mi=0" 0 bash "$S" acik-mi
# açıkken cark-tur şalteri GEÇER (kota/emir satırına ulaşır — İMAR satırı YOK)
out="$(bash "$REPO/scripts/cark-tur.sh" --kuru 2>&1)"
if printf '%s' "$out" | grep -q "İMAR kapalı"; then echo "❌ açıkken cark-tur yine atladı · $out"; DUS=$((DUS+1)); else echo "✅ açıkken şalter geçildi ($out)"; GEC=$((GEC+1)); fi
# kütük: KUR + AÇ + KAPAT + AÇ = 4 satır (ikinci kur yazmaz)
N="$(grep -c -E '^\[.*\] (KUR|AÇ|KAPAT)' "$IMAR_KUTUK")"
if [ "$N" -eq 4 ]; then echo "✅ kütük 4 geçiş satırı"; GEC=$((GEC+1)); else echo "❌ kütük satır sayısı $N (beklenen 4)"; DUS=$((DUS+1)); cat "$IMAR_KUTUK"; fi
# 5) durum çalışır, bilinmeyen komut 2
kapi  "durum rc=0" 0 bash "$S" durum
kapi  "bilinmeyen komut rc=2" 2 bash "$S" sacma
# 6) negatif kontrol: şalter dosyası silinirse açık sayılmaz
rm -f "$IMAR_DURUM"
kapi  "şalter silinince yine kapalı (3)" 3 bash "$S" acik-mi

echo "— $GEC geçti · $DUS düştü"
[ "$DUS" -eq 0 ]
