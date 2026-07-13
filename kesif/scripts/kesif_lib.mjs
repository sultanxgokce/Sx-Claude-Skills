// kesif_lib.mjs — kesif E2E ortak-kütüphanesi (generic, proje-bilmez). Güvenlik-omurgası burada:
// ORIGIN-ALLOWLIST tek-boğaz (deny-all + config-allowlist), trace lokal, çıplak chromium.launch YASAK
// (context DAİMA bu fabrikadan). Artefaktlar (trace.zip) LOKAL — Cortex'e/dışarı ASLA.
import { createRequire } from 'node:module';
import { join } from 'node:path';
import process from 'node:process';

export const SKILL_VERSION = '0.1.0-faz0';

const INTERNAL = ['data:', 'about:', 'blob:'];

function playwright() {
  const runtimeDir = process.env.PW_RUNTIME_DIR;
  if (!runtimeDir) throw new Error('PW_RUNTIME_DIR boş — bootstrap.sh koşulmadı');
  const require = createRequire(join(runtimeDir, 'package.json'));
  return require('playwright');
}

// Origin-EXACT izin denetimi (prefix-match DEĞİL). İç-şemalar (data:/about:/blob:) serbest; http(s) için
// URL.origin ile allowlist'e TAM-eşleşme aranır → `http://127.0.0.1:8000@evil.com` (userinfo-hilesi,
// origin=http://evil.com) ve `http://127.0.0.1:8000.evil.com` (origin farklı) bypass'ları KAPANIR.
// allowlist girdileri de origin'e normalize edilir (yol/query soyulur) — tolerant giriş, katı karşılaştırma.
function originNormalize(x) {
  try { return new URL(x).origin; } catch { return null; }
}
export function izinliUrl(u, allowOrigins) {
  if (INTERNAL.some((p) => u.startsWith(p))) return true;
  const o = originNormalize(u);
  return o !== null && allowOrigins.includes(o);
}

// Allowlist-zorlanımlı tarayıcı-oturumu. allowlist = origin listesi (ör. ['http://127.0.0.1:8000']).
// routeExtra: opsiyonel — allowlist-İÇİ isteklerde ek yönlendirme (enjeksiyon-harness için; null=düz continue).
export async function acStandart({ allowlist, routeExtra = null, tracePath = null }) {
  if (!Array.isArray(allowlist) || allowlist.length === 0) {
    throw new Error('allowlist boş — allowlist-siz oturum YASAK (güvenlik-omurgası)');
  }
  const allowOrigins = allowlist.map(originNormalize).filter(Boolean);
  if (allowOrigins.length === 0) throw new Error('allowlist origin-parse edilemedi (geçerli http(s) origin gerekli)');
  const izinli = (u) => izinliUrl(u, allowOrigins);
  const { chromium } = playwright();
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const context = await browser.newContext();
  const blocked = [];
  if (tracePath) await context.tracing.start({ screenshots: true, snapshots: true });

  await context.route('**/*', async (route) => {
    const url = route.request().url();
    if (!izinli(url)) {
      blocked.push(url);
      return route.abort('blockedbyclient'); // ALLOWLIST-DIŞI = BLOK (auth-broker/diğer-servis asla)
    }
    if (routeExtra) {
      const handled = await routeExtra(route, url); // enjeksiyon: mutant-asset/boş-JS/veri-müdahale
      if (handled) return;
    }
    return route.continue();
  });

  const page = await context.newPage();
  const kapat = async () => {
    try {
      if (tracePath) await context.tracing.stop({ path: tracePath });
    } catch { /* trace-yoksa yut */ }
    await browser.close().catch(() => {});
  };
  return { browser, context, page, blocked, kapat };
}

// Basit assert: gecti=false ise detay-mesajıyla döner (throw etmez — toplu-rapor için).
export function bekle(kosul, mesaj) {
  return { gecti: !!kosul, detay: kosul ? 'ok' : mesaj };
}
