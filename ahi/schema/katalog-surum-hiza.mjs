#!/usr/bin/env node
// katalog-surum-hiza.mjs — catalog.json'daki her skill sürümü SKILL.md frontmatter sürümüyle AYNI mı? (görev …JBZET · kart katalog-surum-hiza)
//
// NİÇİN: catalog.json'daki `version` elle yazılıyor, SKILL.md'deki `version:` ise sync-skills.mjs'in otoritesi. İkisi sessizce ayrıştı:
//   29 Eki 2026 ölçümü — 82 girdinin 17'si farklı (tescil 0.3.0 ↔ 0.9.1, iskan 0.11.0 ↔ 0.11.5 …). Katalogu okuyan (Nexus Skill Kataloğu,
//   künye raporu) yanlış sürüm görür. Tek gerçek SKILL.md'dir (version-lint.mjs onu zorunlu kılar); katalog ona uydurulur.
//
// KULLANIM:  node ahi/schema/katalog-surum-hiza.mjs <repo-root>            → ölçer: sapma sayısı; sapma varsa rc 1, hiç sapma yoksa rc 0
//            node ahi/schema/katalog-surum-hiza.mjs <repo-root> --duzelt   → SKILL.md sürümünü kataloğa yazar (yalnız o girdinin "version" satırı,
//                                                                            biçim/sıra korunur), sonra yeniden ölçer; rc ölçüme göre
// rc 2 = kullanım/okunamadı (catalog.json yok ya da bozuk) — "sapma yok" DENMEZ.  rc 3 = ölçülemeyen girdi var (SKILL.md yok ya da versiyonsuz):
//   bunlar sapma DEĞİL ama hizalanamaz; söylenir, --duzelt dokunmaz. (sync_dagitim:false ve dış/deprecated girdiler de aynı kurala tabidir:
//   katalogda sürüm yazıyorsa SKILL.md ile aynı olmalı.)
// Girdi dizini: `path` varsa onun dizini (…/SKILL.md ya da dizin), yoksa `id`. Zero-dep.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';

const args = process.argv.slice(2);
const DUZELT = args.includes('--duzelt');
const repoRoot = args.find((a) => !a.startsWith('--'));
if (!repoRoot) { console.error('kullanım: katalog-surum-hiza.mjs <repo-root> [--duzelt]'); process.exit(2); }
const catalogP = join(repoRoot, 'catalog.json');
let ham, catalog;
try { ham = readFileSync(catalogP, 'utf8'); catalog = JSON.parse(ham); }
catch (e) { console.error(`✗ catalog.json okunamadı (${e.message}) — ÖLÇÜLEMEDİ`); process.exit(2); }
const skills = Array.isArray(catalog.skills) ? catalog.skills : null;
if (!skills) { console.error('✗ catalog.json içinde skills listesi yok — ÖLÇÜLEMEDİ'); process.exit(2); }

export function skillDizini(entry) {
  const p = typeof entry.path === 'string' && entry.path.trim() ? entry.path.trim() : '';
  if (!p) return entry.id || '';
  return p.endsWith('SKILL.md') ? dirname(p) : p.replace(/\/+$/, '');
}
export function skillSurumu(txt) {
  const m = txt.match(/^\s*version:\s*["']?(\d+\.\d+\.\d+)["']?\s*$/m);   // version-lint.mjs ile aynı desen
  return m ? m[1] : null;
}

const sapma = [], olculemedi = [];
for (const s of skills) {
  if (!s || typeof s !== 'object' || !s.id) { olculemedi.push(['?', 'girdi id taşımıyor']); continue; }
  const dz = skillDizini(s); const p = join(repoRoot, dz, 'SKILL.md');
  if (!existsSync(p)) { olculemedi.push([s.id, `${dz}/SKILL.md yok`]); continue; }
  const v = skillSurumu(readFileSync(p, 'utf8'));
  if (!v) { olculemedi.push([s.id, `${dz}/SKILL.md versiyonsuz`]); continue; }
  if (typeof s.version !== 'string' || s.version !== v) sapma.push([s.id, s.version ?? '(yok)', v]);
}

function duzelt() {
  // Yalnız sapan girdinin "version" satırı değişir: "id": "<id>" satırından sonraki ilk "version": "…" — JSON yeniden yazılmaz (biçim, sıra, anahtar korunur).
  let metin = ham, yazildi = 0;
  for (const [id, eski, yeni] of sapma) {
    const idIdx = metin.indexOf(`"id": "${id}"`);
    if (idIdx < 0) { console.error(`  ✗ ${id}: katalog metninde "id" satırı bulunamadı — DOKUNULMADI`); continue; }
    const re = /"version":\s*"[^"]*"/g; re.lastIndex = idIdx;
    const m = re.exec(metin);
    if (!m || m.index - idIdx > 2000) { console.error(`  ✗ ${id}: "version" satırı girdinin yakınında bulunamadı — DOKUNULMADI`); continue; }
    metin = metin.slice(0, m.index) + `"version": "${yeni}"` + metin.slice(m.index + m[0].length); yazildi++;
    console.log(`  ✎ ${id}: ${eski} → ${yeni}`);
  }
  try { JSON.parse(metin); } catch (e) { console.error(`✗ düzeltilmiş katalog JSON olarak bozuk (${e.message}) — YAZILMADI`); process.exit(2); }
  writeFileSync(catalogP, metin);
  const geri = JSON.parse(readFileSync(catalogP, 'utf8'));   // yazdığını geri oku: "yazdım" demek yetmez
  const kalan = (geri.skills || []).filter((s) => sapma.some(([id, , yeni]) => s.id === id && s.version !== yeni)).length;
  console.log(`  düzeltildi: ${yazildi}/${sapma.length} · geri okuma: ${kalan ? kalan + ' girdi HÂLÂ sapık' : 'hepsi hizalı'}`);
  return kalan === 0 && yazildi === sapma.length;
}

for (const [id, k, s] of sapma) console.log(`  ✗ SAPMA ${id}: katalog ${k} ≠ SKILL.md ${s}`);
for (const [id, n] of olculemedi) console.log(`  ◻ ÖLÇÜLEMEDİ ${id}: ${n}`);
console.log(`katalog↔SKILL.md: girdi ${skills.length} · sapma ${sapma.length} · ölçülemedi ${olculemedi.length}`);
if (DUZELT && sapma.length) {
  const ok = duzelt();
  if (!ok) process.exit(1);
  console.log('✓ katalog SKILL.md sürümlerine hizalandı (yeniden ölçüm: sapma 0)');
  process.exit(olculemedi.length ? 3 : 0);
}
if (sapma.length) { console.error(`✗ ${sapma.length} sapma — SKILL.md tek gerçek; düzeltmek için: node ahi/schema/katalog-surum-hiza.mjs . --duzelt`); process.exit(1); }
if (olculemedi.length) { console.error(`◻ ${olculemedi.length} girdi ölçülemedi (SKILL.md yok/versiyonsuz) — "sapma yok" denemez`); process.exit(3); }
console.log('✓ sapma 0');
