// KARIŞIK KATMAN TEŞHİSİ — bir katman hem duvar çizgisi hem tefriş/sembol konturu taşıyorsa.
//
// 🔴 NİÇİN VAR (iki gerçek müşteri dosyasında ölçüldü, 2026-09-24): bu büronun çizimlerinde `0`
// katmanı karışıktır. Siirt: 232 poligonun 155'i kapalı ilmek (hepsi 2,1 m²'den küçük — tefriş),
// 77'si açık çizgi. Kozluk: 310'un 167'si kapalı, 143'ü açık (34'ü 3 m'den uzun). Katmana `duvar`
// dersen raflar duvar olur (kalınlık sapması), `yok-say` dersen iç bölmeler kaybolur (çeper/oda
// kaçağı). Yani KATMAN-BAŞINA rol bu sınıfta yapısal olarak yetersizdir; ayrım VARLIK düzeyinde.
//
// AYRIM TOPOLOJİKTİR, SAYISAL DEĞİL (MEDDAH şartı 2, K01): kapalı ilmek → tefriş/sembol,
// açık çizgi → duvar adayı. Yukarıdaki "2,1 m²" ve "3 m" KURAL DEĞİL, yalnız raporlanan ölçümdür;
// iki dosya eşik ilan etmeye yetmez.
//
// KOLON RİSKİ (MEDDAH şartı 3): kapalı bir ilmek duvar çizgisine İKİ kenarıyla oturuyorsa kolon
// ya da şaft olabilir → tefriş sayılmaz, SORU sınıfına düşer ve sınırda KALIR. Sessizce silmek,
// yanlış yere duvar koymaktan daha tehlikelidir: kaybolan kolon görünmez bir hatadır.

const EPS_KAYNAK = 'lifting ızgara hücresi (2,0 cm) — kuantizasyon payı, mimari kural DEĞİL';

function kenarlar(e) {
  const k = e.koseler ?? [];
  const son = e.kapali ? k.length : k.length - 1;
  const out = [];
  for (let i = 0; i < son; i++) out.push([[k[i].x, k[i].y], [k[(i + 1) % k.length].x, k[(i + 1) % k.length].y]]);
  return out;
}

const uzunluk = ([a, b]) => Math.hypot(b[0] - a[0], b[1] - a[1]);

// İki kenar "üst üste oturuyor" mu: paralel, aralarındaki dik mesafe ≤ eps ve eksende örtüşüyor.
function oturuyor(k1, k2, eps) {
  const [a, b] = k1, [c, d] = k2;
  const L1 = uzunluk(k1), L2 = uzunluk(k2);
  if (L1 < eps || L2 < eps) return false;
  const ux = (b[0] - a[0]) / L1, uy = (b[1] - a[1]) / L1;
  const vx = (d[0] - c[0]) / L2, vy = (d[1] - c[1]) / L2;
  if (Math.abs(ux * vy - uy * vx) > 0.09) return false;            // ≈5° paralellik payı
  const dik = (p) => Math.abs((p[0] - a[0]) * uy - (p[1] - a[1]) * ux);
  if (dik(c) > eps || dik(d) > eps) return false;
  const eksen = (p) => (p[0] - a[0]) * ux + (p[1] - a[1]) * uy;
  const t = [eksen(c), eksen(d)].sort((x, y) => x - y);
  return Math.min(L1, t[1]) - Math.max(0, t[0]) > eps;             // örtüşme bir hücreden fazla
}

/**
 * @returns {{sinifi: Map<object,string>, ozet: object, kayit: object[]}}
 */
export function karisikTeshis(entities, roller) {
  const eps = Number(roller.karisik_bitisiklik_cm ?? 2.0);
  const karisikKat = Object.entries(roller.roller).filter(([, r]) => r === 'karisik').map(([k]) => k);
  const sinifi = new Map();
  const kayit = [];
  const ozet = { karisik_katman: karisikKat, duvar_adayi: 0, tefris: 0, soru_kolon_olabilir: 0 };
  if (!karisikKat.length) return { sinifi, ozet, kayit, eps };

  const karisikPoly = entities.filter((e) => e.tur === 'poly' && karisikKat.includes(e.katman) && (e.koseler ?? []).length >= 2);
  // Duvar referansı: `duvar`/`kolon` rollü katmanların kenarları + karışık katmanın AÇIK çizgileri
  const duvarRol = Object.entries(roller.roller).filter(([, r]) => r === 'duvar' || r === 'kolon').map(([k]) => k);
  const referans = [];
  for (const e of entities) {
    if (e.tur !== 'poly') continue;
    if (duvarRol.includes(e.katman)) referans.push(...kenarlar(e));
    else if (karisikKat.includes(e.katman) && !e.kapali) referans.push(...kenarlar(e));
  }

  for (const e of karisikPoly) {
    if (!e.kapali) {
      sinifi.set(e, 'duvar_adayi'); ozet.duvar_adayi++;
      continue;
    }
    const ks = kenarlar(e);
    let oturan = 0;
    for (const k of ks) { if (referans.some((r) => oturuyor(k, r, eps))) oturan++; if (oturan >= 2) break; }
    if (oturan >= 2) {
      sinifi.set(e, 'soru_kolon_olabilir'); ozet.soru_kolon_olabilir++;
      kayit.push({ katman: e.katman, sinif: 'soru_kolon_olabilir', kenar: ks.length, duvara_oturan_kenar: oturan,
        gerekce: 'kapalı ilmek duvar çizgisine iki kenarıyla oturuyor — kolon/şaft olabilir, tefriş sayılmadı; SINIRDA KALDI, kullanıcıya sorulmalı' });
    } else {
      sinifi.set(e, 'tefris'); ozet.tefris++;
      kayit.push({ katman: e.katman, sinif: 'tefris', kenar: ks.length, duvara_oturan_kenar: oturan,
        gerekce: 'kapalı ilmek, duvara oturmuyor — tefriş/sembol konturu, sınıra alınmadı' });
    }
  }
  ozet.bitisiklik_cm = eps;
  ozet.bitisiklik_kaynak = EPS_KAYNAK;
  return { sinifi, ozet, kayit, eps };
}
