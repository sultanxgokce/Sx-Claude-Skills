#!/usr/bin/env node
/**
 * sync-skills.test.mjs — İÇERİK-DRIFT bekçisinin SESİ ÇIKIYOR MU?
 *
 * NİÇİN VAR: bir bekçinin varlığı işe yaramaz; ölçülmesi gereken şey sesinin çıkıp çıkmadığıdır.
 * 2026-07-28'de altı gün süren bir sessizliğin sebebi bekçinin yokluğu değil, hatayı bulunca
 * yalnız kendi günlüğüne yazıp "başarılı" dönmesiydi. Bu test o hatayı burada tekrarlatmaz:
 * drift'te hem UYARI metnini hem RC=1'i, temizde hem sessizliği hem RC=0'ı doğrular.
 *
 * Bağımlılıksız (saf Node). Koşum: node sync-skills.test.mjs
 */
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(fileURLToPath(import.meta.url));
const kok = mkdtempSync(join(tmpdir(), 'sync-skills-test-'));
let gecen = 0, kalan = 0;

function kur({ kaynakGovde, hedefGovde, kaynakVer, hedefVer }) {
  const alan = mkdtempSync(join(kok, 'alan-'));
  const kaynak = join(alan, 'repo'), hedefKok = join(alan, 'hedef');
  mkdirSync(join(kaynak, 'ornek-skill'), { recursive: true });
  mkdirSync(join(hedefKok, 'ornek-skill'), { recursive: true });
  const md = (v, govde) => `---\nname: ornek-skill\nversion: ${v}\n---\n\n${govde}\n`;
  writeFileSync(join(kaynak, 'ornek-skill', 'SKILL.md'), md(kaynakVer, kaynakGovde));
  writeFileSync(join(hedefKok, 'ornek-skill', 'SKILL.md'), md(hedefVer, hedefGovde));
  writeFileSync(
    join(kaynak, 'sync-targets.json'),
    JSON.stringify({ targets: { deneme: hedefKok }, install: { 'ornek-skill': ['deneme'] } }),
  );
  // Bekçi manifest'i KENDİ dizininden okuduğu için script'i deneme-alanına kopyalıyoruz.
  writeFileSync(join(kaynak, 'sync-skills.mjs'), readFileSync(join(REPO, 'sync-skills.mjs'), 'utf8'));
  return kaynak;
}

/** Deneme-alanındaki hedef SKILL.md yolu. */
function hedefMdYolu(kaynak) {
  const m = JSON.parse(readFileSync(join(kaynak, 'sync-targets.json'), 'utf8'));
  return join(m.targets.deneme, 'ornek-skill', 'SKILL.md');
}

function kos(kaynak, ...ek) {
  return spawnSync(process.execPath, [join(kaynak, 'sync-skills.mjs'), ...ek], { encoding: 'utf8' });
}

function bekle(ad, kosul, detay = '') {
  if (kosul) { console.log(`  ✓ ${ad}`); gecen++; }
  else { console.log(`  ✗ ${ad}${detay ? ' — ' + detay : ''}`); kalan++; }
}

console.log('\n  sync-skills — bekçi sesi testleri\n');

// G1: sürüm EŞİT + içerik EŞİT → sessiz, RC=0
{
  const kaynak = kur({ kaynakVer: '1.0.0', hedefVer: '1.0.0', kaynakGovde: 'ayni', hedefGovde: 'ayni' });
  const r = kos(kaynak);
  bekle('G1 içerik aynıysa drift YOK', !r.stdout.includes('İÇERİK-DRIFT'), r.stdout.trim());
  bekle('G1 temiz koşuda RC=0', r.status === 0, `rc=${r.status}`);
}

// G2: sürüm EŞİT + içerik FARKLI → İÇERİK-DRIFT + RC=1  (asıl kör nokta)
{
  const kaynak = kur({ kaynakVer: '1.0.0', hedefVer: '1.0.0', kaynakGovde: 'kaynak-metni', hedefGovde: 'ELLE-DEGISTIRILMIS' });
  const r = kos(kaynak);
  bekle('G2 eşit-sürüm-farklı-içerik YAKALANIR', r.stdout.includes('İÇERİK-DRIFT'), r.stdout.trim());
  bekle('G2 drift varken RC=1 (sesi çıkar)', r.status === 1, `rc=${r.status}`);
}

// G3: drift varken --apply (force YOK) hedefe DOKUNMAZ → veri-kaybı panzehiri
{
  const kaynak = kur({ kaynakVer: '1.0.0', hedefVer: '1.0.0', kaynakGovde: 'kaynak', hedefGovde: 'KORUNMALI' });
  const r = kos(kaynak, '--apply');
  bekle('G3 --apply force-suz üzerine YAZMAZ', readFileSync(hedefMdYolu(kaynak), 'utf8').includes('KORUNMALI'));
  bekle('G3 --apply drift varken yine RC=1', r.status === 1, `rc=${r.status}`);
}

// G4: --force ile bilinçli ezme çalışır
{
  const kaynak = kur({ kaynakVer: '1.0.0', hedefVer: '1.0.0', kaynakGovde: 'KAYNAK-KAZANIR', hedefGovde: 'eski' });
  const r = kos(kaynak, '--apply', '--force');
  bekle('G4 --force üzerine yazar', readFileSync(hedefMdYolu(kaynak), 'utf8').includes('KAYNAK-KAZANIR'));
  bekle('G4 --force sonrası RC=0', r.status === 0, `rc=${r.status}`);
}

// G5: üretilmiş artefakt (__pycache__) drift SAYILMAZ → yanlış-pozitif elemesi
{
  const kaynak = kur({ kaynakVer: '1.0.0', hedefVer: '1.0.0', kaynakGovde: 'ayni', hedefGovde: 'ayni' });
  mkdirSync(join(dirname(hedefMdYolu(kaynak)), '__pycache__'), { recursive: true });
  writeFileSync(join(dirname(hedefMdYolu(kaynak)), '__pycache__', 'x.pyc'), 'derlenmis');
  const r = kos(kaynak);
  bekle('G5 __pycache__ drift sayılmaz', !r.stdout.includes('İÇERİK-DRIFT'), r.stdout.trim());
  bekle('G5 yanlış-pozitif yok → RC=0', r.status === 0, `rc=${r.status}`);
}

rmSync(kok, { recursive: true, force: true });
console.log(`\n  özet: ${gecen} geçti · ${kalan} kaldı\n`);
process.exit(kalan === 0 ? 0 : 1);
