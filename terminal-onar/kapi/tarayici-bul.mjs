// tarayici-bul.mjs — tarayıcı sınavları için Playwright'ı BULUR (2.13.1 · SERDAR bulgusu gorev_01M50PZVB1GCVG6D33V1PH96CT).
//
// Niçin: pano-sinav varsayılan olarak /config/projects/Nexus/ui/node_modules'a bakıyordu. Orada paket VAR ama tarayıcı ikilisi
// indirilmemiş (chromium_headless_shell-1217 yok) → import geçer, launch ÇÖKER (rc 1, yığın dökümü; rc=4 ÖLÇÜLEMEDİ değil).
// nvm global paketinin ikilisi var ama ona yalnız KANIT_PLAYWRIGHT_DIR el ile verilince gidiliyordu. Üç koşum üç ortam hatası.
// Kural: aday dizinleri sırayla dene; paketi İÇE AKTAR ve tarayıcı İKİLİSİ diskte mi diye bak; ikisi de tamam olan ilkini seç.
// Hiçbiri olmazsa denenen her yolu sebebiyle söyleyen bir hata fırlat — çağıran bunu ÖLÇÜLEMEDİ (rc 4) olarak basar.
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

// nvm sürüm adları (v22.23.0 · v9.1.0) SAYISAL sıralanır, en yeni önce — düz metin sırası v9'u v22'nin önüne koyardı (bağımsız göz tur 1).
export function surumKarsilastir(a, b) {
  const p = (x) => String(x).replace(/^v/, '').split('.').map((n) => parseInt(n, 10) || 0);
  const [x, y] = [p(a), p(b)];
  for (let i = 0; i < Math.max(x.length, y.length); i++) { const d = (y[i] || 0) - (x[i] || 0); if (d) return d; }
  return 0;
}
// listele(dizin) → alt dizin adları (sınav sahte liste verir)
export function varsayilanAdaylar(ortam = process.env, listele = readdirSync) {
  const a = [];
  if (ortam.KANIT_PLAYWRIGHT_DIR) a.push(ortam.KANIT_PLAYWRIGHT_DIR);
  a.push('/config/projects/Nexus/ui/node_modules');
  const nvm = join(ortam.HOME || '/config', '.nvm/versions/node');
  try { for (const s of [...listele(nvm)].sort(surumKarsilastir)) a.push(join(nvm, s, 'lib/node_modules')); } catch { /* nvm yok */ }
  return [...new Set(a)];
}

// adaylar: dizin listesi · yukle(dizin) → { chromium } (varsayılan: gerçek import) · dosyaVar(yol) → bool
export async function tarayiciBul({ adaylar = varsayilanAdaylar(), yukle, dosyaVar = existsSync } = {}) {
  yukle = yukle || (async (d) => { const m = await import(pathToFileURL(join(d, 'playwright/index.mjs')).href); return { chromium: m.chromium }; });
  const denenen = [];
  for (const d of adaylar) {
    let chromium;
    try { ({ chromium } = await yukle(d)); } catch (e) { denenen.push(`${d}: paket yok (${(e && e.message || '').split('\n')[0].slice(0, 80)})`); continue; }
    let yol = '';
    try { yol = chromium.executablePath(); } catch (e) { denenen.push(`${d}: ikili yolu alınamadı (${e && e.message})`); continue; }
    if (!yol || !dosyaVar(yol)) { denenen.push(`${d}: paket var, tarayıcı İKİLİSİ yok (${yol || '?'}) — npx playwright install`); continue; }
    return { chromium, dizin: d, ikili: yol, denenen };
  }
  const h = new Error('tarayıcı bulunamadı — denenen yollar:\n  ' + (denenen.length ? denenen.join('\n  ') : '(aday yok)'));
  h.denenen = denenen; throw h;
}
