// Canlı Dümen denemesi — blob: fatura penceresi (dal kodu, gerçek köprü + gerçek merkez + gerçek Chrome PDF görüntüleyicisi). Fikstür sayfası bu kutudan sunulur.
import http from 'node:http';
import { appendFileSync, readFileSync, existsSync, unlinkSync } from 'node:fs';
import { createHash } from 'node:crypto';
const [lib, gunluk, kok, ornek] = process.argv.slice(2);
const { Dumen, KapiHata } = await import(lib);
const CDP = 'http://172.30.0.2:9222', MERKEZ = 'http://cloudtop-terminal-merkez:8480';
const PDF = readFileSync(ornek); const oz = (b) => createHash('sha256').update(b).digest('hex').slice(0, 12);
const damga = () => new Date(Date.now() + 3 * 3600e3).toISOString().replace(/\.\d+Z$/, '+03:00');
const yaz = (adim, sonuc) => { const s = `${damga()} dumen-canli-blob ${adim} ${sonuc}`; appendFileSync(gunluk, s + '\n'); console.log(s); };
const SAYFA = `<!doctype html><meta charset=utf-8><title>blob deneme</title><h3>Fatura İşlemleri</h3>
<button id=gor onclick="const b=new Blob([Uint8Array.from(atob('${PDF.toString('base64')}'),c=>c.charCodeAt(0))],{type:'application/pdf'});const f=document.createElement('iframe');f.id='pencere';f.src=window.URL.createObjectURL(b);f.style='width:600px;height:400px';document.getElementById('modal').appendChild(f)">Fatura Görüntüle</button><div id=modal></div>`;
const srv = http.createServer((q, r) => { r.setHeader('content-type', 'text/html; charset=utf-8'); r.end(SAYFA); });
await new Promise((ok) => srv.listen(0, '0.0.0.0', ok));
const ADRES = `http://172.30.0.3:${srv.address().port}/`;
const sekmeler = async () => (await (await fetch(CDP + '/json/list')).json()).filter((t) => t.type === 'page').length;
for (const n of ['tik.pdf', 'acik.pdf', 'adres.pdf']) { const p = `${kok}/${n}`; if (existsSync(p)) unlinkSync(p); }
const once = await sekmeler(); yaz('sekme-once', `sayi=${once}`);
let kod = 0;
try {
  await Dumen.kos({ cdpUrl: CDP, merkez: MERKEZ, dosyaKok: [kok], yaz: () => {} }, async (d) => {
    await d.goto(ADRES); yaz('goto', 'tamam (bu kutudan sunulan fikstür sayfası)');
    const t1 = Date.now(); const f = await d.indir('text=Fatura Görüntüle >> visible=true', `${kok}/tik.pdf`);
    const ayni = oz(readFileSync(`${kok}/tik.pdf`)) === oz(PDF);
    yaz('indir-tikla', `tamam kaynak=${f.kaynak} bayt=${f.bayt} ozet-ayni=${ayni} ms=${Date.now() - t1}`); if (!ayni || f.kaynak !== 'gomulu') kod = 1;
    const g = await d.indirGomulu('iframe[src^="blob:"]', `${kok}/acik.pdf`);
    const ayni2 = oz(readFileSync(`${kok}/acik.pdf`)) === oz(PDF); yaz('indirGomulu', `tamam kaynak=${g.kaynak} bayt=${g.bayt} ozet-ayni=${ayni2}`); if (!ayni2) kod = 1;
    const ba = (await d.nitelikler('iframe[src^="blob:"]', 'src'))[0] || '';
    const a = await d.indirAdres(ba, `${kok}/adres.pdf`);
    const ayni3 = oz(readFileSync(`${kok}/adres.pdf`)) === oz(PDF); yaz('indirAdres-blob', `tamam bayt=${a.bayt} ozet-ayni=${ayni3}`); if (!ayni3) kod = 1;
  }, { toplamAzamiMs: 120000 });
} catch (x) { yaz('kos', `HATA neden=${x instanceof KapiHata ? x.neden : 'baska:' + String(x.message).slice(0, 100)}`); kod = 1; }
await new Promise((r) => setTimeout(r, 1500));
const sonra = await sekmeler(); yaz('sekme-sonra', `sayi=${sonra} artik=${sonra - once}`); if (sonra !== once) kod = 1;
yaz('sonuc', kod === 0 ? 'GECTI' : 'KALDI'); srv.close(); process.exit(kod);
