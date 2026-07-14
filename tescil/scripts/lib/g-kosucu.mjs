// g-kosucu.mjs — TEK G-satırını TAZE koşar, şemalı kanit/G<i>.json yazar (tescil lib; DİVAN K5).
// KOMPOZİSYON: komut-koşumu sert-teslim core/trust_boundary.mjs (kosVeKanitla) üzerinden —
// PASS/FAIL'i LLM değil süreç verir; sır-maskesi core/redaction.mjs (redakte) YAZIM-ÖNCESİ.
// Core import edilemezse KENDİ minimal koşucusu/maskesi devreye girer ve SAPMA kanıt-JSON'da
// isimli raporlanır (sessiz-düşüş yok). Pipe-maskeleme yok: RC her zaman kaydedilir.
// Kullanım: node g-kosucu.mjs --g-b64 <base64(JSON g-objesi)> --out <deneme-dir>
//           --worktree <dir> --kart <k####> --deneme <n> --head-sha <sha> --skill-version <v>
// Çıkış: 0=GECTI · 1=KALDI · 3=harness-hata.
import { createHash } from 'node:crypto';
import { writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const TESCIL_KOKU = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');
const CIKTI_TAVAN = 64 * 1024; // 64KB (SKILL.md §5)

function coreAdaylari() {
  const aday = [];
  if (process.env.TESCIL_SERT_TESLIM_CORE) aday.push(process.env.TESCIL_SERT_TESLIM_CORE);
  aday.push(resolve(TESCIL_KOKU, '..', 'sert-teslim', 'core'));
  aday.push('/config/.claude/skills/sert-teslim/core');
  return aday;
}

async function coreYukle(dosya) {
  for (const dir of coreAdaylari()) {
    try {
      return { mod: await import(pathToFileURL(join(dir, dosya)).href), yol: join(dir, dosya) };
    } catch { /* sıradaki aday */ }
  }
  return { mod: null, yol: null };
}

// Fallback-maske (yalnız redaction.mjs import edilemezse; desenler oradan kopya — sapma raporlanır).
function fallbackRedakte(metin) {
  return metin
    .replace(/postgres:\/\/[^\s]+/g, '[REDACTED:pg-dsn]')
    .replace(/Bearer [A-Za-z0-9._-]+/g, '[REDACTED:bearer]')
    .replace(/gAAAAA[A-Za-z0-9_-]{20,}/g, '[REDACTED:fernet]')
    .replace(/AKIA[A-Z0-9]{16}/g, '[REDACTED:aws-key]')
    .replace(/(?<![^\s])[A-Za-z0-9+/]{40,}={0,2}(?![^\s])/g, '[REDACTED:b64]');
}

function argParse(argv) {
  const a = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--g-b64') a.gB64 = argv[++i];
    else if (argv[i] === '--out') a.out = argv[++i];
    else if (argv[i] === '--worktree') a.worktree = argv[++i];
    else if (argv[i] === '--kart') a.kart = argv[++i];
    else if (argv[i] === '--deneme') a.deneme = Number(argv[++i]);
    else if (argv[i] === '--head-sha') a.headSha = argv[++i];
    else if (argv[i] === '--skill-version') a.skillVersion = argv[++i];
    else { process.stderr.write(`bilinmeyen argüman: ${argv[i]}\n`); process.exit(3); }
  }
  return a;
}

async function main() {
  const a = argParse(process.argv.slice(2));
  if (!a.gB64 || !a.out || !a.worktree || !a.kart) {
    process.stderr.write('kullanım: g-kosucu.mjs --g-b64 <b64> --out <dir> --worktree <dir> --kart <k####> [--deneme n] [--head-sha sha] [--skill-version v]\n');
    process.exit(3);
  }
  const g = JSON.parse(Buffer.from(a.gB64, 'base64').toString('utf8'));
  const cwd = g.cwd ? resolve(a.worktree, g.cwd) : a.worktree;
  const kanitDizini = join(a.out, 'kanit');
  mkdirSync(kanitDizini, { recursive: true });
  const zamanAsimiMs = Number(process.env.TESCIL_G_TIMEOUT_MS || 600000);

  const tb = await coreYukle('trust_boundary.mjs');
  const red = await coreYukle('redaction.mjs');
  const sapmalar = [];

  const baslangic = new Date().toISOString();
  const t0 = Date.now();
  let rc; let log; let tbRef = null;
  if (tb.mod && typeof tb.mod.kosVeKanitla === 'function') {
    // BİRİNCİL YOL: sert-teslim trust_boundary — kanıt-JSON üreteci aynen (yeniden icat yok).
    const sonuc = tb.mod.kosVeKanitla({
      mId: g.id, komut: g.komut, runner: 'generic-rc',
      kanitDizini: join(kanitDizini, 'tb'), cwd, zamanAsimiMs,
    });
    rc = sonuc.kanit.rc;
    log = sonuc.log;
    tbRef = { kullanildi: true, ref: `kanit/tb/${g.id}.json`, skill_version: sonuc.kanit.skill_version, yol: tb.yol };
  } else {
    sapmalar.push('trust_boundary.mjs import edilemedi — yerleşik minimal koşucu kullanıldı (SAPMA)');
    const s = spawnSync('sh', ['-c', g.komut], { cwd, encoding: 'utf8', timeout: zamanAsimiMs, maxBuffer: 64 * 1024 * 1024 });
    rc = s.status ?? 1; // sinyal/zaman-aşımı = FAIL; null asla PASS olmaz (trust_boundary kuralı korunur)
    log = (s.stdout ?? '') + '\n' + (s.stderr ?? '');
    tbRef = { kullanildi: false, sapma: sapmalar[sapmalar.length - 1] };
  }
  const bitis = new Date().toISOString();

  // Sır-maskesi YAZIM-ÖNCESİ (SKILL.md §5) — desen-eşleşmesi de maskelenmiş metinde yapılır ki
  // beklenen_desen kanalıyla sır sızdırılamasın.
  let redakteFn; let redInfo;
  if (red.mod && typeof red.mod.redakte === 'function') {
    redakteFn = red.mod.redakte;
    redInfo = { kullanildi: true, skill_version: red.mod.SKILL_VERSION ?? null, yol: red.yol };
  } else {
    redakteFn = fallbackRedakte;
    sapmalar.push('redaction.mjs import edilemedi — fallback-desen maskesi kullanıldı (SAPMA)');
    redInfo = { kullanildi: false, sapma: sapmalar[sapmalar.length - 1] };
  }
  const temizLog = redakteFn(log ?? '');

  let desenEslesti = null;
  if (g.beklenen_desen) {
    try {
      desenEslesti = new RegExp(g.beklenen_desen, 'm').test(temizLog);
    } catch {
      desenEslesti = temizLog.includes(g.beklenen_desen);
      sapmalar.push('beklenen_desen RegExp derlenemedi — düz-metin araması yapıldı (SAPMA)');
    }
  }
  const beklenenRc = Number.isInteger(g.beklenen_rc) ? g.beklenen_rc : 0;
  const gecti = rc === beklenenRc && (desenEslesti === null || desenEslesti === true);

  const govde = Buffer.from(temizLog, 'utf8');
  const kirpildi = govde.byteLength > CIKTI_TAVAN;
  const hamKirpik = kirpildi ? govde.subarray(0, CIKTI_TAVAN).toString('utf8') : temizLog;

  const kanit = {
    g_id: g.id,
    kart: a.kart,
    deneme: a.deneme ?? 1,
    aciklama: g.aciklama ?? '',
    komut: g.komut,
    komut_sha256: sha256(g.komut),
    worktree: a.worktree,
    worktree_head_sha: a.headSha ?? null,
    zaman_utc: { baslangic, bitis },
    sure_sn: Math.round((Date.now() - t0) / 1000),
    exit_code: rc,
    beklenen: { rc: beklenenRc, desen: g.beklenen_desen ?? null },
    gozlenen: { rc, desen_eslesti: desenEslesti },
    sonuc: gecti ? 'GECTI' : 'KALDI',
    kanit_turu: g.tur,
    stdout_stderr_ham: hamKirpik,
    cikti_kirpildi: kirpildi,
    cikti_tam_sha256: sha256(temizLog), // redakte-TAM çıktının hash'i (kırpılan kuyruk doğrulanabilir kalır)
    tescil_skill_version: a.skillVersion ?? null,
    trust_boundary: tbRef,
    redaction: redInfo,
    ...(sapmalar.length ? { sapmalar } : {}),
  };
  const kanitYolu = join(kanitDizini, `${g.id}.json`);
  writeFileSync(kanitYolu, JSON.stringify(kanit, null, 2) + '\n');
  process.stderr.write(`${g.id}: ${kanit.sonuc} (rc=${rc}, beklenen_rc=${beklenenRc}${desenEslesti === null ? '' : `, desen=${desenEslesti}`}) → ${kanitYolu}\n`);
  process.exit(gecti ? 0 : 1);
}

main().catch((e) => { process.stderr.write(`g-kosucu: ${e.message}\n`); process.exit(3); });
