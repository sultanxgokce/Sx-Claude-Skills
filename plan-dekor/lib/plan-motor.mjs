// plan-motor köprüsü — SINIR YALNIZ CLI'DIR (dosya girdi → dosya çıktı → RC).
// Hiçbir plan-motor modülü import EDİLMEZ; motor taşınsa/sürümlense plan-dekor kırılmaz.
import { existsSync, readFileSync } from 'fs';
import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const buDizin = dirname(fileURLToPath(import.meta.url));

const ADAYLAR = [
  process.env.PLAN_MOTOR_DIR,
  resolve(buDizin, '..', '..', 'plan-motor'),   // kardeş skill (kanonik yerleşim)
  '/config/.claude/skills/plan-motor',
].filter(Boolean);

export const PLAN_MOTOR = ADAYLAR.find((a) => existsSync(join(a, 'cli.mjs'))) ?? null;

export function planMotorGerekli() {
  if (!PLAN_MOTOR) {
    throw new Error(
      'plan-motor bulunamadı. PLAN_MOTOR_DIR ver ya da `bash kur.sh` koş.\n  Aranan: ' + ADAYLAR.join('\n           ')
    );
  }
  return PLAN_MOTOR;
}

// plan-motor cli.mjs'i çağır → { rc, stdout, stderr }
export function motorKos(argumanlar, { sessiz = true } = {}) {
  const kok = planMotorGerekli();
  const r = spawnSync('node', [join(kok, 'cli.mjs'), ...argumanlar], {
    encoding: 'utf8',
    stdio: sessiz ? ['ignore', 'pipe', 'pipe'] : 'inherit',
  });
  if (r.error) throw new Error(`plan-motor çağrılamadı: ${r.error.message}`);
  return { rc: r.status ?? 3, stdout: r.stdout ?? '', stderr: r.stderr ?? '' };
}

// Modeli plan-motor'un KENDİ kapısından geçir. Kırmızıysa plan-dekor hiçbir şey yazmaz.
export function modeliDogrula(modelYolu) {
  const { rc, stdout, stderr } = motorKos(['dogrula', '--model', modelYolu]);
  return { gecti: rc === 0, rc, cikti: (stdout + stderr).trim() };
}

// Mimari kural denetimi (opsiyonel — kural-seti verilirse)
export function modeliDenetle(modelYolu, kuralSetiYolu, raporYolu) {
  const arg = ['denetle', '--model', modelYolu, '--kural-seti', kuralSetiYolu];
  if (raporYolu) arg.push('--rapor', raporYolu);
  const { rc, stdout, stderr } = motorKos(arg);
  return { gecti: rc === 0, rc, cikti: (stdout + stderr).trim() };
}

export function motorSurumu() {
  if (!PLAN_MOTOR) return null;
  try {
    const p = JSON.parse(readFileSync(join(PLAN_MOTOR, 'package.json'), 'utf8'));
    return `${p.name}@${p.version}`;
  } catch { return 'plan-motor@?'; }
}
