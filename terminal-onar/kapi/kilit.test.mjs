// kilit.test.mjs — süreçler arası kayıt kilidi (Parça B7, flock(1)), hermetik: geçici dizin, ağ yok, tmux yok
//   node kilit.test.mjs
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, existsSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dosyaKilit } from './kilit.mjs';

const KOK = dirname(fileURLToPath(import.meta.url));
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const T = mkdtempSync(join(tmpdir(), 'kilit-'));
const KY = join(KOK, 'kilit.mjs');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Ayrı süreçte kilit alır, govde'yi çalıştırır. govde: 'TUTULDU' basıldıktan sonra ne olacağı (b = bırakma fonksiyonu).
// iz verilirse yarışçı: gir/cik zaman damgası yazar, 300 ms bekler, bırakır.
const surec = (govde, iz = '') => spawn(process.execPath, ['-e', `import(${JSON.stringify(KY)}).then(async m=>{try{const b=m.dosyaKilit(${JSON.stringify(T)},{bekleMs:8000});`
  + (iz ? `require('fs').appendFileSync(${JSON.stringify(iz)},'gir '+Date.now()+'\\n');await new Promise(r=>setTimeout(r,300));require('fs').appendFileSync(${JSON.stringify(iz)},'cik '+Date.now()+'\\n');b();console.log('ALINDI')` : `${govde}`)
  + `}catch(e){console.log('RET '+e.kod)}})`], { stdio: ['ignore', 'pipe', 'pipe'] });
const bitir = (c) => new Promise((r) => { let o = ''; c.stdout.on('data', (d) => { o += d; }); c.on('close', () => r(o.trim())); });
const tutulduMu = (c) => new Promise((r) => { let o = ''; c.stdout.on('data', (d) => { o += d; if (o.includes('TUTULDU')) r(true); }); c.on('close', () => r(false)); });
const dene = (bekle) => { try { dosyaKilit(T, { bekleMs: bekle })(); return 'ALINDI'; } catch (e) { return 'RET ' + e.kod; } };
const KL = join(T, 'kadro.kilit');

console.log('── DV-F · süreçler arası kilit (flock(1))');
// DV32: canlı sahip (3 sn tutar) → ikinci girişimci 400 ms'de 503; sahip bırakınca alınır
const canli = surec("console.log('TUTULDU');setTimeout(()=>b(),3000)");
await tutulduMu(canli);
const r32 = dene(400);
kapi('DV32 sahibi CANLI iken kilit alınmaz: 503 (kapı açıcıyı beklerken kilit kaptırılmaz)', r32 === 'RET 503', r32);
await bitir(canli);
kapi('DV32 sahip bırakınca aynı çağrı alır', dene(2000) === 'ALINDI');

// DV32b: sahip ÖLDÜRÜLDÜ (SIGKILL, bırakma çağrılmadan): kernel kilidi düşer, alınır; devral/yaş dosyası üretilmez
const olu = surec("console.log('TUTULDU');process.kill(process.pid,'SIGKILL')");
await tutulduMu(olu); await bitir(olu);
const r32b = dene(2000);
kapi('DV32b sahibi ÖLDÜ (SIGKILL): kilit düşer, alınır ve bırakılır; yan dosya kalmaz', r32b === 'ALINDI' && !existsSync(KL + '.devral'), r32b);

// DV32c: ölü sahipten sonra üç yarışçı aynı anda → hiçbir an iki süreç içeride değil (gir/cik dönüşümlü)
const olu2 = surec("console.log('TUTULDU');process.kill(process.pid,'SIGKILL')");
await tutulduMu(olu2); await bitir(olu2);
const IZ = join(T, 'kilit-iz'); writeFileSync(IZ, '');
const yaris = await Promise.all([1, 2, 3].map(() => bitir(surec('', IZ))));
const ad = readFileSync(IZ, 'utf8').trim().split('\n').map((l) => l.split(' '));
const ust = ad.length === 6 && ad.every((x, i) => (i % 2 === 0 ? x[0] === 'gir' : x[0] === 'cik'));
kapi('DV32c üç yarışçı (ölü sahipten sonra): üçü de sırayla alır, gir/cik dönüşümlü',
  yaris.every((x) => x === 'ALINDI') && ust, JSON.stringify(yaris) + ' ' + ad.map((x) => x[0]).join());

// DV32d: bırakma sonrası aynı süreç hemen yeniden alabilir (kilit dosyası silinmediği için yarış yok)
const b1 = dosyaKilit(T, { bekleMs: 500 }); b1();
kapi('DV32d bırakmadan sonra aynı süreç hemen yeniden alır', dene(500) === 'ALINDI');

// DV32h: sahip DURAKLATILDI (SIGSTOP) — pid yaşıyor, kilit tutuluyor → 503. Sahip öldürülünce alınır.
const dur = surec("console.log('TUTULDU');process.kill(process.pid,'SIGSTOP')");
await tutulduMu(dur); await sleep(100);
const r32h = dene(400);
dur.kill('SIGKILL'); await bitir(dur);
const r32h2 = dene(2000);
kapi('DV32h duraklatılmış (SIGSTOP) sahip kilidi tutar: 503; öldürülünce alınır', r32h === 'RET 503' && r32h2 === 'ALINDI', r32h + ' / ' + r32h2);

// DV32i: iki takipçi kilit boşken aynı anda → ikisi de sırayla alır, gir/cik dönüşümlü
writeFileSync(IZ, '');
const iki = await Promise.all([1, 2].map(() => bitir(surec('', IZ))));
const ad2 = readFileSync(IZ, 'utf8').trim().split('\n').map((l) => l.split(' '));
kapi('DV32i iki takipçi aynı anda: sırayla alır (gir/cik dönüşümlü), ikisi de ALINDI',
  iki.every((x) => x === 'ALINDI') && ad2.length === 4 && ad2.every((x, i) => (i % 2 === 0 ? x[0] === 'gir' : x[0] === 'cik')));

for (const f of [KL, KL + '.devral']) if (existsSync(f)) unlinkSync(f);
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`);
process.exit(k ? 1 : 0);
