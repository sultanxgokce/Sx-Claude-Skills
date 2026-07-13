// sayac_baseline.mjs — §1.5 SAYAÇ-BASELINE denetçisi (FAZ-2/F1, MOTOR-sınıfı: proje-bilmez).
// KAPATILAN CANLI-DELİK: per-M `-t <filtre>` koşumu skipped üretip gate-geçebiliyordu (tam-suite
// baseline ayrı-zorlanmıyordu). İki mekanik + bir flag:
//   (1) HASH-SABİT: her gate-kanıtının komut_sha256'sı baseline-deklarasyonuyla AYNI olmalı →
//       filtreli/değiştirilmiş komut (farklı sha256) uyuşmazlıktan FAIL (asıl-delik kapanır);
//   (2) COUNTER-FLOOR: sayaçlı-runner için collected >= min_collected ∧ skipped <= max_skipped
//       (parse-fail counters=null ASLA PASS'e default'lanmaz — ZAYIF=İHLAL);
//   (3) SAYAÇ-KANITSIZ flag: hiç sayaçlı-runner yoksa gecti-OLABİLİR ama flag set (teslim-lint manşet basar).
// baseline-store = JSON (node-native; YAML-parse YOK). Integrity: baseline entry komut_sha256'sı,
// entry.komut'un kendi hash'iyle uyuşmalı (elle-oynama tespiti). Gate-kanıtı adı: kanit/gate-<id>.json.
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.2.1-faz1';

export function sha256Hex(metin) {
  return createHash('sha256').update(metin, 'utf8').digest('hex');
}

// Bir baseline-store + kanıt-dizinini denetler. Dönüş:
//   { gecti, ihlaller[], sayac_kanitsiz, kontrol_edilen, sayacli_kontrol }
export function baselineDenetle({ baselineYolu, kanitDizini }) {
  const ihlaller = [];
  let store;
  try {
    store = JSON.parse(readFileSync(baselineYolu, 'utf8'));
  } catch (hata) {
    return { gecti: false, ihlaller: [`baseline-store okunamadı: ${hata.message}`], sayac_kanitsiz: false, kontrol_edilen: 0, sayacli_kontrol: 0 };
  }
  const gateler = Array.isArray(store.gate_cmds) ? store.gate_cmds : [];
  if (gateler.length === 0) {
    return { gecti: false, ihlaller: ['baseline-store boş: gate_cmds yok'], sayac_kanitsiz: false, kontrol_edilen: 0, sayacli_kontrol: 0 };
  }

  let sayacliKontrol = 0; // kaç gate-cmd sayaçlı-runner olarak FİİLEN sayaç-kontrolünden geçti
  for (const g of gateler) {
    const id = g.id ?? '<isimsiz>';
    const sayacliBeklenir = typeof g.min_collected === 'number'; // baseline min_collected → counter-runner

    // (0) baseline INTEGRITY: entry.komut_sha256, entry.komut'un hash'iyle uyuşmalı (elle-oynama tespiti)
    if (typeof g.komut !== 'string' || typeof g.komut_sha256 !== 'string') {
      ihlaller.push(`baseline-bozuk (${id}): komut/komut_sha256 alanı eksik`);
      continue;
    }
    if (sha256Hex(g.komut) !== g.komut_sha256) {
      ihlaller.push(`baseline-bozuk-integrity (${id}): baseline komut_sha256, komut'un hash'iyle uyuşmuyor (elle-oynama?)`);
      continue;
    }

    // (1) gate-kanıtı var mı
    const kanitYolu = join(kanitDizini, `gate-${id}.json`);
    if (!existsSync(kanitYolu)) {
      ihlaller.push(`gate-kanıtı yok (${id}): ${kanitYolu} — baseline-deklareli gate koşulmamış`);
      continue;
    }
    let kanit;
    try {
      kanit = JSON.parse(readFileSync(kanitYolu, 'utf8'));
    } catch (hata) {
      ihlaller.push(`gate-kanıtı geçersiz-JSON (${id}): ${hata.message}`);
      continue;
    }

    // (2) HASH-SABİT: gate-kanıtının komutu baseline-deklarasyonuyla AYNI olmalı (asıl-gaming-kilit)
    if (kanit.komut_sha256 !== g.komut_sha256) {
      ihlaller.push(`hash-uyuşmazlığı (${id}): gate-kanıtı komut_sha256≠baseline (filtreli/değiştirilmiş komutla koşulmuş?)`);
      continue;
    }
    // (3) rc==0
    if (kanit.rc !== 0) {
      ihlaller.push(`gate-kanıtı FAIL (${id}): rc=${kanit.rc}`);
      continue;
    }

    // (4) COUNTER-FLOOR — yalnız sayaçlı-runner beklenen entry'lerde
    if (sayacliBeklenir) {
      const c = kanit.counters;
      if (!c || typeof c.collected !== 'number' || typeof c.skipped !== 'number') {
        // parse-fail counters=null → ASLA PASS'e default'lanmaz (ZAYIF=İHLAL)
        ihlaller.push(`SAYAÇ-KANITSIZ (${id}): sayaçlı-runner beklendi ama counters yok/eksik (parse-fail ≠ PASS)`);
        continue;
      }
      const maxSkip = typeof g.max_skipped === 'number' ? g.max_skipped : 0;
      if (c.skipped > maxSkip) {
        ihlaller.push(`skipped-delta (${id}): koşumda ${c.skipped} skip > baseline max ${maxSkip} (filtreli/atlanmış-test?)`);
        continue;
      }
      if (c.collected < g.min_collected) {
        ihlaller.push(`collected-düşüş (${id}): koşumda ${c.collected} < baseline min ${g.min_collected} (test silinmiş/toplanamamış?)`);
        continue;
      }
      sayacliKontrol++;
    }
  }

  // Hiç sayaçlı-kontrol geçmediyse: sayaç-kanıtsız (teslim-lint manşet). İhlal DEĞİL ama zayıflık.
  const sayacKanitsiz = sayacliKontrol === 0;
  return {
    skill_version: SKILL_VERSION,
    gecti: ihlaller.length === 0,
    ihlaller,
    sayac_kanitsiz: sayacKanitsiz,
    kontrol_edilen: gateler.length,
    sayacli_kontrol: sayacliKontrol,
  };
}

function kullanim() {
  process.stderr.write('kullanım: node sayac_baseline.mjs --baseline <baseline.json> --kanit <dizin>\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  const arg = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--baseline') arg.baselineYolu = resolve(argv[++i]);
    else if (argv[i] === '--kanit') arg.kanitDizini = resolve(argv[++i]);
    else kullanim();
  }
  if (!arg.baselineYolu || !arg.kanitDizini) kullanim();
  const r = baselineDenetle(arg);
  for (const i of r.ihlaller) process.stderr.write(`sayac-baseline İHLAL: ${i}\n`);
  if (r.sayac_kanitsiz) process.stderr.write('sayac-baseline: SAYAÇ-KANITSIZ (hiç sayaçlı-runner geçmedi)\n');
  process.stdout.write(JSON.stringify(r) + '\n');
  // Çıkış-kodu: İHLAL→1. sayac_kanitsiz TEK-BAŞINA gate-kapatmaz (manşet-uyarısı); İHLAL kapatır.
  process.exit(r.gecti ? 0 : 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
