// tik-olc.mjs <sayfa url> <yol.json> [genişlik] [yükseklik] — tık bütçesini TARAYICIDA ölçer (Playwright). Elle sayı verilmez.
//
// NİÇİN (retro W42 BERİD Ö5 · D4 "elle verilen tık sayısı ölçüm değildir"): tik-kaydet.sh sayıyı elden alıyordu. Sohbet
//   (Messenger E1) kendi sayfasına özgü bir yürüyücü yazdı; bu, o kalıbın GENEL hâli: yollar tanım dosyasından gelir.
//
// yol.json: { "G1": { "hedef": 2, "adimlar": ["[aria-label=\"Mesajlar\"]", "text=Ayşe"] }, ... }
//   Her adım bir Playwright seçicisidir ve SIRAYLA GERÇEKTEN tıklanır (menü açılır, sonraki adım görünür olur).
// Sayım (her adım için):
//   1  · öğe var, görünür, ekranda ve tıklanabilir
//   +1 · ekran dışında (kaydırma gerekir)
//   +1 · görünmüyor ama DOM'da (üzerine gelme / gizli menü gerekir) — üzerine gelinir, sonra tıklanır
//   YÜRÜNEMEDİ · öğe yok ya da tıklanamıyor → ölçülen = max(9, hedef+1): bütçe HER ZAMAN aşılır (kapı kırmızı), sebebi stderr'de
//     (göz #394 tur 1: sabit 9, hedefi ≥ 9 olan görevde aşım üretmiyordu). Hedef 0-99.
// Her görev temiz sayfayla başlar (yeniden yükleme): bir görevin açtığı menü ötekinin sayısını küçültmez.
// Çıktı (SON satır): G1=<hedef>:<ölçülen> G2=…  ·  rc 0 ölçüldü · 2 tanım bozuk · 3 tarayıcı yok (ÖLÇÜLEMEDİ, sayı basılmaz)
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const [url, yolDosya, gen = '1280', yuk = '800'] = process.argv.slice(2);
if (!url || !yolDosya) { console.error('kullanım: tik-olc.mjs <sayfa url> <yol.json> [genişlik] [yükseklik]'); process.exit(2); }
let yol;
try { yol = JSON.parse(readFileSync(yolDosya, 'utf8')); } catch (e) { console.error('yol tanımı okunamadı: ' + e.message); process.exit(2); }
const adlar = Object.keys(yol);
for (const g of adlar) {
  const t = yol[g];
  if (!/^[A-Za-zÇĞİÖŞÜçğıöşü0-9_-]{1,20}$/.test(g) || !Number.isInteger(t?.hedef) || t.hedef < 0 || t.hedef > 99 || !Array.isArray(t?.adimlar) || !t.adimlar.length
      || t.adimlar.some(a => typeof a !== 'string' || !a.trim())) {
    console.error(`yol tanımı bozuk: ${g} — { "hedef": <0-99 tam sayı>, "adimlar": ["<seçici>", ...] } bekleniyor`); process.exit(2);
  }
}
if (!adlar.length) { console.error('yol tanımında görev yok'); process.exit(2); }
let chromium;
try {
  const require = createRequire(process.env.NODE_PATH ? process.env.NODE_PATH + '/' : import.meta.url);
  ({ chromium } = require('playwright'));
} catch (e) { console.error('ÖLÇÜLEMEDİ: playwright bulunamadı (KANIT_PLAYWRIGHT_DIR / NODE_PATH) — elle sayı yazılmaz'); process.exit(3); }
let tarayici;
try { tarayici = await chromium.launch(); }
catch (e) { console.error('ÖLÇÜLEMEDİ: tarayıcı başlatılamadı (' + String(e.message).split('\n')[0] + ')'); process.exit(3); }
const W = +gen, H = +yuk;
const sayfa = await tarayici.newPage({ viewport: { width: W, height: H } });
const sonuc = [];
for (const g of adlar) {
  await sayfa.goto(url, { waitUntil: 'load' });
  let tik = 0; const YURUNEMEDI = Math.max(9, yol[g].hedef + 1);
  for (const [i, secici] of yol[g].adimlar.entries()) {
    const ad = `${g} adım ${i + 1} (${secici})`;
    const oge = sayfa.locator(secici).first();
    if (!(await oge.count())) { console.error(`${ad}: öğe YOK — yol yürünemedi, ölçülen ${YURUNEMEDI}`); tik = YURUNEMEDI; break; }
    let ek = 0;
    if (!(await oge.isVisible())) {   // :hover menüsü üst öğeye bağlıdır — üst öğenin üzerine gelinir
      ek += 1; await oge.locator('xpath=..').hover({ timeout: 2000 }).catch(() => {});
    }
    const kutu = await oge.boundingBox();
    if (kutu && (kutu.y < 0 || kutu.y + kutu.height > H || kutu.x < 0 || kutu.x + kutu.width > W)) ek += 1;
    try { await oge.click({ timeout: 2000 }); }
    catch (e) { console.error(`${ad}: tıklanamıyor (${String(e.message).split('\n')[0]}) — ölçülen ${YURUNEMEDI}`); tik = YURUNEMEDI; break; }
    tik += 1 + ek;
  }
  sonuc.push(`${g}=${yol[g].hedef}:${Math.min(tik, 999)}`);
}
await tarayici.close();
console.log(sonuc.join(' '));
