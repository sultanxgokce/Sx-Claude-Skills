#!/usr/bin/env bash
# postaci-kutu.test.sh — kutu kurulumunun sınavı: KURU hiçbir şey yazmaz; --uygula yalnız (izinli kutu ∧ DAR jeton ∧ ön kontrol yeşil) iken kurar;
# geniş (200) / ölçülemeyen jeton kurmaz; idempotent; --kapat bayrağı siler; jeton değeri çıktıda geçmez. Sahte postane + sahte crontab; canlıya dokunmaz.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; K="$HERE/postaci-kutu.sh"
T="$(mktemp -d)"; temizle() { kill "${SRV:-0}" 2>/dev/null; find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; }; trap temizle EXIT
pass=0; fail=0; ok() { if eval "$2"; then pass=$((pass+1)); echo "PASS  $1"; else fail=$((fail+1)); echo "FAIL  $1"; fi; }
GIZLI="GIZLI-JETON-DEGERI-XYZ-0123"; echo "$GIZLI" > "$T/jeton"; mkdir -p "$T/oturum"
cat > "$T/crontab" <<'C'
#!/usr/bin/env bash
if [ "${1:-}" = "-l" ]; then cat "$CT_DEPO" 2>/dev/null; else if [ -n "${CT_YAZ_ENGEL:-}" ] && grep -q "postaci.mjs" "$CT_DEPO" 2>/dev/null; then exit 1; fi; cat > "$CT_DEPO"; fi
C
chmod +x "$T/crontab"
cat > "$T/sunucu.mjs" <<'S'
import http from 'node:http'; import fs from 'node:fs';
const d = process.argv[2];
const s = http.createServer((q, r) => {
  const var_ = (x) => fs.existsSync(d + '.' + x);
  if (q.url === '/ben') { r.writeHead(200); return r.end(JSON.stringify({ ok: true, kutu: var_('sohbet') ? 'sohbet' : var_('menzil') ? 'menzil' : 'code' })); }
  if (q.url.startsWith('/kutu/')) { r.writeHead(var_('genis') ? 200 : var_('olcumsuz') ? 500 : 403); return r.end('{}'); }
  r.writeHead(q.url === '/saglik' ? 200 : 404); r.end('{}');
});
s.listen(0, '127.0.0.1', () => fs.writeFileSync(d, String(s.address().port)));
S
node "$T/sunucu.mjs" "$T/port" & SRV=$!
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
export CT_DEPO="$T/ct-depo"
kos() { rm -f "$T/bayrak" "$T/ct-depo" "$T/kalici"; POSTANE_URL="http://127.0.0.1:$PORT" POSTACI_JETON="$T/jeton" OTURUM_DIZIN="$T/oturum" BAYRAK="$T/bayrak" CRONTAB_KOMUT="$T/crontab" KALICI_CRON="$T/kalici" FLOCK_DOSYA="$T/kilit" bash "$K" ${1:-} > "$T/cikti" 2>&1; echo $?; }
ok "S0 sözdizimi" 'bash -n "$K"'
rc=$(kos); ok "S1 KURU: rc 0, crontab ve bayrak YAZILMADI" '[ "$rc" = 0 ] && [ ! -e "$T/ct-depo" ] && [ ! -e "$T/bayrak" ] && grep -q "Şu an HİÇBİR ŞEY değişmedi" "$T/cikti"'
ok "S1b jeton değeri çıktıda geçmez" '! grep -q "$GIZLI" "$T/cikti"'
rc=$(kos --uygula); ok "S2 --uygula (dar jeton, code): kurulur, bayrak yazılır, satır crontab ve kalıcı kopyada TEK" '[ "$rc" = 0 ] && [ -e "$T/bayrak" ] && [ "$(grep -c "postaci.mjs" "$T/ct-depo")" = 1 ] && [ "$(grep -c "postaci.mjs" "$T/kalici")" = 1 ]'
POSTANE_URL="http://127.0.0.1:$PORT" POSTACI_JETON="$T/jeton" OTURUM_DIZIN="$T/oturum" BAYRAK="$T/bayrak" CRONTAB_KOMUT="$T/crontab" KALICI_CRON="$T/kalici" FLOCK_DOSYA="$T/kilit" bash "$K" --uygula >/dev/null 2>&1
ok "S2c cron satırına node MUTLAK yolla yazılır (cron PATH dar)" 'grep -qE " /[^ ]*node --disable-warning" "$T/ct-depo"'
ok "S2b ikinci --uygula idempotent: satır yine TEK" '[ "$(grep -c "postaci.mjs" "$T/ct-depo")" = 1 ]'
touch "$T/port.genis" "$T/port.menzil"; rc=$(kos --uygula); rm -f "$T/port.genis" "$T/port.menzil"
ok "S3 GENİŞ jeton (SERDAR kuyruğu 200, pilot olmayan kutu): rc 1, kurulum YOK, bayrak YOK" '[ "$rc" = 1 ] && [ ! -e "$T/ct-depo" ] && [ ! -e "$T/bayrak" ] && grep -q "jeton GENİŞ" "$T/cikti"'
rm -f "$T/ct-depo" "$T/bayrak"; touch "$T/port.genis"; rc=$(kos --uygula); rm -f "$T/port.genis"
ok "S3b pilot kutu (code) jetonu bilerek geniş: dar yetki şartı uygulanmaz, kurulur" '[ "$rc" = 0 ] && [ -e "$T/bayrak" ] && grep -q "pilot kutu" "$T/cikti"'
rm -f "$T/bayrak" "$T/kalici"; printf 'ESKI-SATIR\n' > "$T/ct-depo"; : > "$T/dosya-engel"
POSTANE_URL="http://127.0.0.1:$PORT" POSTACI_JETON="$T/jeton" OTURUM_DIZIN="$T/oturum" BAYRAK="$T/bayrak" CRONTAB_KOMUT="$T/crontab" KALICI_CRON="$T/dosya-engel/alt/kalici" FLOCK_DOSYA="$T/kilit" bash "$K" --uygula > "$T/cikti" 2>&1; rc=$?
ok "S3c kalıcı kopya yazılamazsa: rc 1, önceki crontab GERİ YÜKLENİR (kısmi kurulum yok), bayrak YOK" '[ "$rc" = 1 ] && [ ! -e "$T/bayrak" ] && ! grep -q "postaci.mjs" "$T/ct-depo" && grep -q "ESKI-SATIR" "$T/ct-depo"'
rm -f "$T/bayrak"; printf 'ESKI-SATIR\n' > "$T/ct-depo"; : > "$T/bayrak"
CT_YAZ_ENGEL=1 POSTANE_URL="http://127.0.0.1:$PORT" POSTACI_JETON="$T/jeton" OTURUM_DIZIN="$T/oturum" BAYRAK="$T/bayrak" CRONTAB_KOMUT="$T/crontab" KALICI_CRON="$T/dosya-engel/alt/kalici" FLOCK_DOSYA="$T/kilit" bash "$K" --uygula > "$T/cikti" 2>&1; rc=$?
ok "S3d geri alma da başarısız olursa: rc 1, 'GERİ ALMA BAŞARISIZ' basılır, başarı mesajı BASILMAZ, bayrak SİLİNİR (cron no-op)" '[ "$rc" = 1 ] && grep -q "GERİ ALMA BAŞARISIZ" "$T/cikti" && ! grep -q "doğrulandı" "$T/cikti" && [ ! -e "$T/bayrak" ]'
touch "$T/port.olcumsuz"; rc=$(kos --uygula); rm -f "$T/port.olcumsuz"
ok "S4 ölçülemeyen yetki (500): rc 1, kurulum YOK (ölçülemeyen yeşil sayılmaz)" '[ "$rc" = 1 ] && [ ! -e "$T/ct-depo" ] && [ ! -e "$T/bayrak" ] && grep -q "ÖLÇÜLEMEDİ" "$T/cikti"'
touch "$T/port.sohbet"; rc=$(kos --uygula); rm -f "$T/port.sohbet"
ok "S5 listede olmayan kutu (sohbet): rc 1, kurulum YOK" '[ "$rc" = 1 ] && [ ! -e "$T/ct-depo" ] && [ ! -e "$T/bayrak" ]'
touch "$T/port.menzil"; rc=$(kos --uygula); rm -f "$T/port.menzil"
ok "S6 listedeki ikinci kutu (menzil, dar jeton): kurulur" '[ "$rc" = 0 ] && [ -e "$T/bayrak" ]'
touch "$T/bayrak"; rc=$(BAYRAK="$T/bayrak" bash "$K" --kapat >"$T/cikti" 2>&1; echo $?); ok "S7 --kapat: bayrak silinir" '[ "$rc" = 0 ] && [ ! -e "$T/bayrak" ]'
rc=$(POSTACI_JETON="$T/yok" POSTANE_URL="http://127.0.0.1:$PORT" OTURUM_DIZIN="$T/oturum" BAYRAK="$T/bayrak" CRONTAB_KOMUT="$T/crontab" bash "$K" --uygula >"$T/cikti" 2>&1; echo $?); ok "S8 jeton dosyası yok: rc 1" '[ "$rc" = 1 ] && [ ! -e "$T/bayrak" ]'
rc=$(bash "$K" --bilinmeyen >/dev/null 2>&1; echo $?); ok "S9 bilinmeyen bayrak: rc 2" '[ "$rc" = 2 ]'
c=$(cd / && bash "$HERE/posta.sh" 2>&1); ok "S10 ajan komutu paketle gelir, başka dizinden çalışır (kutuda onay yolu)" '[[ "$c" == *"kullanım: posta"* ]]'
echo "── SONUÇ: PASS=$pass FAIL=$fail ──"; [ "$fail" = 0 ]
