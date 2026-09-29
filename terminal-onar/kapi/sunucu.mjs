// kapi/sunucu.mjs — sedir-terminal.mmepanel.com'un kapısı (telefon uygulaması + canlı terminal).
//
//   tünel → :7681 (bu sunucu) ─┬─ /            telefon ekranı (PWA)
//                              ├─ /tty/*       ttyd (UNIX soketi, TCP portu YOK) — canlı tmux sedir-ana
//                              └─ /api/*       gönder · tuş · resim · durum · onar · günlük
//
// Kilitler: 1) Cloudflare Access (tünelin önünde)  2) bu kapının parolası (imzalı çerez, 30 gün).
// Parola kasadan gelir (SEDIR__TERMINAL_SIFRE, başlatıcı env'e yükler); hiçbir yere yazılmaz.
// Bağımlılık yok: yalnız Node çekirdeği.
import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFile, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(fileURLToPath(import.meta.url));
const GENEL = path.join(KOK, 'genel');
const BETIK = path.resolve(KOK, '../scripts');
const PORT = +(process.env.KAPI_PORT || 7681);
const TTYD_SOKET = process.env.KAPI_TTYD_SOKET || path.join(process.env.TO_DURUM_DIZ || '/config/.terminal-onar', 'ttyd.sock');
const ANA_TMUX = process.env.TO_ANA_TMUX || 'sedir-ana';
// ── TABAN YOLU ───────────────────────────────────────────────────────────────
// 🔴 NİÇİN: merkez sayfa (terminal.mmepanel.com) kutuları YOL ile ayırır — /sedir/ ·
//    /akar/ … Kapı tabanı bilmezse döndürdüğü her mutlak yol (302 → /giris, çerez
//    Path=/, sayfadaki /api çağrıları) MERKEZE gider, kutuya hiç ulaşmaz. Tabanı
//    merkezin sıyırması da yetmez: sıyrılan yol istekte düzelir ama YANITTAKİ yollar
//    yine kök olur. O yüzden taban kapının kendisinde yaşar.
// Boş bırakılırsa bugünkü kök-yol davranışı BAYT BAYT aynı kalır (geriye dönük).
const TABAN = (process.env.KAPI_TABAN || '').replace(/\/+$/, '');
const T = (y) => TABAN + y;   // dışarıya verilen mutlak yol
// Kutu adı: PWA kimliğinde ve sayfa başlığında görünür. Taban "/sedir" ise "sedir".
const KUTU = process.env.TO_KUTU || (TABAN ? TABAN.slice(1) : '') || 'kutu';
const KUTU_BAS = KUTU.charAt(0).toLocaleUpperCase('tr') + KUTU.slice(1);
const DURUM_DIZ = process.env.TO_DURUM_DIZ || '/config/.terminal-onar';
const RESIM_URL = process.env.KAPI_RESIM_URL || 'http://127.0.0.1:8391/upload';
// 🔴 Parola değişkeninin ADI kutudan türer (SEDIR__… · AKAR__…). Sert yazılsaydı
//    beceri ikinci kutuda parolayı bulamaz, fail-closed açılmaz ve sebebi "parola yok"
//    gibi görünürdü — oysa parola vardı, aranan ad yanlıştı. Ad da veri gibi taşınır.
const SIFRE_ANAHTAR = process.env.KAPI_SIFRE_ANAHTAR
  || ((process.env.TO_KUTU || (TABAN ? TABAN.slice(1) : '')).replace(/-/g, '_').toUpperCase() + '__TERMINAL_SIFRE');
// 🔴 GERI DUSUS YOK (bagimsiz goz tur 2, CIDDI). Onceki hal kutunun kendi
//    anahtari bulunamazsa SEDIR'inkine dusuyordu: AKAR kutusunda AKAR__... yokken
//    SEDIR__... ortamda duruyorsa kapi DURMAK yerine YANLIS SIRLA acilirdi — hem
//    kart 'kasada yoksa kurulum durur' derken, hem de bir kutunun parolasi otekini
//    acardi. Anahtar kutudan turer; baskasinin anahtari asla vekil olamaz.
const SIFRE = process.env[SIFRE_ANAHTAR] || '';
const GUN = 24 * 3600;
if (SIFRE.length < 4) { console.error(`KAPI: parola ortamda yok (${SIFRE_ANAHTAR}) — fail-closed, açılmıyorum`); process.exit(2); }

// ---- oturum çerezi: exp.imza (anahtar = parola → parola değişince bütün oturumlar düşer)
const imzala = (exp) => crypto.createHmac('sha256', SIFRE).update('kapi|' + exp).digest('base64url');
function cerezYap() { const exp = Math.floor(Date.now() / 1000) + 30 * GUN; return `${exp}.${imzala(exp)}`; }
function girisli(req) {
  const m = /(?:^|;\s*)kapi=([^;]+)/.exec(req.headers.cookie || '');
  if (!m) return false;
  const [exp, imza] = m[1].split('.');
  if (!exp || !imza || +exp < Date.now() / 1000) return false;
  const a = Buffer.from(imza), b = Buffer.from(imzala(exp));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
function parolaDogru(p) {
  const a = crypto.createHash('sha256').update(String(p)).digest();
  const b = crypto.createHash('sha256').update(SIFRE).digest();
  return crypto.timingSafeEqual(a, b);
}
// kaba kuvvet freni: dakikada 6 deneme
const denemeler = [];
const cokDeneme = () => { const t = Date.now(); while (denemeler.length && t - denemeler[0] > 60000) denemeler.shift(); return denemeler.length >= 6; };

// ---- yardımcılar
const TIPLER = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.webmanifest': 'application/manifest+json', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf' };
function json(res, kod, veri) { res.writeHead(kod, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }); res.end(JSON.stringify(veri)); }
function dosya(res, ad, ek = {}) {
  const yol = path.join(GENEL, ad);
  if (!yol.startsWith(GENEL) || !fs.existsSync(yol)) { res.writeHead(404); return res.end('yok'); }
  res.writeHead(200, { 'content-type': TIPLER[path.extname(yol)] || 'application/octet-stream', 'cache-control': 'no-cache', ...ek });
  fs.createReadStream(yol).pipe(res);
}
// index.html'i tabanı enjekte ederek sunar. Enjekte edilen değer JSON ile kaçışlanır
// (taban ortam değişkeninden gelir; tırnak içeren bir değer sayfayı bozardı).
function dosyaTabanli(res, ad) {
  const yol = path.join(GENEL, ad);
  if (!yol.startsWith(GENEL) || !fs.existsSync(yol)) { res.writeHead(404); return res.end('yok'); }
  let h = fs.readFileSync(yol, 'utf8');
  // Sayfadaki mutlak varlık yolları da tabana taşınır (manifest · ikon · css · js).
  // Yalnız kök-mutlak olanlar; "//" ile başlayan dış kaynaklara dokunulmaz.
  if (TABAN) h = h.replace(/(href|src)="\/(?!\/)/g, `$1="${TABAN}/`);
  // 🔴 KULLANICIYA GORUNEN AD DA KUTUDAN TURER (bagimsiz goz tur 4).
  //    Sayfalarda 'Sedir' sabit yaziliydi: AKAR kutusunu acan kisi tepede
  //    'Sedir' gorurdu — 'hicbir kutu adi gomulu degil' sozu arayuzde bozuluyordu.
  h = h.split('{{KUTU}}').join(KUTU_BAS);
  h = h.replace('<head>', `<head><script>window.__TABAN=${JSON.stringify(TABAN)};window.__KUTU=${JSON.stringify(KUTU)};</script>`);
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-cache' });
  res.end(h);
}

function govde(req, sinir = 64 * 1024) {
  return new Promise((ok, red) => {
    const parca = []; let n = 0;
    req.on('data', (c) => { n += c.length; if (n > sinir) { red(Object.assign(new Error('çok büyük'), { kod: 413 })); req.destroy(); } else parca.push(c); });
    req.on('end', () => ok(Buffer.concat(parca))); req.on('error', red);
  });
}
function calistir(komut, arg, girdi) {
  return new Promise((ok) => {
    const c = execFile(komut, arg, { timeout: 20000, maxBuffer: 1 << 20 }, (h, out, err) => ok({ kod: h ? (h.code ?? 1) : 0, out: String(out), err: String(err) }));
    if (girdi != null) { c.stdin.end(girdi); }
  });
}

// ---- tmux'a yazma: çok satırlı metin "yapıştır" olarak gider (satır sonları erken göndermesin), sonra Enter
async function tmuxGonder(metin) {
  const b = 'kapi-' + crypto.randomBytes(3).toString('hex');
  let r = await calistir('tmux', ['load-buffer', '-b', b, '-'], metin);
  if (r.kod) return r;
  r = await calistir('tmux', ['paste-buffer', '-p', '-d', '-b', b, '-t', ANA_TMUX]);
  if (r.kod) return r;
  await new Promise((s) => setTimeout(s, 150));
  return calistir('tmux', ['send-keys', '-t', ANA_TMUX, 'Enter']);
}
const TUSLAR = new Set(['Escape', 'Up', 'Down', 'Left', 'Right', 'Enter', 'Tab', 'BTab', 'C-c', 'BSpace',
  '1', '2', '3', '4', '5', 'y', 'n']);

// ---- ttyd'ye vekâlet (HTTP)
function ttydVekil(req, res) {
  const v = http.request({ socketPath: TTYD_SOKET, path: req.url, method: req.method, headers: { ...req.headers, host: 'localhost' } }, (yan) => {
    res.writeHead(yan.statusCode, yan.headers); yan.pipe(res);
  });
  v.on('error', () => { if (!res.headersSent) { res.writeHead(502, { 'content-type': 'text/html; charset=utf-8' }); }
    res.end('<body style="background:#16130f;color:#e9e2d6;font:16px system-ui;padding:24px">Terminal şu an ulaşılamıyor — yukarıdaki <b>Onar</b> düğmesine bas.</body>'); });
  req.pipe(v);
}

// ---- konuşma geçmişi: Claude tam-ekran kipte çalışır → tmux'ta geçmiş satırı YOK, okuma görünümü yalnız
//      son ekranı görür. Önceki mesajlar Claude'un kendi konuşma kaydından (jsonl) SALT-OKUR çekilir:
//      yalnız dosyanın sonu okunur (kayıt GB'larca olabilir), yalnız düz metin mesajlar döner.
const CLAUDE_DIZ = path.join(process.env.HOME || '/config', '.claude');
function anaOturumId() {
  try {
    for (const f of fs.readdirSync(path.join(CLAUDE_DIZ, 'sessions'))) {
      if (!f.endsWith('.json')) continue;
      try {
        const j = JSON.parse(fs.readFileSync(path.join(CLAUDE_DIZ, 'sessions', f), 'utf8'));
        if (!String(j.tmux || '').startsWith(ANA_TMUX + ':')) continue;
        process.kill(j.pid, 0); return j.sessionId;
      } catch {}
    }
  } catch {}
  try { return fs.readFileSync(path.join(DURUM_DIZ, 'ana-oturum'), 'utf8').trim(); } catch { return ''; }
}
function kayitYolu(id) {
  if (!/^[0-9a-f-]{36}$/.test(id)) return '';
  try {
    for (const d of fs.readdirSync(path.join(CLAUDE_DIZ, 'projects'))) {
      const y = path.join(CLAUDE_DIZ, 'projects', d, id + '.jsonl');
      if (fs.existsSync(y)) return y;
    }
  } catch {}
  return '';
}
const SISTEM_ISI = /^\s*<(command-|local-command|system-reminder|task-notification|bash-|user-memory|pasted_content)/;
function gecmisOku(adet) {
  const y = kayitYolu(anaOturumId());
  if (!y) return null;
  const boy = fs.statSync(y).size, oku = Math.min(boy, 6 * 1024 * 1024);
  const fd = fs.openSync(y, 'r'); const b = Buffer.alloc(oku);
  try { fs.readSync(fd, b, 0, oku, boy - oku); } finally { fs.closeSync(fd); }
  const satirlar = b.toString('utf8').split('\n'); if (oku < boy) satirlar.shift();  // ilk satır yarım
  const mesajlar = [];
  for (const s of satirlar) {
    if (!s.includes('"text"') && !s.includes('"type":"user"')) continue;
    let j; try { j = JSON.parse(s); } catch { continue; }
    if ((j.type !== 'user' && j.type !== 'assistant') || j.isMeta || j.isSidechain) continue;
    const c = j.message?.content;
    const metin = (typeof c === 'string' ? c : Array.isArray(c) ? c.filter((p) => p.type === 'text').map((p) => p.text).join('\n\n') : '').trim();
    if (!metin || SISTEM_ISI.test(metin)) continue;
    mesajlar.push({ kim: j.type === 'user' ? 'sen' : 'sedir', metin: metin.slice(0, 20000), zaman: j.timestamp || '' });
  }
  return mesajlar.slice(-adet);
}

const sunucu = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  // Taban SIYRILIR: aşağıdaki bütün yollar taban-bağımsız kalsın (tek yerde çevrilir;
  // her uçta ayrı ayrı ele alınsaydı biri unutulur ve o uç sessizce 404 olurdu).
  let y = url.pathname;
  if (TABAN) {
    if (y === TABAN) { res.writeHead(302, { location: TABAN + '/' }); return res.end(); }
    if (y.startsWith(TABAN + '/')) y = y.slice(TABAN.length);
    else { res.writeHead(404); return res.end('yok'); }   // taban dışı istek bu kapıya ait değil
  }
  res.setHeader('x-content-type-options', 'nosniff');
  res.setHeader('referrer-policy', 'no-referrer');

  // girişsiz açık olanlar: giriş sayfası + PWA kimlik dosyaları
  // 🔴 GİRİŞ SAYFASI DA TABANI BİLMELİ (bağımsız göz, CİDDİ). Düz `dosya()` ile
  //    sunulunca sayfada `window.__TABAN` tanımsız kalıyor, parola KÖKTEKİ /giris'e
  //    gidiyor ve varlıklar kökten isteniyordu. Sunucu 200 döndürdüğü için sınav
  //    yeşildi; kırılan şey sunucu değil TARAYICI AKIŞIYDI.
  if (y === '/giris' && req.method === 'GET') return dosyaTabanli(res, 'giris.html');
  if (y === '/giris' && req.method === 'POST') {
    if (cokDeneme()) return json(res, 429, { hata: 'Çok fazla deneme. Bir dakika bekle.' });
    denemeler.push(Date.now());
    let p = '';
    try { p = JSON.parse(await govde(req, 4096)).parola || ''; } catch { return json(res, 400, { hata: 'Geçersiz istek.' }); }
    if (!parolaDogru(p)) return json(res, 401, { hata: 'Parola yanlış.' });
    // Çerez YALNIZ kendi tabanında geçerli: bir kutunun oturumu ötekine taşınmasın.
    res.setHeader('set-cookie', `kapi=${cerezYap()}; Path=${TABAN || '/'}; Max-Age=${30 * GUN}; HttpOnly; Secure; SameSite=Strict`);
    return json(res, 200, { tamam: true });
  }
  // 🔴 PWA KİMLİĞİ KUTU BAŞINA ÜRETİLİR — dosyadan sunulmaz.
  //    Merkez altında bütün kutular aynı kaynağı paylaşıyor; `scope:"/"` ve sabit
  //    ad ile her kutu telefonun ana ekranına AYNI uygulama olarak kurulurdu:
  //    ikincisi birincinin üstüne yazardı ve hangi kutuya baktığın belirsizleşirdi.
  if (y === '/manifest.webmanifest') {
    const m = {
      name: KUTU_BAS, short_name: KUTU_BAS, description: `${KUTU_BAS} ile canlı konuşma`, lang: 'tr',
      start_url: TABAN + '/', scope: TABAN + '/', display: 'standalone',
      background_color: '#15120e', theme_color: '#15120e',
      icons: [
        { src: T('/ikon-192.png'), sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
        { src: T('/ikon-512.png'), sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
      ],
    };
    res.writeHead(200, { 'content-type': 'application/manifest+json; charset=utf-8', 'cache-control': 'no-cache' });
    return res.end(JSON.stringify(m, null, 2));
  }
  if (['/ikon-192.png', '/ikon-512.png', '/ikon-180.png', '/ikon.svg', '/sw.js', '/zanaat.css', '/archivo-400.ttf', '/archivo-600.ttf'].includes(y))
    return dosya(res, y.slice(1), y === '/sw.js' ? { 'service-worker-allowed': TABAN + '/' } : {});

  if (!girisli(req)) {
    if (y.startsWith('/api/') || y.startsWith('/tty')) return json(res, 401, { hata: 'Oturum yok.' });
    res.writeHead(302, { location: T('/giris') }); return res.end();
  }

  // 🔴 Sayfa kendi tabanını SUNUCUDAN öğrenir. Alternatif `<base href>` idi ve
  //    reddedildi: base, sayfadaki her bağı ve formu birden değiştirir — sürprizi
  //    ölçmesi zor. Tek bir değişken enjekte etmek denetlenebilir.
  if (y === '/' || y === '/index.html') return dosyaTabanli(res, 'index.html');
  if (y === '/uygulama.js') return dosya(res, 'uygulama.js');
  if (y.startsWith('/tty')) return ttydVekil(req, res);

  if (y.startsWith('/api/')) {
    if (req.method === 'POST' && req.headers['x-kapi'] !== '1') return json(res, 403, { hata: 'Başlık eksik.' });
    try {
      if (y === '/api/gonder' && req.method === 'POST') {
        const { metin } = JSON.parse(await govde(req));
        if (!metin || !String(metin).trim()) return json(res, 400, { hata: 'Boş mesaj.' });
        const r = await tmuxGonder(String(metin));
        return r.kod ? json(res, 502, { hata: 'Konuşma odasına ulaşılamadı. Onar düğmesini dene.' }) : json(res, 200, { tamam: true });
      }
      if (y === '/api/tus' && req.method === 'POST') {
        const { tus } = JSON.parse(await govde(req));
        if (!TUSLAR.has(tus)) return json(res, 400, { hata: 'Bilinmeyen tuş.' });
        const r = await calistir('tmux', ['send-keys', '-t', ANA_TMUX, tus]);
        return r.kod ? json(res, 502, { hata: 'Konuşma odasına ulaşılamadı.' }) : json(res, 200, { tamam: true });
      }
      if (y === '/api/resim' && req.method === 'POST') {
        const veri = await govde(req, 25 * 1024 * 1024);
        const r = await fetch(RESIM_URL, { method: 'POST', headers: { 'x-requested-with': 'dashboard', 'content-type': req.headers['content-type'] || 'application/octet-stream' }, body: veri });
        const j = await r.json().catch(() => ({}));
        return r.ok && j.path ? json(res, 200, { yol: j.path }) : json(res, 502, { hata: j.error || 'Fotoğraf kaydedilemedi.' });
      }
      // okuma görünümü: telefona tmux'un içeriği METİN olarak gider (tmux'a istemci bağlanmaz →
      // masaüstünün boyutu hiç bozulmaz; telefon kendi genişliğinde satırı kırar, doğal kaydırır)
      if (y === '/api/ekran') {
        const n = Math.min(Math.max(+(url.searchParams.get('satir') || 600), 50), 3000);
        const r = await calistir('tmux', ['capture-pane', '-p', '-e', '-J', '-S', `-${n}`, '-t', ANA_TMUX]);
        if (r.kod) return json(res, 502, { hata: 'Konuşma odasına ulaşılamadı.' });
        // satır sonundaki boşluk dolgusunu at (telefonda boş satır üretir), renk kodlarını koru
        const metin = r.out.split('\n').map((l) => l.replace(/(?:[ \t]|\x1b\[[0-9;:]*m)+$/, (k) => k.replace(/[ \t]+/g, ''))).join('\n').replace(/\s+$/, '');
        const h = crypto.createHash('sha1').update(metin).digest('hex').slice(0, 16);
        if (url.searchParams.get('h') === h) return json(res, 200, { h, ayni: true });
        return json(res, 200, { h, metin });
      }
      if (y === '/api/gecmis') {
        const adet = Math.min(Math.max(+(url.searchParams.get('adet') || 30), 1), 200);
        const m = gecmisOku(adet);
        return m ? json(res, 200, { mesajlar: m }) : json(res, 404, { hata: 'Konuşma kaydı bulunamadı.' });
      }
      if (y === '/api/surum') {
        // telefon eski sayfada kalmasın: dosyalar değişince sürüm değişir, sayfa kendini yeniler
        const m = fs.readdirSync(GENEL).map((f) => fs.statSync(path.join(GENEL, f)).mtimeMs);
        return json(res, 200, { surum: String(Math.max(...m)) });
      }
      if (y === '/api/durum') {
        const r = await calistir('bash', [path.join(BETIK, 'durum.sh'), '--json']);
        try { return json(res, 200, JSON.parse(r.out)); } catch { return json(res, 500, { hata: 'Durum ölçülemedi.' }); }
      }
      if (y === '/api/onar' && req.method === 'POST') {
        spawn('bash', [path.join(BETIK, 'kademe.sh'), '--kaynak', 'dugme', '--arka'], { detached: true, stdio: 'ignore' }).unref();
        return json(res, 202, { tamam: true });
      }
      if (y === '/api/gunluk') {
        const oku = (f) => { try { return fs.readFileSync(f, 'utf8'); } catch { return ''; } };
        const satir = oku(path.join(DURUM_DIZ, 'gunluk.log')).trim().split('\n').slice(-12);
        return json(res, 200, { merdiven: oku(path.join(DURUM_DIZ, 'kademe.durum')).trim(), satir });
      }
    } catch (e) { return json(res, e.kod || 400, { hata: e.kod === 413 ? 'Dosya çok büyük.' : 'Geçersiz istek.' }); }
    return json(res, 404, { hata: 'Yok.' });
  }
  res.writeHead(404); res.end('yok');
});

// ---- WebSocket (ttyd) — yalnız girişli ve /tty altında
sunucu.on('upgrade', (req, soket, bas) => {
  console.log(new Date().toISOString(), 'tam-terminal bağlantısı', (req.headers['user-agent'] || '').slice(0, 80));
  // 🔴 ÖNEK DEĞİL SINIR: `startsWith('/sedir/tty')` `/sedir/ttyXYZ` yolunu da kabul
  //    ederdi. Yol ya tam eşleşir ya da eğik çizgiyle devam eder.
  const _tty = T('/tty');
  const _yol = (req.url || '').split('?')[0];
  if (!girisli(req) || !(_yol === _tty || _yol.startsWith(_tty + '/'))) { soket.end('HTTP/1.1 401 Unauthorized\r\n\r\n'); return; }
  const hedef = net.connect(TTYD_SOKET, () => {
    const b = [`${req.method} ${req.url} HTTP/1.1`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      const ad = req.rawHeaders[i];
      b.push(`${ad}: ${ad.toLowerCase() === 'host' ? 'localhost' : req.rawHeaders[i + 1]}`);
    }
    hedef.write(b.join('\r\n') + '\r\n\r\n'); if (bas?.length) hedef.write(bas);
    hedef.pipe(soket); soket.pipe(hedef);
  });
  const kapat = () => { hedef.destroy(); soket.destroy(); };
  hedef.on('error', kapat); soket.on('error', kapat);
});

sunucu.listen(PORT, '0.0.0.0', () => console.log(new Date().toISOString(), `kapı :${PORT}${TABAN || ' (kök)'} → ttyd ${TTYD_SOKET}`));
