// koltuk-onbellek sınavı — sahte saat + sayaçlı üretici. Çıktı: "N geçti · M kaldı".
import assert from 'node:assert/strict';
import { onbellekKur } from './koltuk-onbellek.mjs';
let gecti = 0; const kalan = [];
const t = async (ad, fn) => { try { await fn(); gecti++; } catch (e) { kalan.push(`${ad}: ${e.message.split('\n')[0]}`); } };
const kur = (o = {}) => { let saat = 1000, n = 0, sonuc = () => ({ ok: true, n }), bekle = null;
  const c = onbellekKur(async () => { n++; const v = sonuc(); if (bekle) await bekle; return v; }, { taze: 100, bayat: 1000, saat: () => saat, ...o });
  return { c, ileri: (d) => { saat += d; }, sayi: () => n, sonuc: (f) => { sonuc = f; }, tut: (p) => { bekle = p; } }; };
const tur = () => new Promise((r) => setImmediate(r));

await t('O1 taze pencerede üretici ikinci kez koşmaz', async () => { const o = kur(); await o.c.al(); o.ileri(50); const r = await o.c.al(); assert.equal(o.sayi(), 1); assert.equal(r.deger.n, 1); });
await t('O2 bayat pencerede eski cevap hemen döner, arkada tek yenileme koşar, sonraki istek yeniyi alır', async () => {
  const o = kur(); await o.c.al(); o.ileri(200); const r = await o.c.al(); assert.equal(r.deger.n, 1); assert.equal(r.yas, 200); await tur(); await tur(); assert.equal(o.sayi(), 2); assert.equal((await o.c.al()).deger.n, 2); });
await t('O3 bayat pencere dolunca istek taze sonucu bekler', async () => { const o = kur(); await o.c.al(); o.ileri(1500); const r = await o.c.al(); assert.equal(r.deger.n, 2); });
await t('O4 eşzamanlı ilk istekler tek koşuya iner', async () => { const o = kur(); const [a, b, c] = await Promise.all([o.c.al(), o.c.al(), o.c.al()]); assert.equal(o.sayi(), 1); assert.deepEqual([a.deger.n, b.deger.n, c.deger.n], [1, 1, 1]); });
await t('O5 başarısız üretim saklanmaz: sonraki istek yeniden dener', async () => { const o = kur(); o.sonuc(() => ({ ok: false })); assert.equal((await o.c.al()).deger.ok, false); o.sonuc(() => ({ ok: true })); assert.equal((await o.c.al()).deger.ok, true); assert.equal(o.sayi(), 2); });
await t('O6 bayat hatayı süresiz gizlemez: yenileme hep düşerse pencere dolunca hata görünür', async () => { const o = kur(); await o.c.al(); o.sonuc(() => ({ ok: false })); o.ileri(200); await o.c.al(); await tur(); await tur(); o.ileri(1000); assert.equal((await o.c.al()).deger.ok, false); });
await t('O7 dusur eldekini atar, sonraki istek yeniden üretir', async () => { const o = kur(); await o.c.al(); o.c.dusur(); await o.c.al(); assert.equal(o.sayi(), 2); });
await t('O8 dusur sırasında yoldaki eski koşu önbelleğe yazılmaz', async () => {
  const o = kur(); let bitir; o.tut(new Promise((r) => { bitir = r; })); const y = o.c.al(); await tur(); o.c.dusur(); o.tut(null); bitir(); await y; await tur(); await o.c.al(); assert.equal(o.sayi(), 2); });
console.log(`${gecti} geçti · ${kalan.length} kaldı`); kalan.forEach((k) => console.log('  ✗ ' + k)); process.exit(kalan.length ? 1 : 0);
