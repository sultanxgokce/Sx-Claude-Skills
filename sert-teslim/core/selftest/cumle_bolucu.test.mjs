// cumle_bolucu.test.mjs — deterministik cümle-bölücünün davranış-sözleşmesi testleri.
// Kapsam: paragraf-bölme, kısaltma-koruması, kod-bloğu/tablo atlaması, liste-maddesi,
// C-ID determinizmi (iki koşum), boşluk-normalize eşdeğerliği.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bol, SKILL_VERSION } from '../cumle_bolucu.mjs';

test('paragraf-bölme: tek paragraftaki iki cümle ayrı adaylara bölünür', () => {
  const sonuc = bol('Bu birinci cümledir. Bu da ikinci cümledir.', 'deneme.md');
  const paragraflar = sonuc.cumleler.filter((c) => c.tip === 'paragraf');
  assert.equal(paragraflar.length, 2);
  assert.equal(paragraflar[0].metin, 'Bu birinci cümledir.');
  assert.equal(paragraflar[1].metin, 'Bu da ikinci cümledir.');
  assert.equal(sonuc.kaynak_dosya, 'deneme.md');
});

test('kısaltma-koruması: bkz./ör./vb. noktaları cümle-sınırı sayılmaz', () => {
  const sonuc = bol('Detay için bkz. ilgili bölüm ve ör. ek liste vb. kaynaklar. İkinci cümle burada.');
  const paragraflar = sonuc.cumleler.filter((c) => c.tip === 'paragraf');
  assert.equal(paragraflar.length, 2);
  assert.ok(paragraflar[0].metin.includes('bkz. ilgili bölüm'));
  assert.ok(paragraflar[1].metin.startsWith('İkinci cümle'));
});

test('kod-bloğu-atlaması: çitli blok içeriği cümle-adayı olmaz, etiketle listelenir', () => {
  const girdi = [
    'Önce bir paragraf var.',
    '',
    '```',
    'kod satiri bir. kod satiri iki.',
    '```',
    '',
    'Sonra bir paragraf daha.',
  ].join('\n');
  const sonuc = bol(girdi);
  assert.ok(sonuc.cumleler.every((c) => !c.metin.includes('kod satiri')));
  const kod = sonuc.atlananlar.filter((a) => a.tip === 'kod-blogu');
  assert.ok(kod.length >= 1);
  assert.ok(kod.some((a) => a.metin.includes('kod satiri')));
});

test('tablo-atlaması + başlık-etiketi: tablo satırı aday olmaz, başlık tip=baslik ile listelenir', () => {
  const girdi = [
    '# Ana Baslik',
    '',
    '| a | b |',
    '|---|---|',
    '| 1 | 2 |',
    '',
    'Normal paragraf cümlesi.',
  ].join('\n');
  const sonuc = bol(girdi);
  const basliklar = sonuc.cumleler.filter((c) => c.tip === 'baslik');
  assert.equal(basliklar.length, 1);
  assert.equal(basliklar[0].metin, 'Ana Baslik');
  assert.equal(basliklar[0].satir_no, 1);
  const tablolar = sonuc.atlananlar.filter((a) => a.tip === 'tablo');
  assert.equal(tablolar.length, 3);
  assert.ok(sonuc.cumleler.some((c) => c.tip === 'paragraf' && c.metin === 'Normal paragraf cümlesi.'));
});

test('liste-maddesi: - / * / 1. maddeleri tip=liste birer cümle-adayıdır', () => {
  const girdi = ['- birinci madde', '* ikinci madde', '1. üçüncü madde'].join('\n');
  const sonuc = bol(girdi);
  const liste = sonuc.cumleler.filter((c) => c.tip === 'liste');
  assert.equal(liste.length, 3);
  assert.deepEqual(
    liste.map((c) => c.metin),
    ['birinci madde', 'ikinci madde', 'üçüncü madde'],
  );
  assert.deepEqual(liste.map((c) => c.satir_no), [1, 2, 3]);
});

test('C-ID determinizmi: aynı girdi iki koşumda aynı kimlikleri üretir, biçim C-<8 hex>', () => {
  const girdi = 'Deterministik kimlik denemesi. İkinci cümle de sabittir.\n\n- bir madde';
  const bir = bol(girdi);
  const iki = bol(girdi);
  assert.deepEqual(bir.cumleler.map((c) => c.c_id), iki.cumleler.map((c) => c.c_id));
  for (const c of bir.cumleler) assert.match(c.c_id, /^C-[0-9a-f]{8}$/);
  // farklı metin -> farklı kimlik (çakışma-duyarlılığı için asgari kontrol)
  assert.notEqual(bir.cumleler[0].c_id, bir.cumleler[1].c_id);
});

test('boşluk-normalize: çoklu boşluk tek boşluğa iner, C-ID değişmez, harf-büyüklüğü korunur', () => {
  const a = bol('Bu   bir    Deneme.');
  const b = bol('Bu bir Deneme.');
  assert.equal(a.cumleler[0].metin, 'Bu bir Deneme.'); // verbatim korunur, yalnız boşluk-normalize
  assert.equal(a.cumleler[0].c_id, b.cumleler[0].c_id);
  // lowercase YAPILMAZ: büyük harf farkı kimliği değiştirmeli
  const c = bol('bu bir deneme.');
  assert.notEqual(a.cumleler[0].c_id, c.cumleler[0].c_id);
});

test('frontmatter-atlaması: dosya-başı --- ... --- bloğu cümle-adayı OLMAZ, atlananlar-frontmatter', () => {
  const girdi = [
    '---',
    'feature: "x"',
    'vites: HAFIF',
    '---',
    '',
    'Gerçek gereklilik cümlesi burada.',
  ].join('\n');
  const sonuc = bol(girdi);
  // frontmatter içindeki hiçbir satır cümleye girmez
  assert.ok(!sonuc.cumleler.some((c) => c.metin.includes('feature')));
  assert.ok(!sonuc.cumleler.some((c) => c.metin.includes('vites')));
  // gerçek cümle YAKALANIR (frontmatter-sonrası)
  assert.ok(sonuc.cumleler.some((c) => c.metin === 'Gerçek gereklilik cümlesi burada.'));
  // frontmatter satırları atlananlar'da etiketli (açılış+kapanış+içerik = 4 satır)
  const fm = sonuc.atlananlar.filter((a) => a.tip === 'frontmatter');
  assert.equal(fm.length, 4);
});

test('frontmatter-yok: dosya --- ile başlamıyorsa normal işlenir (kapanış-arayışı false-yemez)', () => {
  const sonuc = bol('İlk cümle. İkinci cümle.');
  assert.equal(sonuc.atlananlar.filter((a) => a.tip === 'frontmatter').length, 0);
  assert.equal(sonuc.cumleler.filter((c) => c.tip === 'paragraf').length, 2);
});

test('tematik-ayraç: tek-başına --- / *** / ___ cümle-adayı OLMAZ (atlananlar-tematik-ayrac)', () => {
  const girdi = ['Birinci bölüm cümlesi.', '', '---', '', 'İkinci bölüm cümlesi.', '', '***'].join('\n');
  const sonuc = bol(girdi);
  const ayraclar = sonuc.atlananlar.filter((a) => a.tip === 'tematik-ayrac');
  assert.equal(ayraclar.length, 2); // --- ve ***
  // ayraç metne sızmaz; iki gerçek cümle korunur
  assert.ok(!sonuc.cumleler.some((c) => c.metin === '---' || c.metin === '***'));
  assert.equal(sonuc.cumleler.filter((c) => c.tip === 'paragraf').length, 2);
});

test('tematik-ayraç liste-maddesiyle karışmaz: "- madde" liste kalır, "---" ayraç olur', () => {
  const sonuc = bol(['- gerçek liste maddesi', '---'].join('\n'));
  assert.equal(sonuc.cumleler.filter((c) => c.tip === 'liste').length, 1);
  assert.equal(sonuc.atlananlar.filter((a) => a.tip === 'tematik-ayrac').length, 1);
});

test('sürüm-damgası sabiti dışa açıktır', () => {
  assert.equal(SKILL_VERSION, '0.2.1-faz1');
});
