// dava.test.mjs — DAVA RAFI kapı tarafı (Parça B1-B10) UÇTAN UCA: gerçek kapı süreci + sahte tmux (PATH) + sahte koltuk listesi
// + sahte açıcı + sahte kimlik izi (oturum dizini + /proc) + gerçek günlük bekçi turu. Kayıt vekatip'in şeklinde: iskan-registry.yaml
// (kök dava_kurali + uyeler) + işaret ettiği ekip kaydı. Ölçülen: davalar alanı · Aç'ta yer açma (ve açamayınca HİÇBİR ŞEY açılmaması)
// · dondururken son_calisma · E4 bağla (dava / kişi) ve geri al (kayıt BAYT BAYT eski hâl) · bekçi turu (dondurma: kural) · davasız
// kutuda yanıt değişmez. Hermetik: geçici dizin; gerçek tmux'a, gerçek kayda, gerçek Claude'a dokunmaz.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync, rmSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { davaKuraliAyristir, davaOzet, yerAcAday, kendiligindenDondurulacak, kadroBirlestir, kayitAyristir } from './kadro.mjs';
import { alanlarYaz, kisaAdGecerli, DOSYA_NO, baglaGeriAl, KadroHata } from './kadro-yaz.mjs';
// 2.24.0: kapı ad dışı kimlik için tuz yaratır → sınav GERÇEK $HOME'a dokunmasın
process.env.KOLTUK_TUZ ||= (await import('node:fs')).mkdtempSync((await import('node:os')).tmpdir() + '/kapi-tuz-') + '/tuz';
const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'dava-'));
const SIFRE = 'sinav-parolasi-1234', PORT = 18803, GUN = 86400, SIMDI = Math.floor(Date.now() / 1000);
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };

console.log('── DV-A · saf kurallar (kadro.mjs · kadro-yaz.mjs)');
kapi('DV1 dava_kurali akış ve blok biçimi okunur; eksik/bozuk/aralık dışı kural YOK sayılır (yarım kuralla dondurma yok)',
  JSON.stringify(davaKuraliAyristir('x: 1\ndava_kurali: {tavan: 4, gun: 14}  # Sultan\n')) === '{"tavan":4,"gun":14}'
  && JSON.stringify(davaKuraliAyristir('dava_kurali:\n  # not\n  tavan: 2\n  gun: 7\nuyeler:\n')) === '{"tavan":2,"gun":7}'
  && davaKuraliAyristir('dava_kurali: {tavan: 4}') === null && davaKuraliAyristir('dava_kurali: {tavan: 0, gun: 14}') === null
  && davaKuraliAyristir('  dava_kurali: {tavan: 4, gun: 14}') === null && davaKuraliAyristir('uyeler:\n') === null);
const D = (id, son, ek = {}) => ({ id, rol: 'dava', hal_kayit: 'bilinmiyor', oturum: son ? { ad: 'o' + id, son } : null, ...ek });
const dl = [D('a', SIMDI - 2 * 3600), D('b', SIMDI - 12 * GUN), D('c', SIMDI - 14 * GUN - 60), D('d', 0, { hal_kayit: 'dondurulmus' }), { id: 'REIS', rol: 'reis', hal_kayit: 'bilinmiyor', oturum: { ad: 'R', son: SIMDI - 40 * GUN } }];
const oz = davaOzet(dl, { tavan: 3, gun: 14 }, SIMDI);
kapi('DV2 davaOzet: açık yalnız rol=dava ve dondurulmamış (3) · dondurulacak = son üç gün (b: 2 gün kaldı, c: 0) · personel sayılmaz',
  oz.acik === 3 && JSON.stringify(oz.dondurulacak) === '[{"id":"b","kalan_gun":2},{"id":"c","kalan_gun":0}]', JSON.stringify(oz));
kapi('DV3 yerAcAday: tavan dolu → en uzun süredir dokunulmayan açık dava (c); yer varsa null; istenen dava sayılmaz',
  yerAcAday(dl, { tavan: 3, gun: 14 }, 'd').id === 'c' && yerAcAday(dl, { tavan: 4, gun: 14 }, 'd') === null && yerAcAday(dl, { tavan: 3, gun: 14 }, 'a') === null);
kapi('DV4 kendiliğinden: yalnız gun gününü dolduran açık dava (c); personel 40 gün dokunulmasa da DONDURULMAZ',
  kendiligindenDondurulacak(dl, { tavan: 3, gun: 14 }, SIMDI).map((x) => x.id).join() === 'c');
const ham = 'uyeler:\n  - id: X\n    tmux: "x:0"   # not\n  - id: Y\n';
kapi('DV5 alanlarYaz: var olan satır yerinde (yorum korunur) · yoksa bloğun sonuna · null siler · komşu blok değişmez',
  alanlarYaz(ham, 'id', 'X', { tmux: '"z:0"', son_calisma: '5' }) === 'uyeler:\n  - id: X\n    tmux: "z:0"   # not\n    son_calisma: 5\n  - id: Y\n'
  && alanlarYaz(alanlarYaz(ham, 'id', 'X', { son_calisma: '5' }), 'id', 'X', { son_calisma: null }) === ham);
kapi('DV6 dosya no YYYY/N · kısa ad 1-60, tırnak/ters bölü/satır sonu yok, baş-son boşluk yok',
  DOSYA_NO.test('2025/42') && !DOSYA_NO.test('25/42') && !DOSYA_NO.test('2025/') && !DOSYA_NO.test('2025/42 ') && kisaAdGecerli('İşçilik alacağı')
  && !kisaAdGecerli('a"b') && !kisaAdGecerli('a\\b') && !kisaAdGecerli('a\nb') && !kisaAdGecerli(' a') && !kisaAdGecerli('') && !kisaAdGecerli('x'.repeat(61)));
const eski = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: A\n    tmux: "a:0"\n'), koltuklar: [{ ad: 'a', claude: true, son: 5 }] }).kisiler[0];
kapi('DV7 davasız kişi çıktısı ESKİ ANAHTARLARLA aynı (arz_adi · son_calisma · dondurma · bagla_ile eklenmez)',
  Object.keys(eski).join() === 'id,rol,mod,hal_kayit,tmux,oturum,grup,geri_acilir', Object.keys(eski).join());

const P0 = join(T, 'p0'); mkdirSync(join(P0, '_agents/handoff'), { recursive: true }); const K0 = 'uyeler:\n  - id: 2025/1\n    rol: dava\n    tmux: "a:0"\n';
writeFileSync(join(P0, '_agents/handoff/aile-registry.yaml'), K0);
let r0 = null; try { baglaGeriAl({ proje: P0, ortam: {}, id: '2025/1' }); } catch (e) { r0 = e; }
kapi('DV7b modül kendisi de korur: bağlamayla GELMEMİŞ kaydı baglaGeriAl silmez (409), dosya bayt bayt aynı (kapının ön kontrolüne yaslanmaz)',
  r0 instanceof KadroHata && r0.kod === 409 && readFileSync(join(P0, '_agents/handoff/aile-registry.yaml'), 'utf8') === K0, String(r0));

// ── Kurulum: İSKÂN kutusu (vekatip şekli)
const OTURUM = join(T, 'oturumlar'), TMUX_DEFTER = join(T, 'tmux-defter'), AC_DEFTER = join(T, 'ac-defter'), KILL_DUSUR = join(T, 'kill-dusur');
const ot = (ad, c, gunOnce) => `${ad}\t${c}\t${SIMDI - Math.round(gunOnce * GUN)}\n`;
writeFileSync(OTURUM, ot('sinavkutu-ana', 1, 0) + ot('REIS', 1, 0.01) + ot('veli', 1, 0.08) + ot('hasan', 1, 12) + ot('fatma', 1, 5) + ot('eski', 1, 20)
  + ot('musteri-a', 1, 1) + ot('kisi-ot', 1, 2) + ot('bos-ot', 0, 3) + ot('ayni-ot', 1, 1));
const BIN = join(T, 'bin'); mkdirSync(BIN);
writeFileSync(join(BIN, 'tmux'), `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(TMUX_DEFTER)}\n`
  + `if [ "$1" = kill-session ] && [ "$2" = -t ]; then ad="\${3#=}"; [ -f ${JSON.stringify(KILL_DUSUR)} ] && exit 1\n`
  + `  grep -q "^$ad\t" ${JSON.stringify(OTURUM)} || exit 1; grep -v "^$ad\t" ${JSON.stringify(OTURUM)} > ${JSON.stringify(OTURUM)}.y; mv ${JSON.stringify(OTURUM)}.y ${JSON.stringify(OTURUM)}; exit 0; fi\nexit 0\n`, { mode: 0o755 });
const LISTE = join(T, 'liste.sh');
writeFileSync(LISTE, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nwhile IFS=$'\\t' read -r ad c son; do [ -n "$ad" ] && printf '%s\\t%s\\t%s\\tajan\\tbos\\t\\n' "$ad" "$son" "$c"; done < ${JSON.stringify(OTURUM)}\n`, { mode: 0o755 });
const AC = join(T, 'koltuk-ac.sh');
writeFileSync(AC, `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(AC_DEFTER)}\n[ "$1" = ac ] && printf '%s\\t1\\t%s\\n' "$2" "$(date +%s)" >> ${JSON.stringify(OTURUM)}\necho "açıldı: $2"\n`, { mode: 0o755 });
// Kimlik izi: musteri-a · kisi-ot tek Claude; ayni-ot İKİ Claude (hangisi bağlanır belirsiz); bos-ot hiç (Claude yok)
const ALAN = 'pid:[4026532222]', OTD = join(T, 'sessions'), PROC = join(T, 'proc'); mkdirSync(OTD); mkdirSync(PROC);
const SID = { musteri: '5a1e0000-0000-4000-8000-000000000001', kisi: '5a1e0000-0000-4000-8000-000000000002', mub: '5a1e0000-0000-4000-8000-0000000000ff' };
const surec = (pid, tmux, sid, cwd) => { mkdirSync(join(PROC, String(pid)), { recursive: true }); writeFileSync(join(PROC, String(pid), 'cmdline'), 'claude\0');
  writeFileSync(join(OTD, pid + '.json'), JSON.stringify({ pid: String(pid), pidDomain: 'linux::' + ALAN, sessionId: sid, tmux: tmux + ':@1.%1', name: 'x', nameSource: 'derived', cwd })); };
const PROJE = join(T, 'proje'); mkdirSync(join(PROJE, '_agents/handoff'), { recursive: true });
surec(201, 'musteri-a', SID.musteri, PROJE); surec(202, 'kisi-ot', SID.kisi, PROJE + '/alt'); surec(203, 'ayni-ot', SID.musteri.replace('01', '03'), PROJE); surec(204, 'ayni-ot', SID.musteri.replace('01', '04'), PROJE);
const ISKAN = join(PROJE, 'iskan-registry.yaml'), DAVALAR = join(PROJE, 'davalar.yaml'), EKIP = join(PROJE, '_agents/handoff/ekip-registry.yaml');
const dava = (id, tmux, ad, ek = '') => `  - id: ${id}\n    rol: dava\n    tmux: "${tmux}:0"\n    arz_adi: "${ad}"\n    session_id: 5a1e0000-0000-4000-8000-${String(id.replace('/', '')).padStart(12, '0')}\n${ek}`;
const ILK_ISKAN = 'proje: sinavkutu\nekip_registry_pointer: _agents/handoff/ekip-registry.yaml\ndava_kurali: {tavan: 4, gun: 14}   # Sultan 14:37\nuyeler:\n'
  + '  - id: REIS\n    tmux: "REIS:0"\n    session_id: 5a1e0000-0000-4000-8000-0000000000aa\n'
  + '  - id: MUBEYYIZ\n    tmux: "MUBEYYIZ:0"\n    session_id: ' + SID.mub + '\n'
  + '# kayıt sonu notu\n';
// Dava satırları AYRI dosyada (Sx #350 · kayıt kararı (b)): iskan'da yalnız dava_kurali kalır
const ILK_DAVALAR = 'uyeler:\n' + dava('2025/118', 'veli', 'İşçilik alacağı') + dava('2024/772', 'hasan', 'Tapu iptali') + dava('2026/31', 'fatma', 'Kira tespiti') + dava('2023/1', 'eski', 'Eski dosya')
  + dava('2025/204', 'ali', 'Tazminat', `    durum: dondurulmus\n    durum_once: yok\n    son_calisma: ${SIMDI - 13 * GUN}\n`)
  + '# dava kayıt sonu notu\n';
writeFileSync(ISKAN, ILK_ISKAN); writeFileSync(DAVALAR, ILK_DAVALAR);
writeFileSync(EKIP, 'uyeler:\n  - id: REIS\n    rol: "reis"\n  - id: MUBEYYIZ\n    rol: "ekip"\n');
const ortam = { ...process.env, PATH: BIN + ':' + process.env.PATH, KAPI_PORT: String(PORT), KAPI_TABAN: '/sedir', TO_KUTU: 'sinavkutu', TO_PROJE: PROJE,
  KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_KOLTUK_BETIK: LISTE, KAPI_KOLTUK_AC_BETIK: AC,
  TO_ANA_TMUX: 'sinavkutu-ana', KADRO_KILIT_BEKLE_MS: '1500', KAPI_EKIPC: '', KAPI_OTURUM_DIZ: OTD, KAPI_PROC_KOK: PROC, KAPI_PID_ALANI: ALAN };
const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: ortam, stdio: ['ignore', 'ignore', 'pipe'] });
let hataCikti = ''; p.stderr.on('data', (d) => { hataCikti += d; });
process.on('exit', () => { try { p.kill(); } catch {} });
process.on('uncaughtException', (e) => { console.log('  ✗ sınav çöktü: ' + e.message); try { p.kill(); } catch {} process.exit(1); });
for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch(`http://127.0.0.1:${PORT}/sedir/giris`)).status === 200) break; } catch {} }
await new Promise((r) => setTimeout(r, 200));
if (p.exitCode !== null) { console.log('  ✗ kapı açılamadı (port dolu?) rc=' + p.exitCode + '\n' + hataCikti.slice(-400)); process.exit(1); }
const giris = await fetch(`http://127.0.0.1:${PORT}/sedir/giris`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parola: SIFRE }) });
const CEREZ = 'kapi=' + ((giris.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
const hal = async (govde, { ek = {} } = {}) => {
  const r = await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro/hal`, { method: 'POST', headers: { 'content-type': 'application/json', cookie: CEREZ, 'x-kapi': '1', ...ek }, body: JSON.stringify(govde) });
  let j = {}; try { j = await r.json(); } catch {} return { s: r.status, j };
};
const kadro = async () => (await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro`, { headers: { cookie: CEREZ } })).json();
const kisi = (kd, id) => kd.kisiler.find((x) => x.id === id);
const iskan = () => readFileSync(ISKAN, 'utf8'); const davalar = () => readFileSync(DAVALAR, 'utf8');
const tmuxIz = () => existsSync(TMUX_DEFTER) ? readFileSync(TMUX_DEFTER, 'utf8') : '';
const acIz = () => existsSync(AC_DEFTER) ? readFileSync(AC_DEFTER, 'utf8') : '';
const bekci = (...a) => spawnSync(process.execPath, [join(KOK, 'dava-bekci.mjs'), ...a], { env: ortam, encoding: 'utf8' });

console.log('── DV-B · /api/kadro davalar alanı (B2)');
const k0 = await kadro();
kapi('DV8 davalar: tavan 4 · gun 14 · açık 4 (dondurulmuş sayılmaz, personel sayılmaz) · dondurulacak hasan(12 gün → 2) ve eski(20 gün → 0); bagla: true',
  k0.davalar && k0.davalar.tavan === 4 && k0.davalar.gun === 14 && k0.davalar.acik === 4 && JSON.stringify(k0.davalar.dondurulacak) === '[{"id":"2024/772","kalan_gun":2},{"id":"2023/1","kalan_gun":0}]' && k0.bagla === true, JSON.stringify(k0.davalar));
const a204 = kisi(k0, '2025/204'), a118 = kisi(k0, '2025/118');
kapi('DV9 dava kişisi: rol dava · arz_adi · dondurulmuşta son_calisma (sayı) · açıkta oturum.son; dondurma işareti YOK (elle dondurulmuş)',
  a204.rol === 'dava' && a204.arz_adi === 'Tazminat' && a204.son_calisma === SIMDI - 13 * GUN && !a204.dondurma && a118.arz_adi === 'İşçilik alacağı' && a118.oturum && a118.oturum.ad === 'veli' && !('son_calisma' in a118), JSON.stringify([a204, a118]));
kapi('DV10 kayıtsızlar: musteri-a · kisi-ot · bos-ot · ayni-ot (davalar ve personel oturumu kayıtsız SAYILMAZ)', k0.kayitsiz.map((x) => x.ad).sort().join() === 'ayni-ot,bos-ot,kisi-ot,musteri-a', k0.kayitsiz.map((x) => x.ad).join());

console.log('── DV-C · günlük bekçi turu (B7)');
const bk = bekci('--kuru');
kapi('DV11 --kuru: yalnız "2023/1" dondurulur der, kayda ve tmux\'a dokunmaz', bk.status === 0 && /dondurulur: 2023\/1/.test(bk.stdout) && !/2024\/772/.test(bk.stdout) && iskan() === ILK_ISKAN && davalar() === ILK_DAVALAR && tmuxIz() === '', bk.stdout + bk.stderr);
const b1 = bekci();
kapi('DV12 tur: 2023/1 dondurulur (durum + son_calisma = oturumun son hareketi + dondurma: kural), oturumu kapatılır; 12 günlük 2024/772 DOKUNULMAZ',
  b1.status === 0 && davalar().includes(`  - id: 2023/1\n    durum: dondurulmus\n    durum_once: yok\n    rol: dava\n    tmux: "eski:0"\n    arz_adi: "Eski dosya"\n    session_id: 5a1e0000-0000-4000-8000-000000020231\n    son_calisma: ${SIMDI - 20 * GUN}\n    dondurma: kural\n`)
  && tmuxIz().trim() === 'kill-session -t =eski', b1.stdout + b1.stderr + '\n' + davalar());
const k1 = await kadro();
kapi('DV13 kadroda 2023/1: dondurulmuş · dondurma: kural (raf "kural dondurdu" der); açık 3', kisi(k1, '2023/1').dondurma === 'kural' && kisi(k1, '2023/1').hal_kayit === 'dondurulmus' && k1.davalar.acik === 3, JSON.stringify(kisi(k1, '2023/1')));
const b2 = bekci();
kapi('DV14 ikinci tur boş: dondurulacak dava yok (iz tekrar yazılmaz)', b2.status === 0 && /dondurulacak dava yok/.test(b2.stdout), b2.stdout + b2.stderr);
kapi('DV15 iz kadro-hal.log: "bekci dondur \\"2023/1\\" … (14 gün dokunulmadı)"', /bekci dondur "2023\/1" -→dondurulmus .*\(14 gün dokunulmadı\)/.test(readFileSync(join(T, 'kadro-hal.log'), 'utf8')));

console.log('── DV-D · Aç: yer varken açar, tavan doluyken yer açar (B4)');
const c1 = await hal({ eylem: 'geri-ac', id: '2025/204', yer_ac: true });
kapi('DV16 açık 3 < tavan 4 → kimse dondurulmaz (donduruldu: null); açıcı "ac ali --eski"; yanıtta ekran adı değil kimliği taşır (2.24.0)',
  c1.s === 200 && c1.j.tamam && c1.j.donduruldu === null && c1.j.oturum === true && /^k[0-9a-f]{16}$/.test(c1.j.kimlik || '') && c1.j.ekran === '/sedir/tty/?arg=' + c1.j.kimlik && !c1.j.ekran.includes('ali') && acIz().trim() === 'ac ali --eski', JSON.stringify(c1));
const blok204 = () => (davalar().match(/  - id: 2025\/204\n(?:    .*\n)*/) || [''])[0];
kapi('DV17 geri açılan davanın kaydı: durum ve durum_once satırları KALKTI; son_calisma kaldı (açıkken oturumun son\'u kullanılır)',
  !/durum/.test(blok204()) && blok204().includes(`    son_calisma: ${SIMDI - 13 * GUN}\n`), blok204());
const tOnce = tmuxIz();
const c2 = await hal({ eylem: 'geri-ac', id: '2023/1', yer_ac: true });
const k2 = await kadro();
kapi('DV18 tavan dolu (4) → en uzun süredir dokunulmayan açık dava 2024/772 dondurulur, oturumu kapanır; 2023/1 açılır; donduruldu: "2024/772"',
  c2.s === 200 && c2.j.donduruldu === '2024/772' && c2.j.oturum === true && /kill-session -t =hasan/.test(tmuxIz().slice(tOnce.length)) && kisi(k2, '2024/772').hal_kayit === 'dondurulmus' && k2.davalar.acik === 4, JSON.stringify(c2) + JSON.stringify(k2.davalar));
kapi('DV19 yer açarken dondurulan davaya son_calisma yazıldı, dondurma işareti YOK (kural değil, yer açma); geri açılan 2023/1\'in kural işareti KALKTI',
  kisi(k2, '2024/772').son_calisma === SIMDI - 12 * GUN && !kisi(k2, '2024/772').dondurma && !/- id: 2023\/1\n(?:    .*\n)*?    dondurma:/.test(davalar()), JSON.stringify(kisi(k2, '2024/772')));
const once3 = davalar(), acOnce3 = acIz(); writeFileSync(KILL_DUSUR, '1');
const c3 = await hal({ eylem: 'geri-ac', id: '2024/772', yer_ac: true });
unlinkSync(KILL_DUSUR);
kapi('DV20 tavan dolu ve en eskinin (2026/31) oturumu KAPANMIYOR → 502, istenen dava AÇILMADI (açıcı çağrılmadı), kayıt BAYT BAYT önceki hâl',
  c3.s === 502 && /2026\/31 dondurulamadı/.test(c3.j.hata) && /açılmadı/.test(c3.j.hata) && acIz() === acOnce3 && davalar() === once3, c3.s + ' ' + JSON.stringify(c3.j));
const c4 = await hal({ eylem: 'geri-ac', id: '2024/772' });
kapi('DV21 yer_ac verilmeden (E2 paneli) tavan kuralı UYGULANMAZ: kimse dondurulmaz, açılır', c4.s === 200 && c4.j.donduruldu === null && (await kadro()).davalar.acik === 5, JSON.stringify(c4));
const c5 = await hal({ eylem: 'dondur', id: '2024/772' });
kapi('DV22 rafta Dondur: 200, oturumu kapanır, son_calisma yazılır (açılınca yeni oturumun son\'u)', c5.s === 200 && /- id: 2024\/772\n    durum: dondurulmus\n(?:    .*\n)*?    son_calisma: \d+\n/.test(davalar()), JSON.stringify(c5));

console.log('── DV-E · E4 kayda bağla (B6) · G7 geri al');
const onceBag = davalar(); const onceKisi = iskan();
const e1 = await hal({ eylem: 'bagla', oturum: 'musteri-a', hedef: 'dava', dosya_no: '2026/85', kisa_ad: 'Kira tespiti' });
kapi('DV23 bağla → dava: 200; uyeler listesinin SONUNA blok (kayıt sonu notu yerinde kalır), id tırnaksız, session_id + cwd oturumun kimlik izinden, bagla_ile: true',
  e1.s === 200 && davalar() === onceBag.replace('# dava kayıt sonu notu\n', `  - id: 2026/85\n    rol: dava\n    tmux: "musteri-a:0"\n    arz_adi: "Kira tespiti"\n    session_id: ${SID.musteri}\n    cwd: ${PROJE}\n    bagla_ile: true\n# dava kayıt sonu notu\n`), JSON.stringify(e1) + '\n' + davalar().slice(-400));
const k3 = await kadro();
kapi('DV24 kadroda 2026/85: rol dava · çalışan · oturumu musteri-a · bagla_ile; kayıtsızlardan çıktı; oturum KAPANMADI', kisi(k3, '2026/85') && kisi(k3, '2026/85').grup === 'calisan' && kisi(k3, '2026/85').bagla_ile === true
  && kisi(k3, '2026/85').oturum.ad === 'musteri-a' && !k3.kayitsiz.some((x) => x.ad === 'musteri-a') && !/=musteri-a/.test(tmuxIz()), JSON.stringify(kisi(k3, '2026/85')));
const red = await Promise.all([
  hal({ eylem: 'bagla', oturum: 'bos-ot', hedef: 'dava', dosya_no: '2026/86', kisa_ad: 'x' }),
  hal({ eylem: 'bagla', oturum: 'ayni-ot', hedef: 'dava', dosya_no: '2026/86', kisa_ad: 'x' }),
  hal({ eylem: 'bagla', oturum: 'kisi-ot', hedef: 'dava', dosya_no: '2025/118', kisa_ad: 'x' }),
  hal({ eylem: 'bagla', oturum: 'kisi-ot', hedef: 'dava', dosya_no: '25/1', kisa_ad: 'x' }),
  hal({ eylem: 'bagla', oturum: 'kisi-ot', hedef: 'dava', dosya_no: '2026/86', kisa_ad: 'a"b' }),
  hal({ eylem: 'bagla', oturum: 'sinavkutu-ana', hedef: 'dava', dosya_no: '2026/86', kisa_ad: 'x' }),
  hal({ eylem: 'bagla', oturum: 'veli', hedef: 'dava', dosya_no: '2026/86', kisa_ad: 'x' })]);
kapi('DV25 bağlama retleri: Claude yok 409 · iki Claude 409 · dosya no zaten rafta 409 · YYYY/N değil 400 · kısa adda tırnak 400 · altyapı 403 · kayıtlı oturum 404; kayıt DEĞİŞMEDİ',
  red.map((x) => x.s).join() === '409,409,409,400,400,403,404' && /Claude yok/.test(red[0].j.hata) && /zaten rafta/.test(red[2].j.hata) && davalar() === k3Iskan(), red.map((x) => x.s + ' ' + x.j.hata).join(' | '));
function k3Iskan() { return onceBag.replace('# dava kayıt sonu notu\n', `  - id: 2026/85\n    rol: dava\n    tmux: "musteri-a:0"\n    arz_adi: "Kira tespiti"\n    session_id: ${SID.musteri}\n    cwd: ${PROJE}\n    bagla_ile: true\n# dava kayıt sonu notu\n`); }
const e2 = await hal({ eylem: 'bagla-geri-al', id: '2026/85' });
const k4 = await kadro();
kapi('DV26 G7 geri al → kayıt BAYT BAYT bağlamadan önceki hâl; musteri-a yeniden kayıtsız, oturum KAPANMADI', e2.s === 200 && davalar() === onceBag && k4.kayitsiz.some((x) => x.ad === 'musteri-a') && !/=musteri-a/.test(tmuxIz()), JSON.stringify(e2));
kapi('DV27 bağlamayla gelmemiş kayıt geri alınamaz → 409, kayıt değişmedi', (await hal({ eylem: 'bagla-geri-al', id: '2025/118' })).s === 409 && davalar() === onceBag);
const e3 = await hal({ eylem: 'bagla', oturum: 'kisi-ot', hedef: 'kisi', id: 'MUBEYYIZ' });
const k5 = await kadro(); const mub = kisi(k5, 'MUBEYYIZ');
kapi('DV28 bağla → kişi: MUBEYYIZ\'in session_id\'si oturumunkine döner, önceki bagla_once\'a; kadroda kisi-ot artık MUBEYYIZ oturumu (kimlikle), kayıtsız değil',
  e3.s === 200 && iskan().includes(`  - id: MUBEYYIZ\n    tmux: "MUBEYYIZ:0"\n    session_id: ${SID.kisi}\n    bagla_once: ${SID.mub}\n    bagla_ile: true\n`) && mub.oturum && mub.oturum.ad === 'kisi-ot' && mub.eslesme === 'kimlik' && mub.bagla_ile === true && !k5.kayitsiz.some((x) => x.ad === 'kisi-ot'), JSON.stringify(e3) + JSON.stringify(mub));
kapi('DV29 dava satırına kişi bağlanmaz 409 · çalışan kişiye 409', (await hal({ eylem: 'bagla', oturum: 'musteri-a', hedef: 'kisi', id: '2025/118' })).s === 409 && (await hal({ eylem: 'bagla', oturum: 'musteri-a', hedef: 'kisi', id: 'REIS' })).s === 409);
const e4 = await hal({ eylem: 'bagla-geri-al', id: 'MUBEYYIZ' });
kapi('DV30 kişi bağlamasını geri al → kayıt BAYT BAYT önceki hâl (eski session_id geri), kisi-ot yeniden kayıtsız', e4.s === 200 && iskan() === onceKisi && (await kadro()).kayitsiz.some((x) => x.ad === 'kisi-ot'), JSON.stringify(e4));
kapi('DV31 jetonla bagla → 403 (kadro kararı ekrandan)', (await hal({ eylem: 'bagla', oturum: 'kisi-ot', hedef: 'kisi', id: 'MUBEYYIZ' }, { ek: { authorization: 'Bearer x' } })).s === 403 && iskan() === onceKisi);

console.log('── DV-F · süreçler arası kilit (kilit.mjs · kapı ve bekçi AYNI dosya) · davasız kutu');
// Kilidi AYRI bir süreç tutar (flock(1), kilit.test.mjs). Kapı ve bekçi kilidi PROJE'de alır — kadroYaz da orada kilitler (B1).
const tutucu = spawn(process.execPath, ['-e', `import(${JSON.stringify(join(KOK, 'kilit.mjs'))}).then(m=>{m.dosyaKilit(${JSON.stringify(PROJE)});console.log('TUTULDU');setInterval(()=>{},1e3)})`], { stdio: ['ignore', 'pipe', 'ignore'] });
await new Promise((r) => { let o = ''; tutucu.stdout.on('data', (d) => { o += d; if (o.includes('TUTULDU')) r(); }); tutucu.on('close', r); });
const onceF = davalar(), tmuxF = tmuxIz();
const f1 = await hal({ eylem: 'dondur', id: '2026/31' });
kapi('DV32 kayıt kilidi başka süreçteyken hal ucu 503 döner: kayıt ve oturum DOKUNULMAZ', f1.s === 503 && davalar() === onceF && tmuxIz() === tmuxF, f1.s + ' ' + JSON.stringify(f1.j));
const f2 = bekci();
kapi('DV32b kilit başka süreçteyken bekçi turu yapılmaz: rc 3, kayıt DOKUNULMAZ', f2.status === 3 && davalar() === onceF && tmuxIz() === tmuxF, f2.status + ' ' + f2.stderr);
kapi('DV32c kilit dosyası yalnız PROJE\'de (kapı · bekçi · kadroYaz tek dosya); durum dizininde kilit YOK', existsSync(join(PROJE, 'kadro.kilit')) && !existsSync(join(T, 'kadro.kilit')));
tutucu.kill('SIGKILL'); await new Promise((r) => setTimeout(r, 200));
const f3 = await hal({ eylem: 'geri-ac', id: '2024/772' });
kapi('DV32d tutan süreç ölünce kilit düşer: aynı uç hemen çalışır (200)', f3.s === 200 && f3.j.tamam === true, f3.s + ' ' + JSON.stringify(f3.j));
writeFileSync(ISKAN, ILK_ISKAN.replace(/dava_kurali:.*\n/, '')); writeFileSync(DAVALAR, ILK_DAVALAR);
const k6 = await kadro(); const bk6 = bekci();
kapi('DV33 kural satırı yoksa: /api/kadro\'da davalar ANAHTARI YOK (raf çizilmez) · bekçi turu "tur yok"', !('davalar' in k6) && k6.bagla === true && bk6.status === 0 && /tur yok/.test(bk6.stdout), JSON.stringify(Object.keys(k6)) + bk6.stdout);
const c6 = await hal({ eylem: 'geri-ac', id: '2025/204', yer_ac: true });
kapi('DV34 kuralsız kutuda yer_ac yok sayılır (tavan yok → kimse dondurulmaz)', c6.s === 200 && c6.j.donduruldu === null, JSON.stringify(c6));
// DV35 · filo üç-kopya eşitleyicisi iskan-registry'yi kanonik kopyasıyla EZER (dava satırı yok): davalar.yaml'daki dava satırları yerinde kalır
writeFileSync(ISKAN, ILK_ISKAN);
const k7 = await kadro();
kapi('DV35 iskan eşitlenip ezilse de dava satırları davalar.yaml\'da YERİNDE kalır (kayıp yok): dört dava hâlâ rol=dava olarak kadroda', ['2025/118', '2024/772', '2026/31', '2023/1'].every((id) => kisi(k7, id) && kisi(k7, id).rol === 'dava'), JSON.stringify(k7.kisiler.filter((x) => x.rol === 'dava').map((x) => x.id)));
p.kill();
if (k && hataCikti) console.log('kapı stderr:\n' + hataCikti.slice(-800));
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
