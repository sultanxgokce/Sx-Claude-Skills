// ÜRETİM FAZ A · puanlama — adayı motorun KENDİ yargı katmanıyla sınar, sonra sıralar.
// Kapı iki aşamalıdır ve GEVŞETİLEMEZ: (1) dogrula → geometrik taban, (2) denetleKos → mimari
// kural. İkisinden biri kırmızıysa aday ELENİR; skor yalnız geçenler arasında sıralama yapar.
// "Skoru yüksek ama ihlalli" diye bir aday YOKTUR — sınavı geçmek sıralamanın ön-şartıdır.
import { dogrula } from './model.mjs';
import { denetleKos } from './denetle.mjs';
import { alanM2 } from './geometri.mjs';

// Ağırlıklar üretim tercihidir (kural DEĞİL) — hiçbiri bir eşiği gevşetmez, yalnız geçenleri sıralar.
const AGIRLIK = { alan: 3, bicim: 1, komsuluk: 2, uyari: 0.25 };

function komsuMu(p, q) {
  const xOrt = Math.min(p.x1, q.x1) - Math.max(p.x0, q.x0);
  const yOrt = Math.min(p.y1, q.y1) - Math.max(p.y0, q.y0);
  const dikeyTemas = (p.x1 === q.x0 || q.x1 === p.x0) && yOrt > 0;
  const yatayTemas = (p.y1 === q.y0 || q.y1 === p.y0) && xOrt > 0;
  return dikeyTemas || yatayTemas;
}

export function puanla(aday, norm, ks) {
  const { model, parcalar } = aday;
  const { hatalar, uyarilar: dUyari } = dogrula(model);
  if (hatalar.length) return { gecerli: false, sebep: 'dogrula', ayrinti: hatalar };
  const { ihlaller, uyarilar, bilgiler } = denetleKos(model, ks);
  if (ihlaller.length) return { gecerli: false, sebep: 'denetle', ayrinti: ihlaller };

  const idx = new Map(parcalar.map((p) => [p.oda.id, p]));
  let alanSapma = 0, bicim = 0;
  for (const p of parcalar) {
    const m2 = alanM2([[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]);
    alanSapma += Math.abs(m2 - p.oda.hedef_m2) / p.oda.hedef_m2;
    bicim += Math.max(p.x1 - p.x0, p.y1 - p.y0) / Math.min(p.x1 - p.x0, p.y1 - p.y0) - 1;
  }
  const n = parcalar.length;
  alanSapma /= n; bicim /= n;

  const istenen = norm.komsuluk ?? [];
  const karsilanmayan = istenen.filter(([a, b]) => {
    const p = idx.get(a), q = idx.get(b);
    return !(p && q && komsuMu(p, q));
  });
  const komsulukEksik = istenen.length ? karsilanmayan.length / istenen.length : 0;

  const skor = AGIRLIK.alan * alanSapma + AGIRLIK.bicim * bicim + AGIRLIK.komsuluk * komsulukEksik
    + AGIRLIK.uyari * (uyarilar.length + dUyari.length);

  return {
    gecerli: true,
    skor: +skor.toFixed(4),
    detay: {
      alan_sapma_ort: +alanSapma.toFixed(4),
      bicim_orani_ort: +bicim.toFixed(4),
      komsuluk_karsilanan: `${istenen.length - karsilanmayan.length}/${istenen.length}`,
      komsuluk_karsilanmayan: karsilanmayan,
      denetim_uyari: uyarilar.length,
      dogrula_uyari: dUyari.length,
      denetim_bilgi: bilgiler.length,
    },
    uyarilar: [...dUyari, ...uyarilar],
  };
}
