// Her koşu ölçüm basar (MEDDAH md.4): süre + maliyet + araç. İddialar ölçümden türetilir.
// Varsayılan defter: ./metrikler.jsonl (CWD) — --metrik ile değiştirilebilir.
import { appendFileSync, readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const surum = (() => {
  try {
    const p = JSON.parse(readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'));
    return `${p.name}@${p.version}`;
  } catch { return 'plan-motor@?'; }
})();

export function metrikBas({ komut, baslangicMs, rc, girdi, cikti, maliyetUsd = 0, dosya }) {
  const kayit = {
    ts: new Date().toISOString(),
    arac: surum,
    komut,
    sure_ms: Math.round(performance.now() - baslangicMs),
    maliyet_usd: maliyetUsd,
    girdi: girdi ?? null,
    cikti: cikti ?? null,
    rc,
  };
  const hedef = dosya ?? process.env.PLAN_MOTOR_METRIK ?? 'metrikler.jsonl';
  try {
    appendFileSync(hedef, JSON.stringify(kayit) + '\n');
  } catch (e) {
    console.error(`⚠ metrik defterine yazılamadı (${hedef}): ${e.message}`);
  }
  console.error(`📏 ${kayit.arac} · ${komut} · ${kayit.sure_ms} ms · $${maliyetUsd} · rc=${rc}`);
  return kayit;
}
