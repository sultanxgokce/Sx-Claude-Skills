// mesaj.test.mjs — HERMETİK: sahte merkez (Dümen modu) + sahte Amazon/Trendyol sayfaları (HARITA seçicileriyle) + gerçek headless Chromium (CDP)
//   + gerçek dumen-surucu + sahte gorev.sh. Çalıştır: DUMEN_CHROME=<chrome-headless-shell> node mesaj.test.mjs   (PAZAR_LIB: pazar.mjs yolu, varsayılan yanı)
import http from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, mkdirSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const BURASI = dirname(fileURLToPath(import.meta.url));
const MESAJ = process.env.MESAJ_LIB || join(BURASI, 'mesaj.mjs');
const PAZAR_LIB = process.env.PAZAR_LIB || join(BURASI, 'pazar.mjs');
const DUMEN_LIB = process.env.DUMEN_LIB || resolve(BURASI, '..', '..', 'dumen-surucu', 'scripts', 'dumen.mjs');
const CHROME = process.env.DUMEN_CHROME;
if (!CHROME) { console.log('ÖLÇÜLEMEDİ: DUMEN_CHROME verilmedi'); process.exit(3); }
const { kirp, damgaDogrula, gondermeAcikMi, MesajHata } = await import(PAZAR_LIB);

let G = 0, K = 0;
const ok = (ad, kosul, ayrinti = '') => { if (kosul) { G++; console.log('  ✓ ' + ad); } else { K++; console.log('  ✗ ' + ad + (ayrinti ? '  → ' + ayrinti : '')); } };
const T = mkdtempSync(join(tmpdir(), 'pzm-'));
const bugun = new Date(); const GUN = new Date(bugun.getTime() - bugun.getTimezoneOffset() * 60000).toISOString().slice(0, 10);

// ── sahte sayfalar: Amazon (iki cevapsız + bir cevaplı; müşteri adı ve telefonu ayrı öğede) · Trendyol (bir bekleyen) · giriş sayfası (parola alanı)
let mod = 'ajan'; const gonderilenler = []; let amazonGiris = false;
const AMAZON_LISTE = `<!doctype html><meta charset=utf-8><title>Mesajlar</title><h1>Gelen kutusu</h1>
<div data-thread-id="A-1001" class="thread unresponded"><span class="buyer">Ayşe Y. · +90 532 111 22 33</span><p class="message-preview">Merhaba, siparişim ne zaman kargoya verilir? ayse@example.com</p></div>
<div data-thread-id="A-1002" class="thread unresponded"><span class="buyer">Mehmet K.</span><p class="message-preview">Ürün hasarlı geldi, iade istiyorum.</p></div>
<div data-thread-id="A-0999" class="thread responded"><span class="buyer">Eski</span><p class="message-preview">Teşekkürler, sorun çözüldü.</p></div>`;
const TRENDYOL_LISTE = `<!doctype html><meta charset=utf-8><title>Müşteri soruları</title>
<div data-question-id="T-77" class="q waiting"><span class="buyer">M. D.</span><p class="question-text">Bu ürünün 42 numarası var mı?</p></div>
<div data-question-id="T-70" class="q answered"><p class="question-text">Kargo ücreti ne kadar?</p></div>`;
const sohbetSayfa = (pazar, id, alan) => `<!doctype html><meta charset=utf-8><title>${id}</title><div id="gecmis"></div>
<form method="post" action="/${pazar}/gonder/${id}"><textarea name="${alan}" id="cevap"></textarea><button type="submit" class="${pazar === 'amazon' ? 'send' : 'answer'}">Gönder</button></form>`;
const GIRIS = `<!doctype html><meta charset=utf-8><title>Giriş</title><form><input type=email name=email><input type=password name=password><button>Giriş</button></form>`;
const srv = http.createServer((q, r) => {
  const u = new URL(q.url, 'http://x');
  if (u.pathname === '/dumen/mod') { r.setHeader('content-type', 'application/json'); return r.end(JSON.stringify({ mod, an: '' })); }
  if (u.pathname === '/api/dumen/durak' || u.pathname === '/api/dumen/uyari') { r.statusCode = 200; return r.end('{}'); }
  r.setHeader('content-type', 'text/html; charset=utf-8');
  if (u.pathname === '/amazon/inbox') return r.end(amazonGiris ? GIRIS : AMAZON_LISTE);
  if (u.pathname === '/amazon/signin') return r.end(GIRIS);
  if (u.pathname.startsWith('/amazon/thread/')) return r.end(sohbetSayfa('amazon', u.pathname.split('/').pop(), 'message'));
  if (u.pathname === '/trendyol/sorular') return r.end(TRENDYOL_LISTE);
  if (u.pathname.startsWith('/trendyol/soru/')) return r.end(sohbetSayfa('trendyol', u.pathname.split('/').pop(), 'answer'));
  if (u.pathname.startsWith('/amazon/gonder/') || u.pathname.startsWith('/trendyol/gonder/')) {
    let b = ''; q.on('data', (c) => b += c); return q.on('end', () => { const metin = decodeURIComponent(b.replace(/^(message|answer)=/, '').replace(/\+/g, ' ')); gonderilenler.push({ yol: u.pathname, metin }); r.end(`<!doctype html><meta charset=utf-8><div id="gecmis"><p class="sent">${metin}</p></div>`); });
  }
  r.statusCode = 404; r.end('yok');
});
await new Promise((res) => srv.listen(0, '127.0.0.1', res));
const MERKEZ = `http://127.0.0.1:${srv.address().port}`;
// amazon giriş sayfası adres deseni için ayrı yol: giriş gerekince liste sayfası /amazon/signin'e yönlendirir (gerçekte /ap/signin)
const srvGiris = http.createServer((q, r) => { r.statusCode = 302; r.setHeader('location', `${MERKEZ}/amazon/signin`); r.end(); });
await new Promise((res) => srvGiris.listen(0, '127.0.0.1', res));
const GIRIS_YONLENDIR = `http://127.0.0.1:${srvGiris.address().port}/amazon/inbox`;

const harita = {
  amazon: { ad: 'Amazon (sahte)', olculdu: true, gelen_kutusu: `${MERKEZ}/amazon/inbox`, sohbet_adresi: `${MERKEZ}/amazon/thread/{sohbet}`, giris_deseni: '/signin',
    secici: { sohbet_cevapsiz: '[data-thread-id].unresponded', sohbet_kimlik: 'data-thread-id', son_mesaj: '.message-preview', cevap_alani: 'textarea[name=message]', gonder: 'button.send' },
    gonderme_karari: join(T, 'amazon-gonderme.json') },
  trendyol: { ad: 'Trendyol (sahte)', olculdu: true, gelen_kutusu: `${MERKEZ}/trendyol/sorular`, sohbet_adresi: `${MERKEZ}/trendyol/soru/{sohbet}`, giris_deseni: '/login',
    secici: { sohbet_cevapsiz: '[data-question-id].waiting', sohbet_kimlik: 'data-question-id', son_mesaj: '.question-text', cevap_alani: 'textarea[name=answer]', gonder: 'button.answer' },
    gonderme_karari: null },
};
const HARITA = join(T, 'harita.json'); writeFileSync(HARITA, JSON.stringify(harita));
const GOREV_KAYIT = join(T, 'gorev-cagri.txt'); const GOREV_SH = join(T, 'gorev.sh');
writeFileSync(GOREV_SH, `#!/bin/bash\nprintf '%s\\n' "$@" >> "${GOREV_KAYIT}"\necho "gorev_01TESTONAY"\n`); chmodSync(GOREV_SH, 0o755);

const PORT = 19900 + Math.floor(Math.random() * 90);
const prof = mkdtempSync(join(tmpdir(), 'pzm-chrome-'));
const ch = spawn(CHROME, [`--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT}/json/version`); break; } catch { await new Promise((r) => setTimeout(r, 200)); } }

const ORTAM = { ...process.env, DUMEN_MERKEZ: MERKEZ, DUMEN_CDP: `http://127.0.0.1:${PORT}`, DUMEN_LIB, PAZARYERI_HARITA: HARITA, PAZARYERI_GOREV_SH: GOREV_SH, PAZARYERI_BEKLE: '0', DUMEN_DEFTER_JETON: join(T, 'yok') };
// alt komut EŞZAMANSIZ koşar: sahte merkez/sayfalar bu süreçte; spawnSync olay döngüsünü bloklayıp merkezi cevapsız bırakır (ilk koşuda ölçüldü)
const kos = (...a) => new Promise((res) => { const c = spawn(process.execPath, [MESAJ, ...a], { env: ORTAM }); let out = ''; c.stdout.on('data', (x) => out += x); c.stderr.on('data', (x) => out += x);
  const z = setTimeout(() => c.kill(), 90000); c.on('close', (rc) => { clearTimeout(z); res({ rc, out }); }); });
const damga = (sohbet, gun = GUN) => `${gun} Sultan: onay (görev ekranı · gorev_01TESTONAY · "gönder, cevap uygun ${sohbet}" · beyan:NARH)`;

console.log('── çekirdek (Chromium gerekmez)');
ok('K1 kırpma: telefon, e-posta, IBAN, kart desenleri maskelenir', !/532|example\.com|TR33|4111/.test(kirp('ara +90 532 111 22 33 ya da ali@example.com · TR33 0006 1005 1978 6457 8413 26 · 4111 1111 1111 1111')), kirp('ara +90 532 111 22 33 ya da ali@example.com · TR33 0006 1005 1978 6457 8413 26 · 4111 1111 1111 1111'));
ok('K2 kırpma: uzunluk tavanı 160', kirp('a'.repeat(500)).length <= 160);
const hataKodu = (f) => { try { f(); return null; } catch (e) { return e instanceof MesajHata ? e.kod : 'baska:' + e.message; } };
ok('K3 damga: biçimsiz reddedilir', hataKodu(() => damgaDogrula('Sultan dedi ki olur', 'T-77')) === 'damga-bicim');
ok('K4 damga: dünkü tarih reddedilir', hataKodu(() => damgaDogrula(damga('T-77', '2026-01-01'), 'T-77')) === 'damga-tarih');
ok('K5 damga: başka sohbetin onayı taşınmaz', hataKodu(() => damgaDogrula(damga('T-70'), 'T-77')) === 'damga-sohbet');
ok('K6 damga: doğru damga geçer, parçaları döner', (() => { const d = damgaDogrula(damga('T-77'), 'T-77'); return d.beyan === 'NARH' && d.ref === 'gorev_01TESTONAY'; })());
ok('K7 Amazon gönderme: karar dosyası yokken KAPALI', gondermeAcikMi(harita, 'amazon').acik === false);
writeFileSync(harita.amazon.gonderme_karari, JSON.stringify({ gonderme: 'acik', karar: 'yok' }));
ok('K8 Amazon gönderme: dosya var ama Sultan damgası yoksa KAPALI', gondermeAcikMi(harita, 'amazon').acik === false);
writeFileSync(harita.amazon.gonderme_karari, JSON.stringify({ gonderme: 'acik', karar: `${GUN} Sultan: Amazon'da cevap gönderilebilir (sohbet · ref · "olur" · beyan:NARH)` }));
ok('K9 Amazon gönderme: Sultan kararıyla AÇIK', gondermeAcikMi(harita, 'amazon').acik === true);
ok('K10 Trendyol gönderme: karar gerekmez', gondermeAcikMi(harita, 'trendyol').acik === true);

console.log('── oku (Dümen + sahte sayfalar)');
const o1 = await kos('oku', '--json');
const j1 = (() => { try { return JSON.parse(o1.out.trim().split('\n').pop()); } catch { return null; } })();
ok('O1 oku: iki pazardan üç cevapsız sohbet (cevaplanmışlar yok)', o1.rc === 0 && j1 && j1.cevapsiz.map((x) => x.pazar + ':' + x.sohbet).sort().join() === 'amazon:A-1001,amazon:A-1002,trendyol:T-77', o1.out.slice(-400));
ok('O2 oku: özet mesaj gövdesinden, müşteri adı ve telefonu HİÇ yok, e-posta maskeli', j1 && !/Ayşe|Mehmet|532|ayse@/.test(JSON.stringify(j1)) && j1.cevapsiz.some((x) => x.ozet.includes('<e-posta>')), JSON.stringify(j1));
const o2 = await kos('oku', '--pazar', 'trendyol');
ok('O3 oku --pazar trendyol: yalnız Trendyol, insan okunur satır', o2.rc === 0 && /Trendyol \(sahte\): 1 cevapsız/.test(o2.out) && /trendyol:T-77/.test(o2.out) && !/amazon:/.test(o2.out), o2.out);
harita.amazon.gelen_kutusu = GIRIS_YONLENDIR; writeFileSync(HARITA, JSON.stringify(harita));
const o3 = await kos('oku', '--pazar', 'amazon');
ok('O4 oku: giriş sayfasına düşünce rc 10, parola yazılmaz, "Sultan Dümen\'de girsin"', o3.rc === 10 && /oturum kapalı/.test(o3.out) && /Sultan Dümen'de girsin/.test(o3.out), o3.out);
harita.amazon.gelen_kutusu = `${MERKEZ}/amazon/inbox`; writeFileSync(HARITA, JSON.stringify(harita));
mod = 'sultan';
const o4 = await kos('oku');
ok('O5 oku: Dümen Sultan\'dayken rc 20, eylem yok', o4.rc === 20 && /Sultan'da/.test(o4.out), o4.out);
mod = 'ajan';
harita.trendyol.secici.son_mesaj = '.yok-boyle'; writeFileSync(HARITA, JSON.stringify(harita));
const o5 = await kos('oku', '--pazar', 'trendyol');
ok('O6 oku: harita tutmazsa ÖLÇÜLEMEDİ rc 3 (tahmin yok)', o5.rc === 3 && /harita bu sayfayı tanımıyor/.test(o5.out), o5.out);
harita.trendyol.secici.son_mesaj = '.question-text'; writeFileSync(HARITA, JSON.stringify(harita));

console.log('── taslak (görev defteri)');
const t1 = await kos('taslak', 'trendyol:T-77', '--metin', 'Merhaba, 42 numara stokta; bugün kargoya veriyoruz. Tel: 0532 111 22 33', '--ozet', 'Bu ürünün 42 numarası var mı?');
const gk = existsSync(GOREV_KAYIT) ? readFileSync(GOREV_KAYIT, 'utf8') : '';
ok('T1 taslak: görev defterine sıra sende · karar · onay kaydı açıldı', t1.rc === 0 && /^ac$/m.test(gk) && /^sira-bende$/m.test(gk) && /^karar$/m.test(gk) && /^onay$/m.test(gk), gk + t1.out);
ok('T2 taslak: notta müşteri özeti + cevap taslağı, telefon maskeli', /Cevap taslağı: .*<numara>/.test(gk) && /Müşteri mesajı: Bu ürünün 42/.test(gk), gk);
ok('T3 taslak: sonraki adım (gonder --onay) yazdırılır', /gonder trendyol:T-77 --metin-dosya/.test(t1.out), t1.out);
const t2 = await kos('taslak', 'amazon:A-1001', '--metin', 'Siparişiniz yarın kargoda.');
ok('T4 taslak Amazon: gönderme kapalı uyarısı notta (karar dosyası sıfırlandı)', await (async () => { writeFileSync(harita.amazon.gonderme_karari, '{}'); const r = await kos('taslak', 'amazon:A-1002', '--metin', 'Üzgünüz, iade başlatıyoruz.'); return r.rc === 0 && /gönderme kapalı/.test(readFileSync(GOREV_KAYIT, 'utf8')); })(), t2.out);

console.log('── gonder (onay kapısı + Dümen)');
const MD = join(T, 'cevap.txt'); writeFileSync(MD, 'Merhaba, 42 numara stokta; bugün kargoya veriyoruz.');
const g1 = await kos('gonder', 'trendyol:T-77', '--metin-dosya', MD);
ok('G1 gonder onaysız: rc 2, hiçbir şey gitmedi', g1.rc === 2 && gonderilenler.length === 0, g1.out);
const g2 = await kos('gonder', 'trendyol:T-77', '--metin-dosya', MD, '--onay', damga('T-70'));
ok('G2 gonder başka sohbetin damgasıyla: rc 2, gitmedi', g2.rc === 2 && /anmıyor/.test(g2.out) && gonderilenler.length === 0, g2.out);
const g3 = await kos('gonder', 'trendyol:T-77', '--metin-dosya', MD, '--onay', damga('T-77', '2026-01-01'));
ok('G3 gonder dünkü damgayla: rc 2, gitmedi', g3.rc === 2 && gonderilenler.length === 0, g3.out);
const g4 = await kos('gonder', 'amazon:A-1001', '--metin-dosya', MD, '--onay', damga('A-1001'));
ok('G4 gonder Amazon Sultan kararı yokken: rc 2, gitmedi (okuma/taslak açık, gönderme kapalı)', g4.rc === 2 && /gönderme KAPALI/.test(g4.out) && gonderilenler.length === 0, g4.out);
const g5 = await kos('gonder', 'trendyol:T-77', '--metin-dosya', MD, '--onay', damga('T-77'), '--gorev', 'gorev_01TESTONAY');
await new Promise((r) => setTimeout(r, 300));
ok('G5 gonder Trendyol onaylı: cevap sahte panele ulaştı, metin birebir', g5.rc === 0 && gonderilenler.length === 1 && gonderilenler[0].yol === '/trendyol/gonder/T-77' && gonderilenler[0].metin === readFileSync(MD, 'utf8').trim(), g5.out + JSON.stringify(gonderilenler));
ok('G6 gonder: çıktıda onay tarihi/ref/beyan, görev defterine [gönderildi] adımı', /gönderildi · trendyol:T-77/.test(g5.out) && /beyan:NARH/.test(g5.out) && /\[gönderildi\] Trendyol/.test(readFileSync(GOREV_KAYIT, 'utf8')), g5.out);
writeFileSync(harita.amazon.gonderme_karari, JSON.stringify({ gonderme: 'acik', karar: `${GUN} Sultan: Amazon'da cevap gönderilebilir (sohbet · ref · "olur" · beyan:NARH)` }));
const g6 = await kos('gonder', 'amazon:A-1001', '--metin-dosya', MD, '--onay', damga('A-1001'));
await new Promise((r) => setTimeout(r, 300));
ok('G7 gonder Amazon Sultan kararı + damga: gitti', g6.rc === 0 && gonderilenler.length === 2 && gonderilenler[1].yol === '/amazon/gonder/A-1001', g6.out);
mod = 'sultan';
const g7 = await kos('gonder', 'trendyol:T-77', '--metin-dosya', MD, '--onay', damga('T-77'));
ok('G8 gonder Dümen Sultan\'dayken: rc 20, gitmedi', g7.rc === 20 && gonderilenler.length === 2, g7.out);
mod = 'ajan';
const g8 = await kos('gonder', 'trendyol:T-77', '--metin', 'komut satırında metin');
ok('G9 gonder: metin dosyadan okunur, --metin yok (komut satırı/geçmiş kirlenmez)', g8.rc === 2 && /--metin-dosya/.test(g8.out), g8.out);

console.log(`SONUÇ: geçti=${G} kaldı=${K}`);
ch.kill(); srv.close(); srvGiris.close();
process.exit(K === 0 ? 0 : 1);
