// dumen-yazdir.test.mjs — 0.10.0 HERMETİK: sahte merkez + sahte site + gerçek headless Chromium (CDP) + dumen.mjs. Sınanan: yazdirYakala.
// Çalıştır: DUMEN_CHROME=<chrome-headless-shell> node dumen-yazdir.test.mjs   (dumen.mjs yolu: DUMEN_LIB, varsayılan yanı)
import http from 'http';
import { cocukBaslat, gecici } from './sinav-cocuk.mjs';
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
const LIB = process.env.DUMEN_LIB || new URL('./dumen.mjs', import.meta.url).pathname;
const { Dumen, KapiHata } = await import(LIB);
const CHROME = process.env.DUMEN_CHROME;
if (!CHROME) { console.log('ÖLÇÜLEMEDİ: DUMEN_CHROME verilmedi'); process.exit(3); }

const PDF = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n');
const SAYFA = `<!doctype html><meta charset=utf-8><title>etiket paneli</title>
<div id=icerik style="font:20px sans-serif">ETIKET-ANA-SAYFA barkod 7260038702245305</div>
<span id=sayac>0</span> <span id=hicsonuc>-</span>
<button id=ana onclick="document.getElementById('sayac').textContent=String(+document.getElementById('sayac').textContent+1);window.print()">Ana sayfayı yazdır</button>
<button id=gec onclick="setTimeout(()=>window.print(),800)">Gecikmeli yazdır</button>
<button id=alt onclick="const f=document.createElement('iframe');f.id='kap';f.srcdoc='<!doctype html><p>ETIKET-ALT-BELGE</p>';f.onload=()=>f.contentWindow.print();document.body.appendChild(f)">Alt belgeyi yazdır</button>
<button id=sor onclick="document.getElementById('yamasonuc').textContent=(String(window.print).includes('native code')&&window.__dumenYazdirSay===undefined)?'dogal':'yamali'">Yazdırma işlevi durumu</button><span id=yamasonuc>-</span>
<button id=hic onclick="document.getElementById('hicsonuc').textContent='tiklandi'">Yazdırmaz</button>`;
let mod = 'ajan';
const srv = http.createServer((q, r) => {
  if (q.url === '/dumen/mod') { r.setHeader('content-type', 'application/json'); return r.end(JSON.stringify({ mod, an: '' })); }
  if (q.url.startsWith('/api/dumen/')) { r.setHeader('content-type', 'application/json'); return r.end('{"ok":true}'); }
  r.setHeader('content-type', 'text/html; charset=utf-8'); r.end(SAYFA);
});
await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
const MERKEZ = `http://127.0.0.1:${srv.address().port}`;
const PORT = 19960 + Math.floor(Math.random() * 30);
const prof = gecici('dumen-yazdir-prof-');
const ch = cocukBaslat(CHROME, [`--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT}/json/version`); break; } catch { await new Promise((r) => setTimeout(r, 200)); } }
const CDP = `http://127.0.0.1:${PORT}`;
const T = gecici('dumen-yazdir-'); const KOK = join(T, 'izinli'); const DISARI = join(T, 'disari'); mkdirSync(KOK); mkdirSync(DISARI);

let G = 0, K = 0;
const ok = (ad, kosul, ayrinti = '') => { if (kosul) { G++; console.log('  ✓ ' + ad); } else { K++; console.log('  ✗ ' + ad + (ayrinti ? '  → ' + String(ayrinti).slice(0, 300) : ''));
  if (process.env.DUMEN_ILK_KIRMIZI === '1') { ch.kill('SIGKILL'); console.log(`SONUÇ: geçti=${G} kaldı=${K} (ilk kırmızıda duruldu)`); process.exit(1); } } };
const hata = async (f) => { try { await f(); return null; } catch (e) { return e; } };
const neden = async (f) => { const e = await hata(f); return e ? (e instanceof KapiHata ? e.neden : 'HAM:' + String(e.message).split('\n')[0]) : null; };
const sekmeSay = async () => (await (await fetch(`${CDP}/json/list`)).json()).filter((t) => t.type === 'page').length;
const pdfMi = (y) => existsSync(y) && readFileSync(y).subarray(0, 4).toString('latin1') === '%PDF';
const t0 = Date.now();
try {
  const d = await Dumen.baglan({ cdpUrl: CDP, merkez: MERKEZ, zamanAsimiMs: 1500, dosyaKok: [KOK], eylemSureMs: 2500, eylemAzamiMs: 12000 }); await d.goto(MERKEZ + '/panel');
  const taban = await sekmeSay();
  console.log('── yazdirYakala: ana sayfa');
  const r1 = await hata(() => d.yazdirYakala('#ana', join(KOK, 'ana.pdf')));
  const s1 = existsSync(join(KOK, 'ana.pdf')) ? readFileSync(join(KOK, 'ana.pdf')).length : 0;
  ok('Y1 ana sayfanın yazdırması PDF olarak yazıldı (%PDF, gerçek sayfa boyutu), pencere açılmadı', !r1 && pdfMi(join(KOK, 'ana.pdf')) && s1 > 1000 && (await sekmeSay()) === taban, r1 && r1.message);
  await d.click('#sor');
  ok('Y2 yakalamadan sonra window.print eski (doğal) haline döndü, yama kalıntısı yok', (await d.metin('#yamasonuc')) === 'dogal', await d.metin('#yamasonuc'));
  console.log('── yazdirYakala: gecikmeli · alt belge');
  const r3 = await hata(() => d.yazdirYakala('#gec', join(KOK, 'gec.pdf')));
  ok('Y3 800 ms sonra gelen yazdırma da yakalanır', !r3 && pdfMi(join(KOK, 'gec.pdf')), r3 && r3.message);
  const r4 = await hata(() => d.yazdirYakala('#alt', join(KOK, 'alt.pdf')));
  const s4 = existsSync(join(KOK, 'alt.pdf')) ? readFileSync(join(KOK, 'alt.pdf')).length : 0;
  ok('Y4 alt belgenin (iframe) yazdırması PDF olarak yazıldı, geçici sekme kapandı', !r4 && pdfMi(join(KOK, 'alt.pdf')) && s4 > 500 && s4 < s1 && (await sekmeSay()) === taban, r4 && r4.message);
  console.log('── yazdirYakala: kapılar');
  ok('Y6 yazdırma çağrılmazsa yazdirma-yok (asılmaz), dosya yazılmaz', (await neden(() => d.yazdirYakala('#hic', join(KOK, 'hic.pdf'), { olayMs: 1200 }))) === 'yazdirma-yok' && !existsSync(join(KOK, 'hic.pdf')));
  const sayacOnce = await d.metin('#sayac');
  ok('Y7 .pdf olmayan hedef reddedilir (dosya-turu), tıklama yapılmaz', (await neden(() => d.yazdirYakala('#hic', join(KOK, 'x.png')))) === 'dosya-turu' && (await d.metin('#sayac')) === sayacOnce);
  ok('Y8 izinli dizin dışına yazılmaz (dosya-izinsiz)', (await neden(() => d.yazdirYakala('#ana', join(DISARI, 'x.pdf')))) === 'dosya-izinsiz' && !existsSync(join(DISARI, 'x.pdf')) && (await d.metin('#sayac')) === sayacOnce);
  ok('Y9 var olan dosya sormadan ezilmez (dosya-var), ustuneYaz ile ezilir', (await neden(() => d.yazdirYakala('#ana', join(KOK, 'ana.pdf')))) === 'dosya-var' && (await neden(() => d.yazdirYakala('#ana', join(KOK, 'ana.pdf'), { ustuneYaz: true }))) === null);
  const durum = await d.metin('#icerik');
  const r10 = await hata(() => d.yazdirYakala('#ana', join(KOK, 'ikinci.pdf')));
  ok('Y10 art arda ikinci yakalama da çalışır (yama kalıntısı yok)', !r10 && pdfMi(join(KOK, 'ikinci.pdf')) && durum.includes('ETIKET-ANA-SAYFA'), r10 && r10.message);
  await d.kapat();
} catch (e) { K++; console.log('  ✗ SINAV ÇÖKTÜ: ' + String(e && e.stack || e).slice(0, 600)); }
finally { ch.kill('SIGKILL'); srv.close(); }
console.log(`SONUÇ: geçti=${G} kaldı=${K} süre=${Math.round((Date.now() - t0) / 1000)} sn`);
process.exit(K === 0 && G >= 9 ? 0 : 1);
