#!/usr/bin/env bash
# notion.test.sh — notion-erisim ÇEVRİMDIŞI sınavı (ağ/Notion/kasa GEREKTİRMEZ).
# Sahte-Notion (notion-stub.py) 127.0.0.1'de koşar; gerçek api.notion.com'a HİÇ çıkılmaz —
# CI'da Notion yok; canlı çağrı bağlansaydı sahte-yeşil üretirdi. Canlı duman-testi PR gövdesinde.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$DIR/notion.sh"
G=0; K=0
gec(){ G=$((G+1)); printf '  ✓ %s\n' "$1"; }
kal(){ K=$((K+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"
STUB_PID=""
temizle(){ [ -n "$STUB_PID" ] && kill "$STUB_PID" 2>/dev/null; rm -r "$TMP" 2>/dev/null; }
trap temizle EXIT

echo "== notion.test.sh =="

echo "T1 · sözdizimi"
bash -n "$S" && gec T1 || kal T1 "bash -n düştü"

echo "T2 · SALT-OKUR değişmezi: yazma ucu YOK"
kirli=0
grep -nE 'request *= *"(PATCH|DELETE|PUT)"' "$S" >/dev/null && { kirli=1; echo "    yazma-metodu bulundu"; }
grep -nE '_api POST +"?/v1/(pages|blocks|databases)[^"]*"?( |$)' "$S" | grep -v '/query' >/dev/null \
  && { kirli=1; echo "    POST yazma-ucu bulundu"; }
grep -nE 'cmd_(page_create|db_create|page_update|append|delete)' "$S" >/dev/null && { kirli=1; echo "    yazma-komutu bulundu"; }
[ "$kirli" -eq 0 ] && gec T2 || kal T2 "salt-okur ihlali"

echo "T3 · sır-hijyeni: token ARGV'de değil (-H yerine -K - stdin)"
if grep -nE '\-H +"?Authorization' "$S" >/dev/null; then kal T3 "Authorization -H ile argv'ye düşüyor"
elif grep -q 'curl -sS -K -' "$S"; then gec T3
else kal T3 "curl -K - stdin kalıbı yok"; fi

echo "T4 · Notion-Version başlığı GET ve POST dallarının İKİSİNDE de var"
n="$(grep -c 'Notion-Version: \${NOTION_VERSION}' "$S")"
[ "$n" -ge 2 ] && gec T4 || kal T4 "beklenen ≥2 başlık, bulunan $n"

echo "T5 · bilinmeyen komut reddedilir (yazma denemesi dâhil)"
out="$(bash "$S" page-create 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'SALT-OKUR'; } && gec T5 || kal T5 "rc=$rc çıktı='$out'"

echo "T6 · token YOKken doctor 'doğrulanmadı' der (uydurma-yeşil yok, rc=2)"
: > "$TMP/bos.env"
out="$(CORTEX_ACCESS_ENV="$TMP/bos.env" VAULT_CEK_BIN="$TMP/yok.sh" NOTION_TOKEN= bash "$S" doctor 2>&1)"; rc=$?
{ [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'DOĞRULANMADI'; } && gec T6 || kal T6 "rc=$rc çıktı='$out'"

# ── sahte-Notion'u başlat ────────────────────────────────────────────────────
python3 "$DIR/notion-stub.py" > "$TMP/port" 2>/dev/null &
STUB_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do PORT="$(cat "$TMP/port" 2>/dev/null)"; [ -n "$PORT" ] && break; sleep 0.3; done
[ -n "${PORT:-}" ] || { kal "STUB" "sahte sunucu başlamadı"; echo "SONUÇ: geçen=$G kalan=$K"; exit 1; }
printf 'export NOTION_TOKEN=%s\n' "sahte-jeton-test" > "$TMP/env"; chmod 600 "$TMP/env"
cagir(){ CORTEX_ACCESS_ENV="$TMP/env" VAULT_CEK_BIN="$TMP/yok.sh" NOTION_API_HOST="http://127.0.0.1:$PORT" bash "$S" "$@"; }

echo "T7 · doctor sahte-Notion'da yeşil (Notion-Version doğrulandı)"
out="$(cagir doctor 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'kimlik geçerli'; } && gec T7 || kal T7 "rc=$rc çıktı='$out'"

echo "T8 · YANLIŞ Notion-Version → dürüst kırmızı (400 validation_error, 'jeton geçersiz' DEĞİL)"
out="$(NOTION_API_VERSION=1999-01-01 cagir doctor 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'validation_error'; } && gec T8 || kal T8 "rc=$rc çıktı='$out'"

echo "T9 · db-query sayfalama: 2 istek → 3 satır (has_more/next_cursor gerçekten izleniyor)"
out="$(cagir db-query db-1 2>&1)"
printf '%s' "$out" | grep -q '3 satır · 2 istek' && gec T9 || kal T9 "çıktı='$out'"

echo "T10 · db-query --json: stdout SAF JSONL (özet stderr'e gider)"
n="$(cagir db-query db-1 --json 2>/dev/null | jq -s 'length' 2>/dev/null)"
[ "$n" = "3" ] && gec T10 || kal T10 "jq JSONL sayısı '$n' (beklenen 3)"

echo "T11 · db-list: tekrar eden kayıt TEKİLLEŞİR + imleç döngüsü kesilir"
out="$(cagir db-list 2>&1)"
{ printf '%s' "$out" | grep -q '2 veritabanı (tekil)' && printf '%s' "$out" | grep -q 'LİSTE KESİLDİ'; } \
  && gec T11 || kal T11 "çıktı='$out'"

echo "T12 · db-query olmayan veritabanı → dürüst 404 + paylaşım ipucu"
out="$(cagir db-query yok-db 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'object_not_found'; } && gec T12 || kal T12 "rc=$rc çıktı='$out'"

echo "T13 · file-download: files-OLMAYAN alan reddedilir"
out="$(cagir file-download sayfa-1 Marka "$TMP/indir" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'files tipinde değil'; } && gec T13 || kal T13 "rc=$rc çıktı='$out'"

echo "T14 · file-download: imzalı-URL ölü/süresi dolmuş → dürüst hata, sahte-başarı YOK"
out="$(cagir file-download sayfa-1 Ruhsat "$TMP/indir" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'süresi'; } && gec T14 || kal T14 "rc=$rc çıktı='$out'"
[ -e "$TMP/indir/0.png" ] && kal T14b "başarısız indirmede yarım dosya bırakıldı" || gec T14b

echo "T15 · page-get files/formula alanlarını jq-hatasız basar"
out="$(cagir page-get sayfa-1 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'jq: error' && printf '%s' "$out" | grep -q 'Ruhsat \[files\]'; } \
  && gec T15 || kal T15 "rc=$rc çıktı='$out'"

echo
echo "SONUÇ: geçen=$G kalan=$K"
[ "$K" -eq 0 ]
