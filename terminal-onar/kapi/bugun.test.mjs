// bugun.test.mjs — çıpa ayrıştırma + kutu listesi (hermetik: geçici dizin, fikstür metin; tmux yok, ağ yok) + mutasyon.
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { cipaAyristir, bugunOku, sayilar, DURUM } from './bugun.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const HERE = dirname(fileURLToPath(import.meta.url));

console.log('── A · çıpa ayrıştırma (cipa.sh biçimi, gerçek örnekten)');
const CIPA = `# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17

> Bu dosya compact/kesinti sonrası planın geri okunduğu yerdir.

## Maddeler
- [x] 1) Haftalık retro: 9 ders → 11 görev deftere → KAPANDI · 11 görev deftere D1'li; BÂNİ #672 birleşti
- [~] 2) Federe gelen 42 istek triyajı (MUAVİN) → YARIM · triyaj 234 kapandı; akşam Sultan'a
- [ ] 4) ENİS kasa K1-K4 kararı + BASİRET SIHHAT tarihi Sultan'a
- [-] 3) eski madde → GERİ ALINDI
- [x] G1) Retro'yu Sultan'la değerlendir → KAPANDI · 14:5x konuşuldu
- [ ] G6) Bugünün listesi paneli (BÂNİ acil, gorev_01M54SCQE08KTG9YERG2BBR604) ve gorev_01M54SCQE08KTG9YERG2BBR604 ile ilişkili gorev_01M54T2ENRNVGXFZ421SFPMSQJ
- [ ] serbest madde, etiketi yok
- bu satır madde değil
- [?] 9) bilinmeyen işaret

_yazıldı: 2026-10-17T10:47:25+03:00_
_dokunuldu: 2026-10-17T14:59:13+03:00_
`;
const c = cipaAyristir(CIPA);
kapi('A1 tarih başlıktan', c.tarih === '2026-10-17', c.tarih);
kapi('A2 yedi madde (bilinmeyen işaret ve düz satır madde değil)', c.maddeler.length === 7, String(c.maddeler.length));
const m1 = c.maddeler[0], m2 = c.maddeler[1], m4 = c.maddeler[2], m3 = c.maddeler[3], g1 = c.maddeler[4], g6 = c.maddeler[5], sb = c.maddeler[6];
kapi('A3 sabah maddesi: etiket 1, tür sabah, durum bitti, metin kuyruksuz, sonuç KAPANDI, not ayrı', m1.etiket === '1' && m1.tur === 'sabah' && m1.durum === 'bitti' && m1.metin === 'Haftalık retro: 9 ders → 11 görev deftere' && m1.sonuc === 'KAPANDI' && m1.not.startsWith('11 görev'), JSON.stringify(m1));
kapi('A4 yarım madde [~] → yarim, sonuç YARIM', m2.durum === 'yarim' && m2.sonuc === 'YARIM' && m2.not.includes('triyaj'));
kapi('A5 açık madde: sonuç/not boş, metin tam', m4.durum === 'acik' && m4.sonuc === '' && m4.metin.startsWith('ENİS kasa'));
kapi('A6 geri alınan [-] → geri, sonuç GERİ ALINDI', m3.durum === 'geri' && m3.sonuc === 'GERİ ALINDI' && m3.metin === 'eski madde');
kapi('A7 gün ortası G1) → tür gun-ortasi', g1.etiket === 'G1' && g1.tur === 'gun-ortasi' && g1.durum === 'bitti');
kapi('A8 havuz bağı: gorev_ kimlikleri tekilleştirilmiş (iki kimlik)', g6.gorevler.length === 2 && g6.gorevler[0] === 'gorev_01M54SCQE08KTG9YERG2BBR604' && g6.gorevler[1] === 'gorev_01M54T2ENRNVGXFZ421SFPMSQJ', JSON.stringify(g6.gorevler));
kapi('A9 etiketsiz madde → tür serbest', sb.tur === 'serbest' && sb.etiket === '' && sb.metin.startsWith('serbest madde'));
kapi('A10 damgalar (sondaki _ soyulur)', c.yazildi === '2026-10-17T10:47:25+03:00' && c.dokunuldu === '2026-10-17T14:59:13+03:00', c.yazildi + ' ' + c.dokunuldu);
const s = sayilar(c.maddeler);
kapi('A11 sayılar: 3 açık · 1 yarım · 2 bitti · 1 geri · 7 toplam', s.acik === 3 && s.yarim === 1 && s.bitti === 2 && s.geri === 1 && s.toplam === 7, JSON.stringify(s));
kapi('A12 DURUM kapalı küme (boş · ~ · x · X · -)', Object.keys(DURUM).join('') === ' ~xX-');

console.log('── D · 1.5.0 dilbilgisi (Sx gunluk-plan/sema/bugun-maddesi.md: sahip · kanıt · ertelendi) — fikstür kapısı T17 #357\'de');
const CIPA2 = `# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17

## Maddeler
- [x] 1) Retro paketi (sahip: MUAVİN) gorev_01M54C4A56HDMS1H5SAWFCWSGE → KAPANDI · iki tur · kanıt: cloudtop #669
- [~] 2) Gelen kutusu triyajı (sahip: MUAVİN) → YARIM · 234 kapandı
- [ ] 3) WhatsApp izin kalıcılığı (sahip: Sultan)
- [-] 4) Eski kanal düzeltmesi → GERİ ALINDI · gerekmedi
- [-] 5) Sunum provası (sahip: MUAVİN) → ERTELENDİ · D1: 2026-10-17 Sultan: ertele (sohbet · session_ornek · "bunu yarına bırak" · beyan:MUAVİN)
- [-] 6) Damgasız erteleme → ERTELENDİ · yarın bakarız
- [x] 7) Kanıtı iki parça → KAPANDI · kanıt: Sx #355 · not ortada · kanıt: cloudtop #675
`;
const d = cipaAyristir(CIPA2).maddeler;
kapi('D1 sahip metinden ayrılır: metin "Retro paketi gorev_…", sahip MUAVİN', d[0].sahip === 'MUAVİN' && d[0].metin === 'Retro paketi gorev_01M54C4A56HDMS1H5SAWFCWSGE', JSON.stringify([d[0].sahip, d[0].metin]));
kapi('D2 kanıt nottan ayrılır: kanit "cloudtop #669", not "iki tur"', d[0].kanit === 'cloudtop #669' && d[0].not === 'iki tur', JSON.stringify([d[0].kanit, d[0].not]));
kapi('D3 sahipsiz madde: sahip boş, metin dokunulmaz', d[3].sahip === '' && d[3].metin === 'Eski kanal düzeltmesi' && d[3].durum === 'geri');
kapi('D4 sahip var, sonuç yok: açık madde, not/kanit boş', d[2].sahip === 'Sultan' && d[2].durum === 'acik' && d[2].kanit === '' && d[2].not === '');
kapi('D5 "-" + ERTELENDİ + geçerli D1 → durum ertelendi (geri DEĞİL)', d[4].durum === 'ertelendi' && d[4].sonuc === 'ERTELENDİ' && d[4].not.startsWith('D1: 2026-10-17 Sultan'), d[4].durum);
kapi('D6 "-" + ERTELENDİ + D1 YOK → damgasız erteleme açık sayılır (acik)', d[5].durum === 'acik' && d[5].sonuc === 'ERTELENDİ' && d[5].not === 'yarın bakarız', d[5].durum);
kapi('D7 iki kanıt parçası birleşir, not ayrı kalır', d[6].kanit === 'Sx #355 · cloudtop #675' && d[6].not === 'not ortada', JSON.stringify([d[6].kanit, d[6].not]));
const s2 = sayilar(d);
kapi('D8 sayılar: ertelendi 1 · acik 2 (damgasız erteleme dahil) · geri 1 · yarim 1 · bitti 2 · toplam 7', s2.ertelendi === 1 && s2.acik === 2 && s2.geri === 1 && s2.yarim === 1 && s2.bitti === 2 && s2.toplam === 7, JSON.stringify(s2));
kapi('D9 eski biçim (A fikstürü) sahip/kanit alanlarını boş taşır, kırılmaz', 'sahip' in m1 && 'kanit' in m1 && m1.sahip === '' && m1.kanit === '');
const bos = cipaAyristir('');
kapi('A13 boş metin: tarih null, madde 0 (çökmez)', bos.tarih === null && bos.maddeler.length === 0);

console.log('── B · kutu listesi (dizin tarama: bugün · bugün değil · yedek · eski tek dosya · okunamayan)');
const T = mkdtempSync(join(tmpdir(), 'bugun-')); const H = join(T, '_agents/handoff'); mkdirSync(H, { recursive: true });
writeFileSync(join(H, 'gunluk-plan-cipa.serdar.md'), CIPA);
writeFileSync(join(H, 'gunluk-plan-cipa.bani.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-14\n\n- [~] 1) eski gün\n');
writeFileSync(join(H, 'gunluk-plan-cipa.muavin.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17\n\n- [ ] 1) tek açık madde gorev_01ABCDEFGHJKMNPQRSTVWXYZ\n');
writeFileSync(join(H, 'gunluk-plan-cipa.20261002-MUAVIN.yedek.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17\n- [ ] 1) yedek, taranmaz\n');
writeFileSync(join(H, 'gunluk-plan-cipa.md'), '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-10-17\n- [ ] 1) eski tek dosya, taranmaz\n');
mkdirSync(join(H, 'gunluk-plan-cipa.bozuk.md'));   // dizin: okunamaz
const b = bugunOku(T, '2026-10-17');
kapi('B1 bugünkü iki ajan (muavin · serdar), alfabetik', b.ajanlar.map((a) => a.ajan).join(',') === 'muavin,serdar', JSON.stringify(b.ajanlar.map((a) => a.ajan)));
kapi('B2 başka günün çıpası listeye girmez ama bugun_degil\'de adıyla ve tarihiyle görünür', b.bugun_degil.length === 1 && b.bugun_degil[0].ajan === 'bani' && b.bugun_degil[0].tarih === '2026-10-14', JSON.stringify(b.bugun_degil));
kapi('B3 yedek ve eski tek dosya taranmaz', !JSON.stringify(b).includes('taranmaz'));
kapi('B4 okunamayan dosya okunamadi\'da (sessiz atlama yok)', b.okunamadi.length === 1 && b.okunamadi[0].dosya === 'gunluk-plan-cipa.bozuk.md', JSON.stringify(b.okunamadi));
kapi('B5 toplam sayılar iki ajanın birleşimi (4 açık = 3 + 1)', b.toplam.acik === 4 && b.toplam.toplam === 8, JSON.stringify(b.toplam));
kapi('B6 ajan başına sayılar ve dosya adı', b.ajanlar[1].sayilar.bitti === 2 && b.ajanlar[1].dosya === 'gunluk-plan-cipa.serdar.md');
const yok = bugunOku(join(T, 'yok'), '2026-10-17');
kapi('B7 handoff dizini yoksa var=false, çökmez', yok.var === false && yok.ajanlar.length === 0);

console.log('── C · MUTASYON (kopyada): tarih kapısı · yedek süzgeci · kuyruk ayrımı kaldırılınca sınav kırmızı');
const kaynak = readFileSync(join(HERE, 'bugun.mjs'), 'utf8');
async function mutant(ad, eski, yeni) {
  const s2 = kaynak.replace(eski, yeni); if (s2 === kaynak) throw new Error('desen tutmadı: ' + eski);
  const y = join(T, ad + '.mjs'); writeFileSync(y, s2); return import(pathToFileURL(y).href);
}
const M1 = await mutant('m1', "if (c.tarih !== gun) {", "if (false) {");
kapi('C1 tarih kapısı kaldırılınca eski gün listeye GİRER → B1/B2 bu mutantta düşerdi', M1.bugunOku(T, '2026-10-17').ajanlar.length === 3);
const M2 = await mutant('m2', "&& !/\\.yedek\\.md$/.test(a)", "");
kapi('C2 yedek süzgeci kaldırılınca yedek dosya listeye girer → B3 bu mutantta düşerdi', JSON.stringify(M2.bugunOku(T, '2026-10-17')).includes('yedek, taranmaz'));
const M3 = await mutant('m3', "metin: bas.replace(SAHIP, '').trim(),", "metin: govde,");
kapi('C3 kuyruk ayrımı kaldırılınca metin "→ KAPANDI"yı taşır → A3 bu mutantta düşerdi', M3.cipaAyristir(CIPA).maddeler[0].metin.includes('KAPANDI'));

const M4 = await mutant('m4', "if (m[1] === '-' && sonuc === 'ERTELENDİ') durum = D1.test(not) ? 'ertelendi' : 'acik';", "if (m[1] === '-' && sonuc === 'ERTELENDİ') durum = 'ertelendi';");
kapi('C4 D1 kapısı kaldırılınca damgasız erteleme de "ertelendi" olur → D6 bu mutantta düşerdi', M4.cipaAyristir(CIPA2).maddeler[5].durum === 'ertelendi');
const M5 = await mutant('m5', "metin: bas.replace(SAHIP, '').trim(), sahip: sh ? sh[1].trim() : '',", "metin: bas.trim(), sahip: '',");
kapi('C5 sahip ayrımı kaldırılınca "(sahip: …)" metinde kalır → D1 bu mutantta düşerdi', M5.cipaAyristir(CIPA2).maddeler[0].metin.includes('(sahip:'));
const M6 = await mutant('m6', "const kanit = parca.filter((x) => x.startsWith('kanıt:'))", "const kanit = parca.filter((x) => false)");
kapi('C6 kanıt ayrımı kaldırılınca kanit boş → D2 bu mutantta düşerdi', M6.cipaAyristir(CIPA2).maddeler[0].kanit === '');

console.log(`\n── SONUÇ: ${g} geçti · ${k} kaldı ──`); process.exit(k ? 1 : 0);
