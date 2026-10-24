// koltuk-kimlik.mjs — oturumun AD DIŞI kimliği (2.24.0 · P4GT2W). Kabuk eşi: scripts/koltuk-adi.sh koltuk_kimlik (aynı formül:
// 'k' + sha256(tuz \n ad) ilk 16 onaltılık; tuz kutuya özel, gizli). Eşdeğerlik: scripts/koltuk-kimlik.test.sh.
// Tuz okunamaz/yaratılamazsa kimlik NULL döner — ad adrese geri DÜŞMEZ, çağıran kimliksiz kaydı kimliksiz bırakır.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const KOLTUK_KIMLIK_DESEN = /^k[0-9a-f]{16}$/;
const tuzYolu = () => process.env.KOLTUK_TUZ || path.join(process.env.HOME || '/config', '.koltuk-tuz');

export function koltukTuz() {
  const y = tuzYolu();
  try { const t = fs.readFileSync(y, 'utf8').slice(0, 64); if (t) return t; } catch { /* yok → yarat */ }
  try {
    const g = `${y}.${process.pid}.${crypto.randomBytes(4).toString('hex')}`;
    fs.writeFileSync(g, crypto.randomBytes(16).toString('hex'), { mode: 0o600 });
    try { fs.linkSync(g, y); } catch { /* başkası önce yarattı → onunkini oku */ }
    fs.rmSync(g, { force: true });
    const t = fs.readFileSync(y, 'utf8').slice(0, 64);
    return t || null;
  } catch { return null; }
}

export function koltukKimlik(ad) {
  const t = koltukTuz();
  if (!t) return null;
  return 'k' + crypto.createHash('sha256').update(t + '\n' + String(ad)).digest('hex').slice(0, 16);
}
