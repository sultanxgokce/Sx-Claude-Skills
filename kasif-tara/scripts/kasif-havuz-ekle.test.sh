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

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
