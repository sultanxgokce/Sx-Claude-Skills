// CANLI ölçüm — bu kutunun (code) GERÇEK ttyd soketi + GERÇEK tmux (mouse on, set-clipboard on) + GERÇEK resim
// dinleyicisi (127.0.0.1:8391) üzerinden; kapı = iş alanındaki yeni sunucu.mjs (:17681, taban /code). Koltuk: sinav-pano.
import { chromium } from '/config/projects/Nexus/ui/node_modules/playwright/index.mjs';
import { execFileSync } from 'node:child_process'; import { existsSync, statSync, readFileSync } from 'node:fs';
const P = 'http://127.0.0.1:17681', SIFRE = 'canli-sinav-parolasi-7781';
let gecen = 0, kalan = 0; const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const r = await fetch(`${P}/code/giris`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify({ parola: SIFRE }) });
const cerez = ((r.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
const b = await chromium.launch(); const ctx = await b.newContext({ viewport: { width: 1100, height: 640 }, permissions: ['clipboard-read', 'clipboard-write'] });
await ctx.addCookies([{ name: 'kapi', value: cerez, domain: '127.0.0.1', path: '/code' }]);
const pg = await ctx.newPage(); pg.on('console', (m) => { if (/kapi-pano/.test(m.text())) console.log('   konsol:', m.text()); });
await pg.goto(`${P}/code/tty/?arg=sinav-pano`, { waitUntil: 'load' }); await pg.waitForSelector('.xterm-helper-textarea', { timeout: 15000 });
const pane = () => execFileSync('tmux', ['capture-pane', '-p', '-t', 'sinav-pano:']).toString();
const hazir = await pg.waitForFunction(() => window.__kapiPano && window.__kapiPano.osc52, null, { timeout: 10000 }).then(() => true, () => false);
kapi('C0 canlı ttyd sayfası (/code/tty/?arg=sinav-pano) açıldı, köprü bağlandı', hazir);
await pg.focus('.xterm-helper-textarea'); await pg.bringToFront(); await bekle(500);
// gerçek bir resim üret (yazılı 1400x700 PNG) ve yapıştır
const png = await pg.evaluate(async () => { const cv = new OffscreenCanvas(1400, 700); const c = cv.getContext('2d'); c.fillStyle = '#15120e'; c.fillRect(0, 0, 1400, 700); c.fillStyle = '#c9914f'; c.font = '64px sans-serif'; c.fillText('BÂNİ canlı ölçüm — resim yapıştırma', 60, 200); for (let k = 0; k < 6000; k++) { c.fillStyle = `hsl(${Math.random() * 360},70%,${30 + Math.random() * 50}%)`; c.fillRect(Math.random() * 1400, 300 + Math.random() * 400, 12, 12); }
  const bl = await cv.convertToBlob({ type: 'image/png' }); const u = new Uint8Array(await bl.arrayBuffer()); let s = ''; for (let j = 0; j < u.length; j += 0x8000) s += String.fromCharCode.apply(null, u.subarray(j, j + 0x8000)); return { b64: btoa(s), boy: u.length }; });
await pg.evaluate((b64) => { const bin = atob(b64); const u = new Uint8Array(bin.length); for (let j = 0; j < bin.length; j++) u[j] = bin.charCodeAt(j); const dt = new DataTransfer(); dt.items.add(new File([u], 'r.png', { type: 'image/png' })); const ta = document.querySelector('.xterm-helper-textarea'); ta.focus(); ta.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true })); }, png.b64);
await pg.waitForFunction(() => /yazıldı|✗/.test((document.getElementById('kapi-pano-bildirim') || {}).textContent || ''), null, { timeout: 20000 }).catch(() => {});
await bekle(600);
const ekran = pane(); const yol = (ekran.match(/\/config\/[^\s]+\/\.cc-images\/inbox\/img-[0-9a-f-]+\.(png|webp)/) || [])[0] || '';
console.log('   bildirim:', await pg.$eval('#kapi-pano-bildirim', (e) => e.textContent).catch(() => '-'));
kapi('C1 dönen yol GERÇEK tmux koltuğunda görünüyor (capture-pane)', !!yol, `→ son satır: ${ekran.trim().split('\n').pop()}`);
const kucuk = png.boy >= 300 * 1024;   // 300 KB altı küçültülmez (kural), üstü 2000px webp
kapi(`C2 dosya kutunun gelen kutusunda VAR${kucuk ? ' ve küçültülmüş (webp < kaynak PNG)' : ' (küçük PNG aynen)'}`, !!yol && existsSync(yol) && (kucuk ? (yol.endsWith('.webp') && statSync(yol).size < png.boy) : statSync(yol).size === png.boy), `→ ${yol} ${yol && existsSync(yol) ? statSync(yol).size : '-'} < ${png.boy}`);
if (yol) console.log(`   dosya: ${yol} (${statSync(yol).size} bayt · kaynak PNG ${png.boy} bayt)`);
await pg.screenshot({ path: '/tmp/claude-1000/canli-yapistir.png' });
// kopyalama: uygulama OSC 52 (printf) ve fare seçimi (tmux copy-mode)
await pg.evaluate(() => navigator.clipboard.writeText('pano-bos'));
const komut = async (k) => { await pg.focus('.xterm-helper-textarea'); await pg.keyboard.press('Control+u'); await pg.keyboard.type(k); await pg.keyboard.press('Enter'); };
await komut('printf "\\033]52;c;$(printf canli-osc52-tamam | base64)\\a"'); await bekle(1500);
let pano = await pg.evaluate(() => navigator.clipboard.readText()).catch((e) => 'HATA ' + e.message);
kapi('C3 canlı tmux içinden OSC 52 tarayıcı panosuna iner', pano === 'canli-osc52-tamam', `→ "${pano}"`);
await pg.evaluate(() => navigator.clipboard.writeText('pano-bos'));
await komut('echo CANLI-SECIM-SATIRI-XYZ'); await bekle(800);
const geo = await pg.evaluate(() => { const t = window.term; const bf = t.buffer.active; let satir = -1; for (let i = bf.length - 1; i >= 0; i--) { const l = bf.getLine(i); if (l && l.translateToString(true).trim() === 'CANLI-SECIM-SATIRI-XYZ') { satir = i; break; } } const r = document.querySelector('.xterm-screen').getBoundingClientRect(); return { satir: satir - bf.viewportY, x: r.left, y: r.top, w: r.width / t.cols, h: r.height / t.rows }; });
const y = geo.y + (geo.satir + 0.5) * geo.h;
await pg.mouse.move(geo.x + 0.5 * geo.w, y); await pg.mouse.down(); await pg.mouse.move(geo.x + 21.5 * geo.w, y, { steps: 8 }); await pg.mouse.up(); await bekle(1500);
pano = await pg.evaluate(() => navigator.clipboard.readText()).catch((e) => 'HATA ' + e.message);
kapi('C4 canlı tmux\'ta FAREYLE SEÇİM (copy-mode) tarayıcı panosuna iner — Sultan\'ın kırık yolu', pano === 'CANLI-SECIM-SATIRI-XYZ', `→ "${pano}" satir=${geo.satir}`);
await pg.screenshot({ path: '/tmp/claude-1000/canli-kopyala.png' });
await b.close();
console.log(`\nCANLI GEÇEN: ${gecen} · KALAN: ${kalan}`); process.exit(kalan ? 1 : 0);
