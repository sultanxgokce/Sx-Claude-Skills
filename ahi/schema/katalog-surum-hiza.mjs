#!/usr/bin/env node
// katalog-surum-hiza.mjs — catalog.json'daki her skill sürümü SKILL.md frontmatter sürümüyle AYNI mı? (görev …JBZET · kart katalog-surum-hiza)
//
// NİÇİN: catalog.json'daki `version` elle yazılıyor, SKILL.md'deki `version:` ise sync-skills.mjs'in otoritesi. İkisi sessizce ayrıştı:
//   29 Eki 2026 ölçümü — 82 girdinin 23'ü farklı (ilk elle sayım 17 demişti; path alanı olmayan girdileri saymıyordu) (tescil 0.3.0 ↔ 0.9.1, iskan 0.11.0 ↔ 0.11.5 …). Katalogu okuyan (Nexus Skill Kataloğu,
//   künye raporu) yanlış sürüm görür. Tek gerçek SKILL.md'dir (version-lint.mjs onu zorunlu kılar); katalog ona uydurulur.
//
// KULLANIM:  node ahi/schema/katalog-surum-hiza.mjs <repo-root>            → ölçer: sapma sayısı; sapma varsa rc 1, hiç sapma yoksa rc 0
//            node ahi/schema/katalog-surum-hiza.mjs <repo-root> --duzelt   → SKILL.md sürümünü kataloğa yazar: girdi KENDİ nesne sınırı içinde bulunur, yalnız
//                                                                            oradaki "version" değeri değişir (biçim/sıra korunur; version anahtarı yoksa dokunulmaz),
//                                                                            sonra TÜM katalog yeniden ölçülür; rc ölçüme göre
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

function olc(skills) {   // katalog girdileri ↔ SKILL.md: [sapma[], olculemedi[]]
  const sapma = [], olculemedi = [];
  for (const s of skills) {
    if (!s || typeof s !== 'object' || !s.id) { olculemedi.push(['?', 'girdi id taşımıyor']); continue; }
    const dz = skillDizini(s); const p = join(repoRoot, dz, 'SKILL.md');
    if (!existsSync(p)) { olculemedi.push([s.id, `${dz}/SKILL.md yok`]); continue; }
    const v = skillSurumu(readFileSync(p, 'utf8'));
    if (!v) { olculemedi.push([s.id, `${dz}/SKILL.md versiyonsuz`]); continue; }
    if (typeof s.version !== 'string' || s.version !== v) sapma.push([s.id, s.version ?? '(yok)', v]);
  }
  return [sapma, olculemedi];
}
const [sapma, olculemedi] = olc(skills);

// Girdi sınırları: ham metinde "skills" dizisinin her üst-düzey nesnesinin [baş, son) aralığı — dizge/kaçış bilinçli tarama.
// Düzeltme yalnız kendi nesnesinin İÇİNDE arar; komşuya taşamaz (göz tur 1: version'sız girdi komşusunun sürümünü bozabiliyordu).
export function girdiAraliklari(metin) {
  const k = metin.search(/"skills"\s*:\s*\[/); if (k < 0) return null;
  let i = metin.indexOf('[', k) + 1, derinlik = 0, bas = -1, dizge = false; const ar = [];
  for (; i < metin.length; i++) {
    const c = metin[i];
    if (dizge) { if (c === '\\') i++; else if (c === '"') dizge = false; continue; }
    if (c === '"') { dizge = true; continue; }
    if (c === '{') { if (derinlik === 0) bas = i; derinlik++; }
    else if (c === '}') { derinlik--; if (derinlik === 0 && bas >= 0) { ar.push([bas, i + 1]); bas = -1; } }
    else if (c === ']' && derinlik === 0) break;
  }
  return ar;
}
// Girdi nesnesinin ÜST düzeyindeki "version" değerinin konumu: [değerBaş, değerSon) — iç içe nesnedeki (ör. "kaynak": {"version": …}) version
// değil (göz tur 2 bulgusu). Dizge-bilinçli, derinlik sayan tarama; bulunmazsa null.
export function ustVersionKonumu(parca) {
  let derinlik = 0, i = 0, sonAnahtar = null;
  const dizgeOku = (j) => { let k = j + 1; while (k < parca.length) { if (parca[k] === '\\') k += 2; else if (parca[k] === '"') return k + 1; else k++; } return -1; };
  while (i < parca.length) {
    const c = parca[i];
    if (c === '"') { const son = dizgeOku(i); if (son < 0) return null;
      const kalan = parca.slice(son).match(/^\s*:/); const ust = derinlik === 1;   // yalnız girdinin kendi düzeyi
      if (ust && kalan) { sonAnahtar = JSON.parse(parca.slice(i, son)); i = son + kalan[0].length; continue; }
      if (ust && sonAnahtar === 'version') return [i, son];   // anahtardan sonraki değer dizgesi
      sonAnahtar = null; i = son; continue; }
    if (c === '{' || c === '[') derinlik++; else if (c === '}' || c === ']') derinlik--;
    else if (c === ',') sonAnahtar = null;
    else if (derinlik === 1 && sonAnahtar === 'version' && !/\s/.test(c)) return null;   // version değeri dizge değil (sayı/null): dokunulmaz
    i++;
  }
  return null;
}

function duzelt() {
  // Her sapan girdi KENDİ nesne aralığında bulunur (id JSON.parse ile okunur: boşluk/kaçış yazımından bağımsız) ve yalnız o aralıktaki
  // "version" değeri değişir. JSON yeniden yazılmaz (biçim, sıra, anahtar korunur). version anahtarı yoksa DOKUNULMAZ ve söylenir.
  let metin = ham, yazildi = 0, dokunulmadi = 0;
  const ar = girdiAraliklari(metin);
  if (!ar) { console.error('✗ katalog metninde "skills" dizisi bulunamadı — YAZILMADI'); process.exit(2); }
  const nesne = new Map();   // id → aralık (ham metinden ayrıştırılır)
  for (const [b, e] of ar) { try { const o = JSON.parse(metin.slice(b, e)); if (o && o.id) nesne.set(o.id, [b, e]); } catch { /* bozuk parça: eşlenmez */ } }
  for (const [id, eski, yeni] of [...sapma].sort((x, y) => (nesne.get(y[0])?.[0] ?? -1) - (nesne.get(x[0])?.[0] ?? -1))) {   // sondan başa: öndeki kaymalar aralıkları bozmasın
    const a = nesne.get(id);
    if (!a) { console.error(`  ✗ ${id}: katalog metninde girdi nesnesi bulunamadı — DOKUNULMADI`); dokunulmadi++; continue; }
    const parca = metin.slice(a[0], a[1]); const m = ustVersionKonumu(parca);   // yalnız ÜST düzey version; iç içe nesnedeki değil
    if (!m) { console.error(`  ✗ ${id}: girdinin üst düzeyinde dizge "version" anahtarı yok — DOKUNULMADI (elle ekle)`); dokunulmadi++; continue; }
    metin = metin.slice(0, a[0] + m[0]) + `"${yeni}"` + metin.slice(a[0] + m[1]); yazildi++;
    console.log(`  ✎ ${id}: ${eski} → ${yeni}`);
  }
  let yeniKatalog;
  try { yeniKatalog = JSON.parse(metin); } catch (e) { console.error(`✗ düzeltilmiş katalog JSON olarak bozuk (${e.message}) — YAZILMADI`); process.exit(2); }
  if (!yazildi) { console.log(`  düzeltildi: 0/${sapma.length} — dosyaya dokunulmadı`); return false; }
  writeFileSync(catalogP, metin);
  // yazdığını geri oku ve KATALOĞUN TAMAMINI SKILL.md'lerle yeniden ölç: "yazdım" demek yetmez (göz tur 1: yalnız düzeltilenler okunuyordu)
  const geri = JSON.parse(readFileSync(catalogP, 'utf8'));
  const [kalan] = olc(Array.isArray(geri.skills) ? geri.skills : []);
  console.log(`  düzeltildi: ${yazildi}/${sapma.length}${dokunulmadi ? ` · dokunulmadı ${dokunulmadi}` : ''} · yeniden ölçüm (tüm katalog): ${kalan.length ? kalan.length + ' sapma HÂLÂ var' : 'sapma 0'}`);
  return kalan.length === 0 && dokunulmadi === 0;
}

for (const [id, k, s] of sapma) console.log(`  ✗ SAPMA ${id}: katalog ${k} ≠ SKILL.md ${s}`);
for (const [id, n] of olculemedi) console.log(`  ◻ ÖLÇÜLEMEDİ ${id}: ${n}`);
console.log(`katalog↔SKILL.md: girdi ${skills.length} · sapma ${sapma.length} · ölçülemedi ${olculemedi.length}`);
if (DUZELT && sapma.length) {
  const ok = duzelt();
  if (!ok) process.exit(1);
  console.log('✓ katalog SKILL.md sürümlerine hizalandı (tüm katalog yeniden ölçüldü: sapma 0)');
  process.exit(olculemedi.length ? 3 : 0);
}
if (sapma.length) { console.error(`✗ ${sapma.length} sapma — SKILL.md tek gerçek; düzeltmek için: node ahi/schema/katalog-surum-hiza.mjs . --duzelt`); process.exit(1); }
if (olculemedi.length) { console.error(`◻ ${olculemedi.length} girdi ölçülemedi (SKILL.md yok/versiyonsuz) — "sapma yok" denemez`); process.exit(3); }
console.log('✓ sapma 0');
