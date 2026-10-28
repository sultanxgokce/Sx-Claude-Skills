// kadro-etiket-uc.test.mjs — KADRO ETİKETİ ucu UÇTAN UCA (2.33.0 · görev …ZDV): gerçek kapı süreci + sahte koltuk listesi.
// Ölçülen: POST /api/kadro/etiket → GET /api/kadro kişinin `etiket`ini taşır · kayıt dosyası BAYT BAYT değişmez · yalnız Sultan oturumu
// (çerezsiz 401 · x-kapi'siz 403 · jetonlu 403) · kayıtta olmayan kimlik 404 · bozuk etiket dosyasında kadro düşmez ve yazım 500 ·
// günlüğe değer yazılmaz. Hermetik: geçici dizin, gerçek kayda ve gerçek tmux'a dokunmaz.
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
process.env.KOLTUK_TUZ ||= mkdtempSync(tmpdir() + '/kapi-tuz-') + '/tuz';
const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kadro-etiket-uc-'));
const SIFRE = 'sinav-parolasi-1234', PORT = 18811;
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };

const LISTE = join(T, 'liste.sh');
writeFileSync(LISTE, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf 'sinavkutu-ana\\t1\\t1\\tana\\tbos\\t\\nBASIRET\\t5\\t1\\tajan\\tbos\\t\\n'\n`, { mode: 0o755 });
const PROJE = join(T, 'proje'), KAYIT = join(PROJE, '_agents/handoff/aile-registry.yaml');
mkdirSync(dirname(KAYIT), { recursive: true });
const ILK_KAYIT = 'uyeler:\n  - id: BASIRET\n    tmux: "BASIRET:0"\n    rol: "gözcü"\n  - id: KALFA\n    tmux: "kalfa:0"\n    durum: canli   # elle not\n';
writeFileSync(KAYIT, ILK_KAYIT);
const DURUM = join(T, 'durum'); mkdirSync(DURUM);

const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: String(PORT), KAPI_TABAN: '/sedir',
  TO_KUTU: 'sinavkutu', TO_PROJE: PROJE, KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: DURUM, SINAVKUTU__TERMINAL_SIFRE: SIFRE,
  KAPI_KOLTUK_BETIK: LISTE, TO_ANA_TMUX: 'sinavkutu-ana', KAPI_EKIPC: '', KAPI_OTURUM_DIZ: join(T, 'oturum-yok') }, stdio: ['ignore', 'ignore', 'pipe'] });
let hataCikti = ''; p.stderr.on('data', (d) => { hataCikti += d; });
process.on('exit', () => { try { p.kill(); } catch {} try { rmSync(T, { recursive: true, force: true }); } catch {} });
process.on('uncaughtException', (e) => { console.log('  ✗ sınav çöktü: ' + e.message); try { p.kill(); } catch {} process.exit(1); });
for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch(`http://127.0.0.1:${PORT}/sedir/giris`)).status === 200) break; } catch {} }
await new Promise((r) => setTimeout(r, 200));
if (p.exitCode !== null) { console.log('  ✗ kapı açılamadı (port dolu?) rc=' + p.exitCode + '\n' + hataCikti.slice(-400)); process.exit(1); }
const giris = await fetch(`http://127.0.0.1:${PORT}/sedir/giris`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parola: SIFRE }) });
const CEREZ = 'kapi=' + ((giris.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
const etiket = async (govde, { cerez = CEREZ, xkapi = true, ek = {} } = {}) => {
  const r = await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro/etiket`, { method: 'POST',
    headers: { 'content-type': 'application/json', ...(cerez ? { cookie: cerez } : {}), ...(xkapi ? { 'x-kapi': '1' } : {}), ...ek }, body: JSON.stringify(govde) });
  let j = {}; try { j = await r.json(); } catch {} return { s: r.status, j };
};
const kadro = async () => (await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro`, { headers: { cookie: CEREZ } })).json();
const kisi = (kd, id) => (kd.kisiler || []).find((x) => x.id === id);
const ETIKET_DOSYA = join(DURUM, 'kadro-etiket.json'), GUNLUK = join(DURUM, 'kadro-hal.log');

console.log('── KE-A · kimlik: yalnız Sultan oturumu');
kapi('KE1 çerezsiz 401', (await etiket({ id: 'BASIRET', alan: 'not', deger: 'x' }, { cerez: '' })).s === 401);
kapi('KE2 x-kapi başlığı yoksa 403', (await etiket({ id: 'BASIRET', alan: 'not', deger: 'x' }, { xkapi: false })).s === 403);
kapi('KE3 jetonla gelen istek 403 (ajan yazamaz)', (await etiket({ id: 'BASIRET', alan: 'not', deger: 'x' }, { ek: { 'x-defter-jeton': 'herhangi' } })).s === 403
  && (await etiket({ id: 'BASIRET', alan: 'not', deger: 'x' }, { ek: { authorization: 'Bearer y' } })).s === 403);
kapi('KE4 hiçbiri dosya yazmadı', !existsSync(ETIKET_DOSYA));

console.log('── KE-B · yazım ve okuma');
const k0 = await kadro();
kapi('KE5 GET /api/kadro etiket ucunu ilan eder, etiketsiz kişide alan yok', k0.etiket === true && kisi(k0, 'BASIRET') && !('etiket' in kisi(k0, 'BASIRET')), JSON.stringify(kisi(k0, 'BASIRET')));
const w1 = await etiket({ id: 'BASIRET', alan: 'not', deger: 'sabah raporunu o yazıyor' });
const w2 = await etiket({ id: 'BASIRET', alan: 'ad', deger: 'Gözcü' });
const w3 = await etiket({ id: 'BASIRET', alan: 'aciklama', deger: 'Kutunun nabzını tutar' });
kapi('KE6 üç alan ayrı ayrı yazılır (200)', w1.s === 200 && w2.s === 200 && w3.s === 200 && w3.j.etiket?.ad === 'Gözcü', JSON.stringify(w3));
const k1 = await kadro(), e1 = kisi(k1, 'BASIRET').etiket || {};
kapi('KE7 GET /api/kadro kişinin etiketini taşır (ad · açıklama · not), kimlik ve rol aynı', e1.ad === 'Gözcü' && e1.aciklama === 'Kutunun nabzını tutar' && e1.not === 'sabah raporunu o yazıyor'
  && kisi(k1, 'BASIRET').id === 'BASIRET' && kisi(k1, 'BASIRET').rol === 'gözcü', JSON.stringify(kisi(k1, 'BASIRET')));
kapi('KE8 kayıt dosyası BAYT BAYT aynı (etiket kayda yazılmaz)', readFileSync(KAYIT, 'utf8') === ILK_KAYIT);
kapi('KE9 öteki kişiye etiket sızmaz', !('etiket' in (kisi(k1, 'KALFA') || {})));
const gl = existsSync(GUNLUK) ? readFileSync(GUNLUK, 'utf8') : '';
kapi('KE10 günlükte kimlik · alan · uzunluk var, DEĞER yok', /etiket "BASIRET" not 24 karakter/.test(gl) && !gl.includes('sabah raporunu') && !gl.includes('Gözcü'), JSON.stringify(gl.slice(-200)));
const w4 = await etiket({ id: 'BASIRET', alan: 'ad', deger: '' });
kapi('KE11 boş değer alanı siler, öteki alanlar kalır', w4.s === 200 && !('ad' in (kisi(await kadro(), 'BASIRET').etiket || {})) && kisi(await kadro(), 'BASIRET').etiket?.not);

console.log('── KE-C · ret yolları');
kapi('KE12 kayıtta olmayan kimlik 404 (uydurma kimliğe etiket yazılmaz)', (await etiket({ id: 'YOKKI', alan: 'not', deger: 'x' })).s === 404 && !readFileSync(ETIKET_DOSYA, 'utf8').includes('YOKKI'));
kapi('KE13 bilinmeyen alan 400 · sınır aşımı 400', (await etiket({ id: 'BASIRET', alan: 'rol', deger: 'x' })).s === 400 && (await etiket({ id: 'BASIRET', alan: 'ad', deger: 'a'.repeat(41) })).s === 400);
kapi('KE14 bozuk gövde 400', (await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro/etiket`, { method: 'POST', headers: { 'content-type': 'application/json', cookie: CEREZ, 'x-kapi': '1' }, body: '{bozuk' })).status === 400);
writeFileSync(ETIKET_DOSYA, '{bozuk');
const k2 = await kadro(), w5 = await etiket({ id: 'BASIRET', alan: 'not', deger: 'y' });
kapi('KE15 bozuk etiket dosyasında kadro DÜŞMEZ (etiket_okunamadi işaretli) ve yazım 500, dosya ezilmez', Array.isArray(k2.kisiler) && k2.kisiler.length >= 2 && k2.etiket_okunamadi === true
  && w5.s === 500 && readFileSync(ETIKET_DOSYA, 'utf8') === '{bozuk', JSON.stringify({ n: k2.kisiler?.length, eo: k2.etiket_okunamadi, s: w5.s }));

console.log(`SONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
