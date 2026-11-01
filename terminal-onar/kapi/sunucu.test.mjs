/**
 * terminal-onar kapısı — TABAN YOLU sınavı. Gerçek HTTP, gerçek süreç, borusuz.
 *
 * 🔴 NİÇİN VAR: bu kapı 14 kutuya dağıtılacak ve her kutuda bir DIŞ YÜZEY açacak.
 *    Taban yolu desteği merkez sayfanın ön şartı; yanlış olursa hata sessizdir —
 *    sayfa açılır, çağrılar kök yola gider, MERKEZE düşer ve kutuya hiç ulaşmaz.
 *    Sessiz hata, 14 kutuda 14 kez tekrarlanır.
 *
 * Her iddianın ATEŞLEYEN ve ATEŞLEMEYEN yüzü birlikte ölçülür (SEDİR/MEDDAH kuralı).
 */
import { spawn } from 'node:child_process';
// 2.24.0: kapı ad dışı kimlik için tuz okur/yaratır → sınav GERÇEK $HOME'a dokunmasın (tuz geçici yolda)
import { mkdtempSync as _mkt } from 'node:fs'; import { tmpdir as _tmp } from 'node:os';
process.env.KOLTUK_TUZ = _mkt(_tmp() + '/kapi-tuz-') + '/tuz';
import { koltukKimlik as _kk, KOLTUK_KIMLIK_DESEN as _KD } from './koltuk-kimlik.mjs';
// beklenen ekran adresi: ad DEĞİL kimlik (aynı tuz) · ADI TAŞIMADIĞI ayrıca ölçülür (adr)
const ekr = (ad) => '/sedir/tty/?arg=' + _kk(ad);
const adr = (o, ad) => !!o && o.ekran === ekr(ad) && _KD.test(o.kimlik || '') && o.kimlik === _kk(ad) && !o.ekran.includes(encodeURIComponent(ad)) && !o.ekran.includes(ad);
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import net from 'node:net';
import zlib from 'node:zlib';
import { readFileSync } from 'node:fs';

const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kapi-sinav-'));
const SIFRE = 'sinav-parolasi-1234';
let gecen = 0, kalan = 0; const basarisiz = [];
const kapi = (ad, kosul, ek = '') => {
  if (kosul) { gecen++; console.log(`  ✓ ${ad}`); }
  else { kalan++; basarisiz.push(ad); console.log(`  ✗ ${ad} ${ek}`); }
};

// Sahte ttyd: UNIX soketinde HTTP konuşur, aldığı yolu geri söyler.
function sahteTtyd(yol) {
  const s = net.createServer((c) => {
    let b = '';
    c.on('data', (d) => {
      b += d;
      if (!b.includes('\r\n\r\n')) return;
      s.sayac = (s.sayac || 0) + 1;   // TK: hangi ttyd'ye kaç istek düştü (kişi isteği abc ttyd'sine DÜŞMEMELİ)
      const istenen = b.split(' ')[1] || '';
      const ae = /\r\naccept-encoding:/i.test(b) ? '1' : '0';   // kapı accept-encoding'i sıyırdı mı (x-ae ile geri söylenir)
      const HTML = '<html><head><meta charset="utf-8"></head><body><div id="ttyd">ttyd</div><script>window.sahte=1</script></body></html>';
      if (/[?&]html=1/.test(istenen)) { c.end(`HTTP/1.1 200 OK\r\ncontent-type: text/html\r\nx-ae: ${ae}\r\ncontent-length: ${Buffer.byteLength(HTML)}\r\n\r\n${HTML}`); return; }
      if (/[?&]html=2/.test(istenen)) { const h2 = HTML.replace('</body></html>', ''); c.end(`HTTP/1.1 200 OK\r\ncontent-type: text/html\r\ncontent-length: ${Buffer.byteLength(h2)}\r\n\r\n${h2}`); return; }
      if (/[?&]html=3/.test(istenen)) { const gz = zlib.gzipSync(Buffer.from(HTML)); c.write(`HTTP/1.1 200 OK\r\ncontent-type: text/html\r\ncontent-encoding: gzip\r\ncontent-length: ${gz.length}\r\n\r\n`); c.end(gz); return; }
      const g = JSON.stringify({ ttyd: true, yol: istenen });
      c.end(`HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: ${Buffer.byteLength(g)}\r\n\r\n${g}`);
    });
    c.on('error', () => {});
  });
  return new Promise((r) => s.listen(yol, () => r(s)));
}

// Sahte koltuk betiği: --liste'ye sabit liste döner (biri bozuk adlı — kapı onu süzmeli).
const KOLTUK_SAHTE = join(T, 'koltuk-sahte.sh');
writeFileSync(KOLTUK_SAHTE, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\n'
  + 'printf "sinavkutu-ana\\t1760000000\\t0\\nBASIRET\\t1760000100\\t1\\nsinavkutu-kabuk\\t1760000050\\t0\\nkotu:ad\\t1\\t1\\n"\n');
// 2.2.0: betik 5 alan döner (… tür · hâl) ve ANA adını ortamdan (KOLTUK_ANA) alır — sahte, aldığı adı ilk satıra yazar
const KOLTUK_SAHTE5 = join(T, 'koltuk-sahte5.sh');
writeFileSync(KOLTUK_SAHTE5, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\n'
  + 'printf "sinavkutu-ana\\t1760000000\\t0\\tdiger\\tbilinmiyor\\nBASIRET\\t1760000100\\t1\\tajan\\tsoru\\ncc-1\\t5\\t1\\tdiger\\tbilinmiyor\\n2026/85\\t7\\t1\\tajan\\tgirdi\\n"\n');
const KOLTUK_BOZUK = join(T, 'koltuk-bozuk.sh');
writeFileSync(KOLTUK_BOZUK, '#!/usr/bin/env bash\nexit 1\n');

async function kapiAc(taban, port, ek = {}) {
  const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
    env: { ...process.env, KAPI_PORT: String(port), KAPI_TABAN: taban, TO_KUTU: 'sinavkutu',
           KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'),
           TO_ANA_TMUX: 'sinavkutu-ana', KAPI_KOLTUK_BETIK: KOLTUK_SAHTE, ...ek },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  for (let i = 0; i < 50; i++) {
    await new Promise((r) => setTimeout(r, 100));
    try { const r = await fetch(`http://127.0.0.1:${port}${taban}/giris`); if (r.status === 200) return p; } catch {}
    if (p.exitCode !== null) throw new Error('kapı açılmadı, rc=' + p.exitCode);
  }
  throw new Error('kapı zaman aşımı');
}

const iste = (port, yol, { cerez, metot = 'GET', govde } = {}) =>
  fetch(`http://127.0.0.1:${port}${yol}`, {
    method: metot, redirect: 'manual',
    headers: { ...(cerez ? { cookie: cerez } : {}), ...(govde ? { 'content-type': 'application/json', 'x-kapi': '1' } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });

const ttyd = await sahteTtyd(join(T, 'ttyd.sock'));
const ttydKisi = await sahteTtyd(join(T, 'ayse-ttyd.sock'));   // TK: kişi terminali (ttyd-kisi) — ayrı soket
const P1 = 18771, P2 = 18772, P3 = 18773, P4 = 18774;
const kapiTaban = await kapiAc('/sedir', P1);
const kapiKok = await kapiAc('', P2);

console.log('\n── T · TABAN YOLU (kapı /sedir altında) ──');
{
  const g = await iste(P1, '/sedir/giris');
  kapi('T1 giriş sayfası TABAN altında açılır', g.status === 200, `→ ${g.status}`);
  const k = await iste(P1, '/giris');
  kapi('T2 taban DIŞI istek reddedilir (404) — kapı başkasının yoluna cevap vermez', k.status === 404, `→ ${k.status}`);

  const y = await iste(P1, '/sedir');
  kapi('T3 tabanın kendisi sondaki eğik çizgiye yönlenir',
    y.status === 302 && y.headers.get('location') === '/sedir/', `→ ${y.status} ${y.headers.get('location')}`);

  const a = await iste(P1, '/sedir/', {});
  kapi('T4 girişsiz kök TABANLI giriş sayfasına yönlenir (kök yola DEĞİL)',
    a.status === 302 && a.headers.get('location') === '/sedir/giris', `→ ${a.headers.get('location')}`);

  const api = await iste(P1, '/sedir/api/durum');
  kapi('T5 girişsiz API 401 döner (yönlendirme değil)', api.status === 401, `→ ${api.status}`);

  // ── giriş ──
  const red = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: 'yanlis' } });
  kapi('T6 yanlış parola REDDEDİLİR', red.status === 401, `→ ${red.status}`);
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  kapi('T7 doğru parola KABUL (T6 tautoloji değil)', ok.status === 200, `→ ${ok.status}`);
  const sc = ok.headers.get('set-cookie') || '';
  kapi('T8 çerez YALNIZ kendi tabanında geçerli (Path=/sedir)', /Path=\/sedir(;|$)/.test(sc), `→ ${sc.slice(0, 80)}`);
  kapi('T9 çerez HttpOnly+Secure+SameSite korunur',
    /HttpOnly/.test(sc) && /Secure/.test(sc) && /SameSite=Strict/.test(sc), `→ ${sc.slice(0, 90)}`);

  const cerez = 'kapi=' + (sc.match(/kapi=([^;]+)/) || [])[1];
  // ── BUGÜN ucu (2.15.0): çıpa fikstürü TO_PROJE altında; bugün olan ajan listede, başka gün bugun_degil'de; girişsiz 401
  {
    const PRJ = join(T, 'proje'); mkdirSync(join(PRJ, '_agents/handoff'), { recursive: true });
    writeFileSync(join(PRJ, '_agents/handoff/gunluk-plan-cipa.basiret.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17\n\n- [ ] 1) tek madde gorev_01ABCDEFGHJKMNPQRSTVWXYZ\n- [x] G1) bitti → KAPANDI · not\n');
    writeFileSync(join(PRJ, '_agents/handoff/gunluk-plan-cipa.eski.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-01\n- [ ] 1) bayat\n');
    const PB = 18794; const pb = await kapiAc('/sedir', PB, { TO_PROJE: PRJ });
    const okb = await iste(PB, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
    const cb = 'kapi=' + ((okb.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
    const g0 = await iste(PB, '/sedir/api/bugun?tarih=2026-10-17');
    kapi('BG1 /api/bugun girişsiz 401 (kapı oturumu ister)', g0.status === 401, `→ ${g0.status}`);
    // eski kapıda (önce ölçümü) uç 404 döner: iddialar KIRMIZI düşer ama sınav ÇÖKMEZ (çökerse açılan kapılar kalır, sonraki koşum port alamaz)
    const g1 = await iste(PB, '/sedir/api/bugun?tarih=2026-10-17', { cerez: cb }); const j1 = await g1.json().catch(() => ({}));
    const aj = Array.isArray(j1.ajanlar) ? j1.ajanlar : [], bd = Array.isArray(j1.bugun_degil) ? j1.bugun_degil : [], tp = j1.toplam || {};
    kapi('BG2 bugünkü ajan listede: basiret, 2 madde (1 açık · 1 bitti), görev bağı', g1.status === 200 && aj.length === 1 && aj[0].ajan === 'basiret' && tp.acik === 1 && tp.bitti === 1 && (((aj[0].maddeler || [])[0] || {}).gorevler || [])[0] === 'gorev_01ABCDEFGHJKMNPQRSTVWXYZ', `→ ${g1.status} ` + JSON.stringify(j1).slice(0, 160));
    kapi('BG3 başka günün çıpası bugun_degil\'de (listede değil)', bd.length === 1 && bd[0].ajan === 'eski' && bd[0].tarih === '2026-10-01');
    kapi('BG4 kutu ve proje kimliği cevapta', j1.kutu === 'sinavkutu' && j1.proje === PRJ);
    const g2 = await iste(PB, '/sedir/api/bugun?tarih=17-10-2026', { cerez: cb });
    kapi('BG5 bozuk tarih 400', g2.status === 400, `→ ${g2.status}`);
    const g3 = await iste(PB, '/sedir/api/bugun?tarih=2026-99-99', { cerez: cb });
    kapi('BG5b biçimi doğru ama takvimde olmayan gün (2026-99-99) 400 — boş liste uydurulmaz (göz tur 1)', g3.status === 400, `→ ${g3.status}`);
    const g4 = await iste(PB, '/sedir/api/bugun?tarih=2026-02-29', { cerez: cb });
    kapi('BG5c 2026-02-29 yok (artık yıl değil) → 400', g4.status === 400, `→ ${g4.status}`);
    const g5 = await iste(PB, '/sedir/api/bugun?tarih=2026-10-17', { cerez: cb });
    kapi('BG5d bozuk tarihlerden SONRA kapı hâlâ cevap veriyor (istisna işleyiciyi düşürmedi)', g5.status === 200, `→ ${g5.status}`);
    pb.kill();
  }
  const sayfa = await iste(P1, '/sedir/', { cerez });
  const html = await sayfa.text();
  kapi('T10 sayfa kendi tabanını TAŞIR (sunucudan öğrenir, tahmin etmez)',
    html.includes('window.__TABAN="/sedir"'), `→ ${html.slice(0, 60)}`);
  kapi('T11 sayfadaki mutlak varlık yolları tabana taşınmış',
    html.includes('href="/sedir/manifest.webmanifest"') && !/href="\/manifest/.test(html));

  const man = await iste(P1, '/sedir/manifest.webmanifest', { cerez });
  const mj = await man.json();
  kapi('T12 PWA kimliği KUTU BAŞINA üretilir (kapsam tabanda, ad kutudan)',
    mj.scope === '/sedir/' && mj.start_url === '/sedir/' && /sinavkutu/i.test(mj.name), `→ ${JSON.stringify(mj).slice(0, 90)}`);
  kapi('T13 PWA ikon yolları da tabanlı', String(mj.icons?.[0]?.src || '').startsWith('/sedir/'), `→ ${mj.icons?.[0]?.src}`);

  const tt = await iste(P1, '/sedir/tty/', { cerez });
  const tj = await tt.json();
  kapi('T14 ttyd vekili tabanlı yolu OLDUĞU GİBİ iletir (ttyd -b ile eşleşsin)',
    tj.ttyd === true && tj.yol === '/sedir/tty/', `→ ${JSON.stringify(tj)}`);
}

console.log('\n── TK · KİŞİ TERMİNALİ (/tty-k → ttyd-kisi · A5-3) ──');
{
  // kendi kapısı (P6): birinci kapıdaki giriş sayacı (dakikada 6 deneme) öteki bölümlerin girişleriyle dolmasın
  const P6 = 18776; const kapiKisi = await kapiAc('/sedir', P6);
  const ok = await iste(P6, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const yukselt = (port, yol, cz) => new Promise((coz) => { const s = net.connect(port, '127.0.0.1', () => s.write(`GET ${yol} HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n${cz ? 'Cookie: ' + cz + '\r\n' : ''}\r\n`));
    let g = ''; s.on('data', (d) => { g += d; if (/\r\n\r\n[\s\S]*\}/.test(g) || /^HTTP\/1\.1 (401|502)/.test(g)) { s.destroy(); coz(g); } }); s.on('end', () => coz(g)); s.on('error', () => coz(g)); setTimeout(() => { s.destroy(); coz(g); }, 4000); });
  const g0 = await iste(P6, '/sedir/tty-k/');
  kapi('TK1 girişsiz kişi terminali 401 (kapı oturumu ister)', g0.status === 401, `→ ${g0.status}`);
  const a0 = ttyd.sayac || 0, k0 = ttydKisi.sayac || 0;
  const s1 = await iste(P6, '/sedir/tty-k/', { cerez }); const j1 = await s1.json();
  const s2 = await iste(P6, '/sedir/tty-k/token', { cerez }); const j2 = await s2.json();
  const s3 = await iste(P6, '/sedir/tty-k', { cerez }); const j3 = await s3.json();
  kapi('TK2 /tty-k/ kişi ttyd\'sine KÖKTEN gider (ttyd -b yok): / · /token · tabansız /tty-k → /', s1.status === 200 && j1.yol === '/' && j2.yol === '/token' && j3.yol === '/', `→ ${JSON.stringify([j1, j2, j3])}`);
  kapi('TK3 üç kişi isteğinin hiçbiri abc ttyd\'sine düşmedi (kişi soketi 3, abc 0)', (ttydKisi.sayac || 0) - k0 === 3 && (ttyd.sayac || 0) - a0 === 0, `→ kişi +${(ttydKisi.sayac || 0) - k0} · abc +${(ttyd.sayac || 0) - a0}`);
  const w1 = await yukselt(P6, '/sedir/tty-k/ws', cerez), w0 = await yukselt(P6, '/sedir/tty-k/ws', '');
  kapi('TK4 soket yükseltmesi /tty-k/ws kişi ttyd\'sine /ws olarak gider · girişsiz 401', /"yol":"\/ws"/.test(w1) && /^HTTP\/1\.1 401/.test(w0), `→ ${w1.slice(0, 60).replace(/\s+/g, ' ')} | ${w0.slice(0, 20)}`);
  const t1 = await iste(P6, '/sedir/tty/', { cerez }); const tj = await t1.json();
  kapi('TK5 /tty/ vekili DEĞİŞMEDİ: abc ttyd\'sine tabanlı yol', tj.yol === '/sedir/tty/' && (ttyd.sayac || 0) - a0 === 1, `→ ${JSON.stringify(tj)}`);
  // ttyd-kisi KURULU DEĞİL (soket yok): 502 ve abc ttyd'sine DÜŞMEZ
  const P5 = 18775; const kapiYok = await kapiAc('/sedir', P5, { KAPI_TTYD_KISI_SOKET: join(T, 'yok-ttyd.sock') });
  const ok5 = await iste(P5, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cz5 = 'kapi=' + ((ok5.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const a1 = ttyd.sayac || 0;
  const y1 = await iste(P5, '/sedir/tty-k/', { cerez: cz5 }); const yj = await y1.json().catch(() => ({}));
  const yw = await yukselt(P5, '/sedir/tty-k/ws', cz5);
  kapi('TK6 ttyd-kisi yokken sayfa ve soket 502 (abc ttyd\'sine DÜŞMEZ: abc sayacı aynı) · hata metni kurulumu söyler', y1.status === 502 && /kurulu değil/.test(String(yj.hata)) && /^HTTP\/1\.1 502/.test(yw) && (ttyd.sayac || 0) === a1, `→ ${y1.status} ${JSON.stringify(yj)} | ${yw.slice(0, 20)} | abc ${(ttyd.sayac || 0) - a1}`);
  const y2 = await iste(P5, '/sedir/tty/', { cerez: cz5 }); const y2j = await y2.json();
  kapi('TK7 aynı kapıda /tty/ (abc) çalışmaya devam eder — kişi soketinin yokluğu Sultan terminalini kapatmaz', y2.status === 200 && y2j.yol === '/sedir/tty/', `→ ${y2.status}`);
  kapiYok.kill(); kapiKisi.kill();
}

console.log('\n── Y · KOLTUKLAR (koltuk seçici) ──');
{
  const yok = await iste(P1, '/sedir/api/koltuklar');
  kapi('Y1 girişsiz koltuk listesi 401 (kutunun oturum adları açık değil)', yok.status === 401, `→ ${yok.status}`);
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const r = await iste(P1, '/sedir/api/koltuklar', { cerez });
  const j = await r.json();
  kapi('Y2 girişli liste 200 ve betiğin söylediği koltukları taşır',
    r.status === 200 && j.koltuklar?.map((k) => k.ad).join(',') === 'sinavkutu-ana,BASIRET,sinavkutu-kabuk', `→ ${JSON.stringify(j).slice(0, 160)}`);
  kapi('Y3 bozuk adlı satır SÜZÜLÜR (kapı betiğe körü körüne güvenmez)', !JSON.stringify(j).includes('kotu'));
  const b = j.koltuklar?.find((k) => k.ad === 'BASIRET') || {};
  kapi('Y4 Claude işareti ve son etkinlik taşınır', b.claude === true && b.son === 1760000100, `→ ${JSON.stringify(b)}`);
  kapi('Y5 ekran adresi TABANLI ve ?arg= ile, ad değil AD DIŞI kimlik taşır (2.24.0 · P4GT2W)', adr(b, 'BASIRET'), `→ ${b.ekran}`);
  kapi('Y6 ana koltuk işaretli', j.koltuklar?.[0]?.ana === true && b.ana === false && j.ana === 'sinavkutu-ana');
  const kbk = j.koltuklar?.find((k) => k.ad === 'sinavkutu-kabuk') || {};
  kapi('Y6b el kabuğu işaretli (yalnız <kutu>-kabuk; ana ve ajan değil)', kbk.kabuk === true && b.kabuk === false && j.koltuklar?.[0]?.kabuk === false && j.kabuk === 'sinavkutu-kabuk', `→ ${JSON.stringify(kbk)}`);
  const tt = await (await iste(P1, '/sedir/tty/?arg=BASIRET', { cerez })).json();
  kapi('Y7 ttyd vekili ?arg= sorgusunu OLDUĞU GİBİ iletir (koltuk ttyd\'ye ulaşır)', tt.yol === '/sedir/tty/?arg=BASIRET', `→ ${tt.yol}`);
  const kb = await kapiAc('/sedir', P3, { KAPI_KOLTUK_BETIK: KOLTUK_BOZUK });
  const ok3 = await iste(P3, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const c3 = 'kapi=' + ((ok3.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const rb = await iste(P3, '/sedir/api/koltuklar', { cerez: c3 });
  kapi('Y8 betik düşerse 500 "ölçülemedi" — boş liste ("hiç koltuk yok") BASILMAZ', rb.status === 500, `→ ${rb.status}`);
  // 2.2.0 · tür ve hâl betikten taşınır; eski 3 alanlı betikte alanlar YOKTUR (uydurulmaz); ana adı betiğe ortamdan gider
  const k5 = await kapiAc('/sedir', P4, { KAPI_KOLTUK_BETIK: KOLTUK_SAHTE5 });
  const ok5 = await iste(P4, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const c5 = 'kapi=' + ((ok5.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const j5 = await (await iste(P4, '/sedir/api/koltuklar', { cerez: c5 })).json();
  const b5 = j5.koltuklar?.find((k) => k.ad === 'BASIRET') || {}, cc5 = j5.koltuklar?.find((k) => k.ad === 'cc-1') || {};
  kapi('Y10 tür ve hâl taşınır (BASIRET ajan/soru · cc-1 diğer/bilinmiyor)', b5.tur === 'ajan' && b5.hal === 'soru' && cc5.tur === 'diger' && cc5.hal === 'bilinmiyor', `→ ${JSON.stringify(j5).slice(0, 200)}`);
  kapi('Y10b ana bayrağı kapıdan (betikten değil): sahte ana adını bilmez, kapı yine ana:true işaretler', j5.koltuklar?.find((k) => k.ad === 'sinavkutu-ana')?.ana === true, `→ ${JSON.stringify(j5.koltuklar?.map((k) => [k.ad, k.ana]))}`);
  kapi('Y10c eski 3 alanlı betikte tür/hâl alanı YOK (uydurulmaz)', !('tur' in b) && !('hal' in b));
  // Y10d (kart kapi-koltuk-onbellek): liste betiği yük altında 1,4-3,1 sn; önbellek betiği koşturmaz, yazma isteği eldekini atar, başarısız koşu saklanmaz
  const SAYAC = join(T, 'koltuk-sayac'); const KOLTUK_SAYAN = join(T, 'koltuk-sayan.sh');
  writeFileSync(KOLTUK_SAYAN, `#!/usr/bin/env bash\necho x >> ${JSON.stringify(SAYAC)}\n[ -f ${JSON.stringify(SAYAC + '.dur')} ] && exit 1\nprintf "sinavkutu-ana\\t1760000000\\t0\\n"\n`);
  const AC_SAHTE = join(T, 'koltuk-ac-sayan.sh'); writeFileSync(AC_SAHTE, `#!/usr/bin/env bash\n[ -f ${JSON.stringify(SAYAC + '.acma-dus')} ] && { echo olmadi; exit 1; }\necho acildi\n`);
  const PK = 18889, koc = await kapiAc('/sedir', PK, { KAPI_KOLTUK_BETIK: KOLTUK_SAYAN, KAPI_KOLTUK_AC_BETIK: AC_SAHTE, KAPI_KOLTUK_TAZE_MS: '60000', KAPI_KOLTUK_BAYAT_MS: '120000' });
  const say = () => { try { return readFileSync(SAYAC, 'utf8').trim().split('\n').length; } catch { return 0; } };
  const giris10 = async () => 'kapi=' + (((await iste(PK, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } })).headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const oku10 = async () => { const r = await iste(PK, '/sedir/api/koltuklar', { cerez: ck }); await r.text(); return r.status; };
  const ac10 = async () => { const r = await iste(PK, '/sedir/api/koltuk/BASIRET/ac', { cerez: ck, metot: 'POST', govde: {} }); await r.text(); await new Promise((c) => setTimeout(c, 100)); return r.status; };
  const ck = await giris10(); const once = say();
  const [ka, kb2] = await Promise.all([iste(PK, '/sedir/api/koltuklar', { cerez: ck }), iste(PK, '/sedir/api/koltuklar', { cerez: ck })]);
  const ja = await ka.json(); await kb2.text(); const ikiEs = say() - once;
  await oku10(); const ucuncu = say() - once;
  kapi('Y10d iki eşzamanlı ve bir sonraki istek TEK betik koşusuna iner · cevap yas_ms taşır', ka.status === 200 && ikiEs === 1 && ucuncu === 1 && typeof ja.yas_ms === 'number', `→ ${JSON.stringify({ ikiEs, ucuncu, yas: ja.yas_ms })}`);
  await giris10(); await new Promise((c) => setTimeout(c, 100)); await oku10(); const sonraGiris = say() - once;
  kapi('Y10e ilgisiz yazma isteği (giriş) önbelleği DÜŞÜRMEZ', sonraGiris === 1, `→ ${sonraGiris}`);
  writeFileSync(SAYAC + '.acma-dus', ''); const kBasarisiz = await ac10(); await oku10(); const sonraRed = say() - once;
  kapi('Y10e2 başarısız koltuk açma önbelleği DÜŞÜRMEZ', kBasarisiz === 502 && sonraRed === 1, `→ ${JSON.stringify({ kBasarisiz, sonraRed })}`);
  rmSync(SAYAC + '.acma-dus'); const kBasarili = await ac10(); await oku10(); const sonraAc = say() - once;
  kapi('Y10e3 başarılı koltuk açma önbelleği düşürür: sonraki okuma betiği yeniden koşar', kBasarili === 200 && sonraAc === 2, `→ ${JSON.stringify({ kBasarili, sonraAc })}`);
  writeFileSync(SAYAC + '.dur', ''); await ac10(); const rd = await oku10();
  kapi('Y10f betik düşünce önbellekteki eski liste hatayı gizlemez: 500', rd === 500, `→ ${rd}`);
  koc.kill();
  k5.kill();
  // Kullanıcı yüzü (bağımsız göz, tur 1): seçici sayfada ve betikte var, listeyi aynı uçtan çeker, tam terminali ?arg= ile açar.
  const sayfa = await (await iste(P1, '/sedir/', { cerez })).text();
  const js = await (await iste(P1, '/sedir/uygulama.js', { cerez })).text();
  kapi('Y9 telefon ekranı koltuk seçici TAŞIR (başlıkta seçim kutusu)', sayfa.includes('id="koltuk"'));
  kapi('Y10 seçici listeyi kutunun /api/koltuklar ucundan çeker ve tam terminali ?arg= ile açar',
    js.includes("/api/koltuklar") && js.includes("'?arg='"));
  kb.kill();
}

console.log('\n── K · KÖK DAVRANIŞI (taban boş — geriye dönük) ──');
{
  const g = await iste(P2, '/giris');
  kapi('K1 taban boşken giriş kök yolda açılır', g.status === 200, `→ ${g.status}`);
  const a = await iste(P2, '/');
  kapi('K2 girişsiz kök → /giris (eski davranış BAYT BAYT aynı)',
    a.status === 302 && a.headers.get('location') === '/giris', `→ ${a.headers.get('location')}`);
  const ok = await iste(P2, '/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const sc = ok.headers.get('set-cookie') || '';
  kapi('K3 taban boşken çerez Path=/ kalır', /Path=\/(;|$)/.test(sc), `→ ${sc.slice(0, 60)}`);
  const cerez = 'kapi=' + (sc.match(/kapi=([^;]+)/) || [])[1];
  const h = await (await iste(P2, '/', { cerez })).text();
  kapi('K4 taban boşken sayfa yolları DEĞİŞTİRİLMEZ', h.includes('href="/manifest.webmanifest"'));
  const tt = await (await iste(P2, '/tty/', { cerez })).json();
  kapi('K5 taban boşken ttyd yolu kök kalır', tt.yol === '/tty/', `→ ${tt.yol}`);
}

console.log('\n── M · MAHREMİYET (iki kutu aynı kaynağı paylaşıyor) ──');
{
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const baska = await iste(P1, '/akar/api/durum', { cerez });
  kapi('M1 geçerli oturumla BAŞKA kutunun yoluna gidilemez (404)', baska.status === 404, `→ ${baska.status}`);
  const kendi = await iste(P1, '/sedir/api/durum', { cerez });
  kapi('M2 ... kendi yolu çalışıyor (M1 "her şey 404" değil)', kendi.status === 200, `→ ${kendi.status}`);
}

console.log('\n── W · WEBSOCKET (tam terminal bağlantısı) ──');
{
  // 🔴 BU BÖLÜM BİR MUTASYON TURUNDA DOĞDU: upgrade kapısındaki taban denetimini
  //    öldürdüğümde sınav YEŞİL kaldı — yani WS yolu hiç ölçülmüyordu. Tam terminal
  //    bağlantısı tarayıcıda normal isteklerden AYRI bir yoldan geçer; ölçülmeyen o
  //    yol, kapının en geniş yetkili ucudur (doğrudan kabuğa açılır).
  const ok = await iste(P1, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cerez = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const yukselt = (yol, kurabiye) => new Promise((coz) => {
    const c = net.connect(P1, '127.0.0.1', () => {
      c.write(`GET ${yol} HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n`
        + `Sec-WebSocket-Key: ${Buffer.from('0123456789abcdef').toString('base64')}\r\nSec-WebSocket-Version: 13\r\n`
        + (kurabiye ? `Cookie: ${kurabiye}\r\n` : '') + '\r\n');
    });
    let b = ''; const bit = () => { c.destroy(); coz(b); };
    c.on('data', (d) => { b += d; if (b.includes('\r\n\r\n')) bit(); });
    c.on('error', bit); setTimeout(bit, 3000);
  });
  const w1 = await yukselt('/sedir/tty/ws', cerez);
  kapi('W1 tabanlı WS yolu ttyd\'ye ULAŞIR', /ttyd/.test(w1) || /200 OK/.test(w1), `→ ${w1.slice(0, 40)}`);
  const w2 = await yukselt('/tty/ws', cerez);
  kapi('W2 taban DIŞI WS yolu REDDEDİLİR (401) — geçerli oturumla bile', /401/.test(w2), `→ ${w2.slice(0, 40)}`);
  const w3 = await yukselt('/sedir/tty/ws', '');
  kapi('W3 çerezsiz WS REDDEDİLİR (401)', /401/.test(w3), `→ ${w3.slice(0, 40)}`);
  const w4 = await yukselt('/sedir/api/ekran', cerez);
  kapi('W4 tty dışı yola upgrade REDDEDİLİR', /401/.test(w4), `→ ${w4.slice(0, 40)}`);
}

// ── B · TARAYICI AKIŞI (bağımsız göz, CİDDİ) ──────────────────────────────────
// 🔴 NİÇİN: sunucu /sedir/giris'e 200 döndürüyordu ve sınav yeşildi — ama sayfanın
//    KENDİSİ tabanı bilmiyordu: parola köke gidiyor, varlıklar kökten isteniyor,
//    başarılı girişten sonra kullanıcı kökün / adresine atılıyordu. Yani ölçülen
//    şey "sunucu cevap verdi mi" idi; kırılan şey KULLANICININ YOLUYDU.
{
  const g = await iste(P1, '/sedir/giris');
  const h = await g.text();
  kapi('B1 giriş sayfası tabanı TAŞIR (window.__TABAN gömülü)',
       /window\.__TABAN\s*=\s*"\/sedir"/.test(h), `→ ${/__TABAN/.test(h) ? 'var ama değer yanlış' : 'HİÇ YOK'}`);
  const kokMutlak = (h.match(/(?:href|src)="\/(?!\/)[^"]*/g) || []).filter((x) => !x.includes('/sedir/'));
  kapi('B2 giriş sayfasında KÖK-mutlak varlık yolu kalmadı',
       kokMutlak.length === 0, `→ ${kokMutlak.slice(0, 2).join(' ')}`);
  kapi('B3 başarılı girişten sonra taban altına dönülür (köke DEĞİL)',
       /location\.replace\(\(window\.__TABAN\|\|''\)\s*\+\s*'\/'\)/.test(h),
       `→ ${/location\.replace\('\/'\)/.test(h) ? "hâlâ köke atıyor" : 'desen bulunamadı'}`);
  const gk = await iste(P2, '/giris'); const hk = await gk.text();
  kapi('B4 tabansız kutuda sayfa yine çalışır (B1 tautoloji değil)',
       gk.status === 200 && /window\.__TABAN\s*=\s*""/.test(hk), `→ ${gk.status}`);
}

// ── P · PAROLA VEKİLLİĞİ (bağımsız göz tur 2, CİDDİ) ─────────────────────────
// 🔴 NİÇİN: kutunun kendi anahtarı yoksa kod SEDİR'inkine düşüyordu. AKAR kutusunda
//    AKAR__… yokken SEDİR__… ortamda duruyorsa kapı DURMAK yerine YANLIŞ SIRLA
//    açılırdı. Fail-closed sözü tam burada bozuluyordu.
{
  const cik = (ortam) => new Promise((coz) => {
    const c = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
      env: { ...process.env, KAPI_TABAN: '/akar', TO_KUTU: 'akar', KAPI_PORT: '18779',
             KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), AKAR__TERMINAL_SIFRE: '', ...ortam },
      stdio: ['ignore', 'ignore', 'pipe'] });
    let e = ''; c.stderr.on('data', (d) => { e += d; });
    c.on('exit', (k) => coz({ kod: k, hata: e })); setTimeout(() => { c.kill(); coz({ kod: null, hata: e }); }, 4000);
  });
  const baskasi = await cik({ SEDIR__TERMINAL_SIFRE: 'baskasinin-parolasi-9999' });
  kapi('P1 kutunun kendi parolası yokken BAŞKASININKİYLE açılmaz (fail-closed)',
       baskasi.kod === 2 && /parola ortamda yok/.test(baskasi.hata), `→ çıkış ${baskasi.kod}`);
  const kendi = await cik({ AKAR__TERMINAL_SIFRE: 'akarin-kendi-parolasi-1234' });
  kapi('P2 kendi parolası varken AÇILIR (P1 tautoloji değil)',
       kendi.kod === null, `→ çıkış ${kendi.kod}`);
}

// ── F · YAZI TİPİ YOLU ────────────────────────────────────────────────────────
// Biçem dosyası taban enjeksiyonundan GEÇMEZ (yalnız html yazılır); kök-mutlak
// yazı tipi adresi /sedir/ altında merkez köküne kaçardı.
{
  const c = await iste(P1, '/sedir/zanaat.css'); const g = await c.text();
  kapi('F1 biçem dosyasında kök-mutlak yazı tipi adresi yok',
       !/url\(\s*\//.test(g), `→ ${(g.match(/url\([^)]*\)/g) || []).slice(0, 2).join(' ')}`);
  const f = await iste(P1, '/sedir/archivo-400.ttf');
  kapi('F2 yazı tipi taban altından İNİYOR (F1 tautoloji değil)', f.status === 200, `→ ${f.status}`);
}

// ── C · ÖNBELLEK SINIRI (bağımsız göz tur 3) ─────────────────────────────────
// 🔴 NİÇİN: eski temizlik süzgeci 'kabuk'+taban ile ÖNEK eşliyordu. Kısa adlı bir
//    kutu (/sed) uzun adlının kabını (kabuk/sedir-v3) silebilirdi — başka kutunun
//    çevrimdışı kabuğunu sessizce bozmak. Sınav GERÇEK sw.js'i sahte bir ortamda koşar.
{
  const kaynak = await (await iste(P1, '/sedir/sw.js')).text();
  const calistir = async (yol, kaplar) => {
    const silinen = [];
    const dinleyici = {};
    const sahte = {
      location: { pathname: yol + '/sw.js', origin: 'http://x' },
      addEventListener: (ad, f) => { dinleyici[ad] = f; },
      skipWaiting() {}, clients: { claim() {} },
    };
    const caches = {
      open: async () => ({ addAll: async () => {}, put: async () => {} }),
      keys: async () => kaplar,
      delete: async (x) => { silinen.push(x); return true; },
      match: async () => undefined,
    };
    const fn = new Function('self', 'caches', 'location', 'fetch', 'Response', kaynak);
    fn(sahte, caches, sahte.location, async () => ({ ok: false }), function () {});
    await new Promise((c) => dinleyici.activate({ waitUntil: (p) => p.then(c).catch(c) }));
    return silinen;
  };
  const kaplar = ['kabuk/sedir-v3', 'kabuk/sedir-v2', 'kabuk/sed-v1', 'kabuk-kok-v3'];
  const kisa = await calistir('/sed', kaplar);
  kapi('C1 kısa adlı kutu UZUN adlının önbelleğini silmez',
       !kisa.some((x) => x.startsWith('kabuk/sedir')), `→ sildi: ${kisa.join(' ')}`);
  kapi('C2 ... ama kendi eski kabını siler (C1 tautoloji değil)',
       kisa.includes('kabuk/sed-v1'), `→ sildi: ${kisa.join(' ')}`);
  const uzun = await calistir('/sedir', kaplar);
  kapi('C3 kutu kendi eski sürümünü temizler, komşununkine dokunmaz',
       uzun.includes('kabuk/sedir-v2') && !uzun.includes('kabuk/sed-v1') && !uzun.includes('kabuk-kok-v3'),
       `→ sildi: ${uzun.join(' ')}`);
}

// ── A · GÖRÜNEN AD DA KUTUDAN TÜRER (bağımsız göz tur 4) ─────────────────────
// 🔴 NİÇİN: sayfalarda "Sedir" sabit yazılıydı. AKAR kutusunu açan kişi tepede
//    "Sedir" görürdü; "hiçbir kutu adı gömülü değil" sözü arayüzde bozuluyordu.
{
  const g = await (await iste(P1, '/sedir/giris')).text();
  kapi('A1 giriş ekranı KUTUNUN adını gösterir', /<h1>Sinavkutu<\/h1>/.test(g),
       `→ ${(g.match(/<h1>[^<]*<\/h1>/) || ['yok'])[0]}`);
  kapi('A2 sayfada doldurulmamış yuva kalmadı', !/\{\{KUTU\}\}/.test(g), '→ yuva açık kaldı');
  kapi('A3 kaynakta sabit kutu adı kalmadı',
       !/Sedir/.test(await (await iste(P1, '/sedir/giris')).text()), '→ hâlâ gömülü ad var');

  // Farklı kutu → farklı ad (A1 tautoloji değil)
  const p3 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
    env: { ...process.env, KAPI_PORT: '18781', KAPI_TABAN: '/akar', TO_KUTU: 'akar',
           KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, AKAR__TERMINAL_SIFRE: SIFRE },
    stdio: ['ignore', 'ignore', 'ignore'] });
  let ak = '';
  for (let i = 0; i < 50; i++) {
    await new Promise((r) => setTimeout(r, 100));
    try { const r = await fetch('http://127.0.0.1:18781/akar/giris'); if (r.status === 200) { ak = await r.text(); break; } } catch {}
  }
  kapi('A4 BAŞKA kutu KENDİ adını gösterir (A1 tautoloji değil)',
       /<h1>Akar<\/h1>/.test(ak) && !/Sinavkutu/.test(ak),
       `→ ${(ak.match(/<h1>[^<]*<\/h1>/) || ['açılmadı'])[0]}`);
  p3.kill();
}

// ── K · PANO KÖPRÜSÜ (2.3.0 · Sultan 12 Eki: Cmd+C kopyalamıyor, resim Cmd+V yapıştırılamıyor) ─────
// 🔴 NİÇİN: ttyd'nin HTML'ine genel/pano.js gömülür. Ölçüt içerik türüdür (yol tahmini değil); JSON, WebSocket,
//    sıkıştırılmış ya da 200-dışı cevap OLDUĞU GİBİ akar. Her iddianın ateşleyen ve ateşlemeyen yüzü birlikte.
{
  const giris = async (port, taban) => { const ok = await iste(port, `${taban}/giris`, { metot: 'POST', govde: { parola: SIFRE } });
    return 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
  const cerez = await giris(P1, '/sedir');
  const r1 = await iste(P1, '/sedir/tty/?html=1', { cerez }); const h1 = await r1.text();
  kapi('PN1 ttyd HTML sayfasına pano köprüsü gömülür (data-kapi-pano işareti)', r1.status === 200 && h1.includes("setAttribute('data-kapi-pano'"), `→ ${r1.status} · ${h1.slice(0, 60)}`);
  kapi('PN2 köprü TABANI taşır (window.__TABAN="/sedir") ve /api/resim\'e tabanla gider', /window\.__TABAN="\/sedir"/.test(h1) && h1.includes("TABAN + '/api/resim'"), '→ taban gömülü değil');
  kapi('PN3 ekleme </body> ÖNÜNE girer, sayfa bütün (…</body></html> ile biter)', h1.trimEnd().endsWith('</body></html>') && h1.indexOf('data-kapi-pano') < h1.indexOf('</body>'), `→ …${h1.slice(-40)}`);
  // fetch kendiliğinden gzip ister ve açar → başlık/gövde karşılaştırması DÜZ istekle yapılır
  const r1d = await fetch(`http://127.0.0.1:${P1}/sedir/tty/?html=1`, { headers: { cookie: cerez, 'accept-encoding': 'identity' } }); const h1d = Buffer.from(await r1d.arrayBuffer());
  kapi('PN4 content-length yeniden hesaplanır (düz istekte gövde bayt sayısı = başlık, gzip yok)', !r1d.headers.get('content-encoding') && +r1d.headers.get('content-length') === h1d.length && h1d.includes('data-kapi-pano'), `→ ${r1d.headers.get('content-length')} ≠ ${h1d.length} ce=${r1d.headers.get('content-encoding')}`);
  kapi('PN5 ttyd\'den DÜZ gövde istenir (accept-encoding sıyrılır)', r1.headers.get('x-ae') === '0', `→ x-ae=${r1.headers.get('x-ae')}`);
  kapi('PN6 ttyd\'nin kendi betiği yerinde (köprü sayfayı ezmez)', h1.includes('window.sahte=1') && h1.includes('id="ttyd"'), '→ orijinal gövde kayıp');
  // gzip: istemci isterse EKLENMİŞ gövde sıkıştırılır
  const r2 = await fetch(`http://127.0.0.1:${P1}/sedir/tty/?html=1`, { headers: { cookie: cerez, 'accept-encoding': 'gzip' } });
  const h2 = await r2.text();   // fetch gövdeyi çözer; başlık korunur mu bakılır
  kapi('PN7 istemci gzip istediyse cevap gzip\'lidir ve köprü içindedir', (r2.headers.get('content-encoding') || '') === 'gzip' && h2.includes('data-kapi-pano'), `→ ce=${r2.headers.get('content-encoding')}`);
  // </body> yoksa sona eklenir
  const h3 = await (await iste(P1, '/sedir/tty/?html=2', { cerez })).text();
  kapi('PN8 </body> olmayan sayfada köprü SONA eklenir (sayfa yine açılır)', h3.includes('data-kapi-pano') && h3.indexOf('data-kapi-pano') > h3.indexOf('window.sahte=1'), '→ eklenmedi');
  // sıkıştırılmış ttyd cevabına dokunulmaz
  const r4 = await iste(P1, '/sedir/tty/?html=3', { cerez }); const b4 = Buffer.from(await r4.arrayBuffer());
  let acik4 = ''; try { acik4 = zlib.gunzipSync(b4).toString('utf8'); } catch { acik4 = ''; }
  // fetch gzip'i kendisi açmış olabilir (accept-encoding yollanmadı ama undici bazen çözer) → iki hâl de kabul: gövde sağlam ve köprüsüz
  const b4Sag = acik4 ? acik4.includes('id="ttyd"') : b4.toString('utf8').includes('id="ttyd"');
  const b4Kop = (acik4 || b4.toString('utf8')).includes('data-kapi-pano');
  kapi('PN9 ttyd SIKIŞTIRILMIŞ cevap verirse gövde bozulmaz ve köprü EKLENMEZ', b4Sag && !b4Kop, `→ sağlam=${b4Sag} köprü=${b4Kop}`);
  // JSON / tty dışı dokunulmaz (T14 zaten JSON'u ayrıştırıyor; burada açıkça)
  const h5 = await (await iste(P1, '/sedir/tty/', { cerez })).text();
  kapi('PN10 HTML olmayan ttyd cevabına (json) köprü girmez', !h5.includes('data-kapi-pano') && JSON.parse(h5).ttyd === true, '→ json bozuldu ya da köprü girdi');
  // tabansız kutu
  const ck = await giris(P2, ''); const h6 = await (await iste(P2, '/tty/?html=1', { cerez: ck })).text();
  kapi('PN11 tabansız kutuda köprü __TABAN="" ile gömülür (K2 tautoloji değil)', /window\.__TABAN=""/.test(h6) && h6.includes('data-kapi-pano'), '→ yok');
  // kapatma anahtarı: KAPI_PANO=0 → vekil eski hâli (ekleme yok, accept-encoding geçer)
  const p0 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
    env: { ...process.env, KAPI_PORT: '18783', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', KAPI_PANO: '0',
           KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok') }, stdio: 'ignore' });
  let h7 = '', ae7 = '';
  for (let i = 0; i < 50; i++) {
    await new Promise((r) => setTimeout(r, 100));
    try { const r = await fetch('http://127.0.0.1:18783/sedir/tty/?html=1', { headers: { cookie: cerez, 'accept-encoding': 'gzip' } });
      if (r.status === 200) { h7 = await r.text(); ae7 = r.headers.get('x-ae') || ''; break; } } catch {}
  }
  kapi('PN12 KAPI_PANO=0 → köprü gömülmez, accept-encoding ttyd\'ye geçer (eski davranış bayt bayt)', h7.includes('id="ttyd"') && !h7.includes('data-kapi-pano') && ae7 === '1', `→ köprü=${h7.includes('data-kapi-pano')} x-ae=${ae7}`);
  p0.kill();
  // kaynak dosya kuralları: satır içi gömülür → kapanış script etiketi geçemez; replace değiştiricisi fonksiyon olmalı
  const kaynak = readFileSync(join(KOK, 'genel', 'pano.js'), 'utf8');
  kapi('PN13 pano.js kapanış script etiketi içermez (satır içi gömülüyor)', !/<\/script/i.test(kaynak), '→ gömülünce sayfa yarıda kesilir');
  const sun = readFileSync(join(KOK, 'sunucu.mjs'), 'utf8');
  kapi('PN14 ekleme replace\'i FONKSİYONLA yapılır (pano.js içindeki $ dizileri yorumlanmasın)', /h\.replace\('<\/body>', \(\) => ek \+ '<\/body>'\)/.test(sun), '→ düz dize değiştirici');
}

// ── KA · KOLTUK AÇ (2.4.0 · dilim 5/5) — kapı betiğe sorar, kendisi karar vermez; rc → HTTP eşlemesi ─────
{
  const giris = async (port, taban) => { const ok = await iste(port, `${taban}/giris`, { metot: 'POST', govde: { parola: SIFRE } });
    return 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
  // sahte koltuk-ac.sh: durum → JSON; ac → ada göre rc (canli:0 · merdiven:3 · kayitsiz:4 · bozuk:1); çağrıyı deftere yazar
  const KA = join(T, 'koltuk-ac-sahte.sh'); const DEFTER = join(T, 'ka-defter');
  writeFileSync(KA, '#!/usr/bin/env bash\necho "$*" >> ' + JSON.stringify(DEFTER) + '\n'
    + 'if [ "$1" = durum ]; then printf \'{"ad":"%s","durum":"yok","tmux":false,"claude":false,"hal":"","son":0,"rol":"ROLX","resume":true,"yol":"ekip-ac","ana":false}\\n\' "$2"; exit 0; fi\n'
    + 'case "$2" in canli) echo "açıldı: $2"; exit 0;; merdiven) echo "K0 yetmedi; onarım merdiveni başlatıldı"; exit 3;; kayitsiz) echo "açılamadı: kayıtlı bir koltuk değil" >&2; exit 4;; *) echo "açılamadı: rc=1" >&2; exit 1;; esac\n');
  const p5 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
    env: { ...process.env, KAPI_PORT: '18785', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', KAPI_KOLTUK_AC_BETIK: KA,
           KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: KOLTUK_SAHTE5 }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18785/sedir/giris')).status === 200) break; } catch {} }
  const cerez = await giris(18785, '/sedir');
  const d = await iste(18785, '/sedir/koltuk/BASIRET', { cerez });
  kapi('KA0 /koltuk/<ad> api altında değil → 404 (yol disiplini)', d.status === 404);
  const r1 = await iste(18785, '/sedir/api/koltuk/BASIRET', { cerez }); const j1 = await r1.json();
  kapi('KA1 GET /api/koltuk/<ad> betiğin durum JSON\'unu olduğu gibi taşır (durum·yol·rol·resume)', r1.status === 200 && j1.durum === 'yok' && j1.yol === 'ekip-ac' && j1.rol === 'ROLX' && j1.resume === true, `→ ${JSON.stringify(j1)}`);
  kapi('KA2 betik "durum <ad>" ile çağrıldı', readFileSync(DEFTER, 'utf8').trim().split('\n').pop() === 'durum BASIRET');
  const g = await iste(18785, '/sedir/api/koltuk/BASIRET', { cerez: '' });
  kapi('KA3 girişsiz → 401', g.status === 401);
  const a1 = await iste(18785, '/sedir/api/koltuk/canli/ac', { cerez, metot: 'POST', govde: {} }); const ja1 = await a1.json();
  kapi('KA4 POST …/ac → betik "ac <ad>" (eski yok) · rc0 → 200 tamam, mesaj betikten', a1.status === 200 && ja1.tamam === true && /açıldı/.test(ja1.mesaj) && readFileSync(DEFTER, 'utf8').trim().split('\n').pop() === 'ac canli', `→ ${a1.status} ${JSON.stringify(ja1)}`);
  await iste(18785, '/sedir/api/koltuk/canli/ac', { cerez, metot: 'POST', govde: { eski: true } });
  kapi('KA5 {eski:true} → betiğe --eski geçer (eski sohbete dönüş)', readFileSync(DEFTER, 'utf8').trim().split('\n').pop() === 'ac canli --eski');
  const a3 = await iste(18785, '/sedir/api/koltuk/merdiven/ac', { cerez, metot: 'POST', govde: {} }); const ja3 = await a3.json();
  kapi('KA6 rc3 (merdiven başladı) → 202 tamam:true', a3.status === 202 && ja3.tamam === true && ja3.rc === 3, `→ ${a3.status}`);
  const a4 = await iste(18785, '/sedir/api/koltuk/kayitsiz/ac', { cerez, metot: 'POST', govde: {} }); const ja4 = await a4.json();
  kapi('KA7 rc4 (kayıtsız koltuk) → 409 tamam:false, sebep mesajda', a4.status === 409 && ja4.tamam === false && /kayıtlı bir koltuk değil/.test(ja4.mesaj), `→ ${a4.status} ${ja4.mesaj}`);
  const a5 = await iste(18785, '/sedir/api/koltuk/bozuk/ac', { cerez, metot: 'POST', govde: {} });
  kapi('KA8 rc1 (açılamadı) → 502', a5.status === 502);
  const a6 = await fetch('http://127.0.0.1:18785/sedir/api/koltuk/canli/ac', { method: 'POST', headers: { cookie: cerez, 'content-type': 'application/json' }, body: '{}' });
  kapi('KA9 x-kapi başlığı olmadan POST → 403 (CSRF kalkanı korunur)', a6.status === 403);
  const a7 = await iste(18785, '/sedir/api/koltuk/kotu%3Aad/ac', { cerez, metot: 'POST', govde: {} });
  kapi('KA10 bozuk ad (:) yola GİRMEZ → 404 (betik çağrılmaz)', a7.status === 404 && !/kotu/.test(readFileSync(DEFTER, 'utf8')));
  p5.kill();
  // takılı durumu + zaman aşımı (yedek göz tur 2): sahte betik 'takili' basar; 'yavas' koltuğu açma süresini aşar → 504 (502 'açılamadı' DEĞİL)
  const KA3 = join(T, 'koltuk-ac-sahte3.sh');
  writeFileSync(KA3, '#!/usr/bin/env bash\necho "$*" >> ' + JSON.stringify(join(T, 'ka3-defter')) + '\n[ "$1" = ac ] && [ "$2" = takili ] && [ "$3" != --zorla ] && { echo "takılı görünüyor: --zorla"; exit 5; }\nif [ "$1" = durum ]; then printf \'{"ad":"%s","durum":"takili","tmux":true,"claude":true,"hal":"calisiyor","son":1700000000,"rol":"ROLX","resume":true,"yol":"ekip-ac","ana":false}\\n\' "$2"; exit 0; fi\n[ "$2" = yavas ] && sleep 3\necho "açıldı: $2"; exit 0\n');
  const p7 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18789', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', KAPI_KOLTUK_AC_BETIK: KA3, KAPI_AC_SURE_MS: '500',
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: KOLTUK_SAHTE5 }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18789/sedir/giris')).status === 200) break; } catch {} }
  const c7 = await giris(18789, '/sedir');
  const t1 = await (await iste(18789, '/sedir/api/koltuk/BASIRET', { cerez: c7 })).json();
  kapi('KA11 üçüncü hâl "takili" kapıdan olduğu gibi geçer (son epoch dolu)', t1.durum === 'takili' && t1.son === 1700000000, `→ ${JSON.stringify(t1)}`);
  const t2 = await iste(18789, '/sedir/api/koltuk/yavas/ac', { cerez: c7, metot: 'POST', govde: {} }); const jt2 = await t2.json();
  kapi('KA12 açma süreyi aşarsa 504 + "arkada doğmuş olabilir" (502 açılamadı DEĞİL)', t2.status === 504 && jt2.rc === 124 && /arkada doğmuş/.test(jt2.mesaj), `→ ${t2.status} ${jt2.mesaj}`);
  const t3 = await iste(18789, '/sedir/api/koltuk/hizli/ac', { cerez: c7, metot: 'POST', govde: {} });
  kapi('KA13 süre içinde biten açma 200 (KA12 tautoloji değil)', t3.status === 200);
  const t4 = await iste(18789, '/sedir/api/koltuk/takili/ac', { cerez: c7, metot: 'POST', govde: {} }); const jt4 = await t4.json();
  kapi('KA14 takılı/ölçülemeyen koltuk zorlasız → rc5 → 428 tamam:false (dokunulmadı)', t4.status === 428 && jt4.tamam === false && jt4.rc === 5, `→ ${t4.status} ${JSON.stringify(jt4)}`);
  await iste(18789, '/sedir/api/koltuk/takili/ac', { cerez: c7, metot: 'POST', govde: { zorla: true } });
  kapi('KA15 {zorla:true} → betiğe --zorla geçer', /ac takili --zorla/.test(readFileSync(join(T, 'ka3-defter'), 'utf8')));
  p7.kill();
}

// ── SL · adında '/' olan koltuk (dilim 5/7): listeden DÜŞMEZ, adres encodeURIComponent, /api/koltuk yolu çözülür ──
{
  const giris = async (port, taban) => { const ok = await iste(port, `${taban}/giris`, { metot: 'POST', govde: { parola: SIFRE } });
    return 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
  const KA2 = join(T, 'ka2.sh'); const DEF2 = join(T, 'ka2-defter');
  writeFileSync(KA2, '#!/usr/bin/env bash\necho "$*" >> ' + JSON.stringify(DEF2) + '\nprintf \'{"ad":"%s","durum":"yok","tmux":false,"claude":false,"hal":"","son":0,"rol":"","resume":false,"yol":"yok","ana":false}\\n\' "$2"\n');
  const p6 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18787', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu',
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: KOLTUK_SAHTE5, KAPI_KOLTUK_AC_BETIK: KA2 }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18787/sedir/giris')).status === 200) break; } catch {} }
  const cerez = await giris(18787, '/sedir');
  const j = await (await iste(18787, '/sedir/api/koltuklar', { cerez })).json();
  const k = (j.koltuklar || []).find((x) => x.ad === '2026/85');
  kapi('SL1 "/" içeren koltuk listede (eski süzgeç düşürüyordu)', !!k, `→ ${(j.koltuklar || []).map((x) => x.ad).join(',')}`);
  kapi('SL2 ekran adresi "2026/85" adını (kodlu da) TAŞIMAZ, kimlik taşır', adr(k, '2026/85'), `→ ${k && k.ekran}`);
  const r = await iste(18787, '/sedir/api/koltuk/2026%2F85', { cerez }); const jr = await r.json();
  kapi('SL3 /api/koltuk/<kodlu ad> → yol çözülür, betiğe "durum 2026/85" gider', r.status === 200 && jr.ad === '2026/85' && readFileSync(DEF2, 'utf8').trim() === 'durum 2026/85', `→ ${r.status} ${JSON.stringify(jr)}`);
  const r2 = await iste(18787, '/sedir/api/koltuk/a%20b', { cerez });
  kapi('SL4 arada boşluklu ad yola girer → betiğe "durum a b" (tmux izin verir — bağımsız göz tur 1)', r2.status === 200 && /^durum a b$/m.test(readFileSync(DEF2, 'utf8')), `→ ${r2.status}`);
  const uzun = 'u'.repeat(195) + '/2026';   // 200 karakter, kodlu hâli 202 → eski yol deseni 404 veriyordu
  const r5 = await iste(18787, '/sedir/api/koltuk/' + encodeURIComponent(uzun), { cerez });
  kapi('SL5 200 karakterlik "/"lı ad: kodlu parça 200\'ü aşsa da tekil uç ÇÖZÜMDEN SONRA aynı kuralla sınar → 200', r5.status === 200 && readFileSync(DEF2, 'utf8').includes('durum ' + uzun), `→ ${r5.status}`);
  const r6 = await iste(18787, '/sedir/api/koltuk/' + encodeURIComponent('u'.repeat(201)), { cerez });
  kapi('SL6 201 karakter → 404 (sınır çözülmüş ada uygulanır)', r6.status === 404, `→ ${r6.status}`);
  const e200 = '😀'.repeat(200);   // kodlu 2400 karakter — kuralın kabul ettiği EN UZUN kodlu ad
  const r7 = await iste(18787, '/sedir/api/koltuk/' + encodeURIComponent(e200), { cerez });
  kapi('SL7 200 emojilik ad (kodlu 2400) tekil uca girer → 200; 201 emoji → 404', r7.status === 200 && readFileSync(DEF2, 'utf8').includes('durum ' + e200)
    && (await iste(18787, '/sedir/api/koltuk/' + encodeURIComponent('😀'.repeat(201)), { cerez })).status === 404, `→ ${r7.status}`);
  p6.kill();
}

// ── KD · /api/kadro (2.8.0): kayıt (TO_PROJE/_agents/handoff/aile-registry.yaml) ⟂ 6 sütunlu koltuk listesi ──
{
  const giris = async (port, taban) => { const ok = await iste(port, `${taban}/giris`, { metot: 'POST', govde: { parola: SIFRE } });
    return 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
  const PROJE = join(T, 'proje'); mkdirSync(join(PROJE, '_agents/handoff'), { recursive: true });
  writeFileSync(join(PROJE, '_agents/handoff/aile-registry.yaml'), 'uyeler:\n  - id: BASIRET\n    tmux: "BASIRET:0"\n    rol: "gözcü"\n    hal: calisiyor\n  - id: KALFA\n    tmux: "kalfa:0"\n    rol: "kalfa"\n    amir: BASIRET\n  - id: MIMAR\n    tmux: "mimar:0"\n    hal: emekli\n');
  const K6 = join(T, 'koltuk-sahte6.sh');
  writeFileSync(K6, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\n'
    + 'printf "sinavkutu-ana\\t1760000000\\t0\\tdiger\\tbilinmiyor\\t\\nBASIRET\\t1760000100\\t1\\tajan\\tdis-olay\\tCI bekleniyor\\nkalfa\\t5\\t0\\tajan\\tbilinmiyor\\t\\n2026/85\\t7\\t1\\tajan\\tgirdi\\t\\n"\n');
  const p8 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18791', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: PROJE,
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: K6, TO_ANA_TMUX: 'sinavkutu-ana' }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18791/sedir/giris')).status === 200) break; } catch {} }
  kapi('KD0 girişsiz /api/kadro 401', (await iste(18791, '/sedir/api/kadro')).status === 401);
  const cerez = await giris(18791, '/sedir');
  const r = await iste(18791, '/sedir/api/kadro', { cerez }); const j = await r.json();
  const K = (id) => (j.kisiler || []).find((x) => x.id === id);
  kapi('KD1 200 + kaynak aile kaydı + sayılar', r.status === 200 && j.kaynak.length === 1 && j.kaynak[0].endsWith('aile-registry.yaml') && JSON.stringify(j.sayilar) === JSON.stringify({ calisan: 1, dusen: 1, 'kayitta-var-calismiyor': 0, 'gecici-emekli': 1, kayitsiz: 1, altyapi: 1 }), `→ ${r.status} ${JSON.stringify(j.sayilar)} ${JSON.stringify(j.kaynak)}`);
  const rk = await (await iste(18791, '/sedir/api/koltuklar', { cerez })).json(); const rk1 = (ad) => (rk.koltuklar || []).find((x) => x.ad === ad) || {};
  kapi('RT1 koltuk cevabı kayıttan rütbe taşır: amiri olan personel, altı olan müdür', rk1('kalfa').kademe === 'personel' && rk1('kalfa').amir === 'BASIRET' && rk1('kalfa').amir_ad === 'BASIRET' && rk1('BASIRET').kademe === 'mudur', JSON.stringify(rk1('kalfa')));
  kapi('RT2 rütbe bilgisi olmayan koltukta alan yazılmaz', !('kademe' in rk1('2026/85')) && !('amir' in rk1('2026/85')), JSON.stringify(rk1('2026/85')));
  kapi('KD2 çalışan: BASIRET ⏳ dış olay + ne + ekran adresi', K('BASIRET').grup === 'calisan' && K('BASIRET').oturum.hal === 'dis-olay' && K('BASIRET').oturum.ne === 'CI bekleniyor' && adr(K('BASIRET').oturum, 'BASIRET'), JSON.stringify(K('BASIRET')));
  kapi('KD3 düşen: kalfa (oturum açık, Claude yok) · ana koltuk boş kabuk olsa da DÜŞEN değil, altyapı (E2: "ana oturum")', K('KALFA').grup === 'dusen' && !j.kisiler.some((x) => x.tmux === 'sinavkutu-ana') && j.altyapi.length === 1 && j.altyapi[0].ana && j.altyapi[0].altyapi === 'ana oturum' && adr(j.altyapi[0], 'sinavkutu-ana'), JSON.stringify(j.altyapi));
  kapi('KD4 hal: emekli → geçici/emekli; kayıtsız "2026/85" ekran adresi adı değil kimliği taşır', K('MIMAR').grup === 'gecici-emekli' && j.kayitsiz.length === 1 && adr(j.kayitsiz[0], '2026/85'), JSON.stringify(j.kayitsiz));
  kapi('KD5 proje dizini yanıtta (hangi kayıt okundu, izlenebilir)', j.proje === PROJE);
  p8.kill();
  // KD8 (2.24.0 · göz tur 1): tuz KULLANILAMAZSA (yaratılamaz dizin) kimlik null VE ekran null — adres adla KURULMAZ
  const p8b = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KOLTUK_TUZ: join(T, 'yok-dizin', 'tuz'), KAPI_PORT: '18798', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: PROJE,
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: K6, TO_ANA_TMUX: 'sinavkutu-ana' }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18798/sedir/giris')).status === 200) break; } catch {} }
  const c8b = await giris(18798, '/sedir'); const j8b = await (await iste(18798, '/sedir/api/kadro', { cerez: c8b })).json();
  const hepsi8b = [...(j8b.kisiler || []).map((x) => x.oturum).filter(Boolean), ...(j8b.kayitsiz || []), ...(j8b.altyapi || [])];
  const kl8b = await (await iste(18798, '/sedir/api/koltuklar', { cerez: c8b })).json();
  kapi('KD8 tuz kullanılamazsa kimlik VE ekran null (adres adla kurulmaz) — kadro ve koltuklar ucu', hepsi8b.length > 0 && hepsi8b.every((o) => o.kimlik === null && o.ekran === null)
    && (kl8b.koltuklar || []).length > 0 && kl8b.koltuklar.every((o) => o.kimlik === null && o.ekran === null) && !JSON.stringify(j8b).includes('?arg='), JSON.stringify(j8b.kayitsiz));
  p8b.kill();
  const p9 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18793', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: join(T, 'yok-proje'),
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: KOLTUK_BOZUK }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18793/sedir/giris')).status === 200) break; } catch {} }
  const c9 = await giris(18793, '/sedir');
  kapi('KD6 koltuk listesi ölçülemezse 500 (uydurma kadro yok)', (await iste(18793, '/sedir/api/kadro', { cerez: c9 })).status === 500);
  p9.kill();
  // KD7: kayıt dosyası VAR ama okunamıyor → 500 (boş kayıtla "herkes kayıtsız" demez — göz tur 1)
  const KILIT = join(T, 'kilit-proje'); mkdirSync(join(KILIT, '_agents/handoff/aile-registry.yaml'), { recursive: true });   // yol var, okunamaz (dizin) — root'ta da (göz tur 2)
  const p10 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18795', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: KILIT,
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: K6 }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18795/sedir/giris')).status === 200) break; } catch {} }
  const c10 = await giris(18795, '/sedir'); const r10 = await iste(18795, '/sedir/api/kadro', { cerez: c10 }); const j10 = await r10.json();
  kapi('KD7 kayıt var ama okunamıyor → 500 + hangi dosya', r10.status === 500 && /Kayıt okunamadı: .*aile-registry\.yaml/.test(j10.hata || ''), `→ ${r10.status} ${JSON.stringify(j10)}`);
  p10.kill();
  // KD9–KD11 (2.37.2 · SERDAR): İSKÂN kaydı olan kutuda (NAZIR) koltuk oda alanı AİLE kaydından gelir; id/tmux iskan'ınki kalır
  const NZP = join(T, 'nz-proje'); mkdirSync(join(NZP, '_agents/handoff'), { recursive: true });
  writeFileSync(join(NZP, 'iskan-registry.yaml'), 'proje: nz\nuyeler:\n  - id: nz-yon\n    tmux: "nz-yon:0"\n  - id: nz-motor\n    tmux: "nz-motor:0"\n');
  writeFileSync(join(NZP, '_agents/handoff/aile-registry.yaml'), 'uyeler:\n- id: nz-yon\n  oda: nezaret\n- id: nz-motor\n  oda: omnirouter\n');
  const K7 = join(T, 'koltuk-sahte7.sh');
  writeFileSync(K7, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\n'
    + 'printf "nz-yon\\t1760000100\\t1\\tajan\\tbilinmiyor\\t\\nnz-motor\\t1760000200\\t0\\tajan\\tbilinmiyor\\t\\nnz-bos\\t5\\t0\\tdiger\\tbilinmiyor\\t\\n"\n');
  const p12 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18811', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: NZP,
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), KAPI_KOLTUK_BETIK: K7, TO_ANA_TMUX: 'nz-bos' }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18811/sedir/giris')).status === 200) break; } catch {} }
  const c12 = await giris(18811, '/sedir'); const r12 = await iste(18811, '/sedir/api/koltuklar', { cerez: c12 }); const j12 = await r12.json();
  const KT = (ad) => (j12.koltuklar || []).find((x) => x.ad === ad);
  kapi('KD9 iskan+aile kaydı olan kutuda koltuğun oda alanı aile kaydından gelir (kayıt kaynaklı)', r12.status === 200 && KT('nz-yon')?.oda === 'nezaret' && KT('nz-yon')?.oda_kaynak === 'kayit', JSON.stringify(j12.koltuklar));
  kapi('KD10 ikinci koltuk kendi odasını alır (omnirouter) ve odalar listesinde iki oda var', KT('nz-motor')?.oda === 'omnirouter' && (j12.odalar || []).map((o) => o.ad).join() === 'nezaret,omnirouter', JSON.stringify(j12.odalar));
  kapi('KD11 kayıtta olmayan koltuk oda uydurmaz (oda alanı yok)', KT('nz-bos') !== undefined && KT('nz-bos').oda === undefined, JSON.stringify(KT('nz-bos')));
  p12.kill();
}

// ── KT · /api/kadro/tarif + /api/kadro/uzmanlik (2.20.0 · Mühürdarlık G12): SALT OKUR, girişli, kaynak yoksa ölçülemedi ──
{
  const giris = async (port, taban) => { const ok = await iste(port, `${taban}/giris`, { metot: 'POST', govde: { parola: SIFRE } });
    return 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1]; };
  const VERI = join(KOK, '../../tarif-kaydi/veri');
  const p11 = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, KAPI_PORT: '18797', KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: join(T, 'yok-proje'),
    KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'ayse-ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'oturum-yok'), TO_TARIF_DIZIN: VERI, TO_AJAN_KAYDI: join(T, 'yok/agent-registry.json') }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch('http://127.0.0.1:18797/sedir/giris')).status === 200) break; } catch {} }
  kapi('KT0 girişsiz /api/kadro/tarif ve /api/kadro/uzmanlik 401', (await iste(18797, '/sedir/api/kadro/tarif')).status === 401 && (await iste(18797, '/sedir/api/kadro/uzmanlik')).status === 401);
  const cerez = await giris(18797, '/sedir');
  const r = await iste(18797, '/sedir/api/kadro/tarif', { cerez }); const j = await r.json();
  kapi('KT1 GET /api/kadro/tarif 200: kutu + gerçek tarif (1 uzmanlık · 36 terim), olc yok, yol yok', r.status === 200 && j.kutu === 'sinavkutu' && j.tarif.uzmanliklar.length === 1 && j.terim.terimler.length === 36 && !j.olc.tarif && !j.olc.terim && !JSON.stringify(j).includes(VERI), `→ ${r.status} ${JSON.stringify(j.olc)}`);
  const p = await iste(18797, '/sedir/api/kadro/tarif', { cerez, metot: 'POST', govde: {} });
  const p2 = await iste(18797, '/sedir/api/kadro/uzmanlik', { cerez, metot: 'POST', govde: {} });
  kapi('KT2 yazma yolu yok: POST → 405 (iki uçta da)', p.status === 405 && p2.status === 405, `→ ${p.status} ${p2.status}`);
  const u = await iste(18797, '/sedir/api/kadro/uzmanlik', { cerez }); const ju = await u.json();
  kapi('KT3 kayıt yok → 200 + personel null + olc "kaynak yok" (boş liste DEĞİL)', u.status === 200 && ju.personel === null && ju.olc.personel === 'kaynak yok' && ju.diploma === null, `→ ${u.status} ${JSON.stringify(ju)}`);
  p11.kill();
}

// ── OD · koltuğun ODASI (2.36.8 · SERDAR kararı A, 31 Eki): sıra oda.json → kayıttaki oda → oda dışı; koltukta oda_kaynak ──
{
  const PO = join(T, 'oda-proje'); const od = (y, m) => { mkdirSync(join(PO, y), { recursive: true }); if (m !== undefined) writeFileSync(join(PO, y, 'oda.json'), m); };
  od('agentic-os', JSON.stringify({ ad: 'agentic-os', reis: 'SERDAR', hedef: 'Agentic OS çekirdeği', olcu: 'kapanan iş', ek_yazma: [] }));
  od('agentic-os/alt/derin'); od('freelance', JSON.stringify({ ad: 'freelance', reis: 'BASIRET', hedef: 'Freelance işleri', olcu: 'teklif' }));
  od('bozuk', '{ad: bozuk'); mkdirSync(join(PO, '_agents/handoff'), { recursive: true });
  writeFileSync(join(PO, '_agents/handoff/aile-registry.yaml'), 'uyeler:\n  - id: BASIRET\n    tmux: "BASIRET:0"\n    oda: agentic-os   # eşleşir\n  - id: KALFA\n    tmux: "kalfa:0"\n    oda: agentic-os\n  - id: MIMAR\n    tmux: "mimar:0"\n    oda: freelance\n  - id: CIRAK\n    tmux: "cirak:0"\n  - id: CIRAK2\n    tmux: "cirak2:0"\n    oda: freelance\n  - id: ŞAKİRD\n    oda: hezarfen\n  - id: MÜZEHHİP\n    tmux: "muzehhip:0"\n    oda: hezarfen\n  - id: KOTU\n    tmux: "kotu:0"\n    oda: Kötü_Ad\n');
  const sat = (ad, dizin) => `${ad}\\t5\\t1\\tajan\\tbos\\t\\t\\t\\t${dizin}\\n`;
  const K9 = join(T, 'koltuk-sahte9.sh');
  writeFileSync(K9, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "' + sat('sinavkutu-ana', PO) + sat('cirak2', join(PO, 'bozuk')) + sat('sakird', PO) + sat('muzehhip', PO) + sat('kotu', PO) + sat('BASIRET', join(PO, 'agentic-os/alt/derin')) + sat('kalfa', join(PO, 'freelance')) + sat('mimar', PO) + sat('cirak', join(PO, 'bozuk')) + 'eski\\t5\\t1\\tajan\\tbos\\t\\t\\t\\n' + '"\n');
  const PD = 18780; const pd = await kapiAc('/sedir', PD, { TO_PROJE: PO, KAPI_KOLTUK_BETIK: K9 });
  const ok = await iste(PD, '/sedir/giris', { metot: 'POST', govde: { parola: SIFRE } });
  const cd = 'kapi=' + ((ok.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const r = await iste(PD, '/sedir/api/koltuklar', { cerez: cd }); const metin = await r.text(); let j = {}; try { j = JSON.parse(metin); } catch {}
  const K = (ad) => (j.koltuklar || []).find((x) => x.ad === ad) || {};
  kapi('OD1 koltuk oda klasörünün ALTINDA açılmış: oda yukarıdaki oda.json\'dan (agentic-os), kaynak klasor, kayıtla aynı → uyarı YOK', K('BASIRET').oda === 'agentic-os' && K('BASIRET').oda_kaynak === 'klasor' && !K('BASIRET').oda_uyari, `→ ${JSON.stringify(K('BASIRET'))}`);
  kapi('OD2 kayıt agentic-os, klasör freelance → oda KLASÖRDEN (freelance) + kaynak klasor + iki adı söyleyen uyarı', K('kalfa').oda === 'freelance' && K('kalfa').oda_kaynak === 'klasor' && /'agentic-os'/.test(K('kalfa').oda_uyari || '') && /'freelance'/.test(K('kalfa').oda_uyari || ''), `→ ${JSON.stringify(K('kalfa'))}`);
  kapi('OD3 kayıtta oda var, koltuk oda klasöründe değil → oda KAYITTAN, kaynak kayit, uyarı YOK (kararın 2. basamağı olağan durum)', K('mimar').oda === 'freelance' && K('mimar').oda_kaynak === 'kayit' && !K('mimar').oda_uyari, `→ ${JSON.stringify(K('mimar'))}`);
  kapi('OD4 bozuk oda.json, kayıtta oda yok → odasız gösterilir ve SÖYLENİR (sessiz odasız değil)', !('oda' in K('cirak')) && !('oda_kaynak' in K('cirak')) && /okunamadı/.test(K('cirak').oda_uyari || ''), `→ ${JSON.stringify(K('cirak'))}`);
  kapi('OD4b bozuk oda.json, kayıtta oda var → kayıttan gösterilir, kaynak kayit, uyarı hem bozukluğu hem kayıt odasını söyler', K('cirak2').oda === 'freelance' && K('cirak2').oda_kaynak === 'kayit' && /okunamadı/.test(K('cirak2').oda_uyari || '') && /'freelance'/.test(K('cirak2').oda_uyari || ''), `→ ${JSON.stringify(K('cirak2'))}`);
  kapi('OD5 kayıtsız + odasız koltuk ve dizin sütunu olmayan eski satır: oda dışı (oda · kaynak · uyarı yok)', !('oda' in K('sinavkutu-ana')) && !('oda_kaynak' in K('sinavkutu-ana')) && !K('sinavkutu-ana').oda_uyari && K('eski').ad === 'eski' && !('oda' in K('eski')), `→ ${JSON.stringify([K('sinavkutu-ana'), K('eski')])}`);
  kapi('OD6 odalar kayıt odalarını da taşır, klasör bilgisi kayıt satırını ezer (cirak2 kayıttan önce geldi), sıralı; çalışma dizini yanıta SIZMAZ', JSON.stringify(j.odalar) === JSON.stringify([{ ad: 'agentic-os', hedef: 'Agentic OS çekirdeği', reis: 'SERDAR' }, { ad: 'freelance', hedef: 'Freelance işleri', reis: 'BASIRET' }, { ad: 'hezarfen', hedef: '', reis: '' }]) && !metin.includes(PO) && !/"dizin"/.test(metin), `→ ${JSON.stringify(j.odalar)} sızıntı=${metin.includes(PO)}`);
  kapi('OD8 ad eşlemesi: tmux alanıyla muzehhip ⟷ MÜZEHHİP; tmux alanı yokken ŞAKİRD ⟷ sakird', K('muzehhip').oda === 'hezarfen' && K('muzehhip').oda_kaynak === 'kayit' && K('sakird').oda === 'hezarfen' && K('sakird').oda_kaynak === 'kayit', `→ ${JSON.stringify([K('muzehhip'), K('sakird')])}`);
  kapi('OD9 kayıtta geçersiz oda adı oda sayılmaz: oda dışı', !('oda' in K('kotu')) && !('oda_kaynak' in K('kotu')), `→ ${JSON.stringify(K('kotu'))}`);
  const { odaBul } = await import(pathToFileURL(join(KOK, 'oda.mjs')).href);
  kapi('OD7 göreli ya da boş dizin → oda aranmaz (null)', odaBul('agentic-os') === null && odaBul('') === null && odaBul(undefined) === null);
  pd.kill();
}

kapiTaban.kill(); kapiKok.kill(); ttyd.close(); ttydKisi.close();
console.log(`\n${'─'.repeat(56)}`);
console.log(`GECEN: ${gecen}  ·  KALAN: ${kalan}`);
if (kalan) { console.log('BASARISIZ:'); basarisiz.forEach((a) => console.log('  · ' + a)); }
process.exit(kalan ? 1 : 0);
