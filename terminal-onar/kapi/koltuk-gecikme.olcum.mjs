#!/usr/bin/env node
// Gerçek gecikme ölçümü: yavaş koltuk betiğiyle (1,5 sn) kapıyı açar, bekçinin dakikalık çağrısını ve 61 sn sonraki Sultan isteğini ölçer.
// Kullanım: node koltuk-gecikme.olcum.mjs [kapı dizini]. Çıkış 0: ikinci istek betiği beklemedi. Çıkış 1: bekledi.
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = resolve(process.argv[2] || dirname(fileURLToPath(import.meta.url)));
const T = mkdtempSync(join(tmpdir(), 'kapi-gecikme-'));
const PORT = 18897, SIFRE = 'sinav-parolasi-1234', BEKLE_MS = 61_000, ESIK_MS = 500;
const betik = join(T, 'yavas.sh');
writeFileSync(betik, '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nsleep 1.5\nprintf "olcumkutu-ana\\t1760000000\\t0\\n"\n'); chmodSync(betik, 0o755);
const p = spawn(process.execPath, [join(KOK, 'sunucu.mjs')], {
  env: { ...process.env, KAPI_PORT: String(PORT), KAPI_TABAN: '/olcum', TO_KUTU: 'olcumkutu', KAPI_TTYD_SOKET: join(T, 'y.sock'), KAPI_TTYD_KISI_SOKET: join(T, 'k.sock'),
    TO_DURUM_DIZ: T, OLCUMKUTU__TERMINAL_SIFRE: SIFRE, KAPI_OTURUM_DIZ: join(T, 'yok'), TO_ANA_TMUX: 'olcumkutu-ana', KAPI_KOLTUK_BETIK: betik },
  stdio: 'ignore',
});
const u = `http://127.0.0.1:${PORT}/olcum`;
let rc = 2;
try {
  for (let i = 0; i < 50; i++) { await new Promise((r) => setTimeout(r, 100)); try { if ((await fetch(u + '/giris')).ok) break; } catch {} }
  const g = await fetch(u + '/giris', { method: 'POST', redirect: 'manual', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify({ parola: SIFRE }) });
  const cookie = 'kapi=' + ((g.headers.get('set-cookie') || '').match(/kapi=([^;]+)/) || [])[1];
  const olc = async () => { const t = performance.now(); const r = await fetch(u + '/api/koltuklar', { headers: { cookie } }); await r.text(); return { kod: r.status, ms: Math.round(performance.now() - t) }; };
  const bekci = await olc();
  await new Promise((r) => setTimeout(r, BEKLE_MS));
  const sultan = await olc();
  console.log(`bekçi isteği ${bekci.ms} ms (kod ${bekci.kod}) · ${BEKLE_MS / 1000} sn sonra Sultan isteği ${sultan.ms} ms (kod ${sultan.kod}) · eşik ${ESIK_MS} ms`);
  rc = bekci.kod === 200 && sultan.kod === 200 && sultan.ms < ESIK_MS ? 0 : 1;
  console.log(rc === 0 ? '  ✓ ikinci istek betiği beklemedi' : '  ✗ ikinci istek betiği bekledi');
} finally { p.kill(); }
process.exit(rc);
