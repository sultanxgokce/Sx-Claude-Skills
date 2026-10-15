#!/usr/bin/env bash
# betik-bekcisi.test.sh — bekçinin hermetik sınavı. Gerçek betiklere DOKUNMAZ (sahte kök).
# Ağırlık merkezi MASUMİYET: bu kutuda kapının masumu suçlaması üç kez ölçüldü (6·11·12 Ekim)
# ve bekçinin kendisi ilk koşusunda iki masumu suçladı. ALTIN fikstürler masum kalmalı.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; B="$REPO/scripts/betik-bekcisi.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GEC=0; DUS=0
kapi(){ local ad="$1" bek="$2"; shift 2; local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$bek" ]; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen rc=$bek, gelen rc=$rc"; DUS=$((DUS+1)); fi; }
sayi(){ local ad="$1" kok="$2" alan="$3" bek="$4"
  local n; n="$(bash "$B" --kok "$kok" 2>&1 | sed -n "s/^— kırmızı \([0-9]*\) · sarı \([0-9]*\).*/\\$alan/p")"
  if [ "${n:-X}" = "$bek" ]; then echo "✅ $ad ($bek)"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen $bek, gelen ${n:-boş}"; DUS=$((DUS+1)); fi; }

echo "── ALTIN · masum desenler suçlanmamalı ──"
A="$T/altin"; mkdir -p "$A"
# güvenli sayım · kendini dışlayan pgrep (aynı satır) · kendini dışlayan pgrep (sonraki satır, ölçülen vaka)
printf '#!/bin/bash\nn=$(grep -c x f 2>/dev/null); echo "${n:-0}"\n' > "$A/sayim.sh"
printf '#!/bin/bash\n_pid(){ pgrep -f "x" | grep -vx "$$" | head -1; }\n' > "$A/ayni-satir.sh"
printf '#!/bin/bash\nfor pid in $(pgrep -f "x"); do\n  [ "$pid" = "$$" ] && continue\n  kill "$pid"\ndone\n' > "$A/sonraki-satir.sh"
printf '#!/bin/bash\nfor pid in $(pgrep -f "x"); do\n  args="$(cat /proc/$pid/cmdline)"\n  kill "$pid"\ndone\n' > "$A/proc-kontrol.sh"
# yorum satırındaki ders metni suç değildir
printf '#!/bin/bash\n# 🔴 grep -c … || echo 0 yazmayın, iki satır basar\n# pkill -f desenle öldürmeyin\necho ok\n' > "$A/yorum.sh"
kapi "A1 altın kök temiz (rc 0)" 0 bash "$B" --kok "$A"
sayi "A2 kırmızı sıfır" "$A" 1 "0"
sayi "A3 sarı sıfır" "$A" 2 "0"

echo "── KIRMIZI · gerçek tuzaklar yakalanmalı ──"
K="$T/kirmizi"; mkdir -p "$K"
printf '#!/bin/bash\nt=$(grep -c . "$F" 2>/dev/null || echo 0)\n' > "$K/cift-sifir.sh"
printf '#!/bin/bash\npkill -f "benim-surecim"\n' > "$K/kabuk-oldurme.sh"
kapi "K1 çift sıfır + kabuk öldürme yakalanır (rc 1)" 1 bash "$B" --kok "$K"
sayi "K2 kırmızı iki" "$K" 1 "2"
out="$(bash "$B" --kok "$K" 2>&1)"
case "$out" in *"cift-sifir.sh:2"*) echo "✅ K3 satır numarası gösterildi"; GEC=$((GEC+1));; *) echo "❌ K3 satır numarası yok"; DUS=$((DUS+1));; esac
case "$out" in *"olc-kos.sh"*) echo "✅ K4 meşru yol söylendi"; GEC=$((GEC+1));; *) echo "❌ K4 meşru yol söylenmedi"; DUS=$((DUS+1));; esac

echo "── SARI · yasaklı silme: varsayılan rc'yi düşürmez, --sert düşürür ──"
S="$T/sari"; mkdir -p "$S"; printf '#!/bin/bash\nT=$(mktemp -d); trap %s EXIT\n' "'rm -rf \"\$T\"'" > "$S/silme.sh"
kapi "S1 sarı tek başına rc 0" 0 bash "$B" --kok "$S"
sayi "S2 sarı bir" "$S" 2 "1"
kapi "S3 --sert ile kırmızı (rc 1)" 1 bash "$B" --kok "$S" --sert

echo "── FAIL-CLOSED ve kullanım ──"
kapi "F1 kök yok → ölçemedim (rc 3)" 3 bash "$B" --kok "$T/olmayan"
BOS="$T/bos"; mkdir -p "$BOS"
kapi "F2 betik yok → ölçemedim (rc 3)" 3 bash "$B" --kok "$BOS"
kapi "F3 bilinmeyen argüman (rc 4)" 4 bash "$B" --saçma
# bekçi kendi dosyasını taramaz: gerçek kökte kendi desenleri suç sayılmamalı
out="$(bash "$B" --kok "$REPO/scripts" 2>&1)"
case "$out" in *betik-bekcisi.sh:*|*betik-bekcisi.test.sh:*) echo "❌ F4 bekçi kendini ya da sınavını suçladı"; DUS=$((DUS+1));; *) echo "✅ F4 bekçi kendini ve sınavını taramadı"; GEC=$((GEC+1));; esac
# F4b · gerçek kökte kırmızı SIFIR olmalı: bu kutunun betikleri bu turda onarıldı
n="$(printf '%s\n' "$out" | sed -n 's/^— kırmızı \([0-9]*\).*/\1/p')"
if [ "${n:-X}" = "0" ]; then echo "✅ F4b gerçek kökte kırmızı 0 (onarımlar duruyor)"; GEC=$((GEC+1));
else echo "❌ F4b gerçek kökte kırmızı ${n:-boş} — yeni tuzak girmiş ya da masum suçlanıyor"; DUS=$((DUS+1)); fi
case "$out" in *ATLANAN*) echo "✅ F5 atlamayı söylüyor"; GEC=$((GEC+1));; *) echo "❌ F5 atlamayı gizliyor"; DUS=$((DUS+1));; esac
case "$out" in *"ÖLÇMEDİĞİ"*) echo "✅ F6 ölçmediğini yazıyor"; GEC=$((GEC+1));; *) echo "❌ F6 ölçmediğini yazmıyor"; DUS=$((DUS+1));; esac

echo "── MUTASYON · koruma sökülünce sınav kırmızıya dönmeli ──"
mut(){ local ad="$1" yama="$2" bek_altin="$3"
  local kop="$T/mut.sh"; cp "$B" "$kop"
  python3 -c "$yama" "$kop" || { echo "❌ MUT $ad: yama tutmadı (desen değişti)"; DUS=$((DUS+1)); return; }
  bash "$kop" --kok "$A" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$bek_altin" ]; then echo "✅ MUT $ad: koruma sökülünce ALTIN düştü (rc $rc)"; GEC=$((GEC+1));
  else echo "❌ MUT $ad: koruma söküldü ama altın yeşil kaldı (rc $rc) — kapı SÜS"; DUS=$((DUS+1)); fi; }
# M1 · yorum atlama sökülürse: ders metni suç sayılır → altın kırmızıya döner
mut "yorum atlama" '
import sys; p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a="_yorum \"$satir\" && continue"
assert s.count(a)>=2, "desen %d" % s.count(a)
open(p,"w",encoding="utf-8").write(s.replace(a,"true"))' 1
# M2 · kendini dışlama penceresi sökülürse: masum pgrep suçlanır → altın kırmızıya döner
mut "kendini dışlama penceresi" '
import sys,re; p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a=re.search(r"    case \"\$pencere\" in[^\n]*\n", s)
assert a, "pencere deseni yok"
open(p,"w",encoding="utf-8").write(s.replace(a.group(0),""))' 1

echo
echo "— $GEC geçti · $DUS düştü"
[ "$DUS" -eq 0 ]
