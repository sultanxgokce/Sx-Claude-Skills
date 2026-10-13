/**
 * Telefon ekranı (PWA) tarayıcı sınavı — GERÇEK Chromium, gerçek kapı, sahte koltuk betiği (tmux yok).
 * Bağımsız göz #295 tur 2: "yerel bellekteki eski koltuk adı liste doğrulanmadan terminale konabiliyor".
 * CI dışı (tarayıcı kütüphanesi her koşucuda yok); kütüphane yoksa rc=4 ÖLÇÜLEMEDİ.
 *   node kapi/tarayici-sinav.mjs [--kare <önek>]
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, chmodSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const KOK = dirname(fileURLToPath(import.meta.url));
const PW = process.env.KANIT_PLAYWRIGHT_DIR || '/config/projects/Nexus/ui/node_modules';
let chromium; try { ({ chromium } = await import(pathToFileURL(join(PW, 'playwright/index.mjs')).href)); }
catch { console.log(`ÖLÇÜLEMEDİ: tarayıcı kütüphanesi yok (${PW})`); process.exit(4); }
const i = process.argv.indexOf('--kare'); const KARE = i > 0 ? process.argv[i + 1] : '';
let gecen = 0, kalan = 0;
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const T = mkdtempSync(join(tmpdir(), 'pwa-sinav-'));
const SIFRE = 'sinav-parolasi-1234';
const LISTE = 'printf "sedir-ana\\t1760000000\\t1\\nBASIRET\\t1760000100\\t1\\nCARSI\\t1760000050\\t0\\nPEYK\\t1760000010\\t1\\n"';
const HIZLI = join(T, 'hizli.sh'); writeFileSync(HIZLI, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\n${LISTE}\n`); chmodSync(HIZLI, 0o755);
// sahte koltuk-ac.sh (2.4.0): BASIRET canlı · CARSI Claude'suz (resume var) · PEYK yok (kayıtsız); ac → deftere yazar, rc0
const KA = join(T, 'ka.sh'); const KA_DEFTER = join(T, 'ka-defter');
writeFileSync(KA, `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(KA_DEFTER)}\nif [ "$1" = durum ]; then case "$2" in BASIRET) echo '{"ad":"BASIRET","durum":"canli","tmux":true,"claude":true,"hal":"soru","son":0,"rol":"BASIRET","resume":true,"yol":"ekip-ac","ana":false}';; CARSI) echo '{"ad":"CARSI","durum":"claude-yok","tmux":true,"claude":false,"hal":"","son":0,"rol":"CARSI","resume":true,"yol":"ekip-ac","ana":false}';; sedir-ana) echo '{"ad":"sedir-ana","durum":"takili","tmux":true,"claude":true,"hal":"calisiyor","son":1700000000,"rol":"","resume":false,"yol":"onar","ana":true}';; *) echo '{"ad":"'"$2"'","durum":"yok","tmux":false,"claude":false,"hal":"","son":0,"rol":"","resume":false,"yol":"yok","ana":false}';; esac; exit 0; fi\necho "açıldı: $2"; exit 0\n`); chmodSync(KA, 0o755);
const YAVAS = join(T, 'yavas.sh'); writeFileSync(YAVAS, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nsleep 1.5\n${LISTE}\n`); chmodSync(YAVAS, 0o755);
async function kapiAc(port, betik) {
  const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: String(port), KAPI_TABAN: '/sedir', TO_KUTU: 'sedir',
    TO_ANA_TMUX: 'sedir-ana', KAPI_TTYD_SOKET: join(T, 'yok.sock'), TO_DURUM_DIZ: T, SEDIR__TERMINAL_SIFRE: SIFRE, KAPI_KOLTUK_BETIK: betik, KAPI_KOLTUK_AC_BETIK: KA }, stdio: 'ignore' });
  for (let k = 0; k < 50; k++) { await new Promise(r => setTimeout(r, 100)); try { if ((await fetch(`http://127.0.0.1:${port}/sedir/giris`)).status === 200) return p; } catch {} }
  throw new Error('kapı açılmadı');
}
const P1 = 18791, P2 = 18792;
const k1 = await kapiAc(P1, HIZLI), k2 = await kapiAc(P2, YAVAS);
const giris = async (port) => { const r = await fetch(`http://127.0.0.1:${port}/sedir/giris`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify({ parola: SIFRE }) });
  return ((r.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
const b = await chromium.launch();
const sayfa = async (port, sakla, hemen = false) => {   // hemen: liste gelmeden tıklanacak (yarış)
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  await ctx.addCookies([{ name: 'kapi', value: await giris(port), domain: '127.0.0.1', path: '/sedir' }]);
  const pg = await ctx.newPage();
  if (sakla !== undefined) { await pg.goto(`http://127.0.0.1:${port}/sedir/giris`); await pg.evaluate((v) => localStorage.setItem('sedir-koltuk', v), sakla); }
  await pg.goto(`http://127.0.0.1:${port}/sedir/`, { waitUntil: hemen ? 'domcontentloaded' : 'networkidle' });
  return pg;
};
const src = (pg) => pg.$eval('#tty', (e) => e.getAttribute('src')).catch(() => null);
try {
  console.log('── S · seçici');
  let pg = await sayfa(P1);
  await pg.waitForSelector('#koltuk:not([hidden])', { timeout: 5000 });
  const sec = await pg.$$eval('#koltuk option', (o) => o.map((x) => x.textContent));
  kapi('S1 başlıkta koltuk seçici var, 4 koltuk, ● = Claude', sec.join('|') === 'sedir-ana ●|BASIRET ●|CARSI|PEYK ●', `→ ${sec}`);
  if (KARE) await pg.screenshot({ path: `${KARE}-baslik.png`, clip: { x: 0, y: 0, width: 390, height: 140 } });
  await pg.selectOption('#koltuk', 'BASIRET'); await pg.waitForSelector('#tty', { timeout: 5000 });
  kapi('S2 koltuk seçince tam terminal O koltukla açılır (?arg=BASIRET)', (await src(pg)) === '/sedir/tty/?arg=BASIRET', `→ ${await src(pg)}`);
  kapi('S3 görünüm terminale geçti', (await pg.$eval('#gorunum', (e) => e.getAttribute('aria-pressed'))) === 'true');
  await pg.selectOption('#koltuk', 'sedir-ana'); await pg.waitForTimeout(300);
  kapi('S4 ana koltuk argümansız açılır (eski yol)', (await src(pg)) === '/sedir/tty/', `→ ${await src(pg)}`);
  console.log('── B · yerel bellekteki ad doğrulanmadan kullanılmaz');
  pg = await sayfa(P1, 'CARSI'); await pg.waitForSelector('#koltuk:not([hidden])'); await pg.click('#gorunum'); await pg.waitForSelector('#tty');
  kapi('B1 kayıtlı GEÇERLİ koltuk doğrulanınca kullanılır (?arg=CARSI)', (await src(pg)) === '/sedir/tty/?arg=CARSI', `→ ${await src(pg)}`);
  pg = await sayfa(P1, 'YOK'); await pg.waitForSelector('#koltuk:not([hidden])'); await pg.click('#gorunum'); await pg.waitForSelector('#tty');
  kapi('B2 kayıtlı GEÇERSİZ koltuk terminale KONMAZ (ana koltuğa düşer)', (await src(pg)) === '/sedir/tty/', `→ ${await src(pg)}`);
  kapi('B3 seçici de ana koltuğu gösterir (eski ad sessizce kalmaz)', (await pg.$eval('#koltuk', (e) => e.value)) === 'sedir-ana');
  console.log('── Y · YARIŞ: liste gecikirken terminal açılır');
  pg = await sayfa(P2, 'PEYK', true); await pg.click('#gorunum'); await pg.waitForSelector('#tty');
  const ilk = await src(pg);
  kapi('Y1 liste gelmeden açılan terminal doğrulanmamış adı KULLANMAZ', ilk === '/sedir/tty/', `→ ${ilk}`);
  await pg.waitForFunction(() => document.getElementById('tty')?.getAttribute('src') === '/sedir/tty/?arg=PEYK', null, { timeout: 6000 }).catch(() => {});
  kapi('Y2 liste gelince terminal doğrulanan koltuğa YENİDEN kurulur (?arg=PEYK)', (await src(pg)) === '/sedir/tty/?arg=PEYK', `→ ${await src(pg)}`);
  pg = await sayfa(P2, 'YOK', true); await pg.click('#gorunum'); await pg.waitForSelector('#tty'); await pg.waitForTimeout(2500);
  kapi('Y3 liste gecikse de GEÇERSİZ ad hiçbir anda terminale girmez', (await src(pg)) === '/sedir/tty/', `→ ${await src(pg)}`);
  console.log('── KD · koltuk penceresi (2.4.0): üç durum ayrı, tek tuş');
  pg = await sayfa(P1); await pg.waitForSelector('#koltuk:not([hidden])', { timeout: 5000 });
  await pg.selectOption('#koltuk', 'CARSI'); await pg.waitForTimeout(200);
  await pg.click('#koltukAc'); await pg.waitForFunction(() => /Claude yok/.test(document.getElementById('koltukDurum').textContent), null, { timeout: 5000 }).catch(() => {});
  let dm = await pg.$eval('#koltukDurum', (e) => e.textContent);
  kapi('KD1 Claude\'suz koltuk: pencere "Oturum var, içinde Claude yok" + kayıtlı rol gösterir', /Claude yok/.test(dm) && /CARSI/.test(dm), `→ ${dm}`);
  kapi('KD2 eylem "Yeniden aç" etkin · "Eski sohbete dön" görünür (resume mümkün)', (await pg.$eval('#koltukBasla', (e) => e.textContent + '|' + e.disabled)) === 'Yeniden aç|false' && !(await pg.$eval('#koltukEski', (e) => e.hidden)));
  await pg.click('#koltukEski'); await pg.waitForTimeout(400);
  const defter = readFileSync(KA_DEFTER, 'utf8').trim().split('\n');
  kapi('KD3 "Eski sohbete dön" tek tık → kapıya {eski:true} → betik "ac CARSI --eski"', defter.includes('ac CARSI --eski'), `→ ${defter.slice(-2).join(' | ')}`);
  await pg.evaluate(() => document.getElementById('koltukP').close()); await pg.selectOption('#koltuk', 'BASIRET'); await pg.waitForTimeout(200); await pg.click('#koltukAc'); await pg.waitForFunction(() => /Canlı/.test(document.getElementById('koltukDurum').textContent), null, { timeout: 5000 }).catch(() => {});
  kapi('KD4 canlı koltuk: "Canlı · hâl: soru", eylem devre dışı (ikinci kopya açılmaz)', /Canlı/.test(await pg.$eval('#koltukDurum', (e) => e.textContent)) && (await pg.$eval('#koltukBasla', (e) => e.disabled)) === true);
  await pg.evaluate(() => document.getElementById('koltukP').close()); await pg.selectOption('#koltuk', 'PEYK'); await pg.waitForTimeout(200); await pg.click('#koltukAc'); await pg.waitForFunction(() => /kayıtsız/.test(document.getElementById('koltukDurum').textContent), null, { timeout: 5000 }).catch(() => {});
  dm = await pg.$eval('#koltukDurum', (e) => e.textContent);
  kapi('KD5 kayıtsız koltuk: "açılamaz, önce işe alma" — Aç devre dışı ve soluk, "Eski sohbete dön" GÖRÜNMEZ (hidden fiilen gizler)', /kayıtsız/.test(dm) && (await pg.$eval('#koltukBasla', (e) => e.disabled && getComputedStyle(e).opacity !== '1')) === true && (await pg.$eval('#koltukEski', (e) => e.offsetParent === null)), `→ ${dm}`);
  await pg.evaluate(() => document.getElementById('koltukP').close()); await pg.selectOption('#koltuk', 'sedir-ana'); await pg.waitForTimeout(200); await pg.click('#koltukAc'); await pg.waitForFunction(() => /takılı/.test(document.getElementById('koltukDurum').textContent), null, { timeout: 5000 }).catch(() => {});
  dm = await pg.$eval('#koltukDurum', (e) => e.textContent);
  kapi('KD6 TAKILI koltuk (üçüncü hâl): "Claude takılı görünüyor" + ana koltuk (onarım betiği), eylem "Yeniden aç" etkin', /takılı görünüyor/.test(dm) && /ana koltuk/.test(dm) && (await pg.$eval('#koltukBasla', (e) => e.textContent + '|' + e.disabled)) === 'Yeniden aç|false', `→ ${dm}`);
  if (KARE) await pg.screenshot({ path: `${KARE}-koltuk-pencere.png` });
} finally { await b.close(); k1.kill(); k2.kill(); }
console.log(`\nGEÇEN: ${gecen} · KALAN: ${kalan}`); process.exit(kalan ? 1 : 0);
