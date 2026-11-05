// Canlı Dümen denemesi (dal kodu, gerçek köprü + gerçek merkez). Zararsız: örnek sayfa, örnek PDF, yükleme YOK.
import { appendFileSync, statSync, existsSync, unlinkSync } from 'node:fs';
const [lib, gunluk, kok] = process.argv.slice(2);
const { Dumen, KapiHata } = await import(lib);
const CDP = 'http://172.30.0.2:9222', MERKEZ = 'http://cloudtop-terminal-merkez:8480';
const damga = () => { const d = new Date(Date.now() + 3 * 3600e3); return d.toISOString().replace(/\.\d+Z$/, '+03:00'); };
const yaz = (adim, sonuc) => { const s = `${damga()} dumen-canli ${adim} ${sonuc}`; appendFileSync(gunluk, s + '\n'); console.log(s); };
const sekmeler = async () => (await (await fetch(CDP + '/json/list')).json()).filter((t) => t.type === 'page').length;
const hedef = kok + '/ornek.pdf'; if (existsSync(hedef)) unlinkSync(hedef);
const once = await sekmeler(); yaz('sekme-once', `sayi=${once}`);
let kod = 0;
try {
  await Dumen.kos({ cdpUrl: CDP, merkez: MERKEZ, dosyaKok: [kok], yaz: () => {} }, async (d) => {
    const t0 = Date.now(); await d.goto('https://example.com/'); yaz('goto', `tamam ms=${Date.now() - t0}`);
    const e = await d.engelKapat(); yaz('engelKapat', `tamam escape=${e.escape} tiklanan=${e.tiklanan.length} gizlenen=${e.gizlenen.length}`);
    const o = await d.ogeDurumu('a'); yaz('ogeDurumu', `sayi=${o.sayi} gorunur=${o.gorunur} etkin=${o.etkin}`);
    const t1 = Date.now(); const f = await d.indirAdres('https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', hedef);
    yaz('indirAdres', `tamam tur=${f.tur} bayt=${f.bayt} diskte=${statSync(hedef).size} kaynak=${f.kaynak} ms=${Date.now() - t1}`);
    try { await d.yukle('input[type=file]', hedef, {}); yaz('yukle-onaysiz', 'HATA: reddedilmedi'); kod = 1; }
    catch (x) { yaz('yukle-onaysiz', `reddedildi neden=${x instanceof KapiHata ? x.neden : 'baska:' + String(x.message).slice(0, 60)}`); if (!(x instanceof KapiHata) || x.neden !== 'onay-yok') kod = 1; }
    const t2 = Date.now();
    try { await d.click('#bu-oge-yok-canli-deneme', { azamiMs: 4000 }); yaz('sert-sure', 'HATA: kesilmedi'); kod = 1; }
    catch (x) { const ms = Date.now() - t2; yaz('sert-sure', `kesildi neden=${x instanceof KapiHata ? x.neden : 'baska'} ms=${ms}`); if (!(x instanceof KapiHata) || x.neden !== 'zaman-asimi' || ms > 6000) kod = 1; }
  }, { toplamAzamiMs: 120000 });
} catch (x) { yaz('kos', `HATA neden=${x instanceof KapiHata ? x.neden : 'baska:' + String(x.message).slice(0, 80)}`); kod = 1; }
await new Promise((r) => setTimeout(r, 1500));
const sonra = await sekmeler(); yaz('sekme-sonra', `sayi=${sonra} artik=${sonra - once}`); if (sonra !== once) kod = 1;
yaz('sonuc', kod === 0 ? 'GECTI' : 'KALDI'); process.exit(kod);
