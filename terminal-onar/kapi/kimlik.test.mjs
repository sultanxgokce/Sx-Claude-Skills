// kimlik.test.mjs — kişi↔oturum eşleşmesinin kimlik ayağı (hermetik: sahte oturum dizini + sahte /proc; gerçek kapı süreci uçtan uca).
// SERDAR 16 Eki 00:4x negatif sınavı: kimliği ANA oturumda olan kişi "çalışıyor" çıkmalı, "oturumu yok" çıkmamalı; ana ikinci satır olmamalı.
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { oturumKimlikleri } from './kimlik.mjs';
import { kayitAyristir, kadroBirlestir } from './kadro.mjs';
import { koltukSatirlari } from './koltuklar.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const T = mkdtempSync(join(tmpdir(), 'kimlik-'));
const ALAN = 'pid:[4026531111]';
const OT = join(T, 'sessions'), PROC = join(T, 'proc'); mkdirSync(OT); mkdirSync(PROC);
const surec = (pid, arg0) => { mkdirSync(join(PROC, String(pid)), { recursive: true }); writeFileSync(join(PROC, String(pid), 'cmdline'), arg0 + '\0--resume\0x\0'); };
const dosya = (pid, o) => writeFileSync(join(OT, pid + '.json'), JSON.stringify({ pid: String(pid), pidDomain: 'linux::' + ALAN, ...o }));
dosya(101, { sessionId: 'S-YON', tmux: 'kutu-ana:@1.%1', name: 'kutu-3f', nameSource: 'derived' }); surec(101, 'claude');
dosya(102, { sessionId: 'S-SERDAR', tmux: 'serdar:@2.%2', name: 'serdar', nameSource: 'user' }); surec(102, '/usr/local/bin/claude');
dosya(103, { sessionId: 'S-BASKA', tmux: 'baska:@3.%3', name: 'x', nameSource: 'derived', pidDomain: 'linux::pid:[999]' }); surec(103, 'claude');   // başka kutu
dosya(104, { sessionId: 'S-OLU', tmux: 'olu:@4.%4', name: 'x', nameSource: 'derived' });                                                         // süreç yok
dosya(105, { sessionId: 'S-YENI', tmux: 'yeni:@5.%5', name: 'x', nameSource: 'derived' }); surec(105, 'bash');                                    // pid başka programa geçmiş
writeFileSync(join(OT, 'bozuk.json'), '{'); writeFileSync(join(OT, '106.json'), '{bozuk');
// 099.json içine YAŞAYAN 101'in pid'i yazılmış taklit (başka oturum adıyla). Dizin okuma sırası belirsiz olduğu için (gerçek 101.json
// önce okunursa taklit zaten "görüldü"ye takılır — sınav sıraya bağlı kalırdı, mutasyonda ölçüldü) taklit AYRI dizinde tek başına da sınanır.
const OT2 = join(T, 'sessions-taklit'); mkdirSync(OT2);
writeFileSync(join(OT2, '099.json'), JSON.stringify({ pid: '101', pidDomain: 'linux::' + ALAN, sessionId: 'S-TAKLIT', tmux: 'taklit:@9.%9', name: 'x', nameSource: 'derived' }));

console.log('── K · oturum kimlikleri (kimlik.mjs)');
const kim = oturumKimlikleri({ dizinler: [OT, join(T, 'yok')], procKok: PROC, pidAlani: ALAN });
kapi('K1 yalnız bu kutunun, yaşayan, programı claude olan süreçleri: kutu-ana + serdar', [...kim.keys()].sort().join() === 'kutu-ana,serdar', JSON.stringify([...kim]));
kapi('K2 başka pid alanı · ölmüş süreç · pid\'i başka programa geçmiş · bozuk dosya SAYILMAZ', !kim.has('baska') && !kim.has('olu') && !kim.has('yeni'));
kapi('K3 tmux "oturum:@N.%N" → oturum adı; sessionId + ad + ad kaynağı taşınır', kim.get('kutu-ana')[0].sessionId === 'S-YON' && kim.get('serdar')[0].adKaynak === 'user');
const kimT = oturumKimlikleri({ dizinler: [OT2], procKok: PROC, pidAlani: ALAN }), kimTO = oturumKimlikleri({ dizinler: [OT2, OT], procKok: PROC, pidAlani: ALAN });
kapi('K2b dosya adı ≠ içindeki pid (099.json içinde yaşayan 101) → tek başına SAYILMAZ; taklit önce okunsa da gerçek 101.json gölgelenmez', kimT.size === 0 && !kimTO.has('taklit') && kimTO.get('kutu-ana')[0].sessionId === 'S-YON', JSON.stringify([...kimT, ...kimTO]));
kapi('K4 pid alanı okunamazsa (boş) HİÇBİR dosya sayılmaz (ortak dizinde başka kutuya bağlanmaz)', oturumKimlikleri({ dizinler: [OT], procKok: PROC, pidAlani: '' }).size === 0);

console.log('── E · eşleşme: önce kimlik, sonra tmux adı');
const KAYIT = 'uyeler:\n  - id: kutu-yon\n    tmux: "kutu-yon:0"\n    session_id: "S-YON"\n  - id: SERDAR\n    tmux: "eski-serdar:0"\n  - id: MIM\n    tmux: "mim:0"\n';
const LISTE = 'kutu-ana\t1\t1\tajan\tcalisiyor\t\nserdar\t1\t1\tajan\tsoru\t\nmim\t1\t1\tajan\tbos\t\ndash\t1\t0\tdiger\tbilinmiyor\t\n';
const r = kadroBirlestir({ uyeler: kayitAyristir(KAYIT), koltuklar: koltukSatirlari(LISTE), ana: 'kutu-ana', kimlikler: kim });
const K = (id) => r.kisiler.find((x) => x.id === id);
kapi('E1 (SERDAR negatif sınavı) kimliği ANA oturumda olan kişi "çalışıyor", oturumu kutu-ana, eşleşme kimlikle — "oturumu yok" DEĞİL', K('kutu-yon').grup === 'calisan' && K('kutu-yon').oturum && K('kutu-yon').oturum.ad === 'kutu-ana' && K('kutu-yon').eslesme === 'kimlik', JSON.stringify(K('kutu-yon')));
kapi('E2 ana ikinci satır OLMAZ: ne altyapıda ne kayıtsızlarda "kutu-ana"; tek satır', !r.altyapi.some((x) => x.ad === 'kutu-ana') && !r.kayitsiz.some((x) => x.ad === 'kutu-ana') && r.kisiler.filter((x) => x.oturum && x.oturum.ad === 'kutu-ana').length === 1, JSON.stringify({ a: r.altyapi, ks: r.kayitsiz }));
kapi('E3 kişi ana oturumda çalışıyorsa altyapı korumalı ("ana oturum") — dondur/emekli onu kapatamaz', K('kutu-yon').altyapi === 'ana oturum');
kapi('E4 kullanıcının verdiği Claude adı (serdar, nameSource user) kayıttaki tmux eski olsa da bağlar', K('SERDAR').oturum && K('SERDAR').oturum.ad === 'serdar' && K('SERDAR').eslesme === 'kimlik');
kapi('E5 kimlik izi olmayan kişi eski kuralla (tmux adı) bağlanır, eslesme alanı yok', K('MIM').oturum && K('MIM').oturum.ad === 'mim' && !K('MIM').eslesme);
const r0 = kadroBirlestir({ uyeler: kayitAyristir(KAYIT), koltuklar: koltukSatirlari(LISTE), ana: 'kutu-ana' });
kapi('E6 kimlik verilmezse bugünkü davranış: kutu-yon "kayıtta var, çalışmıyor", ana altyapıda (iki satır — düzeltilen kusur)', r0.kisiler.find((x) => x.id === 'kutu-yon').grup === 'kayitta-var-calismiyor' && r0.altyapi.some((x) => x.ad === 'kutu-ana'));
const iki = new Map([['a', [{ sessionId: 'S', ad: '', adKaynak: '' }]], ['b', [{ sessionId: 'S', ad: '', adKaynak: '' }]]]);
const r2 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: X\n    tmux: "a:0"\n    session_id: "S"\n'), koltuklar: koltukSatirlari('a\t1\t1\tajan\tbos\t\nb\t1\t1\tajan\tbos\t\n'), ana: '', kimlikler: iki });
kapi('E7 aynı kimlik İKİ oturumda → kimlik eşleşmesi yapılmaz (tahmin yok), tmux adına düşer', r2.kisiler[0].oturum.ad === 'a' && !r2.kisiler[0].eslesme);
const cak = new Map([['a', [{ sessionId: 'S', ad: 'x', adKaynak: 'derived' }]], ['b', [{ sessionId: 'Q', ad: 'X', adKaynak: 'user' }]]]);
const r5 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: X\n    tmux: "c:0"\n    session_id: "S"\n'), koltuklar: koltukSatirlari('a\t1\t1\tajan\tbos\t\nb\t1\t1\tajan\tbos\t\n'), ana: '', kimlikler: cak });
kapi('E7b session_id A oturumunu, verilen ad B oturumunu gösteriyor → session_id KAZANIR (basamaklar sıralı), B kayıtsız kalır', r5.kisiler[0].oturum && r5.kisiler[0].oturum.ad === 'a' && r5.kisiler[0].eslesme === 'kimlik' && r5.kayitsiz.map((x) => x.ad).join() === 'b', JSON.stringify(r5));
const r6 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: X\n    tmux: "c:0"\n    session_id: "YOK"\n'), koltuklar: koltukSatirlari('b\t1\t1\tajan\tbos\t\n'), ana: '', kimlikler: cak });
kapi('E7c session_id hiçbir canlı oturumda yoksa (bayat) ad basamağına inilir', r6.kisiler[0].oturum && r6.kisiler[0].oturum.ad === 'b' && r6.kisiler[0].eslesme === 'kimlik');
const yaris = new Map([['b', [{ sessionId: 'SB', ad: 'A', adKaynak: 'user' }]]]);
const r7 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: A\n    tmux: "a:0"\n  - id: B\n    tmux: "zz:0"\n    session_id: "SB"\n'), koltuklar: koltukSatirlari('a\t1\t1\tajan\tbos\t\nb\t1\t1\tajan\tbos\t\n'), ana: '', kimlikler: yaris });
const A7 = r7.kisiler.find((x) => x.id === 'A'), B7 = r7.kisiler.find((x) => x.id === 'B');
kapi('E7d kayıtta ÖNCE gelen A ad ile, SONRA gelen B session_id ile aynı oturuma talip → session_id kazanır (B ← b), A tmux adına düşer (A ← a)', B7.oturum && B7.oturum.ad === 'b' && B7.eslesme === 'kimlik' && A7.oturum && A7.oturum.ad === 'a' && !A7.eslesme, JSON.stringify(r7.kisiler));
const r3 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: Y\n    tmux: "y:0"\n'), koltuklar: koltukSatirlari('y\t1\t1\tajan\tbos\t\n'), ana: '', kimlikler: new Map([['y', [{ sessionId: 'Q', ad: 'Y', adKaynak: 'derived' }]]]) });
kapi('E8 türetilmiş (derived) ad kimlik sayılmaz — yalnız kullanıcının verdiği ad', !r3.kisiler[0].eslesme && r3.kisiler[0].oturum.ad === 'y');

console.log('── U · uçtan uca: gerçek kapı süreci, sahte oturum dizini + sahte /proc');
const KOK = fileURLToPath(new URL('.', import.meta.url));
const PROJE = join(T, 'proje'); mkdirSync(join(PROJE, '_agents/handoff'), { recursive: true }); writeFileSync(join(PROJE, '_agents/handoff/aile-registry.yaml'), KAYIT);
const LB = join(T, 'liste.sh'); writeFileSync(LB, `#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf '${LISTE.replace(/\t/g, '\\t').replace(/\n/g, '\\n')}'\n`, { mode: 0o755 });
const BIN = join(T, 'bin'); mkdirSync(BIN); const TD = join(T, 'tmux-defter');
writeFileSync(join(BIN, 'tmux'), `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(TD)}\nexit 0\n`, { mode: 0o755 });
const SIFRE = 'sinav-parolasi-1234', PORT = 18799;
const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], { env: { ...process.env, PATH: BIN + ':' + process.env.PATH, KAPI_PORT: String(PORT), KAPI_TABAN: '/kutu', TO_KUTU: 'sinavkutu',
  TO_PROJE: PROJE, KAPI_TTYD_SOKET: join(T, 'ttyd.sock'), TO_DURUM_DIZ: T, SINAVKUTU__TERMINAL_SIFRE: SIFRE, KAPI_KOLTUK_BETIK: LB, TO_ANA_TMUX: 'kutu-ana',
  KAPI_OTURUM_DIZ: OT, KAPI_PROC_KOK: PROC, KAPI_PID_ALANI: ALAN }, stdio: ['ignore', 'ignore', 'pipe'] });
process.on('exit', () => { try { p.kill(); } catch {} });
for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch(`http://127.0.0.1:${PORT}/kutu/giris`)).status === 200) break; } catch {} }
await new Promise((r) => setTimeout(r, 200));
if (p.exitCode !== null) { console.log('  ✗ kapı açılamadı rc=' + p.exitCode); process.exit(1); }
const gr = await fetch(`http://127.0.0.1:${PORT}/kutu/giris`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parola: SIFRE }) });
const C = 'kapi=' + ((gr.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
const j = await (await fetch(`http://127.0.0.1:${PORT}/kutu/api/kadro`, { headers: { cookie: C } })).json();
const Y = j.kisiler.find((x) => x.id === 'kutu-yon');
kapi('U1 /api/kadro: kutu-yon çalışan, oturumu kutu-ana (kimlikle), ana ikinci satır değil; düşen/kayıtta-var sayısı 0', Y.grup === 'calisan' && Y.oturum.ad === 'kutu-ana' && Y.eslesme === 'kimlik' && !j.altyapi.some((x) => x.ad === 'kutu-ana') && j.sayilar['kayitta-var-calismiyor'] === 0, JSON.stringify({ Y, s: j.sayilar }));
const d = await fetch(`http://127.0.0.1:${PORT}/kutu/api/kadro/hal`, { method: 'POST', headers: { 'content-type': 'application/json', cookie: C, 'x-kapi': '1' }, body: JSON.stringify({ eylem: 'dondur', id: 'kutu-yon' }) });
kapi('U2 ana oturumda çalışan kişiyi dondur → 403 (ana kapatılmaz), kayıt ve tmux dokunulmadı', d.status === 403 && readFileSync(join(PROJE, '_agents/handoff/aile-registry.yaml'), 'utf8') === KAYIT && !existsSync(TD), String(d.status));
p.kill();
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
