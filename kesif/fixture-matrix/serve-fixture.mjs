// serve-fixture.mjs — bağımlılıksız minimal statik+API sunucu (portability-fixture için).
// GET / → panel.html ; GET /fixture/data → {"value":42}. node built-in http (npm-YOK).
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.argv[2] ?? 8099);

const server = createServer((req, res) => {
  const yol = new URL(req.url, `http://127.0.0.1:${PORT}`).pathname;
  if (yol === '/fixture/data') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ value: 42 }));
    return;
  }
  if (yol === '/' || yol.endsWith('.html')) {
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(readFileSync(join(DIR, 'panel.html')));
    return;
  }
  res.writeHead(404); res.end('yok');
});
server.listen(PORT, '127.0.0.1', () => process.stdout.write(`fixture-panel ayakta: http://127.0.0.1:${PORT}\n`));
