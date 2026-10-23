#!/usr/bin/env bash
# kabuk-sinamalari.test.sh — CI kova koşucusunun (kabuk-sinamalari.sh) sınavı. HERMETİK: geçici git deposu, gerçek sınamalara dokunmaz.
# Kilitlenen: (1) her sınama tam BİR kovaya düşer (yetim yok) (2) kırmızı sınama kovayı kırmızı yapar (3) kovası boş kalan koşu KIRMIZI
# (4) hiç sınama yoksa KIRMIZI (5) karantina atlanır ama SAYILIR, bayatlarsa KIRMIZI (6) süre tavanı aşılınca KIRMIZI (7) bilinmeyen kova rc 2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; K="$HERE/kabuk-sinamalari.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
yeni_depo() {   # yeni_depo <ad> → $T/<ad>: diploma, denetci, iki sıradan sınama, üç karantina taslağı (üçü de KIRMIZI çıkar: atlanmazsa fark edilir)
  local d="$T/$1"; mkdir -p "$d"; ( cd "$d" && git init -q -b main && git config user.email s@t && git config user.name s )
  mkdir -p "$d/tescil/scripts" "$d/yazilim-fabrikasi/scripts" "$d/a" "$d/mucit-suz/scripts" "$d/kasif-tara/scripts" "$d/terminal-onar/scripts"
  for f in tescil/scripts/diploma yazilim-fabrikasi/scripts/denetci a/bir a/iki; do printf '#!/usr/bin/env bash\necho "%s tamam"; exit 0\n' "$f" > "$d/$f.test.sh"; done
  for f in mucit-suz/scripts/mucit-t1 kasif-tara/scripts/kasif-hafiza terminal-onar/scripts/compact; do printf '#!/usr/bin/env bash\nexit 1\n' > "$d/$f.test.sh"; done
}
kos() { ( cd "$1" && shift && bash "$K" "$@" 2>&1 ); }

echo "── K1 · üç kova birlikte tüm sınamaları bölüştürür (yetim yok)"
yeni_depo d1
O1="$(kos "$T/d1" diploma)"; R1=$?; O2="$(kos "$T/d1" denetci)"; R2=$?; O3="$(kos "$T/d1" kalan)"; R3=$?
[ "$R1" -eq 0 ] && [ "$R2" -eq 0 ] && [ "$R3" -eq 0 ]; g $? "K1 üç kova da yeşil (karantina taslakları atlandı)"
B1="$(grep -o 'bu kovada [0-9]*' <<<"$O1" | grep -o '[0-9]*$')"; B2="$(grep -o 'bu kovada [0-9]*' <<<"$O2" | grep -o '[0-9]*$')"; B3="$(grep -o 'bu kovada [0-9]*' <<<"$O3" | grep -o '[0-9]*$')"
[ "$((B1+B2+B3))" -eq 7 ] && [ "$B1" -eq 1 ] && [ "$B2" -eq 1 ] && [ "$B3" -eq 5 ]; g $? "K1b kovalar 1+1+5 = 7 sınama (diploma 1 · denetci 1 · kalan 5 = 2 sıradan + 3 karantina) → $B1+$B2+$B3"
grep -q "tescil/scripts/diploma.test.sh" <<<"$O1" && ! grep -q "a/bir.test.sh" <<<"$O1"; g $? "K1c diploma kovası yalnız diploma sınamasını koşar"
[ "$(grep -c 'KARANTİNA — atlandı' <<<"$O3")" -eq 3 ]; g $? "K1d karantina üç sınamayı ADIYLA loglar"

echo "── K2 · kırmızı sınama kovayı kırmızı yapar"
yeni_depo d2; printf '#!/usr/bin/env bash\nexit 1\n' > "$T/d2/a/iki.test.sh"
O="$(kos "$T/d2" kalan)"; R=$?
[ "$R" -ne 0 ] && grep -q "a/iki.test.sh KIRMIZI" <<<"$O"; g $? "K2 kalan kovasında kırmızı sınama → rc≠0, adıyla bildirilir"
O="$(kos "$T/d2" diploma)"; R=$?
[ "$R" -eq 0 ]; g $? "K2b kırmızı sınama başka kovayı etkilemez (diploma yeşil)"

echo "── K3 · kovası boş kalan koşu KIRMIZI (dosya adı kayarsa kova sessizce yeşil demesin)"
yeni_depo d3; rm -f "$T/d3/yazilim-fabrikasi/scripts/denetci.test.sh"
O="$(kos "$T/d3" denetci)"; R=$?
[ "$R" -eq 1 ] && grep -q "kovasında hiç sınama yok" <<<"$O"; g $? "K3 denetci kovasında sınama yok → rc 1"

echo "── K4 · hiç sınama yoksa KIRMIZI"
mkdir -p "$T/d4" && ( cd "$T/d4" && git init -q -b main )
O="$(kos "$T/d4" kalan)"; R=$?
[ "$R" -eq 1 ] && grep -q "keşif bozuk" <<<"$O"; g $? "K4 sıfır sınama → rc 1 (keşif bozuk)"

echo "── K5 · karantina listesi bayatlarsa KIRMIZI"
yeni_depo d5; rm -f "$T/d5/mucit-suz/scripts/mucit-t1.test.sh"
O="$(kos "$T/d5" kalan)"; R=$?
[ "$R" -ne 0 ] && grep -q "karantina listesi bayat: ./mucit-suz/scripts/mucit-t1.test.sh" <<<"$O"; g $? "K5 karantinadaki dosya silinmiş → rc≠0, bayat bildirilir"

echo "── K6 · süre tavanı aşılınca KIRMIZI"
yeni_depo d6; printf '#!/usr/bin/env bash\n# kabuk-testleri: sure=1\nsleep 5\n' > "$T/d6/a/iki.test.sh"
O="$(kos "$T/d6" kalan)"; R=$?
[ "$R" -ne 0 ] && grep -q "a/iki.test.sh KIRMIZI rc=124" <<<"$O"; g $? "K6 sure=1 isteyen sınama 5 sn uyuyor → rc=124 kırmızı"

echo "── K7 · bilinmeyen kova"
O="$(kos "$T/d1" yok)"; R=$?
[ "$R" -eq 2 ]; g $? "K7 bilinmeyen kova adı → rc 2"

echo "── MUTASYON · kova kuralı her şeyi 'kalan'a atarsa diploma kovası KIRMIZI olur"
yeni_depo dm; M="$T/kabuk-mutant.sh"
python3 - "$K" "$M" <<'PYM'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='    ./tescil/scripts/diploma.test.sh)                  echo diploma ;;\n'; assert a in s, "kova satırı"
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,'',1))
PYM
O="$( cd "$T/dm" && bash "$M" diploma 2>&1 )"; R=$?
[ "$R" -eq 1 ]; g $? "M1 kova kuralından diploma satırı çıkarsa diploma kovası boş → rc 1 (K3 türü kapı bu mutantı yakalar)"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
