// trust_boundary.mjs — KANDIRILAMAZ verdict-runner (FAZ-1, MOTOR-sınıfı: proje-bilmez).
// PASS/FAIL kararını LLM değil BU SÜREÇ verir: komutu kendisi koşar, RC'yi kendisi yakalar,
// sayaçları runner-adapter'la kendisi parse eder, kanıt-JSON'u FORMAT §4 şemasına kendisi yazar.
// Builder'ın "koştum, geçti" beyanı kanıt DEĞİLDİR — kanıt yalnız bu sürecin emit ettiği JSON'dur.
// Sayaç-kuralı (tasarım §5.3): parse-fail => counters=null = ZAYIF-işaret (asla sessiz-PASS'e
// default'lanmaz; zayıflık rejenerasyon-raporunda isimli). Kırmızı-mod (--as-kirmizi): rc==0
// gelirse SÜREÇ KENDİSİ FAIL eder — "hiç-FAIL-edemeyen test" kırmızı-kanıt olarak kaydedilemez.
import { createHash } from 'node:crypto';
import { writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync, execFileSync } from 'node:child_process';
import { resolve, dirname, basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.2.0-faz1';

export function sha256Hex(metin) {
  return createHash('sha256').update(metin, 'utf8').digest('hex');
}

function anaDepoKoku(baslangicDizini) {
  try {
    const cikti = execFileSync('git', ['rev-parse', '--git-common-dir'], {
      cwd: baslangicDizini, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    const mutlak = resolve(baslangicDizini, cikti);
    return basename(mutlak) === '.git' ? dirname(mutlak) : mutlak;
  } catch { return null; }
}

// ── RUNNER-ADAPTER KATALOĞU ──────────────────────────────────────────
// Her adapter: (stdout+stderr) -> {counters|null, notlar[]}. Yalnız SAYAÇ parse eder;
// RC-normalizasyonu (yumuşatma-yasağı) tek-noktada kosVeKanitla'da.
const ADAPTERLER = {
  // pytest: "N passed", "N failed", "N skipped" özet-satırından.
  pytest(cikti) {
    const al = (ad) => {
      const m = cikti.match(new RegExp(`(\\d+) ${ad}`));
      return m ? Number(m[1]) : 0;
    };
    const passed = al('passed'); const failed = al('failed');
    const skipped = al('skipped'); const errors = al('error');
    if (passed + failed + skipped + errors === 0 && !/no tests ran/i.test(cikti)) {
      return { counters: null, notlar: ['pytest sayaç-parse başarısız — counters=null (ZAYIF)'] };
    }
    return { counters: { collected: passed + failed + skipped + errors, passed, failed: failed + errors, skipped }, notlar: [] };
  },
  // vitest: "Tests  N failed | M passed | K skipped (T)" özet-satırından.
  vitest(cikti) {
    const m = cikti.match(/Tests\s+(?:(\d+) failed \| )?(\d+) passed(?: \| (\d+) skipped)?\s*\((\d+)\)/);
    if (m) {
      return { counters: { collected: Number(m[4]), passed: Number(m[2]), failed: Number(m[1] ?? 0), skipped: Number(m[3] ?? 0) }, notlar: [] };
    }
    const f = cikti.match(/Tests\s+(\d+) failed\s*\((\d+)\)/); // tamamı-fail hâli
    if (f) return { counters: { collected: Number(f[2]), passed: 0, failed: Number(f[1]), skipped: 0 }, notlar: [] };
    return { counters: null, notlar: ['vitest sayaç-parse başarısız — counters=null (ZAYIF)'] };
  },
  // node --test (TAP-özeti): "# tests N / # pass N / # fail N / # skipped N"
  'node-test'(cikti) {
    const al = (ad) => {
      const m = cikti.match(new RegExp(`# ${ad} (\\d+)`));
      return m ? Number(m[1]) : null;
    };
    const tests = al('tests'); const pass = al('pass'); const fail = al('fail'); const skipped = al('skipped');
    if (tests === null || pass === null) {
      return { counters: null, notlar: ['node--test sayaç-parse başarısız — counters=null (ZAYIF)'] };
    }
    return { counters: { collected: tests, passed: pass, failed: fail ?? 0, skipped: skipped ?? 0 }, notlar: [] };
  },
  // generic-rc: sayaç YOK — en zayıf sınıf (counters=null her zaman; gate-manşet kuralı teslim-lint'te).
  'generic-rc'() {
    return { counters: null, notlar: ['generic-rc: sayaç-kanıtı yok (tanım-gereği ZAYIF-sınıf)'] };
  },
};

// Komutu koşar, kanıt-JSON'u yazar. Dönüş: {kanit, kanitYolu, log}.
export function kosVeKanitla({ mId, komut, runner, kanitDizini, cwd, kirmiziRef = null, asKirmizi = false, zamanAsimiMs = 600000 }) {
  const adapter = ADAPTERLER[runner];
  if (!adapter) throw new Error(`bilinmeyen runner: ${runner} (katalog: ${Object.keys(ADAPTERLER).join(', ')})`);

  const baslangic = new Date().toISOString();
  const sonucSurec = spawnSync('sh', ['-c', komut], {
    cwd, encoding: 'utf8', timeout: zamanAsimiMs, maxBuffer: 64 * 1024 * 1024,
  });
  const bitis = new Date().toISOString();
  const cikti = (sonucSurec.stdout ?? '') + '\n' + (sonucSurec.stderr ?? '');
  let rc = sonucSurec.status ?? 1; // sinyal/zaman-aşımıyla ölüm = FAIL (null status asla PASS olmaz)

  const { counters, notlar } = adapter(cikti);
  // RC-normalizasyonu TEK-NOKTA (yalnız SERTLEŞTİRİR, asla yumuşatmaz):
  // pytest exit-5 = hiç-test-toplanmadı = FAIL (no-tests=no-proof — tasarım §5.3 runner-kuralı-1'in kökü).
  if (runner === 'pytest' && sonucSurec.status === 5) {
    rc = 1;
    notlar.push('pytest exit-5: hiç test toplanmadı — FAIL sayıldı (no-tests=no-proof)');
  }

  // Kırmızı-mod sahicilik-kilidi: FAIL-etmesi BEKLENEN koşum rc=0 döndüyse bu "kırmızı-kanıt" değildir.
  if (asKirmizi && rc === 0) {
    throw new Error(`KIRMIZI-MOD İHLALİ (${mId}): koşum rc=0 döndü — FAIL-etmeyen koşum kırmızı-kanıt olarak KAYDEDİLEMEZ (sahte-kırmızı yasağı)`);
  }

  const depoKoku = anaDepoKoku(cwd ?? process.cwd());
  const kanit = {
    m_id: mId,
    komut,
    komut_sha256: sha256Hex(komut),
    rc,
    counters,
    started_at: baslangic,
    finished_at: bitis,
    runner,
    kirmizi_kanit_ref: asKirmizi ? null : kirmiziRef,
    skill_version: SKILL_VERSION,
    proje_koku: depoKoku,
    config_yolu: process.env.TESLIM_CONFIG ?? null,
    ...(notlar.length ? { notlar } : {}),
  };

  mkdirSync(kanitDizini, { recursive: true });
  const dosyaAdi = asKirmizi ? `${mId}-kirmizi.json` : `${mId}.json`;
  const kanitYolu = join(kanitDizini, dosyaAdi);
  writeFileSync(kanitYolu, JSON.stringify(kanit, null, 2) + '\n');
  return { kanit, kanitYolu, log: cikti };
}

function kullanim() {
  process.stderr.write(
    'kullanım: node trust_boundary.mjs --m-id <M#> --cmd <komut> --runner <pytest|vitest|node-test|generic-rc> --kanit <dizin> [--cwd <dizin>] [--kirmizi-ref <yol>] [--as-kirmizi]\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  const arg = {};
  for (let i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case '--m-id': arg.mId = argv[++i]; break;
      case '--cmd': arg.komut = argv[++i]; break;
      case '--runner': arg.runner = argv[++i]; break;
      case '--kanit': arg.kanitDizini = argv[++i]; break;
      case '--cwd': arg.cwd = argv[++i]; break;
      case '--kirmizi-ref': arg.kirmiziRef = argv[++i]; break;
      case '--as-kirmizi': arg.asKirmizi = true; break;
      default: kullanim();
    }
  }
  if (!arg.mId || !arg.komut || !arg.runner || !arg.kanitDizini) kullanim();
  try {
    const { kanit, kanitYolu } = kosVeKanitla(arg);
    process.stderr.write(`kanıt yazıldı: ${kanitYolu} (rc=${kanit.rc}${kanit.counters ? `, ${kanit.counters.passed}/${kanit.counters.collected} passed` : ', counters=null ZAYIF'})\n`);
    process.stdout.write(JSON.stringify(kanit, null, 2) + '\n');
    // Çıkış-kodu = koşumun RC'si (kırmızı-modda FAIL-koşum kanıt-yazımı BAŞARILIDIR -> 0).
    process.exit(arg.asKirmizi ? 0 : (kanit.rc === 0 ? 0 : 1));
  } catch (hata) {
    process.stderr.write(`trust_boundary: ${hata.message}\n`);
    process.exit(3);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
