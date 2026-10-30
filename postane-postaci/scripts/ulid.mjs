/**
 * ulid — opak, sıralanabilir, çakışmaz kimlik.
 *
 * NİÇİN ULID, NİÇİN SLUG DEĞİL: slug addan türer; ad değişince kimlik kırılır.
 * `kisi.mjs:29` firma slug'ını kişi id'sine gömüyordu ve dosyanın kendi yorumu (`:52`)
 * bunu zaten yasaklıyordu — kural yazılmıştı, kod onu çiğniyordu.
 * ULID içeriksizdir: hiçbir şey söylemez, bu yüzden hiçbir şeyle yanlışlanamaz.
 */
import { randomBytes } from 'node:crypto';

const ABC = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';   // Crockford base32

export function ulid(ms = Date.now()) {
  let zaman = '';
  let t = ms;
  for (let i = 0; i < 10; i++) { zaman = ABC[t % 32] + zaman; t = Math.floor(t / 32); }
  const r = randomBytes(16);
  let rastgele = '';
  for (let i = 0; i < 16; i++) rastgele += ABC[r[i] % 32];
  return zaman + rastgele;
}

export function yeniId(tur) { return `${tur}_${ulid()}`; }
