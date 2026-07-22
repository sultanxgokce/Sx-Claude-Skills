#!/usr/bin/env node
// wa-version-check.mjs — bayat-tuple gözcüsü (Node-stdlib, zero-dep, salt-okur, value-safe).
//
// Ne yapar: SKILL.md'deki gömülü fallback WA-Web sürüm-tuple'ının 3. bileşenini (client_revision)
// canlı web.whatsapp.com/sw.js değeriyle karşılaştırır. Sır/env-değeri OKUMAZ ve BASMAZ; yalnız
// herkese-açık sürüm numaralarını yazar.
//
// RC: 0 = TAZE (gömülü == canlı) · 1 = BAYAT (gömülü < canlı; #2679 riski) · 2 = ÖLÇÜLEMEDİ.
//
// Kullanım: node scripts/wa-version-check.mjs [SKILL.md-yolu]

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const skillPath = process.argv[2] || join(HERE, '..', 'SKILL.md');

function embeddedRevision(path) {
  // Yalnız fallback atama satırını yakala: `let version...= [2, 3000, NNN]`
  let txt;
  try { txt = readFileSync(path, 'utf8'); }
  catch { return { err: 'SKILL.md okunamadı: ' + path }; }
  const m = txt.match(/let\s+version[^=]*=\s*\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]/);
  if (!m) return { err: 'gömülü fallback tuple bulunamadı' };
  return { rev: Number(m[3]), tuple: [Number(m[1]), Number(m[2]), Number(m[3])] };
}

async function liveRevision() {
  // Baileys fetchLatestWaWebVersion ile aynı kaynak: web.whatsapp.com/sw.js → client_revision.
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 15_000);
  try {
    const res = await fetch('https://web.whatsapp.com/sw.js', {
      signal: ctrl.signal,
      headers: { 'User-Agent': 'Mozilla/5.0' },
    });
    if (!res.ok) return { err: 'sw.js HTTP ' + res.status };
    const body = await res.text();
    const m = body.match(/client_revision\\?"?\s*[:=]\s*(\d+)/);
    if (!m) return { err: 'sw.js içinde client_revision bulunamadı' };
    return { rev: Number(m[1]) };
  } catch (e) {
    return { err: 'ağ/erişim: ' + (e && e.name ? e.name : String(e)) };
  } finally {
    clearTimeout(t);
  }
}

const emb = embeddedRevision(skillPath);
if (emb.err) { console.error('ÖLÇÜLEMEDİ — ' + emb.err); process.exit(2); }

const live = await liveRevision();
if (live.err) {
  console.error('ÖLÇÜLEMEDİ — gömülü=' + emb.rev + ' · canlı alınamadı (' + live.err + ')');
  process.exit(2);
}

if (emb.rev === live.rev) {
  console.log('TAZE — gömülü=' + emb.rev + ' == canlı=' + live.rev);
  process.exit(0);
}
if (emb.rev < live.rev) {
  console.log('BAYAT — gömülü=' + emb.rev + ' < canlı=' + live.rev +
    ' → fallback tuple yenile (SKILL.md §1 + reference/wa-socket.md), #2679 riski.');
  process.exit(1);
}
// gömülü > canlı: fallback zaten canlıdan yeni — bayat değil.
console.log('TAZE — gömülü=' + emb.rev + ' > canlı=' + live.rev + ' (fallback güncel)');
process.exit(0);
