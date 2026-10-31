// kadro.test.mjs — kayıt ⟂ koltuk birleşimi (hermetik: fikstür metin + geçici dizin; tmux yok, ağ yok)
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { kayitAyristir, kayitOku, kadroBirlestir, HAL_KAYIT, altyapiNeden } from './kadro.mjs';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { koltukSatirlari } from './koltuklar.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };

console.log('── A · kayıt ayrıştırma');
const AILE = `meta:\n  aile: SERDAR\nuyeler:\n  - id: SERDAR\n    tmux: "serdar:0"   # yorum\n    mod: kod\n    rol: "yönetici"\n  - id: BERİD\n    tmux: 'berid:0'\n    mod: kod\n    hal: calisiyor\n  - id: ESKI\n    tmux: eski:0\n    hal: emekli\n    rol: eski üye\n  - id: TMUXSUZ\n    tmux: null\n    hal: saçma\n`;
const a = kayitAyristir(AILE);
kapi('A1 dört üye, üç tırnak biçimi de okunur', a.length === 4 && a[0].tmux === 'serdar:0' && a[1].tmux === 'berid:0' && a[2].tmux === 'eski:0', JSON.stringify(a));
kapi('A2 rol/mod/hal alanları; yorum atılır', a[0].rol === 'yönetici' && a[0].mod === 'kod' && a[1].hal === 'calisiyor' && a[2].hal === 'emekli');
kapi('A3 tmux: null → boş; bilinmeyen hal metni olduğu gibi (küme kapısı birleşimde)', a[3].tmux === '' && a[3].hal === 'saçma');
kapi('A4 HAL_KAYIT kapalı küme: calisiyor gecici yedek emekli', HAL_KAYIT.join() === 'calisiyor,gecici,yedek,emekli');

console.log('── B · kayıt dosyaları (İSKÂN + işaretli ekip kaydı · merkez aile kaydı · hiç yok)');
const T = mkdtempSync(join(tmpdir(), 'kadro-'));
const iskan = join(T, 'iskan'); mkdirSync(join(iskan, '_agents/handoff'), { recursive: true });
writeFileSync(join(iskan, 'iskan-registry.yaml'), `proje: iskan\nekip_registry_pointer: _agents/handoff/ekip-registry.yaml\nuyeler:\n  - id: REIS\n    tmux: "cc-aee5:0"\n    cwd: /x\n    rol: "bayat rol"\n    hal: emekli\n  - id: KATIP\n    tmux: "katip:0"\n`);
writeFileSync(join(iskan, '_agents/handoff/ekip-registry.yaml'), `uyeler:\n  - id: REIS\n    tmux: "reis:0"\n    mod: motor\n    rol: "başkâtip"\n    hal: calisiyor\n  - id: KATIP\n    mod: kod\n    rol: "kâtip"\n    hal: gecici\n  - id: YALNIZ_EKIPTE\n    tmux: "ye:0"\n    rol: "ekipte var iskanda yok"\n`);
const b = kayitOku(iskan);
kapi('B1 iki kaynak okundu (iskan + işaretli ekip kaydı)', b.kaynak.length === 2 && b.kaynak[0].endsWith('iskan-registry.yaml') && b.kaynak[1].endsWith('ekip-registry.yaml'), JSON.stringify(b.kaynak));
const reis = b.uyeler.find((u) => u.id === 'REIS'), katip = b.uyeler.find((u) => u.id === 'KATIP');
kapi('B2 tmux İSKÂN kaydından (ilk kaynak kazanır), rol/mod/hal ekip kaydından', reis.tmux === 'cc-aee5:0' && reis.rol === 'başkâtip' && reis.mod === 'motor' && katip.tmux === 'katip:0' && katip.hal === 'gecici', JSON.stringify(b.uyeler));
kapi('B2b ÇATIŞMADA alan önceliği: tmux İSKÂN\'dan kalır, rol/hal ekip kaydı ÜSTÜNE yazar ("bayat rol"/emekli → "başkâtip"/calisiyor) (göz tur 3)', reis.tmux === 'cc-aee5:0' && reis.rol === 'başkâtip' && reis.hal === 'calisiyor' && reis.cwd === '/x', JSON.stringify(reis));
kapi('B3 yalnız ekip kaydında olan üye de kadroda', !!b.uyeler.find((u) => u.id === 'YALNIZ_EKIPTE'));
const merkez = join(T, 'merkez'); mkdirSync(join(merkez, '_agents/handoff'), { recursive: true }); writeFileSync(join(merkez, '_agents/handoff/aile-registry.yaml'), AILE);
const c = kayitOku(merkez);
kapi('B4 merkez: aile kaydı tek kaynak', c.kaynak.length === 1 && c.uyeler.length === 4);
const bos = join(T, 'bos'); mkdirSync(bos);
const d = kayitOku(bos);
kapi('B5 kayıt yok → kaynak boş, üye boş (uydurma yok)', d.kaynak.length === 0 && d.uyeler.length === 0 && d.okunamadi.length === 0);

console.log('── C · birleşim: dört grup + kayıtsız + ana');
// koltuk-bagla --liste 6 sütun: ad · son · claude · tür · hâl · ne
const LISTE = 'sedir-ana\t1760000000\t1\tdiger\tbos\t\nserdar\t1760000100\t1\tajan\tcalisiyor\t\nBERID\t1760000200\t1\tajan\tdis-olay\tCI bekleniyor\neski\t5\t1\tajan\tbos\t\nkatip\t7\t0\tajan\tbilinmiyor\t\nrevak-yon\t9\t1\tdiger\tsoru\t\n20\t3\t0\tdiger\tbilinmiyor\t\n';
const koltuklar = koltukSatirlari(LISTE);
const uyeler = kayitAyristir(AILE + `  - id: KATIP\n    tmux: "katip:0"\n    rol: kâtip\n  - id: MIMAR\n    tmux: "mimar:0"\n    rol: mimar\n`);
const r = kadroBirlestir({ uyeler, koltuklar, ana: 'sedir-ana' });
const G = (id) => r.kisiler.find((x) => x.id === id);
kapi('C1 kayıtlı + oturum var + Claude var → çalışan (hâl ve ne taşınır)', G('SERDAR').grup === 'calisan' && G('SERDAR').oturum.hal === 'calisiyor');
kapi('C2 tmux adı casing farkı (berid ↔ BERID) yine eşleşir; dış olay hâli + ne', G('BERİD').grup === 'calisan' && G('BERİD').oturum.ad === 'BERID' && G('BERİD').oturum.hal === 'dis-olay' && G('BERİD').oturum.ne === 'CI bekleniyor', JSON.stringify(G('BERİD')));
kapi('C3 kayıtlı + oturum açık + Claude YOK → DÜŞEN (asıl düşen; bekçinin canlı saydığı)', G('KATIP').grup === 'dusen' && G('KATIP').oturum.claude === false);
kapi('C4 kayıtlı + oturum yok + hal yok → kayıtta var çalışmıyor, hal_kayit bilinmiyor (uydurma yok)', G('MIMAR').grup === 'kayitta-var-calismiyor' && G('MIMAR').oturum === null && G('MIMAR').hal_kayit === 'bilinmiyor');
kapi('C5 hal: emekli → geçici/emekli grubu — oturumu olsa bile düşen/çalışan sayılmaz', G('ESKI').grup === 'gecici-emekli' && G('ESKI').oturum && G('ESKI').oturum.ad === 'eski');
kapi('C6 geçersiz hal metni (saçma) → bilinmiyor; tmux yok → kayıtta var çalışmıyor', G('TMUXSUZ').hal_kayit === 'bilinmiyor' && G('TMUXSUZ').grup === 'kayitta-var-calismiyor');
kapi('C7 ana koltuk kayıtta yok → ALTYAPI listesinde (ana oturum), ne kişilerde ne kayıtsızlarda (E2: kırmızı "boş oturum" değil)', r.altyapi.some((x) => x.ana && x.ad === 'sedir-ana' && x.altyapi === 'ana oturum') && !r.kisiler.some((x) => x.tmux === 'sedir-ana') && !r.kayitsiz.some((x) => x.ad === 'sedir-ana'), JSON.stringify(r.altyapi));
kapi('C8 kayıtsız oturumlar: revak-yon (Claude var, soru) ve 20 (boş kabuk)', r.kayitsiz.map((x) => x.ad).sort().join() === '20,revak-yon' && r.kayitsiz.find((x) => x.ad === 'revak-yon').hal === 'soru');
kapi('C9 sayılar gruba göre', JSON.stringify(r.sayilar) === JSON.stringify({ calisan: 2, dusen: 1, 'kayitta-var-calismiyor': 2, 'gecici-emekli': 1, kayitsiz: 2, altyapi: 1 }), JSON.stringify(r.sayilar));
const r2 = kadroBirlestir({ uyeler: [], koltuklar, ana: 'sedir-ana' });
kapi('C10 kayıt yoksa herkes kayıtsız (ana altyapıda) — kayıt uydurulmaz', r2.kisiler.length === 0 && r2.kayitsiz.length === 6 && r2.altyapi.length === 1);
const r3 = kadroBirlestir({ uyeler: kayitAyristir(`uyeler:\n  - id: A\n    tmux: "x:0"\n  - id: B\n    tmux: "x:0"\n`), koltuklar: koltukSatirlari('x\t1\t1\tajan\tbos\t\n'), ana: '' });
kapi('C11 aynı tmux iki kayıtta: oturum İLKİNE bağlanır, ikincisi oturumsuz (bir koltuk iki kişiye verilmez)', r3.kisiler[0].oturum && r3.kisiler[1].oturum === null && r3.kayitsiz.length === 0);
const r4 = kadroBirlestir({ uyeler: kayitAyristir(`uyeler:\n  - id: YIL\n    tmux: "2026:0"\n  - id: ONYEDI\n    tmux: "17:0"\n`), koltuklar: koltukSatirlari('20\t1\t1\tajan\tbos\t\n2026\t2\t1\tajan\tbos\t\n'), ana: '' });
kapi('C12 sayısal adlar kırpılmaz: "2026:0" yalnız "2026"a bağlanır, "17" hiçbir koltuğa; "20" kayıtsız kalır (göz tur 1)', r4.kisiler[0].oturum && r4.kisiler[0].oturum.ad === '2026' && r4.kisiler[1].oturum === null && r4.kayitsiz.length === 1 && r4.kayitsiz[0].ad === '20', JSON.stringify(r4));
console.log('── E · E2: altyapı etiketi · dondurulmuş · üretilmiş kayıt durumu');
const LISTE2 = 'kutu-ana\t1\t0\tdiger\tbilinmiyor\t\ndash\t1\t0\tdiger\tbilinmiyor\t\ndashproxy\t1\t0\tdiger\tbilinmiyor\t\ndashwatch\t1\t0\tdiger\tbilinmiyor\t\ncode-kurtarici\t1\t1\tajan\tbos\t\nttyd-x\t1\t0\tdiger\tbilinmiyor\t\nkapi-kutu\t1\t0\tdiger\tbilinmiyor\t\nimglistener2\t1\t0\tdiger\tbilinmiyor\t\ndashboard-deneme\t1\t0\tdiger\tbilinmiyor\t\ndon\t1\t1\tajan\tbos\t\n';
const e2 = kadroBirlestir({ uyeler: kayitAyristir('uyeler:\n  - id: DON\n    tmux: "don:0"\n    hal: calisiyor\n    durum: dondurulmus\n    durum_once: canli\n  - id: ESK\n    tmux: "esk:0"\n    durum: emekli\n'), koltuklar: koltukSatirlari(LISTE2), ana: 'kutu-ana' });
kapi('E1 sekiz altyapı oturumu ayrı listede, gerekçeli; kayıtsız yalnız "dashboard-deneme" (önek benzerliği altyapı sayılmaz)', e2.altyapi.length === 8 && e2.kayitsiz.map((x) => x.ad).join() === 'dashboard-deneme' && e2.altyapi.find((x) => x.ad === 'dash').altyapi === 'mobil panel' && e2.altyapi.find((x) => x.ad === 'code-kurtarici').altyapi === 'kurtarıcı ajan', JSON.stringify(e2.altyapi.map((x) => x.ad + '=' + x.altyapi)));
kapi('E2 durum: dondurulmus kaydın hal: calisiyor satırını ÖRTER → geçici/emekli grubu, oturumu açık olsa bile; geri_acilir (durum_once var)', e2.kisiler[0].hal_kayit === 'dondurulmus' && e2.kisiler[0].grup === 'gecici-emekli' && e2.kisiler[0].geri_acilir === true, JSON.stringify(e2.kisiler[0]));
kapi('E3 durum: emekli ama durum_once yok → geri_acilir false (neyin geri konacağı bilinmiyor)', e2.kisiler[1].hal_kayit === 'emekli' && e2.kisiler[1].geri_acilir === false);
kapi('E4 sayılar: altyapı ayrı sayılır, kayıtsız 1', e2.sayilar.altyapi === 8 && e2.sayilar.kayitsiz === 1);
// koltuk-bagla.sh gizli() kalıplarının her örneği altyapı sayılmalı (kabuk listesi genişlerse koruma düşmesin)
const KB = readFileSync(fileURLToPath(new URL('../scripts/koltuk-bagla.sh', import.meta.url)), 'utf8');
const kaliplar = ((KB.match(/^gizli\(\)\s*\{\s*case "\$1" in ([^)]*)\)/m) || [])[1] || '').split('|').map((x) => x.trim()).filter(Boolean);
const ornek = (k) => k.replace(/^\*/, 'ornek').replace(/\*$/, 'ornek');
kapi('E5 koltuk-bagla gizli() kalıplarının hepsi altyapı (eşdeğerlik; kalıp okunamazsa kırmızı)', kaliplar.length >= 4 && kaliplar.every((k) => altyapiNeden(ornek(k))), JSON.stringify(kaliplar));
// Üretilmiş kutu (aile dalı): aile kaydı + ekipc ekip kaydı (yalnız durum) + model (yalnız durum_once)
const ur = join(T, 'uretilmis'); mkdirSync(join(ur, '_agents/handoff'), { recursive: true }); mkdirSync(join(ur, '_agents/ekip-os'), { recursive: true });
writeFileSync(join(ur, '_agents/handoff/aile-registry.yaml'), 'uyeler:\n- id: u-yon\n  tmux: u-yon:0\n  rol: defteri akıtmak\n- id: u-mim\n  tmux: u-mim:0\n  rol: plan\n');
writeFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), '# <!-- ekipc:uretilen:basla surum=1 hash=x -->\nuyeler:\n  - id: u-yon\n    rol: MÜDÜR\n    durum: dondurulmus\n    tmux: null\n  - id: u-mim\n    rol: MİMAR\n    durum: canli\n  - id: u-yeni\n    rol: KÂŞİF\n    durum: canli\n# <!-- ekipc:uretilen:bitti -->\n');
writeFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'roller:\n- ad: MÜDÜR\n  olcek:\n    ornekler:\n    - kayit: u-yon\n      durum: dondurulmus\n      durum_once: canli\n');
const u = kayitOku(ur); const uy = u.uyeler.find((x) => x.id === 'u-yon'), um = u.uyeler.find((x) => x.id === 'u-mim');
kapi('E6 aile dalı + üretilmiş ekip kaydı: durum ekip kaydından, rol/tmux aile kaydından KALIR, yeni üye EKLENMEZ', uy.durum === 'dondurulmus' && uy.rol === 'defteri akıtmak' && uy.tmux === 'u-yon:0' && um.rol === 'plan' && !u.uyeler.some((x) => x.id === 'u-yeni') && u.kaynak.length === 2, JSON.stringify(u));
kapi('E7 durum_once ekip modelinden (derleyici taşımıyor) → geri_acilir', uy.durum_once === 'canli' && kadroBirlestir({ uyeler: u.uyeler, koltuklar: [], ana: '' }).kisiler.find((x) => x.id === 'u-yon').geri_acilir === true);
console.log('── D · okunamayan kayıt dosyası');
// kayıt YOLU var ama okunamıyor: dosya yerine DİZİN (EISDIR) — root dahil her kullanıcıda deterministik (göz tur 2: chmod 000 root'ta işlemiyordu)
const kilit = join(T, 'kilit'); mkdirSync(join(kilit, '_agents/handoff/aile-registry.yaml'), { recursive: true });
const e = kayitOku(kilit);
kapi('D1 var olan ama okunamayan kayıt → okunamadi dolu, kaynak boş (sessiz boş kadro yok; uç 500 verir)', e.okunamadi.length === 1 && e.kaynak.length === 0 && e.uyeler.length === 0, JSON.stringify(e));
const pn = (h) => koltukSatirlari(`a\t1\t1\tajan\tbos\t\t\t\t/d\t${h}\n`)[0].pencere;
kapi('PN3 pencere sütunu sayıya çevrilir', JSON.stringify(pn('118x53')) === '{"sutun":118,"satir":53}', JSON.stringify(pn('118x53')));
kapi('PN4 boş ya da bozuk boy alan yazmaz (uydurma yok, telefon eski kipte kalır)', ['', '0x53', '118', 'x', '118x0', '99999x5', '1;2x3'].every((h) => pn(h) === undefined));
kapi('PN5 eski 9 sütunlu kapı satırında alan yok', koltukSatirlari('a\t1\t1\tajan\tbos\t\t\t\t/d\n')[0].pencere === undefined);
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
