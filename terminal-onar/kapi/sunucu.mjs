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
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
// Koltuk adı kuralı — kabuktaki TEK kopyası scripts/koltuk-adi.sh; iki dilin eşdeğerliği scripts/koltuk-adi.test.sh'de ölçülür.
// '.' · ':' · kontrol karakteri yok; boşluk arada serbest, başta/sonda yok; ilk karakter '$' '@' '%' '=' olamaz (tmux kimlik önekleri).
import { KOLTUK_AD_DESEN, koltukSatirlari } from './koltuklar.mjs';
import { odaBul, odaUyarisi, odaSec, kayitOdaHaritasi, kayitOdaBul } from './oda.mjs';
import { kayitOku, kadroBirlestir, altyapiNeden, davaOzet, yerAcAday, DAVA_ROL } from './kadro.mjs';
import { tarifOku, uzmanlikOku } from './tarif.mjs';
import { bugunOku } from './bugun.mjs';
import { kadroYazKilitAltinda, KadroHata, davaEkle, kisiyeBagla, baglaGeriAl, DOSYA_NO, kisaAdGecerli } from './kadro-yaz.mjs';
import { etiketOku, etiketYaz, EtiketHata } from './kadro-etiket.mjs';
import { dosyaKilit } from './kilit.mjs';
import { onbellekKur, koltukDegistirir } from './koltuk-onbellek.mjs';   // /api/koltuklar kısa süreli önbellek (ölçüm notu dosyada)
import { koltukKimlik } from './koltuk-kimlik.mjs';   // ad dışı kimlik (2.24.0 · P4GT2W): adres adı değil kimliği taşır
import { oturumKimlikleri, oturumDizinleri } from './kimlik.mjs';   // kişi↔oturum eşleşmesinin kimlik ayağı (salt-okur)
import { davaDondur, davaEk, davaGeriEk } from './dava.mjs';   // Dava Rafı: dondurmanın tek yolu (kapı Aç'ı + günlük bekçi turu)
// Sınav dikişi: süreç kökü ve pid alanı ortamdan verilebilir (gerçekte /proc ve kendi alanı)
const kimlikler = () => oturumKimlikleri({ dizinler: oturumDizinleri(), procKok: process.env.KAPI_PROC_KOK || '/proc',
  ...(process.env.KAPI_PID_ALANI ? { pidAlani: process.env.KAPI_PID_ALANI } : {}) });
// KADRO E2 eylemleri SIRAYLA yürür (bağımsız göz tur 2): bir eylem "kayda yaz → oturumu kapat (await) → gerekirse geri al" zinciridir;
// araya giren ikinci eylem (ör. aynı kişiye 'geri aç') birincinin geri almasını bozar. Kapı tek süreç → süreç içi kuyruk yeter.
let kadroSon = Promise.resolve();
function kadroKilit() { let birak; const p = new Promise((r) => { birak = r; }); const once = kadroSon; kadroSon = once.then(() => p); return once.then(() => birak); }   // E2: kayda durum yazan TEK yer (emekli et · dondur · geri aç)   // 2.8.0 Kadro: kayıt ⟂ koltuk birleşimi (dosya okur, yazmaz)   // ad kuralı + liste çözümü TEK yerde (fark ölçeri de aynısını çağırır)

const KOK = path.dirname(fileURLToPath(import.meta.url));
const GENEL = path.join(KOK, 'genel');
const BETIK = path.resolve(KOK, '../scripts');
const PORT = +(process.env.KAPI_PORT || 7681);
const TTYD_SOKET = process.env.KAPI_TTYD_SOKET || path.join(process.env.TO_DURUM_DIZ || '/config/.terminal-onar', 'ttyd.sock');
// ── KİŞİ TERMİNALİ (2.27.0 · A5-3 · görev …A5Y3P · HEZARFEN köprü sözleşmesi): /tty-k/* → ttyd-kisi (ayrı kullanıcı, komutu kabuksuz
//    kisi-istemci.py; koltuğu istemci köprüden seçer, ?arg= taşınmaz). Kapı köprüyle KONUŞMAZ ve kişiyi tanımaz: bir kutu = bir kişi,
//    soket kurulumdan (kisi-kur.sh: /run/kisi/<kişi>-ttyd.sock; ttyd -b'siz → yol kökten: / · /token · /ws). Soket yoksa 502 —
//    abc ttyd'sine (TTYD_SOKET) hiçbir koşulda DÜŞMEZ (fail-closed: kişi isteği abc kabuğuna ulaşamaz).
const KISI_AD = String(process.env.KAPI_KISI || 'ayse').replace(/[^a-z0-9_-]/g, '') || 'ayse';
const TTYD_KISI_SOKET = process.env.KAPI_TTYD_KISI_SOKET || ('/run/kisi/' + KISI_AD + '-ttyd.sock');
const ANA_TMUX = process.env.TO_ANA_TMUX || 'sedir-ana';
// Kutunun proje dizini — ortak.sh ile AYNI kural (TO_PROJE ya da /config/projects/<kutu>); kadro kayıt dosyaları buradan okunur
const PROJE = process.env.TO_PROJE || ('/config/projects/' + (process.env.TO_KUTU || (process.env.KAPI_TABAN || '').replace(/^\/+|\/+$/g, '') || 'kutu'));
// Koltuk listesinin TEK kaynağı (ttyd de aynı betiği çalıştırır). Sınav başka bir betik verebilir.
const KOLTUK_BETIK = process.env.KAPI_KOLTUK_BETIK || path.join(BETIK, 'koltuk-bagla.sh');
const KOLTUK_AC_BETIK = process.env.KAPI_KOLTUK_AC_BETIK || path.join(BETIK, 'koltuk-ac.sh');
// ── TABAN YOLU ───────────────────────────────────────────────────────────────
// 🔴 NİÇİN: merkez sayfa (terminal.mmepanel.com) kutuları YOL ile ayırır — /sedir/ ·
//    /akar/ … Kapı tabanı bilmezse döndürdüğü her mutlak yol (302 → /giris, çerez
//    Path=/, sayfadaki /api çağrıları) MERKEZE gider, kutuya hiç ulaşmaz. Tabanı
//    merkezin sıyırması da yetmez: sıyrılan yol istekte düzelir ama YANITTAKİ yollar
//    yine kök olur. O yüzden taban kapının kendisinde yaşar.
// Boş bırakılırsa bugünkü kök-yol davranışı BAYT BAYT aynı kalır (geriye dönük).
const TABAN = (process.env.KAPI_TABAN || '').replace(/\/+$/, '');
const T = (y) => TABAN + y;   // dışarıya verilen mutlak yol
// Ekran adresi (2.24.0 · P4GT2W): ?arg= ad DIŞI kimlik taşır (koltuk-bagla.sh çözer). Tuz okunamazsa kimlik null → ekran da NULL:
// adres adla KURULMAZ (göz tur 1: hata anında sızıntıya geri dönülmesin). 'ekran' alanını kapının kendi sayfası kullanmıyor
// (telefon ekranı adresi koltuk adından kendisi kurar); merkez de kendi adresini üretir.
const ekranAdresi = (ad) => { const kimlik = koltukKimlik(ad); return { kimlik, ekran: kimlik ? T('/tty/') + '?arg=' + encodeURIComponent(kimlik) : null }; };
// Kutu adı: PWA kimliğinde ve sayfa başlığında görünür. Taban "/sedir" ise "sedir".
const KUTU = process.env.TO_KUTU || (TABAN ? TABAN.slice(1) : '') || 'kutu';
const KABUK_TMUX = process.env.TO_KABUK_TMUX || KUTU + '-kabuk';   // el kabuğu (ortak.sh KABUK_TMUX ile aynı türetim)
const KUTU_BAS = KUTU.charAt(0).toLocaleUpperCase('tr') + KUTU.slice(1);
const DURUM_DIZ = process.env.TO_DURUM_DIZ || '/config/.terminal-onar';
const KILIT_BEKLE_MS = +process.env.KADRO_KILIT_BEKLE_MS || 30000;   // kayıt kilidi bekleme (sınav kısaltır)
const RESIM_URL = process.env.KAPI_RESIM_URL || 'http://127.0.0.1:8391/upload';
// ── PANO KÖPRÜSÜ (2.3.0 · Sultan 12 Eki: "Cmd+C kopyalamıyor, resmi Cmd+V yapıştıramıyorum") ──
// ttyd'nin HTML sayfasına genel/pano.js gömülür: resim yapıştır → /api/resim → yol terminale; tmux seçimi (OSC 52)
// → tarayıcı panosu. KAPI_PANO=0 ile kapatılır (geriye dönük: o zaman vekil bayt bayt eski hâli).
const PANO_ACIK = process.env.KAPI_PANO !== '0';
// 🔴 KAPI-YENİLE (2.12.0 · SERDAR 00:5x): pano.js açılışta BELLEĞE alınıyordu; yeni pano sürümü diske inince canlı kapı eskiyi
//    sunmaya devam ediyor, tek yol kapıyı yeniden başlatmaktı — bu Sultan'ın web terminalini koparır. Artık SIGHUP pano.js'i
//    bağlantı düşürmeden yeniden okur. Kapı pid'ini ve yüklü pano sha'sını durum dizinine yazar; /giris yanıtı `x-kapi-pano`
//    başlığıyla sha'yı söyler (girişsiz uç, sır değil) — `komut.sh kapi-yenile` bununla tazelenmeyi DOĞRULAR, varsaymaz.
//    SIGHUP'ı tanımayan eski kapıda sinyal süreci ÖLDÜRÜR; o yüzden komut önce kapi.pid'in canlı pid'le eşleştiğine bakar.
const PANO_YOL = process.env.KAPI_PANO_YOL || path.join(GENEL, 'pano.js');
let PANO_JS = '', PANO_SHA = '';
function panoYukle() {
  if (!PANO_ACIK) { PANO_JS = ''; PANO_SHA = 'kapali'; return; }
  const js = fs.readFileSync(PANO_YOL, 'utf8');   // okunamazsa fırlatır: açılışta ölümcül, SIGHUP'ta eski kopya durur
  PANO_JS = js; PANO_SHA = crypto.createHash('sha256').update(js).digest('hex').slice(0, 12);
  try { fs.writeFileSync(path.join(DURUM_DIZ, 'kapi.pano-sha'), PANO_SHA + '\n'); } catch (e) { console.error(new Date().toISOString(), `kapı: kapi.pano-sha yazılamadı: ${e.message}`); }
}
// Dizin ÖNCE (bağımsız göz tur 1): yoksa ilk kapi.pano-sha yazımı sessizce kaybolurdu — yazamıyorsa günlüğe düşer, kapı yine açılır.
try { fs.mkdirSync(DURUM_DIZ, { recursive: true }); } catch (e) { console.error(new Date().toISOString(), `kapı: durum dizini açılamadı (${DURUM_DIZ}): ${e.message}`); }
panoYukle();
try { fs.writeFileSync(path.join(DURUM_DIZ, 'kapi.pid'), String(process.pid) + '\n'); } catch (e) { console.error(new Date().toISOString(), `kapı: kapi.pid yazılamadı: ${e.message}`); }
process.on('SIGHUP', () => {
  const eski = PANO_SHA;
  try { panoYukle(); console.log(new Date().toISOString(), `kapı: SIGHUP — pano.js yeniden okundu (${eski} → ${PANO_SHA}), bağlantılar açık`); }
  catch (e) { console.error(new Date().toISOString(), `kapı: SIGHUP — pano.js okunamadı (${e.message}); eski kopya (${eski}) sunulmaya devam`); }
});
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
const RAPOR_DIZ = process.env.KAPI_RAPOR_DIZ || '/config/.terminal-onar/rapor';
const RAPOR_TIP = { '.html': 'text/html; charset=utf-8', '.json': 'application/json; charset=utf-8', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8', '.pdf': 'application/pdf' };
// ── YAYIN KİPİ (2.3.0 · REVAK-KURTARICI'nın 12 Eki tasarımı, ortak koda 13 Eki taşındı) ────────────────────────
// Rapor klasöründe `.defter-yayin` işareti varsa (defter-sayfasi'nın yayımladığı salt-okur sayfa) klasör YAYIN kipindedir:
// 🔴 Rapor kapıyla AYNI KÖKENDEN sunulur: içindeki bir betik /api/gonder'e ulaşsa tmux'a tuş yazabilirdi. Yayın kipinde her
//    cevap CSP kum havuzunda (opak köken) ve ağ erişimsiz (connect-src/form-action 'none') döner — sayfa çizer, kapıya istek atamaz;
//    yazma yöntemleri 405 (veri.json dahil). İşaretsiz klasör (SEDİR: ev/ridvan, sayfası veri.json'u tarayıcıdan PUT'lar)
//    bayt bayt eski davranıştadır — kum havuzu onun yazma kolunu keserdi. Gizli adlar (.defter-yayin, .gecici…) iki kipte de sunulmaz.
const RAPOR_CSP = "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads; default-src 'none'; "
  + "script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'none'; form-action 'none'; "
  + "base-uri 'none'; frame-ancestors 'self' https://kokpit.mmepanel.com";

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
  // x-kapi-pano: yüklü pano.js sha'sı (12 hex) — kapi-yenile komutu tazelenmeyi bununla ölçer; sır değil, girişsiz sayfada da var.
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-cache', 'x-kapi-pano': PANO_SHA });
  res.end(h);
}

function govde(req, sinir = 64 * 1024) {
  return new Promise((ok, red) => {
    const parca = []; let n = 0;
    req.on('data', (c) => { n += c.length; if (n > sinir) { red(Object.assign(new Error('çok büyük'), { kod: 413 })); req.destroy(); } else parca.push(c); });
    req.on('end', () => ok(Buffer.concat(parca))); req.on('error', red);
  });
}
function calistir(komut, arg, girdi, sure = 20000) {
  return new Promise((ok) => {
    const c = execFile(komut, arg, { timeout: sure, maxBuffer: 1 << 20 }, (h, out, err) => ok({ kod: h ? (h.code ?? 1) : 0, out: String(out), err: String(err), zamanAsimi: !!(h && h.killed) }));
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

// ---- kişi terminali: <taban>/tty-k[/...] → ttyd-kisi köküne (/, /token, /ws). Yol değilse null.
function ttyKisiYolu(url) {
  const tk = T('/tty-k'), u = String(url || ''), p = u.split('?')[0];
  if (!(p === tk || p.startsWith(tk + '/'))) return null;
  const r = u.slice(tk.length); return r.startsWith('/') ? r : ('/' + r);
}
function ttydKisiVekil(req, res) {
  const yol = ttyKisiYolu(req.url);
  const bas = { ...req.headers, host: 'localhost' };
  const v = http.request({ socketPath: TTYD_KISI_SOKET, path: yol, method: req.method, headers: bas }, (yan) => { res.writeHead(yan.statusCode, yan.headers); yan.pipe(res); });
  v.on('error', () => { if (!res.headersSent) json(res, 502, { hata: 'Kişi terminali bu kutuda kurulu değil (ttyd-kisi yok).' }); else res.destroy(); });
  req.pipe(v);
}
// ---- ttyd'ye vekâlet (HTTP). ttyd'nin HTML sayfasına pano köprüsü (genel/pano.js) gömülür.
function ttydVekil(req, res) {
  const bas = { ...req.headers, host: 'localhost' };
  // 🔴 HTML'e EKLEME yapacağız → ttyd'den DÜZ gövde istenir (sıkıştırılmış gövdeye dokunulmaz; merkez.mjs'in
  //    bağımsız-göz dersi: gzip baytını metin sanıp başlığı silmek sayfayı çöpe çevirir). Tel bütçesi korunur:
  //    istemci gzip istediyse eklenmiş gövdeyi BİZ sıkıştırırız (ttyd sayfası ~730 KB düz · ~190 KB gzip).
  const gzipIster = PANO_ACIK && /\bgzip\b/.test(String(req.headers['accept-encoding'] || ''));
  if (PANO_ACIK && req.method === 'GET') delete bas['accept-encoding'];
  const v = http.request({ socketPath: TTYD_SOKET, path: req.url, method: req.method, headers: bas }, (yan) => {
    const tur = String(yan.headers['content-type'] || '');
    const kodlama = String(yan.headers['content-encoding'] || '').trim().toLowerCase();
    // Yalnız 200 + text/html + düz gövde eklenir; WebSocket, token, hata sayfası, sıkıştırılmış cevap OLDUĞU GİBİ akar.
    if (!PANO_ACIK || req.method !== 'GET' || yan.statusCode !== 200 || !tur.includes('text/html') || (kodlama && kodlama !== 'identity')) {
      res.writeHead(yan.statusCode, yan.headers); return yan.pipe(res);
    }
    // Gövde tavanı: aşılırsa eklemeden vazgeç, olduğu gibi akıt (sayfa kaybolmasın).
    const TAVAN = 4 * 1024 * 1024; const parca = []; let boy = 0, akitiliyor = false;
    yan.on('data', (c) => {
      if (akitiliyor) return;
      boy += c.length;
      if (boy > TAVAN) {
        akitiliyor = true; const b2 = { ...yan.headers }; delete b2['content-length'];
        res.writeHead(yan.statusCode, b2); for (const p of parca) res.write(p); res.write(c); yan.pipe(res); return;
      }
      parca.push(c);
    });
    yan.on('end', () => {
      if (akitiliyor) return;
      let h = Buffer.concat(parca).toString('utf8');
      const ek = `<script>window.__TABAN=${JSON.stringify(TABAN)};window.__KUTU=${JSON.stringify(KUTU)};</script><script>${PANO_JS}</script>`;
      // Değiştirici FONKSİYON: düz dize verilse pano.js içindeki '$' dizileri replace tarafından yorumlanırdı.
      h = h.includes('</body>') ? h.replace('</body>', () => ek + '</body>') : h + ek;
      const b2 = { ...yan.headers }; delete b2['content-length']; delete b2['content-encoding'];
      let govde = Buffer.from(h, 'utf8');
      if (gzipIster) { govde = zlib.gzipSync(govde); b2['content-encoding'] = 'gzip'; }
      b2['content-length'] = String(govde.length);
      res.writeHead(yan.statusCode, b2); res.end(govde);
    });
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

const koltukOnbellek = onbellekKur(async () => { const r = await calistir('bash', [KOLTUK_BETIK, '--liste']); return { ok: r.kod === 0, out: r.out }; },
  { taze: +(process.env.KAPI_KOLTUK_TAZE_MS ?? 4000), bayat: +(process.env.KAPI_KOLTUK_BAYAT_MS ?? 150000) });
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
  if (req.method === 'POST') res.once('finish', () => { if (koltukDegistirir(y, res.statusCode)) koltukOnbellek.dusur(); });   // koltuk açma, dondurma: cevap gidince liste eskidir
  res.setHeader('x-content-type-options', 'nosniff');
  res.setHeader('referrer-policy', 'no-referrer');
  // 🔴 ÇERÇEVE İZNİ (canlı sayfa kuralı 1.1.0 · SEDİR'in ölçümü ve isteği, 2026-10-01).
  //    Ölçüldü: kapı HİÇ çerçeve başlığı göndermiyordu — yani açık oturumlu bir terminal
  //    ve altındaki rapor sayfaları HERHANGİ bir sitenin içine gömülebiliyordu. Kural
  //    kokpitin içinde açılmayı istiyor; başlık EKLEMEK burada koruma gevşetmesi DEĞİL,
  //    SIKILAŞTIRMADIR: artık yalnız kendimiz ve kokpit gömebilir.
  //    Her cevaba konur (giriş · rapor · terminal): tek bir yolun başlıksız kalması
  //    korumayı o yoldan deler.
  res.setHeader('content-security-policy', "frame-ancestors 'self' https://kokpit.mmepanel.com");

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
  if (y === '/tty-k' || y.startsWith('/tty-k/')) return ttydKisiVekil(req, res);   // kişi terminali ÖNCE: '/tty' öneki onu da yakalardı (abc ttyd'sine düşerdi)
  if (y.startsWith('/tty')) return ttydVekil(req, res);

    // ── RAPOR SAYFALARI (2026-09-30, Sultan isteği) ─────────────────────────────
  // Girişten SONRA sunulan küçük statik sayfalar: <taban>/rapor/<ad>/ → RAPOR_DIZ/<ad>/.
  // Yazılabilen TEK dosya veri.json (PUT, x-kapi başlığı, geçerli JSON, ≤1 MB, atomik).
  // Kapı parolası + Cloudflare Access arkasında kalır; dışarıya yeni bir yol açmaz.
  if (y.startsWith('/rapor/')) {
    const parca = y.slice('/rapor/'.length).split('/');
    const ad = parca.shift();
    if (!/^[a-z0-9-]{1,40}$/.test(ad || '')) { res.writeHead(404); return res.end('yok'); }
    const kok = path.join(RAPOR_DIZ, ad);
    if (!parca.length) { res.writeHead(302, { location: T(`/rapor/${ad}/`) }); return res.end(); }
    const ic = parca.join('/') || 'index.html';
    // gizli ad (yayın işareti, geçici dosya) sunulmaz — kök ad zaten ^[a-z0-9-]$ kısıtından geçti (nokta giremez), burada açıkça da sorulur
    if (ad.startsWith('.') || parca.some((p) => p.startsWith('.'))) { res.writeHead(404); return res.end('yok'); }
    const yol = path.join(kok, ic);
    // 🔴 METİNSEL ÖNEK YETMEZ — SEMBOLİK BAĞ (bağımsız göz, tur 1).
    //    Önek kontrolü yolun YAZIMINA bakar; dosya sisteminin nereye baktığına değil.
    //    Rapor ağacına konan bir bağ, kökün DIŞINDAKİ bir dosyayı gösterebilir ve metin
    //    kontrolü bunu göremez. Üstelik M9 (yazım kaçışı) ayrıştırıcı yüzünden HTTP'den
    //    tetiklenemiyordu; bu kapı ise HTTP'den ÖLÇÜLEBİLİR — yani ölçülemez sandığımız
    //    savunmanın ölçülebilir yarısı buymuş.
    //    Gerçek yol çözülür (bağlar izlenir), sonra önek YENİDEN sorulur.
    if (!yol.startsWith(kok + path.sep)) { res.writeHead(404); return res.end('yok'); }
    const _gercek = (p0) => { try { return fs.realpathSync(p0); } catch { return null; } };
    // 🔴 ÇAPA RAPOR KÖKÜDÜR, rapor KLASÖRÜ DEĞİL (kendi düzeltmemin kusuru, tur 4'te ölçüldü).
    //    İlk yazımda her şeyi `kok`a (yani <RAPOR_DIZ>/<ad>) göre sınıyordum. Ama `ad`ın
    //    kendisi kök dışına bakan bir BAĞ olabilir; o zaman `kok`un gerçeği de dışarıdadır
    //    ve kontrol KENDİ KENDİNİ onaylar. Ölçüldü: bağlı dizine yazma fiilen dışarı düştü.
    //    Çapa sabit olmalı: RAPOR_DIZ'in gerçeği.
    const tabanGercek = _gercek(RAPOR_DIZ);
    const kokGercek = _gercek(kok);
    if (!tabanGercek || !kokGercek) { res.writeHead(404); return res.end('yok'); }
    const _icinde = (p0) => !!p0 && (p0 === tabanGercek || p0.startsWith(tabanGercek + path.sep));
    if (!_icinde(kokGercek)) { res.writeHead(404); return res.end('yok'); }
    const yayin = fs.existsSync(path.join(kokGercek, '.defter-yayin'));
    if (yayin && req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405, { allow: 'GET, HEAD' }); return res.end(); }
    // 🔴 YAZMA KOLU DA BAĞ KONTROLÜNDEN GEÇER (bağımsız göz, tur 4 — okuma korunmuş,
    //    YAZMA korunmamıştı). Sıra yüzünden PUT, aşağıdaki gerçek-yol sınamasından ÖNCE
    //    çalışıyordu: `veri.json` kökün dışına bakan bir bağ olsaydı, yazma o dosyayı
    //    EZERDİ. Okuma kaçışı sızdırır; yazma kaçışı BOZAR — ikincisi daha ağır.
    //    İki kapı: (a) hedefin bulunduğu dizin gerçekte kökün içinde mi
    //              (b) hedef zaten varsa BAĞ mı — bağsa yazma reddedilir (izlenmez).
    if (req.method === 'PUT' && ic === 'veri.json') {
      try { if (fs.lstatSync(yol).isSymbolicLink()) { res.writeHead(404); return res.end('yok'); } } catch { /* yoksa sorun değil */ }
      if (req.headers['x-kapi'] !== '1') return json(res, 403, { hata: 'Başlık eksik.' });
      try {
        const g = await govde(req, 1024 * 1024);
        JSON.parse(g.toString('utf8'));
        const gecici = yol + '.' + process.pid + '.gecici';
        fs.writeFileSync(gecici, g, { mode: 0o600 }); fs.renameSync(gecici, yol);
        return json(res, 200, { tamam: true, zaman: new Date().toISOString() });
      } catch (e) { return json(res, e.kod || 400, { hata: e.kod === 413 ? 'Çok büyük.' : 'Geçersiz veri.' }); }
    }
    if ((req.method !== 'GET' && !(yayin && req.method === 'HEAD')) || !fs.existsSync(yol)) { res.writeHead(404); return res.end('yok'); }
    const yolGercek = _gercek(yol);
    //    Bağ izlendikten SONRA hâlâ kökün içinde mi? Değilse 404 — dosya var olsa bile.
    if (!_icinde(yolGercek)) { res.writeHead(404); return res.end('yok'); }
    if (!fs.statSync(yolGercek).isFile()) { res.writeHead(404); return res.end('yok'); }
    res.writeHead(200, { 'content-type': RAPOR_TIP[path.extname(yol).toLowerCase()] || 'application/octet-stream', 'cache-control': 'no-store',
      ...(yayin ? { 'content-security-policy': RAPOR_CSP } : {}) });
    if (req.method === 'HEAD') return res.end();
    return fs.createReadStream(yol).pipe(res);
  }

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
      // Koltuklar: kutudaki görünür tmux oturumları. Liste betikten gelir (ttyd'nin kabul ettiğiyle
      // AYNI liste); kapı ad türetmez. Ekran adresi: <taban>/tty/?arg=<kimlik> (2.24.0: ad değil ad dışı kimlik; tuz yoksa adres YOK).
      if (y === '/api/koltuklar') {
        const { deger: r, yas } = await koltukOnbellek.al();
        if (!r.ok) return json(res, 500, { hata: 'Koltuklar ölçülemedi.' });
        // satır çözümü + ad süzgeci kapi/koltuklar.mjs'te (tek kaynak); ad HTML'de kaçışlı, adreste encodeURIComponent
        // ODA (2.36.8 · kutu–oda modeli 2 · SERDAR kararı A, 31 Eki): sıra oda.json → kayıttaki oda → oda dışı (kural kapi/oda.mjs'te); koltukta oda_kaynak klasor|kayit.
        //   Ayrışmada klasör geçerli, oda_uyari döner. Dizin yanıta YAZILMAZ. Kayıt okunamazsa yalnız klasör basamağı kalır, liste düşmez.
        let kayitOda = new Map(); try { kayitOda = kayitOdaHaritasi(kayitOku(PROJE).uyeler); } catch {}
        const odalar = new Map();
        const koltuklar = koltukSatirlari(r.out).map(({ dizin, ...k }) => {
          const bulunan = odaBul(dizin), kayitta = kayitOdaBul(kayitOda, k.ad), sec = odaSec(bulunan, kayitta), uyari = odaUyarisi(bulunan, kayitta);
          if (sec && sec.kaynak === 'klasor') odalar.set(sec.oda, bulunan);   // klasörün hedef · reis bilgisi kayıt satırını ezer
          else if (sec && !odalar.has(sec.oda)) odalar.set(sec.oda, { ad: sec.oda, hedef: '', reis: '' });
          return { ...k, ...(sec ? { oda: sec.oda, oda_kaynak: sec.kaynak } : {}), ...(uyari ? { oda_uyari: uyari } : {}), ana: k.ad === ANA_TMUX, kabuk: k.ad === KABUK_TMUX, ...ekranAdresi(k.ad) };
        });
        return json(res, 200, { kutu: KUTU, ana: ANA_TMUX, kabuk: KABUK_TMUX, yas_ms: yas, odalar: [...odalar.values()].sort((a, b) => a.ad.localeCompare(b.ad, 'tr')), koltuklar });
      }
      // ── KOLTUK AÇ / YENİDEN AÇ / ESKİ SOHBETE DÖN (2.4.0 · dilim 5/5, Sultan: "oturum kapandı/bozuldu/silindi —
      //    tekrar açmak çok basit ve çok sağlam olmalı"). Ölçüm ve iş betikte (scripts/koltuk-ac.sh): üç durum ayrı
      //    (yok · claude-yok · takili), yol = ekip-ac.sh (tek kanonik kapı) | onar.sh (ana) | yok (kayıtsız → ret).
      const km0 = y.match(/^\/api\/koltuk\/([^/]{1,2400})(\/ac)?$/);   // KODLU parça: 4 baytlık UTF-8 karakter (emoji) %XX×4 = 12 karakter → 200 kod noktası en çok 2400; sınır ÇÖZÜMDEN SONRA desenle (bağımsız göz tur 3)   // ad yolda encodeURIComponent ile gelir (%2F); çözülüp aynı süzgeçle sınanır
      let kmAd = ''; try { kmAd = km0 ? decodeURIComponent(km0[1]) : ''; } catch { kmAd = ''; }
      const km = km0 && KOLTUK_AD_DESEN.test(kmAd) ? [km0[0], kmAd, km0[2]] : null;
      if (km && !km[2] && req.method === 'GET') {
        const r = await calistir('bash', [KOLTUK_AC_BETIK, 'durum', km[1]]);
        try { return json(res, 200, JSON.parse(r.out)); } catch { return json(res, 500, { hata: 'Koltuk ölçülemedi.' }); }
      }
      if (km && km[2] && req.method === 'POST') {
        let g = {}; try { g = JSON.parse((await govde(req, 4096)).toString('utf8') || '{}'); } catch { g = {}; }
        const arg = [KOLTUK_AC_BETIK, 'ac', km[1]]; if (g.eski === true) arg.push('--eski'); if (g.zorla === true) arg.push('--zorla');
        // Açma uzun sürebilir (ekip-ac canlılık teyidi · onar.sh): 20 sn değil 120 sn; zaman aşımı 'açılamadı' DEĞİL 504 —
        // oturum arkada doğmuş olabilir, telefon durumu yeniler (yedek göz tur 2).
        const sureMs = +(process.env.KAPI_AC_SURE_MS || 120000);   // sınav kısa süre verir
        const r = await calistir('bash', arg, undefined, sureMs);
        if (r.zamanAsimi) return json(res, 504, { tamam: false, rc: 124, mesaj: `Açma ${Math.round(sureMs / 1000)} sn'de bitmedi — koltuk arkada doğmuş olabilir; durumu yenileyip bak.` });   // mesaj gerçek süreyi söyler (yedek göz tur 4)
        const mesaj = (r.out + r.err).trim().split('\n').filter(Boolean).pop() || '';
        // rc: 0 açıldı/zaten canlı · 1 açılamadı · 3 merdiven başladı · 4 kayıtsız koltuk · 5 takılı: zorla gerek (dokunulmadı)
        const kod = r.kod === 0 ? 200 : r.kod === 3 ? 202 : r.kod === 4 ? 409 : r.kod === 5 ? 428 : 502;
        return json(res, kod, { tamam: r.kod === 0 || r.kod === 3, rc: r.kod, mesaj });
      }
      // ── KADRO (2.8.0 · Kadro E1 önkoşul 1+3, gorev_01M4WVHD00GF5MAQD1J7G74RZ4): kutunun personel KAYDI ⟂ canlı KOLTUKLAR.
      //    Dört grup + kayıtsız (kapi/kadro.mjs tek kaynak). Yalnız okur; kaldır/bağla/emekli ayrı uçlardır (E2-E4). Ekran adresi
      //    koltuk listesiyle aynı kuralla (encodeURIComponent).
      // ── BUGÜN (2.15.0 · gorev_01M54SCQE08KTG9YERG2BBR604): kutudaki ajanların GÜN ÇIPALARI (gunluk-plan/cipa.sh dosyaları) — havuzdan
      //    ayrı "bugün" görünümünün verisi. Salt okur; yeni defter yok (kaynak çıpa). Bugüne ait olmayan çıpa listeye girmez, adıyla
      //    `bugun_degil`de görünür; okunamayan dosya `okunamadi`da. ?tarih=YYYY-MM-DD sınav dikişi (varsayılan kutunun yerel bugünü).
      if (y === '/api/bugun') {
        const t = url.searchParams.get('tarih');
        // göz #355 tur 1: biçim yetmez, takvimde var olan gün olmalı (2026-99-99 → 400; Date gevşek çözümlemesi geri yazımla sınanır)
        // göz tur 2: geçersiz Date'te toISOString RangeError fırlatır — işleyici dışarıdan gelen sorguyla çökmez, 400 döner
        const takvimde = (x) => { try { return /^\d{4}-\d{2}-\d{2}$/.test(x) && new Date(x + 'T00:00:00Z').toISOString().slice(0, 10) === x; } catch { return false; } };
        if (t && !takvimde(t)) return json(res, 400, { hata: 'tarih takvimde olan bir gün olmalı (YYYY-MM-DD).' });
        const b = bugunOku(PROJE, t || undefined);
        return json(res, 200, { kutu: KUTU, proje: PROJE, zaman: new Date().toISOString(), ...b });
      }
      // ── KADRO · Uzmanlıklar + Terimler (Mühürdarlık G12 · SERDAR 22 Eki 05:10 (A)): iki SALT-OKUR uç — veri sahibinin kutusunda okunur, merkez vekil yolundan alır.
      //    Yalnız GET (yazma yolu yok); çıktı beyaz listedir (yol/kaynak/sır yok — tarif.mjs); okunamayan kaynak `olc` + null, boş liste değil.
      if (y === '/api/kadro/tarif' || y === '/api/kadro/uzmanlik') {
        if (req.method !== 'GET') return json(res, 405, { hata: 'Bu uç yalnız okur (GET).' });
        return json(res, 200, { kutu: KUTU, zaman: new Date().toISOString(), ...(y === '/api/kadro/tarif' ? tarifOku() : uzmanlikOku()) });
      }
      if (y === '/api/kadro') {
        const r = await calistir('bash', [KOLTUK_BETIK, '--liste']);
        if (r.kod !== 0) return json(res, 500, { hata: 'Koltuklar ölçülemedi.' });
        const kayit = kayitOku(PROJE);
        // Var olan ama OKUNAMAYAN kayıt dosyası hata sayılır (göz tur 1): boş kayıtla devam etmek herkesi "kayıtsız" gösterirdi — yalan.
        if (kayit.okunamadi.length) return json(res, 500, { hata: 'Kayıt okunamadı: ' + kayit.okunamadi.join(', ') });
        const kd = kadroBirlestir({ uyeler: kayit.uyeler, koltuklar: koltukSatirlari(r.out), ana: ANA_TMUX, kimlikler: kimlikler() });
        const ekranla = (o) => o ? { ...o, ...ekranAdresi(o.ad) } : null;
        // ETİKET (2.33.0 · görev …ZDV): Sultan'ın kayda koyduğu görünen ad · açıklama · not — ayrı dosyadan; okunamazsa kadro düşmez, işaretlenir
        const et = etiketOku(DURUM_DIZ), etiketli = (k) => Object.hasOwn(et.etiketler, k.id) ? { etiket: et.etiketler[k.id] } : {};
        return json(res, 200, { kutu: KUTU, ana: ANA_TMUX, proje: PROJE, kaynak: kayit.kaynak, okunamadi: kayit.okunamadi, zaman: new Date().toISOString(),
          sayilar: kd.sayilar, kisiler: kd.kisiler.map((k) => ({ ...k, oturum: ekranla(k.oturum), ...etiketli(k) })), kayitsiz: kd.kayitsiz.map(ekranla),
          etiket: true, ...(et.okunamadi ? { etiket_okunamadi: true } : {}),   // etiket: bu kapı etiket ucunu taşıyor (merkez düzenleme alanını buna bakarak açar)
          altyapi: kd.altyapi.map(ekranla), eylemler: true,   // eylemler: bu kapı E2 ucunu taşıyor (merkez düğmeleri buna bakar)
          // Dava Rafı (Parça B2): kayıt kökünde dava_kurali varsa raf alanı; bagla: bu kapı E4 (kayda bağla) eylemini taşıyor
          ...(kayit.dava_kurali ? { davalar: davaOzet(kd.kisiler, kayit.dava_kurali) } : {}), bagla: true });
      }
      // ── KADRO E2 (Sultan onaylı, SERDAR 16 Eki 00:3x): dört eylem, hepsi geri alınabilir.
      //    emekli · dondur → kayda durum (kadro-yaz.mjs; önceki değer durum_once) + oturum açıksa kapatılır (kapatılamazsa kayıt GERİ ALINIR)
      //    geri-ac         → durum_once geri konur; dondurulmuştuysa oturum kutunun kendi açıcısıyla eski sohbetine döner (koltuk-ac --eski)
      //    kapat           → YALNIZ kayıtsız oturum (kayıtlı kişi dondurulur, kapatılmaz)
      // 🔴 A06: emeklilik Sultan kararıdır, düğmeyi insan basar. Uç yalnız kapı oturumu çereziyle açılır (yukarıdaki girisli kapısı —
      //    o çerezi yalnız kutu parolası ya da merkez üretir; merkezin önünde Access + merkez parolası). Jeton taşıyan istek REDDEDİLİR:
      //    bu kapının jeton yolu yok; jetonla gelen istek bir ajandır ve "bir gün jeton kabul edilir" diye sessizce açılmasın.
      // 🔴 ALTYAPI oturumları (ana · dash* · ttyd-* · kapi-* · *-kurtarici · imglistener*) hiçbir eylemle kapatılamaz: 403, tmux'a dokunulmaz.
      // ── KADRO ETİKETİ (2.33.0 · görev …ZDV · Sultan 28 Eki): bir kayda görünen ad · açıklama · not — kayıt dosyasına DEĞİL ayrı dosyaya
      //    (kadro-etiket.mjs). Hal ucuyla aynı kimlik kuralı: yalnız Sultan oturumu (çerez + x-kapi), jetonla gelen istek ajandır → 403.
      //    Kimlik kayıtta olmalı (uydurma kimliğe etiket yazılmaz → 404). Günlüğe değer YAZILMAZ (not mahremdir): yalnız kimlik · alan · uzunluk.
      if (y === '/api/kadro/etiket' && req.method === 'POST') {
        if (req.headers.authorization || req.headers['x-defter-jeton']) return json(res, 403, { hata: 'Bu uç jetonla çağrılamaz — etiketi Sultan ekrandan yazar.' });
        let g; try { g = JSON.parse((await govde(req, 8192)).toString('utf8') || '{}'); } catch (e) { return json(res, e.kod === 413 ? 413 : 400, { hata: e.kod === 413 ? 'Çok büyük.' : 'Geçersiz istek.' }); }
        const id = String(g.id || ''), alan = String(g.alan || '');
        const kayit = kayitOku(PROJE);
        if (kayit.okunamadi.length) return json(res, 500, { hata: 'Kayıt okunamadı: ' + kayit.okunamadi.join(', ') });
        if (!kayit.uyeler.some((u) => u.id === id)) return json(res, 404, { hata: 'Bu kimlik kayıtta yok.' });
        const birak = await kadroKilit();
        try {
          const sonuc = etiketYaz(DURUM_DIZ, id, alan, g.deger);
          try { fs.appendFileSync(path.join(DURUM_DIZ, 'kadro-hal.log'), `${new Date().toISOString()} etiket ${JSON.stringify(id)} ${alan} ${sonuc && sonuc[alan] ? [...sonuc[alan]].length + ' karakter' : 'silindi'}\n`); } catch {}
          return json(res, 200, { tamam: true, id, etiket: sonuc });
        } catch (e) { if (e instanceof EtiketHata) return json(res, e.kod, { hata: e.message }); throw e; }
        finally { birak(); }
      }
      if (y === '/api/kadro/hal' && req.method === 'POST') {
        if (req.headers.authorization || req.headers['x-defter-jeton']) return json(res, 403, { hata: 'Bu uç jetonla çağrılamaz — kadro kararını Sultan ekrandan verir.' });
        let g; try { g = JSON.parse((await govde(req, 4096)).toString('utf8') || '{}'); } catch { return json(res, 400, { hata: 'Geçersiz istek.' }); }
        const eylem = String(g.eylem || '');
        if (!['emekli', 'dondur', 'geri-ac', 'kapat', 'bagla', 'bagla-geri-al'].includes(eylem)) return json(res, 400, { hata: 'Eylem: emekli · dondur · geri-ac · kapat · bagla · bagla-geri-al.' });
        // Altyapı kontrolü HER ŞEYDEN ÖNCE ve yalnız adla: liste ölçülemese bile altyapıya dokunulmaz
        if (eylem === 'kapat' && altyapiNeden(String(g.oturum || ''), ANA_TMUX)) return json(res, 403, { hata: `Altyapı oturumu (${altyapiNeden(String(g.oturum), ANA_TMUX)}) kapatılamaz.` });
        if (eylem === 'bagla' && altyapiNeden(String(g.oturum || ''), ANA_TMUX)) return json(res, 403, { hata: `Altyapı oturumu (${altyapiNeden(String(g.oturum), ANA_TMUX)}) kayda bağlanamaz.` });
        const birak = await kadroKilit();
        let dosyaBirak = () => {};
        try {
        // Süreçler arası kilit (B7): günlük bekçi turu da aynı kayda yazar → AYNI dosya (kilit.mjs, PROJE; kadroYaz da orada kilitler).
        // Bütün işlem (yer aç: dondur + aç · bağla) bu kilit altında; içeride yalnız kadroYazKilitAltinda çağrılır.
        try { dosyaBirak = dosyaKilit(PROJE, { bekleMs: KILIT_BEKLE_MS }); } catch (e) { if (e instanceof KadroHata) return json(res, e.kod, { hata: e.message }); throw e; }
        const r = await calistir('bash', [KOLTUK_BETIK, '--liste']);
        if (r.kod !== 0) return json(res, 500, { hata: 'Koltuklar ölçülemedi — hiçbir şey yapılmadı.' });
        const kayit = kayitOku(PROJE);
        if (kayit.okunamadi.length) return json(res, 500, { hata: 'Kayıt okunamadı: ' + kayit.okunamadi.join(', ') });
        const kd = kadroBirlestir({ uyeler: kayit.uyeler, koltuklar: koltukSatirlari(r.out), ana: ANA_TMUX, kimlikler: kimlikler() });
        const izYaz = (satir) => { try { fs.appendFileSync(path.join(DURUM_DIZ, 'kadro-hal.log'), new Date().toISOString() + ' ' + satir + '\n'); } catch {} };
        const kapat = async (ad) => (await calistir('tmux', ['kill-session', '-t', '=' + ad])).kod === 0;   // '=' tam ad eşleşmesi (önek değil)
        if (eylem === 'kapat') {
          const ad = String(g.oturum || '');
          if (!KOLTUK_AD_DESEN.test(ad)) return json(res, 400, { hata: 'Oturum adı geçersiz.' });
          if (kd.kisiler.some((k) => k.oturum && k.oturum.ad === ad)) return json(res, 409, { hata: 'Bu oturum kayıtlı bir kişinin — kapatmak yerine dondur.' });
          if (!kd.kayitsiz.some((o) => o.ad === ad)) return json(res, 404, { hata: 'Böyle bir kayıtsız oturum yok (kapanmış olabilir).' });
          // KAPAT KORUMASI (2.17.0): içinde Claude çalışan oturum kapatılmaz — kayıt okunamasa da canlı ajan öldürülmez
          if (kd.kayitsiz.some((o) => o.ad === ad && !o.kapatilabilir)) return json(res, 409, { hata: 'Bu oturumda Claude çalışıyor — kapatılmaz. Kayıtta görünmüyorsa önce kadro kaydını düzelt.' });
          if (!(await kapat(ad))) return json(res, 502, { hata: 'Oturum kapatılamadı.' });
          izYaz(`kapat ${JSON.stringify(ad)}`);
          return json(res, 200, { tamam: true, mesaj: `${ad} kapatıldı.` });
        }
        // ── E4 · KAYDA BAĞLA (Parça B6): kayıtsız oturum ya yeni dava satırı olur ya da var olan bir kişinin oturumu sayılır.
        //    Oturuma dokunulmaz (kapanmaz, içindeki sohbet sürer). Claude kimliği oturumun kimlik izinden (kimlik.mjs) okunur.
        if (eylem === 'bagla') {
          const ad = String(g.oturum || '');
          if (!KOLTUK_AD_DESEN.test(ad)) return json(res, 400, { hata: 'Oturum adı geçersiz.' });
          if (!kd.kayitsiz.some((o) => o.ad === ad)) return json(res, 404, { hata: 'Böyle bir kayıtsız oturum yok (kapanmış ya da zaten bağlı olabilir).' });
          const kim = (kimlikler().get(ad) || []);
          if (kim.length !== 1) return json(res, 409, { hata: kim.length ? 'Oturumda birden çok Claude var — hangisinin bağlanacağı belirsiz.' : 'Oturumda Claude yok — bağlanacak kimlik bulunamadı.' });
          try {
            if (g.hedef === 'dava') {
              const no = String(g.dosya_no || ''), kisa = String(g.kisa_ad || '');
              if (!DOSYA_NO.test(no)) return json(res, 400, { hata: 'Dosya no YYYY/N biçiminde olmalı (ör. 2025/42).' });
              if (!kisaAdGecerli(kisa)) return json(res, 400, { hata: 'Kısa ad 1-60 harf olmalı; tırnak ve ters bölü olamaz.' });
              if (kd.kisiler.some((k) => k.id === no)) return json(res, 409, { hata: `"${no}" zaten rafta.` });
              const s2 = davaEkle({ proje: PROJE, id: no, tmux: ad, arz_adi: kisa, session_id: kim[0].sessionId, cwd: kim[0].cwd });
              izYaz(`bagla ${JSON.stringify(ad)} → dava ${JSON.stringify(no)} ${s2.dosya}`);
              return json(res, 200, { tamam: true, mesaj: `${no} rafa eklendi.` });
            }
            if (g.hedef === 'kisi') {
              const id = String(g.id || ''); const kisi = kd.kisiler.find((k) => k.id === id);
              if (!kisi) return json(res, 404, { hata: 'Kayıtta böyle bir kişi yok.' });
              if (kisi.altyapi) return json(res, 403, { hata: `Altyapı oturumu (${kisi.altyapi}) — kadro eylemi uygulanamaz.` });
              if (kisi.rol === DAVA_ROL) return json(res, 409, { hata: 'Dava satırına oturum bağlanmaz — yeni dava olarak bağla.' });
              if (kisi.oturum && kisi.oturum.claude) return json(res, 409, { hata: `${id} zaten çalışan bir oturumda — bağlanmadı.` });
              const s2 = kisiyeBagla({ proje: PROJE, id, session_id: kim[0].sessionId });
              izYaz(`bagla ${JSON.stringify(ad)} → kisi ${JSON.stringify(id)} ${s2.onceki || '-'}→${kim[0].sessionId} ${s2.dosya}`);
              return json(res, 200, { tamam: true, mesaj: `${ad} artık ${id} oturumu.` });
            }
            return json(res, 400, { hata: 'Hedef: dava · kisi.' });
          } catch (e) { if (e instanceof KadroHata) return json(res, e.kod, { hata: e.message }); throw e; }
        }
        if (eylem === 'bagla-geri-al') {
          const id = String(g.id || ''); const kisi = kd.kisiler.find((k) => k.id === id);
          if (!id || !kisi) return json(res, 404, { hata: 'Kayıtta böyle bir kişi yok.' });
          if (!kisi.bagla_ile) return json(res, 409, { hata: 'Bu kayıt bağlamayla gelmedi.' });
          try { const s2 = baglaGeriAl({ proje: PROJE, id }); izYaz(`bagla-geri-al ${JSON.stringify(id)} ${s2.silindi ? 'blok silindi' : 'kimlik geri kondu'} ${s2.dosya}`); }
          catch (e) { if (e instanceof KadroHata) return json(res, e.kod, { hata: e.message }); throw e; }
          return json(res, 200, { tamam: true, mesaj: `${id} bağlaması geri alındı; oturum kapanmadı.` });
        }
        const id = String(g.id || '');
        const kisi = kd.kisiler.find((k) => k.id === id);
        if (!id || !kisi) return json(res, 404, { hata: 'Kayıtta böyle bir kişi yok.' });
        if (kisi.altyapi) return json(res, 403, { hata: `Altyapı oturumu (${kisi.altyapi}) — kadro eylemi uygulanamaz.` });
        const onceHal = kisi.hal_kayit;
        // ── Aç YER AÇAR (Parça B4 · Sultan 14:18): dava geri açılırken açık dava sayısı tavana ulaşmışsa en uzun süredir dokunulmayan
        //    açık dava ÖNCE dondurulur. Dondurulamazsa (oturumu kapanmadı) HİÇBİR ŞEY açılmaz → 502.
        let donduruldu = null;
        if (eylem === 'geri-ac' && g.yer_ac === true && kisi.rol === DAVA_ROL && onceHal === 'dondurulmus' && kayit.dava_kurali) {
          const aday = yerAcAday(kd.kisiler, kayit.dava_kurali, id);
          if (aday) {
            try { await davaDondur({ proje: PROJE, kisi: aday, kapat, iz: izYaz, neden: 'yer açmak için' }); }
            catch (e) { if (e instanceof KadroHata) return json(res, e.kod, { hata: `Tavan dolu ve ${aday.id} dondurulamadı (${e.message}) — ${id} açılmadı.` }); throw e; }
            donduruldu = aday.id;
          }
        }
        let sonuc;
        try { sonuc = kadroYazKilitAltinda({ proje: PROJE, id, eylem, ek: kisi.rol === DAVA_ROL ? davaEk(kisi, eylem) : null }); }
        catch (e) { if (e instanceof KadroHata) return json(res, e.kod, { hata: e.message }); throw e; }
        izYaz(`${eylem} ${JSON.stringify(id)} ${sonuc.onceki || '-'}→${sonuc.yeni || '-'} ${sonuc.dosya}${sonuc.uretilmis ? ' (derlendi)' : ''}`);
        if (eylem === 'emekli' || eylem === 'dondur') {
          if (kisi.oturum && !(await kapat(kisi.oturum.ad))) {
            // Kayıt "kapalı" derken oturum çalışıyorsa ekran yalan söyler → kaydı geri al. Geri alma DA düşerse bunu söyle (bağımsız göz
            // tur 1: hata yutulup "döndürüldü" deniyordu) — kayıt şu an yanlış hâldedir ve elle düzeltilmelidir.
            try { kadroYazKilitAltinda({ proje: PROJE, id, eylem: 'geri-ac', ek: kisi.rol === DAVA_ROL ? davaGeriEk(kisi) : null }); izYaz(`geri-al ${JSON.stringify(id)} (oturum kapatılamadı)`); }
            catch (e) { izYaz(`GERI-ALINAMADI ${JSON.stringify(id)} ${String(e.message || e)}`);
              return json(res, 500, { hata: `Oturum kapatılamadı VE kayıt geri alınamadı (${e.message || e}) — kayıt şu an "${sonuc.yeni}" diyor, oturum çalışıyor; elle düzeltilmeli.` }); }
            return json(res, 502, { hata: 'Oturum kapatılamadı — kayıt eski hâline döndürüldü.' });
          }
          return json(res, 200, { tamam: true, mesaj: `${id} ${eylem === 'emekli' ? 'emekli edildi' : 'donduruldu'}${kisi.oturum ? ', oturumu kapandı' : ''}.` });
        }
        // geri-ac: dondurulmuşsa oturum yeniden doğar (eski sohbetine döner); emekliyse yalnız kayıt geri gelir
        if (onceHal === 'dondurulmus' && kisi.tmux && !kisi.oturum) {
          const a = await calistir('bash', [KOLTUK_AC_BETIK, 'ac', kisi.tmux, '--eski'], undefined, +(process.env.KAPI_AC_SURE_MS || 120000));
          const msj = (a.out + a.err).trim().split('\n').filter(Boolean).pop() || '';
          const dz = kisi.rol === DAVA_ROL ? { donduruldu } : {};
          if (a.kod === 0 || a.kod === 3) return json(res, 200, { tamam: true, oturum: true, ...ekranAdresi(kisi.tmux), ...dz, mesaj: `${id} geri açıldı, oturumu eski sohbetiyle açılıyor.` });
          return json(res, 200, { tamam: true, oturum: false, ...dz, mesaj: `${id} kaydı geri açıldı ama oturum açılamadı: ${msj || 'açıcı cevap vermedi'} — Kaldır ile yeniden dene.` });
        }
        return json(res, 200, { tamam: true, ...(kisi.rol === DAVA_ROL ? { donduruldu } : {}), mesaj: `${id} geri açıldı.` });
        } finally { dosyaBirak(); birak(); }
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
  // KİŞİ TERMİNALİ soketi (A5-3): <taban>/tty-k/ws → ttyd-kisi; soket yoksa 502 (abc ttyd'sine düşmez)
  const _kyol = ttyKisiYolu(req.url || '');
  if (_kyol !== null) {
    if (!girisli(req)) { soket.end('HTTP/1.1 401 Unauthorized\r\n\r\n'); return; }
    const hk = net.connect(TTYD_KISI_SOKET, () => {
      const b = [`${req.method} ${_kyol} HTTP/1.1`];
      for (let i = 0; i < req.rawHeaders.length; i += 2) {
        const ad = req.rawHeaders[i];
        b.push(`${ad}: ${ad.toLowerCase() === 'host' ? 'localhost' : req.rawHeaders[i + 1]}`);
      }
      hk.write(b.join('\r\n') + '\r\n\r\n'); if (bas?.length) hk.write(bas);
      hk.pipe(soket); soket.pipe(hk);
    });
    hk.on('error', () => { if (soket.writable) soket.end('HTTP/1.1 502 Bad Gateway\r\n\r\n'); hk.destroy(); soket.destroy(); });
    soket.on('error', () => { hk.destroy(); soket.destroy(); });
    return;
  }
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

sunucu.listen(PORT, '0.0.0.0', () => console.log(new Date().toISOString(), `kapı :${PORT}${TABAN || ' (kök)'} → ttyd ${TTYD_SOKET} · kişi ttyd ${TTYD_KISI_SOKET}`));
