// kapi/oda.mjs — koltuğun ODASI (kutu–oda modeli 2 · görev …1ASZ · SERDAR kararı A, 31 Eki değişikliği: "Kayıt yalnız denetler kararımı bu cümleyle değiştiriyorum.").
// SIRA: (1) koltuğun çalışma dizininden yukarı çıkılır, ilk oda.json odayı verir (oda-kur düzeni: <depo>/<oda>/oda.json = ad · reis · hedef · olcu);
//       (2) oda.json yoksa ya da okunamıyorsa ekip kaydındaki 'oda:' alanı; (3) ikisi de yoksa oda dışı (alan yazılmaz, oda uydurulmaz).
// Ölçüm (31 Eki): filoda oda.json 3 dizinde, kod kutusunda 26 üyenin odası kayıtta — kayıt basamağı olmadan oda listesi boş dönerdi.
// Koltukta oda_kaynak hangi basamağın verdiğini söyler. Klasör ile kayıt ayrışırsa geçerli olan klasördür ve uyarı döner.
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

/** Kayıt adını koltuk adına indirger: Türkçe küçük harf, işaretsiz (MÜZEHHİP → muzehhip · ŞAKİRD → sakird). */
export function adKatla(ad) {
  return String(ad ?? '').toLocaleLowerCase('tr').normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ı/g, 'i');
}

/** Ekip üyeleri → koltuk adı ⟶ oda. Anahtar tmux oturumu; tmux alanı olmayan üyede katlanmış kimlik. Geçersiz oda adı alınmaz. */
export function kayitOdaHaritasi(uyeler, acik = []) {
  const h = new Map(), koltuk = koltukEsle(uyeler, acik);
  for (const u of uyeler || []) {
    if (!u || !ODA_AD_DESEN.test(String(u.oda ?? ''))) continue;
    h.set(koltuk.get(u) || adKatla(u.id), String(u.oda));
  }
  return h;
}

/**
 * Üye → koltuk adı. Kayıttaki tmux adı canlıda yoksa üye görünen adıyla, sonra kimliğiyle açık koltuğa bağlanır
 * (NAZIR: kayıtta nazir-rasatci, canlıda rasatci). Önce tmux adı tutanlar yerleşir; açık koltuğu kayıtlı sahibinden
 * başkası alamaz. Hiçbiri tutmazsa kayıttaki ad kalır: kapalı koltuğa açık koltuk uydurulmaz.
 */
const PASIF_UYE = new Set(['emekli', 'arsiv', 'dondurulmus']);
export function koltukEsle(uyeler, acik = []) {
  const h = new Map(), liste = (uyeler || []).filter((u) => u && !PASIF_UYE.has(u.durum) && !PASIF_UYE.has(u.hal)), acikKatli = new Map(acik.map((a) => [adKatla(a), a])), dolu = new Set();
  const kayitli = (u) => String(u.tmux ?? '').split(':')[0];
  for (const u of liste) { const a = acikKatli.get(adKatla(kayitli(u))); if (kayitli(u) && a) { h.set(u, a); dolu.add(a); } }
  for (const u of liste) {
    if (h.has(u)) continue;
    const a = [u.ad, u.id].map((x) => acikKatli.get(adKatla(x))).find((x) => x && !dolu.has(x));
    if (a) { h.set(u, a); dolu.add(a); } else h.set(u, kayitli(u));
  }
  return h;
}

/** Koltuğun kayıttaki odası: önce birebir ad, sonra katlanmış ad. */
export function kayitOdaBul(harita, koltuk) {
  return harita.get(koltuk) || harita.get(adKatla(koltuk)) || '';
}

/** Kararın sırası: klasör → kayıt → yok. → { oda, kaynak } ya da null. */
export function odaSec(bulunan, kayitOda) {
  if (bulunan && bulunan.ad) return { oda: bulunan.ad, kaynak: 'klasor' };
  return kayitOda ? { oda: kayitOda, kaynak: 'kayit' } : null;
}

/** Sultan-dilinde tek cümle ya da ''. Kayıttan gelen oda olağan durumdur, uyarı değildir; uyarı yalnız ayrışma ve bozuk oda.json içindir. */
export function odaUyarisi(bulunan, kayitOda) {
  if (bulunan && bulunan.bozuk) return kayitOda ? `Çalışma klasöründeki oda.json okunamadı; kayıttaki oda '${kayitOda}' gösteriliyor.` : 'Çalışma klasöründeki oda.json okunamadı; koltuk odasız gösteriliyor.';
  if (!kayitOda || !bulunan || !bulunan.ad || bulunan.ad === kayitOda) return '';
  return `Ekip kaydında oda '${kayitOda}', çalışma klasöründe '${bulunan.ad}'. Geçerli olan klasör.`;
}
