// kilit.test.mjs — süreçler arası kayıt kilidi (Parça B7), hermetik: geçici dizin, ağ yok, tmux yok
//   node kilit.test.mjs
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, unlinkSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dosyaKilit } from './kilit.mjs';

const KOK = dirname(fileURLToPath(import.meta.url));
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const T = mkdtempSync(join(tmpdir(), 'kilit-'));
const KL = join(T, 'kadro.kilit'), KY = join(KOK, 'kilit.mjs');
const kilitDene = (bekle, tut = 0, iz = '', gecikme = 0) => spawn(process.execPath, ['-e', `import(${JSON.stringify(KY)}).then(async m=>{const t=Date.now();try{const b=await m.dosyaKilit(${JSON.stringify(T)},{bekleMs:${bekle}});`
  + (iz ? `require('fs').appendFileSync(${JSON.stringify(iz)},'gir '+Date.now()+'\\n');await new Promise(r=>setTimeout(r,${tut}));require('fs').appendFileSync(${JSON.stringify(iz)},'cik '+Date.now()+'\\n');` : '')
  + `b();console.log('ALINDI')}catch(e){console.log('RET '+e.kod+' '+(Date.now()-t))}})`], { stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, KADRO_KILIT_SINAV_GECIKME: String(gecikme) } });
const bitir = (c) => new Promise((r) => { let o = ''; c.stdout.on('data', (d) => { o += d; }); c.on('close', () => r(o.trim())); });
const oluPid = spawnSync('true').pid;

console.log('── DV-F · süreçler arası kilit');
writeFileSync(KL, process.pid + ' canli'); const eskiZaman = new Date(Date.now() - 3600 * 1000);
utimesSync(KL, eskiZaman, eskiZaman);
const r32 = await bitir(kilitDene(400));
kapi('DV32 sahibi YAŞAYAN kilit bir saatlik bile olsa alınmaz: ikinci yazıcı bekler, 503 ile vazgeçer (kapı açıcıyı beklerken kilit kaptırılmaz)',
  /^RET 503 \d+/.test(r32) && +r32.split(' ')[2] >= 400 && readFileSync(KL, 'utf8') === process.pid + ' canli', r32);
writeFileSync(KL, oluPid + ' olu');
const r32b = await bitir(kilitDene(2000));
kapi('DV32b sahibi ÖLMÜŞ kilit bayattır: alınır, iş bitince bırakılır (dosya kalmaz)', r32b === 'ALINDI' && !existsSync(KL), r32b);
writeFileSync(KL, oluPid + ' olu'); const KIZ = join(T, 'kilit-iz'); writeFileSync(KIZ, '');
// gecikme 400 ms: üçü de bayatı görür, sonra devralmaya çalışır — eski kural (doğrulamadan sil) burada ikinci girişi üretir
const yaris = await Promise.all([1, 2, 3].map(() => bitir(kilitDene(8000, 300, KIZ, 400))));
const ad = readFileSync(KIZ, 'utf8').trim().split('\n').map((l) => l.split(' '));
const ust = ad.every((x, i) => (i % 2 === 0 ? x[0] === 'gir' : x[0] === 'cik')) && ad.length === 6;
kapi('DV32c üç süreç AYNI bayat kilidi aynı anda görür ve devralmaya çalışır (pencere sınavda 400 ms): üçü de sırayla alır, hiçbir an iki süreç içeride değil (gir/çık dönüşümlü)',
  yaris.every((x) => x === 'ALINDI') && ust && !existsSync(KL), JSON.stringify(yaris) + ' ' + ad.map((x) => x[0]).join());
const birak = await dosyaKilit(T, { bekleMs: 500 }); writeFileSync(KL, '4242 baskasi'); birak();
kapi('DV32d bırakma yalnız KENDİ kilidini siler: içerik başkasınınsa dosyaya dokunmaz', existsSync(KL) && readFileSync(KL, 'utf8') === '4242 baskasi');
unlinkSync(KL);

console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`);
process.exit(k ? 1 : 0);
