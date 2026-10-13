// ttyd ?arg= değerini kabuğa URL-ÇÖZÜLMÜŞ mü iletiyor? (gerçek ttyd + gerçek Chromium)
import { spawn } from 'node:child_process'; import { mkdtempSync, existsSync } from 'node:fs'; import http from 'node:http'; import net from 'node:net';
const { chromium } = await import('/config/projects/Nexus/ui/node_modules/playwright/index.mjs');
const T = mkdtempSync('/tmp/ttyd-arg-'); const SOCK = T + '/s.sock';
const ttyd = spawn('/config/.local/bin/ttyd', ['-W', '-a', '-i', SOCK, '-b', '/t', 'bash', '-c', 'printf "ARG=[%s] N=%s\\n" "$1" "$#"; sleep 30', 'x'], { stdio: 'ignore' });
for (let k = 0; k < 50 && !existsSync(SOCK); k++) await new Promise(r => setTimeout(r, 100));
// unix soketi → TCP köprü (tarayıcı için)
const srv = net.createServer((c) => { const u = net.connect(SOCK); c.pipe(u); u.pipe(c); c.on('error', () => u.destroy()); u.on('error', () => c.destroy()); });
await new Promise(r => srv.listen(0, '127.0.0.1', r)); const P = srv.address().port;
const b = await chromium.launch(); const pg = await b.newPage();
for (const arg of ['2026%2F85', '2026/85']) {
  await pg.goto(`http://127.0.0.1:${P}/t/?arg=${arg}`, { waitUntil: 'load' });
  await pg.waitForFunction(() => window.term && /ARG=/.test(Array.from({ length: window.term.buffer.active.length }, (_, i) => window.term.buffer.active.getLine(i)?.translateToString(true) || '').join('\n')), null, { timeout: 10000 }).catch(() => {});
  const t = await pg.evaluate(() => Array.from({ length: window.term.buffer.active.length }, (_, i) => window.term.buffer.active.getLine(i)?.translateToString(true) || '').join('\n').match(/ARG=\[[^\]]*\] N=\d+/)?.[0]);
  console.log(`?arg=${arg} → kabuk: ${t}`);
}
await b.close(); ttyd.kill(); srv.close();
