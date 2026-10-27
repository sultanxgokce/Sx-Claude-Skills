// kapi/oda.mjs — koltuğun ODASI (kutu–oda modeli 2 · görev …1ASZ · SERDAR kararı A, 27 Eki).
// Tek gerçek koltuğun ÇALIŞMA DİZİNİDİR: dizinden yukarı çıkılır, ilk oda.json odayı verir (oda-kur becerisinin düzeni:
// <depo>/<oda>/oda.json = ad · reis · hedef · olcu). Ekip kaydındaki 'oda:' alanı yalnız TUTARLILIK denetimidir — ayrışırsa
// koltukta uyarı döner, oda klasörden gelir. Klasörde oda yoksa koltuk odasızdır (kayıttaki alan oda UYDURMAZ).
import fs from 'node:fs';
import path from 'node:path';

export const ODA_AD_DESEN = /^[a-z0-9][a-z0-9-]{0,29}[a-z0-9]$/;   // ekip kaydıyla aynı kural: kebab, 2-31 karakter
const DERINLIK = 40;

/** dizin → { ad, hedef, reis } · oda.json yoksa null · oda.json var ama okunamıyor/geçersizse { bozuk: true } (sessizce odasız sayılmaz). */
export function odaBul(dizin) {
  if (typeof dizin !== 'string' || !path.isAbsolute(dizin)) return null;
  let d = path.resolve(dizin);
  for (let i = 0; i < DERINLIK; i++) {
    const f = path.join(d, 'oda.json');
    let st = null; try { st = fs.statSync(f); } catch {}
    if (st && st.isFile()) {
      try {
        const m = JSON.parse(fs.readFileSync(f, 'utf8'));
        if (!m || typeof m.ad !== 'string' || !ODA_AD_DESEN.test(m.ad)) return { bozuk: true };
        return { ad: m.ad, hedef: typeof m.hedef === 'string' ? m.hedef.slice(0, 200) : '', reis: typeof m.reis === 'string' ? m.reis.slice(0, 60) : '' };
      } catch { return { bozuk: true }; }
    }
    const ust = path.dirname(d);
    if (ust === d) break;
    d = ust;
  }
  return null;
}

/** Klasördeki oda ile ekip kaydındaki oda ayrışıyorsa Sultan-dilinde tek cümle; değilse ''. Kayıtta alan yoksa denetim yok. */
export function odaUyarisi(bulunan, kayitOda) {
  if (bulunan && bulunan.bozuk) return 'Çalışma klasöründeki oda.json okunamadı; koltuk odasız gösteriliyor.';
  if (!kayitOda) return '';
  const klasor = bulunan && bulunan.ad ? bulunan.ad : '';
  if (klasor === kayitOda) return '';
  return klasor
    ? `Ekip kaydında oda '${kayitOda}', çalışma klasöründe '${klasor}'. Geçerli olan klasör.`
    : `Ekip kaydında oda '${kayitOda}', ama koltuk bir oda klasöründe açılmamış.`;
}
