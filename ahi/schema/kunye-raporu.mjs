#!/usr/bin/env node
// ahi/schema/kunye-raporu.mjs — paket künyesi + npm lisans RAPORU (report-only, ölçer; bloklamaz).
//
// İki soruyu ölçer, ikisini de üç-durumlu (yeşil / kırmızı / ölçülemedi) raporlar:
//   1) KÜNYE   — paket kime ait (`owner`) ve kim tüketiyor (`consumers`)?
//                Sahipsiz paket = başka bir odanın habersiz düzenleyebileceği paket (owner-domain ihlali kaynağı).
//   2) LİSANS  — paketin npm bağımlılıkları hangi lisansta? Kopyaya-bulaşan (GPL/AGPL/SSPL) sınıfı var mı?
//
// ⚖️ Bu araç KURAL DAYATMAZ, ÖLÇER. "Ölçmediğin kuralı sert ilan edemezsin" (K01) gereği:
//    kapıyı kırmızıya çevirmek ayrı ve bilinçli bir karardır → `--strict`.
//    Varsayılan modda exit 0 (drift görünür, iş durmaz).
//
// Zero-dep: yalnız Node stdlib. YAML için tam parser kullanmaz — manifest'ler düz `anahtar: değer`
//   biçimindedir; okuyucu bilinçli olarak dar tutulmuştur ve anlamadığı şeyi "ölçülemedi" sayar (fail-open
//   DEĞİL: rapora "ölçülemedi" satırı düşer ve --strict altında yeşil saydırmaz).
//
// Kullanım:
//   node ahi/schema/kunye-raporu.mjs <repo-koku> [--strict] [--paket <ad>]
// Çıkış: 0 temiz/report-only · 1 --strict altında bulgu var · 2 kullanım/ortam hatası

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const args = process.argv.slice(2);
const repoRoot = args.find((a) => !a.startsWith('--'));
const strict = args.includes('--strict');
const paketIdx = args.indexOf('--paket');
const tekPaket = paketIdx >= 0 ? args[paketIdx + 1] : null;

if (!repoRoot) {
  console.error('kullanım: kunye-raporu.mjs <repo-koku> [--strict] [--paket <ad>]');
  process.exit(2);
}
if (!existsSync(repoRoot) || !statSync(repoRoot).isDirectory()) {
  console.error(`dizin yok: ${repoRoot}`);
  process.exit(2);
}

// Kopyaya-bulaşan (copyleft) sınıfı — bir beceri paketi bunlardan birini taşıyorsa
// paketin kendisi de aynı lisansı devralmak zorunda kalabilir. Karar Sultan'ındır; araç yalnız işaretler.
const BULASAN = [/\bAGPL/i, /\bGPL-/i, /\bGPL\b/i, /\bSSPL/i, /\bCC-BY-NC/i];
// Serbest kullanım — bilinen ve sorunsuz sınıf.
const SERBEST = [/\bMIT\b/i, /\bApache/i, /\bBSD/i, /\bISC\b/i, /\bMPL/i, /\bUnlicense\b/i, /\bCC0/i];

function lisansSinifi(lisans) {
  if (!lisans) return 'olculemedi';
  if (BULASAN.some((r) => r.test(lisans))) return 'bulasan';
  if (SERBEST.some((r) => r.test(lisans))) return 'serbest';
  return 'bilinmeyen';
}

// Dar YAML okuyucu: yalnız kök seviyesindeki `anahtar: değer` ve `anahtar:` + `  - öğe` listelerini anlar.
function manifestOku(yol) {
  const satirlar = readFileSync(yol, 'utf8').split('\n');
  const cikti = {};
  let acikListe = null;
  for (const ham of satirlar) {
    const satir = ham.replace(/\s+$/, '');
    if (!satir || satir.trimStart().startsWith('#')) continue;
    const listeEsi = satir.match(/^\s+-\s*(.+)$/);
    if (listeEsi && acikListe) {
      cikti[acikListe].push(listeEsi[1].replace(/^["']|["']$/g, ''));
      continue;
    }
    const esle = satir.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (!esle) { acikListe = null; continue; }
    const [, anahtar, deger] = esle;
    if (deger === '') { cikti[anahtar] = []; acikListe = anahtar; }
    else { cikti[anahtar] = deger.replace(/^["']|["']$/g, ''); acikListe = null; }
  }
  return cikti;
}

function paketleriBul(kok) {
  const bulunan = [];
  for (const ad of readdirSync(kok)) {
    const dizin = join(kok, ad);
    if (!statSync(dizin).isDirectory()) continue;
    const manifest = join(dizin, 'ahi.manifest.yaml');
    if (existsSync(manifest)) bulunan.push({ ad, dizin, manifest });
  }
  return bulunan.sort((a, b) => a.ad.localeCompare(b.ad));
}

function lisanslariOlc(paketDizini) {
  const pkgYolu = join(paketDizini, 'package.json');
  if (!existsSync(pkgYolu)) return { durum: 'bagimlilik-yok', kalemler: [] };
  let pkg;
  try { pkg = JSON.parse(readFileSync(pkgYolu, 'utf8')); }
  catch { return { durum: 'olculemedi', neden: 'package.json okunamadi', kalemler: [] }; }

  const bagimliliklar = Object.keys({ ...(pkg.dependencies || {}) });
  if (bagimliliklar.length === 0) return { durum: 'bagimlilik-yok', kalemler: [] };

  const nodeModules = join(paketDizini, 'node_modules');
  if (!existsSync(nodeModules)) {
    // Kurulu değilse lisans OKUNAMAZ. Bunu "temiz" saymak sahte-yeşil olurdu.
    return { durum: 'olculemedi', neden: 'node_modules kurulu degil', kalemler: bagimliliklar.map((ad) => ({ ad, lisans: null, sinif: 'olculemedi' })) };
  }
  const kalemler = bagimliliklar.map((ad) => {
    const depPkg = join(nodeModules, ad, 'package.json');
    if (!existsSync(depPkg)) return { ad, lisans: null, sinif: 'olculemedi' };
    try {
      const j = JSON.parse(readFileSync(depPkg, 'utf8'));
      const lisans = typeof j.license === 'string' ? j.license
        : (j.license && j.license.type) ? j.license.type
        : (Array.isArray(j.licenses) && j.licenses[0]?.type) || null;
      return { ad, lisans, sinif: lisansSinifi(lisans) };
    } catch { return { ad, lisans: null, sinif: 'olculemedi' }; }
  });
  return { durum: 'olculdu', kalemler };
}

const paketler = paketleriBul(repoRoot).filter((p) => !tekPaket || p.ad === tekPaket);
if (paketler.length === 0) {
  console.error(tekPaket ? `paket bulunamadi: ${tekPaket}` : `${repoRoot} altinda ahi.manifest.yaml tasiyan paket yok`);
  process.exit(2);
}

const bulgular = [];
let kunyeliSayi = 0;
const satirlar = [];

for (const p of paketler) {
  let m;
  try { m = manifestOku(p.manifest); }
  catch (e) { satirlar.push(`  ?  ${p.ad.padEnd(22)} kunye: olculemedi (${e.message})`); bulgular.push(`${p.ad}: manifest okunamadi`); continue; }

  const sahip = typeof m.owner === 'string' && m.owner.trim() ? m.owner.trim() : null;
  const tuketiciler = Array.isArray(m.consumers) ? m.consumers : (typeof m.consumers === 'string' && m.consumers.trim() ? [m.consumers.trim()] : []);
  if (sahip) kunyeliSayi++; else bulgular.push(`${p.ad}: sahip (owner) beyan edilmemis`);

  const lis = lisanslariOlc(p.dizin);
  const bulasanlar = lis.kalemler.filter((k) => k.sinif === 'bulasan');
  const olculemeyen = lis.kalemler.filter((k) => k.sinif === 'olculemedi');
  if (bulasanlar.length) bulgular.push(`${p.ad}: kopyaya-bulasan lisans -> ${bulasanlar.map((k) => `${k.ad}(${k.lisans})`).join(', ')}`);

  const kunyeIsaret = sahip ? '✓' : '✗';
  const sahipMetin = sahip ? `${sahip}${tuketiciler.length ? ` -> ${tuketiciler.join(',')}` : ''}` : 'SAHIPSIZ';
  let lisMetin;
  if (lis.durum === 'bagimlilik-yok') lisMetin = 'npm bagimliligi yok';
  else if (lis.durum === 'olculemedi') lisMetin = `olculemedi (${lis.neden}; ${lis.kalemler.length} bagimlilik)`;
  else lisMetin = `${lis.kalemler.length} bagimlilik · bulasan=${bulasanlar.length} · olculemedi=${olculemeyen.length}`;

  satirlar.push(`  ${kunyeIsaret}  ${p.ad.padEnd(22)} kunye: ${sahipMetin.padEnd(28)} lisans: ${lisMetin}`);
}

console.log(`\nAHÎ künye + lisans raporu — ${repoRoot}`);
console.log(`paket: ${paketler.length} · künyeli: ${kunyeliSayi} · künyesiz: ${paketler.length - kunyeliSayi}\n`);
for (const s of satirlar) console.log(s);

if (bulgular.length) {
  console.log(`\nbulgular (${bulgular.length}):`);
  for (const b of bulgular) console.log(`  - ${b}`);
} else {
  console.log('\nbulgu yok.');
}

if (strict && bulgular.length) {
  console.log('\n--strict: bulgu var -> exit 1');
  process.exit(1);
}
console.log(strict ? '\n--strict: temiz -> exit 0' : '\nrapor-modu (bloklamaz) -> exit 0');
process.exit(0);
