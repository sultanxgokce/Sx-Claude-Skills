/**
 * kapi-yenile.test.mjs — kapı SIGHUP'ta pano.js'i BAĞLANTI DÜŞÜRMEDEN yeniden okur mu? Gerçek süreç, gerçek HTTP, borusuz.
 *
 * Niçin (SERDAR 00:5x, 16 Eki 2026): pano.js açılışta belleğe alınıyordu; yeni pano sürümü diske inince canlı kapı eskiyi sunuyor,
 * tek yol kapıyı yeniden başlatmaktı — Sultan'ın açık web terminali kopuyordu. Her iddianın ateşleyen ve ateşlemeyen yüzü ölçülür.
 * Mutasyon (beklenen kırmızı): SIGHUP kancası sökülürse Node'un varsayılanı süreci öldürür → Y3/Y5 kırmızı.
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import net from 'node:net';
// 2.24.0: kapı ad dışı kimlik için tuz yaratır → sınav GERÇEK $HOME'a dokunmasın
process.env.KOLTUK_TUZ ||= (await import('node:fs')).mkdtempSync((await import('node:os')).tmpdir() + '/kapi-tuz-') + '/tuz';

const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kapi-yenile-'));
const SIFRE = 'sinav-parolasi-1234';
let gecen = 0, kalan = 0;
const kapi = (ad, kosul, ek = '') => { if (kosul) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const sha = (s) => createHash('sha256').update(s).digest('hex').slice(0, 12);
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));

const PANO = join(T, 'pano.js');
const V1 = 'window.__pano="surum-1";', V2 = 'window.__pano="surum-2 $& $1";';   // '$' dizileri: replace tuzağı da sınanır
writeFileSync(PANO, V1);
const PORT = 18781, TABAN = '/sinavkutu';
// Durum dizini süreç başlamadan VAR OLMAZ (bağımsız göz tur 1): kapı onu kendisi açmalı, ilk sha yazımı kaybolmamalı.
const DURUM = join(T, 'yeni-durum');
const ortam = (ek = {}) => ({ ...process.env, KAPI_PORT: String(PORT), KAPI_TABAN: TABAN, TO_KUTU: 'sinavkutu', KAPI_TTYD_SOKET: join(T, 'ttyd.sock'),
  TO_DURUM_DIZ: DURUM, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_PANO_YOL: PANO, KAPI_KOLTUK_BETIK: join(T, 'yok.sh'), ...ek });
const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: ortam(), stdio: ['ignore', 'pipe', 'pipe'] });
let cikti = ''; p.stdout.on('data', (d) => { cikti += d; }); p.stderr.on('data', (d) => { cikti += d; });
let acildi = false;
for (let i = 0; i < 50 && !acildi; i++) { await bekle(100); try { acildi = (await fetch(`http://127.0.0.1:${PORT}${TABAN}/giris`)).status === 200; } catch {} }
if (!acildi) { console.log('kapı açılmadı:\n' + cikti); process.exit(1); }
const baslik = async () => (await fetch(`http://127.0.0.1:${PORT}${TABAN}/giris`)).headers.get('x-kapi-pano');

console.log('\n── Y · kapı-yenile (SIGHUP) ──');
kapi('Y1 /giris yanıtı yüklü pano sha\'sını söyler (x-kapi-pano = sha(pano.js v1))', (await baslik()) === sha(V1), `→ ${await baslik()} ≠ ${sha(V1)}`);
kapi('Y1b kapi.pid durum dizinine yazıldı ve canlı pid ile aynı', existsSync(join(DURUM, 'kapi.pid')) && readFileSync(join(DURUM, 'kapi.pid'), 'utf8').trim() === String(p.pid));
kapi('Y1c kapi.pano-sha dosyası da sha(v1)', existsSync(join(DURUM, 'kapi.pano-sha')) && readFileSync(join(DURUM, 'kapi.pano-sha'), 'utf8').trim() === sha(V1));

// Uzun ömürlü bağlantı: SIGHUP'tan ÖNCE açılır, SONRA aynı soketten istek atılır → cevap gelirse bağlantı kopmamıştır
const soket = net.connect(PORT, '127.0.0.1');
await new Promise((r) => soket.once('connect', r));
let soketKapandi = false; soket.on('close', () => { soketKapandi = true; }); soket.on('error', () => {});
const soketIste = () => new Promise((r) => { let b = ''; const d = (c) => { b += c; if (/\r\n\r\n/.test(b)) { soket.off('data', d); r(b); } }; soket.on('data', d);
  soket.write(`GET ${TABAN}/giris HTTP/1.1\r\nhost: localhost\r\nconnection: keep-alive\r\n\r\n`); setTimeout(() => { soket.off('data', d); r(b); }, 2000); });
const once = await soketIste();
kapi('Y2 kalıcı bağlantı SIGHUP öncesi çalışıyor (kontrol)', /200 OK/.test(once) && once.toLowerCase().includes('x-kapi-pano: ' + sha(V1)));

writeFileSync(PANO, V2);
kapi('Y2b disk değişti ama kapı hâlâ ESKİSİNİ sunuyor (ateşlemeyen yüz: yeniden okuma kendiliğinden olmaz)', (await baslik()) === sha(V1));
process.kill(p.pid, 'SIGHUP');
let yeni = ''; for (let i = 0; i < 20 && yeni !== sha(V2); i++) { await bekle(100); try { yeni = await baslik(); } catch { yeni = 'ÖLDÜ'; } }
kapi('Y3 SIGHUP sonrası kapı YENİ pano.js\'i sunar (x-kapi-pano = sha(v2))', yeni === sha(V2), `→ ${yeni} ≠ ${sha(V2)}`);
kapi('Y3b süreç aynı pid ile yaşıyor (yeniden başlamadı)', p.exitCode === null && readFileSync(join(DURUM, 'kapi.pid'), 'utf8').trim() === String(p.pid));
const sonra = await soketIste();
kapi('Y4 🔴 SIGHUP öncesi açılan bağlantı SIGHUP sonrası da cevap alır — bağlantı KOPMADI', !soketKapandi && /200 OK/.test(sonra) && sonra.toLowerCase().includes('x-kapi-pano: ' + sha(V2)), `kapandı=${soketKapandi}`);
kapi('Y4b günlük satırı eski→yeni sha\'yı söyler', new RegExp(`SIGHUP — pano.js yeniden okundu \\(${sha(V1)} → ${sha(V2)}\\)`).test(cikti));

// Okunamayan pano.js: eski kopya sunulmaya devam eder, süreç ölmez
const { unlinkSync } = await import('node:fs');
unlinkSync(PANO);
process.kill(p.pid, 'SIGHUP'); await bekle(300);
kapi('Y5 pano.js okunamazsa SIGHUP süreci ÖLDÜRMEZ, son sağlam kopya sunulur', p.exitCode === null && (await baslik()) === sha(V2), `exit=${p.exitCode}`);
kapi('Y5b hata günlüğe düşer (sessiz değil)', /pano.js okunamadı/.test(cikti));
writeFileSync(PANO, V1); process.kill(p.pid, 'SIGHUP'); await bekle(300);
kapi('Y6 dosya geri gelince bir sonraki SIGHUP yine okur (v1)', (await baslik()) === sha(V1));

// KAPI_PANO=0: köprü kapalı → başlık 'kapali' (kapi-yenile.sh bunu 'tazelenecek şey yok' sayar, disk sha'sını kovalamaz)
const p2 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: ortam({ KAPI_PORT: String(PORT + 1), KAPI_PANO: '0', TO_DURUM_DIZ: join(T, 'durum2') }), stdio: ['ignore', 'pipe', 'pipe'] });
let b2 = null; for (let i = 0; i < 50 && b2 === null; i++) { await bekle(100); try { b2 = (await fetch(`http://127.0.0.1:${PORT + 1}${TABAN}/giris`)).headers.get('x-kapi-pano'); } catch {} }
kapi('Y7 KAPI_PANO=0 ile başlık "kapali" der (sha değil) — komut bunu tazelenecek-şey-yok sayar', b2 === 'kapali', `→ ${b2}`);
p2.kill('SIGTERM');

soket.destroy(); p.kill('SIGTERM');
console.log(`\nkapi-yenile.test: ${gecen} geçti · ${kalan} kaldı`);
process.exit(kalan ? 1 : 0);
