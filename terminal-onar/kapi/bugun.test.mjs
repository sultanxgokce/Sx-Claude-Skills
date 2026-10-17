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
const M3 = await mutant('m3', "metin: (k ? k[1] : govde).trim(),", "metin: govde,");
kapi('C3 kuyruk ayrımı kaldırılınca metin "→ KAPANDI"yı taşır → A3 bu mutantta düşerdi', M3.cipaAyristir(CIPA).maddeler[0].metin.includes('KAPANDI'));

console.log(`\n── SONUÇ: ${g} geçti · ${k} kaldı ──`); process.exit(k ? 1 : 0);
