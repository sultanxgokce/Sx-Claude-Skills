// kadro.test.mjs — kayıt ⟂ koltuk birleşimi (hermetik: fikstür metin + geçici dizin; tmux yok, ağ yok)
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { kayitAyristir, kayitOku, kadroBirlestir, HAL_KAYIT } from './kadro.mjs';
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
kapi('C7 ana koltuk kayıtta yok → kişilerde "(kimliği yok)" olarak, kayıtsızlara DÜŞMEZ', r.kisiler.some((x) => x.ana && x.tmux === 'sedir-ana' && x.rol === '(kimliği yok)' && x.grup === 'calisan') && !r.kayitsiz.some((x) => x.ad === 'sedir-ana'));
kapi('C8 kayıtsız oturumlar: revak-yon (Claude var, soru) ve 20 (boş kabuk)', r.kayitsiz.map((x) => x.ad).sort().join() === '20,revak-yon' && r.kayitsiz.find((x) => x.ad === 'revak-yon').hal === 'soru');
kapi('C9 sayılar gruba göre', JSON.stringify(r.sayilar) === JSON.stringify({ calisan: 3, dusen: 1, 'kayitta-var-calismiyor': 2, 'gecici-emekli': 1, kayitsiz: 2 }), JSON.stringify(r.sayilar));
const r2 = kadroBirlestir({ uyeler: [], koltuklar, ana: 'sedir-ana' });
kapi('C10 kayıt yoksa herkes kayıtsız (ana hariç) — kayıt uydurulmaz', r2.kisiler.length === 1 && r2.kayitsiz.length === 6);
const r3 = kadroBirlestir({ uyeler: kayitAyristir(`uyeler:\n  - id: A\n    tmux: "x:0"\n  - id: B\n    tmux: "x:0"\n`), koltuklar: koltukSatirlari('x\t1\t1\tajan\tbos\t\n'), ana: '' });
kapi('C11 aynı tmux iki kayıtta: oturum İLKİNE bağlanır, ikincisi oturumsuz (bir koltuk iki kişiye verilmez)', r3.kisiler[0].oturum && r3.kisiler[1].oturum === null && r3.kayitsiz.length === 0);
const r4 = kadroBirlestir({ uyeler: kayitAyristir(`uyeler:\n  - id: YIL\n    tmux: "2026:0"\n  - id: ONYEDI\n    tmux: "17:0"\n`), koltuklar: koltukSatirlari('20\t1\t1\tajan\tbos\t\n2026\t2\t1\tajan\tbos\t\n'), ana: '' });
kapi('C12 sayısal adlar kırpılmaz: "2026:0" yalnız "2026"a bağlanır, "17" hiçbir koltuğa; "20" kayıtsız kalır (göz tur 1)', r4.kisiler[0].oturum && r4.kisiler[0].oturum.ad === '2026' && r4.kisiler[1].oturum === null && r4.kayitsiz.length === 1 && r4.kayitsiz[0].ad === '20', JSON.stringify(r4));
console.log('── D · okunamayan kayıt dosyası');
// kayıt YOLU var ama okunamıyor: dosya yerine DİZİN (EISDIR) — root dahil her kullanıcıda deterministik (göz tur 2: chmod 000 root'ta işlemiyordu)
const kilit = join(T, 'kilit'); mkdirSync(join(kilit, '_agents/handoff/aile-registry.yaml'), { recursive: true });
const e = kayitOku(kilit);
kapi('D1 var olan ama okunamayan kayıt → okunamadi dolu, kaynak boş (sessiz boş kadro yok; uç 500 verir)', e.okunamadi.length === 1 && e.kaynak.length === 0 && e.uyeler.length === 0, JSON.stringify(e));
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
