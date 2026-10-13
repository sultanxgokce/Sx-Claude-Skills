/**
 * terminal-onar kapısı — RAPOR YOLU sınavı (<taban>/rapor/<ad>/). Gerçek HTTP, gerçek süreç.
 *
 * NİÇİN VAR (2026-09-30, SEDİR): kapı, girişten sonra küçük statik rapor sayfaları sunar ve
 * yalnız veri.json'a yazar. Bu yol bir DIŞ YÜZEYİN içinde yazma yetkisidir; gevşerse ya
 * girişsiz okunur ya da kutuda keyfî dosya yazılır. Her iddianın ATEŞLEYEN ve ATEŞLEMEYEN
 * yüzü birlikte ölçülür; mutasyonları: rapor.mutasyon.sh.
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, symlinkSync } from 'node:fs';
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
// 🔴 SEMBOLİK BAĞ FİKSTÜRÜ (bağımsız göz, tur 1): rapor ağacının İÇİNE konan bir bağ,
//    kökün DIŞINDAKİ bir dosyayı gösteriyor. Metinsel önek kontrolü bunu göremez.
writeFileSync(join(T, 'disarida.txt'), 'KOK-DISI-GIZLI');
try { symlinkSync(join(T, 'disarida.txt'), join(RD, 'ornek', 'kacis.txt')); } catch {}
try { symlinkSync(T, join(RD, 'ornek', 'disari')); } catch {}
// Yazma kaçışı fikstürü: ayrı bir rapor klasöründe veri.json'un KENDİSİ kök dışına bağ.
mkdirSync(join(RD, 'yazkacis'), { recursive: true });
writeFileSync(join(T, 'kurban.json'), '{"dokunulmadi":true}');
try { symlinkSync(join(T, 'kurban.json'), join(RD, 'yazkacis', 'veri.json')); } catch {}
// Bağlı DİZİN: rapor adı kökün dışındaki bir klasöre bakıyor → yazma oraya düşerdi.
mkdirSync(join(T, 'disklasor'), { recursive: true });
writeFileSync(join(T, 'disklasor', 'veri.json'), '{"dis":"dokunulmadi"}');
try { symlinkSync(join(T, 'disklasor'), join(RD, 'dizkacis')); } catch {}
writeFileSync(join(T, 'gizli.log'), 'GIZLI');
// ad kısıtının ATEŞLEYEN yüzü: diskte VAR olan ama adı kurala uymayan bir klasör (yoksa 404'ü 'dosya yok' verir, kısıt ölçülmez)
mkdirSync(join(RD, 'usta', 'belgeler'), { recursive: true });
writeFileSync(join(RD, 'usta', 'index.html'), '<!doctype html><title>usta</title>USTA-DEFTERI');
writeFileSync(join(RD, 'usta', 'veri.json'), '{"surum":1}');
writeFileSync(join(RD, 'usta', 'belgeler', 'b.txt'), 'BELGE');
writeFileSync(join(RD, 'usta', '.defter-yayin'), 'isaret');
writeFileSync(join(RD, 'ornek', '.gizli'), 'GIZLI');
symlinkSync(join(T, 'gizli.txt'), join(RD, 'usta', 'kacak.txt'));
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

  // 🔴 R21 · SEMBOLİK BAĞ KAÇIŞI (bağımsız göz, tur 1 — M9'un ÖLÇÜLEBİLİR yarısı).
  //    M9 (yazım kaçışı) adres ayrıştırıcısı yüzünden HTTP'den tetiklenemiyordu ve
  //    "ölçemedim" diye yazılmıştı. Ama kaçışın ikinci yolu BAĞ üzerinden geçiyor ve o
  //    HTTP'den ölçülebiliyor: ağacın içindeki bir bağ, kökün dışını gösterebilir.
  const kacis1 = await iste('/rapor/ornek/kacis.txt', { cerez });
  kapi('R21 ağaç içindeki bağ kök DIŞINI gösteriyorsa 404', kacis1.status === 404, `→ ${kacis1.status}`);
  const govde1 = await kacis1.text();
  kapi('R21b kök dışı içerik SIZMADI (durum kodu yetmez, gövde ölçülür)',
    !govde1.includes('KOK-DISI-GIZLI'), `→ ${govde1.slice(0, 40)}`);
  const kacis2 = await iste('/rapor/ornek/disari/disarida.txt', { cerez });
  kapi('R21c bağlı DİZİN üzerinden de geçilemez', kacis2.status === 404, `→ ${kacis2.status}`);
  const saglam = await iste('/rapor/ornek/foto/a.jpg', { cerez });
  kapi('R21d gerçek dosya HÂLÂ sunuluyor (R21 her şeyi kapatmadı)', saglam.status === 200, `→ ${saglam.status}`);

  // 🔴 R22 · YAZMA kaçışı (bağımsız göz, tur 4). Okuma korunuyordu, YAZMA korunmuyordu:
  //    sıra yüzünden PUT gerçek-yol sınamasından ÖNCE çalışıyordu. Hedef kökün dışına bakan
  //    bir bağ olsaydı yazma o dosyayı EZERDİ. Okuma kaçışı sızdırır, yazma kaçışı BOZAR.
  const yz = await iste('/rapor/yazkacis/veri.json', { cerez, metot: 'PUT', govde: '{"ele":"gecti"}' });
  kapi('R22 bağ olan veri.json\'a yazma REDDEDİLİR', yz.status === 404, `→ ${yz.status}`);
  kapi('R22b bağ EZİLSE de kök dışındaki dosya DEĞİŞMEDİ (atomik yazım bağı izlemez)',
    readFileSync(join(T, 'kurban.json'), 'utf8') === '{"dokunulmadi":true}',
    `→ ${readFileSync(join(T, 'kurban.json'), 'utf8')}`);
  // 🔴 ASIL AĞIR HÂL: rapor adının KENDİSİ kök dışına bakan bir dizin bağı. O zaman
  //    atomik yazım da kurtarmaz — geçici dosya da hedef de kökün DIŞINA düşer.
  const dz = await iste('/rapor/dizkacis/veri.json', { cerez, metot: 'PUT', govde: '{"ele":"gecti"}' });
  kapi('R22c bağlı DİZİNE yazma REDDEDİLİR', dz.status === 404, `→ ${dz.status}`);
  kapi('R22d kök dışı klasördeki dosya DEĞİŞMEDİ (dosya ölçülür)',
    readFileSync(join(T, 'disklasor', 'veri.json'), 'utf8') === '{"dis":"dokunulmadi"}',
    `→ ${readFileSync(join(T, 'disklasor', 'veri.json'), 'utf8')}`);

  // 🔴 R20 · ÇERÇEVE İZNİ (SEDİR'in önerdiği kapı · canlı sayfa kuralı 1.1.0).
  //    Ölçülmüştü: kapı hiç çerçeve başlığı göndermiyordu, yani açık oturumlu terminal ve
  //    rapor sayfaları herhangi bir sitenin içine gömülebiliyordu. Kapı HER cevapta ölçülür:
  //    tek bir yolun başlıksız kalması korumayı o yoldan deler.
  const csp = (y) => (y.headers.get('content-security-policy') || '');
  const girisSayfa = await iste('/giris');
  kapi('R20 giriş sayfasında frame-ancestors var', csp(girisSayfa).includes('frame-ancestors'), csp(girisSayfa) || 'başlık YOK');
  kapi('R20b kokpite izinli', csp(girisSayfa).includes('https://kokpit.mmepanel.com'), csp(girisSayfa));
  kapi('R20c herkese açık DEĞİL (R20 tautoloji değil)', !/frame-ancestors[^;]*\*/.test(csp(girisSayfa)), csp(girisSayfa));
  kapi('R20d rapor sayfasında da var (tek yol başlıksız kalmaz)', csp(oku).includes('frame-ancestors'), csp(oku) || 'başlık YOK');
  console.log('\n── Y · YAYIN KİPİ (.defter-yayin işaretli klasör: salt-okur + kum havuzu — REVAK tasarımı, 2.3.0) ──');
  {
    const csp2 = (y) => (y.headers.get('content-security-policy') || '');
    const y0 = await iste('/rapor/usta/');
    kapi('Y1 girişsiz yayın sayfası AÇILMAZ (girişe yönlenir)', y0.status === 302 && (y0.headers.get('location') || '').endsWith('/sinavkutu/giris'), `→ ${y0.status}`);
    const y1 = await iste('/rapor/usta/', { cerez }); const h1 = await y1.text();
    kapi('Y2 girişli yayın sayfası açılır (Y1 tautoloji değil)', y1.status === 200 && h1.includes('USTA-DEFTERI') && /text\/html/.test(y1.headers.get('content-type') || ''), `→ ${y1.status}`);
    kapi('Y3 kokpit içinde açılabilir (frame-ancestors kokpit), X-Frame-Options YOK',
      csp2(y1).includes("frame-ancestors 'self' https://kokpit.mmepanel.com") && !y1.headers.get('x-frame-options'), csp2(y1).slice(-70));
    kapi('Y4 yayın sayfası KUM HAVUZUNDA ve ağsız (kapı uçlarına istek atamaz)',
      /(^|;\s*)sandbox /.test(csp2(y1)) && !/allow-same-origin/.test(csp2(y1)) && csp2(y1).includes("connect-src 'none'") && csp2(y1).includes("form-action 'none'"), csp2(y1).slice(0, 80));
    const y2 = await iste('/rapor/usta', { cerez });
    kapi('Y5 eğik çizgisiz yayın adı TABANLI yola yönlenir', y2.status === 302 && (y2.headers.get('location') || '').endsWith('/sinavkutu/rapor/usta/'), `→ ${y2.status} ${y2.headers.get('location')}`);
    const y3 = await iste('/rapor/usta/belgeler/b.txt', { cerez });
    kapi('Y6 belge (txt) sunulur, o da kum havuzunda', y3.status === 200 && (await y3.text()) === 'BELGE' && /sandbox/.test(csp2(y3)) && /text\/plain/.test(y3.headers.get('content-type') || ''), `→ ${y3.status}`);
    const y4 = await iste('/rapor/usta/.defter-yayin', { cerez });
    kapi('Y7 gizli ad (yayın işareti) sunulmaz', y4.status === 404, `→ ${y4.status}`);
    const y5 = await iste('/rapor/usta/%2e%2e/%2e%2e/gizli.txt', { cerez });
    const y5b = await iste('/rapor/usta%2F..%2F..%2Fgizli.txt', { cerez });
    kapi('Y8 yol kaçışı (%2e%2e, kodlu eğik çizgi) dizin dışına çıkamaz', y5.status === 404 && y5b.status === 404 && !(await y5.text()).includes('GIZLI'), `→ ${y5.status} ${y5b.status}`);
    const y6 = await iste('/rapor/usta/kacak.txt', { cerez });
    kapi('Y9 sembolik bağ dizin dışını SUNMAZ', y6.status === 404 && !(await y6.text()).includes('GIZLI'), `→ ${y6.status}`);
    const y7 = await iste('/rapor/usta/', { cerez, metot: 'POST' });
    const y8 = await iste('/rapor/usta/veri.json', { cerez, metot: 'PUT', govde: '{"surum":9}' });
    kapi('Y10 yayın kipinde yazma yöntemi REDDEDİLİR (405) — veri.json dahil, dosya değişmedi',
      y7.status === 405 && y8.status === 405 && readFileSync(join(RD, 'usta', 'veri.json'), 'utf8') === '{"surum":1}', `→ ${y7.status} ${y8.status}`);
    const y9 = await iste('/rapor/usta/', { cerez, metot: 'HEAD' });
    kapi('Y11 HEAD yayın kipinde 200 ve kum havuzu başlığı taşır', y9.status === 200 && /sandbox/.test(csp2(y9)), `→ ${y9.status}`);
    // 🔴 GERİLEME ZIRHI: işaretsiz klasör (SEDİR'in ev/ridvan sayfaları veri.json'u tarayıcıdan PUT'lar) ESKİ davranışta kalır
    const e1 = await iste('/rapor/ornek/', { cerez });
    kapi('Y12 işaretsiz klasör kum havuzuna ALINMAZ (SEDİR sayfası veri.json yazabilsin)', e1.status === 200 && !/sandbox/.test(csp2(e1)) && csp2(e1).includes('frame-ancestors'), csp2(e1).slice(0, 60));
    const e2 = await iste('/rapor/ornek/.gizli', { cerez });
    kapi('Y13 gizli ad işaretsiz klasörde de sunulmaz', e2.status === 404, `→ ${e2.status}`);
    const e3 = await iste('/rapor/ornek/', { cerez, metot: 'POST' });
    kapi('Y14 işaretsiz klasörde yazma yöntemi eskisi gibi 404 (405 yalnız yayın kipi)', e3.status === 404, `→ ${e3.status}`);
  }
} finally {
  p.kill();
}
console.log(`\n${gecen} geçti · ${kalan} kaldı${kalan ? ' → ' + basarisiz.join(' | ') : ''}`);
process.exit(kalan ? 1 : 0);
