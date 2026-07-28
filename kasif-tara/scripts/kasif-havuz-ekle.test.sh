#!/usr/bin/env bash
# kasif-havuz-ekle.test.sh — çift-önleme + birim-etiketi golden'ları (k0124).
# KASIF_TEST=1 + temp-havuz: gerçek havuza ASLA yazmaz.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$DIR/kasif-havuz-ekle.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

H="$TMP/havuz.jsonl"
kos(){ KASIF_TEST=1 KASIF_HAVUZ="$H" KASIF_TARIH=2026-07-17 bash "$SUT" "$@" 2>/dev/null; }

echo "== T1: geçerli aday eklenir + cell(s01) + dedup_key alanları doğar =="
: > "$H"
echo '[{"baslik":"Keşşaf deneme bulgusu birinci","detay":"d","kanit":"https://ör.nek/a"}]' > "$TMP/g1.json"
OUT="$(kos --girdi "$TMP/g1.json")"
echo "$OUT" | jq -e '.eklenen==1' >/dev/null && ok "eklenen=1" || no "eklenme başarısız: $OUT"
jq -e 'select(.id=="b0001") | .cell=="s01" and .dedup_key=="keşşaf deneme bulgusu birinci"' "$H" >/dev/null \
  && ok "cell=s01 + dedup_key=norm(başlık) yazıldı" || no "filo-alanları eksik/yanlış"

echo "== T2: birebir-tekrar ikinci koşuda anahtar-atlanır (idempotent) =="
OUT="$(kos --girdi "$TMP/g1.json")"
echo "$OUT" | jq -e '.eklenen==0 and (.atlanan_anahtar + .atlanan_dup) >= 1' >/dev/null \
  && ok "tekrar-koşu 0 ekledi" || no "idempotens kırık: $OUT"
[ "$(wc -l < "$H")" -eq 1 ] && ok "havuz hâlâ 1 satır" || no "havuz satır-sayısı bozuk"

echo "== T3: Jaccard'ın KAÇIRDIĞI kısa-token başlıkta anahtar yakalar =="
: > "$H"
echo '[{"baslik":"S3 v2 uç","detay":"d","kanit":"https://ör.nek/k1"}]' > "$TMP/g3.json"
kos --girdi "$TMP/g3.json" >/dev/null
echo '[{"baslik":"s3  V2 uç!!","detay":"farklı-detay","kanit":"https://ör.nek/k2"}]' > "$TMP/g3b.json"
OUT="$(kos --girdi "$TMP/g3b.json")"
echo "$OUT" | jq -e '.eklenen==0 and .atlanan_anahtar==1 and .atlanan_dup==0' >/dev/null \
  && ok "kısa-token varyantı YALNIZ anahtarla yakalandı (Jaccard kör-noktası kapandı)" \
  || no "anahtar-katmanı yakalamadı: $OUT"

echo "== T4: CELL_ID=s02 → cell etiketi s02 (birim-ayrımı) =="
: > "$H"
OUT="$(CELL_ID=s02 kos --girdi "$TMP/g1.json")"
jq -e 'select(.id=="b0001") | .cell=="s02"' "$H" >/dev/null && ok "s02-etiketi yazıldı" || no "cell-etiketi yanlış"

echo "== T5: eski alansız-satır (göç yok) aynı-başlık adayı yine bloklar =="
: > "$H"
echo '{"id":"b0001","kaynak":"kasif","tip":"bulgu","baslik":"Eski usül kayıt başlığı","detay":"d","kanit":"k","tarih":"2026-07-01","durum":"ham","kart":null}' > "$H"
echo '[{"baslik":"eski usül kayıt başlığı","detay":"yeni","kanit":"https://ör.nek/y"}]' > "$TMP/g5.json"
OUT="$(kos --girdi "$TMP/g5.json")"
echo "$OUT" | jq -e '.eklenen==0' >/dev/null && ok "alansız eski-satır okuma-anında norm'landı, bloke etti" || no "geriye-uyum kırık: $OUT"

echo "== T6: işlenmiş (durum≠ham/aday) eski kayıt YENİDEN-girişi engellemez (nüks=sinyal) =="
: > "$H"
echo '{"id":"b0001","kaynak":"kasif","tip":"bulgu","baslik":"Nüks eden mesele kaydı","detay":"d","kanit":"k","tarih":"2026-06-01","durum":"islendi","kart":"k0001","dedup_key":"nüks eden mesele kaydı"}' > "$H"
echo '[{"baslik":"Nüks eden mesele kaydı","detay":"tekrar görüldü","kanit":"https://ör.nek/n"}]' > "$TMP/g6.json"
OUT="$(kos --girdi "$TMP/g6.json")"
echo "$OUT" | jq -e '.eklenen==1' >/dev/null && ok "işlenmiş-kayıt nüksü yeniden girebildi" || no "nüks-kuralı kırık: $OUT"

echo "== T6b: ham-durumda Jaccard-benzeri başlık HÂLÂ bloklar (mevcut koruma aynen) =="
: > "$H"
echo '{"id":"b0001","kaynak":"kasif","tip":"bulgu","baslik":"Önemli mesele kaydı hakkında bulgu","detay":"d","kanit":"k","tarih":"2026-07-01","durum":"ham","kart":null}' > "$H"
echo '[{"baslik":"önemli mesele kaydı hakkında bulgular","detay":"benzer","kanit":"https://ör.nek/b"}]' > "$TMP/g6b.json"
OUT="$(kos --girdi "$TMP/g6b.json")"
echo "$OUT" | jq -e '.eklenen==0 and .atlanan_dup==1' >/dev/null && ok "ham-kayıt Jaccard-koruması aynen" || no "Jaccard-katmanı zayıfladı: $OUT"

echo "== T7: parti-içi çift → ilk kazanır, ikinci anahtar-atlanır =="
: > "$H"
echo '[{"baslik":"Parti içi tekrar denemesi","detay":"1","kanit":"k1"},{"baslik":"parti  içi tekrar denemesi!","detay":"2","kanit":"k2"}]' > "$TMP/g7.json"
OUT="$(kos --girdi "$TMP/g7.json")"
echo "$OUT" | jq -e '.eklenen==1 and .atlanan_anahtar==1' >/dev/null && ok "parti-içi tekilleşti" || no "parti-içi çift geçti: $OUT"

echo "== T8: 2-İSTEMCİ eşzamanlılık — aynı aday iki paralel koşuda TEK satır (flock+anahtar) =="
: > "$H"
echo '[{"baslik":"Eşzamanlı yarış bulgusu","detay":"d","kanit":"https://ör.nek/r"}]' > "$TMP/g8.json"
kos --girdi "$TMP/g8.json" >/dev/null 2>&1 &
P1=$!
kos --girdi "$TMP/g8.json" >/dev/null 2>&1 &
P2=$!
wait "$P1" "$P2"
SAT="$(grep -c '"eşzamanlı yarış bulgusu"' "$H" || true)"
[ "$SAT" -eq 1 ] && ok "iki paralel istemci → havuzda TEK kayıt (A2 kabul-kriteri)" || no "yarış-durumu: $SAT kayıt"

echo "== T9: fail-closed korundu — kanıtsız aday şema-atlanır, rc=0 =="
: > "$H"
echo '[{"baslik":"Kanıtsız aday burada","detay":"d","kanit":""}]' > "$TMP/g9.json"
OUT="$(kos --girdi "$TMP/g9.json")"; RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | jq -e '.eklenen==0 and .atlanan_gecersiz==1' >/dev/null \
  && ok "şema-süzgeci aynen" || no "fail-closed bozuldu (rc=$RC): $OUT"

echo "== T10: KASIF_TEST'siz yabancı-havuz reddi (SF1 güvenlik-değişmezi) =="
KASIF_HAVUZ="$TMP/baska.jsonl" bash "$SUT" --girdi "$TMP/g1.json" >/dev/null 2>&1
[ $? -eq 2 ] && ok "kanonik-havuz-dışı hedef exit=2" || no "SF1 delindi"


# ══════════════════════════════════════════════════════════════════════════════════════════
# L24 F6 · KAŞİF HAFIZASI (yazma ucu) — H1..H8
# Bu bloklar üç defterin gerçekten dolduğunu ve iki güvenlik sözleşmesinin (hermetik kalkan,
# fail-soft) tuttuğunu sınar. Hepsi izole $TMP altında; gerçek deftere dokunmaz (H7 bunu KANITLAR).
# ══════════════════════════════════════════════════════════════════════════════════════════
HD="$TMP/kasif"; mkdir -p "$HD"
HV="$TMP/hafiza-havuz.jsonl"; : > "$HV"
hkos(){ KASIF_TEST=1 KASIF_HAVUZ="$HV" KASIF_HAFIZA_DIR="$HD" KASIF_TARIH=2026-07-27 bash "$SUT" "$@" 2>/dev/null; }

echo ""
echo "== H1: tur etiketi — her bulgu hangi turda geldiğini taşır =="
printf '[{"baslik":"Birinci hafiza denemesi bulgusu","detay":"d","kanit":"https://ornek.dev/blog/bir"},{"baslik":"Ikinci hafiza denemesi bulgusu","detay":"d","kanit":"https://baska.io/yazi/iki"}]' > "$TMP/h1.json"
hkos --girdi "$TMP/h1.json" >/dev/null
t1="$(jq -r '.tur // ""' "$HV" | sort -u | tr '\n' ' ' | tr -d ' ')"
[ "$t1" = "t20260727-1" ] && ok "tur=t20260727-1 iki bulguya da yazıldı" || no "tur etiketi: [$t1]"

echo "== H2: kaynak kütüphanesi — hangi adrese gidildi, ne getirdi =="
[ -f "$HD/kaynaklar.jsonl" ] && ok "kaynaklar.jsonl oluştu" || no "kaynaklar.jsonl YOK"
[ "$(wc -l < "$HD/kaynaklar.jsonl" 2>/dev/null)" = "2" ] && ok "iki ayrı kaynak kaydedildi" || no "kaynak sayısı"
z="$(jq -r 'select(.url_key=="ornek.dev/blog/bir") | "\(.ziyaret)/\(.verim)"' "$HD/kaynaklar.jsonl" 2>/dev/null)"
[ "$z" = "1/1" ] && ok "ziyaret=1 verim=1" || no "ilk ziyaret sayacı: [$z]"

echo "== H3: AYNI kaynağa ikinci ziyaret — sayaç artar, geçmiş korunur =="
printf '[{"baslik":"Ucuncu bambaska bir hafiza bulgusu","detay":"d","kanit":"https://ornek.dev/blog/bir"}]' > "$TMP/h3.json"
hkos --girdi "$TMP/h3.json" >/dev/null
z2="$(jq -r 'select(.url_key=="ornek.dev/blog/bir") | "\(.ziyaret)/\(.verim)"' "$HD/kaynaklar.jsonl" 2>/dev/null)"
[ "$z2" = "2/2" ] && ok "ziyaret=2 verim=2 (aynı adres, yeni bulgu)" || no "ikinci ziyaret: [$z2]"
[ "$(jq -r 'select(.url_key=="ornek.dev/blog/bir") | (.turlar|length)' "$HD/kaynaklar.jsonl")" = "2" ] \
  && ok "iki tur da kaynağa iliştirildi" || no "turlar birikmedi"

echo "== H4: TEKRAR SİNYALİ — dedup'ta düşen aday sessizce yok olmaz =="
printf '[{"baslik":"Birinci hafiza denemesi bulgusu","detay":"d","kanit":"https://ucuncu.com/ayni-fikir"}]' > "$TMP/h4.json"
onceki="$(wc -l < "$HV")"
hkos --girdi "$TMP/h4.json" >/dev/null
[ "$(wc -l < "$HV")" = "$onceki" ] && ok "havuz BÜYÜMEDİ (dedup korundu)" || no "dedup delindi"
[ -f "$HD/tekrar.jsonl" ] && ok "tekrar.jsonl oluştu" || no "tekrar.jsonl YOK"
grep -q 'ucuncu.com' "$HD/tekrar.jsonl" 2>/dev/null \
  && ok "kaybolan fikrin GELDİĞİ KAYNAK kaydedildi" || no "hostlar yazılmadı"

echo "== H5: BOŞ TUR görünür (B8 — 'bulamadı' ile 'hiç bakmadı' ayrışır) =="
echo '[]' > "$TMP/h5.json"
hkos --girdi "$TMP/h5.json" >/dev/null
son="$(tail -1 "$HD/seyir.jsonl" 2>/dev/null)"
[ "$(jq -r '.eklenen' <<<"$son" 2>/dev/null)" = "0" ] && ok "boş tur seyre YAZILDI (eklenen=0)" || no "boş tur kayboldu"
[ "$(jq -r '.aday' <<<"$son" 2>/dev/null)" = "0" ] && ok "aday=0 kaydı doğru" || no "aday alanı"

echo "== H6: tur numarası seyirden artar (havuzdan DEĞİL — boş tur da sayılır) =="
turlar="$(jq -r '.tur' "$HD/seyir.jsonl" | tr '\n' ' ')"
[ "$turlar" = "t20260727-1 t20260727-2 t20260727-3 t20260727-4 " ] \
  && ok "dört tur sırayla numaralandı" || no "tur dizisi: [$turlar]"

echo "== H7: HERMETİK KALKAN — test modunda yol verilmezse ODANIN defterine yazmaz =="
# F3 dersi: mutasyon-testi bu kalkan olmadığı için ortak dizine iki kez sızdı, elle temizlik gerekti.
# ⚠️ Bu testin İLK hâli VAKUMDU: bu deponun kökünde _agents/kasif zaten YOK, dolayısıyla
#    "değişmedi" demek hiçbir şey kanıtlamıyordu. Şimdi GERÇEKTEN defteri OLAN sahte bir proje
#    kurulup KAŞİF onun içinde koşturuluyor — kalkan delinirse dizin dolar ve test düşer.
SAHTE="$TMP/sahte-proje"
mkdir -p "$SAHTE/_agents/kasif" "$SAHTE/_agents/handoff"
( cd "$SAHTE" && git init -q && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
: > "$SAHTE/_agents/handoff/bulgu-havuzu.jsonl"
onceden="$(ls -1 "$SAHTE/_agents/kasif" 2>/dev/null | sort | tr '\n' ',')"
( cd "$SAHTE" && KASIF_TEST=1 KASIF_HAVUZ="$SAHTE/_agents/handoff/bulgu-havuzu.jsonl" \
    KASIF_TARIH=2026-07-27 bash "$SUT" --girdi "$TMP/h1.json" ) >/dev/null 2>&1
sonradan="$(ls -1 "$SAHTE/_agents/kasif" 2>/dev/null | sort | tr '\n' ',')"
[ "$onceden" = "$sonradan" ] && ok "test modunda defter dizini BOŞ kaldı (kalkan tuttu)" \
  || no "SIZINTI: [$onceden] → [$sonradan]"

echo "== H7b: ama ÜRETİM modunda hafıza gerçekten yazılır (kalkan yalnız teste özel) =="
# Negatif testin ikizi: kalkan her şeyi susturuyor olsaydı H7 yanlış sebeple geçerdi.
: > "$SAHTE/_agents/handoff/bulgu-havuzu.jsonl"
( cd "$SAHTE" && KASIF_TARIH=2026-07-27 bash "$SUT" --girdi "$TMP/h1.json" ) >/dev/null 2>&1
[ -s "$SAHTE/_agents/kasif/seyir.jsonl" ] && ok "üretim modunda seyir defteri YAZILDI" \
  || no "üretimde de yazmıyor — kalkan fazla geniş"
[ -s "$SAHTE/_agents/kasif/kaynaklar.jsonl" ] && ok "üretim modunda kaynak kütüphanesi YAZILDI" \
  || no "kaynaklar yazılmadı"

echo "== H8: FAIL-SOFT — defter yazılamasa bile malzeme kaybolmaz =="
# Sözleşme: hafıza ikincildir. Yazılamazsa uyarır ama havuza ekleme AYNEN sürer.
KIRIK="$TMP/kirik-dizin"; : > "$KIRIK"   # dizin yerine DOSYA → mkdir/yazma imkânsız
: > "$TMP/fs-havuz.jsonl"
printf '[{"baslik":"Fail soft denemesi icin bulgu","detay":"d","kanit":"https://ornek.dev/fs"}]' > "$TMP/h8.json"
KASIF_TEST=1 KASIF_HAVUZ="$TMP/fs-havuz.jsonl" KASIF_HAFIZA_DIR="$KIRIK/alt" KASIF_TARIH=2026-07-27 \
  bash "$SUT" --girdi "$TMP/h8.json" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "hafıza yazılamadı ama rc=0 (ana iş bozulmadı)" || no "fail-soft delindi: rc=$rc"
[ "$(wc -l < "$TMP/fs-havuz.jsonl")" = "1" ] && ok "bulgu havuza YİNE de eklendi" || no "malzeme kayboldu"

echo "== R1: ROL-KAPISI — MUCİT rolündeki alt-ajan havuza YAZAMAZ (ADR-025 K4) =="
: > "$TMP/rol-havuz.jsonl"
printf '[{"baslik":"Rol kapisi denemesi icin bulgu","detay":"d","kanit":"https://ornek.dev/rol"}]' > "$TMP/r1.json"
ERR="$TMP/rol.err"
LAYIHA_ROL=mucit KASIF_TEST=1 KASIF_HAVUZ="$TMP/rol-havuz.jsonl" KASIF_TARIH=2026-07-28 \
  bash "$SUT" --girdi "$TMP/r1.json" >/dev/null 2>"$ERR"
rc=$?
[ "$rc" -eq 2 ] && ok "yanlış-rol RC=2 ile reddedildi" || no "rol-kapısı delik: rc=$rc"
grep -q 'K4' "$ERR" && ok "ret gerekçesi K4'e atıf yapıyor" || no "ret sessiz/gerekçesiz"
[ ! -s "$TMP/rol-havuz.jsonl" ] && ok "reddedilen koşu havuza HİÇBİR ŞEY yazmadı" || no "yazma sızdı"

echo "== R2: doğru rol + rolsüz koşu çalışır (kapı fazla geniş değil) =="
LAYIHA_ROL=kasif KASIF_TEST=1 KASIF_HAVUZ="$TMP/rol-havuz.jsonl" KASIF_TARIH=2026-07-28 \
  bash "$SUT" --girdi "$TMP/r1.json" >/dev/null 2>&1
[ "$(wc -l < "$TMP/rol-havuz.jsonl")" = "1" ] && ok "LAYIHA_ROL=kasif normal ekledi" || no "doğru rol de bloklandı"
: > "$TMP/rol-havuz2.jsonl"
kos --girdi "$TMP/r1.json" >/dev/null
KASIF_TEST=1 KASIF_HAVUZ="$TMP/rol-havuz2.jsonl" KASIF_TARIH=2026-07-28 bash "$SUT" --girdi "$TMP/r1.json" >/dev/null 2>&1
[ "$(wc -l < "$TMP/rol-havuz2.jsonl")" = "1" ] && ok "rol BOŞKEN geriye-uyum korundu" || no "rolsüz koşu bozuldu"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
