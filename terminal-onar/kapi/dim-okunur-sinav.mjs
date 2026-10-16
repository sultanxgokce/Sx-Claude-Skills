/**
 * Dim okunurluk tarayıcı sınavı — GERÇEK Chromium · GERÇEK ttyd (onar.sh'taki tema) · GERÇEK tmux · GERÇEK kapı (pano.js gömülü).
 * Niçin (Sultan 16 Eki 2026 10:10 karesi, nazir-yon): Claude Code soru satırları ESC[2m (dim) ile basılıyor, koyu temada okunmuyordu.
 * Ölçüm iki yüzlü: PİKSEL (ekran görüntüsünden mürekkep rengi → WCAG kontrast; Sultan'ın gördüğü şey) + HÜCRE NİTELİĞİ
 * (xterm tamponu: isDim · fg; kanca mantığının kenarları). Önce = köprüsüz kapı (KAPI_PANO=0): sorun ölçülür (kontrol).
 *   node kapi/dim-okunur-sinav.mjs [--kare <önek>]
 * CI dışı: tarayıcı kütüphanesi / ttyd / tmux yoksa rc=4 ÖLÇÜLEMEDİ (yeşil DEĞİL).
 */
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, chmodSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const KOK = dirname(fileURLToPath(import.meta.url));
// Tarayıcı: aday dizinler sırayla, paketi VE ikilisi olan ilki (tarayici-bul.mjs, 2.13.1) — eski sabit yol ikilisiz pakette launch'ta çökerdi
import { tarayiciBul } from './tarayici-bul.mjs';
let chromium, PW; try { ({ chromium, dizin: PW } = await tarayiciBul()); console.log(`tarayıcı: ${PW}`); }
catch (e) { console.log('ÖLÇÜLEMEDİ: ' + e.message); process.exit(4); }
const TTYD = process.env.TTYD_BIN || join(process.env.HOME || '/config', '.local/bin/ttyd');
if (!existsSync(TTYD)) { console.log(`ÖLÇÜLEMEDİ: ttyd yok (${TTYD})`); process.exit(4); }
try { execFileSync('tmux', ['-V'], { stdio: 'ignore' }); } catch { console.log('ÖLÇÜLEMEDİ: tmux yok'); process.exit(4); }
const ki = process.argv.indexOf('--kare'); const KARE = ki > 0 ? process.argv[ki + 1] : '';
let gecen = 0, kalan = 0;
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const T = mkdtempSync(join(tmpdir(), 'dim-sinav-'));
const SIFRE = 'sinav-parolasi-1234'; const TMUX_L = 'dim-sinav-' + process.pid;

// Tema onar.sh'tan OKUNUR (tek kaynak; sınav kendi temasını uydurursa canlıyı ölçmez)
const onar = readFileSync(join(KOK, '../scripts/onar.sh'), 'utf8');
const tm = onar.match(/-t 'theme=(\{[^']*\})'/); if (!tm) { console.log('ÖLÇÜLEMEDİ: onar.sh içinde theme bulunamadı'); process.exit(4); }
const TEMA_JSON = tm[1].replace(/\\"/g, '"'); const TEMA = JSON.parse(TEMA_JSON);
const hex = (s) => [1, 3, 5].map((i) => parseInt(s.slice(i, i + 2), 16)); const BG = hex(TEMA.background);
const lum = ([r, g, b]) => { const f = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
const oran = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

// Satır betiği: komut yankısında işaret geçmesin diye dosyadan koşar
const SATIR = join(T, 'satirlar.sh');
writeFileSync(SATIR, `#!/usr/bin/env bash
printf '\\n'
printf ' L1 NORMAL metin satiri\\n'
printf '\\e[2m L2 DIM duz metin\\e[0m\\n'
printf '\\e[2;38;5;244m L3 DIM gri-244 soru satiri\\e[0m\\n'
printf '\\e[2m L4A dim-parca\\e[22m L4B devam-varsayilan\\n'
printf '\\e[32m L5A yesil \\e[2mL5B dim-yesil\\e[22m L5C yine-yesil\\e[0m\\n'
printf '\\e[1;2m L6A bold-dim\\e[22m L6B sonra\\e[0m\\n'
printf '\\e[90m L7 brightBlack temasi\\e[0m\\n'
printf ' SON\\n'
`); chmodSync(SATIR, 0o755);

const CONF = join(T, 'tmux.conf');
writeFileSync(CONF, 'set -g mouse on\nset -g default-terminal tmux-256color\nset -g status off\n');
const SOCK = join(T, 'ttyd.sock');
const ttydOrtam = { ...process.env, TERM: 'xterm-256color', PS1: 'sinav$ ' }; delete ttydOrtam.TMUX; delete ttydOrtam.TMUX_PANE;
const ttyd = spawn(TTYD, ['-W', '-i', SOCK, '-b', '/sinav/tty', '-t', 'fontSize=12', '-t', 'disableLeaveAlert=true', '-t', 'theme=' + TEMA_JSON,
  'tmux', '-L', TMUX_L, '-f', CONF, 'new-session', '-A', '-s', 'sinav-ana', 'bash', '--norc', '--noprofile'], { env: ttydOrtam, stdio: ['ignore', 'ignore', 'pipe'] });
let ttydHata = ''; ttyd.stderr.on('data', (d) => { ttydHata += d; });
for (let k = 0; k < 80 && !existsSync(SOCK); k++) await bekle(100);
if (!existsSync(SOCK)) { console.log('ÖLÇÜLEMEDİ: ttyd soketi açılmadı\n' + ttydHata.slice(-300)); process.exit(4); }
const KOLTUK = join(T, 'koltuk.sh'); writeFileSync(KOLTUK, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "sinav-ana\\t1\\t0\\tdiger\\tbilinmiyor\\n"\n'); chmodSync(KOLTUK, 0o755);
async function kapiAc(port, ek = {}) {
  const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: String(port), KAPI_TABAN: '/sinav', TO_KUTU: 'sinav',
    TO_ANA_TMUX: 'sinav-ana', KAPI_TTYD_SOKET: SOCK, TO_DURUM_DIZ: T, SINAV__TERMINAL_SIFRE: SIFRE, KAPI_KOLTUK_BETIK: KOLTUK, ...ek }, stdio: 'ignore' });
  for (let k = 0; k < 50; k++) { await bekle(100); try { if ((await fetch(`http://127.0.0.1:${port}/sinav/giris`)).status === 200) return p; } catch {} }
  throw new Error('kapı açılmadı');
}
const P1 = 18797, P2 = 18798;
// 🔴 BAYAT KAPI PORTU + ÇIKIŞ TEMİZLİĞİ (#347 deseni; ölçüldü 16 Eki: launch'ta çöken bir koşum kapılarını bıraktı, sonraki koşum 'kapı açılmadı').
import net from 'node:net';
const portDolu = (port) => new Promise((r) => { const c = net.connect({ port, host: '127.0.0.1' }); const bitir = (v) => { try { c.destroy(); } catch {} r(v); };
  c.once('connect', () => bitir(true)); c.once('error', () => bitir(false)); setTimeout(() => bitir(false), 1500); });
for (const port of [P1, P2]) {
  if (await portDolu(port)) { console.log(`ÖLÇÜLEMEDİ: :${port} zaten dinleniyor — yarım kalan koşumun kapısı (TO_KUTU=sinav sunucu.mjs) ya da yabancı süreç. PID ile kapat: for p in $(pgrep -f 'node .*sunucu.mjs'); do tr '\\0' '\\n' </proc/$p/environ | grep -q '^TO_KUTU=sinav$' && echo $p; done`); process.exit(4); }
}
const cocuklar = [ttyd]; process.on('exit', () => { for (const c of cocuklar) { try { c.kill('SIGTERM'); } catch {} } try { execFileSync('tmux', ['-L', TMUX_L, 'kill-server'], { stdio: 'ignore' }); } catch {} });
let k1, k2; try { k1 = await kapiAc(P1); cocuklar.push(k1); k2 = await kapiAc(P2, { KAPI_PANO: '0' }); cocuklar.push(k2); }
catch (e) { console.log('ÖLÇÜLEMEDİ: ' + e.message + ' (kapı açılamadı — port/ortam)'); process.exit(4); }
const giris = async (port) => { const r = await fetch(`http://127.0.0.1:${port}/sinav/giris`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify({ parola: SIFRE }) });
  return ((r.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
let b; try { b = await chromium.launch(); } catch (e) { console.log('ÖLÇÜLEMEDİ: tarayıcı açılamadı — ' + String(e.message).split('\n')[0]); process.exit(4); }
const ekranda = (pg, metin, ms = 8000) => pg.waitForFunction((m) => { const t = window.term; if (!t) return false; const bf = t.buffer.active; for (let i = 0; i < bf.length; i++) { const l = bf.getLine(i); if (l && l.translateToString(true).includes(m)) return true; } return false; }, metin, { timeout: ms }).then(() => true, () => false);
async function sayfa(port) {
  const ctx = await b.newContext({ viewport: { width: 1000, height: 600 } });
  await ctx.addCookies([{ name: 'kapi', value: await giris(port), domain: '127.0.0.1', path: '/sinav' }]);
  const pg = await ctx.newPage();
  await pg.goto(`http://127.0.0.1:${port}/sinav/tty/`, { waitUntil: 'load' });
  await pg.waitForSelector('.xterm-helper-textarea', { timeout: 15000 });
  const hazir = await ekranda(pg, 'sinav$', 15000);
  return { pg, hazir };
}
const tmux = (...a) => execFileSync('tmux', ['-L', TMUX_L, '-f', CONF, ...a], { stdio: ['ignore', 'pipe', 'pipe'] });

// Ölçüm: tampon satırı + hücre nitelikleri + ekran görüntüsünden parça mürekkep rengi
async function olc(pg, isaretler) {
  await bekle(700);
  const bilgi = await pg.evaluate((isaretler) => {
    const t = window.term; const el = document.querySelector('.xterm-screen'); const r = el.getBoundingClientRect(); const bf = t.buffer.active; const bul = {};
    for (let i = 0; i < bf.length; i++) {
      const l = bf.getLine(i); if (!l) continue; const s = l.translateToString(false);
      for (const m of isaretler) { const c0 = s.indexOf(m); if (c0 >= 0 && !bul[m] && !s.includes('satirlar.sh')) {
        const cell = l.getCell(c0 + 1); bul[m] = { i, c0, c1: c0 + m.length, dim: !!cell.isDim(), bold: !!cell.isBold(), fg: cell.getFgColor(), mode: cell.getFgColorMode() }; } }
    }
    return { x: r.x, y: r.y, w: r.width, h: r.height, rows: t.rows, cols: t.cols, bul, dimOkunur: !!(window.__kapiPano && window.__kapiPano.dimOkunur), kopru: !!window.__kapiPano };
  }, isaretler);
  const png = await pg.screenshot({ clip: { x: bilgi.x, y: bilgi.y, width: bilgi.w, height: bilgi.h } });
  const veri = await pg.evaluate(async (b64) => { const im = new Image(); im.src = 'data:image/png;base64,' + b64; await im.decode(); const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const g = c.getContext('2d'); g.drawImage(im, 0, 0); return { w: c.width, h: c.height, d: Array.from(g.getImageData(0, 0, c.width, c.height).data) }; }, png.toString('base64'));
  const olcek = veri.h / bilgi.h, hCell = bilgi.h / bilgi.rows, cw = bilgi.w / bilgi.cols;
  const sonuc = {};
  for (const [m, p] of Object.entries(bilgi.bul)) {
    const y0 = Math.floor(p.i * hCell * olcek), y1 = Math.floor((p.i + 1) * hCell * olcek), x0 = Math.floor(p.c0 * cw * olcek), x1 = Math.ceil(p.c1 * cw * olcek); const pik = [];
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) { const k = (y * veri.w + x) * 4; const q = [veri.d[k], veri.d[k + 1], veri.d[k + 2]]; if (Math.abs(q[0] - BG[0]) + Math.abs(q[1] - BG[1]) + Math.abs(q[2] - BG[2]) > 24) pik.push(q); }
    let renk = null, kontrast = 0;
    if (pik.length) { pik.sort((a, c) => lum(c) - lum(a)); const ust = pik.slice(0, Math.max(1, Math.floor(pik.length * 0.1))); renk = [0, 1, 2].map((c) => Math.round(ust.reduce((t, q) => t + q[c], 0) / ust.length)); kontrast = oran(renk, BG); }
    sonuc[m] = { ...p, renk: renk ? '#' + renk.map((v) => v.toString(16).padStart(2, '0')).join('') : null, kontrast, piksel: pik.length };
  }
  return { ...bilgi, sonuc };
}
const IS = ['L1 NORMAL', 'L2 DIM duz', 'L3 DIM gri-244', 'L4A dim-parca', 'L4B devam', 'L5A yesil', 'L5B dim-yesil', 'L5C yine-yesil', 'L6A bold-dim', 'L6B sonra', 'L7 brightBlack'];
const k = (s, m) => s.sonuc[m] || { kontrast: 0, renk: 'yok', fg: '?', dim: '?', bold: '?' };
const oz = (s, m) => `${m}: ${k(s, m).renk} ${k(s, m).kontrast.toFixed(2)}:1 fg=${k(s, m).fg} dim=${k(s, m).dim}`;
// Ölçüm tablosu HER koşumda basılır (bağımsız göz tur 1: geçen kapı sayı göstermiyordu; önce/sonra çifti sayıyla okunmalı)
const tablo = (s, baslik) => { console.log(`  ÖLÇÜM ${baslik} (mürekkep rengi · WCAG kontrast · xterm hücre fg/dim):`); for (const m of IS) console.log('    ' + oz(s, m)); };

try {
  console.log(`tema (onar.sh): bg ${TEMA.background} · fg ${TEMA.foreground} · brightBlack ${TEMA.brightBlack || 'YOK'}`);
  console.log('\n── Ö · ÖNCE: köprüsüz kapı (KAPI_PANO=0) — sorun ÖLÇÜLÜYOR mu (kontrol, ateşlemeyen yüz)');
  const { pg: pO, hazir: hO } = await sayfa(P2);
  kapi('Ö0 gerçek ttyd+tmux sayfası açıldı', hO);
  tmux('send-keys', '-t', 'sinav-ana', `bash ${SATIR}`, 'Enter');
  kapi('Ö0b satırlar ekrana geldi', await ekranda(pO, 'SON', 8000));
  const O = await olc(pO, IS); tablo(O, 'ÖNCE (köprüsüz)');
  kapi('Ö1 köprü YOK (pano.js gömülmedi) — ölçüm eski davranışı görüyor', !O.kopru);
  kapi('Ö2 🔴 "dim + gri-244" (Sultan\'ın soru satırı) kontrastı < 3:1 — OKUNMUYOR (sorun gerçek)', k(O, 'L3 DIM gri-244').kontrast > 0 && k(O, 'L3 DIM gri-244').kontrast < 3, oz(O, 'L3 DIM gri-244'));
  kapi('Ö3 hücre dim bayrağı taşıyor (xterm dim çiziyor)', k(O, 'L3 DIM gri-244').dim === true && k(O, 'L2 DIM duz').dim === true);
  kapi('Ö4 düz dim normalin yarısından soluk (xterm yarım saydamlık; 4,4-4,5:1, AA kıyısında)', k(O, 'L2 DIM duz').kontrast > 0 && k(O, 'L2 DIM duz').kontrast < k(O, 'L1 NORMAL').kontrast / 2, `${oz(O, 'L2 DIM duz')} · ${oz(O, 'L1 NORMAL')}`);
  if (KARE) await pO.screenshot({ path: `${KARE}-once.png` });
  await pO.context().close();

  console.log('\n── D · SONRA: kapı köprüyle (pano.js dim kancası + tema brightBlack)');
  const { pg, hazir } = await sayfa(P1);
  kapi('D0 sayfa açıldı', hazir);
  tmux('send-keys', '-t', 'sinav-ana', 'clear', 'Enter'); await bekle(300);
  tmux('send-keys', '-t', 'sinav-ana', `bash ${SATIR}`, 'Enter');
  kapi('D0b satırlar ekrana geldi', await ekranda(pg, 'SON', 8000));
  const S = await olc(pg, IS); tablo(S, 'SONRA (köprülü)');
  kapi('D1 köprü bağlı ve dim kancası takılı (__kapiPano.dimOkunur)', S.kopru && S.dimOkunur);
  kapi('D2 🔴 "dim + gri-244" soru satırı ≥ 4,5:1 (WCAG AA) — artık okunur', k(S, 'L3 DIM gri-244').kontrast >= 4.5, oz(S, 'L3 DIM gri-244'));
  kapi('D3 düz dim ≥ 4,5:1 (brightBlack tonu)', k(S, 'L2 DIM duz').kontrast >= 4.5 && k(S, 'L2 DIM duz').fg === 8, oz(S, 'L2 DIM duz'));
  kapi('D3b hücre artık dim DEĞİL (renkle ikincil, solgun değil)', k(S, 'L2 DIM duz').dim === false && k(S, 'L3 DIM gri-244').dim === false);
  kapi('D4 normal metin DEĞİŞMEDİ (dim\'siz SGR\'ye dokunulmaz)', k(S, 'L1 NORMAL').fg === -1 && Math.abs(k(S, 'L1 NORMAL').kontrast - k(O, 'L1 NORMAL').kontrast) < 0.3, oz(S, 'L1 NORMAL'));
  kapi('D5 dim kapanınca (22) metin VARSAYILAN renge döner', k(S, 'L4B devam').fg === -1 && k(S, 'L4B devam').kontrast >= 12, oz(S, 'L4B devam'));
  kapi('D6 dim\'den önceki açık renk 22\'de GERİ KONUR (yeşil → dim → yine yeşil)', k(S, 'L5A yesil').fg === 2 && k(S, 'L5B dim-yesil').fg === 8 && k(S, 'L5C yine-yesil').fg === 2, `${oz(S, 'L5A yesil')} · ${oz(S, 'L5B dim-yesil')} · ${oz(S, 'L5C yine-yesil')}`);
  kapi('D7 bold+dim → 22 sonrası bold da kapanır, renk varsayılan (22 kaybolmaz)', k(S, 'L6A bold-dim').bold === true && k(S, 'L6B sonra').bold === false && k(S, 'L6B sonra').fg === -1, `bold=${k(S, 'L6A bold-dim').bold}/${k(S, 'L6B sonra').bold} fg=${k(S, 'L6B sonra').fg}`);
  kapi('D8 temanın brightBlack tonu kendisi ≥ 4,5:1 (ikincil metin okunur)', k(S, 'L7 brightBlack').kontrast >= 4.5, oz(S, 'L7 brightBlack'));
  kapi('D9 köprüsüz sayfadaki normal/yeşil renkler köprülüyle AYNI (yan etki yok)', k(S, 'L5A yesil').renk === k(O, 'L5A yesil').renk && k(S, 'L1 NORMAL').renk === k(O, 'L1 NORMAL').renk, `${k(O, 'L5A yesil').renk}→${k(S, 'L5A yesil').renk}`);
  if (KARE) await pg.screenshot({ path: `${KARE}-sonra.png` });
  await pg.context().close();
} catch (e) { console.log('SINAV HATASI:', e.message); kalan++; }
finally {
  await b.close(); k1.kill(); k2.kill(); ttyd.kill();
  try { tmux('kill-server'); } catch {}
}
console.log(`\ndim-okunur-sinav: ${gecen} geçti · ${kalan} kaldı`);
process.exit(kalan ? 1 : 0);
