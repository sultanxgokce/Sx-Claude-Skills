#!/usr/bin/env bash
# on-goz.test.sh — ön göz (W42-E1) her kontrolünü gerçek kanıt ve gerçek git geçmişiyle ölçer + mutasyon.
# Hermetik: geçici depo (origin/main tabanı), kanıt GERÇEK kanit.sh ile alınır, gh sahte (PR başı + gövde).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OG="${MUTANT:-$HERE/on-goz.sh}"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
D="$T/depo"; mkdir -p "$D/_agents/fabrika/kartlar" "$D/src"
git -C "$D" init -q -b main; git -C "$D" config user.email s@t; git -C "$D" config user.name s
printf 'eski\n' > "$D/src/a.sh"; git -C "$D" add -A; git -C "$D" commit -qm taban; git -C "$D" update-ref refs/remotes/origin/main HEAD
git -C "$D" checkout -qb is-x
kart() { python3 -c 'import json,sys;json.dump({"is":"is-x","cumle":sys.argv[1]},open(sys.argv[2],"w"),ensure_ascii=False)' "$1" "$D/_agents/fabrika/kartlar/is-x.json"; }
kart "a.sh yeni davranış · boş girdide rc 2 · hata yolunda iz bırakır (gorev_X)"
olc() { (cd "$D" && bash "$HERE/kanit.sh" olcum is-x "$1" --asama "$2" -- bash -c "$3; exit 0") >/dev/null 2>&1 || { [ "$2" = once ] || echo "  (olc $1 $2 kaydedilmedi)" >&2; }; }   # son komut exit: kanit.sh boru reddi
SGH="$T/gh.sh"; printf '#!/usr/bin/env bash\ncase "$*" in *headRefOid*) echo "${GH_BAS:-}";; *body*) echo "${GH_GOVDE:-## Dürüst sınır\nX ölçülmez}";; esac\n' > "$SGH"; chmod +x "$SGH"
DEN="$T/denetci-eski.sh"; printf 'eski denetçi: ilk 60 satır\n' > "$DEN"
og() { (cd "$D" && GH_BAS="${GH_BAS:-$(git -C "$D" rev-parse HEAD)}" FABRIKA_GH="$SGH" ON_GOZ_DENETCI="$DEN" bash "$OG" is-x "$@") > "$T/out" 2>&1; local rc=$?; O="$(cat "$T/out")"; return $rc; }
doldur() { sed -i 's/…/dolu/g' "$D/_agents/fabrika/kanit/is-x/ON-GOZ.md"; }
ver() { git -C "$D" add -A; git -C "$D" commit -qm "${1:-is}"; }

echo "════ O1 · hazır iş: kontroller yeşil, tablo dolu → rc 0 ════"
printf 'yeni\n' > "$D/src/a.sh"
olc kapi once 'echo "✗ eski davranış"; exit 1'; olc kapi sonra 'echo "✓ yeni davranış"; echo "mutant x sınavı kırmızı yapıyor"'
sleep 3; ver "kod + kanıt"   # commit ölçümden SONRA (tolerans 2 sn): kanıtlı commit bayat sayılmamalı
og --pr 7; [ $? -eq 2 ]; g $? "O1a tablo boşken rc 2 (kendine-sor doldurulmadan göze gidilmez)"
grep -q "3 boş hücre\|9 boş hücre\|boş hücre" <<<"$O"; g $? "O1b boş hücre sayısı yazılı"
[ "$(grep -c '^| [0-9]' "$D/_agents/fabrika/kanit/is-x/ON-GOZ.md")" -eq 3 ]; g $? "O1c kart cümlesi 3 maddeye bölündü (· ayırıcı; görev izi madde değil)"
doldur; og --pr 7; R=$?; [ $R -eq 0 ]; g $? "O1d tablo dolu + kontroller yeşil → rc 0 (rc=$R)"
grep -q "ÖN GÖZ TAMAM" <<<"$O"; g $? "O1e göze gönderme komutu yazılı"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d["rc"]==0 and d["bas"]==sys.argv[2] else 1)' "$D/_agents/fabrika/kanit/is-x/ON-GOZ.json" "$(git -C "$D" rev-parse HEAD)"; g $? "O1f ON-GOZ.json yazıldı, baş sha'sı yerel HEAD"
ver "ön göz tablosu"

echo "════ O2 · BAYAT KANIT: ölçümden sonra kanıtsız kod commit'i → rc 2 ════"
sleep 3; printf 'yeni2\n' > "$D/src/a.sh"; ver "kod tek başına"
GH_BAS="" og --pr 7; [ $? -eq 2 ] && grep -q "✗ bayat-kanit:.*src/a.sh.*kanıtsız commit" <<<"$O"; g $? "O2a kanıt KANIT.json'suz commit'ten eski → kırmızı"
sleep 1; olc kapi sonra 'echo "✓ yeni2"; echo mutant'; sleep 3; ver "yeniden ölçüldü"
og --pr 7; grep -q "✓ bayat-kanit" <<<"$O"; g $? "O2b yeniden ölçüp kanıtla commit'leyince yeşil (ölç → birlikte commit'le kalıbı bayat SAYILMAZ)"

echo "════ O3 · commit'lenmemiş üretim kodu ════"
sleep 3; printf 'kirli\n' > "$D/src/a.sh"
og --pr 7; [ $? -eq 2 ] && grep -q "✗ kirli-agac:.*src/a.sh" <<<"$O" && grep -q "✗ bayat-kanit:.*commit'siz" <<<"$O"; g $? "O3 kirli dosya: kirli-agac + bayat (mtime ölçümden yeni) kırmızı"
git -C "$D" checkout -q -- src/a.sh

echo "════ O4 · sonra ölçümü kırmızı · O5 önce/sonra çifti ════"
olc kapi2 sonra 'echo "✗ kaldı"; exit 1'; ver k2
og --pr 7; [ $? -eq 2 ] && grep -q "✗ sonra-kirmizi:.*kapi2" <<<"$O"; g $? "O4 kırmızı sonra ölçümü → rc 2"
olc kapi2 sonra 'echo ok; echo mutant'; olc yetim once 'echo eski; exit 1'; ver k3
og --pr 7; [ $? -eq 2 ] && grep -q "✗ olcum-cifti:.*yetim" <<<"$O"; g $? "O5 önce ölçümü var, sonrası yok → kırmızı"
olc yetim sonra 'echo yeni; echo mutant'; ver k4

echo "════ O6 · sarılar rc'yi düşürmez ama yazılır ════"
GH_GOVDE="sınırsız gövde" og --pr 7; R=$?; [ $R -eq 0 ] && grep -q "⚠ durust-sinir" <<<"$O"; g $? "O6a PR gövdesinde dürüst sınır yok → sarı, rc 0 (rc=$R)"
og; grep -q "⚠ pr-basi:.*PR verilmedi" <<<"$O"; g $? "O6b --pr verilmedi → sarı"
GH_BAS="deadbeef" og --pr 7; [ $? -eq 2 ] && grep -q "✗ pr-basi:.*deadbeef" <<<"$O"; g $? "O6c PR başı yerel HEAD değil → kırmızı (eski fark = yanan tur)"
kart "Nexus kancası ve cloudtop yedeği birlikte · boş girdi"; og --pr 7; grep -q "⚠ kart-depo:.*Nexus.*cloudtop\|⚠ kart-depo:.*cloudtop.*Nexus" <<<"$O"; g $? "O6d kart başka depoları anıyor → sarı"
kart "a.sh yeni davranış · boş girdide rc 2 · hata yolunda iz bırakır (gorev_X)"; og --pr 7; grep -q "✓ kart-depo" <<<"$O"; g $? "O6e tek depolu kart → yeşil"

echo "════ O7 · mutant izi · sonuç göze sığar mı ════"
D2="$T/depo2"; cp -r "$D" "$D2"; Dk="$D"; D="$D2"
find "$D/_agents/fabrika/kanit" -mindepth 1 -delete; olc ozet sonra 'echo "✓ tamam"'; ver m1
og --pr 7; grep -q "⚠ mutant-izi" <<<"$O"; g $? "O7a hiçbir ölçümde mutant yok → sarı"
olc uzun tek 'for i in $(seq 1 70); do echo "  ✓ k$i"; done; echo "── SONUÇ: 70 geçti · 0 kaldı ──"'; ver m2
og --pr 7; grep -q "⚠ goze-sigar:.*olcum-uzun-tek.txt" <<<"$O"; g $? "O7b SONUÇ 60. satırdan sonra + eski denetçi → sarı"
printf 'olcum_ozeti() { :; }\n' > "$DEN"; og --pr 7; grep -q "✓ goze-sigar" <<<"$O"; g $? "O7c denetçi ölçüm özetini biliyorsa → yeşil (sonucu kendisi taşır)"
printf 'eski\n' > "$DEN"; D="$Dk"

echo "════ O8 · ölçülemedi ════"
(cd "$D" && FABRIKA_GH="$SGH" bash "$OG" yok-is) >/dev/null 2>&1; [ $? -eq 3 ]; g $? "O8a kart yok → rc 3 (ölçülemedi yeşil değildir)"
mkdir -p "$T/bos/_agents/fabrika/kartlar"; git -C "$T/bos" init -q -b main; git -C "$T/bos" commit -q --allow-empty -m t; git -C "$T/bos" update-ref refs/remotes/origin/main HEAD
python3 -c 'import json;json.dump({"is":"k","cumle":"x · y"},open("'"$T"'/bos/_agents/fabrika/kartlar/k.json","w"))'
(cd "$T/bos" && bash "$OG" k) > "$T/out" 2>&1; R=$?; [ $R -eq 2 ] && grep -q "✗ kanit-manifesti\|✗ bayat-kanit:.*hiç ölçüm yok" "$T/out"; g $? "O8b kanıtsız iş → rc 2 (kanıtsız adım 4 yok)"

echo "════ O10 · ilk tur ölçeri: origin/main'deki DENETIM-1 kayıtlarından oran + bulgu sınıfı ════"
I="$T/olcu"; mkdir -p "$I"; git -C "$I" init -q -b main; git -C "$I" config user.email s@t; git -C "$I" config user.name s
dn() { mkdir -p "$I/_agents/fabrika/kanit/$1"; python3 -c 'import json,sys;json.dump({"is":sys.argv[1],"sonuc":{"kod_puani":int(sys.argv[2]),"dogru_sey":sys.argv[3],"bulgular":[{"ne":sys.argv[4],"kanit":""}] if sys.argv[4] else []}},open(sys.argv[5],"w"),ensure_ascii=False)' "$1" "$2" "$3" "$4" "$I/_agents/fabrika/kanit/$1/DENETIM-1.json"; }
dn a 5 E ""; dn b 3 E "kanıt bayat: ölçüm eski koda ait"; dn c 4 H "mutant sınavı kırmızı yapmıyor"; dn d 5 E ""
mkdir -p "$I/_agents/fabrika/kanit/e"; echo '{"sonuc":{"kod_puani":5,"dogru_sey":"E"}}' > "$I/_agents/fabrika/kanit/e/DENETIM-2.json"   # 2. tur sayılmaz
git -C "$I" add -A; git -C "$I" commit -qm d; git -C "$I" update-ref refs/remotes/origin/main HEAD
dn f 2 H "yerel, commit'siz"   # origin/main dışı: sayılmaz
o="$(python3 "$HERE/ilk-tur-olc.py" "$I")"
grep -q "TOPLAM .* 2/4 .*= %50" <<<"$o"; g $? "O10a yalnız origin/main + yalnız 1. tur: 2/4 = %50 (commit'siz kayıt ve 2. tur sayılmadı)"
grep -q "kanit-bayat/eksik *1" <<<"$o" && grep -q "sinav-yetersiz *1" <<<"$o"; g $? "O10b kalan işlerin bulguları sınıflandı"

[ "$gecen" -ge 20 ]; g $? "sınav gerçekten koştu ($gecen ≥ 20)"
if [ -n "${IC_KOSUM:-}" ]; then echo "── (iç) $gecen · $kalan"; [ "$kalan" -eq 0 ]; exit $?; fi

echo "════ O9 · MUTASYON: kontrolü bozunca sınav kırmızı veriyor mu ════"
MS="$(mktemp -d)"; MA=(); MP=()
mut() { local M="$HERE/.mutant-ongoz-$1.sh"; MA+=("$1|$M")
  sed "$2" "$HERE/on-goz.sh" > "$M" 2>/dev/null || { echo SED > "$MS/$1"; return; }
  cmp -s "$M" "$HERE/on-goz.sh" && { echo FARKSIZ > "$MS/$1"; return; }
  ( IC_KOSUM=1 MUTANT="$M" bash "$0" >/dev/null 2>&1 && echo SAG > "$MS/$1" || echo OLDU > "$MS/$1" ) & MP+=($!); }
mut bayat-yok 's@^            if z and z > son_olcum + datetime.timedelta(seconds=2) and KJ not in@            if False and KJ not in@'
mut kanitli-commit-de-bayat 's@ and KJ not in git("show", "--name-only", "--format=", h).split():@:@'
mut kirli-yok 's@^if kirli: kayit("kirli-agac", "kirmizi"@if False: kayit("kirli-agac", "kirmizi"@'
mut sonra-kirmizi-gecer 's@^kayit("sonra-kirmizi", "kirmizi" if kotu@kayit("sonra-kirmizi", "sari" if kotu@'
mut yetim-gecer 's@^if yetim: kayit("olcum-cifti", "kirmizi"@if yetim: kayit("olcum-cifti", "sari"@'
mut tablo-sayilmaz 's@^rc = 2 if (kirmizi or bos) else 0@rc = 2 if kirmizi else 0@'
mut pr-basi-bakilmaz 's@^elif E\["PR_BAS"\] != bas:@elif False:@'
mut goze-sigar-yok 's@^        if len(L) > 60 and any@        if False and any@'
mut kart-depo-yok 's@^baska = \[d for d@baska = [] and [d for d@'
mut durust-sinir-gevsek 's@|^#+ .*\\bsınır", E@|sınır", E@'
mut madde-bolunmez 's@^    parcalar = \[p.strip(" .;") for p in re.split(@    parcalar = [p.strip(" .;") for p in re.split(r"^$", govde) if False] or [govde] or re.split(@'
for p in "${MP[@]}"; do wait "$p" 2>/dev/null; done
for k in "${MA[@]}"; do a="${k%%|*}"; M="${k#*|}"; s="$(cat "$MS/$a" 2>/dev/null)"
  [ "$s" = OLDU ]; g $? "mutant '$a' sınavı kırmızı yapıyor${s:+ ($s)}"; rm -f "$M"; done
find "$MS" -mindepth 1 -delete; rmdir "$MS"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
