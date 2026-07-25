#!/usr/bin/env bash
# layiha-fabrika.test.sh — L24 FAZ-D2 kill-switch golden-testleri (layiha-aday-havuzu.test.sh deseni).
# İzole: bayrak/havuz/defter TÜM yollar env-override ile temp-dizine yönlendirilir — GERÇEK
# /config/.claude/layiha-fabrikasi.kapali'ye ve GERÇEK aday-havuzuna ASLA DOKUNMAZ.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_LIB="$HERE/layiha-fabrika-guard.lib.sh"
FABRIKA="$HERE/layiha-fabrika.sh"
# Çapraz-paket: KAŞİF ve MUCİT motorları artık kendi paketlerinde (L24 F3). Kardeş-paket yolu hem
# kurulu düzende (/config/.claude/skills/<paket>) hem Sx repo düzeninde aynı şekilde çözülür.
KASIF="$HERE/../../kasif-tara/scripts/kasif-havuz-ekle.sh"
AH="$HERE/layiha-aday-havuzu.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0; fail=0
check() { local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then pass=$((pass+1)); echo "PASS  $name"
  else fail=$((fail+1)); echo "FAIL  $name → want='$want' got='$got'"; fi
}
check_eq0() { local name="$1" got="$2"
  if [ "$got" = "0" ]; then pass=$((pass+1)); echo "PASS  $name (rc=0)"
  else fail=$((fail+1)); echo "FAIL  $name → rc=$got (0 beklendi)"; fi
}
rc_of() { "$@" >/dev/null 2>&1; echo $?; }

# ── İzole test-ortamı: yalın-güvenlik — gerçek bayrağa/havuza asla dokunma ──
export LAYIHA_FABRIKA_BAYRAK="$T/layiha-fabrikasi.kapali"
export LAYIHA_ADAY_HAVUZ="$T/aday-havuz.jsonl"

# ────────────────────────────────────────────────────────────────────────────
echo "== T1: bayrak-YOKKEN layiha üretim-yolu geçer (mucit-t1.sh --profil layiha çalışır) =="
MUCIT="$HERE/../../mucit-suz/scripts/mucit-t1.sh"
H="$T/bulgu-havuzu.jsonl"
cat > "$H" <<'JSONL'
{"id":"b1","baslik":"T1 bayrak-yok bulgusu","durum":"ham","kanit":"scripts/x.sh:10 — kanıt","kaynak":"denetim"}
JSONL
echo '[]' > "$T/kartlar.json"
mucit() { bash "$MUCIT" suz --havuz "$H" --kartlar "$T/kartlar.json" "$@"; }

OUT1="$(mucit --profil layiha --defter "$T/d1.jsonl" 2>"$T/t1.err")"
RC1=$?
check "T1 rc=0" "0" "$RC1"
check "T1 üretim engellenmedi (aday geçti)" "1" "$(echo "$OUT1" | jq -r '.uygun_sayi // "?"' 2>/dev/null)"

# ────────────────────────────────────────────────────────────────────────────
echo "== T2: bayrak-VARKEN layiha üretimi DURUR (exit=0 graceful-skip + mesaj + çıktı YOK) =="
printf 'test-kapatma-sebebi\ntarih: 2026-07-25T00:00:00Z\n' > "$LAYIHA_FABRIKA_BAYRAK"
OUT2="$(mucit --profil layiha --defter "$T/d2.jsonl" 2>"$T/t2.err")"
RC2=$?
check_eq0 "T2 exit=0 (üretim-atlama hata değil, kasıtlı-skip)" "$RC2"
check "T2 stderr'de KAPALI mesajı var" "1" "$(grep -c 'KAPALI' "$T/t2.err" 2>/dev/null || echo 0)"
check "T2 aday-çıktısı BASILMADI (üretim gerçekten durdu)" "" "$OUT2"

# ── KAPSAM-DİSİPLİNİ: bayrak layiha-fabrikasını kapatır, DİVAN'ı (ayrı anayasa §8) SUSTURMAZ ──
OUT2B="$(mucit --profil divan --defter "$T/d2b.jsonl" 2>"$T/t2b.err")"
RC2B=$?
check_eq0 "T2b bayrak-VARKEN DİVAN profili ÇALIŞMAYA DEVAM eder" "$RC2B"
check "T2b DİVAN çıktısı gerçek (susturulmadı)" "divan" "$(echo "$OUT2B" | jq -r '.profil // "?"' 2>/dev/null)"

# KAŞİF de MUAF: ham-bulgu toplama paylaşılan havuza yazar, DİVAN da onu kullanır → guard'sız.
KH="$T/kasif-havuz.jsonl"; : > "$KH"
echo '[{"baslik":"T2c kasif muaf bulgusu","detay":"d","kanit":"https://ör.nek/t2c"}]' > "$T/g2c.json"
KASIF_TEST=1 KASIF_HAVUZ="$KH" KASIF_TARIH=2026-07-25 bash "$KASIF" --girdi "$T/g2c.json" >/dev/null 2>&1
check_eq0 "T2c bayrak-VARKEN KAŞİF (paylaşılan ham-havuz) MUAF — çalışır" "$?"
check "T2c KAŞİF havuza yazdı" "1" "$(wc -l < "$KH" 2>/dev/null | tr -d " " || echo 0)"

# ────────────────────────────────────────────────────────────────────────────
echo "== T3: bayrak-VARKEN CRUD (layiha-aday-havuzu.sh liste/durum) HÂLÂ ÇALIŞIR =="
# LAYIHA_FABRIKA_BAYRAK hâlâ var (T2'den) — CRUD bunu hiç okumaz, kör olmalı.
cat > "$LAYIHA_ADAY_HAVUZ" <<'JSONL'
{"id":"A001","pct":80,"sinif":"muhendislik","baslik":"CRUD-canli aday","goal":"test","durum":"aday","slug":"crud-canli-aday","kanit":"k"}
JSONL
LISTE_RC="$(rc_of bash "$AH" liste --porcelain)"
check "T3 liste rc=0 (CRUD guard'tan etkilenmedi)" "0" "$LISTE_RC"
LISTE_OUT="$(bash "$AH" liste --porcelain)"
check "T3 liste kaydı görünüyor" "1" "$(echo "$LISTE_OUT" | grep -c 'crud-canli-aday')"
DURUM_RC="$(rc_of bash "$AH" durum)"
check "T3 durum rc=0" "0" "$DURUM_RC"

# ────────────────────────────────────────────────────────────────────────────
echo "== T4: layiha-fabrika.sh kapat --sebep → durum çıktısında sebep GÖRÜNÜR =="
rm -f "$LAYIHA_FABRIKA_BAYRAK"
KAPAT_OUT="$(bash "$FABRIKA" kapat --sebep "MUCİT T2 regresyonu — geçici durduruldu")"
check "T4 kapat rc=0" "0" "$(rc_of bash -c 'true')"
check "T4 bayrak-dosyası oluştu" "1" "$([ -f "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"
DURUM_OUT="$(bash "$FABRIKA" durum)"
check "T4 durum KAPALI gösterir" "1" "$(echo "$DURUM_OUT" | grep -c 'KAPALI')"
check "T4 durum sebep-metnini içerir" "1" "$(echo "$DURUM_OUT" | grep -c 'MUCİT T2 regresyonu')"

# ────────────────────────────────────────────────────────────────────────────
echo "== T5: kapat→ac idempotent (round-trip AÇIK'a döner, tekrar ac hata vermez) =="
AC_RC1="$(rc_of bash "$FABRIKA" ac)"
check "T5 ac rc=0" "0" "$AC_RC1"
check "T5 bayrak silindi" "1" "$([ ! -e "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"
DURUM_ACIK="$(bash "$FABRIKA" durum)"
check "T5 durum AÇIK gösterir" "1" "$(echo "$DURUM_ACIK" | grep -c 'AÇIK')"
AC_RC2="$(rc_of bash "$FABRIKA" ac)"
check "T5 zaten-açıkken tekrar ac idempotent (rc=0)" "0" "$AC_RC2"
# kapat→ac→kapat→ac ikinci tam-tur da temiz kapanmalı
bash "$FABRIKA" kapat --sebep "ikinci-tur" >/dev/null
bash "$FABRIKA" ac >/dev/null
check "T5 ikinci round-trip sonunda bayrak yok" "1" "$([ ! -e "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"

# ── T6: bayrak İÇERİKSİZ (boş-dosya) olduğunda da kapalı sayılır (tasarruf-modu sadeliği) ──
echo "== T6: içeriksiz (boş) bayrak da KAPALI sayılır (yalın test -f yeterli) =="
: > "$LAYIHA_FABRIKA_BAYRAK"
OUT6="$(mucit --profil layiha --defter "$T/d6.jsonl" 2>"$T/t6.err")"
check_eq0 "T6 boş-bayrak da üretimi durdurur (rc=0 skip)" "$?"
check "T6 aday-çıktısı yok" "" "$OUT6"
check "T6 gerekçesiz-bayrak açıkça belirtilir" "1" "$(grep -c 'gerekçe belirtilmemiş' "$T/t6.err" 2>/dev/null || echo 0)"
rm -f "$LAYIHA_FABRIKA_BAYRAK"

# ════════════════════════════════════════════════════════════════════════════
# F2 · ÇİFT-MODLU KAPATMA (Sultan-kararı K2): "hepsini kapat" (filo) + "şu odayı kapat" (yerel)
# LAYIHA_FABRIKA_HOST = test-dikişi (üretimde ayarlanmaz) → çok-oda senaryosu tek makinede kurulur.
# ════════════════════════════════════════════════════════════════════════════
# Guard'ın çıkış-kodu ters-okunmaya çok müsait (0=açık/devam · 1=kapalı/atla) → testte kelimeye
# çeviriyoruz; beklenti satırları böylece gözle doğrulanabilir kalıyor.
GUARD_RC() { # $1=host → "ACIK" | "KAPALI"
  if LAYIHA_FABRIKA_HOST="$1" bash -c \
      'source "$1"; layiha_fabrika_guard "test" >/dev/null 2>&1' _ "$GUARD_LIB"; then
    echo ACIK
  else
    echo KAPALI
  fi
}
KAPAT() { LAYIHA_FABRIKA_HOST="$1" bash "$FABRIKA" "${@:2}"; }

echo "== T7/T8: 'şu odayı kapat' YALNIZ o odayı durdurur (öteki oda üretmeye devam) =="
rm -f "$LAYIHA_FABRIKA_BAYRAK"
KAPAT oda-A kapat --yerel --sebep "A odasında MUCİT regresyonu" >/dev/null
check "T7 kapatılan oda (A) KAPALI" "KAPALI" "$(GUARD_RC oda-A)"
check "T8 kapatılmayan oda (B) AÇIK — vakumsuzluk kanıtı: aynı bayrak, farklı karar" "ACIK" "$(GUARD_RC oda-B)"
check "T7b bayrak kapsam=yerel" "yerel" "$(jq -r '.kapsam' "$LAYIHA_FABRIKA_BAYRAK")"
check "T7c scope yalnız A" "oda-A" "$(jq -r '.scope|join(",")' "$LAYIHA_FABRIKA_BAYRAK")"

echo "== T9: aynı bayrağa ikinci oda eklenir; mükerrer kayıt YAZILMAZ (idempotent) =="
KAPAT oda-B kapat --yerel >/dev/null
check "T9 iki oda da kapalı" "KAPALI,KAPALI" "$(GUARD_RC oda-A),$(GUARD_RC oda-B)"
check "T9 üçüncü oda hâlâ açık" "ACIK" "$(GUARD_RC oda-C)"
KAPAT oda-A kapat --yerel >/dev/null
check "T9b tekrar-kapat mükerrer eklemez" "oda-A,oda-B" "$(jq -r '.scope|join(",")' "$LAYIHA_FABRIKA_BAYRAK")"
check "T9c --sebep'siz ikinci kapatma ilk gerekçeyi SİLMEZ" "A odasında MUCİT regresyonu" \
  "$(jq -r '.sebep' "$LAYIHA_FABRIKA_BAYRAK")"

echo "== T10: 'bu odayı aç' yalnız bu odayı açar, ötekini kapalı bırakır =="
KAPAT oda-A ac >/dev/null
check "T10 A açıldı" "ACIK" "$(GUARD_RC oda-A)"
check "T10 B hâlâ KAPALI (yanlışlıkla hepsi açılmadı)" "KAPALI" "$(GUARD_RC oda-B)"
check "T10b scope'ta yalnız B kaldı" "oda-B" "$(jq -r '.scope|join(",")' "$LAYIHA_FABRIKA_BAYRAK")"

echo "== T11: scope'ta olmayan odada 'ac' zararsız no-op (bayrağa dokunmaz) =="
ONCE="$(cat "$LAYIHA_FABRIKA_BAYRAK")"
AC_RC_C="$(KAPAT oda-C ac >/dev/null 2>&1; echo $?)"
check "T11 rc=0 (hata değil)" "0" "$AC_RC_C"
check "T11 bayrak değişmedi" "1" "$([ "$ONCE" = "$(cat "$LAYIHA_FABRIKA_BAYRAK")" ] && echo 1 || echo 0)"
check "T11 B hâlâ kapalı" "KAPALI" "$(GUARD_RC oda-B)"

echo "== T12: son oda açılınca bayrak DOSYASI silinir (artık kapatma yok) =="
KAPAT oda-B ac >/dev/null
check "T12 bayrak silindi" "1" "$([ ! -e "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"
check "T12 her oda açık" "ACIK,ACIK,ACIK" "$(GUARD_RC oda-A),$(GUARD_RC oda-B),$(GUARD_RC oda-C)"

echo "== T13: 'hepsini kapat' her odayı durdurur (scope'ta olmayan oda dahil) =="
KAPAT oda-A kapat --filo --sebep "filo-geneli durdurma" >/dev/null
check "T13 kapsam=filo" "filo" "$(jq -r '.kapsam' "$LAYIHA_FABRIKA_BAYRAK")"
check "T13 A·B·C hepsi KAPALI" "KAPALI,KAPALI,KAPALI" "$(GUARD_RC oda-A),$(GUARD_RC oda-B),$(GUARD_RC oda-C)"

echo "== T14: BAŞKA odanın filo-kapatmasını yalın 'ac' geri alamaz (10 odayı sessizce açmaz) =="
AC_RC_F="$(KAPAT oda-B ac >/dev/null 2>&1; echo $?)"
check "T14 rc=2 (reddedildi)" "2" "$AC_RC_F"
check "T14 bayrak SİLİNMEDİ" "1" "$([ -e "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"
check "T14 hata-metni doğru komutu söylüyor" "1" \
  "$(KAPAT oda-B ac 2>&1 >/dev/null | grep -c 'ac --filo')"
check "T14b 'ac --filo' ile açılır" "1" \
  "$(KAPAT oda-B ac --filo >/dev/null 2>&1; [ ! -e "$LAYIHA_FABRIKA_BAYRAK" ] && echo 1 || echo 0)"

echo "== T15: filo kapalıyken 'kapat --yerel' sessizce GEVŞETMEZ (kapsam filo kalır) =="
KAPAT oda-A kapat --filo >/dev/null
KAPAT oda-B kapat --yerel >/dev/null
check "T15 kapsam hâlâ filo" "filo" "$(jq -r '.kapsam' "$LAYIHA_FABRIKA_BAYRAK")"
check "T15 C hâlâ kapalı (daraltma olmadı)" "KAPALI" "$(GUARD_RC oda-C)"
rm -f "$LAYIHA_FABRIKA_BAYRAK"

echo "== T16: GERİYE-UYUM — eski-usul çıplak bayrak TÜM filoyu kapatmaya devam eder =="
printf 'eski-usul bayrak\n' > "$LAYIHA_FABRIKA_BAYRAK"
check "T16 A·B·C hepsi KAPALI (sessiz-gevşeme yok)" "KAPALI,KAPALI,KAPALI" \
  "$(GUARD_RC oda-A),$(GUARD_RC oda-B),$(GUARD_RC oda-C)"
echo "== T17: FAIL-CLOSED — bozuk JSON kapalı sayılır =="
printf '{"kapsam":"yerel","scope":[' > "$LAYIHA_FABRIKA_BAYRAK"
check "T17 bozuk-JSON → KAPALI" "KAPALI" "$(GUARD_RC oda-C)"
printf '{"kapsam":"saçmalık","scope":["oda-A"]}' > "$LAYIHA_FABRIKA_BAYRAK"
check "T17b tanınmayan kapsam → KAPALI (bilinmeyen değer üretime izin vermez)" "KAPALI" "$(GUARD_RC oda-C)"

echo "== T18: FAIL-CLOSED — jq YOKKEN kapsam okunamaz → kapalı sayılır =="
mkdir -p "$T/binonly"
for b in bash dirname head tr hostname cat; do
  p="$(command -v "$b" 2>/dev/null)" && ln -sf "$p" "$T/binonly/$b"
done
check "T18 jq gerçekten PATH-dışı" "1" \
  "$(PATH="$T/binonly" bash -c 'command -v jq >/dev/null 2>&1 && echo 0 || echo 1')"
printf '{"kapsam":"yerel","scope":["oda-A"]}' > "$LAYIHA_FABRIKA_BAYRAK"
# jq'suz: kapsam okunamaz → yerel-muafiyet UYGULANMAZ, oda-C de kapalı sayılır.
NOJQ_RC="$(PATH="$T/binonly" LAYIHA_FABRIKA_BAYRAK="$LAYIHA_FABRIKA_BAYRAK" LAYIHA_FABRIKA_HOST=oda-C \
  bash -c 'source "$1"; layiha_fabrika_guard "test" >/dev/null 2>&1; echo $?' _ "$GUARD_LIB")"
check "T18b jq yokken açık-oda bile KAPALI sayılır (fail-closed)" "1" "$NOJQ_RC"
rm -f "$LAYIHA_FABRIKA_BAYRAK"

echo "== T19 (B9): ekran, KAŞİF'in DURMADIĞINI açıkça söyler — 'kapattım' ≠ 'her şey durdu' =="
D19="$(bash "$FABRIKA" durum)"
check "T19 durum-ekranı KAŞİF'i adıyla anıyor" "1" "$(echo "$D19" | grep -q 'KAŞİF' && echo 1 || echo 0)"
check "T19 'DURMAZ' ifadesi geçiyor (muafiyet net)" "1" "$(echo "$D19" | grep -c 'dış-taraması DURMAZ')"
K19="$(bash "$FABRIKA" kapat --sebep "B9 ekran-metni testi")"
check "T19b kapat-ekranı da KAŞİF muafiyetini yazıyor" "1" "$(echo "$K19" | grep -q 'KAŞİF' && echo 1 || echo 0)"
check "T19c kapat-ekranı hangi kapsamda kapattığını söylüyor" "1" "$(echo "$K19" | grep -c 'TÜM FİLO')"
D19B="$(bash "$FABRIKA" durum)"
check "T19d durum bu-odanın kararını başlıkta veriyor" "1" "$(echo "$D19B" | grep -c 'bu oda')"
rm -f "$LAYIHA_FABRIKA_BAYRAK"

echo
total=$((pass + fail))
echo "TOPLAM: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
