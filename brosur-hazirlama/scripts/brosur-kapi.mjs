#!/usr/bin/env node
// Broşür kapısı — ölçülebilen ölçütleri ölçer, ölçemediklerini "gözle bakılacak" diye listeler.
// Kullanım: node brosur-kapi.mjs brosur.html   · çıkış 0 yeşil · 1 kırmızı · 3 ölçülemedi
// Panel işareti: data-panel="kapak|ic-kanat|ic-1|ic-2|ic-3|arka". Tarayıcı: Playwright (PW_KOK ile kök verilebilir).
// TAŞINABİLİRLİK (MUAVİN, 2026-09-19 global paketleme): AKAR kutusunda doğdu. Tarayıcı kökü artık
// PW_KOK → AKAR yolu → normal çözümleme sırasıyla aranır; tarayıcı BAŞLAMAZSA rc=3 (eskiden yığın izi + rc=1).
// Yasak söz listesi kuruma göre değişir: BROSUR_YASAK="desen|desen" (verilmezse AKAR listesi).
// F5 PDF sayacı BROSUR_PDF_KAPISI ile verilir; yoksa F5 ölçülemedi → rc=3 (kırmızı DEĞİL).
import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {existsSync} from 'node:fs';
const dosya = process.argv[2];
if (!dosya || !existsSync(dosya)) { console.error('Kullanım: node brosur-kapi.mjs brosur.html'); process.exit(3); }
// 'bugün' kelimesi tek başına yasak değil ("bugün nasıl yapılıyor" meşru); zamana bağlı iddia gözle bakılır (G4).
// AKAR listesi (fiyat/oran/vaat kapısı) — kuruma göre değişir; BROSUR_YASAK ile ezilir.
const YASAK = process.env.BROSUR_YASAK
  ? process.env.BROSUR_YASAK.split('|').filter(Boolean).map(d => new RegExp(d, 'i'))
  : [/%\s?\d/, /\byüzde \d/i, /garanti/i, /kazan[çc]/i, /tasarruf/i];
// AKAR kutusunda tarayıcı kitaplıkları ayrı ortamda durur; başka kutuda bu üç değişken zararsızdır.
const PWL = '/config/.local/micromamba/envs/pw-libs';
if (existsSync(PWL)) { process.env.LD_LIBRARY_PATH ||= PWL + '/lib'; process.env.FONTCONFIG_PATH ||= PWL + '/etc/fonts'; process.env.FONTCONFIG_FILE ||= PWL + '/etc/fonts/fonts.conf'; }
let chromium; const denenen = [];
for (const kok of [process.env.PW_KOK, '/config/tooling/pw-runtime/', import.meta.url].filter(Boolean)) {
  for (const ad of ['playwright', 'playwright-core']) {
    try { ({chromium} = createRequire(kok.endsWith('/') || kok.startsWith('file:') ? kok : kok + '/')(ad)); break; }
    catch { denenen.push(kok + ' → ' + ad); }
  }
  if (chromium) break;
}
if (!chromium) { console.error('ÖLÇÜLEMEDİ: tarayıcı kütüphanesi yok — broşür ÖLÇÜLMEDİ, "yeşil" DEĞİL. Denenen: ' + denenen.join(' · ') + '. Çözüm: PW_KOK=<playwright kurulu dizin>.'); process.exit(3); }
let b;
try { b = await chromium.launch({args: ['--no-sandbox', '--disable-dev-shm-usage']}); }
catch (e) { console.error('ÖLÇÜLEMEDİ: tarayıcı başlatılamadı — ' + String(e && e.message || e).split('\n')[0]); process.exit(3); }
const p = await b.newPage({viewport: {width: 1600, height: 1100}});
await p.goto('file://' + resolve(dosya)); await p.waitForTimeout(800);
const o = await p.evaluate(() => {
  const say = t => (t.trim().match(/[\p{L}\p{N}’']+/gu) || []).length;
  const paneller = [...document.querySelectorAll('[data-panel]')].map(el => {
    const r = el.getBoundingClientRect(); let metinAlan = 0, enKucuk = 99, kirimaYakin = 0;
    const yuruyucu = document.createTreeWalker(el, NodeFilter.SHOW_TEXT); const gorulen = new Set();
    while (yuruyucu.nextNode()) { const n = yuruyucu.currentNode; if (!n.textContent.trim()) continue; const e = n.parentElement; if (gorulen.has(e)) continue; gorulen.add(e);
      const s = getComputedStyle(e); if (s.visibility === 'hidden' || s.display === 'none') continue;
      const q = e.getBoundingClientRect(); if (!q.width || !q.height) continue; metinAlan += q.width * q.height;
      if (!e.closest('[data-kunye]')) enKucuk = Math.min(enKucuk, parseFloat(s.fontSize));
      const mm = r.width / 99; if (q.left - r.left < 5 * mm - 0.5 || r.right - q.right < 5 * mm - 0.5) kirimaYakin++; }
    return {ad: el.dataset.panel, kelime: say(el.innerText), metinOran: metinAlan / (r.width * r.height), enKucukPx: enKucuk, pxMm: r.width / 99, kirimaYakin, tablo: el.querySelectorAll('table').length, uzunListe: [...el.querySelectorAll('ul,ol')].filter(l => l.children.length > 3).length, metin: el.innerText};
  });
  return {paneller};
});
await b.close();
if (!o.paneller.length) { console.error('ÖLÇÜLEMEDİ: data-panel işaretli panel bulunamadı'); process.exit(3); }
let kirmizi = 0; const yaz = (ok, m) => { console.log((ok ? '  ✓ ' : '  ✗ ') + m); if (!ok) kirmizi++; };
const toplam = o.paneller.filter(x => x.ad !== 'arka').reduce((t, x) => t + x.kelime, 0) + (o.paneller.find(x => x.ad === 'arka') ? Math.min(o.paneller.find(x => x.ad === 'arka').kelime, 30) : 0);
yaz(toplam <= 350, 'B1 toplam kelime ' + toplam + ' (≤ 350; arka panelden en çok 30 sayılır)');
for (const x of o.paneller) {
  const pt = x.enKucukPx / x.pxMm / 0.3528;   // ekran pikseli → basılı punto (panel 99 mm)
  if (x.ad === 'kapak') yaz(x.kelime <= 20, 'A1 kapak ' + x.kelime + ' kelime (≤ 20)');
  const tavan = /^ic-\d/.test(x.ad) ? 40 : 70;
  if (x.ad !== 'kapak') yaz(x.kelime <= tavan, 'B2 ' + x.ad + ' ' + x.kelime + ' kelime (≤ ' + tavan + ')');
  yaz(pt >= 8.95, 'B3 ' + x.ad + ' en küçük gövde yazısı ' + pt.toFixed(1) + ' pt (≥ 9; künye için data-kunye)');
  yaz(x.tablo === 0 && x.uzunListe === 0, 'B4 ' + x.ad + ' tablo ' + x.tablo + ' · üçten uzun liste ' + x.uzunListe);
  yaz(x.kirimaYakin === 0, 'D2 ' + x.ad + ' kırıma ya da kenara 5 mm\'den yakın metin öğesi: ' + x.kirimaYakin);
  const y = YASAK.filter(r => r.test(x.metin)).map(String); yaz(!y.length, 'G3/G4 ' + x.ad + ' yasak söz: ' + (y.join(' ') || 'yok'));
}
const ic = o.paneller.filter(x => /^ic/.test(x.ad)); const oran = ic.reduce((t, x) => t + x.metinOran, 0) / (ic.length || 1);
yaz(oran <= 0.55, 'C1 iç yüzde metin alanı %' + Math.round(oran * 100) + ' (≤ %55)');
console.log('\n  GÖZLE BAKILACAK (kapı ölçemez, teslimde imzalanır): A2 kol boyu okunurluk · A3 kapakta tek odak · C2 tam açılışta tek kompozisyon · C3 ekran görüntüsü kırpılmış yakın plan · C4 görüntü içi yazı · D1 panel testi · E1/E2 tek eylem, kare kod tarandı · G4 zamanla yanlışlaşan söz (bugün, tarih, kalan gün) · F baskı payları, 300 dpi, gömülü yazı tipi · katlanmış görünüm');
console.log(kirmizi ? '\n  ❌ ' + kirmizi + ' ölçüt kırmızı — "hazır" denmez' : '\n  ✅ ölçülen ölçütler yeşil — gözle bakılacaklar imzalanmadan yine "hazır" denmez');
// 18 Eyl 2026: Işık v6 PDF'i 3 sayfaydı (0,1 mm taşma → boş sayfa); kapı HTML'i ölçüyor, PDF'i değil.
// PDF=<yol> verilirse sayfa sayısı ölçülür (BEKLENEN_SAYFA, varsayılan 2); fazlası/eksiği kırmızı.
let olculemedi = 0;
if (process.env.PDF) {
  const sayac = process.env.BROSUR_PDF_KAPISI || 'tanitim/scripts/pdf-sayfa-kapisi.py';   // AKAR deposu yolu (cwd'ye göreli)
  if (!existsSync(sayac)) { console.log('  ⊘ F5 PDF sayfa sayısı ÖLÇÜLEMEDİ — sayaç yok: ' + sayac + ' (BROSUR_PDF_KAPISI ver)'); olculemedi++; }
  else {
    const { spawnSync } = await import('node:child_process');
    const r = spawnSync('python3', [sayac, process.env.PDF, process.env.BEKLENEN_SAYFA || '2'], { encoding: 'utf8' });
    const ok = r.status === 0; console.log((ok ? '  ✓ ' : '  ✗ ') + 'F5 PDF sayfa sayısı: ' + (r.stdout || r.stderr).trim()); if (!ok) kirmizi++;
  }
} else console.log('  · F5 PDF sayfa sayısı ÖLÇÜLMEDİ — PDF=<yol> verilmedi');
process.exit(kirmizi ? 1 : olculemedi ? 3 : 0);
