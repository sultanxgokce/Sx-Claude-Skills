#!/usr/bin/env bash
# layiha-defteri.test.sh — defterin ilk test takımı (L24 F4).
#
# BOŞLUK: bu script L24'ün en çok dokunulan dosyasıydı ve BUGÜNE KADAR HİÇ TESTİ YOKTU — kimlik,
#   tescil-disiplini ve Sultan'ın gördüğü liste hep elle doğrulanıyordu. Bu takım o boşluğu kapatır.
#
# HERMETİK: yalnız $TMPDIR altında sahte defterler; gerçek deftere ve ortak dizine YAZMAZ (G8 kanıtlar).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/layiha-defteri.sh"
FILO="$HERE/layiha-filo.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS  $1"; }
kotu() { FAIL=$((FAIL+1)); echo "FAIL  $1 — beklenen [$2] · gelen [$3]"; }
esit() { if [ "$2" = "$3" ]; then ok "$1"; else kotu "$1" "$2" "$3"; fi; }
var()  { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else kotu "$1" "içerir: $3" "$2"; fi; }
yok()  { if printf '%s' "$2" | grep -q -- "$3"; then kotu "$1" "içermemeli: $3" "$2"; else ok "$1"; fi; }

D="$T/defter.jsonl"; : > "$D"
# HAT_ROOT = hat-yolu.lib.sh'in KANONİK test-dikişi (script kendi HAT_KOK'unu ondan türetir).
sut() { LAYIHA_DEFTER="$D" HAT_ROOT="$T/OdaBir" bash "$SUT" "$@"; }

echo "=== G1 · sözdizimi ==="
bash -n "$SUT" 2>/dev/null; esit "G1 layiha-defteri.sh bash -n" "0" "$?"
bash -n "$FILO" 2>/dev/null; esit "G1 layiha-filo.sh bash -n" "0" "$?"
python3 -c "import ast;ast.parse(open('$HERE/layiha_defteri_lib.py').read())" 2>/dev/null
esit "G1 kitaplık python-sözdizimi" "0" "$?"

echo
echo "=== G2 · kimlik: yeni kayıt v + proje taşır ==="
sut ekle --slug bir-konu --konu "Birinci layiha" --dokuman "_agents/spec/bir.md" --resume "bir de" >/dev/null
esit "G2 ekle rc=0" "0" "$?"
esit "G2 şema-sürümü yazıldı" "1"        "$(python3 -c "import json;print(json.loads(open('$D').readline())['v'])")"
esit "G2 proje (oda) yazıldı"  "OdaBir"  "$(python3 -c "import json;print(json.loads(open('$D').readline())['proje'])")"
esit "G2 kod atandı"           "L01"     "$(python3 -c "import json;print(json.loads(open('$D').readline())['id'])")"

echo
echo "=== G3 · liste SALT-OKURDUR (eski sürüm dosyayı sessizce yeniden yazıyordu) ==="
# Eksik alanlı ESKİ kayıt ekle — eski sürüm bunu görünce backfill yapıp dosyayı baştan yazardı.
printf '{"slug":"eski-kayit","konu":"Sürümsüz eski kayıt","tarih":"2026-07-01","durum":"insa-bekliyor","dokuman":"x.md"}\n' >> "$D"
ONCE="$(sha256sum "$D" | cut -d' ' -f1)"
sut liste >/dev/null 2>&1; esit "G3 liste rc=0" "0" "$?"
sut liste --hepsi >/dev/null 2>&1
sut liste --porcelain >/dev/null 2>&1
esit "G3 üç listeden sonra defter BAYT-AYNI" "$ONCE" "$(sha256sum "$D" | cut -d' ' -f1)"
L3="$(sut liste --hepsi)"
var "G3 eksik alanlı eski kayıt yine de listede (bellekte normalize)" "$L3" "Sürümsüz eski kayıt"
var "G3 eski kayda bellekte kod verildi" "$L3" "L02"

echo
echo "=== G4 · tanınmayan bayrak SESSİZCE YUTULMAZ ==="
OUT4="$(sut liste --proje Nexus 2>&1)"; RC4=$?
esit "G4 --proje (yok böyle bir bayrak) rc=2" "2" "$RC4"
var  "G4 hata mesajı geçerli bayrakları sayıyor" "$OUT4" "tescil-bekleyen"
sut liste --tescil-bekleyen >/dev/null 2>&1; esit "G4 gerçek bayrak hâlâ çalışıyor" "0" "$?"

echo
echo "=== G5 · 'hangi çekmeceyi açtım' satırı ==="
L5="$(sut liste --hepsi)"
var "G5 oda adı basılıyor"      "$L5" "oda: OdaBir"
var "G5 defter yolu basılıyor"  "$L5" "$D"
P5="$(sut liste --hepsi --porcelain | tail -1)"
var "G5 porcelain özetinde defter yolu var" "$P5" "defter="

echo
echo "=== G6 · İLERİ-SÜRÜM KAPISI: yeni şemalı defteri eski araç EZEMEZ ==="
D6="$T/ileri.jsonl"
printf '{"v":99,"id":"L01","slug":"gelecek","konu":"Gelecekten kayıt","tarih":"2026-07-25","durum":"insa-bekliyor","dokuman":"y.md"}\n' > "$D6"
ONCE6="$(sha256sum "$D6" | cut -d' ' -f1)"
OUT6="$(LAYIHA_DEFTER="$D6" HAT_ROOT="$T/OdaBir" bash "$SUT" ekle --slug yeni --konu "K" --dokuman "z.md" 2>&1)"; RC6=$?
esit "G6 ileri-sürümlü deftere yazma rc=2" "2" "$RC6"
var  "G6 hata sürümü söylüyor"             "$OUT6" "şema-sürümü"
esit "G6 defter DEĞİŞMEDİ (hiçbir şey yazılmadı)" "$ONCE6" "$(sha256sum "$D6" | cut -d' ' -f1)"
LAYIHA_DEFTER="$D6" HAT_ROOT="$T/OdaBir" bash "$SUT" durum L01 insa-edildi >/dev/null 2>&1
esit "G6 durum-flip de reddedildi" "2" "$?"

echo
echo "=== G7 · eşzamanlı yazım: iki paralel ekle, iki kayıt da hayatta (flock + atomik) ==="
D7="$T/paralel.jsonl"; : > "$D7"
( LAYIHA_DEFTER="$D7" HAT_ROOT="$T/OdaBir" bash "$SUT" ekle --slug p-bir --konu "Paralel bir" --dokuman a.md >/dev/null 2>&1 ) &
( LAYIHA_DEFTER="$D7" HAT_ROOT="$T/OdaBir" bash "$SUT" ekle --slug p-iki --konu "Paralel iki" --dokuman b.md >/dev/null 2>&1 ) &
wait
esit "G7 iki kayıt da yazıldı" "2" "$(grep -c . "$D7")"
python3 -c "
import json,sys
ok=all(json.loads(l) for l in open('$D7') if l.strip())
print('0' if ok else '1')" 2>/dev/null | grep -q '^0'
esit "G7 hiçbir satır yarım/bozuk değil" "0" "$?"

echo
echo "=== G8 · K1: proje klasörü olmayan yerde ortak dizine YAZMAZ ==="
ORTAK="${HOME:-/config}/.claude"
FOTO() { find "$ORTAK" -maxdepth 2 -name 'layiha-*.jsonl' 2>/dev/null | sort; }
ONCE8="$(FOTO)"
GITSIZ="$T/gitsiz"; mkdir -p "$GITSIZ"
( cd "$GITSIZ" && env -u LAYIHA_DEFTER bash "$SUT" ekle --slug kacak --konu "K" --dokuman "d.md" ) >/dev/null 2>&1
esit "G8 git-siz dizinde ekle rc=2" "2" "$?"
( cd "$GITSIZ" && env -u LAYIHA_DEFTER bash "$SUT" liste ) >/dev/null 2>&1
esit "G8 git-siz dizinde liste rc=2" "2" "$?"
esit "G8 ortak dizinde layiha defteri OLUŞMADI" "$ONCE8" "$(FOTO)"

echo
echo "=== G9 · mevcut davranış korundu (tescil disiplini regresyonu) ==="
sut durum bir-konu insa-edildi >/dev/null 2>&1; esit "G9 durum rc=0" "0" "$?"
esit "G9 insa-edildi otomatik tescil-kuyruğuna girdi" "bekliyor" \
  "$(python3 -c "import json;print([json.loads(l)['tescil']['durum'] for l in open('$D') if 'bir-konu' in l][0])")"
sut tescil bir-konu tescilli --vites TAM >/dev/null 2>&1
esit "G9 muhursuz TAM-tescil REDDEDİLDİ (sahte-tescil panzehiri)" "2" "$?"
sut tescil bir-konu tescilli --vites HAFIF --gerekce "tek-G kanıtı" >/dev/null 2>&1
esit "G9 HAFİF tescil gerekçeyle geçti" "0" "$?"
esit "G9 tescilli kayıt aktif listeden düştü" "0" "$(sut liste --porcelain | grep -c 'bir-konu')"
esit "G9 tescil sonrası şema-sürümü korundu" "1" \
  "$(python3 -c "import json;print([json.loads(l).get('v') for l in open('$D') if 'bir-konu' in l][0])")"

echo
echo "=== G10 · FİLO görünümü (K3): her satırda oda adı, YALNIZ başlık ==="
for oda in OdaBir OdaIki; do
  mkdir -p "$T/filo/$oda/_agents/handoff"
  LAYIHA_DEFTER="$T/filo/$oda/_agents/handoff/layiha-defteri.jsonl" HAT_ROOT="$T/filo/$oda" \
    bash "$SUT" ekle --slug "${oda,,}-is" --konu "$oda odasının işi" \
    --dokuman "d.md" --resume "GİZLİ-DEVAM-CÜMLESİ-$oda" >/dev/null 2>&1
done
F10="$(LAYIHA_FILO_KOK="$T/filo" bash "$FILO" 2>&1)"; RC10=$?
esit "G10 filo rc=0" "0" "$RC10"
var  "G10 birinci oda göründü"        "$F10" "OdaBir"
var  "G10 ikinci oda göründü"         "$F10" "OdaIki"
var  "G10 başlık basıldı"             "$F10" "odasının işi"
yok  "G10 devam-cümlesi BASILMADI (yalnız başlık)" "$F10" "GİZLİ-DEVAM-CÜMLESİ"
yok  "G10 doküman yolu BASILMADI"     "$F10" "d.md"
var  "G10 İ1 sınırı alt-notta söyleniyor" "$F10" "izole container"
esit "G10 toplam 2 layiha sayıldı" "1" "$(printf '%s' "$F10" | grep -c 'toplam 2 layiha')"
D10="$T/filo/OdaBir/_agents/handoff/layiha-defteri.jsonl"; ONCE10="$(sha256sum "$D10" | cut -d' ' -f1)"
LAYIHA_FILO_KOK="$T/filo" bash "$FILO" >/dev/null 2>&1
esit "G10 filo hiçbir deftere YAZMADI" "$ONCE10" "$(sha256sum "$D10" | cut -d' ' -f1)"
LAYIHA_FILO_KOK="$T/filo" bash "$FILO" --yok-boyle 2>/dev/null
esit "G10 filo tanınmayan bayrağı reddediyor" "2" "$?"

echo
echo "=== G11 · kuyruk-değişmezi: inşa bitmiş kayıt tescil kuyruğu DIŞINDA kalamaz ==="
# FIRSTHAND VAKA: L22 (youtube-ai-not-akisi) defterde durum=insa-edildi ama tescil.durum="yok" idi
# → ne "tescil bekleyen" listesinde göründü ne de kimse tescile sevk etti; 5 gün sessizce kayboldu.
# `durum` komutu kuyruğa sokuyordu, ama kayıt BAŞKA bir yoldan (elle düzenleme / kural konmadan önce
# yazılmış eski kayıt / dışarıdan üretilmiş satır) o hâle gelebiliyordu. Kapı artık okuma-anında.
D11="$T/kuyruk.jsonl"
cat > "$D11" <<'JSONL'
{"id":"L01","slug":"elle-bozulmus","konu":"Elle insa-edildi yapilmis kayit","tarih":"2026-07-24","durum":"insa-edildi","dokuman":"d.md","pr":"","resume":"x de","not":"","v":1,"proje":"OdaBir","tescil":{"durum":"yok","kart":"","ajan":"","tarih":"","muhur_ref":"","muhur_sha256":"","deneme":0,"vites":"","gerekce":""}}
{"id":"L02","slug":"muaf-olan","konu":"Sultan muaf tutmus","tarih":"2026-07-24","durum":"insa-edildi","dokuman":"d.md","pr":"","resume":"y de","not":"","v":1,"proje":"OdaBir","tescil":{"durum":"muaf","kart":"","ajan":"","tarih":"2026-07-24","muhur_ref":"","muhur_sha256":"","deneme":0,"vites":"","gerekce":"Sultan karari"}}
{"id":"L03","slug":"hala-insada","konu":"Insa bitmemis","tarih":"2026-07-24","durum":"insa-ediliyor","dokuman":"d.md","pr":"","resume":"z de","not":"","v":1,"proje":"OdaBir","tescil":{"durum":"yok","kart":"","ajan":"","tarih":"","muhur_ref":"","muhur_sha256":"","deneme":0,"vites":"","gerekce":""}}
JSONL
ONCE11="$(sha256sum "$D11" | cut -d' ' -f1)"
K11="$(LAYIHA_DEFTER="$D11" HAT_ROOT="$T/OdaBir" bash "$SUT" liste --tescil-bekleyen --porcelain 2>&1)"
var  "G11 elle bozulmuş kayıt kuyrukta göründü" "$K11" "L01"
yok  "G11 muaf kayıt kuyruğa ÇEKİLMEDİ (verdikt ezilmiyor)" "$K11" "L02"
yok  "G11 inşası bitmemiş kayıt kuyruğa girmedi"  "$K11" "L03"
esit "G11 liste hâlâ salt-okur (dosya değişmedi)" "$ONCE11" "$(sha256sum "$D11" | cut -d' ' -f1)"
H11="$(LAYIHA_DEFTER="$D11" HAT_ROOT="$T/OdaBir" bash "$SUT" liste --hepsi 2>&1)"
var  "G11 muaf kayıt hâlâ muaf görünüyor" "$H11" "muaf"

echo
echo "=== G12 · simetrik kapı: inşa geri alınınca kayıt kuyrukta ASILI kalmaz ==="
# FIRSTHAND VAKA: L23 (whatsapp-filo-erisimi) yarım çıktı → 'insa-bekliyor'a alındı, ama tescil
# alanı 'bekliyor' kaldı: aynı satırda hem "⏳ inşa bekliyor" hem "📋 tescil bekliyor" göründü.
# Giriş kapısı vardı, çıkış kapısı yoktu (2026-07-29).
D12="$T/cikis.jsonl"; : > "$D12"
sut12() { LAYIHA_DEFTER="$D12" HAT_ROOT="$T/OdaBir" bash "$SUT" "$@"; }
sut12 ekle --slug geri-alinan --konu "Yarim cikan is" --dokuman d.md --resume "x de" >/dev/null
sut12 durum L01 insa-edildi >/dev/null
esit "G12 önce kuyruğa girdi" "1" "$(sut12 liste --tescil-bekleyen --porcelain | grep -c '^L01')"
C12="$(sut12 durum L01 insa-bekliyor 2>&1)"
var  "G12 çıkış kullanıcıya SÖYLENİYOR" "$C12" "kuyruğundan ÇIKTI"
esit "G12 kuyruktan düştü" "0" "$(sut12 liste --tescil-bekleyen --porcelain | grep -c '^L01')"
esit "G12 kayıt kaybolmadı (hepsi'nde duruyor)" "1" "$(sut12 liste --hepsi --porcelain | grep -c '^L01')"
# VERDİKT VERİLMİŞ kayıt geri alınırsa karar EZİLMEZ — muaf, muaf kalır.
sut12 ekle --slug verdikti-olan --konu "Sultan muaf tuttu" --dokuman d.md --resume "y de" >/dev/null
sut12 durum L02 insa-edildi >/dev/null
sut12 tescil L02 muaf --gerekce "Sultan karari" >/dev/null
sut12 durum L02 insa-ediliyor >/dev/null
esit "G12 muaf verdikti EZİLMEDİ" "muaf" "$(sut12 liste --hepsi --porcelain | awk -F'\t' '$1=="L02"{print $4}')"

echo
echo "=== G13 · kanıt kalıcılığı: damga vurulurken mühür depoya alınır ==="
# FIRSTHAND VAKA: L14-L19'un tescil kayıtları mühür yollarını taşıyordu ama o dosyaların
# HİÇBİRİ depoda yoktu — hepsi geçici worktree'lerde üretilmiş, worktree kaldırılınca kanıt
# yok olmuştu. Defterde damga + parmak-izi vardı, dayandığı belge YOKTU (2026-07-29).
D13="$T/kanit.jsonl"; : > "$D13"
K13="$T/kok13"; mkdir -p "$K13"
DIS13="$T/gecici-worktree/_agents/tescil/k9001"; mkdir -p "$DIS13"
printf '{"verdikt":"GECTI","kart":"k9001"}\n' > "$DIS13/muhur-ozet.json"
printf '# MUHUR\nverdikt: GECTI\n' > "$DIS13/MUHUR.md"
sut13() { LAYIHA_DEFTER="$D13" HAT_ROOT="$K13" bash "$SUT" "$@"; }
sut13 ekle --slug kanit-testi --konu "Kanit kaliciligi" --dokuman d.md --resume "x de" >/dev/null
sut13 durum L01 insa-edildi >/dev/null
sut13 tescil L01 tescilli --vites TAM --kart k9001 --muhur "$DIS13/MUHUR.md" >/dev/null 2>&1
esit "G13 tescil rc=0" "0" "$?"
esit "G13 mühür depoya kopyalandı"      "1" "$(test -f "$K13/_agents/tescil/k9001/MUHUR.md" && echo 1 || echo 0)"
esit "G13 özet de kopyalandı"           "1" "$(test -f "$K13/_agents/tescil/k9001/muhur-ozet.json" && echo 1 || echo 0)"
esit "G13 dış kaynak SİLİNMEDİ (kopya, taşıma değil)" "1" "$(test -f "$DIS13/MUHUR.md" && echo 1 || echo 0)"
R13="$(sut13 liste --hepsi --porcelain | awk -F'\t' '$1=="L01"{print $4}')"
esit "G13 kayıt tescilli"               "tescilli" "$R13"
# İkinci damga denemesi mevcut kanıtı EZMEZ
printf 'DEGISTIRILMIS\n' > "$K13/_agents/tescil/k9001/MUHUR.md"
sut13 tescil L01 tescilli --vites TAM --kart k9001 --muhur "$DIS13/MUHUR.md" >/dev/null 2>&1
esit "G13 mevcut kanıt üzerine YAZILMADI" "1" "$(grep -c DEGISTIRILMIS "$K13/_agents/tescil/k9001/MUHUR.md")"

echo
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
