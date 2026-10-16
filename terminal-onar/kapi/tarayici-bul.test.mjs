// tarayici-bul.test.mjs — tarayıcı bulucu ÇALIŞTIRILARAK ölçülür (hermetik: sahte yükleyici + sahte dosya varlığı; ağ/tarayıcı yok).
// Son kapı gerçek kutuda: varsayılan adaylar içinden ikilisi olan birini bulur mu (bulamazsa ÖLÇÜLEMEDİ sayılır, kırmızı değil).
import { tarayiciBul, varsayilanAdaylar } from './tarayici-bul.mjs';
import { existsSync } from 'node:fs';
let gecen = 0, kalan = 0;
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const sahte = (paketVar, ikili) => ({ chromium: { executablePath: () => ikili } , paketVar });
const yukle = (harita) => async (d) => { const p = harita[d]; if (!p || !p.paketVar) throw new Error("Cannot find module '" + d + "/playwright/index.mjs'"); return { chromium: p.chromium }; };

console.log('── A · seçim sırası ve ikili kontrolü');
{
  const harita = { '/nexus': sahte(true, '/cache/1217/chrome'), '/nvm22': sahte(true, '/cache/1200/chrome') };
  const var1 = (y) => y === '/cache/1200/chrome';
  const r = await tarayiciBul({ adaylar: ['/nexus', '/nvm22'], yukle: yukle(harita), dosyaVar: var1 });
  kapi('A1 🔴 paketi olan ama İKİLİSİ olmayan ilk aday ATLANIR, ikilisi olan ikinci seçilir (SERDAR vakası)', r.dizin === '/nvm22' && r.ikili === '/cache/1200/chrome', `→ ${r.dizin}`);
  kapi('A1b atlanan aday sebebiyle listede (ikili yok + kurulum ipucu)', r.denenen.length === 1 && /İKİLİSİ yok/.test(r.denenen[0]) && /playwright install/.test(r.denenen[0]), `→ ${r.denenen[0]}`);
  const r2 = await tarayiciBul({ adaylar: ['/nexus', '/nvm22'], yukle: yukle(harita), dosyaVar: () => true });
  kapi('A2 ikisi de tamamsa İLK aday kazanır (sıra korunur — açık beyan önde)', r2.dizin === '/nexus');
  const r3 = await tarayiciBul({ adaylar: ['/yok', '/nvm22'], yukle: yukle(harita), dosyaVar: () => true });
  kapi('A3 paketi olmayan aday atlanır ("paket yok" sebebiyle)', r3.dizin === '/nvm22' && /paket yok/.test(r3.denenen[0]), `→ ${r3.denenen[0]}`);
}
console.log('── B · hiçbiri yoksa: fırlatır, denenenleri sayar (çökme değil, ÖLÇÜLEMEDİ malzemesi)');
{
  const harita = { '/nexus': sahte(true, '/cache/1217/chrome') };
  let h = null; try { await tarayiciBul({ adaylar: ['/nexus', '/yok'], yukle: yukle(harita), dosyaVar: () => false }); } catch (e) { h = e; }
  kapi('B1 hata fırlatılır, mesaj iki yolu da sebebiyle sayar', !!h && h.denenen.length === 2 && /nexus.*İKİLİSİ yok/.test(h.message) && /yok: paket yok/.test(h.message), `→ ${h && h.message.replace(/\n/g, ' | ')}`);
  let h2 = null; try { await tarayiciBul({ adaylar: [], yukle: yukle({}) }); } catch (e) { h2 = e; }
  kapi('B2 aday yoksa da fırlatır ("aday yok")', !!h2 && /aday yok/.test(h2.message));
}
console.log('── C · varsayılan aday listesi');
{
  const a = varsayilanAdaylar({ KANIT_PLAYWRIGHT_DIR: '/acik/beyan', HOME: '/olmayan-ev' });
  kapi('C1 açık beyan (KANIT_PLAYWRIGHT_DIR) listenin BAŞINDA', a[0] === '/acik/beyan');
  kapi('C2 Nexus ui/node_modules eski varsayılan olarak hâlâ listede (geriye dönük)', a.includes('/config/projects/Nexus/ui/node_modules'));
  const b = varsayilanAdaylar({ HOME: process.env.HOME || '/config' });
  kapi('C3 nvm global node_modules dizinleri (varsa) listede, en yeni sürüm önce', b.some((d) => /\.nvm\/versions\/node\/v[\d.]+\/lib\/node_modules$/.test(d)) || !existsSync((process.env.HOME || '/config') + '/.nvm/versions/node'), `→ ${b.join(' · ')}`);
}
console.log('── G · gerçek kutu (bütünleşik): varsayılan adaylardan ikilisi olan biri bulunur mu');
{
  let r = null, h = null; try { r = await tarayiciBul(); } catch (e) { h = e; }
  if (r) kapi(`G1 bulundu: ${r.dizin} → ${r.ikili.split('/').slice(-3).join('/')}`, true);
  else console.log(`  ÖLÇÜLEMEDİ (yeşil sayılmaz): bu kutuda ikilisi olan Playwright yok —\n  ${h.message.replace(/\n/g, '\n  ')}`);
}
console.log(`\ntarayici-bul.test: ${gecen} geçti · ${kalan} kaldı`);
process.exit(kalan ? 1 : 0);
