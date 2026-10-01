/**
 * terminal-onar kapısı — RAPOR YOLU sınavı (<taban>/rapor/<ad>/). Gerçek HTTP, gerçek süreç.
 *
 * NİÇİN VAR (2026-09-30, SEDİR): kapı, girişten sonra küçük statik rapor sayfaları sunar ve
 * yalnız veri.json'a yazar. Bu yol bir DIŞ YÜZEYİN içinde yazma yetkisidir; gevşerse ya
 * girişsiz okunur ya da kutuda keyfî dosya yazılır. Her iddianın ATEŞLEYEN ve ATEŞLEMEYEN
 * yüzü birlikte ölçülür; mutasyonları: rapor.mutasyon.sh.
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kapi-rapor-sinav-'));
const RD = join(T, 'rapor');
const SIFRE = 'sinav-parolasi-1234';
let gecen = 0, kalan = 0; const basarisiz = [];
const kapi = (ad, kosul, ek = '') => {
  if (kosul) { gecen++; console.log(`  ✓ ${ad}`); }
  else { kalan++; basarisiz.push(ad); console.log(`  ✗ ${ad} ${ek}`); }
};

// sahne: bir rapor, bir foto, ayrıca rapor DIŞINDA bir gizli dosya (kaçış hedefi)
mkdirSync(join(RD, 'ornek', 'foto'), { recursive: true });
writeFileSync(join(RD, 'ornek', 'index.html'), '<title>ornek</title>SAYFA');
writeFileSync(join(RD, 'ornek', 'veri.json'), '{"surum":1}');
writeFileSync(join(RD, 'ornek', 'foto', 'a.jpg'), 'JPEGGIBI');
writeFileSync(join(T, 'gizli.log'), 'GIZLI');
// ad kısıtının ATEŞLEYEN yüzü: diskte VAR olan ama adı kurala uymayan bir klasör (yoksa 404'ü 'dosya yok' verir, kısıt ölçülmez)
mkdirSync(join(RD, 'BUYUK_ad'), { recursive: true }); writeFileSync(join(RD, 'BUYUK_ad', 'index.html'), 'SIZDI');

const P = 18781;
const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
  env: { ...process.env, KAPI_PORT: String(P), KAPI_TABAN: '/sinavkutu', TO_KUTU: 'sinavkutu', KAPI_RAPOR_DIZ: RD,
         KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE },
  stdio: ['ignore', 'pipe', 'pipe'],
});
for (let i = 0; i < 50; i++) {
  await new Promise((r) => setTimeout(r, 100));
  try { if ((await fetch(`http://127.0.0.1:${P}/sinavkutu/giris`)).status === 200) break; } catch {}
  if (p.exitCode !== null) { console.error('kapı açılmadı'); process.exit(2); }
}
const B = `http://127.0.0.1:${P}/sinavkutu`;
const iste = (yol, { cerez, metot = 'GET', govde, baslik = true } = {}) => fetch(B + yol, {
  method: metot, redirect: 'manual',
  headers: { ...(cerez ? { cookie: cerez } : {}), ...(govde != null && baslik ? { 'x-kapi': '1' } : {}), 'content-type': 'application/json' },
  body: govde,
});

try {
  console.log('\n── R · RAPOR YOLU ──');
  const g0 = await iste('/rapor/ornek/');
  kapi('R1 girişsiz rapor sayfası AÇILMAZ, girişe yönlenir', g0.status === 302 && (g0.headers.get('location') || '').endsWith('/sinavkutu/giris'), `→ ${g0.status} ${g0.headers.get('location')}`);
  const g0w = await iste('/rapor/ornek/veri.json', { metot: 'PUT', govde: '{"x":1}' });
  kapi('R2 girişsiz YAZMA reddedilir', g0w.status !== 200, `→ ${g0w.status}`);
  kapi('R2b girişsiz yazma dosyayı DEĞİŞTİRMEDİ', readFileSync(join(RD, 'ornek', 'veri.json'), 'utf8') === '{"surum":1}');

  const giris = await fetch(B + '/giris', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parola: SIFRE }) });
  const cerez = (giris.headers.get('set-cookie') || '').split(';')[0];
  kapi('R3 giriş çerezi alındı (sonraki kapılar tautoloji değil)', giris.status === 200 && cerez.startsWith('kapi='));

  const s = await iste('/rapor/ornek/', { cerez });
  kapi('R4 girişli rapor sayfası AÇILIR (index.html)', s.status === 200 && (await s.text()).includes('SAYFA'), `→ ${s.status}`);
  const y = await iste('/rapor/ornek', { cerez });
  kapi('R5 sondaki eğik çizgisiz ad, TABANLI adrese yönlenir', y.status === 302 && y.headers.get('location') === '/sinavkutu/rapor/ornek/', `→ ${y.headers.get('location')}`);
  const f = await iste('/rapor/ornek/foto/a.jpg', { cerez });
  kapi('R6 alt klasördeki dosya doğru türle gelir', f.status === 200 && f.headers.get('content-type') === 'image/jpeg', `→ ${f.status} ${f.headers.get('content-type')}`);

  for (const [ad, yol] of [['R7 kodlu kaçış (..%2f)', '/rapor/ornek/..%2f..%2fgizli.log'], ['R8 düz kaçış (../)', '/rapor/ornek/../../gizli.log'],
                           ['R9 geçersiz rapor adı', '/rapor/..%2f/gizli.log'], ['R10 büyük harf/özel karakterli ad', '/rapor/Ornek!/index.html']]) {
    const r = await iste(yol, { cerez }); const t = await r.text();
    kapi(`${ad} reddedilir, gizli dosya SIZMAZ`, r.status === 404 && !t.includes('GIZLI'), `→ ${r.status}`);
  }
  const ad = await iste('/rapor/BUYUK_ad/', { cerez }); const adT = await ad.text();
  kapi('R10b diskte VAR ama adı kurala uymayan klasör sunulmaz', ad.status === 404 && !adT.includes('SIZDI'), `→ ${ad.status}`);
  const yok = await iste('/rapor/olmayan/', { cerez });
  kapi('R11 olmayan rapor 404', yok.status === 404, `→ ${yok.status}`);

  const w1 = await iste('/rapor/ornek/veri.json', { cerez, metot: 'PUT', govde: '{"surum":2}', baslik: false });
  kapi('R12 x-kapi başlıksız yazma 403', w1.status === 403, `→ ${w1.status}`);
  const w2 = await iste('/rapor/ornek/veri.json', { cerez, metot: 'PUT', govde: 'bozuk{' });
  kapi('R13 geçersiz JSON 400', w2.status === 400, `→ ${w2.status}`);
  kapi('R13b reddedilen yazmalar dosyayı DEĞİŞTİRMEDİ', readFileSync(join(RD, 'ornek', 'veri.json'), 'utf8') === '{"surum":1}');
  // Sunucu sınırı aşan gövdede bağlantıyı keser (okumayı sürdürmez) → istemci ya 413 görür ya da bağlantı kopar.
  let w3d = 'bağlantı kesildi';
  try { const w3 = await iste('/rapor/ornek/veri.json', { cerez, metot: 'PUT', govde: '"' + 'x'.repeat(1024 * 1024 + 10) + '"' }); w3d = w3.status; } catch {}
  kapi('R14 1 MB üstü reddedilir ve dosya DEĞİŞMEZ', w3d !== 200 && readFileSync(join(RD, 'ornek', 'veri.json'), 'utf8') === '{"surum":1}', `→ ${w3d}`);
  const w4 = await iste('/rapor/ornek/index.html', { cerez, metot: 'PUT', govde: '{"a":1}' });
  kapi('R15 veri.json DIŞINDAKİ dosyaya yazılamaz', w4.status !== 200 && readFileSync(join(RD, 'ornek', 'index.html'), 'utf8').includes('SAYFA'), `→ ${w4.status}`);
  const w5 = await iste('/rapor/ornek/yeni.json', { cerez, metot: 'PUT', govde: '{"a":1}' });
  kapi('R16 yeni dosya OLUŞTURULAMAZ', w5.status !== 200 && !existsSync(join(RD, 'ornek', 'yeni.json')), `→ ${w5.status}`);

  const ok = await iste('/rapor/ornek/veri.json', { cerez, metot: 'PUT', govde: '{"surum":3}' });
  kapi('R17 geçerli yazma 200 ve dosyaya iner (R12–R16 tautoloji değil)', ok.status === 200 && readFileSync(join(RD, 'ornek', 'veri.json'), 'utf8') === '{"surum":3}', `→ ${ok.status}`);
  kapi('R18 atomik yazım geride geçici dosya bırakmaz', !readdirSync(join(RD, 'ornek')).some((n) => n.includes('gecici')));
  const oku = await iste('/rapor/ornek/veri.json', { cerez });
  kapi('R19 yazılan veri geri okunur, önbelleğe alınmaz', (await oku.text()) === '{"surum":3}' && oku.headers.get('cache-control') === 'no-store');
} finally {
  p.kill();
}
console.log(`\n${gecen} geçti · ${kalan} kaldı${kalan ? ' → ' + basarisiz.join(' | ') : ''}`);
process.exit(kalan ? 1 : 0);
