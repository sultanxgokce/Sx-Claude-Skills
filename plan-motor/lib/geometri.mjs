// Saf geometri — bağımlılıksız. Tüm uzunluklar cm, alanlar m².

export function uzunluk(a, b) {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

// Shoelace — köşe listesi [[x,y],...] → alan (cm² mutlak değer)
export function alanCm2(noktalar) {
  let s = 0;
  for (let i = 0; i < noktalar.length; i++) {
    const [x1, y1] = noktalar[i];
    const [x2, y2] = noktalar[(i + 1) % noktalar.length];
    s += x1 * y2 - x2 * y1;
  }
  return Math.abs(s) / 2;
}

export function alanM2(noktalar) {
  return alanCm2(noktalar) / 10000;
}

export function cevreCm(noktalar) {
  let s = 0;
  for (let i = 0; i < noktalar.length; i++) {
    s += uzunluk(noktalar[i], noktalar[(i + 1) % noktalar.length]);
  }
  return s;
}

export function agirlikMerkezi(noktalar) {
  // Poligon centroid'i (alan-ağırlıklı); dejenere durumda köşe ortalaması
  let a = 0, cx = 0, cy = 0;
  for (let i = 0; i < noktalar.length; i++) {
    const [x1, y1] = noktalar[i];
    const [x2, y2] = noktalar[(i + 1) % noktalar.length];
    const c = x1 * y2 - x2 * y1;
    a += c; cx += (x1 + x2) * c; cy += (y1 + y2) * c;
  }
  if (Math.abs(a) < 1e-9) {
    const n = noktalar.length;
    return [noktalar.reduce((s, p) => s + p[0], 0) / n, noktalar.reduce((s, p) => s + p[1], 0) / n];
  }
  return [cx / (3 * a), cy / (3 * a)];
}

export function bbox(noktaListesi) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [x, y] of noktaListesi) {
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
  }
  return { minX, minY, maxX, maxY, w: maxX - minX, h: maxY - minY };
}

// Duvar üstünde orana denk gelen nokta ve birim yön vektörü
export function duvarNoktasi(a, b, oran) {
  const L = uzunluk(a, b);
  const ux = (b[0] - a[0]) / L, uy = (b[1] - a[1]) / L;
  return { nokta: [a[0] + ux * L * oran, a[1] + uy * L * oran], u: [ux, uy], L };
}
