/**
 * terminal-onar kapısı — TABAN YOLU sınavı. Gerçek HTTP, gerçek süreç, borusuz.
 *
 * 🔴 NİÇİN VAR: bu kapı 14 kutuya dağıtılacak ve her kutuda bir DIŞ YÜZEY açacak.
 *    Taban yolu desteği merkez sayfanın ön şartı; yanlış olursa hata sessizdir —
 *    sayfa açılır, çağrılar kök yola gider, MERKEZE düşer ve kutuya hiç ulaşmaz.
 *    Sessiz hata, 14 kutuda 14 kez tekrarlanır.
 *
 * Her iddianın ATEŞLEYEN ve ATEŞLEMEYEN yüzü birlikte ölçülür (SEDİR/MEDDAH kuralı).
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import net from 'node:net';

const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kapi-sinav-'));
const SIFRE = 'sinav-parolasi-1234';
let gecen = 0, kalan = 0; const basarisiz = [];
const kapi = (ad, kosul, ek = '') => {
  if (kosul) { gecen++; console.log(`  ✓ ${ad}`); }
  else { kalan++; basarisiz.push(ad); console.log(`  ✗ ${ad} ${ek}`); }
};

// Sahte ttyd: UNIX soketinde HTTP konuşur, aldığı yolu geri söyler.
function sahteTtyd(yol) {
  const s = net.createServer((c) => {
    let b = '';
    c.on('data', (d) => {
      b += d;
      if (!b.includes('\r\n\r\n')) return;
      const istenen = b.split(' ')[1] || '';
      const g = JSON.stringify({ ttyd: true, yol: istenen });
      c.end(`HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: ${Buffer.byteLength(g)}\r\n\r\n${g}`);
    });
    c.on('error', () => {});
  });
  return new Promise((r) => s.listen(yol, () => r(s)));
}

async function kapiAc(taban, port) {
  const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
    env: { ...process.env, KAPI_PORT: String(port), KAPI_TABAN: taban, TO_KUTU: 'sinavkutu',
           KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  for (let i = 0; i < 50; i++) {
    await new Promise((r) => setTimeout(r, 100));
    try { const r = await fetch(`http://127.0.0.1:${port}${taban}/giris`); if (r.status === 200) return p; } catch {}
    if (p.exitCode !== null) throw new Error('kapı açılmadı, rc=' + p.exitCode);
  }
  throw new Error('kapı zaman aşımı');
}

const iste = (port, yol, { cerez, metot = 'GET', govde } = {}) =>
  fetch(`http://127.0.0.1:${port}${yol}`, {
    method: metot, redirect: 'manual',
    headers: { ...(cerez ? { cookie: cerez } : {}), ...(govde ? { 'content-type': 'application/json', 'x-kapi': '1' } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });

const ttyd = await sahteTtyd(join(T, 'ttyd.sock'));
const P1 = 18771, P2 = 18772;
const kapiTaban = await kapiAc('/sedir', P1);
const kapiKok = await kapiAc('', P2);

console.log('\n── T · TABAN YOLU (kapı /sedir altında) ──');
{
  const g = await iste(P1, '/sedir/giris');
  kapi('T1 giriş sayfası TABAN altında açılır', g.status === 200, `→ ${g.status}`);
  const k = await iste(P1, '/giris');
  kapi('T2 taban DIŞI istek reddedilir (404) — kapı başkasının yoluna cevap vermez', k.status === 404, `→ ${k.status}`);

  const y = await iste(P1, '/sedir');
  kapi('T3 tabanın kendisi sondaki eğik çizgiye yönlenir',
    y.status === 302 && y.headers.get('location') === '/sedir/', `→ ${y.status} ${y.headers.get('location')}`);

  const a = await iste(P1, '/sedir/', {});
  kapi('T4 girişsiz kök TABANLI giriş sayfasına yönlenir (kök yola DEĞİL)',
    a.status === 302 && a.headers.get('location') === '/sedir/giris', `→ ${a.headers.get('location')}`);

  const api = await iste(P1, '/sedir/api/durum');
  kapi('T5 girişsiz API 401 döner (yönlendirme değil)', api.status === 401, `→ ${api.status}`);

  // ── giriş ──
  const red = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: 'yanlis' } });
  kapi('T6 yanlış parola REDDEDİLİR', red.status === 401, `→ ${red.status}`);
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  kapi('T7 doğru parola KABUL (T6 tautoloji değil)', ok.status === 200, `→ ${ok.status}`);
  const sc = ok.headers.get('set-cookie') || '';
  kapi('T8 çerez YALNIZ kendi tabanında geçerli (Path=/sedir)', /Path=\/sedir(;|$)/.test(sc), `→ ${sc.slice(0, 80)}`);
  kapi('T9 çerez HttpOnly+Secure+SameSite korunur',
    /HttpOnly/.test(sc) && /Secure/.test(sc) && /SameSite=Strict/.test(sc), `→ ${sc.slice(0, 90)}`);

  const cerez = 'kapi=' + (sc.match(/kapi=([^;]+)/) || [])[1];
  const sayfa = await iste(P1, '/sedir/', { cerez });
  const html = await sayfa.text();
  kapi('T10 sayfa kendi tabanını TAŞIR (sunucudan öğrenir, tahmin etmez)',
    html.includes('window.__TABAN="/sedir"'), `→ ${html.slice(0, 60)}`);
  kapi('T11 sayfadaki mutlak varlık yolları tabana taşınmış',
    html.includes('href="/sedir/manifest.webmanifest"') && !/href="\/manifest/.test(html));

  const man = await iste(P1, '/sedir/manifest.webmanifest', { cerez });
  const mj = await man.json();
  kapi('T12 PWA kimliği KUTU BAŞINA üretilir (kapsam tabanda, ad kutudan)',
    mj.scope === '/sedir/' && mj.start_url === '/sedir/' && /sinavkutu/i.test(mj.name), `→ ${JSON.stringify(mj).slice(0, 90)}`);
  kapi('T13 PWA ikon yolları da tabanlı', String(mj.icons?.[0]?.src || '').startsWith('/sedir/'), `→ ${mj.icons?.[0]?.src}`);

  const tt = await iste(P1, '/sedir/tty/', { cerez });
  const tj = await tt.json();
  kapi('T14 ttyd vekili tabanlı yolu OLDUĞU GİBİ iletir (ttyd -b ile eşleşsin)',
    tj.ttyd === true && tj.yol === '/sedir/tty/', `→ ${JSON.stringify(tj)}`);
}

console.log('\n── K · KÖK DAVRANIŞI (taban boş — geriye dönük) ──');
{
  const g = await iste(P2, '/giris');
  kapi('K1 taban boşken giriş kök yolda açılır', g.status === 200, `→ ${g.status}`);
  const a = await iste(P2, '/');
  kapi('K2 girişsiz kök → /giris (eski davranış BAYT BAYT aynı)',
    a.status === 302 && a.headers.get('location') === '/giris', `→ ${a.headers.get('location')}`);
  const ok = await iste(P2, '/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const sc = ok.headers.get('set-cookie') || '';
  kapi('K3 taban boşken çerez Path=/ kalır', /Path=\/(;|$)/.test(sc), `→ ${sc.slice(0, 60)}`);
  const cerez = 'kapi=' + (sc.match(/kapi=([^;]+)/) || [])[1];
  const h = await (await iste(P2, '/', { cerez })).text();
  kapi('K4 taban boşken sayfa yolları DEĞİŞTİRİLMEZ', h.includes('href="/manifest.webmanifest"'));
  const tt = await (await iste(P2, '/tty/', { cerez })).json();
  kapi('K5 taban boşken ttyd yolu kök kalır', tt.yol === '/tty/', `→ ${tt.yol}`);
}

console.log('\n── M · MAHREMİYET (iki kutu aynı kaynağı paylaşıyor) ──');
{
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const baska = await iste(P1, '/akar/api/durum', { cerez });
  kapi('M1 geçerli oturumla BAŞKA kutunun yoluna gidilemez (404)', baska.status === 404, `→ ${baska.status}`);
  const kendi = await iste(P1, '/sedir/api/durum', { cerez });
  kapi('M2 ... kendi yolu çalışıyor (M1 "her şey 404" değil)', kendi.status === 200, `→ ${kendi.status}`);
}

console.log('\n── W · WEBSOCKET (tam terminal bağlantısı) ──');
{
  // 🔴 BU BÖLÜM BİR MUTASYON TURUNDA DOĞDU: upgrade kapısındaki taban denetimini
  //    öldürdüğümde sınav YEŞİL kaldı — yani WS yolu hiç ölçülmüyordu. Tam terminal
  //    bağlantısı tarayıcıda normal isteklerden AYRI bir yoldan geçer; ölçülmeyen o
  //    yol, kapının en geniş yetkili ucudur (doğrudan kabuğa açılır).
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const yukselt = (yol, kurabiye) => new Promise((coz) => {
    const c = net.connect(P1, '127.0.0.1', () => {
      c.write(`GET ${yol} HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n`
        + `Sec-WebSocket-Key: ${Buffer.from('0123456789abcdef').toString('base64')}\r\nSec-WebSocket-Version: 13\r\n`
        + (kurabiye ? `Cookie: ${kurabiye}\r\n` : '') + '\r\n');
    });
    let b = ''; const bit = () => { c.destroy(); coz(b); };
    c.on('data', (d) => { b += d; if (b.includes('\r\n\r\n')) bit(); });
    c.on('error', bit); setTimeout(bit, 3000);
  });
  const w1 = await yukselt('/sedir/tty/ws', cerez);
  kapi('W1 tabanlı WS yolu ttyd\'ye ULAŞIR', /ttyd/.test(w1) || /200 OK/.test(w1), `→ ${w1.slice(0, 40)}`);
  const w2 = await yukselt('/tty/ws', cerez);
  kapi('W2 taban DIŞI WS yolu REDDEDİLİR (401) — geçerli oturumla bile', /401/.test(w2), `→ ${w2.slice(0, 40)}`);
  const w3 = await yukselt('/sedir/tty/ws', '');
  kapi('W3 çerezsiz WS REDDEDİLİR (401)', /401/.test(w3), `→ ${w3.slice(0, 40)}`);
  const w4 = await yukselt('/sedir/api/ekran', cerez);
  kapi('W4 tty dışı yola upgrade REDDEDİLİR', /401/.test(w4), `→ ${w4.slice(0, 40)}`);
}

// ── B · TARAYICI AKIŞI (bağımsız göz, CİDDİ) ──────────────────────────────────
// 🔴 NİÇİN: sunucu /sedir/giris'e 200 döndürüyordu ve sınav yeşildi — ama sayfanın
//    KENDİSİ tabanı bilmiyordu: parola köke gidiyor, varlıklar kökten isteniyor,
//    başarılı girişten sonra kullanıcı kökün / adresine atılıyordu. Yani ölçülen
//    şey "sunucu cevap verdi mi" idi; kırılan şey KULLANICININ YOLUYDU.
{
  const g = await iste(P1, '/sedir/giris');
  const h = await g.text();
  kapi('B1 giriş sayfası tabanı TAŞIR (window.__TABAN gömülü)',
       /window\.__TABAN\s*=\s*"\/sedir"/.test(h), `→ ${/__TABAN/.test(h) ? 'var ama değer yanlış' : 'HİÇ YOK'}`);
  const kokMutlak = (h.match(/(?:href|src)="\/(?!\/)[^"]*/g) || []).filter((x) => !x.includes('/sedir/'));
  kapi('B2 giriş sayfasında KÖK-mutlak varlık yolu kalmadı',
       kokMutlak.length === 0, `→ ${kokMutlak.slice(0, 2).join(' ')}`);
  kapi('B3 başarılı girişten sonra taban altına dönülür (köke DEĞİL)',
       /location\.replace\(\(window\.__TABAN\|\|''\)\s*\+\s*'\/'\)/.test(h),
       `→ ${/location\.replace\('\/'\)/.test(h) ? "hâlâ köke atıyor" : 'desen bulunamadı'}`);
  const gk = await iste(P2, '/giris'); const hk = await gk.text();
  kapi('B4 tabansız kutuda sayfa yine çalışır (B1 tautoloji değil)',
       gk.status === 200 && /window\.__TABAN\s*=\s*""/.test(hk), `→ ${gk.status}`);
}

// ── P · PAROLA VEKİLLİĞİ (bağımsız göz tur 2, CİDDİ) ─────────────────────────
// 🔴 NİÇİN: kutunun kendi anahtarı yoksa kod SEDİR'inkine düşüyordu. AKAR kutusunda
//    AKAR__… yokken SEDİR__… ortamda duruyorsa kapı DURMAK yerine YANLIŞ SIRLA
//    açılırdı. Fail-closed sözü tam burada bozuluyordu.
{
  const cik = (ortam) => new Promise((coz) => {
    const c = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
      env: { ...process.env, KAPI_TABAN: '/akar', TO_KUTU: 'akar', KAPI_PORT: '18779',
             KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), AKAR__TERMINAL_SIFRE: '', ...ortam },
      stdio: ['ignore', 'ignore', 'pipe'] });
    let e = ''; c.stderr.on('data', (d) => { e += d; });
    c.on('exit', (k) => coz({ kod: k, hata: e })); setTimeout(() => { c.kill(); coz({ kod: null, hata: e }); }, 4000);
  });
  const baskasi = await cik({ SEDIR__TERMINAL_SIFRE: 'baskasinin-parolasi-9999' });
  kapi('P1 kutunun kendi parolası yokken BAŞKASININKİYLE açılmaz (fail-closed)',
       baskasi.kod === 2 && /parola ortamda yok/.test(baskasi.hata), `→ çıkış ${baskasi.kod}`);
  const kendi = await cik({ AKAR__TERMINAL_SIFRE: 'akarin-kendi-parolasi-1234' });
  kapi('P2 kendi parolası varken AÇILIR (P1 tautoloji değil)',
       kendi.kod === null, `→ çıkış ${kendi.kod}`);
}

// ── F · YAZI TİPİ YOLU ────────────────────────────────────────────────────────
// Biçem dosyası taban enjeksiyonundan GEÇMEZ (yalnız html yazılır); kök-mutlak
// yazı tipi adresi /sedir/ altında merkez köküne kaçardı.
{
  const c = await iste(P1, '/sedir/zanaat.css'); const g = await c.text();
  kapi('F1 biçem dosyasında kök-mutlak yazı tipi adresi yok',
       !/url\(\s*\//.test(g), `→ ${(g.match(/url\([^)]*\)/g) || []).slice(0, 2).join(' ')}`);
  const f = await iste(P1, '/sedir/archivo-400.ttf');
  kapi('F2 yazı tipi taban altından İNİYOR (F1 tautoloji değil)', f.status === 200, `→ ${f.status}`);
}

// ── C · ÖNBELLEK SINIRI (bağımsız göz tur 3) ─────────────────────────────────
// 🔴 NİÇİN: eski temizlik süzgeci 'kabuk'+taban ile ÖNEK eşliyordu. Kısa adlı bir
//    kutu (/sed) uzun adlının kabını (kabuk/sedir-v3) silebilirdi — başka kutunun
//    çevrimdışı kabuğunu sessizce bozmak. Sınav GERÇEK sw.js'i sahte bir ortamda koşar.
{
  const kaynak = await (await iste(P1, '/sedir/sw.js')).text();
  const calistir = async (yol, kaplar) => {
    const silinen = [];
    const dinleyici = {};
    const sahte = {
      location: { pathname: yol + '/sw.js', origin: 'http://x' },
      addEventListener: (ad, f) => { dinleyici[ad] = f; },
      skipWaiting() {}, clients: { claim() {} },
    };
    const caches = {
      open: async () => ({ addAll: async () => {}, put: async () => {} }),
      keys: async () => kaplar,
      delete: async (x) => { silinen.push(x); return true; },
      match: async () => undefined,
    };
    const fn = new Function('self', 'caches', 'location', 'fetch', 'Response', kaynak);
    fn(sahte, caches, sahte.location, async () => ({ ok: false }), function () {});
    await new Promise((c) => dinleyici.activate({ waitUntil: (p) => p.then(c).catch(c) }));
    return silinen;
  };
  const kaplar = ['kabuk/sedir-v3', 'kabuk/sedir-v2', 'kabuk/sed-v1', 'kabuk-kok-v3'];
  const kisa = await calistir('/sed', kaplar);
  kapi('C1 kısa adlı kutu UZUN adlının önbelleğini silmez',
       !kisa.some((x) => x.startsWith('kabuk/sedir')), `→ sildi: ${kisa.join(' ')}`);
  kapi('C2 ... ama kendi eski kabını siler (C1 tautoloji değil)',
       kisa.includes('kabuk/sed-v1'), `→ sildi: ${kisa.join(' ')}`);
  const uzun = await calistir('/sedir', kaplar);
  kapi('C3 kutu kendi eski sürümünü temizler, komşununkine dokunmaz',
       uzun.includes('kabuk/sedir-v2') && !uzun.includes('kabuk/sed-v1') && !uzun.includes('kabuk-kok-v3'),
       `→ sildi: ${uzun.join(' ')}`);
}

kapiTaban.kill(); kapiKok.kill(); ttyd.close();
console.log(`\n${'─'.repeat(56)}`);
console.log(`GECEN: ${gecen}  ·  KALAN: ${kalan}`);
if (kalan) { console.log('BASARISIZ:'); basarisiz.forEach((a) => console.log('  · ' + a)); }
process.exit(kalan ? 1 : 0);
