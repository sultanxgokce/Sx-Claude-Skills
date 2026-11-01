// rutbe.test.mjs — koltuk rütbesinin kayıttan türetilmesi (kart rutbe-koltuk-alani). Hermetik; fikstürler gerçek merkez ve NAZIR kayıt biçiminde.
import { rutbeHaritasi, rutbeBul } from './rutbe.mjs';
import { koltukEsle, kayitOdaHaritasi } from './oda.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const MERKEZ = [{ id: 'SERDAR', oda: 'agentic-os', oda_muduru: 'evet', tmux: 'serdar:0' }, { id: 'MUAVİN', oda: 'agentic-os', tmux: 'muavin:0' }, { id: 'YAVER', amir: 'MUAVİN', tmux: 'yaver:0' },
  { id: 'BÂNİ', oda: 'agentic-os', amir: 'SERDAR', tmux: 'bani:0' }, { id: 'BERİD', oda: 'mesajlasma', oda_muduru: 'evet', amir: 'SERDAR', tmux: 'berid:0' },
  { id: 'BENNÂ', amir: 'BÂNİ', tmux: 'benna:0' }, { id: 'MÜZEHHİP', amir: 'BÂNİ', tmux: 'muzehhip:0' }, { id: 'MİRAHUR', amir: 'SERDAR', tmux: 'MIRAHUR:0' },
  { id: 'EMANETÇİ', tmux: 'emanetci:0' }, { id: 'ESKİ', amir: 'BÂNİ', durum: 'emekli', tmux: 'eski:0' }, { id: 'KAYIP', amir: 'OLMAYAN', tmux: 'kayip:0' }];
const m = rutbeHaritasi(MERKEZ);
kapi('R1 amiri boş oda müdürü reis', m.get('serdar')?.kademe === 'reis' && !m.get('serdar').amir);
kapi('R2 altı olan üye müdür, amiri koltuk adıyla, görünen adıyla gelir', m.get('bani')?.kademe === 'oda müdürü' && m.get('bani').amir === 'serdar' && m.get('bani').amir_ad === 'SERDAR', JSON.stringify(m.get('bani')));
kapi('R3 oda müdürü alanı altı olmasa da müdür yapar', m.get('berid')?.kademe === 'oda müdürü');
kapi('R4 personel amirine bağlanır, diakritik fark engel değil', m.get('benna')?.kademe === 'personel' && m.get('benna').amir === 'bani' && m.get('muzehhip')?.amir_ad === 'BÂNİ');
kapi('R5 büyük harfli tmux adı korunur', m.get('MIRAHUR')?.kademe === 'personel');
kapi('R6 bilgisiz üyeye rütbe uydurulmaz', !m.has('emanetci'));
kapi('R7 emekli üye sayılmaz', !m.has('eski'));
kapi('R8 çözülemeyen amir: rütbe yok, sahte bağ yok', !m.has('kayip'), JSON.stringify(m.get('kayip')));
kapi('R9 amiri boş ama altı olan üye reis değil müdürdür', m.get('muavin')?.kademe === 'oda müdürü');
const NAZIR = [{ id: 'nazir-yon', ad: 'ŞEHBENDER', oda: 'nezaret', oda_muduru: 'evet', amir: 'Sultan', tmux: 'nazir-yon:0' }, { id: 'nazir-seyyah', ad: 'CİHANNÜMA', oda: 'hermes', amir: 'ŞEHBENDER', tmux: 'cihannuma:0' },
  { id: 'nazir-kilavuz', ad: 'KILAVUZ', oda: 'hermes', amir: 'CİHANNÜMA', tmux: 'kilavuz:0' }, { id: 'nazir-mizanci', ad: 'MİZANCI', oda: 'hermes', amir: 'CİHANNÜMA', tmux: 'mizanci:0' }];
const n = rutbeHaritasi(NAZIR);
kapi('R10 amiri Sultan olan reis', n.get('nazir-yon')?.kademe === 'reis');
kapi('R11 kimlik ile görünen ad farklıyken amir görünen addan çözülür', n.get('kilavuz')?.amir === 'cihannuma' && n.get('kilavuz').amir_ad === 'CİHANNÜMA' && n.get('cihannuma')?.kademe === 'oda müdürü' && n.get('cihannuma').amir === 'nazir-yon', JSON.stringify(n.get('kilavuz')));
kapi('R12 katlanmış adla bulur', rutbeBul(m, 'BENNA').kademe === 'personel');
kapi('R13 reisin koltuğu açık değilse bile ana koltuğa rütbe düşmez (Sultan kararı)', !rutbeBul(n, 'nazir-ana').kademe && !rutbeBul(n, 'nazir-ana', { ana: 'nazir-ana', acik: ['nazir-ana', 'cihannuma'] }).kademe);
kapi('R14 reisin kendi koltuğu hâlâ reis', rutbeBul(n, 'nazir-yon').kademe === 'reis');
kapi('R15 boş kayıt boş harita, hata yok', rutbeHaritasi(undefined).size === 0 && !rutbeBul(new Map(), 'x').kademe);
const CANLI = [{ id: 'nazir-yon', ad: 'ŞEHBENDER', amir: 'Sultan', oda_muduru: 'evet', oda: 'nezaret', tmux: 'nazir-yon:0' }, { id: 'nazir-rasatci', ad: 'RASATÇI', amir: 'ŞEHBENDER', oda_muduru: 'evet', oda: 'omnirouter', tmux: 'nazir-rasatci:0' },
  { id: 'nazir-seyyah', ad: 'CİHANNÜMA', amir: 'ŞEHBENDER', oda_muduru: 'evet', oda: 'hermes', tmux: 'nazir-seyyah:0' }, { id: 'nazir-seritdar', ad: 'ŞERİTDAR', amir: 'ŞEHBENDER', oda: 'nezaret', tmux: 'nazir-seritdar:0' }, { id: 'nazir-mim', ad: 'MÜSTENSİH', amir: 'CİHANNÜMA', oda: 'hermes', tmux: 'nazir-mim:0' }];
const ACIK = ['nazir-yon', 'rasatci', 'cihannuma', 'seritdar'], c = rutbeHaritasi(CANLI, ACIK), co = kayitOdaHaritasi(CANLI, ACIK);
kapi('R16 kayıttaki tmux eski, müdür canlı koltuğuna adından bağlanır', c.get('rasatci')?.kademe === 'oda müdürü' && c.get('cihannuma')?.kademe === 'oda müdürü' && c.get('cihannuma')?.amir === 'nazir-yon', JSON.stringify([...c]));
kapi('R17 oda da canlı koltuğa bağlanır', co.get('rasatci') === 'omnirouter' && co.get('seritdar') === 'nezaret' && co.get('cihannuma') === 'hermes' && co.get('nazir-yon') === 'nezaret', JSON.stringify([...co]));
kapi('R18 kapalı koltuğun rütbesi eski adında kalır, açık koltuğa uydurulmaz', c.get('nazir-mim')?.amir === 'cihannuma'  && !c.has('mustensih'));
const SAHIP = koltukEsle([{ id: 'a', ad: 'BOSTAN', tmux: 'kapali:0' }, { id: 'b', ad: 'BAŞKA', tmux: 'bostan:0' }], ['bostan']);
kapi('R19 açık koltuğu kayıtlı sahibinden adıyla kimse alamaz', [...SAHIP.entries()].every(([u, k]) => (u.id === 'b') === (k === 'bostan')), JSON.stringify([...SAHIP.values()]));
kapi('R20 acik verilmeyen eski çağrı aynen çalışır', rutbeHaritasi(CANLI).has('nazir-rasatci') && kayitOdaHaritasi(CANLI).get('nazir-rasatci') === 'omnirouter');
const EMEKLI = [{ id: 'eski', ad: 'RASATÇI', durum: 'emekli', oda: 'hermes', tmux: 'eski:0' }, { id: 'yeni', ad: 'YENİ', oda: 'nezaret', tmux: 'rasatci:0' }];
kapi('R21 emekli üye adıyla açık koltuğun odasını alamaz', kayitOdaHaritasi(EMEKLI, ['rasatci']).get('rasatci') === 'nezaret' && !koltukEsle(EMEKLI, ['rasatci']).has(EMEKLI[0]));
kapi('R22 emekli üyenin koltuğu boşken de açık koltuğa bağlanmaz', !kayitOdaHaritasi([EMEKLI[0]], ['rasatci']).has('rasatci'));
console.log(`geçen ${g} · kalan ${k}`); process.exit(k ? 1 : 0);
