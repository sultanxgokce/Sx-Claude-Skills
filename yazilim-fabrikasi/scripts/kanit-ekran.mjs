// kanit-ekran.mjs — başsız Chromium ile kare çeker. kanit.py çağırır; NODE_PATH playwright'ın olduğu node_modules'a bakar.
// argv: url out [urunImi] [bekle] [genislik]
// rc: 0 kare alındı · 2 ürün imi YOK (açılan sayfa ürün değil — 6. kanun) · 3 alınamadı
import { createRequire } from "node:module";
const require = createRequire(process.env.NODE_PATH ? process.env.NODE_PATH + "/" : import.meta.url);
const [url, out, urunImi = "", bekle = "", genislik = "1280"] = process.argv.slice(2);
let pw;
try { pw = require("playwright"); } catch (e) { console.error("playwright yüklenemedi: " + e.message); process.exit(3); }
const browser = await pw.chromium.launch({ headless: true, args: ["--no-sandbox"] }).catch(e => { console.error("chromium açılamadı: " + e.message); process.exit(3); });
try {
  const page = await browser.newPage({ viewport: { width: Number(genislik) || 1280, height: 800 } });
  const r = await page.goto(url, { waitUntil: "networkidle", timeout: 20000 }).catch(e => { throw new Error("sayfa açılamadı: " + e.message); });
  if (r && r.status() >= 400) { console.error(`HTTP ${r.status()} — sayfa ürün değil`); process.exit(2); }
  if (bekle) await page.waitForSelector(bekle, { timeout: 10000 }).catch(() => { throw new Error("beklenen öğe gelmedi: " + bekle); });
  if (urunImi) {
    const n = await page.locator(urunImi).count();
    if (n === 0) { console.error(`ürün imi bulunamadı: ${urunImi} (başlık: ${await page.title()})`); process.exit(2); }
  }
  await page.screenshot({ path: out, fullPage: true });
  console.log(`kare: ${out} · başlık: ${await page.title()}`);
} catch (e) {
  console.error(e.message); process.exit(3);
} finally {
  await browser.close();
}
