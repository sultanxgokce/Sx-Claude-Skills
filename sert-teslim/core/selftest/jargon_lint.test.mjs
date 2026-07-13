// jargon_lint.test.mjs — MOTOR proje-bilmezlik regresyon-kilidinin kendi-testi.
// (1) mevcut MOTOR temiz (RC=0); (2) MOTOR-dosyasına proje-terimi enjekte edilirse YAKALAR (RC!=0).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, cpSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const CORE = dirname(fileURLToPath(import.meta.url)) + '/..';
const KOK = CORE + '/..'; // skill kökü
const LINT = CORE + '/jargon-lint.sh';

function kos(kok) {
  try {
    execFileSync('sh', [LINT, '--kok', kok], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return 0;
  } catch (e) {
    return e.status ?? 1;
  }
}

test('mevcut MOTOR temiz: jargon-lint RC=0', () => {
  assert.equal(kos(KOK), 0);
});

test('enjeksiyon: MOTOR-dosyasına proje-terimi girerse YAKALAR (RC!=0)', () => {
  const dizin = mkdtempSync(join(tmpdir(), 'jargon-'));
  try {
    mkdirSync(join(dizin, 'core'), { recursive: true });
    mkdirSync(join(dizin, 'reference'), { recursive: true });
    // temiz-motor kopyala, sonra bir core-dosyasına yasak-terim enjekte et
    cpSync(join(KOK, 'core'), join(dizin, 'core'), { recursive: true });
    writeFileSync(join(dizin, 'core', 'sizinti.mjs'), '// aron_legacy kaynağına bağlan\nexport const x = 1;\n');
    assert.notEqual(kos(dizin), 0);
  } finally {
    rmSync(dizin, { recursive: true, force: true });
  }
});
