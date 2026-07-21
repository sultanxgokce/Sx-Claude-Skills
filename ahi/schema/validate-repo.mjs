#!/usr/bin/env node
// ahi validate-repo.mjs — repo-parity drift-lint (catalog.json ↔ sync-targets.json ↔ targets-varlığı).
// ADR-001: catalog/sync-targets'a YAZMAZ — yalnız RAPORLAR. version = sync-skills.mjs otoritesi (DOKUNMAZ).
// Mod: default report-only (exit 0, drift-görünür ama bloklamaz) · --strict → gate (exit 1).
// Zero-dep: yalnız Node-stdlib (catalog/sync-targets JSON → JSON.parse).
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.argv[2];
const strict = process.argv.includes('--strict');
if (!repoRoot) { console.error('kullanım: validate-repo.mjs <repo-root> [--strict]'); process.exit(2); }

function loadJson(p) {
  try { return JSON.parse(readFileSync(p, 'utf8')); }
  catch (e) { console.error(`parse-hatası ${p}: ${e.message}`); process.exit(2); }
}

const catalogP = join(repoRoot, 'catalog.json');
const targetsP = join(repoRoot, 'sync-targets.json');
if (!existsSync(catalogP) || !existsSync(targetsP)) {
  console.error('catalog.json / sync-targets.json bulunamadı (repo-parity için gerekli)'); process.exit(2);
}
const catalog = loadJson(catalogP);
const targets = loadJson(targetsP);

const catalogIds = new Set((catalog.skills || []).map((s) => s.id).filter(Boolean));
const installKeys = new Set(Object.keys(targets.install || {}));

const drift = [];
for (const k of installKeys) if (!catalogIds.has(k)) drift.push(`sync-targets.install "${k}" var → catalog.json'da YOK`);
// sync_dagitim:false = beyanlı katalog-only giriş (proje-kod-tabanına gömülü; makine-dağıtımı yok).
// Beyansız + install'sız katalog-girişi DRIFT kalır (yeni-giriş dişi korunur).
const noSync = new Set((catalog.skills || []).filter((s) => s.sync_dagitim === false).map((s) => s.id));
for (const c of catalogIds) if (!installKeys.has(c) && !noSync.has(c)) drift.push(`catalog "${c}" var → sync-targets.install'da YOK (dağıtım-dışıysa sync_dagitim:false beyan et)`);
// D6/C1: install-listesi tanımsız hedefe işaret edemez — sync-skills.mjs bu sınıfı SESSİZCE
// "missing" sayıp atlar (canlı-vaka: seyir-defteri→medigate/huma, hedef tanımsızdı → dağıtım hiç olmadı).
const targetKeys = new Set(Object.keys(targets.targets || {}));
for (const [k, list] of Object.entries(targets.install || {}))
  for (const t of list || [])
    if (!targetKeys.has(t)) drift.push(`install "${k}" tanımsız hedefe işaret ediyor: "${t}" (targets'ta YOK → sync sessiz-atlar)`);
// D8-b/E3+R-03: kapsam-refleksi davranış-çıpası — AHÎ üretim-akışı bu anahtarları taşımak ZORUNDA
// (federe-standart; ise-alim aynası = Nexus kapsam-refleksi.test.sh). Silinirse drift → strict/CI KIRMIZI.
const ahiSkillP = join(repoRoot, 'ahi', 'SKILL.md');
if (existsSync(ahiSkillP)) {
  const t = readFileSync(ahiSkillP, 'utf8');
  for (const key of ['Kapsam-refleksi (E3/R-03', 'zaten-var-mı', 'negatif-kapsam', 'bölge-çakışma', 'dağıtım-kapsamı'])
    if (!t.includes(key)) drift.push(`ahi/SKILL.md kapsam-refleksi çıpası eksik: "${key}" (E3/R-03 federe-standart)`);
} else if (existsSync(join(repoRoot, 'ahi'))) {
  // fail-closed: ahi/ var ama SKILL.md yok = kapsam-refleksi kanonu kayıp (version-lint'e kuple kalma)
  drift.push('ahi/SKILL.md YOK — kapsam-refleksi kanonu kayıp (E3/R-03)');
}

if (drift.length === 0) {
  console.log(`✓ repo-parity temiz (catalog ${catalogIds.size} ↔ sync-targets ${installKeys.size})`);
  process.exit(0);
}
console.error(`${strict ? '✗' : '⚠'} repo-parity drift (${drift.length}):`);
for (const d of drift) console.error(`  - ${d}`);
if (!strict) console.error("(report-only → exit 0. --strict ile gate'lenir. NOT: mevcut-drift ekosistem-bakımı; AHÎ yazmaz/düzeltmez — ADR-001.)");
process.exit(strict ? 1 : 0);
