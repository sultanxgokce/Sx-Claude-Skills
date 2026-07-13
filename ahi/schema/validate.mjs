#!/usr/bin/env node
// ahi — zero-dep manifest doğrulayıcı (constrained-YAML-subset PARSE eder, grep-değil).
// Değişmez: yalnız Node-stdlib (package.json/ajv YOK) · deterministik · named-error + exit 0/1.
// Kapsam (FAZ-0b): required-keys + tier-enum + no-placeholder + usta-requires. Parity/drift = FAZ-2 (ADR-001).
// Desteklenen YAML-alt-kümesi: `key: value` · `key:` + `  - item` (liste) · `key:` + `  subkey: value` (map) · `# yorum`.
import { readFileSync } from 'node:fs';

const TIERS = ['cirak', 'kalfa', 'usta', 'pir'];
const REQUIRED = ['tier', 'name', 'generic_goal']; // version=SKILL.md frontmatter (ADR-001), manifest'te DEĞİL

const unq = (s) => s.replace(/^["']|["']$/g, '');

function parseYaml(text) {
  const obj = {};
  let curKey = null, kind = null; // kind: 'list' | 'map' | null(pending)
  for (const raw of text.split('\n')) {
    if (/^\s*#/.test(raw) || raw.trim() === '') continue;
    const line = raw.replace(/\s+#.*$/, '');       // satır-içi yorum (boşluk sonrası)
    const listM = line.match(/^\s+-\s+(.*)$/);
    const childM = line.match(/^\s+([A-Za-z_][\w-]*):\s*(.*)$/);
    const topM = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (curKey && listM) {
      if (kind === null) { kind = 'list'; obj[curKey] = []; }
      if (kind === 'list') { obj[curKey].push(unq(listM[1].trim())); continue; }
    }
    if (curKey && childM && !topM) {
      if (kind === null) { kind = 'map'; obj[curKey] = {}; }
      if (kind === 'map') { obj[curKey][childM[1]] = unq(childM[2].trim()); continue; }
    }
    if (topM) {
      curKey = topM[1];
      const v = topM[2].trim();
      if (v === '') { kind = null; obj[curKey] = null; } // pending → çocukla çözülür
      else { obj[curKey] = unq(v); curKey = null; kind = null; }
    }
  }
  return obj;
}

function main() {
  const file = process.argv[2];
  if (!file) { console.error('kullanım: validate.mjs <manifest.yaml>'); process.exit(2); }
  let text;
  try { text = readFileSync(file, 'utf8'); }
  catch { console.error(`HATA: dosya okunamadı: ${file}`); process.exit(2); }

  const m = parseYaml(text);
  const errs = [];
  if (/\{\{[^}]*\}\}/.test(text)) errs.push('dolmamış placeholder {{...}} var (sevk-RED)');
  for (const k of REQUIRED) if (m[k] == null || m[k] === '') errs.push(`zorunlu alan eksik: ${k}`);
  if (m.tier && !TIERS.includes(m.tier)) errs.push(`geçersiz tier: "${m.tier}" (cirak|kalfa|usta|pir)`);
  if (m.tier === 'usta' && (!Array.isArray(m.requires) || m.requires.length < 1))
    errs.push('usta kademesi requires[] gerektirir (≥1 bileşen deklare — DOCTRINE §10)');

  if (errs.length) {
    console.error(`✗ ${file} — GEÇERSİZ:`);
    for (const e of errs) console.error(`  - ${e}`);
    process.exit(1);
  }
  console.log(`✓ ${file} — geçerli (tier=${m.tier}, name=${m.name})`);
  process.exit(0);
}

main();
