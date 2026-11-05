// dumen-dosya.test.mjs — 0.9.0 HERMETİK: sahte merkez + iki sahte site (ikinci köken) + gerçek headless Chromium (CDP) + dumen.mjs.
// Sınanan: yukle · indir · indirAdres · yeniSekmeAdresi · engelKapat · ogeDurumu · bekle · sert süre sınırı · kapat garantisi (Dumen.kos).
// Çalıştır: DUMEN_CHROME=<chrome-headless-shell> node dumen-dosya.test.mjs   (dumen.mjs yolu: DUMEN_LIB, varsayılan yanı)
import http from 'http';
import { spawn } from 'child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, mkdirSync, symlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
const LIB = process.env.DUMEN_LIB || new URL('./dumen.mjs', import.meta.url).pathname;
const { Dumen, KapiHata } = await import(LIB);
const CHROME = process.env.DUMEN_CHROME;
if (!CHROME) { console.log('ÖLÇÜLEMEDİ: DUMEN_CHROME verilmedi'); process.exit(3); }

const PDF = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n');
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');
let mod = 'ajan'; let modGecikme = 0; const istek = {};
const say = (u) => { istek[u] = (istek[u] || 0) + 1; };
const dis = http.createServer((q, r) => { say('dis' + q.url); r.setHeader('content-type', 'application/pdf'); r.setHeader('content-disposition', 'attachment; filename="dis.pdf"'); r.end(PDF); });   // başka köken, CORS başlığı YOK
await new Promise((ok) => dis.listen(0, '127.0.0.1', ok));
const DIS = `http://127.0.0.1:${dis.address().port}`;
const SAYFA = () => `<!doctype html><meta charset=utf-8><title>panel</title>
<div id=ust><a id=a href="/dosya.pdf">Faturayı indir</a> <a id=p href="/r.png" target=_blank>Görseli Gör</a> <a id=v href="/gor.pdf" target=_blank>Fatura Görüntüle</a>
<a id=x href="${DIS}/dis.pdf">Başka kökenden indir</a> <a id=g href="/giris.pdf">Oturum düşmüş indirme</a> <a id=bozuk href="/bozuk.pdf">Bozuk</a> <button id=yok>Hiçbir şey açmaz</button></div>
<div id=yuk><input id=f type=file style="display:none" onchange="const x=this.files[0];x.text().then(t=>document.getElementById('fs').textContent=x.name+'|'+x.size+'|'+btoa(t))"><span id=fs>-</span>
<button id=sec onclick="document.getElementById('f2').click()">Fatura gönder</button><input id=f2 type=file style="display:none" onchange="document.getElementById('fs2').textContent=this.files[0].name"><span id=fs2>-</span></div>
<div id=ortulu style="position:relative;width:200px;height:40px"><button id=alt onclick="fetch('/tik')">Altta</button><div id=ortu style="position:absolute;inset:0;background:#0003"></div></div>
<button id=ortukaldir onclick="setTimeout(()=>document.getElementById('ortu').remove(),1500)">Örtüyü 1,5 sn sonra kaldır</button> <button id=tik2 onclick="fetch('/tik2')">Tık 2</button>
<div id=iadekutu><button id=iade onclick="document.getElementById('iz').textContent='iade-reddedildi'">Reddet</button><span id=iz>-</span></div>
<div id=cz>Bu site çerez kullanır. <button onclick="document.getElementById('cz').remove()">Reddet</button> <button onclick="document.getElementById('kb').textContent='kabul'">Kabul Et</button></div><span id=kb>-</span>
<div id=tur>Yeni özellik turu <button onclick="document.getElementById('tur').remove()">Turu Geç</button></div>
<iframe id=qualaroo_anket src="about:blank" style="width:50px;height:50px"></iframe><div id=ozel style="width:10px;height:10px">katman</div>
<button class=btn style="display:none">Gönder</button><button class=btn>Gönder</button><textarea id=msj disabled></textarea>`;
const srv = http.createServer((q, r) => {
  say(q.url);
  if (q.url === '/dumen/mod') { r.setHeader('content-type', 'application/json'); return setTimeout(() => r.end(JSON.stringify({ mod, an: '' })), modGecikme); }
  if (q.url === '/tik' || q.url === '/tik2') return r.end('ok');
  if (q.url.startsWith('/api/dumen/')) { r.setHeader('content-type', 'application/json'); return r.end('{"ok":true}'); }
  if (q.url === '/dosya.pdf') { r.setHeader('content-type', 'application/pdf'); r.setHeader('content-disposition', 'attachment; filename="musteri-adi-fatura.pdf"'); return r.end(PDF); }
  if (q.url === '/gor.pdf') { r.setHeader('content-type', 'application/pdf'); return r.end(PDF); }
  if (q.url === '/r.png') { r.setHeader('content-type', 'image/png'); return r.end(PNG); }
  if (q.url === '/giris.pdf') { r.setHeader('content-type', 'text/html; charset=utf-8'); r.setHeader('content-disposition', 'attachment; filename="f.pdf"'); return r.end('<!doctype html><title>Giriş</title><form>parola</form>'); }
  if (q.url === '/bozuk.pdf') { r.setHeader('content-type', 'application/pdf'); r.setHeader('content-disposition', 'attachment; filename="f.pdf"'); return r.end('bu pdf degil'); }
  r.setHeader('content-type', 'text/html; charset=utf-8'); r.end(SAYFA());
});
await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
const MERKEZ = `http://127.0.0.1:${srv.address().port}`;
const PORT = 19900 + Math.floor(Math.random() * 60);
const prof = mkdtempSync(join(tmpdir(), 'dumen-dosya-prof-'));
const ch = spawn(CHROME, [`--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, '--no-sandbox', '--headless', 'about:blank'], { stdio: 'ignore' });
for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${PORT}/json/version`); break; } catch { await new Promise((r) => setTimeout(r, 200)); } }
const CDP = `http://127.0.0.1:${PORT}`;

// dosya düzeni: KOK izinli dizin · DISARI izinsiz
const T = mkdtempSync(join(tmpdir(), 'dumen-dosya-'));
const KOK = join(T, 'izinli'); const DISARI = join(T, 'disari'); mkdirSync(KOK); mkdirSync(DISARI); mkdirSync(join(KOK, 'in'));
const FATURA = join(KOK, 'ahmet-yilmaz-fatura.pdf'); writeFileSync(FATURA, PDF);
const BASKA = join(KOK, 'baska.pdf'); writeFileSync(BASKA, Buffer.concat([PDF, Buffer.from('x')]));
writeFileSync(join(DISARI, 'gizli.pdf'), PDF); symlinkSync(join(DISARI, 'gizli.pdf'), join(KOK, 'bag.pdf'));
writeFileSync(join(KOK, 'defter-jeton.txt'), 'sahte'); writeFileSync(join(KOK, 'program.exe'), 'MZ');

let G = 0, K = 0;
const ok = (ad, kosul, ayrinti = '') => { if (kosul) { G++; console.log('  ✓ ' + ad); } else { K++; console.log('  ✗ ' + ad + (ayrinti ? '  → ' + String(ayrinti).slice(0, 300) : ''));
  if (process.env.DUMEN_ILK_KIRMIZI === '1') { ch.kill('SIGKILL'); console.log(`SONUÇ: geçti=${G} kaldı=${K} (ilk kırmızıda duruldu)`); process.exit(1); } } };   // mutant koşusu: ilk kırmızı yeter
const hata = async (f) => { try { await f(); return null; } catch (e) { return e; } };
const neden = async (f) => { const e = await hata(f); return e ? (e instanceof KapiHata ? e.neden : 'HAM:' + String(e.message).split('\n')[0]) : null; };
const sekmeSay = async () => (await (await fetch(`${CDP}/json/list`)).json()).filter((t) => t.type === 'page').length;
const satirlar = [];
const GUN = Dumen.bugun();
const damga = (dosya, gun = GUN) => `${gun} Sultan: yükle (görev ekranı · gorev_01TESTYUKLE · "faturayı yükle" · ${Dumen.dosyaIzi(dosya)} · beyan:NARH)`;
const sec = { cdpUrl: CDP, merkez: MERKEZ, zamanAsimiMs: 1500, yaz: (s) => satirlar.push(s) };
const t0 = Date.now();
try {
  console.log('── izinli dizin verilmeden dosya işi YOK (fail-closed)');
  delete process.env.DUMEN_DOSYA_KOK;
  const d0 = await Dumen.baglan(sec); await d0.goto(MERKEZ + '/panel');
  ok('F1 yukle: izinli dizin verilmediyse reddedilir (dosya-kok-yok)', (await neden(() => d0.yukle('#f', FATURA, { onay: damga(FATURA) }))) === 'dosya-kok-yok');
  ok('F2 indir: izinli dizin verilmediyse reddedilir, tıklama YAPILMAZ', (await neden(() => d0.indir('#a', join(KOK, 'in', 'a.pdf')))) === 'dosya-kok-yok' && !istek['/dosya.pdf']);
  await d0.kapat();

  const d = await Dumen.baglan({ ...sec, dosyaKok: [KOK], eylemSureMs: 2500, eylemAzamiMs: 8000 }); await d.goto(MERKEZ + '/panel');
  const taban = await sekmeSay();

  console.log('── yukle: onay + dosya kapıları');
  ok('Y1 onaysız yükleme reddedilir (onay-yok), alan boş kalır', (await neden(() => d.yukle('#f', FATURA))) === 'onay-yok' && (await d.metin('#fs')) === '-');
  ok('Y2 dünkü onay reddedilir (onay-bayat)', (await neden(() => d.yukle('#f', FATURA, { onay: damga(FATURA, '2026-01-01') }))) === 'onay-bayat');
  ok('Y3 BAŞKA dosya için verilmiş onay reddedilir (onay-dosya)', (await neden(() => d.yukle('#f', FATURA, { onay: damga(BASKA) }))) === 'onay-dosya');
  ok('Y4 izinli dizin dışındaki dosya reddedilir (dosya-izinsiz)', (await neden(() => d.yukle('#f', join(DISARI, 'gizli.pdf'), { onay: damga(join(DISARI, 'gizli.pdf')) }))) === 'dosya-izinsiz');
  ok('Y5 izinli dizindeki BAĞ dışarıyı gösteriyorsa reddedilir (dosya-izinsiz)', (await neden(() => d.yukle('#f', join(KOK, 'bag.pdf'), { onay: damga(join(KOK, 'bag.pdf')) }))) === 'dosya-izinsiz');
  ok('Y6 sır taşıyabilecek yol reddedilir (dosya-yasak)', (await neden(() => d.yukle('#f', join(KOK, 'defter-jeton.txt'), { onay: damga(join(KOK, 'defter-jeton.txt')) }))) === 'dosya-yasak');
  ok('Y7 izinli olmayan tür reddedilir (dosya-turu)', (await neden(() => d.yukle('#f', join(KOK, 'program.exe'), { onay: damga(join(KOK, 'program.exe')) }))) === 'dosya-turu');
  ok('Y8 reddedilen yüklemelerin hiçbiri alana dosya koymadı', (await d.metin('#fs')) === '-');
  satirlar.length = 0;
  const y = await d.yukle('#f', FATURA, { onay: damga(FATURA) });
  ok('Y9 onaylı yükleme: GİZLİ dosya alanına ad, boyut ve içerik birebir ulaştı', (await d.metin('#fs')) === `ahmet-yilmaz-fatura.pdf|${PDF.length}|${PDF.toString('base64')}` && y.bayt === PDF.length && y.uzanti === '.pdf', await d.metin('#fs'));
  ok('Y10 terminal satırı dosya ADINI taşımaz (müşteri verisi), "gönderme ayrı" der', satirlar.some((s) => s.includes('⬆') && s.includes('GÖNDERME')) && !satirlar.join(' ').includes('ahmet'), satirlar.join(' | '));
  await d.yukle('#sec', FATURA, { onay: damga(FATURA), secici: true });
  ok('Y11 dosya penceresi açan düğme ({ secici: true }): dosya seçildi', (await d.metin('#fs2')) === 'ahmet-yilmaz-fatura.pdf', await d.metin('#fs2'));
  ok('Y12 dosya penceresi açmayan düğmede asılmaz (yukleme-penceresi-yok)', (await neden(() => d.yukle('#yok', FATURA, { onay: damga(FATURA), secici: true, olayMs: 1200 }))) === 'yukleme-penceresi-yok');
  mod = 'sultan';
  ok('Y13 Dümen Sultan\'dayken yükleme YOK (sultanda)', (await neden(() => d.yukle('#f', BASKA, { onay: damga(BASKA) }))) === 'sultanda');
  ok('Y14 Dümen Sultan\'dayken indirme YOK (sultanda), tıklama yapılmadı', (await neden(() => d.indir('#a', join(KOK, 'in', 's.pdf')))) === 'sultanda' && !istek['/dosya.pdf']);
  mod = 'ajan';

  console.log('── indir: baytlar tarayıcının içinden alınır');
  satirlar.length = 0;
  const i1 = await d.indir('#a', join(KOK, 'in', 'fatura.pdf'));
  ok('I1 indirme başlatan tıklama: dosya birebir yazıldı (kaynak indirme)', readFileSync(join(KOK, 'in', 'fatura.pdf')).equals(PDF) && i1.kaynak === 'indirme' && i1.bayt === PDF.length, JSON.stringify(i1));
  ok('I2 terminal satırı sunucunun önerdiği dosya adını taşımaz', satirlar.some((s) => s.includes('⬇')) && !satirlar.join(' ').includes('musteri-adi'), satirlar.join(' | '));
  const i3 = await d.indir('#p', join(KOK, 'in', 'gorsel.png'));
  ok('I3 dosyayı YENİ SEKMEDE açan tıklama: dosya birebir yazıldı (kaynak yeni-sekme)', readFileSync(join(KOK, 'in', 'gorsel.png')).equals(PNG) && i3.kaynak === 'yeni-sekme', JSON.stringify(i3));
  ok('I4 kendi tıklamasının açtığı sekme KAPATILDI (sekme sayısı aynı)', (await sekmeSay()) === taban, `${await sekmeSay()} ≠ ${taban}`);
  const i5 = await d.indir('#v', join(KOK, 'in', 'goruntule.pdf'));
  ok('I5 "Fatura Görüntüle" (yeni sekme + PDF): dosya birebir yazıldı, artık sekme yok', readFileSync(join(KOK, 'in', 'goruntule.pdf')).equals(PDF) && (await sekmeSay()) === taban, JSON.stringify(i5));
  const i6 = await d.indir('#x', join(KOK, 'in', 'dis.pdf')).catch((e) => ({ hata: e.neden || String(e.message) }));
  ok('I6 BAŞKA kökenden indirme (sayfa içi okuma engelli): tarayıcının ağ yığınıyla alındı', i6.kaynak === 'indirme' && readFileSync(join(KOK, 'in', 'dis.pdf')).equals(PDF), JSON.stringify(i6));
  const tb = Date.now();
  ok('I7 ne indirme ne sekme açan tıklama ASILMAZ (indirme-yok)', (await neden(() => d.indir('#yok', join(KOK, 'in', 'yok.pdf'), { olayMs: 1200 }))) === 'indirme-yok' && Date.now() - tb < 6000, `${Date.now() - tb} ms`);
  ok('I8 dosya yerine GİRİŞ SAYFASI gelirse dosya sayılmaz, diske yazılmaz (indirme-sayfa)', (await neden(() => d.indir('#g', join(KOK, 'in', 'giris.pdf')))) === 'indirme-sayfa' && !existsSync(join(KOK, 'in', 'giris.pdf')));
  ok('I9 uzantısıyla uyuşmayan içerik yazılmaz (indirme-tur)', (await neden(() => d.indir('#bozuk', join(KOK, 'in', 'bozuk.pdf')))) === 'indirme-tur' && !existsSync(join(KOK, 'in', 'bozuk.pdf')));
  const once = istek['/dosya.pdf'];
  ok('I10 hedef izinli dizin dışındaysa tıklama YAPILMAZ (dosya-izinsiz)', (await neden(() => d.indir('#a', join(DISARI, 'kacak.pdf')))) === 'dosya-izinsiz' && istek['/dosya.pdf'] === once && !existsSync(join(DISARI, 'kacak.pdf')));
  ok('I11 var olan dosya kendiliğinden ezilmez (dosya-var)', (await neden(() => d.indir('#a', join(KOK, 'in', 'fatura.pdf')))) === 'dosya-var' && istek['/dosya.pdf'] === once);
  writeFileSync(join(KOK, 'in', 'fatura.pdf'), 'eski');
  await d.indir('#a', join(KOK, 'in', 'fatura.pdf'), { ustuneYaz: true });
  ok('I12 { ustuneYaz: true } ile ezilir', readFileSync(join(KOK, 'in', 'fatura.pdf')).equals(PDF));
  const ia = await d.indirAdres(MERKEZ + '/r.png', join(KOK, 'in', 'adres.png'));
  ok('I13 indirAdres: adresi bilinen dosya tarayıcının oturumuyla alındı', readFileSync(join(KOK, 'in', 'adres.png')).equals(PNG) && ia.kaynak === 'adres');
  ok('I14 indirAdres yalnız http(s) alır (file: reddedilir)', (await neden(() => d.indirAdres('file:///etc/passwd', join(KOK, 'in', 'p.txt')))) === 'kullanim');

  console.log('── yeni sekme adresi');
  ok('S1 yeniSekmeAdresi: açılan sekmenin adresi döndü, sekme kapatıldı', (await d.yeniSekmeAdresi('#p')) === MERKEZ + '/r.png' && (await sekmeSay()) === taban);
  ok('S2 yeni sekme açmayan tıklama asılmaz (sekme-yok)', (await neden(() => d.yeniSekmeAdresi('#yok', { olayMs: 1200 }))) === 'sekme-yok');

  console.log('── öğe durumu ve bekleme (salt-okur)');
  const od = await d.ogeDurumu('.btn');
  ok('O1 gizli eşi olan seçici: 2 eşleşme, 1 görünür, ilk görünürün sırası 1', od.sayi === 2 && od.gorunurSayi === 1 && od.ilkGorunur === 1 && od.gorunur && od.etkin, JSON.stringify(od));
  ok('O2 pasif mesaj kutusu boşa yazmadan görülür (etkin: false)', (await d.ogeDurumu('#msj')).etkin === false && (await d.ogeDurumu('#msj')).gorunur === true);
  ok('O3 olmayan öğe: sayı 0, görünür değil', (await d.ogeDurumu('#hic-yok')).sayi === 0 && (await d.ogeDurumu('#hic-yok')).gorunur === false);
  ok('O4 bekle: görünen öğe true, olmayan öğe süre dolunca false (atmaz)', (await d.bekle('#a')) === true && (await d.bekle('#hic-yok', { azamiMs: 700 })) === false);

  console.log('── engel kapatma');
  ok('E0 çerez KABUL etmek onaysız reddedilir (onay-yok)', (await neden(() => d.engelKapat({ cerez: 'kabul' }))) === 'onay-yok');
  const dok = await d.engelKapat({ cerez: 'dokunma', gizle: [] });
  ok('E1 cerez: dokunma → çerez şeridi yerinde, tur kapatıldı', (await d.ogeDurumu('#cz')).sayi === 1 && (await d.ogeDurumu('#tur')).sayi === 0 && dok.tiklanan.join() === 'Turu Geç' && dok.gizlenen === 1, JSON.stringify(dok));
  const r = await d.engelKapat({ gizle: ['#ozel'] });
  ok('E2 varsayılan: çerez şeridi REDDEDİLDİ (Kabul Et\'e basılmadı)', (await d.ogeDurumu('#cz')).sayi === 0 && (await d.metin('#kb')) === '-' && r.tiklanan.includes('Reddet'), JSON.stringify(r));
  ok('E3 çerez kutusu DIŞINDAKİ "Reddet" (iade talebi) TIKLANMADI', (await d.metin('#iz')) === '-', await d.metin('#iz'));
  ok('E4 anket çerçevesi ve ek katman gizlendi, rapor sayıyı verdi', (await d.ogeDurumu('#qualaroo_anket')).gorunur === false && (await d.ogeDurumu('#ozel')).gorunur === false && r.gizlenen === 1 && r.escape === 3, JSON.stringify(r));
  await d.goto(MERKEZ + '/odeme/panel');
  ok('E5 ödeme sayfasında engel kapatılmaz (durak), çerez şeridi yerinde', (await neden(() => d.engelKapat())) === 'durak' && (await d.ogeDurumu('#cz')).sayi === 1);
  await d.goto(MERKEZ + '/panel');

  console.log('── sert süre sınırı ve kapat garantisi');
  await d.click('#ortukaldir');   // örtü 1,5 sn sonra kalkacak: kesilmeyen bir tıklama O ZAMAN gerçekleşirdi
  const tz = Date.now();
  const ez = await hata(() => d.click('#alt', { timeout: 8000, azamiMs: 700 }));
  ok('Z1 örtülü düğmede tıklama sert süre sınırında KESİLİR (zaman-asimi, ≤ 3 sn)', ez instanceof KapiHata && ez.neden === 'zaman-asimi' && Date.now() - tz < 3000, `${ez && ez.message} ${Date.now() - tz} ms`);
  ok('Z2 süre aşımı iletisi "hâli bilinmiyor, ölç" der (körlemesine yineleme yok)', /BİLİNMİYOR/.test(String(ez && ez.message)));
  await new Promise((r2) => setTimeout(r2, 2200));   // örtü çoktan kalktı
  ok('Z1b süre aşımından SONRA yarım kalan tıklama GERÇEKLEŞMEDİ (eylem gerçekten kesildi)', !istek['/tik'], `tık=${istek['/tik']}`);
  await d.goto(MERKEZ + '/panel'); await d.click('#ortukaldir');
  ok('Z1c pozitif kontrol: bağlantı geri geldi, örtü kalkınca aynı düğme tıklanır ve sayılır', (await d.bekle('#ortu', { durum: 'hidden', azamiMs: 5000 })) === true && (await d.click('#alt').then(() => new Promise((r2) => setTimeout(r2, 400)))) === undefined && istek['/tik'] === 1, `tık=${istek['/tik']} bağlanma=${d.durum().baglanmaSayisi}`);
  await d.goto(MERKEZ + '/panel');
  const tv = Date.now();
  const ev = await hata(() => d.click('#alt'));
  ok('Z3 süre verilmese de tıklama SÜRESİZ değil (bağlantının eylem süresi 2,5 sn → ≤ 6 sn içinde hata)', ev && !(ev instanceof KapiHata) && Date.now() - tv < 6000, `${Date.now() - tv} ms`);
  await d.click('#p');   // yeni sekme açar ve açık bırakır
  await new Promise((r2) => setTimeout(r2, 400));
  ok('Z4 tıklama yeni sekme açtı (ön koşul)', (await sekmeSay()) === taban + 1, `${await sekmeSay()}`);
  await d.kapat(); await d.kapat();   // iki kez çağrılabilir
  ok('Z5 kapat(): kendi sekmesi VE kendi tıklamasının açtığı sekme kapandı', (await sekmeSay()) === taban - 1, `${await sekmeSay()} ≠ ${taban - 1}`);
  const tk = await sekmeSay();
  const e1 = await hata(() => Dumen.kos({ ...sec, dosyaKok: [KOK] }, async (x) => { await x.goto(MERKEZ + '/panel'); throw new Error('iş patladı'); }));
  ok('Z6 Dumen.kos: iş hata verse de sekme kapandı, hata çağırana ulaştı', e1 && /iş patladı/.test(e1.message) && (await sekmeSay()) === tk, `${await sekmeSay()} ≠ ${tk}`);
  const e2 = await hata(() => Dumen.kos({ ...sec, dosyaKok: [KOK] }, async (x) => { await x.goto(MERKEZ + '/panel'); await new Promise(() => {}); }, { toplamAzamiMs: 1500 }));
  ok('Z7 Dumen.kos: iş asılırsa toplam süre sınırında kesilir, sekme kapanır', e2 instanceof KapiHata && e2.neden === 'zaman-asimi' && (await sekmeSay()) === tk, `${e2 && e2.message}`);
  const e3 = await hata(() => Dumen.kos({ ...sec, dosyaKok: [KOK] }, async (x) => { await x.goto(MERKEZ + '/panel'); await new Promise((r2) => setTimeout(r2, 1800)); await x.click('#tik2'); }, { toplamAzamiMs: 900 }));
  await new Promise((r2) => setTimeout(r2, 2300));
  ok('Z7b süresi dolup KAPATILAN bağlantı sonradan yeniden bağlanıp tıklamaz (tık yok, artık sekme yok)', e3 instanceof KapiHata && !istek['/tik2'] && (await sekmeSay()) === tk, `tık2=${istek['/tik2']} sekme=${await sekmeSay()}`);
  let sureKapi = 0;
  const e4 = await hata(() => Dumen.kos({ ...sec, zamanAsimiMs: 6000 }, async (x) => {
    await x.goto(MERKEZ + '/panel'); modGecikme = 2500; const tb2 = Date.now();
    try { await x.click('#alt', { timeout: 20000, azamiMs: 4000 }); } finally { sureKapi = Date.now() - tb2; modGecikme = 0; }
  }));
  modGecikme = 0;
  ok('Z2b sert tavan KAPI DAHİLDİR: yavaş kapı (2,5 sn) + asılı eylem toplamı 4 sn tavanında kesilir (≤ 5,3 sn)', e4 instanceof KapiHata && e4.neden === 'zaman-asimi' && sureKapi >= 3600 && sureKapi < 5300, `${sureKapi} ms · ${e4 && e4.message}`);
  const sonuc = await Dumen.kos({ ...sec, dosyaKok: [KOK] }, async (x) => { await x.goto(MERKEZ + '/panel'); return x.metin('#a'); });
  ok('Z8 Dumen.kos: işin sonucu döner, sekme kapanır', sonuc === 'Faturayı indir' && (await sekmeSay()) === tk);
  const to = Date.now();
  const yokDurum = await Dumen.kos({ ...sec, eylemSureMs: 9000 }, async (x) => { await x.goto(MERKEZ + '/panel'); return x.ogeDurumu('#hic-yok'); });
  ok('Z9 olmayan öğede kapı ASILMAZ: durma noktası ölçümü kendi kısa süresiyle biter (eylem süresi 9 sn iken ≤ 5 sn)', yokDurum.sayi === 0 && Date.now() - to < 5000, `${Date.now() - to} ms`);
} catch (e) { K++; console.log('  ✗ SINAV ÇÖKTÜ: ' + String(e && e.stack || e).slice(0, 600)); }
finally { ch.kill('SIGKILL'); srv.close(); dis.close(); }
console.log(`SONUÇ: geçti=${G} kaldı=${K} süre=${Math.round((Date.now() - t0) / 1000)} sn`);
process.exit(K === 0 && G >= 55 ? 0 : 1);
