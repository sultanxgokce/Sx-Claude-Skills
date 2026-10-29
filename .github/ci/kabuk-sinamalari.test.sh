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

echo "── K10 · süre beyanından sonra açıklama gelebilir (WRVA: sicil 480 beyanı sessizce 300'e düşüyordu)"
yeni_depo d10; printf '#!/usr/bin/env bash\n# kabuk-testleri: sure=1   (yerelde 0 sn ölçüldü; CI payı)\nsleep 4\n' > "$T/d10/a/iki.test.sh"
O="$(kos "$T/d10" kalan)"; R=$?
[ "$R" -ne 0 ] && grep -q "a/iki.test.sh KIRMIZI rc=124 (süre tavanı 1sn" <<<"$O"; g $? "K10 'sure=1   (açıklama)' beyanı 1 sn olarak okundu (varsayılan 300'e düşmedi): 4 sn uyuyan sınama rc=124"
printf '#!/usr/bin/env bash\n# kabuk-testleri: sure=abc\nexit 0\n' > "$T/d10/a/bir.test.sh"
O="$(kos "$T/d10" kalan)"
grep -q "a/bir.test.sh 'kabuk-testleri:' başlığı var ama sure=N okunamadı" <<<"$O"; g $? "K10b beyan var ama okunamıyor (sure=abc) → UYARI satırı (sessiz varsayılan yok)"
echo "── K7 · bilinmeyen kova"
O="$(kos "$T/d1" yok)"; R=$?
[ "$R" -eq 2 ]; g $? "K7 bilinmeyen kova adı → rc 2"

echo "── K8 · CI'ın HİÇ koşmayacağı dosya kümesi (lint.yml pull_request.paths-ignore) tam olarak '_agents/**'"
LY="$HERE/../workflows/lint.yml"
ignore_listesi() {   # ignore_listesi <lint.yml> → pull_request bloğundaki paths-ignore maddeleri, satır satır (yorum satırları atlanır)
  awk '/^on:/{on=1;next} on&&/^[^ #]/{on=0} on&&/^  pull_request:/{pr=1;next} pr&&/^  [^ #]/{pr=0} pr&&/^    paths-ignore:/{pi=1;next} pi&&/^    [^ #-]/{pi=0} pi&&/^      - /{sub(/^      - /,"");gsub(/[\047"]/,"");print}' "$1"
}
[ -f "$LY" ]; g $? "K8a lint.yml bulundu ($LY)"
L1="$(ignore_listesi "$LY")"
[ "$L1" = "_agents/**" ]; g $? "K8b paths-ignore listesi TAM olarak '_agents/**' (kanıt/denetim/kart dosyası): '$L1'"
! grep -qE '\.md|SKILL' <<<"$L1"; g $? "K8c SKILL.md ve .md dosyaları CI'dan KAÇMAZ (sürüm frontmatter'ı lint'in konusu)"
sed "s#      - '_agents/\*\*'#      - '_agents/**'\n      - '**/*.md'#" "$LY" > "$T/lint-mutant.yml"
[ "$(ignore_listesi "$T/lint-mutant.yml" | wc -l)" -eq 2 ] && [ "$(ignore_listesi "$T/lint-mutant.yml" | tail -n 1)" = "**/*.md" ]; g $? "K8d ayıklayıcı mutantı görür: listeye '**/*.md' eklenince 2 madde okunur (K8b bu mutantta KIRMIZI olurdu)"
echo "── K9 · diploma iki parçaya bölünür: diploma-1 / diploma-2 aynı sınamayı DIPLOMA_PARCA=1/2 · 2/2 ile koşar"
yeni_depo d9; printf '#!/usr/bin/env bash\necho "PARCA=${DIPLOMA_PARCA:-yok}"; exit 0\n' > "$T/d9/tescil/scripts/diploma.test.sh"
P1="$(kos "$T/d9" diploma-1)"; R1=$?; P2="$(kos "$T/d9" diploma-2)"; R2=$?; P0="$(kos "$T/d9" diploma)"; R0=$?
[ $R1 -eq 0 ] && [ $R2 -eq 0 ] && grep -q "bu kovada 1 " <<<"$P1" && grep -q "bu kovada 1 " <<<"$P2"; g $? "K9a diploma-1 ve diploma-2 yeşil, ikisi de diploma sınamasını (tek sınama) bulur"
grep -q "PARCA=1/2" <<<"$P1" && grep -q "PARCA=2/2" <<<"$P2"; g $? "K9b parçalar sınamaya DIPLOMA_PARCA=1/2 ve 2/2 geçirir"
[ $R0 -eq 0 ] && grep -q "PARCA=yok" <<<"$P0"; g $? "K9c düz 'diploma' kovası bölünmez (DIPLOMA_PARCA verilmez → sınama hepsini koşar)"
! grep -q "a/bir.test.sh" <<<"$P1$P2"; g $? "K9d parçalar diploma dışı sınama koşmaz"
M9="$(sed -n 's/^ *kova: \[\(.*\)\].*/\1/p' "$HERE/../workflows/lint.yml" | tr -d ' ')"
grep -q ',diploma-1,' <<<",$M9," && grep -q ',diploma-2,' <<<",$M9," && ! grep -q ',diploma,' <<<",$M9,"; g $? "K9e lint.yml matrisi diploma-1 + diploma-2 koşar, bölünmemiş diploma YOK (çift koşu olmasın): [$M9]"

echo "── MUTASYON · kova kuralı her şeyi 'kalan'a atarsa diploma kovası KIRMIZI olur"
yeni_depo dm; M="$T/kabuk-mutant.sh"
python3 - "$K" "$M" <<'PYM'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='    ./tescil/scripts/diploma.test.sh)                  echo diploma ;;\n'; assert a in s, "kova satırı"
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,'',1))
PYM
O="$( cd "$T/dm" && bash "$M" diploma 2>&1 )"; R=$?
[ "$R" -eq 1 ]; g $? "M1 kova kuralından diploma satırı çıkarsa diploma kovası boş → rc 1 (K3 türü kapı bu mutantı yakalar)"
echo "── MUTASYON · sure_sec eski kalıba dönerse (satır sonu şart) K10 kırmızı olur"
M2="$T/kabuk-mutant2.sh"
python3 - "$K" "$M2" <<'PYM'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a=r"\([^0-9].*\)\{0,1\}$"; assert s.count(a)==1, "sure kalıbı"
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a," *$",1))
PYM
yeni_depo dm2; printf '#!/usr/bin/env bash\n# kabuk-testleri: sure=1   (açıklama)\nsleep 4\n' > "$T/dm2/a/iki.test.sh"
O="$( cd "$T/dm2" && bash "$M2" kalan 2>&1 )"; R=$?
[ "$R" -eq 0 ] && grep -q "a/iki.test.sh (4[0-9]* ms)" <<<"$O"; g $? "M2 eski kalıp: açıklamalı beyan okunmaz, 300 varsayılanıyla 4 sn'lik sınama YEŞİL geçer → K10 bu mutantta KIRMIZI olurdu"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
