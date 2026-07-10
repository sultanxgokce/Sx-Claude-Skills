// enjeksiyon.mjs — ULTIMATE-dogfood enjeksiyon-harness (generic mekanik, proje-bilmez).
// Panele kasıtlı defekt sokar, hedef-senaryonun KIRMIZI-döndüğünü kanıtlar (senaryo gerçekten-test-ediyor).
// GÜVENLİK: mutant panel Playwright-route ile YERİNDE sunulur (document+assets scratch-mutant'tan; API canlı
// backend'e continue). Origin DAİMA panel-allowlist (config'ten, origin-exact) — dış-origin YOK. Canlı panel/dist
// ASLA-dokunulmaz. panel/src mutasyonu backup+finally-restore + son git-diff-temiz teyidi (garantili-geri-al).
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { spawnSync, execFileSync } from 'node:child_process';
import { resolve, join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import process from 'node:process';
import { acStandart } from './kesif_lib.mjs';
import { apiCek } from './e2e-run.mjs';

export const SKILL_VERSION = '0.1.0-faz0';

function anaDepoKoku(cwd) {
  return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, encoding: 'utf8' }).trim();
}

// Mutant dist'i Playwright-route ile sun: YALNIZ document(/, *.html) + /assets/* scratch-mutant'tan
// fulfill; DİĞER her istek (API vb.) canlı-backend'e continue (return false). Generic — endpoint-BİLMEZ
// (SPA-statik/API ayrımı yol-türünden: document+asset serve, gerisi backend).
function mutantRoute(mutantDist) {
  return async (route, url) => {
    const yol = new URL(url).pathname;
    if (yol === '/' || yol.endsWith('.html')) {
      route.fulfill({ status: 200, contentType: 'text/html', body: readFileSync(join(mutantDist, 'index.html'), 'utf8') });
      return true;
    }
    if (yol.startsWith('/assets/')) {
      const ad = basename(yol);
      const dosya = join(mutantDist, 'assets', ad);
      if (existsSync(dosya)) {
        const ct = ad.endsWith('.js') ? 'application/javascript' : ad.endsWith('.css') ? 'text/css' : 'application/octet-stream';
        route.fulfill({ status: 200, contentType: ct, body: readFileSync(dosya) });
        return true;
      }
    }
    return false; // document/asset değil → canlı-backend'e devam (API dahil)
  };
}

// bos-asset: canlı index.html yüklenir AMA /assets/*.js boş-fulfill → React mount-etmez.
function bosAssetRoute() {
  return async (route, url) => {
    const yol = new URL(url).pathname;
    if (yol.startsWith('/assets/') && yol.endsWith('.js')) {
      route.fulfill({ status: 200, contentType: 'application/javascript', body: '/* enjeksiyon: boş JS — React mount-etmez */' });
      return true;
    }
    return false;
  };
}

// panel/src mutasyonu → scratch-outDir build → geri-al. Dönüş: mutantDist yolu.
function mutantBuild({ repoKoku, dosya, ara, yerine, scratchDir }) {
  const tam = join(repoKoku, dosya);
  const orijinal = readFileSync(tam, 'utf8');
  if (!orijinal.includes(ara)) throw new Error(`enjeksiyon-ara bulunamadı (${dosya}): ${ara.slice(0, 40)}...`);
  const mutant = orijinal.split(ara).join(yerine);
  if (mutant === orijinal) throw new Error(`mutasyon no-op (${dosya}) — ara==yerine?`);
  const mutantDist = join(scratchDir, 'dist');
  try {
    writeFileSync(tam, mutant);
    const r = spawnSync('sh', ['-c', `cd "${join(repoKoku, 'panel')}" && npx vite build --outDir "${mutantDist}" --emptyOutDir`], {
      encoding: 'utf8', timeout: 180000,
    });
    if (r.status !== 0) throw new Error(`mutant-build FAIL (${dosya}): ${(r.stderr || r.stdout || '').slice(-400)}`);
  } finally {
    writeFileSync(tam, orijinal); // GARANTİLİ-GERİ-AL (build-fail'de bile)
  }
  if (!existsSync(join(mutantDist, 'index.html'))) throw new Error('mutant-dist index.html yok');
  return mutantDist;
}

async function birEnjeksiyon({ enj, senaryolar, panelUrl, allowlist, repoKoku, scratchKok, apiEndpoints, readySelector }) {
  const hedef = senaryolar.find((s) => s.ad === enj.hedef_senaryo);
  if (!hedef) throw new Error(`hedef-senaryo yok: ${enj.hedef_senaryo}`);

  let routeExtra;
  let mutantDist = null;
  if (enj.tip === 'bos-asset') {
    routeExtra = bosAssetRoute();
  } else if (enj.tip === 'mutant-build') {
    mutantDist = mutantBuild({ repoKoku, dosya: enj.dosya, ara: enj.ara, yerine: enj.yerine, scratchDir: join(scratchKok, enj.ad) });
    routeExtra = mutantRoute(mutantDist);
  } else {
    throw new Error(`bilinmeyen enjeksiyon-tipi: ${enj.tip}`);
  }

  // API ground-truth (canlı backend'ten, PROJE-config uçlarından) — senaryo çapraz-kanıt için
  const api = await apiCek(panelUrl.replace(/\/$/, ''), apiEndpoints);

  const { page, blocked, kapat } = await acStandart({ allowlist, routeExtra });
  let sonuc;
  try {
    await page.goto(panelUrl, { waitUntil: 'networkidle', timeout: 20000 });
    if (readySelector) await page.waitForSelector(readySelector, { timeout: 6000 }).catch(() => {});
    try {
      sonuc = await hedef.calistir(page, api);
    } catch (e) {
      sonuc = { gecti: false, detay: `istisna: ${e.message}` };
    }
  } finally {
    await kapat();
  }

  // ULTIMATE-ölçüt: enjeksiyon-altında hedef-senaryo KIRMIZI (gecti=false) olmalı.
  const yakalandi = sonuc.gecti === false;
  return {
    ad: enj.ad, tip: enj.tip, hedef_senaryo: enj.hedef_senaryo, aciklama: enj.aciklama,
    senaryo_gecti: sonuc.gecti, yakalandi, harness_hata: false, detay: sonuc.detay,
    allowlist_ihlali: blocked.length, mutant_dist: mutantDist,
  };
}

// Bulgu-1 (v0.1.1): mutantBuild-fırlatmalarının kökü apparat-kırılganlığı olabilir (anchor-metni
// gerçek-uncommitted-diff'le kaymış/silinmiş) — bu durum 'KAÇTI(!!)' (gerçek anti-false-green
// başarısızlığı) İLE AYNI ANLAMA GELMEZ. HARNESS-HATA ayrı-etiketlenir ki "kaçtı" sinyali güvenilir
// kalsın (kök=anchor-fragility ≠ hollow-senaryo).
const HARNESS_HATA_DESENI = /enjeksiyon-ara bulunamadı|mutasyon no-op|mutant-build FAIL|mutant-dist index\.html yok/;

export async function kosEnjeksiyonlar({ panelUrl, allowlist, senaryolarYolu, enjeksiyonlarYolu, kanitDizini, scratchKok }) {
  mkdirSync(kanitDizini, { recursive: true });
  const repoKoku = anaDepoKoku(resolve(senaryolarYolu, '..'));
  const mod = await import(pathToFileURL(resolve(senaryolarYolu)).href);
  const { senaryolar, apiEndpoints, readySelector } = mod;
  const { enjeksiyonlar } = await import(pathToFileURL(resolve(enjeksiyonlarYolu)).href);

  const sonuclar = [];
  for (const enj of enjeksiyonlar) {
    let s;
    try {
      s = await birEnjeksiyon({ enj, senaryolar, panelUrl, allowlist, repoKoku, scratchKok, apiEndpoints, readySelector });
    } catch (e) {
      const harnessMi = HARNESS_HATA_DESENI.test(e.message);
      s = {
        ad: enj.ad, tip: enj.tip, hedef_senaryo: enj.hedef_senaryo,
        yakalandi: false, harness_hata: harnessMi,
        detay: `${harnessMi ? 'HARNESS-HATA' : 'HATA'}: ${e.message}`, allowlist_ihlali: 0,
      };
    }
    sonuclar.push(s);
  }

  // GARANTİLİ-GERİ-AL teyidi: panel/src git-diff TEMİZ olmalı (mutasyonlar geri-alındı)
  let srcTemiz = true;
  let diffCikti = '';
  try {
    diffCikti = execFileSync('git', ['diff', '--name-only', '--', 'panel/src'], { cwd: repoKoku, encoding: 'utf8' }).trim();
    srcTemiz = diffCikti === '';
  } catch { srcTemiz = false; }

  const yakalanan = sonuclar.filter((s) => s.yakalandi).length;
  const harnessHatali = sonuclar.filter((s) => s.harness_hata).length;
  const kacanGercek = sonuclar.length - yakalanan - harnessHatali; // harness-hatalı hariç gerçek-kaçan
  const ihlal = sonuclar.reduce((n, s) => n + (s.allowlist_ihlali || 0), 0);
  const rapor = {
    skill_version: SKILL_VERSION, panel_url: panelUrl, allowlist,
    toplam: sonuclar.length, yakalanan, kacan: kacanGercek, harness_hatali: harnessHatali,
    panel_src_temiz: srcTemiz, panel_src_diff: diffCikti,
    allowlist_ihlali_toplam: ihlal, enjeksiyonlar: sonuclar,
  };
  writeFileSync(join(kanitDizini, 'e2e-enjeksiyon.json'), JSON.stringify(rapor, null, 2) + '\n');
  return rapor;
}

function kullanim() {
  process.stderr.write('kullanım: node enjeksiyon.mjs --panel-url <url> --allowlist <csv> --senaryolar <p> --enjeksiyonlar <p> --kanit <dir> --scratch <dir>\n');
  process.exit(2);
}

async function main() {
  const argv = process.argv.slice(2);
  const arg = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--panel-url') arg.panelUrl = argv[++i];
    else if (a === '--allowlist') arg.allowlist = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--senaryolar') arg.senaryolarYolu = argv[++i];
    else if (a === '--enjeksiyonlar') arg.enjeksiyonlarYolu = argv[++i];
    else if (a === '--kanit') arg.kanitDizini = argv[++i];
    else if (a === '--scratch') arg.scratchKok = argv[++i];
    else kullanim();
  }
  if (!arg.panelUrl || !arg.allowlist || !arg.senaryolarYolu || !arg.enjeksiyonlarYolu || !arg.kanitDizini || !arg.scratchKok) kullanim();
  const rapor = await kosEnjeksiyonlar(arg);
  for (const s of rapor.enjeksiyonlar) {
    const etiket = s.yakalandi ? 'YAKALANDI(kırmızı)' : s.harness_hata ? 'HARNESS-HATA(apparat-kırılgan)' : 'KAÇTI(!!)';
    process.stderr.write(`${etiket} · ${s.ad} → hedef=${s.hedef_senaryo} senaryo_gecti=${s.senaryo_gecti} — ${s.detay}\n`);
  }
  process.stderr.write(`ENJEKSİYON: ${rapor.yakalanan}/${rapor.toplam} yakalandı · harness-hatalı=${rapor.harness_hatali} · panel/src-temiz=${rapor.panel_src_temiz} · allowlist-ihlali=${rapor.allowlist_ihlali_toplam}\n`);
  process.stdout.write(JSON.stringify({ yakalanan: rapor.yakalanan, toplam: rapor.toplam, harness_hatali: rapor.harness_hatali, panel_src_temiz: rapor.panel_src_temiz }) + '\n');
  // GEÇER: hepsi-yakalandı ∧ harness-hata-yok ∧ src-temiz ∧ allowlist-ihlali-yok
  // (harness-hata AYRICA fail eder — apparat-kırılganken "temiz-geçti" denemez; ama etiketi ayrı
  // olduğundan operatör 'gerçek-kaçan-bug' ile 'anchor-tamiri-lazım'ı karıştırmaz.)
  process.exit(rapor.kacan === 0 && rapor.harness_hatali === 0 && rapor.panel_src_temiz && rapor.allowlist_ihlali_toplam === 0 ? 0 : 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
