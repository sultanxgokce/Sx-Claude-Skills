// dumen.test.mjs — HERMETİK: sahte merkez (mod + durak ucu + sayfalar) + gerçek headless Chromium (CDP portu) + dumen.mjs.
// Çalıştır: DUMEN_CHROME=<chrome-headless-shell> node dumen.test.mjs   (dumen.mjs yolu: DUMEN_LIB, varsayılan yanı)
import http from 'http';
import { spawn } from 'child_process';
import { mkdtempSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
const LIB = process.env.DUMEN_LIB || new URL('./dumen.mjs', import.meta.url).pathname;
const { Dumen, KapiHata } = await import(LIB);
const CHROME = process.env.DUMEN_CHROME;
if (!CHROME) { console.log('ÖLÇÜLEMEDİ: DUMEN_CHROME verilmedi'); process.exit(3); }

let mod = 'ajan'; let uyariKod = 200; const uyariGelen = []; const uyariBaslik = []; let durakKod = 200; const duraklar = []; const durakBaslik = [];
const JETON_DOSYA = join(mkdtempSync(join(tmpdir(), 'dumen-jeton-')), 'jeton'); const JETON = 'sahte-jeton-' + Math.random().toString(36).slice(2);
writeFileSync(JETON_DOSYA, JETON + '\n'); process.env.DUMEN_DEFTER_JETON = JETON_DOSYA;
const FORM = `<!doctype html><title>f</title><input id=t type=text><input id=d type=date><select id=s><option value=a>a</option><option value=b>b</option></select><input id=pw type=password><input id=otp type=text name=otp><button id=g>Tamam</button><button id=ode>Öde</button>`;
let modSonra = null;   // /dumen/mod cevaplandıktan SONRA bir kez çalışır (kapı geçti, tam o sırada soket düşsün)
const srv = http.createServer((q, r) => {
  if (q.url === '/dumen/mod') { r.setHeader('content-type', 'application/json'); r.end(JSON.stringify({ mod, an: '' })); if (modSonra) { const f = modSonra; modSonra = null; f(); } return; }
  if (q.url === '/yavas') { return setTimeout(() => { r.setHeader('content-type', 'text/html; charset=utf-8'); r.end(FORM); }, 4000); }
  if (q.url === '/api/dumen/uyari' && q.method === 'POST') { let b = ''; q.on('data', (c) => b += c); return q.on('end', () => { uyariGelen.push(JSON.parse(b)); uyariBaslik.push(q.headers['x-defter-jeton'] || null); r.statusCode = uyariKod; r.end('{}'); }); }
  if (q.url === '/api/dumen/durak' && q.method === 'POST') { let b = ''; q.on('data', (c) => b += c); return q.on('end', () => { duraklar.push(JSON.parse(b)); durakBaslik.push(q.headers['x-defter-jeton'] || null); r.statusCode = durakKod; r.end('{}'); }); }
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
const { chromium } = await (await import(LIB)).playwrightYukle();
const ham = (await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`)).contexts()[0].pages()[0];   // TEST'in kendi bağlantısı: 'insan/sayfa' rolü + okuma
const d = await Dumen.baglan({ cdpUrl: `http://127.0.0.1:${PORT}`, merkez: MERKEZ, zamanAsimiMs: 1500, yaz: (s) => satirlar.push(s) });
const hata = async (f) => { try { await f(); return null; } catch (e) { return e; } };
const deger = (sel) => ham.evaluate((s) => document.querySelector(s).value, sel);
await d.goto(MERKEZ + '/sayfa');

console.log('── mod ajan');
await d.fill('#t', 'merhaba');
ok('D1 mod ajan: metin alanı dolduruldu', (await deger('#t')) === 'merhaba');
await d.fill('#d', '2026-10-27'); await d.selectOption('#s', 'b');
ok('D2 tarih ve seçim eylemleri sonuç verdi', (await deger('#d')) === '2026-10-27' && (await deger('#s')) === 'b');
const tarihOlay = d.eslesmis().filter((o) => o.tur === 'date' || o.tur === 'select-one');
ok('D3 metin dışı alan değişimi dinleyiciyle YAKALANDI ve ajan eylemiyle eşleşti (isTrusted=false)', tarihOlay.length >= 2 && tarihOlay.every((o) => o.trusted === false), JSON.stringify(tarihOlay));
ok('D4 yabancı (eylem penceresi dışı) olay yok', d.yabanci().length === 0, JSON.stringify(d.yabanci()));

const gorU = d.uyarilar().filter((u) => u.kod === 'gorulemeyen-eylem');
ok('D3b fill(tarih) ve selectOption "köprüde GÖRÜNMEZ" uyarısı bastı (2 eylem)', gorU.length === 2 && gorU.some((u) => u.ad === 'fill' && u.hedef === '#d') && gorU.some((u) => u.ad === 'selectOption' && u.hedef === '#s'), JSON.stringify(gorU));
ok('D3c uyarı terminale de yazıldı', satirlar.filter((x) => x.includes('GÖRÜNMEZ')).length === 2, satirlar.join(' | '));
ok('D3d metin alanı fill\'i (Input.insertText, köprü görür) uyarı ÜRETMEDİ', !gorU.some((u) => u.hedef === '#t'), JSON.stringify(gorU));
ok('D3e uyarı alan DEĞERİNİ taşımaz', !JSON.stringify(d.uyarilar()).includes('2026-10-27'));
await d.iletimBekle();
const gorG = uyariGelen.filter((u) => u.kod === 'gorulemeyen-eylem');
ok('D3f görünmez eylem uyarısı MERKEZE gitti (2 eylem × kod+sayı), jeton başlığıyla', gorG.length === 2 && uyariBaslik.slice(0, 2).every((h) => h === JETON), JSON.stringify({ gorG, uyariBaslik }));
ok('D3g merkeze yalnız {kod, n} gitti — hedef/değer/adres/çerez YOK', uyariGelen.every((u) => Object.keys(u).sort().join() === 'kod,n') && !JSON.stringify(uyariGelen).includes('2026-10-27') && !JSON.stringify(uyariGelen).includes('#d'), JSON.stringify(uyariGelen));

console.log('── sayfa sahte olay üretir → yabancı');
await new Promise((r) => setTimeout(r, 300));
await ham.evaluate(() => { const e = document.getElementById('t'); e.value = 'sahte'; e.dispatchEvent(new Event('input', { bubbles: true })); });
await new Promise((r) => setTimeout(r, 200));
ok('D5 sayfanın kendi olayı YABANCI sayıldı (insan ya da sayfa)', d.yabanci().length === 1 && d.yabanci()[0].id === 't', JSON.stringify(d.yabanci()));

await new Promise((r) => setTimeout(r, 800));   // HİÇBİR eylem/uyarilar() çağrısı yok: uyarı olay anında kendiliğinden gelmeli
ok('D5c eylem dışı uyarı KENDİLİĞİNDEN terminale yazıldı (sonraki kapı/uyarilar() çağrısı beklenmeden)', satirlar.some((x) => x.includes('DIŞINDA')), satirlar.join(' | '));
const yU = d.uyarilar().filter((u) => u.kod === 'yabanci-olay');
await d.iletimBekle();
ok('D5f eylem dışı değişiklik uyarısı MERKEZE gitti (kod yabanci-olay, n=1)', uyariGelen.some((u) => u.kod === 'yabanci-olay' && u.n === 1), JSON.stringify(uyariGelen));
uyariKod = 500; satirlar.length = 0; const oncekiG = uyariGelen.length;
await d.fill('#d', '2026-11-01'); await d.iletimBekle();
ok('D5g merkez uyarı ucu 500 verirse eylem YİNE yapıldı, terminale "İLETİLEMEDİ" yazıldı', (await deger('#d')) === '2026-11-01' && uyariGelen.length > oncekiG && satirlar.some((x) => x.includes('İLETİLEMEDİ')), satirlar.join(' | '));
uyariKod = 200;
const jetonYol = process.env.DUMEN_DEFTER_JETON; process.env.DUMEN_DEFTER_JETON = jetonYol + '.yok'; satirlar.length = 0; const oncekiJ = uyariGelen.length;
await d.fill('#d', '2026-11-02'); await d.iletimBekle(); process.env.DUMEN_DEFTER_JETON = jetonYol;
ok('D5h kutu jetonu okunamazsa uyarı JETONSUZ GÖNDERİLMEZ (merkeze istek yok), eylem sürer, terminale "kutu jetonu okunamadı" yazılır', uyariGelen.length === oncekiJ && (await deger('#d')) === '2026-11-02' && satirlar.some((x) => x.includes('kutu jetonu okunamadı')), satirlar.join(' | '));
ok('D5b eylem dışı değişiklik UYARI üretti', yU.length === 1 && yU[0].hedef === 't', JSON.stringify(yU));
ok('D5d aynı olay ikinci kez uyarmaz', d.uyarilar().filter((u) => u.kod === 'yabanci-olay').length === 1);

console.log('── click sırasında sayfanın sentetik olayı "köprüde görünmez eylem" SAYILMAZ');
await ham.evaluate(() => { const b = document.createElement('button'); b.id = 'sahteB'; b.textContent = 'x'; b.onclick = () => document.getElementById('t').dispatchEvent(new Event('input', { bubbles: true })); document.body.appendChild(b); });
const once = d.uyarilar().filter((u) => u.kod === 'gorulemeyen-eylem').length;
await d.click('#sahteB');
ok('D5e click sırasındaki sentetik olay görülemeyen-eylem UYARISI üretmedi', d.uyarilar().filter((u) => u.kod === 'gorulemeyen-eylem').length === once, JSON.stringify(d.uyarilar()));

console.log('── mod sultan');
mod = 'sultan'; satirlar.length = 0;
const eS = await hata(() => d.fill('#t', 'DEGISMEZ'));
ok('D6 mod sultan: eylem REDDEDİLDİ', eS instanceof KapiHata && eS.neden === 'sultanda', String(eS));
ok('D7 mod sultan: alan DEĞİŞMEDİ', (await deger('#t')) === 'sahte');
ok('D8 bekleme satırı terminale yazıldı', satirlar.some((s) => s.includes("Sultan'da")), satirlar.join('|'));
mod = 'ajan';

console.log('── merkez cevapsız → fail-closed');
const dM = await Dumen.baglan({ cdpUrl: `http://127.0.0.1:${PORT}`, merkez: 'http://127.0.0.1:1', zamanAsimiMs: 800, yaz: () => {} });
const eM = await hata(() => dM.fill('#t', 'DEGISMEZ2'));
ok('D9 merkez cevapsız: eylem REDDEDİLDİ (fail-closed)', eM instanceof KapiHata && eM.neden === 'merkez-cevapsiz', String(eM));
ok('D10 merkez cevapsız: alan DEĞİŞMEDİ (DEGISMEZ2 yazılmadı)', (await deger('#t')) !== 'DEGISMEZ2');

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
ok('D17 ham nesneler DIŞARIYA AÇIK DEĞİL (d.page/d.cdp/d.tarayici/d.merkez yok)', d.page === undefined && d.cdp === undefined && d.tarayici === undefined && d.merkez === undefined);
durakKod = 500; satirlar.length = 0; duraklar.length = 0;
await d.goto(MERKEZ + '/sayfa');
const e500 = await hata(() => d.fill('#pw', 'x'));
ok('D18 durak ucu 500 verirse eylem yine YAPILMAZ ama bildirildi=false ve satır UYARIR', e500 instanceof KapiHata && e500.bildirildi === false && (await deger('#pw')) === '' && satirlar.some((x) => x.includes('İLETİLEMEDİ')), `${e500} ${satirlar.join('|')}`);
durakKod = 200;
ok('D15 ödeme sayfasında zararsız düğme tıklaması GEÇTİ (aşırı engelleme yok)', true);
await d.goto(MERKEZ + '/sayfa');
await ham.evaluate(() => { const e = document.getElementById('pw'); e.value = 'insan-sifresi'; e.dispatchEvent(new Event('input', { bubbles: true })); });   // insan/sayfa parola alanını doldurdu
await new Promise((r) => setTimeout(r, 200));
const sizan = JSON.stringify(d.olayKaydi());
ok('D16 parola alanı değişimi KAYDEDİLDİ ama DEĞER yok (<gizli>)', sizan.includes('<gizli>') && !sizan.includes('insan-sifresi') && !sizan.includes('gizli-deger'), sizan.slice(-200));

console.log('── durak bildirimi jeton başlığı');
ok('D19 durak bildirimi x-defter-jeton başlığıyla gitti (her istek)', durakBaslik.length > 0 && durakBaslik.every((h) => h === JETON), JSON.stringify(durakBaslik.map((h) => h && h.slice(0, 6))));
ok('D20 jeton değeri günlük satırlarında YOK', !satirlar.some((x) => x.includes(JETON)));

console.log('── mod sultan iken soket düşer');
const PORT2 = PORT + 100; const prof2 = mkdtempSync(join(tmpdir(), 'dumen-test2-'));
const baslat = () => spawn(CHROME, [`--remote-debugging-port=${PORT2}`, `--user-data-dir=${prof2}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
const bekle = async () => { for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT2}/json/version`); return; } catch { await new Promise((r) => setTimeout(r, 200)); } } };
let ch2 = baslat(); await bekle();
const sat2 = [];
const dS = await Dumen.baglan({ cdpUrl: `http://127.0.0.1:${PORT2}`, merkez: MERKEZ, zamanAsimiMs: 1500, yaz: (s) => sat2.push(s) });
await dS.goto(MERKEZ + '/sayfa');
mod = 'sultan';
ch2.kill('SIGKILL'); await new Promise((r) => setTimeout(r, 600));   // köprü soketi düştü (Dümen Sultan'a geçti)
const eK = await hata(() => dS.fill('#t', 'x'));
ok('D21 sultan + soket düşük: eylem "sultanda" (ham bağlantı hatası DEĞİL)', eK instanceof KapiHata && eK.neden === 'sultanda', String(eK));
const eK2 = await hata(() => dS.click('#g'));
ok('D22 sultan iken tekrar denenince yine "sultanda", yeniden bağlanma YOK', eK2 instanceof KapiHata && eK2.neden === 'sultanda' && dS.durum().baglanmaSayisi === 1, JSON.stringify(dS.durum()));
ok('D23 bekleme satırı yazıldı', sat2.some((x) => x.includes("Sultan'da")));
ch2 = baslat(); await bekle();   // geri verildi: köprü ucu yeniden açıldı ama mod hâlâ sultan
const eK3 = await hata(() => dS.fill('#t', 'x'));
ok('D24 uç yeniden açıldı ama mod hâlâ sultan: yine bağlanmadı', eK3 instanceof KapiHata && eK3.neden === 'sultanda' && dS.durum().baglanmaSayisi === 1, JSON.stringify(dS.durum()));
mod = 'ajan';
const eR = await hata(async () => { await dS.goto(MERKEZ + '/sayfa'); await dS.fill('#t', 'geri-verildi'); });
ok('D25 mod ajan olunca YENİDEN bağlandı ve eylem yapıldı', eR === null && dS.durum().baglanmaSayisi === 2 && dS.durum().kopuk === false, JSON.stringify(dS.durum()));
await dS.kapat(); ch2.kill();

console.log('── kapı geçtikten SONRA soket düşer (eylem sırasında)');
const PORT3 = PORT + 200; const prof3 = mkdtempSync(join(tmpdir(), 'dumen-test3-'));
const baslat3 = () => spawn(CHROME, [`--remote-debugging-port=${PORT3}`, `--user-data-dir=${prof3}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
const bekle3 = async () => { for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT3}/json/version`); return; } catch { await new Promise((r) => setTimeout(r, 200)); } } };
let ch3 = baslat3(); await bekle3();
const dZ = await Dumen.baglan({ cdpUrl: `http://127.0.0.1:${PORT3}`, merkez: MERKEZ, zamanAsimiMs: 1500, yaz: () => {} });
mod = 'ajan';
modSonra = () => { mod = 'sultan'; setTimeout(() => ch3.kill('SIGKILL'), 300); };
const eZ = await hata(() => dZ.goto(MERKEZ + '/yavas', { timeout: 6000 }));
ok('D26 eylem sırasında Sultan aldı + soket düştü: "sultanda" (ham hata ya da baglanti-koptu DEĞİL)', eZ instanceof KapiHata && eZ.neden === 'sultanda', String(eZ));
mod = 'ajan'; ch3 = baslat3(); await bekle3();
ok('D27 geri verildi (mod ajan): kopukluk durumda görünür', dZ.durum().kopuk === true && dZ.durum().baglanmaSayisi === 1, JSON.stringify(dZ.durum()));
const eR2 = await hata(() => dZ.goto(MERKEZ + '/sayfa'));
ok('D28 mod ajan olunca bir sonraki eylemde yeniden bağlandı', eR2 === null && dZ.durum().kopuk === false && dZ.durum().baglanmaSayisi === 2, JSON.stringify(dZ.durum()));
modSonra = () => { setTimeout(() => ch3.kill('SIGKILL'), 300); };   // mod ajan KALIR, soket yine düşer
const eY = await hata(() => dZ.goto(MERKEZ + '/yavas', { timeout: 6000 }));
ok('D29 mod ajan iken soket düşerse: açık hata "baglanti-koptu" (sessiz yutulmaz)', eY instanceof KapiHata && eY.neden === 'baglanti-koptu', String(eY));
await dZ.kapat(); ch3.kill();

// ── SALT-OKUR yöntemler (metin · kare) — SİNAN/VADE 31 Eki
mod = 'ajan'; await d.goto(MERKEZ + '/sayfa');
await ham.fill('#t', 'gizli-deger-731');
const uyariOnce = uyariGelen.length, durakOnce = duraklar.length; satirlar.length = 0;
const m1 = await d.metin();
ok('O1 metin(): görünür sayfa yazısı döner', typeof m1 === 'string' && m1.includes('Tamam') && m1.includes('Öde'), JSON.stringify(m1).slice(0, 120));
ok('O2 metin(): giriş alanının DEĞERİ metne girmez', !m1.includes('gizli-deger-731'));
ok('O3 okuma sayfayı değiştirmez, terminale/merkeze metin yazmaz, uyarı üretmez', (await deger('#t')) === 'gizli-deger-731' && !satirlar.some((x) => x.includes('Tamam')) && uyariGelen.length === uyariOnce, JSON.stringify(satirlar));
const eOP = await hata(() => d.metin('#pw'));
ok('O4 parola alanını hedefleyen okuma durma noktasına takılır', eOP instanceof KapiHata && eOP.neden === 'durak' && duraklar.length === durakOnce + 1 && duraklar.at(-1).neden === 'sifre', String(eOP));
const kareYol = join(mkdtempSync(join(tmpdir(), 'dumen-kare-')), 'k.png');
await d.kare(kareYol);
const kb = (await import('fs')).readFileSync(kareYol);
ok('O5 kare(yol): PNG dosyası yazılır', kb.length > 100 && kb.subarray(1, 4).toString() === 'PNG', String(kb.length));
mod = 'sultan';
const eOM = await hata(() => d.metin());
const kareYol2 = kareYol.replace('k.png', 'k2.png');
const eOK = await hata(() => d.kare(kareYol2));
ok('O6 Dümen Sultanda iken okuma da YOK (metin + kare "sultanda", dosya yazılmaz)', eOM instanceof KapiHata && eOM.neden === 'sultanda' && eOK instanceof KapiHata && eOK.neden === 'sultanda' && !(await import('fs')).existsSync(kareYol2), String(eOM) + ' / ' + String(eOK));
mod = 'ajan';
const eOY = await hata(() => d.kare());
ok('O7 kare() yolsuz reddedilir', eOY instanceof KapiHata && eOY.neden === 'kare-yolu-yok', String(eOY));

console.log(`SONUÇ: geçti=${G} kaldı=${K}`);
await ham.context().browser().close().catch(() => {}); await d.kapat(); await dM.kapat(); ch.kill(); srv.close();
process.exit(K === 0 ? 0 : 1);
