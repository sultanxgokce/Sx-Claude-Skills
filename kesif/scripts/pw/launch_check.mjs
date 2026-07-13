// launch_check.mjs — kesif güvenlik-omurgası SELFTEST'i (MOTOR-parçası, proje-bilmez).
// Kanıtladıkları: (1) headless-chromium root-suz LAUNCH oluyor; (2) render gerçek (DOM-metni okunuyor);
// (3) origin-allowlist DENY-ALL zorlanımı ÇALIŞIYOR — allowlist-dışı istek BLOKLANIR (kanıtı: ihlal-listesi).
// Çıplak chromium.launch yasağının nedeni bu dosya: context YALNIZ buradaki allowlist-route'la açılır.
// Girdi (env): PW_RUNTIME_DIR (playwright paketi burada) + KESIF_ALLOWLIST (virgüllü origin-prefix listesi).
// Çıktı: stdout JSON {launch_ok, render_ok, deny_ok, blocked} + RC=0 yalnız üçü de true ise.
import { createRequire } from 'node:module';
import { join } from 'node:path';
import process from 'node:process';

const SKILL_VERSION = '0.1.0-faz0';

const runtimeDir = process.env.PW_RUNTIME_DIR;
const allowRaw = process.env.KESIF_ALLOWLIST || '';
if (!runtimeDir) { console.error('PW_RUNTIME_DIR boş'); process.exit(2); }
const allowlist = allowRaw.split(',').map(s => s.trim()).filter(Boolean);
if (allowlist.length === 0) { console.error('KESIF_ALLOWLIST boş — allowlist-siz context YASAK'); process.exit(2); }

const require = createRequire(join(runtimeDir, 'package.json'));
const { chromium } = require('playwright');

// İç-sayfa şemaları serbest (gerçek-ağ değil); geri kalan her şey allowlist-prefix'ine tabi.
const INTERNAL = ['data:', 'about:', 'blob:'];
const allowed = (url) =>
  INTERNAL.some(p => url.startsWith(p)) || allowlist.some(p => url.startsWith(p));

const sonuc = { skill_version: SKILL_VERSION, launch_ok: false, render_ok: false, deny_ok: false, blocked: [] };
let browser;
try {
  browser = await chromium.launch({ args: ['--no-sandbox'] }); // root-suz container: sandbox kapalı, izole-ortam kabulü
  sonuc.launch_ok = true;

  const context = await browser.newContext();
  await context.route('**/*', (route) => {
    const url = route.request().url();
    if (allowed(url)) return route.continue();
    sonuc.blocked.push(url);
    return route.abort('blockedbyclient');
  });

  const page = await context.newPage();
  await page.setContent('<html><body><h1 id="probe">kesif-selftest</h1></body></html>');
  sonuc.render_ok = (await page.textContent('#probe')) === 'kesif-selftest';

  // Deny-kanıtı: allowlist-DIŞI hedefe kasıtlı istek (TEST-NET-1 192.0.2.0/24 — gerçek-ağa asla ulaşmaz;
  // zaten route-abort keser). Fetch reddi + ihlal-listesinde iz = zorlanım çalışıyor.
  const denied = await page.evaluate(async () => {
    try { await fetch('http://192.0.2.1/kesif-deny-probe'); return false; }
    catch { return true; }
  });
  sonuc.deny_ok = denied && sonuc.blocked.some(u => u.includes('192.0.2.1'));
} catch (e) {
  console.error('launch_check istisna:', e.message);
} finally {
  if (browser) await browser.close().catch(() => {});
}

console.log(JSON.stringify(sonuc, null, 2));
process.exit(sonuc.launch_ok && sonuc.render_ok && sonuc.deny_ok ? 0 : 1);
