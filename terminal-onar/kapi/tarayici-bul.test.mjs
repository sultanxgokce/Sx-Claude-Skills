// tarayici-bul.test.mjs — tarayıcı bulucu ÇALIŞTIRILARAK ölçülür (hermetik: sahte yükleyici + sahte dosya varlığı; ağ/tarayıcı yok).
// Son kapı gerçek kutuda: varsayılan adaylar içinden ikilisi olan birini bulur mu (bulamazsa ÖLÇÜLEMEDİ sayılır, kırmızı değil).
import { tarayiciBul, varsayilanAdaylar, surumKarsilastir } from './tarayici-bul.mjs';
import { existsSync } from 'node:fs';
let gecen = 0, kalan = 0, olculemedi = false;
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
  const b = varsayilanAdaylar({ HOME: '/ev' }, (d) => (d === '/ev/.nvm/versions/node' ? ['v9.1.0', 'v22.23.0', 'v22.9.1', 'v18.20.4'] : []));
  const nvmler = b.filter((d) => d.includes('/.nvm/')).map((d) => d.split('/')[5]);
  kapi('C3 🔴 nvm sürümleri SAYISAL sıralanır, en yeni önce (v9 v22\'nin önüne geçmez)', JSON.stringify(nvmler) === JSON.stringify(['v22.23.0', 'v22.9.1', 'v18.20.4', 'v9.1.0']), `→ ${nvmler.join(' ')}`);
  kapi('C3b düz metin sırası v9\'u öne koyardı (mutasyon kanıtı: eski sıralama yanlış)', ['v9.1.0', 'v22.23.0', 'v22.9.1'].sort().reverse()[0] === 'v9.1.0' && [ 'v9.1.0', 'v22.23.0', 'v22.9.1' ].sort(surumKarsilastir)[0] === 'v22.23.0');
  kapi('C4 nvm dizini yoksa liste yine çıkar (Nexus kalır), hata yok', varsayilanAdaylar({ HOME: '/yok' }, () => { throw new Error('ENOENT'); }).includes('/config/projects/Nexus/ui/node_modules'));
}
console.log('── G · gerçek kutu (bütünleşik): varsayılan adaylardan ikilisi olan biri bulunur mu');
{
  let r = null, h = null; try { r = await tarayiciBul(); } catch (e) { h = e; }
  if (r) kapi(`G1 bulundu: ${r.dizin} → ${r.ikili.split('/').slice(-3).join('/')}`, true);
  else { olculemedi = true; console.log(`  ÖLÇÜLEMEDİ: bu kutuda ikilisi olan Playwright yok —\n  ${h.message.replace(/\n/g, '\n  ')}`); }
}
console.log(`\ntarayici-bul.test: ${gecen} geçti · ${kalan} kaldı${olculemedi ? ' · G1 ÖLÇÜLEMEDİ (rc 4, yeşil DEĞİL)' : ''}`);
// rc: 1 = kırmızı · 4 = hermetik kapılar yeşil ama gerçek kutu ölçülemedi (bağımsız göz tur 1: ölçülemeyen rc 0 dönmesin) · 0 = hepsi
process.exit(kalan ? 1 : olculemedi ? 4 : 0);
