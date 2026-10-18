#!/usr/bin/env bash
# cipa.sh sınavı — çıpa yazılıyor mu, compact önerisi ÇIPASIZ üretiliyor mu (fail-closed).
# Hermetik: gerçek çıpaya DOKUNMAZ, kendi geçici dizininde koşar.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARAC="$KOK/cipa.sh"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
# Çıpa artık AJAN BAŞINA dosyaya yazıyor (b0097); sınav kimliği sabitler ki yol tahmin edilmesin.
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="sinav"
C="$T/cipa/gunluk-plan-cipa.sinav.md"

echo "── ÇIPASIZ compact önerisi ÜRETİLMEZ (fail-closed · asıl kapı)"
bash "$ARAC" compact-onerisi >/dev/null 2>&1; kapi "K1 çıpa yokken öneri rc=3" "3" "$?"
kapi "K2 çıpa yokken çıktı da üretilmez" "0" "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'compact yapalım')"

echo "── çıpa yazılır ve GERİ OKUNUR"
bash "$ARAC" yaz --plan "1) ilk is | 2) ikinci is | 3) ucuncu is" >/dev/null 2>&1; kapi "K3 yaz rc=0" "0" "$?"
kapi "K4 dosya diskte" "1" "$([ -f "$C" ] && echo 1 || echo 0)"
kapi "K5 üç madde yazıldı" "3" "$(grep -c '^- \[' "$C" 2>/dev/null)"
kapi "K6 tarih çıpada" "1" "$(grep -c '2026-01-02' "$C" 2>/dev/null; true)"
bash "$ARAC" yaz >/dev/null 2>&1; kapi "K7 plansız yaz REDDEDİLİR (boş çıpa çıpa değildir)" "2" "$?"

echo "── çıpa VARKEN öneri üretilir"
bash "$ARAC" compact-onerisi >/dev/null 2>&1; kapi "K8 çıpa varken öneri rc=0" "0" "$?"
kapi "K9 öneri Sultan'a sorulacak cümleyi taşır (K8 tautoloji değil)" "1" \
     "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'compact yapalım mı')"
kapi "K10 öneri OTOMATİK yapmadığını SÖYLER" "1" \
     "$(bash "$ARAC" compact-onerisi 2>/dev/null | grep -c 'Otomatik YAPILMAZ')"

echo "── madde durumu tazelenir"
bash "$ARAC" tazele --madde 2 --durum kapandi --not "kanit var" >/dev/null 2>&1; kapi "K11 tazele rc=0" "0" "$?"
kapi "K12 ikinci madde KAPANDI" "1" "$(grep -c '^- \[x\] 2) ikinci is → KAPANDI · kanit var' "$C" 2>/dev/null; true)"
kapi "K13 öteki maddeler DOKUNULMADI" "2" "$(grep -c '^- \[ \]' "$C" 2>/dev/null; true)"
bash "$ARAC" tazele --madde 9 --durum kapandi >/dev/null 2>&1; kapi "K14 olmayan madde REDDEDİLİR" "1" "$?"
bash "$ARAC" tazele --madde 1 --durum uydurma >/dev/null 2>&1; kapi "K15 geçersiz durum REDDEDİLİR" "2" "$?"
bash "$ARAC" tazele --madde 3 --durum yarim >/dev/null 2>&1
kapi "K16 yarım madde işaretlenir (ertesi güne taşınacak olan)" "1" "$(grep -c '^- \[~\] 3) ucuncu is → YARIM' "$C" 2>/dev/null; true)"

echo "── tazeleme İKİ KEZ koşunca çoğaltmaz (idempotent)"
bash "$ARAC" tazele --madde 2 --durum kapandi --not "kanit var" >/dev/null 2>&1
kapi "K17 tek KAPANDI etiketi (üst üste yazmaz)" "1" "$(grep -c 'KAPANDI' "$C" 2>/dev/null; true)"

echo "── NÂZIR'ın bulduğu üç kusur (araç yazıldığı gün bulundu)"
# 🔴 K19: değersiz bayrak SONSUZ DÖNGÜ yapıyordu (shift 2 tek argümanda ilerlemiyor, işlemci %100).
#    Kapı zaman aşımıyla ölçer: 124 dönerse araç ASILMIŞ demektir ve bu BAŞARI SAYILMAZ.
for b in "--plan" "--madde" "--durum"; do
  timeout 5 bash "$ARAC" yaz $b >/dev/null 2>&1; rc=$?
  kapi "K19 değersiz $b → asılmaz, reddeder (rc=2)" "2" "$rc"
done
timeout 5 bash "$ARAC" yaz --plan --not x >/dev/null 2>&1
kapi "K19d bayrak-bayrak → değer verilmemiş sayılır" "2" "$?"
# K20: geri alınmış madde ayrı bir durumdur; kapanmış gibi görünmemeli.
bash "$ARAC" tazele --madde 1 --durum geri-alindi --not "vazgecildi" >/dev/null 2>&1
kapi "K20 geri alınan madde [-] işaretlenir" "1" "$(grep -c '^- \[-\] 1) ilk is → GERİ ALINDI' "$C" 2>/dev/null; true)"
bash "$ARAC" tazele --madde 1 --durum kapandi >/dev/null 2>&1
kapi "K20b geri alınmış madde kapandıya çevrilince ÜST ÜSTE YAZILMAZ" "0" \
     "$(grep -c 'GERİ ALINDI → KAPANDI' "$C" 2>/dev/null; true)"
kapi "K21 geçersiz durum hâlâ reddedilir (K20 kapıyı gevşetmedi)" "2" \
     "$(bash "$ARAC" tazele --madde 1 --durum uydurma >/dev/null 2>&1; echo $?)"

echo "── ÇIPA AJAN BAŞINA (b0097 · KÂŞİF/BASİRET buldu, kusur bendeydi)"
# 🔴 Niçin: ilk yazımda çıpa TEK dosyaydı ve `yaz` KESEREK yazıyordu; o dizin kutular
#    arası ortak olduğu için ikinci ajan birincinin planını SİLİYORDU. Ölçülmüş vaka var.
AT="$T/ajanli"; export GUNLUK_PLAN_CIPA_DIZ="$AT"
GUNLUK_PLAN_AJAN=BIRINCI bash "$ARAC" yaz --plan "1) birinci isi" >/dev/null 2>&1
GUNLUK_PLAN_AJAN=IKINCI  bash "$ARAC" yaz --plan "1) ikinci isi"  >/dev/null 2>&1
kapi "K22 iki ajan İKİ ayrı dosya" "2" "$(ls "$AT" 2>/dev/null | grep -c '^gunluk-plan-cipa\..*\.md$')"
kapi "K23 birincinin planı DURUYOR (ikinci ezmedi)" "1" \
     "$(grep -c 'birinci isi' "$AT/gunluk-plan-cipa.birinci.md" 2>/dev/null; true)"
kapi "K24 ikincinin planı kendi dosyasında" "1" \
     "$(grep -c 'ikinci isi' "$AT/gunluk-plan-cipa.ikinci.md" 2>/dev/null; true)"
kapi "K25 birinci dosyada ikincinin planı YOK (K23 tautoloji değil)" "0" \
     "$(grep -c 'ikinci isi' "$AT/gunluk-plan-cipa.birinci.md" 2>/dev/null; true)"
# Eski tek dosya duruyorsa EZİLMEDEN yanına taşınır (geriye dönük).
ET="$T/eski"; mkdir -p "$ET"; printf '# eski plan\n- [ ] 1) eski madde\n' > "$ET/gunluk-plan-cipa.md"
# 🔴 K28b · SALT-OKUR KOMUT DOSYA YARATMAZ (bağımsız göz tur 2): göç eskiden komut
#    ayrıştırılmadan ÖNCE koşuyordu; `oku`/`yol`/`compact-onerisi` bile dosya yaratıyordu.
#    Bu kapı o yan etkiyi yasaklıyor — ölçen araç ölçtüğü şeyi değiştirmemeli.
for kk in oku yol compact-onerisi; do
  GUNLUK_PLAN_CIPA_DIZ="$ET" GUNLUK_PLAN_AJAN=UCUNCU bash "$ARAC" "$kk" >/dev/null 2>&1
done
kapi "K28b salt-okur komutlar (oku·yol·compact-onerisi) dosya YARATMAZ" "0" \
     "$(ls "$ET" 2>/dev/null | grep -c '^gunluk-plan-cipa\.ucuncu\.md$')"
# K28c · salt-okur `oku` eski tek dosyayı KOPYALAMADAN okur (içerik kaybolmaz, dosya doğmaz)
kapi "K28c oku eski tek dosyayı kopyalamadan okur" "1" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$ET" GUNLUK_PLAN_AJAN=UCUNCU bash "$ARAC" oku 2>/dev/null | grep -c 'eski madde')"
# göç YAZMA işidir → `tazele` yapar (düzenlemek için dosyaya ihtiyacı var)
GUNLUK_PLAN_CIPA_DIZ="$ET" GUNLUK_PLAN_AJAN=UCUNCU bash "$ARAC" tazele --madde 1 --durum yarim >/dev/null 2>&1
kapi "K26 eski TEK dosya korunur (silinmez)" "1" "$(grep -c 'eski madde' "$ET/gunluk-plan-cipa.md" 2>/dev/null; true)"
kapi "K27 eski plan ajanın dosyasına TAŞINIR (kaybolmaz)" "1" \
     "$(grep -c 'eski madde' "$ET/gunluk-plan-cipa.ucuncu.md" 2>/dev/null; true)"
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="sinav"

# K28-K30 · `yol` komutu: BAŞKA araçların yolu TAHMİN etmemesi için tek kaynak (2026-10-05).
#   Ölçülmüş vaka: /gun-ortasi'nın cipa-ekle.sh'ı yolu kendi türetiyordu; ajan-başına dosyaya
#   geçince eski TEK dosyaya yazmaya devam etti → kimsenin okumadığı dosya + ortak kilit öldü.
YOL="$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="sinav" bash "$ARAC" yol 2>/dev/null)"
kapi "K28 yol, yaz'ın yazdığı dosyanın TA KENDİSİ" "$C" "$YOL"
rm -f "$T/cipa/gunluk-plan-cipa.yokajan.md"
kapi "K29 dosya YOKKEN de yol basar (rc=0) — 'nereye' ile 'yazdım mı' ayrı" "0" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=yokajan bash "$ARAC" yol >/dev/null 2>&1; echo $?)"
kapi "K30 yol AJANA göre değişir (tek dosyaya dönmez)" "0" \
     "$(a=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=bir bash "$ARAC" yol); \
        b=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=iki bash "$ARAC" yol); \
        [ "$a" != "$b" ] && echo 0 || echo 1)"

# ── K31-K35 · bağımsız gözün tur-2 bulguları (2026-10-05) ────────────────────
# K31 · Türkçe harf adı BOZMAZ. Ölçülmüş vaka: "MUAVİN" → "muav-n" (tr -c çok baytlı harfi
#   tanımıyor) — yani aracın sahibinin kendi adı bozuluyordu ve kimse görmüyordu.
kapi "K31 Türkçe ad bozulmaz (MUAVİN → muavin)" "gunluk-plan-cipa.muavin.md" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="MUAVİN" bash "$ARAC" yol | sed 's|.*/||')"
# K32 · Tamamen elenen ad BOŞ bırakılmaz (yol `…-cipa..md` oluyordu)
kapi "K32 tamamen elenen ad → bilinmiyor (boş değil)" "gunluk-plan-cipa.bilinmiyor.md" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="###" bash "$ARAC" yol | sed 's|.*/||')"
# K33 · İki AYRI ad tek dosyaya ÇÖKMEZ ("A!" ile "A?" ikisi de "a" oluyordu)
kapi "K33 temizlikte çakışan iki ad AYRI dosya" "0" \
     "$(a=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN='A!' bash "$ARAC" yol); \
        b=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN='A?' bash "$ARAC" yol); \
        [ "$a" != "$b" ] && echo 0 || echo 1)"
# K34 · KİLİT FAIL-CLOSED: kilit alınamıyorsa YAZMAZ. Eskiden `|| true` ile yazmaya geçiyordu.
#   Kilidi başka bir süreç tutuyorken yaz/tazele 10 sn bekler, alamazsa rc=1 verir.
KL="$T/cipa/gunluk-plan-cipa.kilitli.md"
GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=kilitli bash "$ARAC" yaz --plan "1) a" >/dev/null 2>&1
( exec 9>>"$KL.kilit"; flock 9; sleep 3 ) & kp=$!; sleep 0.4
t0=$(date +%s%N)
rk="$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN=kilitli timeout 20 bash "$ARAC" yaz --plan "1) b" >/dev/null 2>&1; echo $?)"
bk=$(( ($(date +%s%N)-t0)/1000000 )); wait "$kp" 2>/dev/null
kapi "K34 yaz dalı ortak kilidi BEKLER (kilitsiz kesmiyor)" "bekledi" \
     "$([ "$bk" -ge 1500 ] && echo bekledi || echo "beklemedi(${bk}ms)")"
# K35 · kilit DOSYASI açılamıyorsa yazma YAPILMAZ (dizin salt-okur)
RO="$T/salt-okur"; mkdir -p "$RO"; printf '# x\n- [ ] 1) a\n' > "$RO/gunluk-plan-cipa.ro.md"; chmod 500 "$RO"
kapi "K35 kilit açılamıyorsa rc=1 (fail-open değil)" "1" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$RO" GUNLUK_PLAN_AJAN=ro bash "$ARAC" tazele --madde 1 --durum kapandi >/dev/null 2>&1; echo $?)"
chmod 700 "$RO"

echo "── GERÇEK çıpaya dokunulmadı"
kapi "K18 sınav kendi dizininde kaldı" "1" "$(printf '%s' "$C" | grep -c "^$T/" )"

# ── K36-K38 · `ajan` komutu: kimliğin TEK KAYNAĞI (2026-10-06) ───────────────
#   Ölçülmüş vaka: ölçüm aracı (olc.sh) "dün nerede bıraktım" kaynağında SERDAR'ın defterini
#   ÇİVİLİ okuyordu — her ajana. Çare kimliği burada ikinci kez türetmek değil, SORMAKTIR.
kapi "K36 ajan, yol'daki dosya adıyla AYNI kimliği basar (iki yazım yok)" "0" \
     "$(a=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="MUAVİN" bash "$ARAC" ajan); \
        y=$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="MUAVİN" bash "$ARAC" yol); \
        [ "$(basename "$y")" = "gunluk-plan-cipa.$a.md" ] && echo 0 || echo 1)"
kapi "K37 ajan SALT-OKUR: dosya YARATMAZ" "0" \
     "$(d="$T/cipa-ajan"; mkdir -p "$d"; GUNLUK_PLAN_CIPA_DIZ="$d" GUNLUK_PLAN_AJAN=sinavci bash "$ARAC" ajan >/dev/null 2>&1; ls "$d" | wc -l)"
kapi "K38 kimlik türetilemezse 'bilinmiyor' basar (uydurma ad YOK)" "bilinmiyor" \
     "$(GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_AJAN="###" bash "$ARAC" ajan 2>/dev/null)"

# ── T1-T14 · BUGÜN TABLOSU + KAPANIŞ KAPISI (gorev_01M54TNAQVP4PJ7M7MGZRPT7A7 · Sultan 17 Eki) ──
SEMA="$KOK/../sema"
echo "── ortak satır dilbilgisi: fikstür ⟂ beklenen (kokpit kapısıyla AYNI sözleşme)"
kapi "T1 tablo.py --json ortak fikstürü beklenen.json'a BİREBİR çevirir" "0" \
     "$(diff <(python3 "$KOK/tablo.py" "$SEMA/ornek-cipa.md" --json) "$SEMA/beklenen.json" >/dev/null 2>&1; echo $?)"
J() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print($2)" "$SEMA/beklenen.json"; }
kapi "T2 sahip metinden AYRILIR" "MUAVİN|Retro paketi gorev_01M54C4A56HDMS1H5SAWFCWSGE" "$(J x "d['maddeler'][0]['sahip']+'|'+d['maddeler'][0]['metin']")"
kapi "T3 kanıt nottan AYRILIR" "cloudtop #669|iki tur" "$(J x "d['maddeler'][0]['kanit']+'|'+d['maddeler'][0]['not']")"
kapi "T4 geçerli D1'li erteleme = ertelendi" "ertelendi" "$(J x "d['maddeler'][4]['durum']")"
kapi "T5 damgasız 'ERTELENDİ' = AÇIK (sessiz taşıma yok)" "acik" "$(J x "d['maddeler'][5]['durum']")"
kapi "T6 durum adları kokpit kapısıyla aynı küme" "acik,bitti,ertelendi,geri,yarim" "$(J x "','.join(sorted(set(m['durum'] for m in d['maddeler'])))")"

echo "── kapanış kapısı: açık madde varsa kapanış KABUL EDİLMEZ"
export GUNLUK_PLAN_AJAN="kapanis" ; CK="$T/cipa/gunluk-plan-cipa.kapanis.md"
bash "$ARAC" yaz --plan "1) birinci (sahip: MUAVİN) | 2) ikinci | 3) üçüncü" >/dev/null 2>&1
bash "$ARAC" kapanis >/dev/null 2>&1; kapi "T7 üç açık madde → kapanış rc=4" "4" "$?"
bash "$ARAC" tazele --madde 1 --durum kapandi --kanit "PR #12" >/dev/null 2>&1
kapi "T8 --kanit satıra 'kanıt:' parçası olarak yazılır" "1" "$(grep -c '^- \[x\] 1) birinci (sahip: MUAVİN) → KAPANDI · kanıt: PR #12$' "$CK"; true)"
kapi "T9 tabloda kanıt sütunu dolu" "1" "$(bash "$ARAC" tablo --md 2>/dev/null | grep -c '| 1 | birinci | MUAVİN | kapandı | PR #12 |')"
bash "$ARAC" tazele --madde 2 --durum ertelendi >/dev/null 2>&1; kapi "T10 D1'siz erteleme REDDEDİLİR" "2" "$?"
bash "$ARAC" tazele --madde 2 --durum ertelendi --d1 "Sultan dedi ki ertele" >/dev/null 2>&1; kapi "T11 biçimsiz D1 REDDEDİLİR (oturum-ref · kırpık · beyan zorunlu)" "2" "$?"
for _v in "bugün görüşelim" "erteleme" "ertelenmesin, bugün bitsin" "ertele istemiyorum" "ertele mi?" "erteleyelim mi bilmiyorum"; do
  bash "$ARAC" tazele --madde 2 --durum ertelendi --d1 "2026-01-02 Sultan: $_v (sohbet · sinav-oturum · \"bugün\" · beyan:SINAV)" >/dev/null 2>&1
  kapi "T11b biçimi doğru ama karar 'ertele' değil ('$_v') → REDDEDİLİR" "2" "$?"
done
kapi "T11c reddedilen D1 çıpaya yazılmadı (madde 2 hâlâ açık, ERTELENDİ yok)" "0" "$(grep -c "ERTELENDİ" "$CK"; true)"
printf '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-01-02\n\n## Maddeler\n- [-] 2) elle → ERTELENDİ · D1: 2026-01-02 Sultan: bugün görüşelim (sohbet · s · "x" · beyan:SINAV)\n- [-] 3) elle → ERTELENDİ · D1: 2026-01-02 Sultan: yarına ertelensin (sohbet · s · "x" · beyan:SINAV)\n- [-] 4) elle → ERTELENDİ · D1: 2026-01-02 Sultan: ertele istemiyorum (sohbet · s · "x" · beyan:SINAV)\n- [-] 5) elle → ERTELENDİ · D1: 2026-01-02 Sultan: Ertelendi (sohbet · s · "x" · beyan:SINAV)\n' > "$T/elle-d1.md"
kapi "T11d ayrıştırıcı: kararsız D1 'açık', küme içi karar 'ertelendi' okunur" "acik|ertelendi|acik|ertelendi" \
     "$(python3 "$KOK/tablo.py" "$T/elle-d1.md" --json | python3 -c "import json,sys; print('|'.join(m['durum'] for m in json.load(sys.stdin)['maddeler']))")"
bash "$ARAC" tazele --madde 2 --durum ertelendi --d1 '2026-01-02 Sultan: ertele (sohbet · sinav-oturum · "yarına kalsın" · beyan:SINAV)' >/dev/null 2>&1
kapi "T12 geçerli D1 ile ertelendi yazılır" "1" "$(grep -c '^- \[-\] 2) ikinci → ERTELENDİ · D1: 2026-01-02 Sultan: ertele' "$CK"; true)"
bash "$ARAC" kapanis >/dev/null 2>&1; kapi "T13 bir madde hâlâ açık → kapanış rc=4" "4" "$?"
bash "$ARAC" tazele --madde 3 --durum geri-alindi >/dev/null 2>&1; bash "$ARAC" kapanis >/dev/null 2>&1
kapi "T14 hepsi kapandı/ertelendi/geri → kapanış rc=0" "0" "$?"
kapi "T15 tablo --json yaşayan çıpada da aynı alanları verir" "MUAVİN|bitti|ertelendi|geri" \
     "$(bash "$ARAC" tablo --json 2>/dev/null | python3 -c "import json,sys; m=json.load(sys.stdin)['maddeler']; print('|'.join([m[0]['sahip'],m[0]['durum'],m[1]['durum'],m[2]['durum']]))")"
GUNLUK_PLAN_AJAN="yok-boyle" bash "$ARAC" kapanis >/dev/null 2>&1; kapi "T16 çıpa yoksa kapanış rc=1 (ölçemedim ≠ temiz)" "1" "$?"

echo "── tazele hedefi = tablodaki GÖRÜNÜR kimlik (bağımsız göz #357 tur 3: G1 hedeflenemiyordu)"
export GUNLUK_PLAN_AJAN="etiket" ; CE="$T/cipa/gunluk-plan-cipa.etiket.md"
bash "$ARAC" yaz --plan "1) bir | serbest iş | G1) gün ortası | G2) ikinci gün ortası" >/dev/null 2>&1
bash "$ARAC" tazele --madde G1 --durum kapandi --kanit "PR #7" >/dev/null 2>&1; r=$?
kapi "T19 --madde G1 gün ortası maddesini tazeler (fiziksel sırası 3 olsa da)" "0|1|0" \
     "$r|$(grep -c '^- \[x\] G1) gün ortası → KAPANDI · kanıt: PR #7$' "$CE"; true)|$(grep -c '^- \[x\] serbest' "$CE"; true)"
kapi "T20 tablo ile tazele aynı kimliği konuşur (G1 kapandı)" "1" "$(bash "$ARAC" tablo --md 2>/dev/null | grep -c '| G1 | gün ortası | — | kapandı | PR #7 |')"
bash "$ARAC" tazele --madde g2 --durum yarim >/dev/null 2>&1
kapi "T21 etiket büyük/küçük harf duyarsız (g2 → G2)" "1" "$(grep -c '^- \[~\] G2) ikinci gün ortası → YARIM$' "$CE"; true)"
bash "$ARAC" tazele --madde 2 --durum yarim >/dev/null 2>&1
kapi "T22 etiketsiz satır için sıra numarası hâlâ çalışır (2 → serbest iş)" "1" "$(grep -c '^- \[~\] serbest iş → YARIM$' "$CE"; true)"
once="$(md5sum < "$CE")"; bash "$ARAC" tazele --madde G9 --durum kapandi >/dev/null 2>&1; r=$?
kapi "T23 olmayan etiket rc=1 ve çıpa DEĞİŞMEZ" "1|aynı" "$r|$([ "$(md5sum < "$CE")" = "$once" ] && echo aynı || echo değişti)"
printf -- '- [ ] G1) kopya\n' >> "$CE"; once="$(md5sum < "$CE")"
bash "$ARAC" tazele --madde G1 --durum yarim >/dev/null 2>&1; r=$?
kapi "T24 aynı etiket iki maddede → rc=1, hiçbirine dokunulmaz (belirsizlik tahminle çözülmez)" "1|aynı" "$r|$([ "$(md5sum < "$CE")" = "$once" ] && echo aynı || echo değişti)"
export GUNLUK_PLAN_AJAN="sinav"
export GUNLUK_PLAN_AJAN="sinav"

echo "── kokpit kapısıyla uyum (terminal-onar/kapi/bugun.mjs — ortak fikstür)"
KAPI_BG="${GUNLUK_PLAN_KAPI_BUGUN:-$KOK/../../terminal-onar/kapi/bugun.mjs}"
if [ -f "$KAPI_BG" ] && command -v node >/dev/null 2>&1; then
  node "$SEMA/kapi-uyum.mjs" "$KAPI_BG" "$SEMA/ornek-cipa.md" "$SEMA/beklenen.json" >/dev/null 2>&1
  kapi "T17 kapının ayrıştırıcısı ortak fikstürü BİREBİR okur (muafiyet yok)" "0" "$?"
  # pozitif kontrol: '-' satırını atlayan bir kapı UYUMSUZ sayılmalı (araç farkı görebiliyor mu?)
  sed 's/\[\(\[\)\? ~xX-\]/[ ~xX]/' "$KAPI_BG" > "$T/bugun-bozuk.mjs"
  grep -q '\[ ~xX\]' "$T/bugun-bozuk.mjs" || sed -i 's/\[\([ ~xX]*\)-\]/[\1]/' "$T/bugun-bozuk.mjs"
  node "$SEMA/kapi-uyum.mjs" "$T/bugun-bozuk.mjs" "$SEMA/ornek-cipa.md" "$SEMA/beklenen.json" >/dev/null 2>&1
  kapi "T18 satır atlayan (bozuk) kapı UYUMSUZ yakalanır — ölçüm aracı farkı görüyor" "1" "$?"
else
  # 🟡 ÖLÇEMEDİM ≠ yeşil: kapının ayrıştırıcısı bu depoda yok (#355 birleşmeden) ya da node yok
  echo "  🟡 T17/T18 ÖLÇÜLEMEDİ: kapı ayrıştırıcısı yok ($KAPI_BG) — uyum bu koşumda sınanmadı"
fi

echo

echo "── kutulu tablo ZORUNLU biçim (Sultan 18 Eki 'bu tarz bir görünüm istiyorum')"
KUTU=$(python3 "$KOK/tablo.py" "$SEMA/ornek-cipa.md" 2>/dev/null)
kapi "T21 varsayılan çıktı çerçevelidir (┌ ├ └)" "3" "$(printf '%s\n' "$KUTU" | grep -c '^[┌├└]')"
kapi "T22 başlık satırı sayılı özet taşır (madde · ✅ · 🟡 · ⬜)" "1" "$(printf '%s\n' "$KUTU" | grep -c '^📋 BUGÜN · .* madde · [0-9]* ✅ kapandı · [0-9]* 🟡 yarım · [0-9]* ⬜ açık')"
kapi "T23 durum sütunu işaretle basılır, kelimeyle değil" "0" "$(printf '%s\n' "$KUTU" | grep -cE '│ +(kapandı|açık|yarım) +│')"
kapi "T24 beş durumun beşi işaretli (✅ 🟡 ⬜ ⏸ ➖)" "5" "$(for i in ✅ 🟡 ⬜ ⏸ ➖; do printf '%s\n' "$KUTU" | grep -q "$i" && echo x; done | wc -l)"
kapi "T25 --md eski düz biçimi verir (kokpit/metin kanalı)" "1" "$(python3 "$KOK/tablo.py" "$SEMA/ornek-cipa.md" --md 2>/dev/null | grep -c '^|---|---|---|---|---|$')"
MUT="$T/tablo-mut.py"; sed "s/ISARET\[m\['durum'\]\]/etiket(m)/" "$KOK/tablo.py" > "$MUT"
kapi "T26 mutant (işaret yerine kelime) T23'ü düşürür — kapı ısırıyor" "1" "$( [ "$(python3 "$MUT" "$SEMA/ornek-cipa.md" 2>/dev/null | grep -cE '│ +(kapandı|açık|yarım) +│')" -gt 0 ] && echo 1 || echo 0)"

kapi "T27 kutunun bütün satırları aynı görünür genişlikte (⏸ dahil, göz #369 tur 1)" "1" "$(printf '%s\n' "$KUTU" | grep '^[│┌├└]' | python3 -c "
import sys
G={'✅','🟡','⬜','⏸','➖'}
w=lambda s: sum(2 if (c in G or ord(c)>=0x1F000 or 0x2600<=ord(c)<=0x27BF) else 1 for c in s)
print(len(set(w(l.rstrip('\n')) for l in sys.stdin)))")"

echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
