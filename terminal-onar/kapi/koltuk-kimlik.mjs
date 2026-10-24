// koltuk-kimlik.mjs — oturumun AD DIŞI kimliği (2.24.0 · P4GT2W). Kabuk eşi: scripts/koltuk-adi.sh koltuk_kimlik (aynı formül:
// 'k' + sha256(tuz \n ad) ilk 16 onaltılık; tuz kutuya özel, gizli). Eşdeğerlik: scripts/koltuk-kimlik.test.sh.
// Tuz okunamaz/yaratılamazsa kimlik NULL döner — ad adrese geri DÜŞMEZ, çağıran kimliksiz kaydı kimliksiz bırakır.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const KOLTUK_KIMLIK_DESEN = /^k[0-9a-f]{16}$/;
const tuzYolu = () => process.env.KOLTUK_TUZ || path.join(process.env.HOME || '/config', '.koltuk-tuz');

const TUZ_DESEN = /^[0-9a-f]{32}$/;
// Var olan tuz yalnız şu üç şartla kullanılır (göz tur 1): bu kullanıcıya ait · biçimi 32 onaltılık · kipi 600. Kip gevşekse ve dosya
// bizimse 600'e çekilir; başkasınınsa ya da biçimi bozuksa KULLANILMAZ (null → kimlik yok, adres yok). Kabuk eşi aynı kuralı taşır.
function tuzGecerli(y) {
  let st; try { st = fs.statSync(y); } catch { return null; }
  if (!st.isFile() || (typeof process.getuid === 'function' && st.uid !== process.getuid())) return null;
  if ((st.mode & 0o077) !== 0) { try { fs.chmodSync(y, 0o600); } catch { return null; } }
  let t; try { t = fs.readFileSync(y, 'utf8'); } catch { return null; }
  return TUZ_DESEN.test(t) ? t : null;
}

export function koltukTuz() {
  const y = tuzYolu();
  if (fs.existsSync(y)) return tuzGecerli(y);
  try {
    const g = `${y}.${process.pid}.${crypto.randomBytes(4).toString('hex')}`;
    fs.writeFileSync(g, crypto.randomBytes(16).toString('hex'), { mode: 0o600 });
    try { fs.linkSync(g, y); } catch { /* başkası önce yarattı → onunkini oku */ }
    fs.rmSync(g, { force: true });
    return tuzGecerli(y);
  } catch { return null; }
}

export function koltukKimlik(ad) {
  const t = koltukTuz();
  if (!t) return null;
  return 'k' + crypto.createHash('sha256').update(t + '\n' + String(ad)).digest('hex').slice(0, 16);
}
