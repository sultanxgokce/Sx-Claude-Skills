// masa.test.mjs — HERMETİK: sahte merkez (mod + durak ucu) + sahte masaüstü bekçisi (HTTP) + masa.mjs. Chromium gerekmez.
// Çalıştır: node masa.test.mjs   (masa.mjs yolu: MASA_LIB, varsayılan yanı)
import http from 'http';
import { mkdtempSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
const LIB = process.env.MASA_LIB || new URL('./masa.mjs', import.meta.url).pathname;
const { Masa } = await import(LIB);
const { KapiHata } = await import(new URL('./dumen.mjs', import.meta.url).pathname);

const dizin = mkdtempSync(join(tmpdir(), 'masa-test-'));
const MASA_JETON = 'masa-jeton-' + Math.random().toString(36).slice(2), DEFTER_JETON = 'defter-jeton-' + Math.random().toString(36).slice(2);
const MASA_DOSYA = join(dizin, 'masa-jeton'); writeFileSync(MASA_DOSYA, MASA_JETON + '\n');
const DEFTER_DOSYA = join(dizin, 'defter-jeton'); writeFileSync(DEFTER_DOSYA, DEFTER_JETON + '\n'); process.env.DUMEN_DEFTER_JETON = DEFTER_DOSYA;
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from('sahte-kare')]);

let mod = 'ajan', merkezCevap = true, masaKod = 200, masaDus = false;
const masaIstekleri = [], duraklar = [], durakBaslik = [];
const merkez = http.createServer((q, r) => {
  if (q.url === '/dumen/mod') { if (!merkezCevap) { q.socket.destroy(); return; } r.setHeader('content-type', 'application/json'); return r.end(JSON.stringify({ mod })); }
  if (q.url === '/api/dumen/durak' && q.method === 'POST') { let b = ''; q.on('data', (c) => b += c); return q.on('end', () => { duraklar.push(JSON.parse(b)); durakBaslik.push(q.headers['x-defter-jeton']); r.setHeader('content-type', 'application/json'); r.end('{"ok":true}'); }); }
  r.statusCode = 404; r.end();
});
const masa = http.createServer((q, r) => {
  let b = ''; q.on('data', (c) => b += c); q.on('end', () => {
    masaIstekleri.push({ yontem: q.method, yol: q.url, jeton: q.headers['x-dumen-jeton'], govde: b ? JSON.parse(b) : null });
    if (masaDus) { q.socket.destroy(); return; }
    if (masaKod !== 200) { r.statusCode = masaKod; r.setHeader('content-type', 'application/json'); return r.end(JSON.stringify({ ok: false, aciklama: 'sahte ' + masaKod })); }
    if (q.url.startsWith('/ekran')) { r.setHeader('content-type', 'image/png'); return r.end(PNG); }
    r.setHeader('content-type', 'application/json'); r.end(JSON.stringify({ ok: true, mod: 'ajan', genislik: 1920, yukseklik: 1080 }));
  });
});
await Promise.all([merkez, masa].map((s) => new Promise((ok) => s.listen(0, '127.0.0.1', ok))));
const satirlar = [];
const m = new Masa({ masaUrl: `http://127.0.0.1:${masa.address().port}`, merkez: `http://127.0.0.1:${merkez.address().port}`, jetonDosya: MASA_DOSYA, zamanAsimiMs: 1500, yaz: (s) => satirlar.push(s) });

let G = 0, K = 0;
const ok = (ad, kosul, ayrinti = '') => { if (kosul) { G++; console.log('  ✓ ' + ad); } else { K++; console.log('  ✗ ' + ad + (ayrinti ? '  → ' + ayrinti : '')); } };
const hata = async (f) => { try { await f(); return null; } catch (e) { return e; } };
const sifirla = () => { mod = 'ajan'; merkezCevap = true; masaKod = 200; masaDus = false; masaIstekleri.length = 0; duraklar.length = 0; durakBaslik.length = 0; satirlar.length = 0; };

console.log('── ajan modu: eylemler doğru uca, doğru gövdeyle, jetonla gider');
sifirla();
const kare = await m.ekranAl({ olcek: 2 });
ok('D1 ekranAl PNG Buffer döner (başlık doğru)', Buffer.isBuffer(kare) && kare.subarray(0, 4).equals(PNG.subarray(0, 4)));
ok('D1 istek GET /ekran?olcek=2 ve x-dumen-jeton = masa jetonu', masaIstekleri[0]?.yol === '/ekran?olcek=2' && masaIstekleri[0]?.jeton === MASA_JETON);
await m.tik(10, 20, { dugme: 3, cift: true, etiket: 'Dosya menüsü' });
ok('D2 tik gövdesi {x,y,dugme,cift}', JSON.stringify(masaIstekleri[1]?.govde) === JSON.stringify({ x: 10, y: 20, dugme: 3, cift: true }));
await m.yaz('ls -la', { alan: 'Terminal komut satırı' });
ok('D2 yaz gövdesi {metin}', masaIstekleri[2]?.govde?.metin === 'ls -la');
await m.tus('ctrl+alt+t'); await m.kaydir(5, 6, -3); const dr = await m.durum();
ok('D2 tus/kaydir/durum doğru uçlara', masaIstekleri[3]?.govde?.kombinasyon === 'ctrl+alt+t' && masaIstekleri[4]?.govde?.dy === -3 && masaIstekleri[5]?.yol === '/durum' && dr.genislik === 1920);
ok('D12 yazılan metin ve jeton çıktıya (yaz callback) GİRMEDİ', !satirlar.join('\n').includes('ls -la') && !satirlar.join('\n').includes(MASA_JETON));

console.log('── çift kilit: merkez modu');
sifirla(); mod = 'sultan';
let e = await hata(() => m.ekranAl());
ok('D3 mod sultan → KapiHata sultanda, bekçi HİÇ çağrılmadı', e instanceof KapiHata && e.neden === 'sultanda' && masaIstekleri.length === 0);
ok("D3 terminale tek satır: Dümen Sultan'da · bekliyorum", satirlar.includes("⏸ Dümen Sultan'da · bekliyorum"));
for (const f of [() => m.tik(1, 1), () => m.yaz('x', { alan: 'Terminal' }), () => m.tus('ctrl+l'), () => m.kaydir(1, 1, 1), () => m.durum()]) await hata(f);
ok('D3 tüm eylemler sultanda reddedildi, bekçiye istek yok', masaIstekleri.length === 0);
sifirla(); mod = 'sultan';
const hs = [await hata(() => m.yaz('x', { alan: 'Parola' })), await hata(() => m.tik(1, 1, { etiket: 'Ödemeyi onayla' })), await hata(() => m.tus('a', { alan: 'CVV' }))];
ok("D3b mod sultan + hassas alan/tık: neden 'sultanda', merkeze durak bildirimi GİTMEDİ", hs.every((x) => x instanceof KapiHata && x.neden === 'sultanda') && duraklar.length === 0 && masaIstekleri.length === 0);
sifirla(); merkezCevap = false;
e = await hata(() => m.tik(1, 1));
ok('D4 merkez cevapsız → fail-closed (merkez-cevapsiz), bekçi çağrılmadı', e instanceof KapiHata && e.neden === 'merkez-cevapsiz' && masaIstekleri.length === 0);

console.log('── çift kilit: bekçi tarafı');
sifirla(); masaKod = 423;
e = await hata(() => m.tik(1, 1));
ok("D5 merkez 'ajan' derken bekçi 423 → hata DEĞİL sultanda", e instanceof KapiHata && e.neden === 'sultanda');
sifirla(); masaDus = true;
e = await hata(() => m.ekranAl());
ok('D6 bağlantı koptu + merkez ajan → masa-koptu (gerçek kopma)', e instanceof KapiHata && e.neden === 'masa-koptu', e && e.neden);
sifirla(); masaDus = true;   // bekçi çağrısı gelince mod sultana geçer
masa.once('request', () => { mod = 'sultan'; });
e = await hata(() => m.ekranAl());
ok('D6 bağlantı koptu + o sırada mod sultan → sultanda (soket düşmesi hata değil)', e instanceof KapiHata && e.neden === 'sultanda', e && e.neden);
sifirla(); masaKod = 401; e = await hata(() => m.tik(1, 1)); ok('D10 bekçi 401 → masa-yetki', e?.neden === 'masa-yetki');
sifirla(); masaKod = 503; e = await hata(() => m.tik(1, 1)); ok('D10 bekçi 503 → masa-kapali', e?.neden === 'masa-kapali');
sifirla(); masaKod = 403; e = await hata(() => m.tus('ctrl+alt+F1')); ok('D9 bekçi 403 → yasak', e?.neden === 'yasak');
sifirla(); masaKod = 400; e = await hata(() => m.tik(99999, 1)); ok('D9 bekçi 400 → istek', e?.neden === 'istek');
const bos = new Masa({ masaUrl: `http://127.0.0.1:${masa.address().port}`, merkez: `http://127.0.0.1:${merkez.address().port}`, jetonDosya: join(dizin, 'yok'), yaz: () => {} });
sifirla(); e = await hata(() => bos.tik(1, 1));
ok('D11 masa jeton dosyası yok → masa-jeton-yok, bekçi çağrılmadı', e?.neden === 'masa-jeton-yok' && masaIstekleri.length === 0);

console.log('── durma noktaları (ajan tarafı)');
sifirla();
e = await hata(() => m.yaz('merhaba'));
ok('D7 alan söylenmeden yaz çalışmaz (alan-belirtilmedi), bekçi çağrılmadı', e?.neden === 'alan-belirtilmedi' && masaIstekleri.length === 0);
e = await hata(() => m.yaz('gizli123', { alan: 'Parola' }));
ok('D7 parola alanı → durak sifre, bekçi çağrılmadı, merkeze bildirildi (defter jetonuyla)', e?.neden === 'durak' && e.bildirildi === true && duraklar[0]?.neden === 'sifre' && durakBaslik[0] === DEFTER_JETON && masaIstekleri.length === 0);
e = await hata(() => m.yaz('123456', { alan: 'SMS doğrulama kodu' }));
ok('D7 SMS kodu alanı → durak sms', e?.neden === 'durak' && duraklar[1]?.neden === 'sms');
e = await hata(() => m.yaz('4111', { alan: 'Kart no (CVV)' }));
ok('D7 kart/CVV alanı → durak odeme', e?.neden === 'durak' && duraklar[2]?.neden === 'odeme');
e = await hata(() => m.tik(5, 5, { etiket: 'Ödemeyi onayla' }));
ok('D8 "Ödemeyi onayla" tıkı → durak odeme, bekçi çağrılmadı', e?.neden === 'durak' && duraklar[3]?.neden === 'odeme' && masaIstekleri.length === 0);
e = await hata(() => m.tik(5, 5, { etiket: 'Tümünü sil' }));
ok('D8 "Tümünü sil" tıkı → durak gonder', e?.neden === 'durak' && duraklar[4]?.neden === 'gonder');
e = await hata(() => m.tus('a'));
ok('D13 tek karakterli tuş alansız gitmez (harf harf şifre yazımı yaz kapısını delmesin)', e?.neden === 'alan-belirtilmedi' && masaIstekleri.length === 0);
e = await hata(() => m.tus('p', { alan: 'Şifre' }));
ok('D13 tek karakterli tuş + parola alanı → durak', e?.neden === 'durak' && masaIstekleri.length === 0);
await m.tus('p', { alan: 'Terminal'}); await m.tus('ctrl+l'); await m.tus('Return');
ok('D13 meşru tek karakter (alan Terminal), ctrl+l, Return geçer', masaIstekleri.length === 3);
ok('D7 durak bildirimi yalnız neden taşır (metin/alan değeri yok)', duraklar.every((d) => Object.keys(d).join() === 'neden'));
sifirla();
e = await hata(() => m.yaz('x', { alan: 'Terminal' }));
ok('D7 meşru alan geçer', e === null && masaIstekleri.length === 1);

masa.close(); merkez.close();
console.log(`\nSONUÇ: ${G} geçti · ${K} kaldı`);
process.exit(K ? 1 : 0);
