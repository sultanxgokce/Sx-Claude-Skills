#!/usr/bin/env bash
# kip-ayirt-olcer.sh <kod kaynağı: git ref | "agac"> — 8RYVG/pr-kip-olcer: bir PR dokunuşunun yalnız KİP mi İÇERİK mi olduğu ölçülebiliyor mu?
#   Verilen kaynaktaki yazilim-fabrikasi/scripts geçici dizine alınır. Geçici depoda GERÇEK git farkı üretilir (fikstür uydurma değil):
#   kip.sh yalnız çalıştırma biti alır (100644→100755) · icerik.sh bir satır değişir · eski-ad.sh yeniden adlandırılır.
#   Her yol için `pr-kip-olc.sh --fark <fark> <yol>` koşulur. Beklenen: kip 0 · içerik 1 · ad değiştirme 1 (fail-closed).
#   Araç kaynakta YOKSA (ana dal) her yol "ölçülemedi" (127) basar — eski kapı yalnız YOL eşleştirdiği için üçünü de çakışma sayıyordu.
#   Çıkış 0 = üç beklenen de tuttu · 1 = tutmadı.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s" "$T/d"
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts | tar -x -C "$T/s" --strip-components=2; fi
cd "$T/d" && git init -q . && git config user.email t@t && git config user.name t && git config core.fileMode true
printf 'a\n' > kip.sh; printf 'b\n' > icerik.sh; printf 'c\n' > eski-ad.sh; git add -A; git commit -qm ilk
chmod +x kip.sh; printf 'b2\n' > icerik.sh; git mv eski-ad.sh yeni-ad.sh; git add -A; git commit -qm pr
git diff -M HEAD~1 HEAD > "$T/fark.patch"
echo "kod kaynağı: $1 · araç: $([ -f "$T/s/pr-kip-olc.sh" ] && echo var || echo YOK)"
sonuc=""
for y in kip.sh icerik.sh yeni-ad.sh; do
  if [ -f "$T/s/pr-kip-olc.sh" ]; then bash "$T/s/pr-kip-olc.sh" --fark "$T/fark.patch" "$y" >/dev/null 2>&1; rc=$?; else rc=127; fi
  echo "   $y → rc=$rc"; sonuc="$sonuc$y:$rc "
done
[ "$sonuc" = "kip.sh:0 icerik.sh:1 yeni-ad.sh:1 " ]
