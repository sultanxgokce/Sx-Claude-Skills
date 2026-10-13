#!/usr/bin/env bash
# koltuk-xss.tarayici.sh — GERÇEK kapı sunucusu + GERÇEK Chromium: koltuk adı artık '/' '<' '"' taşıyabildiği için (2.4.1) koltuk seçici
# adı KAÇIŞLI yazmalı. Sahte koltuk listesi '<img/src=x/onerror=alert(7)>' · 'x"y' · '2026/85' verir; ölçülür: hiçbir diyalog/alert
# açılmaz · seçicide <img> öğesi DOĞMAZ · üç ad seçicide METİN olarak birebir görünür · option value = ad (adres doğru koltuğa gider).
# rc: 0 geçti · 1 kalan · 3 ÖLÇÜLEMEDİ (playwright yok)
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; P=""
trap '[ -n "$P" ] && kill $P 2>/dev/null; find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
PW="${WA_TEST_PLAYWRIGHT:-$(npm root -g 2>/dev/null)}"; [ -d "$PW/playwright" ] || { echo "ÖLÇÜLEMEDİ: playwright yok"; exit 3; }
cat > "$T/koltuk.sh" <<'K'
#!/usr/bin/env bash
[ "$1" = --liste ] || exit 2
printf 'sinavkutu-ana\t1760000000\t1\tajan\tbos\n<img/src=x/onerror=alert(7)>\t1760000100\t1\tajan\tbos\nx"y\t5\t0\tajan\tbos\n2026/85\t7\t1\tajan\tgirdi\n'
K
chmod +x "$T/koltuk.sh"
KAPI_PORT=18799 KAPI_TABAN=/sinav TO_KUTU=sinavkutu KAPI_TTYD_SOKET="$T/ttyd.sock" TO_DURUM_DIZ="$T" SINAVKUTU__TERMINAL_SIFRE=sinav-parola \
  TO_ANA_TMUX=sinavkutu-ana KAPI_KOLTUK_BETIK="$T/koltuk.sh" node "$D/sunucu.mjs" >"$T/gunluk" 2>&1 </dev/null & P=$!
for i in $(seq 1 50); do curl -s -o /dev/null -m 1 http://127.0.0.1:18799/sinav/giris && break; sleep 0.1; done
C="$(curl -s -D - -o /dev/null -X POST -H 'content-type: application/json' -d '{"parola":"sinav-parola"}' http://127.0.0.1:18799/sinav/giris | sed -n 's/^set-cookie: kapi=\([^;]*\).*/\1/Ip')"
[ -n "$C" ] || { echo "ÖLÇÜLEMEDİ: giriş çerezi alınamadı"; exit 3; }
cat > "$T/olc.cjs" <<'JS'
const { chromium } = require(process.argv[2] + '/playwright');
(async () => {
  const b = await chromium.launch(); const ctx = await b.newContext();
  await ctx.addCookies([{ name: 'kapi', value: process.argv[3], domain: '127.0.0.1', path: '/sinav', secure: false, httpOnly: true }]);
  const p = await ctx.newPage(); let diyalog = 0; p.on('dialog', (d) => { diyalog++; d.dismiss(); });
  await p.goto('http://127.0.0.1:18799/sinav/'); await p.waitForFunction(() => document.querySelectorAll('#koltuk option').length >= 4, null, { timeout: 8000 }).catch(() => {});
  await p.waitForTimeout(500);
  const v = await p.evaluate(() => { const s = document.querySelector('#koltuk');
    return { img: s ? s.querySelectorAll('img').length : -1, metin: s ? [...s.options].map((o) => o.textContent.replace(' ●', '')) : [], deger: s ? [...s.options].map((o) => o.value) : [] }; });
  await p.screenshot({ path: process.argv[4] });
  await b.close(); console.log(JSON.stringify({ diyalog, ...v }));
})().catch((e) => { console.log(JSON.stringify({ hata: String(e) })); process.exit(1); });
JS
O="$(node "$T/olc.cjs" "$PW" "$C" "${KX_KARE:-$T/kare.png}")"; echo "  ölçüm: $O"
al(){ printf '%s' "$O" | python3 -c 'import json,sys
try: d=json.load(sys.stdin); v=d.get(sys.argv[1]); print(json.dumps(v,ensure_ascii=False) if isinstance(v,list) else v)
except Exception: print("ÖLÇÜLEMEDİ")' "$1"; }
g=0; k=0; kapi(){ if [ "$2" = "$3" ]; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
kapi "X1 hiçbir diyalog/alert açılmadı" "0" "$(al diyalog)"
kapi "X2 seçicide <img> öğesi DOĞMADI" "0" "$(al img)"
B='["sinavkutu-ana", "<img/src=x/onerror=alert(7)>", "x\"y", "2026/85"]'
kapi "X3 adlar seçicide METİN olarak birebir" "$B" "$(al metin)"
kapi "X4 option değeri = ad (adres doğru koltuğa gider)" "$B" "$(al deger)"
echo; echo "GEÇEN: $g · KALAN: $k"; [ "$k" = 0 ]
