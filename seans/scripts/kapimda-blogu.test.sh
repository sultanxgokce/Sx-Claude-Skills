#!/usr/bin/env bash
# kapimda-blogu.test.sh — karşılama ekranının "kapında N iş var" bloğunu hermetik sınar.
#
# Kritik kapı G2: kart VARKEN blok ÇİZİLİYOR mu. Bu, bloğun var olma sebebidir —
# 2026-07-31'de `kapimda.md` kuruldu ama hiçbir çağıranı yoktu (grep → 0), yani
# dosya vardı ve Sultan onu hiç görmüyordu ("yapılmış ama bağlanmamış iş").
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/basla"
gecti=0; dustu=0
ok()   { echo "PASS  $1"; gecti=$((gecti+1)); }
kotu() { echo "FAIL  $1"; dustu=$((dustu+1)); }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Fonksiyonu tek başına koşturmak için: script'i source etmeden ilgili bloğu ayıkla.
# (basla bir menü döngüsü çalıştırır → tümünü source etmek asılır.)
ayikla() {
  sed -n '/^_kapimda_blogu() {/,/^}/p' "$SUT"
}
kos() {
  KAPIMDA_DOSYA="$1" bash -c "
    C_SAR=''; C_SIF=''; C_SOL=''
    $(ayikla)
    _kapimda_blogu
  "
}

# ── G1: dosya YOK → tek kelime etmez (yokluk ≠ arıza)
cikti="$(kos "$T/hic-yok.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "G1a dosya yok → exit 0" || kotu "G1a exit=$rc"
[ -z "$cikti" ] && ok "G1b dosya yokken SESSİZ" || kotu "G1b boşuna konuştu: $cikti"

# ── G2: kart VAR → blok çiziliyor (bloğun VAR OLMA sebebi)
cat > "$T/dolu.md" <<'EOF'
# başlık
🚦 SENDE · Birinci Kart
gövde satırı, ekrana ÇIKMAMALI
🚦 SENDE · İkinci Kart
EOF
cikti="$(kos "$T/dolu.md" 2>&1)"
grep -q "kapında 2 iş var" <<<"$cikti" && ok "G2a sayı doğru basıldı" || kotu "G2a sayı yok: $cikti"
grep -q "Birinci Kart" <<<"$cikti" && ok "G2b kart başlığı basıldı" || kotu "G2b başlık yok"
grep -q "İkinci Kart"  <<<"$cikti" && ok "G2c ikinci başlık basıldı" || kotu "G2c ikinci yok"
grep -q "ekrana ÇIKMAMALI" <<<"$cikti" && kotu "G2d gövde sızdı — yalnız başlık basılmalı" || ok "G2d gövde sızmıyor"

# ── G3: 3 kart tavanı + "+N daha"
{ for i in 1 2 3 4 5; do echo "🚦 SENDE · Kart$i"; done; } > "$T/bes.md"
cikti="$(kos "$T/bes.md" 2>&1)"
[ "$(grep -c '•' <<<"$cikti")" -eq 3 ] && ok "G3a en fazla 3 kart çizildi" || kotu "G3a tavan aşıldı: $(grep -c '•' <<<"$cikti")"
grep -q "+2 daha" <<<"$cikti" && ok "G3b artan sayı bildirildi" || kotu "G3b '+2 daha' yok"
grep -q "kapında 5 iş var" <<<"$cikti" && ok "G3c toplam sayı gerçeği söylüyor" || kotu "G3c toplam yanlış"

# ── G4: BAŞKASINDA olan iş kapıda SAYILMAZ (yanlış-yük panzehiri)
cat > "$T/baskasinda.md" <<'EOF'
⏸️ BAŞKASINDA · Devredilen İş
🚦 SENDE · Gerçek İş
EOF
cikti="$(kos "$T/baskasinda.md" 2>&1)"
grep -q "kapında 1 iş var" <<<"$cikti" && ok "G4a yalnız SENDE sayıldı" || kotu "G4a sayım yanlış: $cikti"
grep -q "Devredilen" <<<"$cikti" && kotu "G4b başkasındaki iş kapıda gösterildi" || ok "G4b başkasındaki iş gösterilmiyor"

# ── G5: kartsız dosya → sessiz
printf '# yalnız başlık\nhiç kart yok\n' > "$T/bos.md"
cikti="$(kos "$T/bos.md" 2>&1)"
[ -z "$cikti" ] && ok "G5 kartsız dosyada SESSİZ" || kotu "G5 boşuna konuştu: $cikti"

echo; echo "── SONUÇ: $gecti geçti · $dustu kaldı ──"
[ "$dustu" -eq 0 ]
