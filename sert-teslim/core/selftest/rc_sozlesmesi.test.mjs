// rc_sozlesmesi.test.mjs — RC-kontrakt drift-guard (ARAYUZ-SOZLESMESI.md, /sert-döngü'nün oracle-yüzeyi).
// teslim-lint.sh'nin RC=0(gate-temiz)/RC=1(ihlal) sözleşmesi sürüm-bump'ta sessizce kaymasın diye
// yalnız kullanım-hatası + eksik-dizin yüzeyini kilitler (gerçek bir teslim-dizini gerektirmez).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(HERE, '..', '..', 'scripts', 'teslim-lint.sh');

test('RC-kontrakt: teslim-lint.sh argsız → RC=2 (kullanım-hatası)', () => {
  const r = spawnSync('sh', [SCRIPT], { encoding: 'utf8' });
  assert.equal(r.status, 2);
});

test('RC-kontrakt: teslim-lint.sh olmayan-dizin → RC=1 (İHLAL, MATRIS.md yok)', () => {
  const r = spawnSync('sh', [SCRIPT, '/tmp/rc-sozlesmesi-yok-boyle-bir-dizin'], { encoding: 'utf8' });
  assert.equal(r.status, 1);
});
