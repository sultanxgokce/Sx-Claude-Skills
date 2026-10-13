/**
 * Pano köprüsü tarayıcı sınavı — GERÇEK Chromium · GERÇEK ttyd · GERÇEK tmux (mouse on, set-clipboard on) · GERÇEK kapı ·
 * sahte resim dinleyicisi (yüklenen baytı tutar, yol döner). Sultan'ın yolu birebir: Cmd+V resim → /api/resim → yol
 * terminalde; fareyle seçim → tmux copy-mode → OSC 52 → tarayıcı panosu.
 *   node kapi/pano-sinav.mjs [--kare <önek>]
 * CI dışı: tarayıcı kütüphanesi / ttyd / tmux yoksa rc=4 ÖLÇÜLEMEDİ (yeşil DEĞİL).
 */
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, chmodSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import http from 'node:http';
const KOK = dirname(fileURLToPath(import.meta.url));
const PW = process.env.KANIT_PLAYWRIGHT_DIR || '/config/projects/Nexus/ui/node_modules';
let chromium; try { ({ chromium } = await import(pathToFileURL(join(PW, 'playwright/index.mjs')).href)); }
catch { console.log(`ÖLÇÜLEMEDİ: tarayıcı kütüphanesi yok (${PW})`); process.exit(4); }
const TTYD = process.env.TTYD_BIN || join(process.env.HOME || '/config', '.local/bin/ttyd');
if (!existsSync(TTYD)) { console.log(`ÖLÇÜLEMEDİ: ttyd yok (${TTYD})`); process.exit(4); }
let TMUX = 'tmux'; try { execFileSync('tmux', ['-V'], { stdio: 'ignore' }); } catch { console.log('ÖLÇÜLEMEDİ: tmux yok'); process.exit(4); }
const i = process.argv.indexOf('--kare'); const KARE = i > 0 ? process.argv[i + 1] : '';
let gecen = 0, kalan = 0; const basarisiz = [];
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; basarisiz.push(ad); console.log(`  ✗ ${ad} ${ek}`); } };
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const T = mkdtempSync(join(tmpdir(), 'pano-sinav-'));
const SIFRE = 'sinav-parolasi-1234';
const TMUX_L = 'pano-sinav-' + process.pid;

// ── sahte resim dinleyicisi (kutudaki 127.0.0.1:8391'in yerine): baytı tutar, kanonik yol döner
const yuklemeler = [];
const dinleyici = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/upload') { res.writeHead(404); return res.end(); }
  const p = []; req.on('data', (c) => p.push(c)); req.on('end', () => {
    const b = Buffer.concat(p);
    const uz = b[0] === 0x89 ? '.png' : b.slice(8, 12).toString() === 'WEBP' ? '.webp' : '.bin';
    const yol = `/sinav/inbox/img-${yuklemeler.length + 1}${uz}`;
    yuklemeler.push({ tip: req.headers['content-type'], boy: b.length, govde: b, yol, xrw: req.headers['x-requested-with'] });
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ ok: true, path: yol }));
  });
});
await new Promise((r) => dinleyici.listen(0, '127.0.0.1', r)); const DPORT = dinleyici.address().port;

// ── gerçek ttyd → gerçek tmux (Sultan'ın düzeni: mouse on · set-clipboard on)
const CONF = join(T, 'tmux.conf');
// terminal-features clipboard: dış terminalin (xterm-256color) OSC 52 alabildiğini tmux'a söyler (Ms) — kutuların tmux.conf'unda da var
writeFileSync(CONF, 'set -g mouse on\nset -g set-clipboard on\nset -g default-terminal tmux-256color\nset -g status off\nset -as terminal-features ",xterm*:clipboard"\n');
const SOCK = join(T, 'ttyd.sock');
// Sınav bir tmux penceresinden koşabilir: TMUX ortamı çocuğa geçerse içerideki tmux "nested" diye reddeder → temizlenir.
const ttydOrtam = { ...process.env, TERM: 'xterm-256color', PS1: 'sinav$ ' }; delete ttydOrtam.TMUX; delete ttydOrtam.TMUX_PANE;
const ttyd = spawn(TTYD, ['-W', '-i', SOCK, '-b', '/sinav/tty', '-t', 'disableLeaveAlert=true',
  // 🔴 Komutun sonuna `-i` KONMAZ (ölçüldü 13 Ekim: ttyd 1.7.7 komut argümanlarındaki sondaki `-i`'yi kendi
  //    --interface seçeneği sanıp SIGSEGV ile ölüyor; pty zaten kabuğu etkileşimli yapar).
  TMUX, '-L', TMUX_L, '-f', CONF, 'new-session', '-A', '-s', 'sinav-ana', 'bash', '--norc', '--noprofile'],
  { env: ttydOrtam, stdio: ['ignore', 'ignore', 'pipe'] });
let ttydHata = ''; ttyd.stderr.on('data', (d) => { ttydHata += d; }); ttyd.on('error', (e) => { ttydHata += 'SPAWN: ' + e.message; });
for (let k = 0; k < 80 && !existsSync(SOCK); k++) await bekle(100);
if (!existsSync(SOCK)) { console.log(`ÖLÇÜLEMEDİ: ttyd soketi açılmadı (pid=${ttyd.pid} rc=${ttyd.exitCode} sinyal=${ttyd.signalCode} sock=${SOCK})\n` + ttydHata.split('\n').slice(-6).join('\n')); process.exit(4); }

const KOLTUK = join(T, 'koltuk.sh'); writeFileSync(KOLTUK, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "sinav-ana\\t1\\t0\\tdiger\\tbilinmiyor\\n"\n'); chmodSync(KOLTUK, 0o755);
async function kapiAc(port, ek = {}) {
  const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: String(port), KAPI_TABAN: '/sinav', TO_KUTU: 'sinav',
    TO_ANA_TMUX: 'sinav-ana', KAPI_TTYD_SOKET: SOCK, TO_DURUM_DIZ: T, SINAV__TERMINAL_SIFRE: SIFRE, KAPI_KOLTUK_BETIK: KOLTUK,
    KAPI_RESIM_URL: `http://127.0.0.1:${DPORT}/upload`, ...ek }, stdio: 'ignore' });
  for (let k = 0; k < 50; k++) { await bekle(100); try { if ((await fetch(`http://127.0.0.1:${port}/sinav/giris`)).status === 200) return p; } catch {} }
  throw new Error('kapı açılmadı');
}
const P1 = 18795, P2 = 18796;
const k1 = await kapiAc(P1), k2 = await kapiAc(P2, { KAPI_PANO: '0' });
const giris = async (port) => { const r = await fetch(`http://127.0.0.1:${port}/sinav/giris`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify({ parola: SIFRE }) });
  return ((r.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };

const b = await chromium.launch();
const ekran = (pg) => pg.evaluate(() => { const t = window.term; if (!t) return ''; const bf = t.buffer.active; const s = []; for (let i = 0; i < bf.length; i++) s.push((bf.getLine(i) && bf.getLine(i).translateToString(true)) || ''); return s.join('\n'); });
const ekranda = (pg, metin, ms = 8000) => pg.waitForFunction((m) => { const t = window.term; if (!t) return false; const bf = t.buffer.active; for (let i = 0; i < bf.length; i++) { const l = bf.getLine(i); if (l && l.translateToString(true).includes(m)) return true; } return false; }, metin, { timeout: ms }).then(() => true, () => false);
const bildirim = (pg) => pg.$eval('#kapi-pano-bildirim', (e) => (e.style.display !== 'none' ? e.textContent : '')).catch(() => '');
async function sayfa(port) {
  const ctx = await b.newContext({ viewport: { width: 1100, height: 640 }, permissions: ['clipboard-read', 'clipboard-write'] });
  await ctx.addCookies([{ name: 'kapi', value: await giris(port), domain: '127.0.0.1', path: '/sinav' }]);
  const pg = await ctx.newPage();
  await pg.goto(`http://127.0.0.1:${port}/sinav/tty/`, { waitUntil: 'load' });
  await pg.waitForSelector('.xterm-helper-textarea', { timeout: 15000 });
  const hazir = await ekranda(pg, 'sinav$', 15000);
  await pg.focus('.xterm-helper-textarea'); await pg.bringToFront();
  return { pg, hazir };
}
// Yapıştırma olayı: Sultan'ın Cmd+V'si tarayıcıda tam olarak budur (paste olayı xterm'in yardımcı textarea'sına düşer)
const yapistir = (pg, { tip, b64, metin }) => pg.evaluate(({ tip, b64, metin }) => {
  const dt = new DataTransfer();
  if (metin != null) dt.setData('text/plain', metin);
  if (b64) { const bin = atob(b64); const u = new Uint8Array(bin.length); for (let j = 0; j < bin.length; j++) u[j] = bin.charCodeAt(j); dt.items.add(new File([u], 'resim', { type: tip })); }
  const ta = document.querySelector('.xterm-helper-textarea'); ta.focus();
  return ta.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
}, { tip, b64, metin });
const PNG1 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='; // 1×1 png

try {
  console.log('── Y · resim yapıştırma (Cmd+V)');
  let { pg, hazir } = await sayfa(P1);
  kapi('Y0 gerçek ttyd+tmux sayfası açıldı, kabuk istemi göründü', hazir, `→ ${(await ekran(pg)).slice(0, 80)}`);
  const kop = await pg.waitForFunction(() => window.__kapiPano && window.__kapiPano.osc52 === true, null, { timeout: 8000 }).then(() => true, () => false);
  kapi('Y1 köprü ttyd\'nin xterm\'ine bağlandı (window.__kapiPano.osc52)', kop);
  const once = yuklemeler.length;
  await yapistir(pg, { tip: 'image/png', b64: PNG1 });
  await pg.waitForFunction(() => /yazıldı|✗/.test((document.getElementById('kapi-pano-bildirim') || {}).textContent || ''), null, { timeout: 10000 }).catch(() => {});
  kapi('Y2 resim /api/resim üzerinden dinleyiciye ULAŞTI (bayt bayt aynı · x-requested-with: dashboard)',
       yuklemeler.length === once + 1 && yuklemeler[once].govde.equals(Buffer.from(PNG1, 'base64')) && yuklemeler[once].xrw === 'dashboard',
       `→ ${yuklemeler.length - once} yükleme`);
  kapi('Y3 dönen yol TERMİNALE yazıldı (kabuk satırında görünür)', await ekranda(pg, '/sinav/inbox/img-1.png'), `→ ${(await ekran(pg)).trim().split('\n').pop()}`);
  const bd = await bildirim(pg);
  kapi('Y4 kullanıcıya bildirildi: "resmin yolu terminale yazıldı — Enter ile gönder"', /terminale yazıldı/.test(bd), `→ ${bd}`);
  if (KARE) await pg.screenshot({ path: `${KARE}-yapistir.png` });
  // büyük resim → 2000px webp
  const buyuk = await pg.evaluate(async () => { const cv = new OffscreenCanvas(2600, 1600); const c = cv.getContext('2d');
    for (let k = 0; k < 4000; k++) { c.fillStyle = `hsl(${Math.random() * 360},70%,${30 + Math.random() * 50}%)`; c.fillRect(Math.random() * 2600, Math.random() * 1600, 40, 40); }
    const bl = await cv.convertToBlob({ type: 'image/png' }); const u = new Uint8Array(await bl.arrayBuffer()); let s = ''; for (let j = 0; j < u.length; j += 0x8000) s += String.fromCharCode.apply(null, u.subarray(j, j + 0x8000)); return { b64: btoa(s), boy: u.length }; });
  const once2 = yuklemeler.length; await bekle(1600);   // köprü aynı anda ikinci yüklemeyi almaz (mesgul); bitti, sonrakine geç
  await yapistir(pg, { tip: 'image/png', b64: buyuk.b64 });
  await pg.waitForFunction((n) => (document.getElementById('kapi-pano-bildirim') || {}).textContent && /yazıldı|✗/.test(document.getElementById('kapi-pano-bildirim').textContent) && true, once2, { timeout: 20000 }).catch(() => {});
  for (let k = 0; k < 50 && yuklemeler.length === once2; k++) await bekle(200);
  const y2 = yuklemeler[once2];
  let en = 0; if (y2) en = await pg.evaluate(async (b64) => { const bin = atob(b64); const u = new Uint8Array(bin.length); for (let j = 0; j < bin.length; j++) u[j] = bin.charCodeAt(j); const bm = await createImageBitmap(new Blob([u], { type: 'image/webp' })); return bm.width; }, y2.govde.toString('base64')).catch(() => 0);
  kapi(`Y5 büyük PNG (${Math.round(buyuk.boy / 1024)} KB, 2600px) 2000px WebP olarak küçültülür ve küçülür`, !!y2 && y2.tip === 'image/webp' && en === 2000 && y2.boy < buyuk.boy, `→ ${y2 ? `${y2.tip} ${en}px ${Math.round(y2.boy / 1024)} KB` : 'yükleme yok'}`);
  kapi('Y6 ikinci yol da terminale yazıldı', await ekranda(pg, '/sinav/inbox/img-2.webp'));
  // metin yapıştırma DOKUNULMAZ
  const once3 = yuklemeler.length;
  await pg.keyboard.press('Control+u');   // satır temiz: sarılmış satırda alt dize bölünmesin
  await yapistir(pg, { metin: 'echo metin-yapistirma-calisiyor' });
  kapi('Y7 METİN yapıştırma xterm\'in kendi yoluyla aynen çalışır (köprü dokunmaz)', await ekranda(pg, 'echo metin-yapistirma-calisiyor') && yuklemeler.length === once3, '→ metin gelmedi ya da yükleme sayıldı');

  console.log('── K · kopyalama (fare seçimi → tmux → OSC 52 → tarayıcı panosu)');
  // 🔴 Komut GERÇEK TUŞLARLA verilir, term.paste ile DEĞİL: bash köşeli-yapıştırma kipinde yapıştırılan satır sonu
  //    çalıştırılmaz (ilk turda printf hiç koşmadı, sınav ürünü değil kendini ölçtü).
  const komut = async (pg, k) => { await pg.focus('.xterm-helper-textarea'); await pg.keyboard.press('Control+u'); await pg.keyboard.type(k); await pg.keyboard.press('Enter'); };
  await pg.evaluate(() => navigator.clipboard.writeText('pano-bos'));
  await komut(pg, 'printf "\\033]52;c;$(printf merhaba-pano | base64)\\a"');   // uygulama OSC 52 → tmux (set-clipboard on) → ttyd
  await bekle(1500);
  let pano = await pg.evaluate(() => navigator.clipboard.readText()).catch((e) => 'HATA:' + e.message);
  kapi('K1 uygulamanın OSC 52\'si tmux üzerinden tarayıcı panosuna İNER', pano === 'merhaba-pano', `→ pano="${pano}"`);
  const bk = await bildirim(pg);
  kapi('K2 kullanıcıya "seçim panoya kopyalandı" denir', /panoya kopyalandı/.test(bk), `→ ${bk}`);
  if (KARE) await pg.screenshot({ path: `${KARE}-kopyala.png` });
  // fareyle seçim: tmux copy-mode (mouse on) → MouseDragEnd1Pane copy-selection-and-cancel → OSC 52
  await pg.evaluate(() => navigator.clipboard.writeText('pano-bos'));
  await komut(pg, 'echo SECILECEK-SATIR-ABC');
  // Komut satırı da aynı metni taşır → ÇIKTI satırı (tek başına, tam eşit) beklenir; yoksa yarış (ölçüldü: 1/3 koşuda satir=-1)
  await pg.waitForFunction(() => { const bf = window.term.buffer.active; for (let i = 0; i < bf.length; i++) { const l = bf.getLine(i); if (l && l.translateToString(true).trim() === 'SECILECEK-SATIR-ABC') return true; } return false; }, null, { timeout: 8000 }).catch(() => {});
  const geo = await pg.evaluate(() => { const t = window.term; const bf = t.buffer.active; let satir = -1; for (let i = bf.length - 1; i >= 0; i--) { const l = bf.getLine(i); if (l && l.translateToString(true).trim() === 'SECILECEK-SATIR-ABC') { satir = i; break; } }
    const r = document.querySelector('.xterm-screen').getBoundingClientRect(); return { satir: satir - bf.viewportY, x: r.left, y: r.top, w: r.width / t.cols, h: r.height / t.rows }; });
  kapi('K3 seçilecek satır ekranda bulundu', geo.satir >= 0, `→ ${JSON.stringify(geo)}`);
  const y = geo.y + (geo.satir + 0.5) * geo.h;
  await pg.mouse.move(geo.x + 0.5 * geo.w, y); await pg.mouse.down(); await pg.mouse.move(geo.x + 19.5 * geo.w, y, { steps: 8 }); await pg.mouse.up();
  await bekle(1200);
  pano = await pg.evaluate(() => navigator.clipboard.readText()).catch((e) => 'HATA:' + e.message);
  kapi('K4 FAREYLE SEÇİM (tmux copy-mode) tarayıcı panosuna iner — Sultan\'ın kırık yolu', pano === 'SECILECEK-SATIR-ABC', `→ pano="${pano}"`);
  // Cmd+C ipucu: seçim yokken bir kez
  await pg.focus('.xterm-helper-textarea'); await bekle(3200);   // "zaten panoda" penceresi geçsin
  await pg.keyboard.press('Meta+c'); await bekle(200);
  const ip = await bildirim(pg);
  kapi('K5 Cmd+C seçimsiz basılınca yol gösterilir (Shift basılı sürükle ipucu)', /Shift basılı/.test(ip), `→ "${ip}"`);
  // Shift-sürükle → tarayıcı seçimi (fare tmux\'a gitmez)
  await pg.keyboard.down('Shift'); await pg.mouse.move(geo.x + 0.5 * geo.w, y); await pg.mouse.down(); await pg.mouse.move(geo.x + 19.5 * geo.w, y, { steps: 8 }); await pg.mouse.up(); await pg.keyboard.up('Shift');
  const sec = await pg.evaluate(() => window.term.getSelection());
  kapi('K6 Shift basılı sürükleme TARAYICI seçimi yapar (Cmd+C ile kopyalanabilir)', sec.trim() === 'SECILECEK-SATIR-ABC', `→ "${sec}"`);

  console.log('── N · olumsuz kontrol: köprüsüz kapı (KAPI_PANO=0) aynı ölçümde KIRMIZI');
  await pg.context().close();   // köprülü sayfa AYNI tmux oturumuna bağlı kalırsa OSC 52'yi o alır ve panoyu doldurur → kontrol kirlenir
  ({ pg, hazir } = await sayfa(P2));
  const yok = await pg.evaluate(() => !window.__kapiPano && !document.documentElement.hasAttribute('data-kapi-pano'));
  kapi('N1 köprüsüz sayfada işaret ve bağ yok', hazir && yok);
  await pg.evaluate(() => navigator.clipboard.writeText('pano-bos'));
  await komut(pg, 'printf "\\033]52;c;$(printf merhaba-pano | base64)\\a"'); await bekle(1500);
  pano = await pg.evaluate(() => navigator.clipboard.readText()).catch(() => 'HATA');
  kapi('N2 köprüsüz: OSC 52 panoya İNMEZ (ölçüm yokluğu görüyor; K1 tautoloji değil)', pano === 'pano-bos', `→ pano="${pano}"`);
  const once4 = yuklemeler.length; await yapistir(pg, { tip: 'image/png', b64: PNG1 }); await bekle(1500);
  kapi('N3 köprüsüz: resim yapıştırma dinleyiciye ULAŞMAZ (Y2 tautoloji değil)', yuklemeler.length === once4, `→ ${yuklemeler.length - once4} yükleme`);

  // ── E · tarayıcı eklentisi (cloudtop-terminal-image.user.js, Tampermonkey) AYNI sayfada ─────────────
  // Sultan'ın tarayıcısında eklenti `https://*.mmepanel.com/*` jokeriyle kurulu → ttyd sayfasında da yüklenir.
  // EKLENTI_YOL verilirse eklenti document-idle'da (Tampermonkey gibi) sayfaya sokulur ve Cmd+V taklit edilir:
  // keydown (eklentinin B yolu panoyu okur) + paste olayı (tarayıcının yaptığı). Verilmezse ÖLÇÜLMEDİ (yeşil değil).
  const EKLENTI = process.env.EKLENTI_YOL || '';
  if (EKLENTI && existsSync(EKLENTI)) {
    console.log(`── E · tarayıcı eklentisi aynı sayfada (${EKLENTI})`);
    const kaynak = readFileSync(EKLENTI, 'utf8').replace(/^\/\/ ==UserScript==[\s\S]*?==\/UserScript==\s*/m, '');
    const ctx = await b.newContext({ viewport: { width: 1100, height: 640 }, permissions: ['clipboard-read', 'clipboard-write'] });
    await ctx.addCookies([{ name: 'kapi', value: await giris(P1), domain: '127.0.0.1', path: '/sinav' }]);
    await ctx.addInitScript({ content: `window.GM_addStyle=function(){};document.addEventListener('DOMContentLoaded',function(){try{${kaynak}\n}catch(e){console.error('[eklenti] hata',e&&e.message)}});` });
    const pe = await ctx.newPage(); const gunluk = []; let yanlisYol = 0;
    pe.on('console', (m) => gunluk.push(m.text()));
    pe.on('request', (r) => { if (r.url().includes('/proxy/8391/')) yanlisYol++; });
    await pe.goto(`http://127.0.0.1:${P1}/sinav/tty/`, { waitUntil: 'load' });
    await pe.waitForSelector('.xterm-helper-textarea', { timeout: 15000 }); await ekranda(pe, 'sinav$', 15000);
    await pe.focus('.xterm-helper-textarea'); await pe.bringToFront(); await bekle(800);
    kapi('E0 eklenti sayfaya yüklendi ([term-paste] günlüğü)', gunluk.some((t) => /\[term-paste\]/.test(t)), `→ ${gunluk.slice(0, 3).join(' | ')}`);
    const onceE = yuklemeler.length;
    await pe.evaluate(async (b64) => { const bin = atob(b64); const u = new Uint8Array(bin.length); for (let j = 0; j < bin.length; j++) u[j] = bin.charCodeAt(j);
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': new Blob([u], { type: 'image/png' }) })]);
      const ta = document.querySelector('.xterm-helper-textarea'); ta.focus();
      ta.dispatchEvent(new KeyboardEvent('keydown', { key: 'v', code: 'KeyV', metaKey: true, bubbles: true, cancelable: true }));
      const dt = new DataTransfer(); dt.items.add(new File([u], 'resim', { type: 'image/png' }));
      ta.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true })); }, PNG1);
    await bekle(3000);
    kapi('E1 eklenti ttyd sayfasında işareti görüp ÇEKİLDİ (günlük: "çekiliyorum")', gunluk.some((t) => /çekiliyorum/.test(t)), `→ ${gunluk.filter((t) => /term-paste/.test(t)).slice(-2).join(' | ')}`);
    kapi('E2 eklenti code-server yoluna (/proxy/8391/) HİÇ istek atmadı (merkezde "Böyle bir kutu yok" olurdu)', yanlisYol === 0, `→ ${yanlisYol} istek`);
    kapi('E3 yükleme TEK ve köprüden (çift yükleme yok)', yuklemeler.length === onceE + 1, `→ ${yuklemeler.length - onceE}`);
    const kirmizi = await pe.evaluate(() => Array.from(document.querySelectorAll('div')).map((d) => d.textContent || '').filter((t) => /^✗/.test(t.trim())));
    kapi('E4 ekranda eklentiden kırmızı bildirim YOK', kirmizi.length === 0, `→ ${kirmizi.join(' | ')}`);
    if (KARE) await pe.screenshot({ path: `${KARE}-eklenti.png` });
  } else console.log('── E · eklenti sınavı ÖLÇÜLMEDİ (EKLENTI_YOL verilmedi) — yeşil sayılmaz');
} finally {
  await b.close(); k1.kill(); k2.kill(); ttyd.kill(); dinleyici.close();
  try { execFileSync(TMUX, ['-L', TMUX_L, 'kill-server'], { stdio: 'ignore' }); } catch {}
}
console.log(`\nGEÇEN: ${gecen} · KALAN: ${kalan}`); if (kalan) basarisiz.forEach((a) => console.log('  · ' + a));
process.exit(kalan ? 1 : 0);
