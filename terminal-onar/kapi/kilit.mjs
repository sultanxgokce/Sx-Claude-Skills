// kilit.mjs — süreçler arası kayıt kilidi (Parça B7). Kapı ve günlük bekçi turu AYNI kayda yazar; ikisi de bu kilidi alır.
// Sınav: kilit.test.mjs (DV32a–d).
import fs from 'node:fs';
import path from 'node:path';
import { KadroHata } from './kadro-yaz.mjs';

// Süreçler arası kayıt kilidi (Parça B7): kapı (süreç içi kuyruk) ile günlük bekçi turu AYNI kayda yazar → ikisi de bu kilidi alır.
// O_EXCL dosyası; içinde "<pid> <jeton>". 🔴 Sahiplik (bağımsız göz tur 1):
//   · Kilit yalnız SAHİBİ ÖLMÜŞSE bayattır (pid yaşıyorsa ne kadar eski olursa olsun beklenir — kapı açıcıyı 120 sn bekleyebilir;
//     yaşa bakan eski kural tam o anda kilidi bekçiye kaptırıyordu). İçeriği okunamayan (yazılırken ölmüş) kilit için yaş eşiği.
//   · Bayat kilit doğrudan SİLİNMEZ: önce eşsiz ada taşınır, taşınanın içeriği bayat sanılanla aynı mı bakılır. Aynı değilse (araya
//     başkası taze kilit koymuş) geri konur (link: yalnız yer boşsa) — iki süreç aynı bayatı görse de biri ötekinin kilidini silemez.
//   · Bırakma yalnız içerik hâlâ kendi jetonuysa siler.
// 30 sn'de alınamazsa KadroHata 503 (hiçbir şey yazılmaz).
const yasiyor = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
export async function dosyaKilit(dizin, { bekleMs = 30000, bayatMs = 600000 } = {}) {
  const y = path.join(dizin, 'kadro.kilit'); const bas = Date.now();
  const ben = process.pid + ' ' + Math.random().toString(36).slice(2) + Date.now().toString(36);
  const oku = (f) => { try { return fs.readFileSync(f, 'utf8'); } catch { return null; } };
  for (;;) {
    try { const fd = fs.openSync(y, 'wx'); fs.writeSync(fd, ben); fs.closeSync(fd); return () => { if (oku(y) === ben) { try { fs.unlinkSync(y); } catch {} } }; }
    catch (e) { if (e.code !== 'EEXIST') throw e; }
    const c = oku(y);
    if (c !== null) {
      const pid = +String(c).split(' ')[0];
      let yas = 0; try { yas = Date.now() - fs.statSync(y).mtimeMs; } catch { continue; }
      const bayat = Number.isInteger(pid) && pid > 0 ? !yasiyor(pid) : yas > bayatMs;
      if (bayat) {
        // Sınav dikişi: bayatı görmekle devralmak arasındaki pencereyi genişletir (yarış sınavı DV32c belirli olsun; gerçekte 0)
        if (+process.env.KADRO_KILIT_SINAV_GECIKME > 0) await new Promise((r) => setTimeout(r, +process.env.KADRO_KILIT_SINAV_GECIKME));
        const t = y + '.bayat.' + process.pid + '.' + Math.random().toString(36).slice(2);
        try { fs.renameSync(y, t); } catch { continue; }
        if (oku(t) !== c) { try { fs.linkSync(t, y); } catch {} }   // başkasının taze kilidini kaptık → yer boşsa geri koy
        try { fs.unlinkSync(t); } catch {}
        continue;
      }
    }
    if (Date.now() - bas > bekleMs) throw new KadroHata(503, 'Kayıt başka bir işlemce kilitli — biraz sonra yeniden dene.');
    await new Promise((r) => setTimeout(r, 100));
  }
}
