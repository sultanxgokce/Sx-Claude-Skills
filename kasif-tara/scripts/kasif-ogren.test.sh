#!/usr/bin/env bash
# kasif-ogren.test.sh — KURAL HALKASI kapıları (ADR-025 K5).
# İZOLE: KASIF_TEST=1 + temp defterler → gerçek odaya ASLA yazmaz.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$DIR/kasif-ogren.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

Y="$T/yontem.jsonl"; K="$T/kaynaklar.jsonl"; M="$T/mucit.jsonl"; R="$T/tekrar.jsonl"
: > "$Y"; : > "$K"; : > "$M"; : > "$R"

kos(){ KASIF_TEST=1 KASIF_YONTEM_DEFTERI="$Y" KASIF_KAYNAKLAR="$K" KASIF_MUCIT_DEFTERI="$M" \
       KASIF_TEKRAR="$R" KASIF_TARIH="${TARIH:-2026-07-28}" bash "$SUT" "$@"; }

echo "== Y1: sözdizimi =="
bash -n "$SUT" 2>/dev/null && ok "bash -n temiz" || no "sözdizimi hatası"

echo "== Y2: EŞİK ALTI — 2 örnekten kural DOĞMAZ (rastlantı ≠ desen) =="
cat > "$K" <<'JSONL'
{"host":"kisir.example","ziyaret":1,"bulgu_idler":[]}
{"host":"kisir.example","ziyaret":1,"bulgu_idler":[]}
JSONL
OUT="$(kos --yaz)"
[ ! -s "$Y" ] && ok "2 örnekte defter boş kaldı" || no "eşik delindi: $(cat "$Y")"

echo "== Y3: EŞİĞE ULAŞINCA aday doğar =="
echo '{"host":"kisir.example","ziyaret":1,"bulgu_idler":[]}' >> "$K"
OUT="$(kos)"
grep -q 'DRY-RUN' <<<"$OUT" && ok "varsayılan DRY-RUN (kanon K05)" || no "varsayılan yazıyor: $OUT"
[ ! -s "$Y" ] && ok "dry-run hiçbir şey yazmadı" || no "dry-run yazdı"

echo "== Y4: --yaz ile aday yazılır, durum=aday (kural DEĞİL) =="
kos --yaz >/dev/null
[ "$(wc -l < "$Y")" = "1" ] && ok "1 aday yazıldı" || no "beklenen 1 satır, olan $(wc -l < "$Y")"
jq -e 'select(.tip=="kisir-kaynak" and .durum=="aday" and .ornek==3)' "$Y" >/dev/null \
  && ok "aday doğdu (kural değil), örnek=3" || no "şema/durum yanlış: $(cat "$Y")"

echo "== Y5: İDEMPOTENS — ikinci koşu ikinci kez yazmaz =="
kos --yaz >/dev/null
[ "$(wc -l < "$Y")" = "1" ] && ok "tekrar koşu çoğaltmadı" || no "duplicate doğdu"

echo "== Y6: TERFİ Sultan-onayı OLMADAN reddedilir (insan-adına yazma yasağı) =="
ERR="$T/e1"; kos terfi y0001 >/dev/null 2>"$ERR"; rc=$?
[ "$rc" -eq 2 ] && ok "onaysız terfi RC=2" || no "onay kapısı delik: rc=$rc"
grep -qi 'sultan' "$ERR" && ok "ret gerekçesi Sultan-onayına atıf yapıyor" || no "gerekçe yok"
jq -rs 'last|.durum' "$Y" | grep -q '^aday$' && ok "durum hâlâ aday" || no "durum değişti"

echo "== Y7: COOLDOWN dolmadan terfi reddedilir (7 gün) =="
ERR="$T/e2"; kos terfi y0001 --sultan-onay >/dev/null 2>"$ERR"; rc=$?
[ "$rc" -eq 2 ] && ok "cooldown içinde terfi RC=2" || no "cooldown delik: rc=$rc"
grep -qi 'cooldown' "$ERR" && ok "gerekçe cooldown diyor" || no "gerekçe belirsiz"

echo "== Y8: COOLDOWN dolunca + Sultan-onayı → kural olur =="
TARIH=2026-08-05 kos terfi y0001 --sultan-onay --gerekce "Sultan: doğru, oraya gitmeyelim" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "terfi geçti" || no "terfi başarısız: rc=$rc"
jq -rs 'last|.durum' "$Y" | grep -q '^kural$' && ok "durum=kural" || no "durum kural olmadı"

echo "== Y9: kararı verilmiş kural YENİDEN aday olarak doğmaz =="
ONCE="$(wc -l < "$Y")"; kos --yaz >/dev/null
[ "$(wc -l < "$Y")" = "$ONCE" ] && ok "terfi edilmiş desen yeniden doğmadı" || no "yeniden doğdu"

echo "== Y10: REDDİ gerekçesiz olmaz; reddedilen bir daha doğmaz =="
cat > "$M" <<'JSONL'
{"verdikt":"elendi","not":"zaten-var: scripts/x.sh"}
{"verdikt":"elendi","not":"zaten var, bkz scripts/y.sh"}
{"verdikt":"elendi","not":"ZATEN VAR — kodda mevcut"}
JSONL
kos --yaz >/dev/null
ID="$(jq -rs '[.[]|select(.tip=="elenen-sinif")]|last|.id' "$Y")"
[ -n "$ID" ] && [ "$ID" != "null" ] && ok "MUCİT gerekçelerinden sınıf-kuralı doğdu ($ID)" || no "elenen-sinif doğmadı"
kos reddi "$ID" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "gerekçesiz reddi RC=2" || no "gerekçe kapısı delik"
kos reddi "$ID" --gerekce "bu eleme aslında doğruydu" >/dev/null 2>&1
ONCE="$(wc -l < "$Y")"; kos --yaz >/dev/null
[ "$(wc -l < "$Y")" = "$ONCE" ] && ok "reddedilen desen yeniden doğmadı" || no "reddedilen yeniden doğdu"

echo "== Y11: GÜÇLÜ TEKRAR pozitif kuralı — ≥3 AYRI kaynak =="
: > "$Y"
cat > "$R" <<'JSONL'
{"dedup_key":"ajan hafizasi diske yazilmali","hostlar":["a.dev","b.dev"],"kez":2}
{"dedup_key":"ajan hafizasi diske yazilmali","hostlar":["a.dev","b.dev","c.dev"],"kez":3}
{"dedup_key":"tek kaynakli fikir","hostlar":["z.dev"],"kez":1}
JSONL
: > "$K"; : > "$M"
kos --yaz >/dev/null
jq -e 'select(.tip=="guclu-tekrar" and .anahtar=="ajan hafizasi diske yazilmali")' "$Y" >/dev/null \
  && ok "3 ayrı kaynaktan gelen fikir sinyal-kuralı oldu" || no "guclu-tekrar doğmadı"
jq -e 'select(.anahtar=="tek kaynakli fikir")' "$Y" >/dev/null 2>&1 \
  && no "tek kaynaktan kural doğdu (eşik delik)" || ok "tek kaynak kural doğurmadı"

echo "== Y12: LİSTE görünümü kural/aday ayrımını basar =="
OUT="$(kos liste)"
grep -q 'ADAYLAR' <<<"$OUT" && grep -q 'KURALLAR' <<<"$OUT" \
  && ok "liste iki bölümü de basıyor" || no "liste eksik: $OUT"

echo "== Y13: BOŞ DEFTER — hiç veri yoksa çökmez, 0 döner =="
: > "$K"; : > "$M"; : > "$R"; : > "$Y"
kos >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "boş defterle rc=0" || no "boş defterde çöktü: rc=$rc"

echo "== Y14: LLM ÇAĞRISI YOK (enjeksiyon yüzeyi sıfır) =="
grep -qE 'claude|curl|WebFetch|openrouter' "$SUT" && no "script LLM/ağ çağırıyor — enjeksiyon yüzeyi açıldı" \
  || ok "script hiçbir LLM/ağ çağrısı içermiyor"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] && echo "GOLDEN: TEMİZ ✓" || echo "GOLDEN: FAIL ✗"
exit "$FAIL"
