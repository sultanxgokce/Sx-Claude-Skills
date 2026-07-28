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
 * DRIFT KORUMASI — İKİ AYRI HÂL, ikisi de --force olmadan DOKUNULMAZ ve ikisi de RC=1 verir:
 *   1) hedef sürümü kaynaktan YENİ  → kurulu kopya elle düzenlenip bump'lanmış
 *   2) sürümler EŞİT ama içerik farklı (İÇERİK-DRIFT) → bump'lanmadan düzenlenmiş
 * (2) eskiden görünmezdi: script `= güncel` deyip geçiyor, sonraki --apply ise değişikliği
 * sessizce siliyordu. Bekçinin çıkış-kodu vermesi şart — vermezse cron/CI drift'i duymaz.
 *
 * Kaynak-doğruluk: her SKILL.md frontmatter'ında `version: x.y.z` ZORUNLU (semver).
 */
import { readFileSync, existsSync, mkdirSync, readdirSync, statSync, copyFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const FORCE = args.includes('--force');
const ONLY = args.includes('--skill') ? args[args.indexOf('--skill') + 1] : null;

// ── yardımcılar ──────────────────────────────────────────────────────────────
// Kopyalanmayan/karşılaştırılmayan üretilmiş artefaktlar. __pycache__ eklendi (2026-07-28):
// içerik-parmak-izi ilk koşuşunda TEK farkı o üretiyordu → gerçek olmayan drift alarmı.
// Bekçinin ilk işi kendi yanlış-pozitifini elemektir; gürültülü bekçi susturulan bekçidir.
const JUNK_DIRS = new Set(['__pycache__', 'node_modules', '.pytest_cache', '.ruff_cache']);
const isJunk = (n) =>
  n === '.DS_Store' || n.startsWith('._') || JUNK_DIRS.has(n) || n.endsWith('.pyc');

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

/**
 * Klasörün İÇERİK parmak-izi — dosya-yolu + içerik, deterministik sırayla (junk hariç).
 *
 * NİÇİN VAR: sürüm karşılaştırması tek başına "eşit-sürüm-farklı-içerik" hâlini GÖREMEZ.
 * Biri kurulu kopyayı sürüm bump'lamadan düzenlerse script `= güncel` deyip geçiyordu;
 * bir sonraki `--apply` ise (copyDir önce rmSync yapar) o değişikliği sessizce yok ediyordu.
 * Federation-nöbetçisi vakasının (2026-07-28) birebir aynı sınıfı: sessizce ayrışır, kimse duymaz.
 */
function dirHash(dir) {
  const h = createHash('sha256');
  const walk = (d, prefix) => {
    for (const name of readdirSync(d).sort()) {
      if (isJunk(name)) continue;
      const p = join(d, name), rel = prefix ? `${prefix}/${name}` : name;
      if (statSync(p).isDirectory()) walk(p, rel);
      else { h.update(rel); h.update('\0'); h.update(readFileSync(p)); h.update('\0'); }
    }
  };
  walk(dir, '');
  return h.digest('hex').slice(0, 12);
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
        // Sürümler eşit — İÇERİK de eşit mi? (sürüm tek başına yeterli değil, bkz dirHash yorumu)
        const sh = dirHash(srcDir), dh = dirHash(dstDir);
        if (sh === dh) {
          console.log(`  = ${label}: güncel (v${srcVer})`);
          skipped++;
        } else {
          console.log(`  ⚠ ${label}: İÇERİK-DRIFT — sürüm aynı (v${srcVer}) ama içerik farklı`);
          console.log(`     → kaynak ${sh} ≠ kurulu ${dh}. Sürüm bump'lanmadan düzenlenmiş.`);
          console.log(`     → hangisinin doğru olduğunu SÜRÜM söyleyemez: farkı incele (diff), kaynağa taşı ve bump'la;`);
          console.log(`        kurulu kopya çöpse --force ile ez (--force olmadan DOKUNULMAZ).`);
          if (APPLY && FORCE) { copyDir(srcDir, dstDir); console.log(`     → --force: üzerine yazıldı v${srcVer}`); planned++; }
          else warned++;
        }
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

// Drift SESSİZ kalmamalı: bekçi ancak çıkış-kodu verirse cron/CI onu duyar.
// (missing bilinçli olarak RC'yi bozmaz — hedef dizini olmayan container normal bir hâldir.)
if (warned > 0) process.exit(1);
