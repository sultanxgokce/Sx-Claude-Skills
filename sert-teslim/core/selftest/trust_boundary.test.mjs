// trust_boundary selftest — verdict-runner'ın kandırılamazlığı: RC-yakalama, sayaç-parse
// (runner-fixture'ları), pytest-exit-5=FAIL, kırmızı-mod sahicilik-kilidi, kanıt-JSON şema-uyumu.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { kosVeKanitla, sha256Hex, SKILL_VERSION } from '../trust_boundary.mjs';

function tempDizin() {
  return mkdtempSync(join(tmpdir(), 'tb-test-'));
}

test('PASS-koşum: rc=0 + kanıt-JSON şemaya-uygun + komut-hash doğru', () => {
  const dizin = tempDizin();
  const komut = 'true';
  const { kanit, kanitYolu } = kosVeKanitla({ mId: 'M1', komut, runner: 'generic-rc', kanitDizini: dizin });
  assert.equal(kanit.rc, 0);
  assert.equal(kanit.komut_sha256, sha256Hex(komut));
  assert.equal(kanit.counters, null); // generic-rc: tanım-gereği sayaçsız
  assert.equal(kanit.skill_version, SKILL_VERSION);
  const diskten = JSON.parse(readFileSync(kanitYolu, 'utf8'));
  assert.equal(diskten.m_id, 'M1');
});

test('FAIL-koşum: rc!=0 aynen yakalanır (yumuşatma yok)', () => {
  const dizin = tempDizin();
  const { kanit } = kosVeKanitla({ mId: 'M2', komut: 'exit 7', runner: 'generic-rc', kanitDizini: dizin });
  assert.equal(kanit.rc, 7);
});

test('KIRMIZI-MOD sahicilik-kilidi: rc=0 dönen koşum kırmızı-kanıt olarak KAYDEDİLEMEZ (throw)', () => {
  const dizin = tempDizin();
  assert.throws(
    () => kosVeKanitla({ mId: 'M3', komut: 'true', runner: 'generic-rc', kanitDizini: dizin, asKirmizi: true }),
    /KIRMIZI-MOD İHLALİ/,
  );
});

test('KIRMIZI-MOD meşru: FAIL-eden koşum M#-kirmizi.json olarak yazılır', () => {
  const dizin = tempDizin();
  const { kanit, kanitYolu } = kosVeKanitla({ mId: 'M4', komut: 'exit 1', runner: 'generic-rc', kanitDizini: dizin, asKirmizi: true });
  assert.equal(kanit.rc, 1);
  assert.ok(kanitYolu.endsWith('M4-kirmizi.json'));
  assert.equal(kanit.kirmizi_kanit_ref, null); // kırmızının kırmızısı olmaz
});

test('pytest-adapter: özet-satırından sayaçlar + exit-5=FAIL normalizasyonu', () => {
  const dizin = tempDizin();
  // pytest'i taklit eden fixture-script: özet basar, exit-5 döner (hiç-test-toplanmadı)
  const sahte = join(dizin, 'sahte-pytest.sh');
  writeFileSync(sahte, '#!/bin/sh\necho "no tests ran in 0.01s"\nexit 5\n');
  const { kanit } = kosVeKanitla({ mId: 'M5', komut: `sh ${sahte}`, runner: 'pytest', kanitDizini: dizin });
  assert.equal(kanit.rc, 1); // exit-5 -> FAIL (no-tests=no-proof)
  assert.ok((kanit.notlar ?? []).some((n) => n.includes('exit-5')));
});

test('pytest-adapter: "99 passed" sayaç-parse', () => {
  const dizin = tempDizin();
  const sahte = join(dizin, 'p.sh');
  writeFileSync(sahte, '#!/bin/sh\necho "99 passed, 1 warning in 14.63s"\nexit 0\n');
  const { kanit } = kosVeKanitla({ mId: 'M6', komut: `sh ${sahte}`, runner: 'pytest', kanitDizini: dizin });
  assert.deepEqual(kanit.counters, { collected: 99, passed: 99, failed: 0, skipped: 0 });
});

test('vitest-adapter: karışık özet "2 failed | 3 passed (5)" parse', () => {
  const dizin = tempDizin();
  const sahte = join(dizin, 'v.sh');
  writeFileSync(sahte, '#!/bin/sh\necho " Tests  2 failed | 3 passed (5)"\nexit 1\n');
  const { kanit } = kosVeKanitla({ mId: 'M7', komut: `sh ${sahte}`, runner: 'vitest', kanitDizini: dizin });
  assert.deepEqual(kanit.counters, { collected: 5, passed: 3, failed: 2, skipped: 0 });
  assert.equal(kanit.rc, 1);
});

test('sayaç-parse-fail: counters=null + ZAYIF-notu (sessiz-PASS-default YOK)', () => {
  const dizin = tempDizin();
  const sahte = join(dizin, 'bos.sh');
  writeFileSync(sahte, '#!/bin/sh\necho "tanınmaz çıktı"\nexit 0\n');
  const { kanit } = kosVeKanitla({ mId: 'M8', komut: `sh ${sahte}`, runner: 'vitest', kanitDizini: dizin });
  assert.equal(kanit.counters, null);
  assert.ok((kanit.notlar ?? []).some((n) => n.includes('ZAYIF')));
});

test('node-test-adapter: TAP-özeti parse', () => {
  const dizin = tempDizin();
  const sahte = join(dizin, 'nt.sh');
  writeFileSync(sahte, '#!/bin/sh\nprintf "# tests 26\\n# pass 26\\n# fail 0\\n# skipped 0\\n"\nexit 0\n');
  const { kanit } = kosVeKanitla({ mId: 'M9', komut: `sh ${sahte}`, runner: 'node-test', kanitDizini: dizin });
  assert.deepEqual(kanit.counters, { collected: 26, passed: 26, failed: 0, skipped: 0 });
});

test('bilinmeyen-runner: throw (sessiz-generic-düşüş YOK)', () => {
  assert.throws(
    () => kosVeKanitla({ mId: 'M10', komut: 'true', runner: 'olmayan', kanitDizini: tempDizin() }),
    /bilinmeyen runner/,
  );
});
