#!/usr/bin/env node
/**
 * compact-olc.mjs — TEK oturum kaydından (jsonl) bağlam ölçüsü. Damga icat etmez; iki ölçü de kayıttan okunur (MUAVİN envanteri 14 Eki):
 *   • bağlam yüzdesi = son asistan yanıtının kullanımı (input + cache_read + cache_creation) ÷ pencere
 *     pencere: ctx-windows.json kuralları (merkez kanonu) → ORTAK-MIMARI gömülü tablo → eşleşmezse 200k VARSAYIM (payda_tahmin:true, '~').
 *     Pencere her zaman harness tahminidir (M04); kesin doluluk yalnız /context.
 *   • son compact = sondan 1 MB bloklarla taranan `compact_boundary` satırı (tavan 64 MB; tavan dolunca "yok" değil "tavana kadar yok").
 * Çıktı tek satır JSON: {tok, model, pencere, payda_tahmin, yuzde, son_compact (epoch|null), tetik, acilis (epoch|null), tarandi_mb, olculemedi?}
 *   node compact-olc.mjs <kayit.jsonl>
 */
import { openSync, readSync, fstatSync, closeSync, readFileSync, existsSync } from 'node:fs';

const yol = process.argv[2];
if (!yol) { console.log(JSON.stringify({ olculemedi: 'kayıt yolu verilmedi' })); process.exit(2); }
const epoch = (ts) => { const t = Date.parse(ts || ''); return Number.isFinite(t) ? Math.floor(t / 1000) : null; };
let fd;
try { fd = openSync(yol, 'r'); } catch (e) { console.log(JSON.stringify({ olculemedi: 'kayıt açılamadı: ' + e.code })); process.exit(2); }
const n = fstatSync(fd).size;
const oku = (bas, uz) => { const b = Buffer.alloc(uz); const r = readSync(fd, b, 0, uz, bas); return b.subarray(0, r).toString('utf8'); };

// ── kuyruk: son 600 KB → son asistan kullanımı + model + ad ──
let tok = null, model = null, ad = null;
for (const s of oku(Math.max(0, n - 600000), Math.min(n, 600000)).split('\n')) {
  let d; try { d = JSON.parse(s); } catch { continue; }
  for (const k of ['customTitle', 'agentName']) if (typeof d[k] === 'string') ad = d[k];
  const m = d.message;
  if (d.type === 'assistant' && m && typeof m === 'object' && m.usage && m.model !== '<synthetic>') {
    const u = m.usage; model = m.model || model;
    tok = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
  }
}
// ── baş: açılış zamanı ──
let acilis = null;
for (const s of oku(0, Math.min(n, 65536)).split('\n').slice(0, 80)) {
  let d; try { d = JSON.parse(s); } catch { continue; }
  if (typeof d.timestamp === 'string') { acilis = epoch(d.timestamp); break; }
}
// ── sondan 1 MB bloklarla compact_boundary (tavan 64 MB) ──
let son_compact = null, tetik = null, tarandi_mb = 0, son = n, kuyruk = '';
const BLOK = 1 << 20, TAVAN = Number(process.env.TO_COMPACT_TARAMA_MB || 64);
while (son > 0 && tarandi_mb < TAVAN && son_compact === null) {
  const bas = Math.max(0, son - BLOK); const parca = oku(bas, son - bas) + kuyruk; tarandi_mb++;
  if (parca.includes('"compact_boundary"')) {
    for (const x of parca.split('\n').filter((l) => l.includes('"compact_boundary"')).reverse()) {
      let d; try { d = JSON.parse(x); } catch { continue; }
      if (d.subtype === 'compact_boundary') { son_compact = epoch(d.timestamp); tetik = (d.compactMetadata && d.compactMetadata.trigger) || null; break; }
    }
  }
  kuyruk = parca.slice(0, parca.indexOf('\n') + 1); son = bas;
}
closeSync(fd);
// ── pencere (payda): ctx-windows.json kuralları (merkezin ctx-nudge kanonu; TO_CTX_WINDOWS ya da bilinen yollar) → yoksa ORTAK-MIMARI
//    model sözlüğünden GÖMÜLÜ tablo → hiçbiri eşleşmezse 200k VARSAYILIR ve payda_tahmin:true (kaynak 'bilinmeyen'; canlı 15 Eki ölçümü:
//    [1m]-siz 'opus-5'/'fable' kayıtları 200k sayılınca %226/%398 basıyordu — payda yanlışsa compact kararı da yanlış olur).
const GOMULU = [[['fable', 'mythos', '[1m]'], 1000000], [['opus-5'], 1000000], [['kimi', 'minimax'], 1000000],
  [['opus-4-8', 'opus-4.8', 'opus-4-7', 'opus-4.7', 'sonnet-5', 'sonnet5', 'sonnet-4-6', 'sonnet4.6'], 500000], [['haiku', 'glm', 'gemini'], 200000]];
function pencereCoz(m) {
  const ml = (m || '').toLowerCase(); let kurallar = null, vars = 200000;
  for (const y of [process.env.TO_CTX_WINDOWS, '/config/projects/Nexus/scripts/hooks/ctx-windows.json', '/config/.claude/ctx-windows.json']) {
    if (y && existsSync(y)) { try { const d = JSON.parse(readFileSync(y, 'utf8')); kurallar = d.rules.map((r) => [r.match, r.window]); vars = d.default_window || vars; break; } catch { /* bozuk → gömülü */ } }
  }
  if (kurallar) for (const [subs, w] of kurallar) if (subs.some((x) => ml.includes(String(x).toLowerCase()))) return { pencere: w, kaynak: 'json' };
  for (const [subs, w] of GOMULU) if (subs.some((x) => ml.includes(x))) return { pencere: w, kaynak: 'gomulu' };
  return { pencere: vars, kaynak: 'bilinmeyen' };
}
const { pencere, kaynak } = pencereCoz(model);
const payda_tahmin = kaynak === 'bilinmeyen';
const yuzde = tok === null ? null : Math.round(100 * tok / pencere);
console.log(JSON.stringify({ tok, model, ad, pencere, payda_kaynak: kaynak, payda_tahmin, yuzde, son_compact, tetik, acilis, tarandi_mb }));
