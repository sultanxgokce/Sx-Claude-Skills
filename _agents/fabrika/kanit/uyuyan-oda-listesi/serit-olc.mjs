// Tellal şeridi ölçümü: canlı tellal kapısının 4 Kas 15:4x yanıtı (yalnız ad/oda/hal; ölçüm SERDAR, merkez vekili) GERÇEK merkez şerit koduna (cloudtop sayfalar.mjs MRK.koltukSatiri) verilir.
// kip=once: kapının 2.41.0 yanıtı aynen · kip=sonra: 2.41.1 kuralı (uyuyanın odası listede yoksa eklenir — sunucu.mjs'teki satırın birebir aynısı) uygulanmış yanıt.
import { LISTE_HTML } from '/config/projects/cloudtop/infra/terminal-merkez/sayfalar.mjs';
const kip = process.argv[2];
const kod = [...LISTE_HTML.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).find((b) => b.includes('var MRK='));
globalThis.window = globalThis.window || {};
const MRK = new Function(kod + '\n;return MRK;')();
const U = (ad, oda) => ({ ad, hal: 'uyuyor', oda });
const j = { kutu: 'tellal', ana: 'tellal-ana', odalar: [{ ad: 'mimari-cizim', hedef: '', reis: '' }, { ad: 'ortak-kapilar', hedef: '', reis: '' }],
  koltuklar: [{ ad: 'MEDDAH', oda: 'ortak-kapilar', tur: 'ajan', claude: true, hal: 'bos' }, { ad: 'MUCESSEM', oda: 'mimari-cizim', tur: 'ajan', claude: true, hal: 'bos' }, { ad: 'MUDEVVIN', oda: 'mimari-cizim', tur: 'ajan', claude: true, hal: 'bos' }, { ad: 'tellal-kabuk', kabuk: true, tur: 'kabuk', hal: 'bos' }],
  uyuyanlar: [U('PERGEL','mimari-cizim'),U('USTABAŞI','bakim'),U('DEMİRCİ','bakim'),U('HAYALBAZ','reklam-videosu'),U('KUKLACI','reklam-videosu'),U('TEZHİPÇİ','reklam-videosu'),U('MÜNŞİ','web-tanitim'),U('MÜZEYYİN','web-tanitim'),U('CİLTÇİ','web-tanitim'),U('NÂŞİR','sosyal-medya'),U('TAKVİMCİ','sosyal-medya'),U('MUHARRİR','sosyal-medya')] };
if (kip === 'sonra') { const odalar = new Map(j.odalar.map((o) => [o.ad, o])); for (const u of j.uyuyanlar) if (u.oda && !odalar.has(u.oda)) odalar.set(u.oda, { ad: u.oda, hedef: '', reis: '' }); j.odalar = [...odalar.values()].sort((a, b) => a.ad.localeCompare(b.ad, 'tr')); }
const h = MRK.koltukSatiri('tellal', j, [], null);
const kume = {}; const re = /<span class="mrk-oda[^"]*" data-oda="([^"]*)">/g; let m;
while ((m = re.exec(h))) { let d = 1, k = m.index + m[0].length; const t = /<span\b|<\/span>/g; t.lastIndex = k; let x; while (d > 0 && (x = t.exec(h))) d += x[0] === '</span>' ? -1 : 1; kume[m[1]] = [...h.slice(k, t.lastIndex).matchAll(/data-uyan="([^"]+)"/g)].map((y) => y[1]); }
const ic = new Set(Object.values(kume).flat()), hepsi = [...h.matchAll(/data-uyan="([^"]+)"/g)].map((y) => y[1]), sonda = hepsi.filter((a) => !ic.has(a));
for (const [o, l] of Object.entries(kume)) console.log(`oda ${o}: ${l.length} uyuyan [${l.join(', ')}]`);
console.log(`kümede uyuyan: ${ic.size}/${hepsi.length} · sonda: ${sonda.length} [${sonda.join(', ')}]`);
const istenen = ['bakim', 'reklam-videosu', 'web-tanitim', 'sosyal-medya'];
const tamam = istenen.every((o) => (kume[o] || []).length === 3 - (o === 'bakim' ? 1 : 0)) && sonda.length === 0;
console.log(`dört oda (bakim 2 · reklam-videosu 3 · web-tanitim 3 · sosyal-medya 3) kendi kümesinde ve sonda 0: ${tamam ? 'EVET' : 'HAYIR'}`);
process.exit(tamam ? 0 : 1);
