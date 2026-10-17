// kilit.mjs — süreçler arası kayıt kilidi (Parça B7). Kapı ve günlük bekçi turu AYNI kayda yazar; ikisi de bu kilidi alır.
// Sınav: kilit.test.mjs (DV32a–d).
import fs from 'node:fs';
import path from 'node:path';
import { KadroHata } from './kadro-yaz.mjs';

// Süreçler arası kayıt kilidi (Parça B7): kapı (süreç içi kuyruk) ile günlük bekçi turu AYNI kayda yazar → ikisi de bu kilidi alır.
// O_EXCL dosyası; içinde "<pid> <jeton>". 🔴 Sahiplik (bağımsız göz tur 1 ve 2):
//   · Kilit yalnız SAHİBİ ÖLMÜŞSE bayattır (pid yaşıyorsa ne kadar eski olursa olsun beklenir — kapı açıcıyı 120 sn bekleyebilir;
//     yaşa bakan eski kural tam o anda kilidi bekçiye kaptırıyordu). İçeriği okunamayan (yazılırken ölmüş) kilit için yaş eşiği.
//   · Bayat kilidi yalnız DEVRAL kilidini (kadro.kilit.devral, O_EXCL) tutan süreç siler; silmeden önce içeriğin hâlâ aynı bayat
//     olduğuna bakar. Kilit dosyası silinene kadar kimse yeni kilit yazamaz → doğrulama ile silme arasında taze kilit kaybolmaz.
//     (Tur 1'deki yarış: taşı-ve-geri-koy deseni, araya giren taze kilidi yerinden alıp geri koyamıyordu.)
//     Devral kilidi 5 sn'den eskiyse tutucusu ölmüş sayılır ve kaldırılır (tutulma mikrosaniye sürer).
//   · Bırakma yalnız içerik hâlâ kendi jetonuysa siler.
// 30 sn'de alınamazsa KadroHata 503 (hiçbir şey yazılmaz).
const yasiyor = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
const DEVRAL_BAYAT_MS = 5000;
export async function dosyaKilit(dizin, { bekleMs = 30000, bayatMs = 600000 } = {}) {
  const y = path.join(dizin, 'kadro.kilit'), d = y + '.devral'; const bas = Date.now();
  const ben = process.pid + ' ' + Math.random().toString(36).slice(2) + Date.now().toString(36);
  const oku = (f) => { try { return fs.readFileSync(f, 'utf8'); } catch { return null; } };
  const ac = (f) => { try { const fd = fs.openSync(f, 'wx'); fs.writeSync(fd, ben); fs.closeSync(fd); return true; } catch (e) { if (e.code !== 'EEXIST') throw e; return false; } };
  for (;;) {
    if (ac(y)) return () => { if (oku(y) === ben) { try { fs.unlinkSync(y); } catch {} } };
    const c = oku(y);
    if (c !== null) {
      const pid = +String(c).split(' ')[0];
      let yas = 0; try { yas = Date.now() - fs.statSync(y).mtimeMs; } catch { continue; }
      const bayat = Number.isInteger(pid) && pid > 0 ? !yasiyor(pid) : yas > bayatMs;
      if (bayat) {
        // Sınav dikişi: bayatı görmekle devralmak arasındaki pencereyi genişletir (yarış sınavı DV32c belirli olsun; gerçekte 0)
        if (+process.env.KADRO_KILIT_SINAV_GECIKME > 0) await new Promise((r) => setTimeout(r, +process.env.KADRO_KILIT_SINAV_GECIKME));
        if (ac(d)) {
          if (oku(y) === c) { try { fs.unlinkSync(y); } catch {} }   // hâlâ aynı bayat → sil; başkası taze kilit koymuşsa dokunma
          try { fs.unlinkSync(d); } catch {}
          continue;
        }
        try { if (Date.now() - fs.statSync(d).mtimeMs > DEVRAL_BAYAT_MS) fs.unlinkSync(d); } catch {}
      }
    }
    if (Date.now() - bas > bekleMs) throw new KadroHata(503, 'Kayıt başka bir işlemce kilitli — biraz sonra yeniden dene.');
    await new Promise((r) => setTimeout(r, 100));
  }
}
