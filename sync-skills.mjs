#!/usr/bin/env node
/**
 * sync-skills.mjs — Sx-Claude-Skills için SENKRON KATMANI.
 *
 * Sorun: bu repo skill'lerin KAYNAĞI ama "pull+adapt" modeli güncellemeleri yaymıyor →
 * bir skill gelişince diğer projeler bayat kalıyor (drift). Bu script o boşluğu kapatır:
 * kaynak skill klasörlerini sync-targets.json'daki hedeflere VERSİYON-DAMGALI kopyalar.
 *
 * KULLANIM (bağımlılıksız, saf Node ESM):
 *   node sync-skills.mjs                 # --check (dry-run): ne olurdu, göster (VARSAYILAN)
 *   node sync-skills.mjs --apply         # kopyala (yalnız kaynak >= hedef ise)
 *   node sync-skills.mjs --apply --force # hedef daha yeni olsa bile üstüne yaz
 *   node sync-skills.mjs --skill whatsapp-baileys [--apply]   # tek skill
 *
 * DRIFT KORUMASI: hedef sürümü kaynaktan YENİ ise (biri kurulu kopyayı elle düzenlemiş)
 * script UYARIR ve --force olmadan DOKUNMAZ → önce o değişikliği kaynağa geri taşı.
 *
 * Kaynak-doğruluk: her SKILL.md frontmatter'ında `version: x.y.z` ZORUNLU (semver).
 */
import { readFileSync, existsSync, mkdirSync, readdirSync, statSync, copyFileSync, rmSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const FORCE = args.includes('--force');
const ONLY = args.includes('--skill') ? args[args.indexOf('--skill') + 1] : null;

// ── yardımcılar ──────────────────────────────────────────────────────────────
const isJunk = (n) => n === '.DS_Store' || n.startsWith('._');

/** SKILL.md frontmatter'ından `version:` çek. */
function readVersion(skillMdPath) {
  if (!existsSync(skillMdPath)) return null;
  const txt = readFileSync(skillMdPath, 'utf8');
  const m = txt.match(/^\s*version:\s*["']?(\d+\.\d+\.\d+)["']?\s*$/m);
  return m ? m[1] : null;
}

/** semver kaba karşılaştırma: a>b →1, a<b →-1, eşit →0. */
function cmpVer(a, b) {
  const pa = a.split('.').map(Number), pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) { if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0) ? 1 : -1; }
  return 0;
}

/** klasörü özyinelemeli kopyala (junk hariç). Hedefteki eski içerik önce silinir (temiz kopya). */
function copyDir(src, dst) {
  if (existsSync(dst)) rmSync(dst, { recursive: true, force: true });
  mkdirSync(dst, { recursive: true });
  for (const name of readdirSync(src)) {
    if (isJunk(name)) continue;
    const s = join(src, name), d = join(dst, name);
    if (statSync(s).isDirectory()) copyDir(s, d);
    else copyFileSync(s, d);
  }
}

// ── manifest ─────────────────────────────────────────────────────────────────
const manifest = JSON.parse(readFileSync(join(REPO, 'sync-targets.json'), 'utf8'));
const { targets, install } = manifest;

console.log(`\n  sync-skills — ${APPLY ? (FORCE ? 'APPLY --force' : 'APPLY') : 'CHECK (dry-run)'}\n`);

let planned = 0, skipped = 0, warned = 0, missing = 0;

for (const [skillId, targetKeys] of Object.entries(install)) {
  if (ONLY && skillId !== ONLY) continue;
  const srcDir = join(REPO, skillId);
  const srcMd = join(srcDir, 'SKILL.md');
  const srcVer = readVersion(srcMd);
  if (!srcVer) { console.log(`  ✗ ${skillId}: kaynak SKILL.md/version yok — atlandı`); missing++; continue; }

  for (const key of targetKeys) {
    const baseDir = targets[key];
    if (!baseDir) { console.log(`  ✗ ${skillId} → '${key}': hedef tanımsız`); missing++; continue; }
    if (!existsSync(baseDir)) { console.log(`  ✗ ${skillId} → ${key} (${baseDir}): dizin yok — atlandı`); missing++; continue; }

    const dstDir = join(baseDir, skillId);
    const dstVer = readVersion(join(dstDir, 'SKILL.md'));
    const label = `${skillId} → ${key}`;

    if (!dstVer) {
      console.log(`  + ${label}: YENİ kurulum (v${srcVer})`);
      if (APPLY) copyDir(srcDir, dstDir);
      planned++;
    } else {
      const c = cmpVer(srcVer, dstVer);
      if (c > 0) {
        console.log(`  ↑ ${label}: güncelle v${dstVer} → v${srcVer}`);
        if (APPLY) copyDir(srcDir, dstDir);
        planned++;
      } else if (c === 0) {
        console.log(`  = ${label}: güncel (v${srcVer})`);
        skipped++;
      } else {
        console.log(`  ⚠ ${label}: HEDEF DAHA YENİ (hedef v${dstVer} > kaynak v${srcVer}) — DRIFT!`);
        console.log(`     → kurulu kopya elle düzenlenmiş olabilir. Önce kaynağa geri taşı, ya da --force ile ez.`);
        if (APPLY && FORCE) { copyDir(srcDir, dstDir); console.log(`     → --force: üzerine yazıldı v${srcVer}`); planned++; }
        else warned++;
      }
    }
  }
}

console.log(`\n  özet: ${planned} ${APPLY ? 'uygulandı' : 'planlandı'} · ${skipped} güncel · ${warned} drift-uyarı · ${missing} eksik`);
if (!APPLY && planned > 0) console.log(`  → uygulamak için: node sync-skills.mjs --apply\n`);
else console.log('');
