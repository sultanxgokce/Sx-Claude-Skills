#!/usr/bin/env bash
# kanit-olculen-commit.test.sh — kanit.sh olcum kaydı ölçümün koştuğu commit'i (olculen_commit) ve ağacın kirliliğini (olculen_kirli) taşır.
set -uo pipefail
export KANIT_SIRA=0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; K="${KANIT:-$HERE/kanit.sh}"
gecen=0; kalan=0; g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; export KANIT_DEPO="$T"
( cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t && echo a > f.sh && git add -A && git commit -q -m "chore: ilk" ) >/dev/null 2>&1
alan() { python3 -c "import json,sys;m=json.load(open(sys.argv[1]));print(m['kayitlar'][-1].get(sys.argv[2],'YOK'))" "$T/_agents/fabrika/kanit/is-k/KANIT.json" "$1"; }
echo "════ K1 · temiz ağaç: olculen_commit = HEAD, olculen_kirli = False ════"
( cd "$T" && bash "$K" olcum is-k bir --asama tek -- echo 1 ) >/dev/null 2>&1
H="$(git -C "$T" rev-parse HEAD)"
[ "$(alan olculen_commit)" = "$H" ]; g $? "olculen_commit HEAD ile aynı"
[ "$(alan olculen_kirli)" = "False" ]; g $? "olculen_kirli=False"
echo "════ K2 · izlenen dosyada commit'siz değişiklik: olculen_kirli = True ════"
( cd "$T" && echo b > f.sh && bash "$K" olcum is-k iki --asama tek --kirli-izin "sınav: kirli bayrağı ölçülür" -- echo 2 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "True" ]; g $? "olculen_kirli=True"
echo "════ K3 · imza bozulmadı (dogrula rc=0) ════"
( cd "$T" && bash "$K" dogrula is-k ) >/dev/null 2>&1; g $? "dogrula rc=0"
echo "════ K4 · kod temiz, izlenen kanıt dosyası değişmiş: kirli SAYILMAZ (aracın kendi yazımı koda dair bir şey söylemez) ════"
( cd "$T" && git add -A && git commit -q -m "docs: kanıt" ) >/dev/null 2>&1
( cd "$T" && bash "$K" olcum is-k uc --asama tek -- echo 3 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "False" ]; g $? "temiz başta ilk kayıt False"
( cd "$T" && bash "$K" olcum is-k dort --asama tek -- echo 4 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "False" ]; g $? "aynı başta ikinci kayıt da False (KANIT.json izlenen ve değişmiş)"
( cd "$T" && git add -A && git commit -q -m "docs: kanıt 2" && bash "$K" olcum is-k dort --asama tek -- echo 5 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "False" ]; g $? "aynı etiket yeniden: izlenen ölçüm dosyası değişse de False"
echo "════ K5 · kanıt dışındaki izlenen dosya değişince yine kirli ════"
( cd "$T" && echo c > f.sh && bash "$K" olcum is-k bes --asama tek --kirli-izin "sınav: kirli bayrağı ölçülür" -- echo 6 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "True" ]; g $? "kanıt dışı değişiklik True (dışlama yalnız kanıt dizini)"
echo "════ K6 · kirli ağaç, izinsiz: ölçüm KOŞMAZ (rc 2) ════"
( cd "$T" && echo d > f.sh && bash "$K" olcum is-k alti --asama tek -- echo 7 ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ]; g $? "rc=2"
[ "$(alan etiket)" != "alti" ]; g $? "kayıt yazılmadı"
echo "════ K7 · izin gerekçesi 15 karakterden kısa → rc 2 ════"
( cd "$T" && bash "$K" olcum is-k yedi --asama tek --kirli-izin "kısa" -- echo 8 ) >/dev/null 2>&1; [ $? -eq 2 ]; g $? "kısa gerekçe rc=2"
echo "════ K8 · izinli kayıt kirli_kurali + kirli_izin taşır; temiz ağaçta izin yazılmaz ════"
( cd "$T" && bash "$K" olcum is-k sekiz --asama tek --kirli-izin "sınav: ikinci izinli ölçüm" -- echo 9 ) >/dev/null 2>&1
[ "$(alan kirli_kurali)" = "1" ]; g $? "kirli_kurali=1"; [ "$(alan kirli_izin)" = "sınav: ikinci izinli ölçüm" ]; g $? "kirli_izin yazıldı"
( cd "$T" && git checkout -q -- f.sh && bash "$K" olcum is-k dokuz --asama tek --kirli-izin "temiz ağaçta gereksiz izin" -- echo 10 ) >/dev/null 2>&1
[ "$(alan kirli_kurali)" = "1" ]; g $? "temiz ağaçta kirli_kurali=1"; [ "$(alan kirli_izin)" = "YOK" ]; g $? "temiz ağaçta kirli_izin yazılmadı"
# 🔴 0.9.0 (6 Kas, görev …PYWKB · MUHAKKİK revizyonu): eski K9 "dosya kaydı kirli ağaçta kural damgası taşımaz" diyordu (0.7.0 kararı: kapı yalnız
#    kodu ölçen yollarda). Kural sonrası 9 izinsiz kirli kayıt yalnız dosya ve canli yolundan geldi; kural bütün kanıtı kapsar → iki yol da DURUR.
echo "════ K9 · dosya kaydı kirli ağaçta İZİNSİZ yazılmaz (rc 2); izinliyse kirli_kurali + kirli_izin taşır ════"
( cd "$T" && echo e > f.sh && echo veri > ek.txt && bash "$K" dosya is-k onbir ek.txt --asama tek ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ]; g $? "K9 izinsiz kirli dosya kaydı rc=2"; [ "$(alan etiket)" != "onbir" ]; g $? "K9 izinsiz dosya kaydı YAZILMADI"
( cd "$T" && bash "$K" dosya is-k onbir ek.txt --asama tek --kirli-izin "sınav: kirli ağaçta dosya kaydı" ) >/dev/null 2>&1
[ "$(alan etiket)" = "onbir" ]; g $? "K9 izinli dosya kaydı yazıldı"; [ "$(alan kirli_kurali)" = "1" ]; g $? "K9 dosya kaydında kirli_kurali=1"
[ "$(alan kirli_izin)" = "sınav: kirli ağaçta dosya kaydı" ]; g $? "K9 dosya kaydında gerekçe yazıldı"
echo "════ K10 · canlı kaydı kirli ağaçta İZİNSİZ yazılmaz (rc 2); izinliyse kirli_kurali + kirli_izin taşır ════"
printf '2026-11-06T10:00:00+03:00 olay-k10 ateşlendi\n' > "$T/k10.log"
( cd "$T" && bash "$K" canli is-k oniki --kaynak "dosya:$T/k10.log" --desen olay-k10 ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ]; g $? "K10 izinsiz kirli canlı kaydı rc=2"; [ "$(alan etiket)" != "oniki" ]; g $? "K10 izinsiz canlı kaydı YAZILMADI"
( cd "$T" && bash "$K" canli is-k oniki --kaynak "dosya:$T/k10.log" --desen olay-k10 --kirli-izin "sınav: kirli ağaçta canlı kaydı" ) >/dev/null 2>&1
[ "$(alan etiket)" = "oniki" ]; g $? "K10 izinli canlı kaydı yazıldı"; [ "$(alan kirli_kurali)" = "1" ]; g $? "K10 canlı kaydında kirli_kurali=1"
[ "$(alan kirli_izin)" = "sınav: kirli ağaçta canlı kaydı" ]; g $? "K10 canlı kaydında gerekçe yazıldı"
echo "════ K11 · temiz ağaçta dosya ve canlı izinsiz yazılır, damga taşır (gereksiz engel yok) ════"
( cd "$T" && git checkout -q -- f.sh && git add ek.txt k10.log && git commit -q -m "chore: ek" && bash "$K" dosya is-k onuc ek.txt --asama tek ) >/dev/null 2>&1
[ "$(alan etiket)" = "onuc" ]; g $? "K11 temiz ağaçta dosya kaydı izinsiz yazıldı"; [ "$(alan kirli_kurali)" = "1" ] && [ "$(alan kirli_izin)" = "YOK" ]; g $? "K11 damga var, izin yok"
( cd "$T" && bash "$K" canli is-k ondort --kaynak "dosya:$T/k10.log" --desen olay-k10 ) >/dev/null 2>&1
[ "$(alan etiket)" = "ondort" ]; g $? "K11 temiz ağaçta canlı kaydı izinsiz yazıldı"
echo "════ K12 · --olculen-dizin: ölçüm geçici kopyada koşar, kayıt O ağacın kimliğini taşır (görev …PGT8Z1) ════"
T2="$(mktemp -d)"
( cd "$T2" && git init -q -b main && git config user.email t@t && git config user.name t && echo z > g.sh && git add -A && git commit -q -m "chore: kopya" ) >/dev/null 2>&1
H2="$(git -C "$T2" rev-parse HEAD)"; HT="$(git -C "$T" rev-parse HEAD)"
( cd "$T" && bash "$K" olcum is-k oncekopya --asama once --olculen-dizin "$T2" -- bash -c 'pwd -P; exit 0' ) >/dev/null 2>&1
[ "$(alan olculen_commit)" = "$H2" ]; g $? "K12 olculen_commit ölçülen kopyanın HEAD'i"
grep -qx "$(cd "$T2" && pwd -P)" "$T/_agents/fabrika/kanit/is-k/olcum-oncekopya-once.txt"; g $? "K12 komut ölçülen kopyada KOŞTU (pwd = kopya, çalışılan ağaç değil) — kimlik komutla bağlı"
[ "$(alan olculen_commit)" != "$HT" ]; g $? "K12 çalışılan dalın ucu yazılmadı"
[ "$(alan olculen_dizin)" = "$T2" ]; g $? "K12 kayıt olculen_dizin taşır"
[ "$(alan olculen_kirli)" = "False" ]; g $? "K12 temiz kopya olculen_kirli=False"
echo q >> "$T2/g.sh"
( cd "$T" && bash "$K" olcum is-k kirlikopya --asama once --olculen-dizin "$T2" -- echo kopya2 ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ]; g $? "K12 kirli kopya izinsiz rc=2 (kapı kopyaya bakar)"
( cd "$T" && bash "$K" olcum is-k kirlikopya --asama once --olculen-dizin "$T2" --kirli-izin "sınav: kirli kopya ölçümü" -- echo kopya2 ) >/dev/null 2>&1
[ "$(alan olculen_kirli)" = "True" ]; g $? "K12 kirli kopya izinli: olculen_kirli=True"
GT="$(mktemp -d)"
( cd "$T" && bash "$K" olcum is-k gitdegil --asama once --olculen-dizin "$GT" -- echo x ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ]; g $? "K12 git ağacı olmayan dizin rc=2, ölçüm koşmaz"
[ "$(alan etiket)" != "gitdegil" ]; g $? "K12 kayıt yazılmadı"
( cd "$T" && bash "$K" dogrula is-k ) >/dev/null 2>&1; g $? "K12 imza bozulmadı (dogrula rc=0)"
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
