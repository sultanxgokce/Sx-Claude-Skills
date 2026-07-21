#!/usr/bin/env node
// version-lint.mjs — install'lı her skill SKILL.md + semver version-frontmatter taşır (Federe D6/C2).
// NEDEN dosya (inline node -e değil): shell-quoting tuzağı — regex'teki tırnak sınıfı CI'da
// single-quote bloğunu kesip bash-syntax-error üretti (D6 adversaryal-panel land-blocker'ı).
// Zero-dep; kullanım: node ahi/schema/version-lint.mjs <repo-root>
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.argv[2];
if (!repoRoot) { console.error('kullanım: version-lint.mjs <repo-root>'); process.exit(2); }

const st = JSON.parse(readFileSync(join(repoRoot, 'sync-targets.json'), 'utf8'));
const ids = Object.keys(st.install || {});
let bad = 0;
for (const id of ids) {
  const p = join(repoRoot, id, 'SKILL.md');
  if (!existsSync(p)) { console.error(`EKSIK: ${id}/SKILL.md`); bad++; continue; }
  if (!/^\s*version:\s*["']?\d+\.\d+\.\d+/m.test(readFileSync(p, 'utf8'))) {
    console.error(`VERSIYONSUZ: ${id}/SKILL.md (semver frontmatter zorunlu — sync-skills karşılaştırması buna dayanır)`);
    bad++;
  }
}
if (bad) { console.error(`✗ ${bad} ihlal`); process.exit(1); }
console.log(`✓ install-listesi ${ids.length} skill: SKILL.md + version tam`);
