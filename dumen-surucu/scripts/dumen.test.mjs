// dumen.test.mjs — HERMETİK: sahte merkez (mod + durak ucu + sayfalar) + gerçek headless Chromium (CDP portu) + dumen.mjs.
// Çalıştır: DUMEN_CHROME=<chrome-headless-shell> node dumen.test.mjs   (dumen.mjs yolu: DUMEN_LIB, varsayılan yanı)
import http from 'http';
import { spawn } from 'child_process';
import { mkdtempSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
const LIB = process.env.DUMEN_LIB || new URL('./dumen.mjs', import.meta.url).pathname;
const { Dumen, KapiHata } = await import(LIB);
const CHROME = process.env.DUMEN_CHROME;
if (!CHROME) { console.log('ÖLÇÜLEMEDİ: DUMEN_CHROME verilmedi'); process.exit(3); }

let mod = 'ajan'; const duraklar = [];
const FORM = `<!doctype html><title>f</title><input id=t type=text><input id=d type=date><select id=s><option value=a>a</option><option value=b>b</option></select><input id=pw type=password><input id=otp type=text name=otp><button id=g>Tamam</button><button id=ode>Öde</button>`;
const srv = http.createServer((q, r) => {
  if (q.url === '/dumen/mod') { r.setHeader('content-type', 'application/json'); return r.end(JSON.stringify({ mod, an: '' })); }
  if (q.url === '/api/dumen/durak' && q.method === 'POST') { let b = ''; q.on('data', (c) => b += c); return q.on('end', () => { duraklar.push(JSON.parse(b)); r.end('{}'); }); }
  r.setHeader('content-type', 'text/html; charset=utf-8'); r.end(FORM);
});
await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
const MERKEZ = `http://127.0.0.1:${srv.address().port}`;
const PORT = 19800 + Math.floor(Math.random() * 100);
const prof = mkdtempSync(join(tmpdir(), 'dumen-test-'));
const ch = spawn(CHROME, [`--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT}/json/version`); break; } catch { await new Promise((r) => setTimeout(r, 200)); } }

let G = 0, K = 0;
const ok = (ad, kosul, ayrinti = '') => { if (kosul) { G++; console.log('  ✓ ' + ad); } else { K++; console.log('  ✗ ' + ad + (ayrinti ? '  → ' + ayrinti : '')); } };
const satirlar = [];
const d = await Dumen.baglan({ cdpUrl: `http://127.0.0.1:${PORT}`, merkez: MERKEZ, zamanAsimiMs: 1500, yaz: (s) => satirlar.push(s) });
const hata = async (f) => { try { await f(); return null; } catch (e) { return e; } };
const deger = (sel) => d.page.evaluate((s) => document.querySelector(s).value, sel);
await d.goto(MERKEZ + '/sayfa');

console.log('── mod ajan');
await d.fill('#t', 'merhaba');
ok('D1 mod ajan: metin alanı dolduruldu', (await deger('#t')) === 'merhaba');
await d.fill('#d', '2026-10-27'); await d.selectOption('#s', 'b');
ok('D2 tarih ve seçim eylemleri sonuç verdi', (await deger('#d')) === '2026-10-27' && (await deger('#s')) === 'b');
const tarihOlay = d.eslesmis().filter((o) => o.tur === 'date' || o.tur === 'select-one');
ok('D3 metin dışı alan değişimi dinleyiciyle YAKALANDI ve ajan eylemiyle eşleşti (isTrusted=false)', tarihOlay.length >= 2 && tarihOlay.every((o) => o.trusted === false), JSON.stringify(tarihOlay));
ok('D4 yabancı (eylem penceresi dışı) olay yok', d.yabanci().length === 0, JSON.stringify(d.yabanci()));

console.log('── sayfa sahte olay üretir → yabancı');
await new Promise((r) => setTimeout(r, 300));
await d.page.evaluate(() => { const e = document.getElementById('t'); e.value = 'sahte'; e.dispatchEvent(new Event('input', { bubbles: true })); });
await new Promise((r) => setTimeout(r, 200));
ok('D5 sayfanın kendi olayı YABANCI sayıldı (insan ya da sayfa)', d.yabanci().length === 1 && d.yabanci()[0].id === 't', JSON.stringify(d.yabanci()));

console.log('── mod sultan');
mod = 'sultan'; satirlar.length = 0;
const eS = await hata(() => d.fill('#t', 'DEGISMEZ'));
ok('D6 mod sultan: eylem REDDEDİLDİ', eS instanceof KapiHata && eS.neden === 'sultanda', String(eS));
ok('D7 mod sultan: alan DEĞİŞMEDİ', (await deger('#t')) === 'sahte');
ok('D8 bekleme satırı terminale yazıldı', satirlar.some((s) => s.includes("Sultan'da")), satirlar.join('|'));
mod = 'ajan';

console.log('── merkez cevapsız → fail-closed');
const gercekMerkez = d.merkez; d.merkez = 'http://127.0.0.1:1';
const eM = await hata(() => d.fill('#t', 'DEGISMEZ2'));
ok('D9 merkez cevapsız: eylem REDDEDİLDİ (fail-closed)', eM instanceof KapiHata && eM.neden === 'merkez-cevapsiz', String(eM));
ok('D10 merkez cevapsız: alan DEĞİŞMEDİ', (await deger('#t')) === 'sahte');
d.merkez = gercekMerkez;

console.log('── durma noktaları');
const eP = await hata(() => d.fill('#pw', 'gizli-deger'));
ok('D11 parola alanı: eylem YAPILMADI, durak=sifre', eP instanceof KapiHata && eP.neden === 'durak' && (await deger('#pw')) === '' && duraklar.some((x) => x.neden === 'sifre'), `${eP} ${JSON.stringify(duraklar)}`);
const eO = await hata(() => d.fill('#otp', '123456'));
ok('D12 ad=otp alanı: durak=sms/sifre bildirildi, değer yazılmadı', eO instanceof KapiHata && (await deger('#otp')) === '', String(eO));
ok('D13 merkeze yalnız NEDEN gitti (değer/adres/çerez yok)', duraklar.every((x) => Object.keys(x).join() === 'neden'), JSON.stringify(duraklar));
await d.goto(MERKEZ + '/checkout');
const eOde = await hata(() => d.click('#ode'));
ok('D14 ödeme sayfasında "Öde" tıklaması durdu, durak=odeme', eOde instanceof KapiHata && duraklar.some((x) => x.neden === 'odeme'), `${eOde} ${JSON.stringify(duraklar)}`);
await d.click('#g');
ok('D15 ödeme sayfasında zararsız düğme tıklaması GEÇTİ (aşırı engelleme yok)', true);
await d.goto(MERKEZ + '/sayfa');
await d.page.evaluate(() => { const e = document.getElementById('pw'); e.value = 'insan-sifresi'; e.dispatchEvent(new Event('input', { bubbles: true })); });   // insan/sayfa parola alanını doldurdu
await new Promise((r) => setTimeout(r, 200));
const sizan = JSON.stringify(d.olaylar);
ok('D16 parola alanı değişimi KAYDEDİLDİ ama DEĞER yok (<gizli>)', sizan.includes('<gizli>') && !sizan.includes('insan-sifresi') && !sizan.includes('gizli-deger'), sizan.slice(-200));

console.log(`SONUÇ: geçti=${G} kaldı=${K}`);
await d.kapat(); ch.kill(); srv.close();
process.exit(K === 0 ? 0 : 1);
