// kadro-hal.test.mjs — KADRO E2 ucu UÇTAN UCA: gerçek kapı süreci + sahte tmux (PATH) + sahte koltuk listesi (durum dosyasından)
// + sahte açıcı. Ölçülen: dondur → kayıt + oturum kapanır → kadroda dondurulmuş → geri aç → kayıt BAYT BAYT ilk hâl + oturum eski
// sohbetiyle açılır · altyapı oturumuna kapat 403 ve tmux'a HİÇ dokunulmaz · jeton/çerezsiz/başlıksız ret · kapatılamayan oturumda
// kayıt geri alınır. Hermetik: geçici dizin, gerçek tmux'a ve gerçek kayda dokunmaz.
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync, rmSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const KOK = dirname(fileURLToPath(import.meta.url));
const T = mkdtempSync(join(tmpdir(), 'kadro-hal-'));
const SIFRE = 'sinav-parolasi-1234', PORT = 18797;
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };

// Kutunun "tmux"u: oturumlar bir dosyada (ad · claude). Liste betiği ve sahte tmux aynı dosyayı okur/yazar.
const OTURUM = join(T, 'oturumlar'), TMUX_DEFTER = join(T, 'tmux-defter'), AC_DEFTER = join(T, 'ac-defter');
const ILK_OTURUM = 'sinavkutu-ana\t1\ndash\t0\ndashwatch\t0\nBASIRET\t1\nkalfa\t0\ngezgin\t0\ninatci\t1\ninatci2\t1\n';
writeFileSync(OTURUM, ILK_OTURUM);
const BIN = join(T, 'bin'); mkdirSync(BIN);
writeFileSync(join(BIN, 'tmux'), `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(TMUX_DEFTER)}\n`
  + `if [ "$1" = kill-session ] && [ "$2" = -t ]; then ad="\${3#=}"; [ "$ad" = inatci ] && exit 1\n`
  // inatci2: kapatma düşer VE kayıt dizini salt-okur olur → geri alma da düşer (bağımsız göz tur 1: hata yutuluyordu)
  + `  [ "$ad" = inatci2 ] && { chmod a-w ${JSON.stringify(join(T, 'proje/_agents/handoff'))}; exit 1; }\n`
  + `  grep -q "^$ad\t" ${JSON.stringify(OTURUM)} || exit 1; grep -v "^$ad\t" ${JSON.stringify(OTURUM)} > ${JSON.stringify(OTURUM)}.y; mv ${JSON.stringify(OTURUM)}.y ${JSON.stringify(OTURUM)}; exit 0; fi\nexit 0\n`, { mode: 0o755 });
const LISTE = join(T, 'liste.sh');
writeFileSync(LISTE, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nwhile IFS=$'\\t' read -r ad c; do [ -n "$ad" ] && printf '%s\\t5\\t%s\\tajan\\tbos\\t\\n' "$ad" "$c"; done < ${JSON.stringify(OTURUM)}\n`, { mode: 0o755 });
const AC = join(T, 'koltuk-ac.sh');
writeFileSync(AC, `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(AC_DEFTER)}\n[ "$1" = ac ] && printf '%s\\t1\\n' "$2" >> ${JSON.stringify(OTURUM)}\necho "açıldı: $2"\n`, { mode: 0o755 });
const PROJE = join(T, 'proje'), KAYIT = join(PROJE, '_agents/handoff/aile-registry.yaml');
mkdirSync(dirname(KAYIT), { recursive: true });
const ILK_KAYIT = 'uyeler:\n  - id: BASIRET\n    tmux: "BASIRET:0"\n    rol: "gözcü"\n    hal: calisiyor\n  - id: KALFA\n    tmux: "kalfa:0"\n    durum: canli   # elle not\n  - id: INATCI\n    tmux: "inatci:0"\n  - id: PANELCI\n    tmux: "dashwatch:0"\n  - id: INATCI2\n    tmux: "inatci2:0"\n';
writeFileSync(KAYIT, ILK_KAYIT);

const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, PATH: BIN + ':' + process.env.PATH, KAPI_PORT: String(PORT), KAPI_TABAN: '/sedir',
  TO_KUTU: 'sinavkutu', TO_PROJE: PROJE, KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE,
  KAPI_KOLTUK_BETIK: LISTE, KAPI_KOLTUK_AC_BETIK: AC, TO_ANA_TMUX: 'sinavkutu-ana', KAPI_EKIPC: '' }, stdio: ['ignore', 'ignore', 'pipe'] });
let hataCikti = ''; p.stderr.on('data', (d) => { hataCikti += d; });
// Sınav ne olursa olsun KENDİ sürecini öldürür (yetim kapı portu tutup sonraki koşuya cevap veriyordu — ölçüldü)
process.on('exit', () => { try { p.kill(); } catch {} });
process.on('uncaughtException', (e) => { console.log('  ✗ sınav çöktü: ' + e.message); try { p.kill(); } catch {} process.exit(1); });
for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch(`http://127.0.0.1:${PORT}/sedir/giris`)).status === 200) break; } catch {} }
// Cevap veren BU süreç mi: portu başka bir kapı tutuyorsa bizimki açılamaz ve çıkar
await new Promise((r) => setTimeout(r, 200));
if (p.exitCode !== null) { console.log('  ✗ kapı açılamadı (port dolu?) rc=' + p.exitCode + '\n' + hataCikti.slice(-400)); process.exit(1); }
const giris = await fetch(`http://127.0.0.1:${PORT}/sedir/giris`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parola: SIFRE }) });
const CEREZ = 'kapi=' + ((giris.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
const hal = async (govde, { cerez = CEREZ, xkapi = true, ek = {} } = {}) => {
  const r = await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro/hal`, { method: 'POST',
    headers: { 'content-type': 'application/json', ...(cerez ? { cookie: cerez } : {}), ...(xkapi ? { 'x-kapi': '1' } : {}), ...ek }, body: JSON.stringify(govde) });
  let j = {}; try { j = await r.json(); } catch {} return { s: r.status, j };
};
const kadro = async () => (await fetch(`http://127.0.0.1:${PORT}/sedir/api/kadro`, { headers: { cookie: CEREZ } })).json();
const tmuxIz = () => existsSync(TMUX_DEFTER) ? readFileSync(TMUX_DEFTER, 'utf8') : '';
const kayit = () => readFileSync(KAYIT, 'utf8');

console.log('── KH-A · kimlik: yalnız Sultan oturumu (çerez + başlık), jeton yolu yok');
kapi('KH1 çerezsiz → 401', (await hal({ eylem: 'kapat', oturum: 'gezgin' }, { cerez: '' })).s === 401);
kapi('KH2 çerezsiz + Bearer jeton → 401 (jeton kimlik sayılmaz)', (await hal({ eylem: 'kapat', oturum: 'gezgin' }, { cerez: '', ek: { authorization: 'Bearer ajan-jetonu' } })).s === 401);
kapi('KH3 çerez VAR ama Bearer/defter jetonu da taşıyor → 403 (jetonla gelen istek ajandır)', (await hal({ eylem: 'kapat', oturum: 'gezgin' }, { ek: { authorization: 'Bearer x' } })).s === 403 && (await hal({ eylem: 'kapat', oturum: 'gezgin' }, { ek: { 'x-defter-jeton': 'x' } })).s === 403);
kapi('KH4 x-kapi başlığı yok → 403 (sayfa dışı form gönderimi)', (await hal({ eylem: 'kapat', oturum: 'gezgin' }, { xkapi: false })).s === 403);
kapi('KH5 bu dört istekte tmux\'a HİÇ dokunulmadı', tmuxIz() === '');

console.log('── KH-B · altyapı negatif: kapat/dondur/emekli 403, tmux\'a dokunulmaz');
const a1 = await hal({ eylem: 'kapat', oturum: 'dash' }), a2 = await hal({ eylem: 'kapat', oturum: 'sinavkutu-ana' }), a3 = await hal({ eylem: 'kapat', oturum: 'ttyd-sinavkutu' }), a4 = await hal({ eylem: 'kapat', oturum: 'code-kurtarici' });
kapi('KH6 kapat: dash · ana · ttyd-* (listede bile yok) · *-kurtarici → 403, gerekçe Sultan dilinde', [a1, a2, a3, a4].every((x) => x.s === 403) && /mobil panel/.test(a1.j.hata) && /ana oturum/.test(a2.j.hata), JSON.stringify([a1, a2, a3, a4].map((x) => x.s + ' ' + x.j.hata)));
const a5 = await hal({ eylem: 'dondur', id: 'PANELCI' }), a6 = await hal({ eylem: 'emekli', id: 'PANELCI' });
kapi('KH7 kayıtlı ama koltuğu altyapı (dashwatch) olan kişiyi dondur/emekli → 403, kayıt değişmedi', a5.s === 403 && a6.s === 403 && kayit() === ILK_KAYIT, a5.s + ' ' + a6.s);
kapi('KH8 altyapı isteklerinde tmux\'a HİÇ dokunulmadı', tmuxIz() === '', tmuxIz());
const kd0 = await kadro();
kapi('KH9 /api/kadro: altyapı ayrı (ana · dash; kayıtlı dashwatch kişide altyapı etiketli), kayıtsızlar yalnız gezgin; eylemler: true', kd0.eylemler === true && kd0.altyapi.map((x) => x.ad).sort().join() === 'dash,sinavkutu-ana' && kd0.kayitsiz.map((x) => x.ad).join() === 'gezgin'
  && kd0.kisiler.find((x) => x.id === 'PANELCI').altyapi === 'mobil panel', JSON.stringify({ a: kd0.altyapi, ks: kd0.kayitsiz }));

console.log('── KH-C · kayıtsız oturumu kapat');
kapi('KH10 kayıtlı kişinin oturumunu "kapat" → 409 (dondur yolu), tmux\'a dokunulmadı', (await hal({ eylem: 'kapat', oturum: 'BASIRET' })).s === 409 && tmuxIz() === '');
const c1 = await hal({ eylem: 'kapat', oturum: 'gezgin' });
kapi('KH11 kayıtsız "gezgin" → 200, tmux kill-session -t =gezgin (tam ad eşleşmesi)', c1.s === 200 && tmuxIz().trim() === 'kill-session -t =gezgin', c1.s + ' ' + tmuxIz());
kapi('KH12 kapanmış oturumu tekrar kapat → 404', (await hal({ eylem: 'kapat', oturum: 'gezgin' })).s === 404);

console.log('── KH-D · dondur → geri aç (uçtan uca)');
const d1 = await hal({ eylem: 'dondur', id: 'BASIRET' });
kapi('KH13 dondur BASIRET → 200; kayıtta durum: dondurulmus + durum_once: yok; oturum kapatıldı', d1.s === 200 && kayit().includes('  - id: BASIRET\n    durum: dondurulmus\n    durum_once: yok\n') && /kill-session -t =BASIRET/.test(tmuxIz()), d1.s + ' ' + JSON.stringify(d1.j));
const kd1 = await kadro(); const B1 = kd1.kisiler.find((x) => x.id === 'BASIRET');
kapi('KH14 kadroda: geçici/emekli grubunda, hâl dondurulmus, geri açılır, oturumu yok', B1.grup === 'gecici-emekli' && B1.hal_kayit === 'dondurulmus' && B1.geri_acilir === true && B1.oturum === null, JSON.stringify(B1));
kapi('KH15 dondurulmuşu yeniden dondur → 409', (await hal({ eylem: 'dondur', id: 'BASIRET' })).s === 409);
const d2 = await hal({ eylem: 'geri-ac', id: 'BASIRET' });
kapi('KH16 geri aç → 200 oturum:true; açıcı "ac BASIRET --eski" (eski sohbetine döner)', d2.s === 200 && d2.j.oturum === true && readFileSync(AC_DEFTER, 'utf8').trim() === 'ac BASIRET --eski', JSON.stringify(d2.j));
kapi('KH17 kayıt BAYT BAYT ilk hâl', kayit() === ILK_KAYIT);
const B2 = (await kadro()).kisiler.find((x) => x.id === 'BASIRET');
kapi('KH18 kadroda yeniden çalışan (oturum açık, hal_kayit kaydın hal: alanından)', B2.grup === 'calisan' && B2.hal_kayit === 'calisiyor' && B2.oturum && B2.oturum.ad === 'BASIRET', JSON.stringify(B2));

console.log('── KH-E · emekli et → geri aç (oturum yeniden AÇILMAZ) · satır yorumu korunur');
const e1 = await hal({ eylem: 'emekli', id: 'KALFA' });
kapi('KH19 emekli KALFA → 200; durum: emekli (yorum kaldı) + durum_once: canli; oturumu kapatıldı', e1.s === 200 && kayit().includes('    durum: emekli   # elle not\n    durum_once: canli\n') && /kill-session -t =kalfa/.test(tmuxIz()), JSON.stringify(e1));
const acOnce = readFileSync(AC_DEFTER, 'utf8');
const e2 = await hal({ eylem: 'geri-ac', id: 'KALFA' });
kapi('KH20 emekliyi geri aç → kayıt BAYT BAYT ilk hâl, açıcı ÇAĞRILMADI (emeklilik oturum kararı değil)', e2.s === 200 && kayit() === ILK_KAYIT && readFileSync(AC_DEFTER, 'utf8') === acOnce, JSON.stringify(e2));

console.log('── KH-F · oturum kapatılamazsa kayıt geri alınır · geçersiz istekler');
const f1 = await hal({ eylem: 'dondur', id: 'INATCI' });
kapi('KH21 kill-session düşer → 502 ve kayıt BAYT BAYT ilk hâl (ekran "dondurulmuş" deyip oturum çalışmaz)', f1.s === 502 && kayit() === ILK_KAYIT, f1.s + ' ' + JSON.stringify(f1.j));
const f2 = await hal({ eylem: 'dondur', id: 'INATCI2' });
chmodSync(dirname(KAYIT), 0o755);
kapi('KH21b kapatma düşer + geri alma da düşer → 500 ve DÜRÜST cümle ("geri alınamadı … elle düzeltilmeli"), "döndürüldü" DENMEZ; iz kaydında GERI-ALINAMADI', f2.s === 500 && /geri alınamadı/.test(f2.j.hata) && /elle düzeltilmeli/.test(f2.j.hata) && !/döndürüldü/.test(f2.j.hata) && kayit().includes('  - id: INATCI2\n    durum: dondurulmus'), f2.s + ' ' + JSON.stringify(f2.j));
writeFileSync(KAYIT, ILK_KAYIT);
kapi('KH22 dondurulmamışı geri aç → 409 · bilinmeyen kişi → 404 · bilinmeyen eylem → 400', (await hal({ eylem: 'geri-ac', id: 'INATCI' })).s === 409 && (await hal({ eylem: 'dondur', id: 'YOK' })).s === 404 && (await hal({ eylem: 'sil', id: 'INATCI' })).s === 400);
const iz = existsSync(join(T, 'kadro-hal.log')) ? readFileSync(join(T, 'kadro-hal.log'), 'utf8') : '';
kapi('KH23 iz kaydı: her eylem tek satır (kapat · dondur · geri-ac · emekli · geri-al)', /kapat "gezgin"/.test(iz) && /dondur "BASIRET" -→dondurulmus/.test(iz) && /geri-ac "BASIRET" dondurulmus→-/.test(iz) && /emekli "KALFA" canli→emekli/.test(iz) && /geri-al "INATCI"/.test(iz) && /GERI-ALINAMADI "INATCI2"/.test(iz), iz);
p.kill();
if (k && hataCikti) console.log('kapı stderr:\n' + hataCikti.slice(-800));
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
