// a4_dogrula.test.mjs — A4-MUTABAKAT sayımsal-doğrulayıcının sözleşmesi (MUTABAKAT-motoru testi).
// Karar SCRIPT'in: her C-ID tam-1-kez, normatif→≥1-m_ref, uydurma/eksik-yasağı, matris↔A4 self-tutarlılık.
// Fixture: mkdtemp'e cumleler.json + eslesme.json + MATRIS.md kurulur.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { dogrula } from '../a4_dogrula.mjs';

const KOLON_BASLIK =
  '| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |';
const KOLON_AYRAC = '|---|---|---|---|---|---|---|---|---|---|';

function kur({ cumleler, tablo, matrisSatirlari }) {
  const dizin = mkdtempSync(join(tmpdir(), 'a4-test-'));
  const cumlelerYolu = join(dizin, 'cumleler.json');
  const eslesmeYolu = join(dizin, 'eslesme.json');
  const matrisYolu = join(dizin, 'MATRIS.md');
  writeFileSync(cumlelerYolu, JSON.stringify({ cumleler }));
  writeFileSync(eslesmeYolu, JSON.stringify({ tablo }));
  writeFileSync(matrisYolu, [KOLON_BASLIK, KOLON_AYRAC, ...matrisSatirlari, ''].join('\n'));
  return { dizin, cumlelerYolu, eslesmeYolu, matrisYolu };
}

function mSatiri(mId, cId) {
  return `| ${mId} | ${cId} | cümle | arayuz-1 | komut | \`printf ok\` | - | sentetik | bekliyor | kanit/${mId}.json |`;
}

const temizle = (d) => rmSync(d, { recursive: true, force: true });

test('temiz: her C-ID sınıflı + normatif→M-eşli + matris↔A4 tutarlı -> gecti=true', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }, { c_id: 'C-2', tip: 'paragraf', metin: 'b' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M1'] }, { c_id: 'C-2', normatif: false, gerekce: 'meta' }],
    matrisSatirlari: [mSatiri('M1', 'C-1')],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, true);
    assert.deepEqual(r.ihlaller, []);
    assert.equal(r.normatif_degil.length, 1);
  } finally { temizle(dizin); }
});

test('uydurma-satır: A4 kaynak-dışı C-ID üretemez -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M1'] }, { c_id: 'C-UYDURMA', normatif: false, gerekce: 'x' }],
    matrisSatirlari: [mSatiri('M1', 'C-1')],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('uydurma-satır') && i.includes('C-UYDURMA')));
  } finally { temizle(dizin); }
});

test('çift-sınıflandırma: aynı C-ID iki kez -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M1'] }, { c_id: 'C-1', normatif: false, gerekce: 'x' }],
    matrisSatirlari: [mSatiri('M1', 'C-1')],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('çift-sınıflandırma')));
  } finally { temizle(dizin); }
});

test('eşlenmemiş-normatif: normatif ama m_refs boş (gereklilik-atlaması) -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: [] }],
    matrisSatirlari: [],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('eşlenmemiş-normatif')));
  } finally { temizle(dizin); }
});

test('kırık-ref: normatif m_ref matris-te YOK -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M9'] }],
    matrisSatirlari: [mSatiri('M1', 'C-1')],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('kırık-ref') && i.includes('M9')));
  } finally { temizle(dizin); }
});

test('eksik-sınıflandırma: kaynak-cümle A4-tablosunda hiç yok -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }, { c_id: 'C-2', tip: 'liste', metin: 'b' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M1'] }], // C-2 sınıflandırılmadı
    matrisSatirlari: [mSatiri('M1', 'C-1')],
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('eksik-sınıflandırma') && i.includes('C-2')));
  } finally { temizle(dizin); }
});

test('matris-uydurma-C-ID: matris-satırı kaynak-listede-olmayan C-ID çıpalıyor -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M1'] }],
    matrisSatirlari: [mSatiri('M1', 'C-HAYALET')], // matris C-HAYALET diyor, cumleler'de yok
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('matris-uydurma-C-ID')));
  } finally { temizle(dizin); }
});

test('matris↔A4 tutarsız: matris "M1←C-1" ama A4 C-1 için m_refs M1 içermiyor -> ihlal', () => {
  const { dizin, ...y } = kur({
    cumleler: [{ c_id: 'C-1', tip: 'liste', metin: 'a' }, { c_id: 'C-2', tip: 'liste', metin: 'b' }],
    tablo: [{ c_id: 'C-1', normatif: true, m_refs: ['M2'] }, { c_id: 'C-2', normatif: false, gerekce: 'x' }],
    matrisSatirlari: [mSatiri('M1', 'C-1')], // matris M1←C-1 ama A4 C-1→[M2]
  });
  try {
    const r = dogrula(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('matris↔A4 tutarsız')));
  } finally { temizle(dizin); }
});
