// Saf geometri — SIFIR bağımlılık. Uzunluklar cm, alanlar m².
// plan-dekor bilinçli olarak plan-motor'dan import ETMEZ: sınır yalnız CLI'dır (dosya→dosya→RC).
// Örtüşen ~40 satır matematiği taşımak, kırılgan cross-skill yol-çözümünden ucuzdur.

export function uzunluk(a, b) {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

// Shoelace — köşe listesi [[x,y],...] → alan (cm² mutlak)
export function alanCm2(noktalar) {
  let s = 0;
  for (let i = 0; i < noktalar.length; i++) {
    const [x1, y1] = noktalar[i];
    const [x2, y2] = noktalar[(i + 1) % noktalar.length];
    s += x1 * y2 - x2 * y1;
  }
  return Math.abs(s) / 2;
}

export function alanM2(noktalar) { return alanCm2(noktalar) / 10000; }

export function agirlikMerkezi(noktalar) {
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

export function duvarNoktasi(a, b, oran) {
  const L = uzunluk(a, b);
  const ux = (b[0] - a[0]) / L, uy = (b[1] - a[1]) / L;
  return { nokta: [a[0] + ux * L * oran, a[1] + uy * L * oran], u: [ux, uy], L };
}

// ---- mobilyaya özgü (plan-motor'da YOK) ----

// Eksen-hizalı dikdörtgen: {x, y, g, d} — sol-üst köşe + genişlik/derinlik
export function dikdortgenKoseleri({ x, y, g, d }) {
  return [[x, y], [x + g, y], [x + g, y + d], [x, y + d]];
}

// İki eksen-hizalı dikdörtgen çakışıyor mu? (tolerans: pay cm kadar küçültülmüş)
export function dikdortgenCakisir(a, b, tolerans = 0.5) {
  return !(a.x + a.g - tolerans <= b.x || b.x + b.g - tolerans <= a.x ||
           a.y + a.d - tolerans <= b.y || b.y + b.d - tolerans <= a.y);
}

// Ray-casting — nokta poligonun içinde mi
export function noktaIcinde(p, poligon) {
  let ic = false;
  for (let i = 0, j = poligon.length - 1; i < poligon.length; j = i++) {
    const [xi, yi] = poligon[i], [xj, yj] = poligon[j];
    if ((yi > p[1]) !== (yj > p[1]) && p[0] < ((xj - xi) * (p[1] - yi)) / (yj - yi) + xi) ic = !ic;
  }
  return ic;
}

// Dikdörtgen tamamen poligonun içinde mi? (4 köşe + kenar orta noktaları örneklenir)
export function dikdortgenIcinde(r, poligon) {
  const k = dikdortgenKoseleri(r);
  const ornekler = [...k];
  for (let i = 0; i < k.length; i++) {
    const a = k[i], b = k[(i + 1) % k.length];
    ornekler.push([(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]);
  }
  ornekler.push([r.x + r.g / 2, r.y + r.d / 2]);
  // kenardaki sayısal gürültüyü ele: örnekleri merkeze 0.5 cm çek
  const [cx, cy] = [r.x + r.g / 2, r.y + r.d / 2];
  return ornekler.every((p) => {
    const dx = cx - p[0], dy = cy - p[1];
    const L = Math.hypot(dx, dy) || 1;
    return noktaIcinde([p[0] + (dx / L) * 0.5, p[1] + (dy / L) * 0.5], poligon);
  });
}

// Dairesel sektör (kapı açılım yayı) ile eksen-hizalı dikdörtgen kesişiyor mu?
// merkez: menteşe noktası · r: kanat uzunluğu · a0,a1: radyan aralık (a0 < a1)
export function sektorDikdortgenKesisir(merkez, r, a0, a1, dik) {
  // Dikdörtgeni ızgarayla örnekle (≤ 4 cm adım) — sektör içinde tek nokta yeterli.
  const adim = Math.max(2, Math.min(4, Math.min(dik.g, dik.d) / 4));
  const normalize = (a) => { while (a < 0) a += Math.PI * 2; while (a >= Math.PI * 2) a -= Math.PI * 2; return a; };
  const b0 = normalize(a0), genislik = a1 - a0;
  for (let x = dik.x; x <= dik.x + dik.g + 1e-9; x += adim) {
    for (let y = dik.y; y <= dik.y + dik.d + 1e-9; y += adim) {
      const dx = x - merkez[0], dy = y - merkez[1];
      const mesafe = Math.hypot(dx, dy);
      if (mesafe > r) continue;
      let aci = normalize(Math.atan2(dy, dx) - b0);
      if (aci <= genislik + 1e-9) return true;
    }
  }
  return false;
}

// Bir dikdörtgeni temiz-alan payıyla büyüt (yön-farkında: mobilyanın kendi ekseninde)
// yon: 0=+x, 1=+y, 2=-x, 3=-y  (mobilyanın "ön" yüzünün baktığı yön)
export function temizAlanlaBuyut(r, temiz, yon) {
  const { on = 0, arka = 0, sol = 0, sag = 0 } = temiz ?? {};
  // yerel (ön/arka/sol/sağ) → global (+x/+y/-x/-y)
  const pay = [0, 0, 0, 0]; // [+x, +y, -x, -y]
  pay[yon] = on;
  pay[(yon + 2) % 4] = arka;
  pay[(yon + 1) % 4] = sag;
  pay[(yon + 3) % 4] = sol;
  return {
    x: r.x - pay[2], y: r.y - pay[3],
    g: r.g + pay[0] + pay[2], d: r.d + pay[1] + pay[3],
  };
}
