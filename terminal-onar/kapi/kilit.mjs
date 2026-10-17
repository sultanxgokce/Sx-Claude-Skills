// kilit.mjs — süreçler arası kayıt kilidi (Parça B7). Kapı ve günlük bekçi turu AYNI kayda yazar; ikisi de bu kilidi alır.
// Sınav: kilit.test.mjs (DV32a–f). Kullanan: kadro-yaz.mjs (kadroYaz tüm okuma-yazma boyunca tutar).
import fs from 'node:fs';
import path from 'node:path';
import { KadroHata } from './kadro-yaz.mjs';

// Süreçler arası kayıt kilidi (Parça B7): kapı (süreç içi kuyruk) ile günlük bekçi turu AYNI kayda yazar → ikisi de bu kilidi alır.
// O_EXCL dosyası; içinde "<pid> <jeton>". Senkron (kadroYaz senkron çağrılır; uyku Atomics.wait ile).
// 🔴 Sahiplik (bağımsız göz tur 1, 2 ve 3):
//   · Kilit yalnız SAHİBİ ÖLMÜŞSE bayattır (pid yaşıyorsa ne kadar eski olursa olsun beklenir — kapı açıcıyı 120 sn bekleyebilir;
//     yaşa bakan eski kural tam o anda kilidi bekçiye kaptırıyordu). İçeriği okunamayan (yazılırken ölmüş) kilit için yaş eşiği.
//   · Bayat kilidi yalnız DEVRAL kilidini (kadro.kilit.devral, O_EXCL) tutan süreç siler; silmeden önce içeriğin hâlâ aynı bayat
//     olduğuna bakar. Kilit dosyası silinene kadar kimse yeni kilit yazamaz → doğrulama ile silme arasında taze kilit kaybolmaz.
//     (Tur 1'deki yarış: taşı-ve-geri-koy deseni, araya giren taze kilidi yerinden alıp geri koyamıyordu.)
//   · Devral kilidi yalnız İÇERİĞİ hâlâ kendi jetonuysa silinir (tur 2). 5 sn'den eski devral tutucusu ölmüş sayılır ve yalnız
//     okunan içerik hâlâ aynıysa kaldırılır (tutulma mikrosaniye sürer; okuma-silme arası kalan pencere pratikte kapalı).
//   · Bırakma yalnız içerik hâlâ kendi jetonuysa siler.
// 30 sn'de alınamazsa KadroHata 503 (hiçbir şey yazılmaz).
const yasiyor = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
const uyu = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const DEVRAL_BAYAT_MS = 5000;
export function dosyaKilit(dizin, { bekleMs = 30000, bayatMs = 600000 } = {}) {
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
        if (+process.env.KADRO_KILIT_SINAV_GECIKME > 0) uyu(+process.env.KADRO_KILIT_SINAV_GECIKME);
        if (ac(d)) {
          if (oku(y) === c) { try { fs.unlinkSync(y); } catch {} }   // hâlâ aynı bayat → sil; başkası taze kilit koymuşsa dokunma
          if (oku(d) === ben) { try { fs.unlinkSync(d); } catch {} }  // yalnız kendi devralımızı bırak
          continue;
        }
        try {
          const dc = oku(d);
          if (Date.now() - fs.statSync(d).mtimeMs > DEVRAL_BAYAT_MS && oku(d) === dc) fs.unlinkSync(d);
        } catch {}
      }
    }
    if (Date.now() - bas > bekleMs) throw new KadroHata(503, 'Kayıt başka bir işlemce kilitli — biraz sonra yeniden dene.');
    uyu(100);
  }
}
