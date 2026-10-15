#!/usr/bin/env bash
# pr-kip-olc.test.sh — ölçüm aracının kendi sınavı.
#
# NİÇİN ÇİFT YÖNLÜ: bu araç bir kapıyı GEVŞETMEK için yazıldı (yalnız-kip PR'ı artık iş
# alanını bloklamayacak). Gevşetme en kolay sahte-yeşil üretme yoludur; o yüzden sınav
# ağırlığını "ne zaman GEVŞEMEMELİ" tarafına koyar: rename · silme · binary · tanınmayan hâl
# hepsi ÇAKIŞMA kalmalı. Yalnız tek bir durum ucuza iner ve o da ölçülerek.
#
# Koşum: bash yazilim-fabrikasi/scripts/pr-kip-olc.test.sh ; echo rc=$?
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARAC="$BURASI/pr-kip-olc.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECTI=0; KALDI=0

kapi() { # kapi <ad> <beklenen-rc> <fark-dosyasi> <yol>
  local ad="$1" bek="$2" fark="$3" yol="$4" cikti rc
  cikti="$(bash "$ARAC" --fark "$fark" "$yol" 2>&1)"; rc=$?
  if [ "$rc" = "$bek" ]; then printf '  ✓ %-46s (rc=%s)\n' "$ad" "$rc"; GECTI=$((GECTI+1))
  else printf '  ✗ %-46s beklenen rc=%s, gelen rc=%s\n' "$ad" "$bek" "$rc"
       printf '%s\n' "$cikti" | sed 's/^/      /'; KALDI=$((KALDI+1)); fi
  SON="$cikti"
}
icerir() {
  if printf '%s' "$SON" | grep -qF -- "$2"; then printf '  ✓ %s\n' "$1"; GECTI=$((GECTI+1))
  else printf '  ✗ %s — çıktıda yok: %s\n' "$1" "$2"; KALDI=$((KALDI+1)); fi
}

# ── fikstürler: gerçek `gh pr diff` çıktısının biçimi ─────────────────────────────────
cat > "$T/yalniz-kip.diff" <<'EOF'
diff --git a/yazilim-fabrikasi/scripts/one.sh b/yazilim-fabrikasi/scripts/one.sh
old mode 100644
new mode 100755
diff --git a/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh b/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh
old mode 100644
new mode 100755
EOF

cat > "$T/icerik.diff" <<'EOF'
diff --git a/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh b/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh
index 1111111..2222222 100644
--- a/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh
+++ b/ui-tasarim-akisi/arac/yogunluk-denetle.test.sh
@@ -10,6 +10,7 @@ set -u
 KAPI="$BURASI/yogunluk-denetle.py"
+# yeni satır
EOF

cat > "$T/kip-ve-icerik.diff" <<'EOF'
diff --git a/a/x.sh b/a/x.sh
old mode 100644
new mode 100755
index 1111111..2222222
--- a/a/x.sh
+++ b/a/x.sh
@@ -1,2 +1,3 @@
 bir
+iki
EOF

cat > "$T/rename.diff" <<'EOF'
diff --git a/eski/ad.sh b/yeni/ad.sh
similarity index 100%
rename from eski/ad.sh
rename to yeni/ad.sh
EOF

cat > "$T/silme.diff" <<'EOF'
diff --git a/gidecek.sh b/gidecek.sh
deleted file mode 100755
index 3333333..0000000
EOF

cat > "$T/binary.diff" <<'EOF'
diff --git a/kare.png b/kare.png
index 4444444..5555555 100644
Binary files a/kare.png and b/kare.png differ
EOF

cat > "$T/tanimsiz.diff" <<'EOF'
diff --git a/tuhaf.sh b/tuhaf.sh
index 6666666..7777777 100644
EOF

cat > "$T/tirnakli.diff" <<'EOF'
diff --git "a/yol/iki kelime.sh" "b/yol/iki kelime.sh"
old mode 100644
new mode 100755
EOF

cat > "$T/tirnakli-icerik.diff" <<'EOF'
diff --git "a/yol/iki kelime.sh" "b/yol/iki kelime.sh"
index 1111111..2222222 100755
--- "a/yol/iki kelime.sh"
+++ "b/yol/iki kelime.sh"
@@ -1 +1,2 @@
 bir
+iki
EOF

echo "── 1 · YALNIZ KİP ucuza iner (kusurun kendisi: PR #326 vakası)"
kapi "yalnız kip → rc=0" 0 "$T/yalniz-kip.diff" "ui-tasarim-akisi/arac/yogunluk-denetle.test.sh"
icerir "içerik farkının SIFIR olduğu söylenir" "içerik farkı YOK"
kapi "aynı diff'in öteki dosyası da kip → rc=0" 0 "$T/yalniz-kip.diff" "yazilim-fabrikasi/scripts/one.sh"

echo "── 2 · GERÇEK dokunuş çakışma KALIR (gevşeme yok)"
kapi "içerik hunk'ı → rc=1" 1 "$T/icerik.diff" "ui-tasarim-akisi/arac/yogunluk-denetle.test.sh"
icerir "kaç parça olduğu söylenir" "parça"
kapi "kip VE içerik birlikte → rc=1 (kip indirimi yutmaz)" 1 "$T/kip-ve-icerik.diff" "a/x.sh"

echo "── 3 · HUNK YOK ama ZARARSIZ DEĞİL — üç ayrı tuzak"
kapi "rename (hunk yok) → rc=1" 1 "$T/rename.diff" "eski/ad.sh"
icerir "sebep yazılır (yer değiştirme)" "ADLANDIRILIYOR"
kapi "rename hedefi de → rc=1" 1 "$T/rename.diff" "yeni/ad.sh"
kapi "silme (hunk yok) → rc=1" 1 "$T/silme.diff" "gidecek.sh"
kapi "binary (hunk görünmez) → rc=1" 1 "$T/binary.diff" "kare.png"

echo "── 4 · ÖLÇÜLEMEDİ 'temiz' DEĞİLDİR (fail-closed)"
kapi "tanınmayan bölüm → rc=3" 3 "$T/tanimsiz.diff" "tuhaf.sh"
icerir "'zararsız sayılmaz' denir" "SAYILMAZ"
kapi "diff'te olmayan yol → rc=3" 3 "$T/icerik.diff" "hic/olmayan.sh"
kapi "fark dosyası yok → rc=3" 3 "$T/yok-boyle-dosya.diff" "x.sh"

echo "── 5 · YOL EŞLEŞMESİ TAM OLMALI (kısmi ad yanlış bölüm kesmesin)"
# 'denetle.test.sh' yolu, 'yogunluk-denetle.test.sh' bölümünü KESMEMELİ → ölçülemedi.
kapi "kısmi ad eşleşmiyor → rc=3" 3 "$T/icerik.diff" "denetle.test.sh"


echo "── 6 · DAYANIKLILIK (bağımsız göz tur-1 bulguları)"
# (a) git boşluklu yolu TIRNAKLAR: alan bölmek o satırı parçalar ve geçerli bir yalnız-kip
#     dosyası rc=3'e düşerdi. Jeton-sınırlı eşleşme bunu çözer, kısmi adı hâlâ tutmaz.
kapi "tırnaklı/boşluklu yol · yalnız kip → rc=0" 0 "$T/tirnakli.diff" "yol/iki kelime.sh"
icerir "kip olarak tanınır" "YALNIZ KİP"
kapi "tırnaklı/boşluklu yol · içerik → rc=1" 1 "$T/tirnakli-icerik.diff" "yol/iki kelime.sh"
kapi "tırnaklı yolda kısmi ad hâlâ TUTMAZ → rc=3" 3 "$T/tirnakli.diff" "kelime.sh"
# (b) değer isteyen bayrak, değeri eksikse kabuk hatasına değil KULLANIM hatasına düşer.
#     `set -u` altında $2'ye dokunmak aracın tanımlı çıkış kodlarını bozar.
cikti="$(bash "$ARAC" --fark 2>&1)"; rc=$?
if [ "$rc" = "2" ]; then printf '  ✓ %-46s (rc=2)\n' "--fark değersiz → kullanım hatası"; GECTI=$((GECTI+1))
else printf '  ✗ %-46s beklenen rc=2, gelen rc=%s\n' "--fark değersiz → kullanım hatası" "$rc"; KALDI=$((KALDI+1)); fi
cikti="$(bash "$ARAC" 326 x.sh --depo 2>&1)"; rc=$?
if [ "$rc" = "2" ]; then printf '  ✓ %-46s (rc=2)\n' "--depo değersiz → kullanım hatası"; GECTI=$((GECTI+1))
else printf '  ✗ %-46s beklenen rc=2, gelen rc=%s\n' "--depo değersiz → kullanım hatası" "$rc"; KALDI=$((KALDI+1)); fi

echo "────────────────────────────────────────────"
printf 'TOPLAM: %d geçti · %d kaldı\n' "$GECTI" "$KALDI"
[ "$KALDI" = "0" ] || exit 1
