// dumen-bekle.test.mjs — HERMETİK: sahte merkez (/dumen/mod) + dumen-bekle.mjs (kütüphane çağrısı ve GERÇEK süreç). Chromium gerekmez.
// Çalıştır: node dumen-bekle.test.mjs   (kütüphane yolu: BEKLE_LIB, varsayılan yanı)
import http from 'http';
import { spawn } from 'child_process';
const LIB = process.env.BEKLE_LIB || new URL('./dumen-bekle.mjs', import.meta.url).pathname;
const { bekle } = await import(LIB);
let gecen = 0, kalan = 0;
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
let mod = 'ajan', cevap = true; const istekler = [];
const merkez = http.createServer((q, r) => {
  istekler.push({ yontem: q.method, yol: q.url, baslik: Object.keys(q.headers) });
  if (q.url !== '/dumen/mod') { r.writeHead(404); return r.end(); }
  if (!cevap) { q.socket.destroy(); return; }
  r.setHeader('content-type', 'application/json'); r.end(JSON.stringify({ mod, an: 'x' }));
});
await new Promise((s) => merkez.listen(0, '127.0.0.1', s));
const URL_ = `http://127.0.0.1:${merkez.address().port}`;
const yazilar = []; const yaz = (s) => yazilar.push(s);
const sinir = (p, ad) => Promise.race([p, new Promise((s) => setTimeout(() => { kapi('SINIR ' + ad + ' 6 sn içinde bitmedi (sonsuz bekleme)', false); s(-1); }, 6000))]);
const kos = (o) => { yazilar.length = 0; return sinir(bekle({ merkez: URL_, aralikMs: 40, yaz, azamiMs: 3000, ...o }), JSON.stringify(Object.keys(o))); };

console.log('════ D · Dümen bekleme ════');
mod = 'ajan'; cevap = true; istekler.length = 0;
let rc = await kos({}); kapi('D1 mod zaten ajan → rc 0, "zaten ajanda" (bekleme yok)', rc === 0 && /zaten ajanda/.test(yazilar.join('\n')), `rc=${rc} ${yazilar}`);

mod = 'sultan'; setTimeout(() => { mod = 'ajan'; }, 300); const t0 = Date.now();
rc = await kos({}); const gecti = Date.now() - t0;
kapi('D2 Sultan\'dayken bekler, geri verilince rc 0 + "geri verildi" (≥250 ms bekledi)', rc === 0 && gecti >= 250 && /geri verildi/.test(yazilar.join('\n')) && !/zaten ajanda/.test(yazilar.join('\n')), `rc=${rc} sure=${gecti} ${yazilar}`);
kapi('D2b bekleme başında "Sultan\'da" tek kez söylenir', yazilar.filter((s) => /Sultan'da/.test(s)).length === 1, JSON.stringify(yazilar));

mod = 'sultan';
rc = await kos({ azamiMs: 400 }); kapi('D3 süre dolunca rc 3, "devam edebilirsin" DEMEZ (Dümen hâlâ Sultan\'da)', rc === 3 && !/devam edebilirsin/.test(yazilar.join('\n')) && /hâlâ Sultan/.test(yazilar.join('\n')), `rc=${rc} ${yazilar}`);

cevap = false; mod = 'ajan';
rc = await kos({}); kapi('D4 merkez art arda cevapsız → rc 4 (ÖLÇÜLEMEDİ), "devam" VARSAYILMAZ', rc === 4 && !/devam edebilirsin/.test(yazilar.join('\n')) && /ÖLÇÜLEMEDİ/.test(yazilar.join('\n')), `rc=${rc} ${yazilar}`);

cevap = true; let sayac = 0; const kesikOkuyucu = (u, o) => (++sayac <= 3 ? Promise.reject(new Error('kesik')) : fetch(u, o));
rc = await kos({ okuyucu: kesikOkuyucu }); kapi('D5 üç cevapsızlık tavanı aşmaz: 4. okumada ajan → rc 0 (kısa kesinti bekleyişi bozmaz)', rc === 0 && sayac === 4, `rc=${rc} sayac=${sayac}`);

// kesintiler ARALIKLI: 3 cevapsız, Sultan, 3 cevapsız, ajan → sayaç araya giren geçerli okumada sıfırlanır (toplam 6 ama art arda 3)
sayac = 0; const seri = ['x', 'x', 'x', 'sultan', 'x', 'x', 'x', 'ajan'];
const aralikliOkuyucu = (u, o) => { const k = seri[sayac++]; return k === 'x' ? Promise.reject(new Error('kesik')) : Promise.resolve({ ok: true, json: async () => ({ mod: k }) }); };
rc = await kos({ okuyucu: aralikliOkuyucu }); kapi('D5b kesintiler art arda değilse sayaç sıfırlanır: 3+3 cevapsız araya Sultan girince rc 0', rc === 0 && sayac === 8, `rc=${rc} sayac=${sayac}`);

rc = await sinir(bekle({ merkez: '', yaz }), 'merkezsiz'); kapi('D6 merkez adresi yok → rc 2', rc === 2);

kapi('D7 yalnız GET /dumen/mod: başka yol yok, jeton başlığı yok', istekler.length > 0 && istekler.every((i) => i.yontem === 'GET' && i.yol === '/dumen/mod' && !i.baslik.includes('x-defter-jeton') && !i.baslik.includes('authorization')), JSON.stringify(istekler.slice(0, 2)));

// GERÇEK SÜREÇ: arka plan bitişi ajanı uyandıran mekanizmanın kendisi (süreç sultan iken YAŞAR, geri verilince rc 0 ile ÇIKAR)
mod = 'sultan'; cevap = true;
const cocuk = spawn('node', [new URL('./dumen-bekle.mjs', import.meta.url).pathname.replace(/[^/]+$/, '') + (process.env.BEKLE_LIB ? process.env.BEKLE_LIB.replace(/^.*\//, '') : 'dumen-bekle.mjs'), '--merkez', URL_, '--aralik-sn', '0.05', '--azami-dk', '1'], { stdio: ['ignore', 'pipe', 'pipe'], cwd: process.env.BEKLE_LIB ? process.env.BEKLE_LIB.replace(/[^/]+$/, '') : undefined });
let cikti = ''; cocuk.stdout.on('data', (c) => { cikti += c; });
let bitti = null; cocuk.on('exit', (k) => { bitti = k; });
await new Promise((s) => setTimeout(s, 600));
kapi('D8 gerçek süreç: Sultan\'dayken ÇIKMAZ (ajan uyanmaz)', bitti === null, `bitti=${bitti}`);
mod = 'ajan';
await sinir(new Promise((s) => { const t = setInterval(() => { if (bitti !== null) { clearInterval(t); s(); } }, 30); }), 'gerçek süreç');
kapi('D9 gerçek süreç: geri verilince rc 0 ile çıkar ve "geri verildi" basar (uyandırma anı)', bitti === 0 && /geri verildi/.test(cikti), `bitti=${bitti} cikti=${cikti}`);
merkez.close();
console.log(`── SONUÇ: ${gecen} geçti · ${kalan} kaldı ──`);
process.exit(kalan === 0 ? 0 : 1);
