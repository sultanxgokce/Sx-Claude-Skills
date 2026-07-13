// sayac_baseline.test.mjs — §1.5 sayaç-baseline denetçisinin sözleşmesi (MOTOR, gaming-kilit).
// KAPATILAN DELİK: per-M `-t <filtre>` koşumu skipped üretip gate-geçebiliyordu. İki mekanizma:
//   (1) HASH-SABİT: gate-kanıtının komut_sha256'sı baseline-deklarasyonuyla AYNI olmalı → filtreli-komut
//       (farklı-sha256) uyuşmazlıktan FAIL; (2) COUNTER-FLOOR: collected>=min ∧ skipped<=max.
// + SAYAÇ-KANITSIZ: hiç sayaçlı-runner yoksa flag (teslim-lint manşet basar).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { baselineDenetle } from '../sayac_baseline.mjs';

const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');

function kur({ baselineGateler, kanitlar }) {
  const dizin = mkdtempSync(join(tmpdir(), 'sayac-baseline-'));
  const kanitDizini = join(dizin, 'kanit');
  mkdirSync(kanitDizini, { recursive: true });
  const baselineYolu = join(dizin, 'baseline.json');
  writeFileSync(baselineYolu, JSON.stringify({ olusturuldu: '2026-01-01T00:00:00Z', gate_cmds: baselineGateler }));
  for (const [id, kanit] of Object.entries(kanitlar)) {
    writeFileSync(join(kanitDizini, `gate-${id}.json`), JSON.stringify(kanit));
  }
  return { dizin, baselineYolu, kanitDizini };
}

// yardımcı: geçerli gate-kanıtı (trust_boundary şeması)
function gateKanit(komut, { rc = 0, counters = null, runner = 'generic-rc' } = {}) {
  return { komut, komut_sha256: sha256(komut), rc, counters, runner, started_at: '2026-01-01T00:00:00Z', finished_at: '2026-01-01T00:01:00Z' };
}

const temizle = (d) => rmSync(d, { recursive: true, force: true });

test('temiz: hash-eşleşir + collected>=min + skipped<=max -> gecti=true', () => {
  const komut = 'cd backend && run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: sha256(komut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: { 'be-test': gateKanit(komut, { runner: 'pytest', counters: { collected: 100, passed: 100, failed: 0, skipped: 0 } }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, true, JSON.stringify(r.ihlaller));
    assert.equal(r.sayac_kanitsiz, false);
  } finally { temizle(dizin); }
});

test('HASH-UYUŞMAZLIĞI (asıl-delik): filtreli-komut kanıtı (farklı sha256) -> İHLAL', () => {
  const tamKomut = 'run all tests';
  const filtreliKomut = 'run all tests -t SF2a'; // per-M filtre → farklı sha256
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut: tamKomut, komut_sha256: sha256(tamKomut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    // kanıt filtreli-komutla üretilmiş: hash tamKomut'unkiyle uyuşmaz
    kanitlar: { 'be-test': gateKanit(filtreliKomut, { runner: 'pytest', counters: { collected: 100, passed: 1, failed: 0, skipped: 99 } }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('hash-uyuşmazlığı') || i.includes('komut_sha256')));
  } finally { temizle(dizin); }
});

test('SKIPPED-DELTA: skipped>max_skipped -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: sha256(komut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: { 'be-test': gateKanit(komut, { runner: 'pytest', counters: { collected: 100, passed: 96, failed: 0, skipped: 4 } }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('skipped')));
  } finally { temizle(dizin); }
});

test('COLLECTED-DÜŞÜŞ: collected<min_collected -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: sha256(komut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: { 'be-test': gateKanit(komut, { runner: 'pytest', counters: { collected: 80, passed: 80, failed: 0, skipped: 0 } }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('collected')));
  } finally { temizle(dizin); }
});

test('SAYAÇ-KANITSIZ: counter-runner baseline ama kanıt counters=null (parse-fail asla PASS) -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: sha256(komut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: { 'be-test': gateKanit(komut, { runner: 'pytest', counters: null }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.toLowerCase().includes('sayaç') || i.includes('counters')));
  } finally { temizle(dizin); }
});

test('gate-kanıtı-yok: baseline entry var ama kanit/gate-<id>.json yok -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: sha256(komut), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: {}, // hiç kanıt yok
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('kanıt') && i.includes('be-test')));
  } finally { temizle(dizin); }
});

test('rc≠0: gate-kanıtı FAIL etmiş -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-lint', komut, komut_sha256: sha256(komut), runner: 'generic-rc' }],
    kanitlar: { 'be-lint': gateKanit(komut, { rc: 1 }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('rc')));
  } finally { temizle(dizin); }
});

test('BASELINE-BOZUK (integrity): baseline komut_sha256 komut ile uyuşmuyor -> İHLAL', () => {
  const komut = 'run tests';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'be-test', komut, komut_sha256: 'deadbeef'.repeat(8), runner: 'pytest', min_collected: 100, max_skipped: 0 }],
    kanitlar: { 'be-test': gateKanit(komut, { runner: 'pytest', counters: { collected: 100, passed: 100, failed: 0, skipped: 0 } }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, false);
    assert.ok(r.ihlaller.some((i) => i.includes('baseline') && (i.includes('bozuk') || i.includes('integrity') || i.includes('uyuşm'))));
  } finally { temizle(dizin); }
});

test('sayac_kanitsiz flag: yalnız generic-rc gate-cmd (hiç sayaçlı-runner yok) -> gecti=true + flag', () => {
  const komut = 'build project';
  const { dizin, ...y } = kur({
    baselineGateler: [{ id: 'fe-build', komut, komut_sha256: sha256(komut), runner: 'generic-rc' }],
    kanitlar: { 'fe-build': gateKanit(komut, { runner: 'generic-rc', counters: null }) },
  });
  try {
    const r = baselineDenetle(y);
    assert.equal(r.gecti, true, JSON.stringify(r.ihlaller));
    assert.equal(r.sayac_kanitsiz, true); // teslim-lint bunu görüp "SAYAÇ-KANITSIZ" manşeti basar
  } finally { temizle(dizin); }
});
