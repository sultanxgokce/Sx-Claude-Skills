// rc-sozlesmesi.test.mjs — RC-kontrakt drift-guard (ARAYUZ-SOZLESMESI.md, /sert-döngü'nün oracle-yüzeyi).
// e2e-run.mjs + enjeksiyon.mjs sürüm-bump'ında kullanım-hatası exit-code'u (RC=2) sessizce
// kayarsa /sert-döngü'nün "RC=2 → ABORT, retry-anlamsız" kararı yanlış-yorumlanır. Bu test
// yalnız kullanım-hatası yüzeyini kilitler (canlı-panel gerektirmez, hızlı+CI-güvenli).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const SCRIPTS = join(HERE, '..', 'scripts');

test('RC-kontrakt: e2e-run.mjs argsız → RC=2 (kullanım-hatası, retry-anlamsız)', () => {
  const r = spawnSync('node', [join(SCRIPTS, 'e2e-run.mjs')], { encoding: 'utf8' });
  assert.equal(r.status, 2);
});

test('RC-kontrakt: enjeksiyon.mjs argsız → RC=2 (kullanım-hatası, retry-anlamsız)', () => {
  const r = spawnSync('node', [join(SCRIPTS, 'enjeksiyon.mjs')], { encoding: 'utf8' });
  assert.equal(r.status, 2);
});
