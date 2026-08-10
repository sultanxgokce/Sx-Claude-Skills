// Parametrik mobilya sembolleri — elle yazılmış SVG path'leri, dış varlık/lisans YOK.
// Her sembol yerel koordinatta çizilir: (0,0) sol-üst, genişlik g, derinlik d.
// Yerleştirici yön'ü (0=+x,1=+y,2=-x,3=-y) transform ile uygular.

const f = (n) => +n.toFixed(2);

// Her sembol: (g, d, renkler) → SVG parça dizisi
const SEMBOLLER = {
  yatak(g, d, r) {
    const yastikD = Math.min(d * 0.18, 32);
    const yorganY = yastikD + 4;
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="3" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      // yorgan
      `<rect x="2" y="${f(yorganY)}" width="${f(g - 4)}" height="${f(d - yorganY - 2)}" rx="4" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
      // yorgan kıvrımı
      `<line x1="2" y1="${f(yorganY + 22)}" x2="${f(g - 2)}" y2="${f(yorganY + 22)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.6)}" opacity="0.6"/>`,
      // yastıklar
      ...(g > 120
        ? [
            `<rect x="${f(g * 0.08)}" y="4" width="${f(g * 0.36)}" height="${f(yastikD)}" rx="6" fill="${r.vurgu}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
            `<rect x="${f(g * 0.56)}" y="4" width="${f(g * 0.36)}" height="${f(yastikD)}" rx="6" fill="${r.vurgu}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
          ]
        : [`<rect x="${f(g * 0.15)}" y="4" width="${f(g * 0.7)}" height="${f(yastikD)}" rx="6" fill="${r.vurgu}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`]),
    ];
  },

  komodin(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="2" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<line x1="${f(g * 0.25)}" y1="${f(d * 0.65)}" x2="${f(g * 0.75)}" y2="${f(d * 0.65)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`,
    ];
  },

  dolap(g, d, r) {
    const parcalar = [`<rect x="0" y="0" width="${f(g)}" height="${f(d)}" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`];
    const kapak = Math.max(1, Math.round(g / 55));
    for (let i = 1; i < kapak; i++) {
      parcalar.push(`<line x1="${f((g / kapak) * i)}" y1="0" x2="${f((g / kapak) * i)}" y2="${f(d)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.6)}"/>`);
    }
    // askı çubuğu izi
    parcalar.push(`<line x1="3" y1="${f(d * 0.5)}" x2="${f(g - 3)}" y2="${f(d * 0.5)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.5)}" stroke-dasharray="6 5" opacity="0.7"/>`);
    return parcalar;
  },

  kanepe(g, d, r) {
    const kol = Math.min(g * 0.12, 24);
    const sirt = Math.min(d * 0.28, 26);
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="8" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<rect x="${f(kol)}" y="${f(sirt)}" width="${f(g - kol * 2)}" height="${f(d - sirt - 3)}" rx="5" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
      `<line x1="${f(g / 2)}" y1="${f(sirt)}" x2="${f(g / 2)}" y2="${f(d - 3)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.6)}" opacity="0.7"/>`,
    ];
  },

  koltuk(g, d, r) {
    const sirt = Math.min(d * 0.3, 22);
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="10" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<rect x="${f(g * 0.15)}" y="${f(sirt)}" width="${f(g * 0.7)}" height="${f(d - sirt - 4)}" rx="6" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
    ];
  },

  sehpa(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="6" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<rect x="${f(g * 0.12)}" y="${f(d * 0.15)}" width="${f(g * 0.76)}" height="${f(d * 0.7)}" rx="4" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.5)}" opacity="0.6"/>`,
    ];
  },

  // ⚠ DEĞİŞMEZ: sembol, mobilyanın BEYAN EDİLEN kutusunun dışına çizim yapamaz.
  // Sandalyeler bir zamanlar kutunun dışına çiziliyordu → çakışma denetimine girmeyen,
  // modelin rezerve etmediği alanı işgal eden çizim demekti (çizim modelden fazlasını iddia edemez).
  masa(g, d, r) {
    const parcalar = [];
    const sandalyeD = Math.min(30, d * 0.26);
    const tablaY = sandalyeD + 3;
    const tablaD = d - (sandalyeD + 3) * 2;
    // sandalyeler — kutunun İÇİNDE, uzun kenarlara
    if (g >= 110 && tablaD > 25) {
      const sandalye = Math.min(42, g * 0.22), bosluk = 12;
      const adet = Math.max(1, Math.floor((g + bosluk) / (sandalye + bosluk)));
      const baslangic = (g - (adet * sandalye + (adet - 1) * bosluk)) / 2;
      for (let i = 0; i < adet; i++) {
        const x = baslangic + i * (sandalye + bosluk);
        parcalar.push(`<rect x="${f(x)}" y="0" width="${f(sandalye)}" height="${f(sandalyeD)}" rx="5" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`);
        parcalar.push(`<rect x="${f(x)}" y="${f(d - sandalyeD)}" width="${f(sandalye)}" height="${f(sandalyeD)}" rx="5" fill="${r.ikincil}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`);
      }
      parcalar.push(`<rect x="0" y="${f(tablaY)}" width="${f(g)}" height="${f(tablaD)}" rx="4" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`);
    } else {
      parcalar.push(`<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="4" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`);
    }
    return parcalar;
  },

  tezgah(g, d, r) {
    const parcalar = [`<rect x="0" y="0" width="${f(g)}" height="${f(d)}" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`];
    // eviye
    parcalar.push(`<rect x="${f(g * 0.08)}" y="${f(d * 0.18)}" width="${f(Math.min(g * 0.25, 55))}" height="${f(d * 0.64)}" rx="4" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`);
    // ocak (4 göz)
    const ocakX = g * 0.55, ocakG = Math.min(g * 0.3, 58);
    parcalar.push(`<rect x="${f(ocakX)}" y="${f(d * 0.15)}" width="${f(ocakG)}" height="${f(d * 0.7)}" rx="3" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`);
    for (const [dx, dy] of [[0.28, 0.32], [0.72, 0.32], [0.28, 0.68], [0.72, 0.68]]) {
      parcalar.push(`<circle cx="${f(ocakX + ocakG * dx)}" cy="${f(d * 0.15 + d * 0.7 * dy)}" r="${f(Math.min(ocakG * 0.13, 9))}" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.6)}"/>`);
    }
    return parcalar;
  },

  buzdolabi(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="3" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<line x1="0" y1="${f(d * 0.35)}" x2="${f(g)}" y2="${f(d * 0.35)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.7)}"/>`,
      `<text x="${f(g / 2)}" y="${f(d * 0.75)}" text-anchor="middle" font-size="${f(Math.min(g, d) * 0.3)}" fill="${r.cizgi}" opacity="0.55">❄</text>`,
    ];
  },

  klozet(g, d, r) {
    return [
      `<rect x="${f(g * 0.12)}" y="0" width="${f(g * 0.76)}" height="${f(d * 0.32)}" rx="3" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<ellipse cx="${f(g / 2)}" cy="${f(d * 0.62)}" rx="${f(g * 0.42)}" ry="${f(d * 0.32)}" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
    ];
  },

  lavabo(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="5" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<ellipse cx="${f(g / 2)}" cy="${f(d * 0.56)}" rx="${f(g * 0.33)}" ry="${f(d * 0.32)}" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`,
      `<circle cx="${f(g / 2)}" cy="${f(d * 0.18)}" r="${f(Math.min(g, d) * 0.07)}" fill="${r.cizgi}" opacity="0.6"/>`,
    ];
  },

  dus(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="3" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<path d="M0 0 L${f(g)} ${f(d)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.5)}" opacity="0.4"/>`,
      `<path d="M${f(g)} 0 L0 ${f(d)}" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.5)}" opacity="0.4"/>`,
      `<circle cx="${f(g / 2)}" cy="${f(d / 2)}" r="${f(Math.min(g, d) * 0.13)}" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`,
    ];
  },

  kuvet(g, d, r) {
    return [
      `<rect x="0" y="0" width="${f(g)}" height="${f(d)}" rx="8" fill="${r.dolgu}" stroke="${r.cizgi}" stroke-width="${r.kalinlik}"/>`,
      `<rect x="${f(g * 0.06)}" y="${f(d * 0.13)}" width="${f(g * 0.88)}" height="${f(d * 0.74)}" rx="${f(d * 0.3)}" fill="none" stroke="${r.cizgi}" stroke-width="${f(r.kalinlik * 0.8)}"/>`,
      `<circle cx="${f(g * 0.86)}" cy="${f(d / 2)}" r="${f(Math.min(g, d) * 0.06)}" fill="${r.cizgi}" opacity="0.6"/>`,
    ];
  },
};

export function sembolCiz(ad, g, d, renkler) {
  const ciz = SEMBOLLER[ad] ?? SEMBOLLER.dolap;
  return ciz(g, d, renkler).join('');
}

export function sembolVarMi(ad) { return Object.hasOwn(SEMBOLLER, ad); }
export const SEMBOL_ADLARI = Object.keys(SEMBOLLER);
