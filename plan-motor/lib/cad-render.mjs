// CAD RENDER — bir DWG/DXF'i KENDİ geometrisiyle çizer (sadık gösterim).
//
// Bunu model-render'dan (lib/svg.mjs) ayıran şey: orada plan semantik modelden ÜRETİLİR
// (revizyon için), burada çizimde ne varsa O gösterilir. İkisi ayrı iştir:
//   · mevcut planı GÖSTERMEK      → bu dosya (mimarın gövdeleri zaten çizilmiş, yeniden kurma)
//   · planı DEĞİŞTİRMEK           → model + lib/svg.mjs
// Mevcut durumu model üstünden çizmeye çalışmak, hazır duvar gövdelerini oda konturlarından
// yeniden inşa etmek demektir; kenarlar taraklanır, odalar arasında boşluk kalır. Yapılmaz.
//
// ⚠️ İKİ TUZAK (ikisi de bu projede ölçüldü):
//  1. `isClosed` polyline'ın son→ilk kenarı köşe listesinde GÖRÜNMEZ (bu dosyada 74/153 kapalı).
//  2. `bulge` YAY demektir. Köşede bulge≠0 ise o kenar düz DEĞİL, yaydır. Yok sayılırsa
//     kapı kanadı yay yerine kiriş çizilir — kapılar üçgene döner (bu dosyada 14 köşe bulge'lu).
import { readFileSync } from 'fs';
import { sigdir } from './metin-olc.mjs';

// Katman biçimi — AutoCAD monokrom çıktısına yakın
const BICIM = {
  px_walls: { dolgu: '#9d9d9d', cizgi: '#1b1b1b', kalinlik: 1.6 },
  px_columns: { dolgu: '#111111', cizgi: '#111111', kalinlik: 1.6 },
  px_wallhatch: { dolgu: '#c9c9c9', cizgi: 'none', kalinlik: 0 },
  px_openings: { dolgu: 'none', cizgi: '#1b1b1b', kalinlik: 1.3 },
  px_furniture: { dolgu: 'none', cizgi: '#8a8a8a', kalinlik: 1.0 },
  Zone_Line: { dolgu: 'none', cizgi: '#1b1b1b', kalinlik: 1.3 },
  DimLine: { dolgu: 'none', cizgi: '#7a7a7a', kalinlik: 0.9 },
  _varsayilan: { dolgu: 'none', cizgi: '#4a4a4a', kalinlik: 1.0 },
};
// çizim sırası: dolgular altta, çizgiler üstte
const SIRA = ['px_wallhatch', 'px_walls', 'px_columns', 'Zone_Line', 'px_furniture', 'DimLine', 'px_openings'];

export async function cadEntities(yol) {
  const uzanti = yol.toLowerCase().split('.').pop();
  if (uzanti === 'dwg') return dwgOku(yol);
  if (uzanti === 'dxf') return dxfOku(yol);
  throw new Error(`desteklenmeyen uzantı: .${uzanti}`);
}

async function dwgOku(yol) {
  const acad = await import('@node-projects/acad-ts');
  const veri = readFileSync(yol);
  const dwg = new acad.DwgReader(veri.buffer.slice(veri.byteOffset, veri.byteOffset + veri.byteLength)).read();
  const cikti = [];
  for (const e of [...(dwg.modelSpace?.entities ?? [])]) {
    const katman = e.layer?.name ?? '?';
    const t = e.constructor?.name ?? '';
    if (/MText|^Text/.test(t)) {
      const p = e.insertPoint ?? e.insertionPoint ?? e.position;
      if (p) cikti.push({ tur: 'metin', katman, metin: (e.value ?? e.text ?? '').toString(), x: p.x, y: p.y, yukseklik: e.height ?? e.verticalHeight ?? 22 });
    } else if (/LwPolyline|Polyline/.test(t)) {
      const koseler = [...e.vertices].map((v) => {
        const p = v.location ?? v;
        return { x: p.x, y: p.y, bulge: v.bulge ?? 0 };
      });
      cikti.push({ tur: 'poly', katman, koseler, kapali: !!e.isClosed });
    } else if (/^Line/.test(t)) {
      cikti.push({ tur: 'poly', katman, kapali: false, koseler: [
        { x: e.startPoint.x, y: e.startPoint.y, bulge: 0 },
        { x: e.endPoint.x, y: e.endPoint.y, bulge: 0 },
      ] });
    } else if (/^Arc/.test(t)) {
      cikti.push({ tur: 'yay', katman, cx: e.center.x, cy: e.center.y, r: e.radius, bas: e.startAngle, son: e.endAngle });
    } else if (/^Circle/.test(t)) {
      cikti.push({ tur: 'daire', katman, cx: e.center.x, cy: e.center.y, r: e.radius });
    }
  }
  return cikti;
}

async function dxfOku(yol) {
  const DxfParser = (await import('dxf-parser')).default;
  const d = new DxfParser().parse(readFileSync(yol, 'utf8'));
  const cikti = [];
  for (const e of d.entities ?? []) {
    const katman = e.layer ?? '?';
    if (e.type === 'MTEXT' || e.type === 'TEXT') {
      const p = e.position ?? e.startPoint;
      if (p) cikti.push({ tur: 'metin', katman, metin: e.text ?? '', x: p.x, y: p.y, yukseklik: e.height ?? 22 });
    } else if (e.type === 'LWPOLYLINE' || e.type === 'POLYLINE') {
      cikti.push({
        tur: 'poly', katman, kapali: !!(e.shape || e.closed),
        koseler: (e.vertices ?? []).map((v) => ({ x: v.x, y: v.y, bulge: v.bulge ?? 0 })),
      });
    } else if (e.type === 'LINE') {
      cikti.push({ tur: 'poly', katman, kapali: false, koseler: [
        { x: e.startPoint.x, y: e.startPoint.y, bulge: 0 },
        { x: e.endPoint.x, y: e.endPoint.y, bulge: 0 },
      ] });
    } else if (e.type === 'ARC') {
      cikti.push({ tur: 'yay', katman, cx: e.center.x, cy: e.center.y, r: e.radius, bas: (e.startAngle * Math.PI) / 180, son: (e.endAngle * Math.PI) / 180 });
    } else if (e.type === 'CIRCLE') {
      cikti.push({ tur: 'daire', katman, cx: e.center.x, cy: e.center.y, r: e.radius });
    }
  }
  return cikti;
}

// ───────────────────────────────────────────────────────────────────────────
// NOKTA REVİZYONU — mevcut bir çizimin geometrisini dosya-tabanlı bir tarifle
// düzenler (duvar kaydır / sil). Sıfırdan model kurmadan "şu duvarı 70 cm kaydır"
// demenin yolu budur; çıktı yine çizimin kendi geometrisidir, kalite düşmez.
//
// Tarif biçimi:
//   { "tasi": [ { "ad": "...", "bolge": [x0,y0,x1,y1], "katman": "px_walls", "dx": -70, "dy": 0 } ],
//     "sil":  [ { "ad": "...", "bolge": [x0,y0,x1,y1], "katman": "px_walls" } ] }
// Kural: bir nesne ancak TÜM köşeleri bölgenin içindeyse etkilenir — yarısı dışarıda
// kalan bir duvarı kaydırmak çizimi sessizce kopartır.
export function duzenleUygula(entities, duzenleme) {
  const gunluk = [];
  const icinde = (e, b) =>
    (e.koseler ?? []).length > 0 &&
    e.koseler.every((v) => v.x >= b[0] && v.x <= b[2] && v.y >= b[1] && v.y <= b[3]);

  let sonuc = entities.map((e) => (e.tur === 'poly' ? { ...e, koseler: e.koseler.map((v) => ({ ...v })) } : { ...e }));

  for (const s of duzenleme.sil ?? []) {
    const once = sonuc.length;
    sonuc = sonuc.filter((e) => !(e.tur === 'poly' && (!s.katman || e.katman === s.katman) && icinde(e, s.bolge)));
    gunluk.push(`sil "${s.ad ?? '?'}": ${once - sonuc.length} nesne`);
  }
  for (const t of duzenleme.tasi ?? []) {
    let sayi = 0;
    for (const e of sonuc) {
      if (e.tur !== 'poly') continue;
      if (t.katman && e.katman !== t.katman) continue;
      if (!icinde(e, t.bolge)) continue;
      for (const v of e.koseler) { v.x += t.dx ?? 0; v.y += t.dy ?? 0; }
      sayi++;
    }
    gunluk.push(`taşı "${t.ad ?? '?'}" (dx=${t.dx ?? 0}, dy=${t.dy ?? 0}): ${sayi} nesne`);
    if (sayi === 0) gunluk.push(`  ⚠ hiçbir nesne eşleşmedi — bölge/katman yanlış olabilir`);
  }
  return { entities: sonuc, gunluk };
}

// ───────────────────────────────────────────────────────────────────────────
// DUVAR GÖVDESİ — bazı çizimlerde duvarlar kapalı poligon DEĞİL, açık çizgi
// parçalarıyla (iki paralel yüz + uç kapakları) çizilir; dolgu tutunacak yüzey
// yoktur. Gövdeyi çizimin KENDİ çizgilerinden kapatırız: parçalar kesişimlerde
// kırılır, düzlemsel graf kurulur, en küçük yüzler bulunur. Oda etiketi İÇEREN
// yüz odadır (beyaz kalır), en büyük yüz dış dünyadır; geriye kalan yüzler
// duvar/kolon gövdesidir → gri dolar.
// (Yalnız eksen-hizalı, yaysız duvar çizgileri için — px_walls tam böyledir.)
const T = 0.6;
const dgm = (p) => `${Math.round(p[0] / T)},${Math.round(p[1] / T)}`;

function parcalaraAyir(segmentler) {
  const noktalar = new Map();
  const ekle = (p) => noktalar.set(dgm(p), p);
  for (const [a, b] of segmentler) { ekle(a); ekle(b); }
  const yatay = segmentler.filter(([a, b]) => Math.abs(a[1] - b[1]) < T);
  const dikey = segmentler.filter(([a, b]) => Math.abs(a[0] - b[0]) < T);
  for (const [ya, yb] of yatay) {
    const y = ya[1], [x0, x1] = [ya[0], yb[0]].sort((m, n) => m - n);
    for (const [da, db] of dikey) {
      const x = da[0], [t0, t1] = [da[1], db[1]].sort((m, n) => m - n);
      if (x >= x0 - T && x <= x1 + T && y >= t0 - T && y <= t1 + T) ekle([x, y]);
    }
  }
  const tum = [...noktalar.values()];
  const parcalar = new Map();
  for (const [a, b] of segmentler) {
    const dikeyMi = Math.abs(a[0] - b[0]) < T;
    const sabit = dikeyMi ? a[0] : a[1];
    const [t0, t1] = (dikeyMi ? [a[1], b[1]] : [a[0], b[0]]).sort((m, n) => m - n);
    const uzerinde = tum
      .filter((p) => (dikeyMi ? Math.abs(p[0] - sabit) < T && p[1] >= t0 - T && p[1] <= t1 + T
                              : Math.abs(p[1] - sabit) < T && p[0] >= t0 - T && p[0] <= t1 + T))
      .map((p) => (dikeyMi ? p[1] : p[0]))
      .sort((m, n) => m - n);
    for (let i = 0; i < uzerinde.length - 1; i++) {
      const u = dikeyMi ? [sabit, uzerinde[i]] : [uzerinde[i], sabit];
      const v = dikeyMi ? [sabit, uzerinde[i + 1]] : [uzerinde[i + 1], sabit];
      if (dgm(u) !== dgm(v)) parcalar.set([dgm(u), dgm(v)].sort().join('|'), [u, v]);
    }
  }
  return [...parcalar.values()];
}

function yuzleriBul(parcalar) {
  const konum = new Map();
  const komsu = new Map();
  for (const [a, b] of parcalar) {
    const ka = dgm(a), kb = dgm(b);
    konum.set(ka, a); konum.set(kb, b);
    if (!komsu.has(ka)) komsu.set(ka, []);
    if (!komsu.has(kb)) komsu.set(kb, []);
    komsu.get(ka).push(kb); komsu.get(kb).push(ka);
  }
  const aci = (u, v) => Math.atan2(konum.get(v)[1] - konum.get(u)[1], konum.get(v)[0] - konum.get(u)[0]);
  for (const [u, liste] of komsu) liste.sort((a, b) => aci(u, a) - aci(u, b));

  const gidilen = new Set();
  const yuzler = [];
  for (const [a0, b0] of parcalar) {
    for (const [bas, son] of [[dgm(a0), dgm(b0)], [dgm(b0), dgm(a0)]]) {
      if (gidilen.has(`${bas}>${son}`)) continue;
      const dongu = [];
      let u = bas, v = son;
      while (true) {
        gidilen.add(`${u}>${v}`);
        dongu.push(u);
        const liste = komsu.get(v);
        const i = liste.indexOf(u);
        const w = liste[(i - 1 + liste.length) % liste.length]; // en dar sağa dönüş
        [u, v] = [v, w];
        if (u === bas && v === son) break;
        if (dongu.length > 20000) return [];
      }
      if (dongu.length >= 3) yuzler.push(dongu.map((k) => konum.get(k)));
    }
  }
  return yuzler;
}

const isaretliAlan = (poly) => {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
};

const iceriyorMu = (nokta, poly) => {
  let ic = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > nokta[1]) !== (yj > nokta[1]) &&
        nokta[0] < ((xj - xi) * (nokta[1] - yi)) / (yj - yi) + xi) ic = !ic;
  }
  return ic;
};

export function duvarGovdeleri(entities, katmanlar = ['px_walls', 'px_columns']) {
  const segmentler = [];
  for (const e of entities) {
    if (e.tur !== 'poly' || !katmanlar.includes(e.katman)) continue;
    const k = e.koseler;
    const son = e.kapali ? k.length : k.length - 1;
    for (let i = 0; i < son; i++) {
      const a = k[i], b = k[(i + 1) % k.length];
      if (Math.abs(a.bulge) > 1e-9) return [];               // yay varsa bu yol geçersiz
      if (Math.abs(a.x - b.x) > T && Math.abs(a.y - b.y) > T) return []; // eğik varsa da
      segmentler.push([[a.x, a.y], [b.x, b.y]]);
    }
  }
  if (!segmentler.length) return [];
  const yuzler = yuzleriBul(parcalaraAyir(segmentler));
  if (!yuzler.length) return [];

  const etiketler = entities.filter((e) => e.tur === 'metin').map((e) => [e.x, e.y]);
  // ⚠️ İŞARETE GÖRE ELEME YAPILMAZ: yüz dolaşımı iç yüzleri tutarlı yönde vermez;
  // işareti pozitif olanları seçmek dış duvar bantlarının yarısını sessizce düşürür.
  // Doğru ölçüt MUTLAK alandır: en büyüğü dış dünyadır, etiket içerenler odadır.
  const alanli = yuzler.map((y) => ({ poly: y, alan: Math.abs(isaretliAlan(y)) })).filter((y) => y.alan > 1);
  if (!alanli.length) return [];
  const enBuyuk = Math.max(...alanli.map((y) => y.alan));
  return alanli
    .filter((y) => y.alan < enBuyuk * 0.999)                 // dış dünya yüzü at
    .filter((y) => !etiketler.some((p) => iceriyorMu(p, y.poly))) // oda yüzü at
    .map((y) => y.poly);
}

// MText biçim kodlarını ayıkla: "{\fArial|b1;SALON\P27 m2}" → ["SALON", "27 m2"]
function metniAyikla(ham) {
  return ham
    .replace(/^\{/, '').replace(/\}$/, '')
    .replace(/\\f[^;]*;/g, '')
    .replace(/\\[A-Za-z][^;\\]*;/g, '')
    .split(/\\P/)
    .map((s) => s.trim())
    .filter(Boolean);
}

const s2 = (n) => (+n).toFixed(2);

// bulge → SVG yay komutu. bulge = tan(θ/4); θ = kapsanan açı.
// y AYNALANDIĞI için (ekran y aşağı) dönüş yönü ters çevrilir → sweep = bulge>0 ? 0 : 1
function yayKomutu(p1, p2, bulge, Y) {
  const teta = 4 * Math.atan(bulge);
  const kiris = Math.hypot(p2.x - p1.x, p2.y - p1.y);
  const yaricap = Math.abs(kiris / (2 * Math.sin(teta / 2)));
  if (!Number.isFinite(yaricap) || yaricap <= 0) return `L${s2(p2.x)} ${s2(Y(p2.y))}`;
  const buyukYay = Math.abs(teta) > Math.PI ? 1 : 0;
  const yon = bulge > 0 ? 0 : 1;
  return `A${s2(yaricap)} ${s2(yaricap)} 0 ${buyukYay} ${yon} ${s2(p2.x)} ${s2(Y(p2.y))}`;
}

function yolVer(e, Y) {
  const k = e.koseler;
  if (!k.length) return null;
  const parca = [`M${s2(k[0].x)} ${s2(Y(k[0].y))}`];
  const son = e.kapali ? k.length : k.length - 1;
  for (let i = 0; i < son; i++) {
    const a = k[i], b = k[(i + 1) % k.length];
    parca.push(Math.abs(a.bulge) > 1e-9 ? yayKomutu(a, b, a.bulge, Y) : `L${s2(b.x)} ${s2(Y(b.y))}`);
  }
  if (e.kapali) parca.push('Z'); // ← kapanış kenarı; atlanırsa gövde bir kenar eksik kalır
  return parca.join(' ');
}

export function cadSvg(entities, { baslik, altbaslik, genislikPx = 2200, govdeler = null, vurgu = null, kirp = null } = {}) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const gozet = (x, y) => {
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
  };
  for (const e of entities) {
    if (e.tur === 'poly') for (const v of e.koseler) gozet(v.x, v.y);
    else if (e.tur === 'yay' || e.tur === 'daire') { gozet(e.cx - e.r, e.cy - e.r); gozet(e.cx + e.r, e.cy + e.r); }
    else if (e.tur === 'metin') gozet(e.x, e.y);
  }
  if (kirp) { minX = kirp[0]; minY = kirp[1]; maxX = kirp[2]; maxY = kirp[3]; }
  const pay = 90;
  const ustPay = baslik ? 210 : pay;   // başlık çizimin üstüne binmesin
  const altPay = 150;                  // ölçek çubuğu için
  const vbX = minX - pay, vbW = maxX - minX + pay * 2;
  const vbY = minY - ustPay, vbH = maxY - minY + ustPay + altPay;
  const Y = (y) => maxY + minY - y; // DWG y yukarı → ekran y aşağı

  const p = [];
  p.push(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${s2(vbX)} ${s2(vbY)} ${s2(vbW)} ${s2(vbH)}" ` +
    `width="${Math.round(genislikPx)}" height="${Math.round((genislikPx * vbH) / vbW)}" ` +
    `font-family="DejaVu Sans, Helvetica, Arial, sans-serif">`
  );
  p.push(`<rect x="${s2(vbX)}" y="${s2(vbY)}" width="${s2(vbW)}" height="${s2(vbH)}" fill="#ffffff"/>`);

  if (baslik) {
    // B-003 (aynı sınıf, bu yol da taşıyordu): başlığı çerçeveye SIĞDIR — tek satırda küçült,
    // olmazsa iki satıra böl, olmazsa taban puntoda kırp. Sığan başlıkta çıktı BAYT-EŞ kalır
    // (punto 46, tek satır) → mevcut paftaların determinizm çıpaları korunur.
    const kullanilirW = vbW - 80;
    const bas = sigdir(baslik, {
      genislik: kullanilirW, puntolar: [46, 42, 38, 34, 30], cokSatirPuntolar: [34, 31, 28, 25], satir: 2, kalin: true,
    });
    let by = vbY + 70;
    for (const satir of bas.satirlar) {
      p.push(`<text x="${s2(vbX + 40)}" y="${s2(by)}" font-size="${bas.punto}" font-weight="700" fill="#1b1b1b">${xml(satir)}</text>`);
      by += Math.round(bas.punto * 1.15);
    }
    if (altbaslik) {
      const alt = sigdir(altbaslik, { genislik: kullanilirW, puntolar: [24, 22, 20, 18, 16] });
      const altY = bas.satirlar.length === 1 ? vbY + 112 : by + 6;
      p.push(`<text x="${s2(vbX + 40)}" y="${s2(altY)}" font-size="${alt.punto}" fill="#6a6a6a">${xml(alt.satirlar[0])}</text>`);
    }
  }

  // duvar gövdesi dolgusu (çizimde kapalı gövde yoksa çizgilerden kapatılır)
  if (govdeler && govdeler.length) {
    p.push(`<g fill="${BICIM.px_walls.dolgu}" stroke="none">`);
    for (const g of govdeler) {
      p.push(`<path d="${g.map(([x, y], i) => `${i ? 'L' : 'M'}${s2(x)} ${s2(Y(y))}`).join(' ')} Z"/>`);
    }
    p.push('</g>');
  }

  const katmanlar = [...new Set(entities.map((e) => e.katman))];
  const sirali = [...SIRA.filter((k) => katmanlar.includes(k)), ...katmanlar.filter((k) => !SIRA.includes(k) && k !== 'TEXT')];

  for (const kat of sirali) {
    const b = BICIM[kat] ?? BICIM._varsayilan;
    p.push(`<g fill="${b.dolgu}" stroke="${b.cizgi}" stroke-width="${b.kalinlik}" stroke-linejoin="round" stroke-linecap="round">`);
    for (const e of entities) {
      if (e.katman !== kat) continue;
      if (e.tur === 'poly') {
        const d = yolVer(e, Y);
        if (d) p.push(`<path d="${d}"${e.kapali ? '' : ' fill="none"'}/>`);
      } else if (e.tur === 'daire') {
        p.push(`<circle cx="${s2(e.cx)}" cy="${s2(Y(e.cy))}" r="${s2(e.r)}"/>`);
      } else if (e.tur === 'yay') {
        const x1 = e.cx + e.r * Math.cos(e.bas), y1 = e.cy + e.r * Math.sin(e.bas);
        const x2 = e.cx + e.r * Math.cos(e.son), y2 = e.cy + e.r * Math.sin(e.son);
        const kapsam = (e.son - e.bas + 2 * Math.PI) % (2 * Math.PI);
        p.push(`<path fill="none" d="M${s2(x1)} ${s2(Y(y1))} A${s2(e.r)} ${s2(e.r)} 0 ${kapsam > Math.PI ? 1 : 0} 0 ${s2(x2)} ${s2(Y(y2))}"/>`);
      }
    }
    p.push('</g>');
  }

  // ── VURGU KATMANI: değişiklik paftası (yıkılan / yeni açılan / etkilenen bölge) ──
  if (vurgu) {
    for (const b of vurgu.bolge ?? []) {
      const d = b.poligon.map(([x, y], i) => `${i ? 'L' : 'M'}${s2(x)} ${s2(Y(y))}`).join(' ') + ' Z';
      p.push(`<path d="${d}" fill="${b.renk ?? '#f0b429'}" fill-opacity="0.22" stroke="${b.renk ?? '#f0b429'}" stroke-width="4" stroke-dasharray="18 10"/>`);
    }
    for (const y of vurgu.yikilan ?? []) {
      p.push(`<line x1="${s2(y.a[0])}" y1="${s2(Y(y.a[1]))}" x2="${s2(y.b[0])}" y2="${s2(Y(y.b[1]))}" stroke="#ffffff" stroke-width="26" stroke-linecap="round"/>`);
      p.push(`<line x1="${s2(y.a[0])}" y1="${s2(Y(y.a[1]))}" x2="${s2(y.b[0])}" y2="${s2(Y(y.b[1]))}" stroke="#c0392b" stroke-width="9" stroke-dasharray="16 11" stroke-linecap="round"/>`);
    }
    for (const k of vurgu.yeni_kapi ?? []) {
      p.push(`<line x1="${s2(k.a[0])}" y1="${s2(Y(k.a[1]))}" x2="${s2(k.b[0])}" y2="${s2(Y(k.b[1]))}" stroke="#ffffff" stroke-width="24" stroke-linecap="round"/>`);
      p.push(`<line x1="${s2(k.a[0])}" y1="${s2(Y(k.a[1]))}" x2="${s2(k.b[0])}" y2="${s2(Y(k.b[1]))}" stroke="#1e8449" stroke-width="9" stroke-linecap="round"/>`);
    }
    for (const d of vurgu.yeni_duvar ?? []) {
      p.push(`<line x1="${s2(d.a[0])}" y1="${s2(Y(d.a[1]))}" x2="${s2(d.b[0])}" y2="${s2(Y(d.b[1]))}" stroke="#1f4e79" stroke-width="22" stroke-linecap="butt"/>`);
    }
    for (const n of vurgu.not ?? []) {
      p.push(`<text x="${s2(n.x)}" y="${s2(Y(n.y))}" font-size="${n.boy ?? 28}" font-weight="700" fill="${n.renk ?? '#c0392b'}" text-anchor="middle">${xml(n.metin)}</text>`);
    }
  }

  // etiketler en üstte
  for (const e of entities) {
    if (e.tur !== 'metin') continue;
    const satirlar = metniAyikla(e.metin);
    const h = Math.max(e.yukseklik || 22, 20);
    satirlar.forEach((satir, i) => {
      const kalin = i === 0;
      p.push(
        `<text x="${s2(e.x)}" y="${s2(Y(e.y) + i * h * 1.35)}" font-size="${s2(h * (kalin ? 1.15 : 1.05))}" ` +
        `font-weight="${kalin ? 700 : 400}" fill="#57503f" text-anchor="middle">${xml(satir)}</text>`
      );
    });
  }

  // ölçek çubuğu
  const cX = vbX + 40, cY = vbY + vbH - 46;
  for (let i = 0; i < 4; i++) {
    p.push(`<rect x="${s2(cX + i * 50)}" y="${s2(cY)}" width="50" height="11" fill="${i % 2 ? '#ffffff' : '#1b1b1b'}" stroke="#1b1b1b" stroke-width="1.4"/>`);
  }
  p.push(`<text x="${s2(cX)}" y="${s2(cY - 10)}" font-size="20" fill="#6a6a6a">0</text>`);
  p.push(`<text x="${s2(cX + 100)}" y="${s2(cY - 10)}" font-size="20" fill="#6a6a6a">1 m</text>`);
  p.push(`<text x="${s2(cX + 200)}" y="${s2(cY - 10)}" font-size="20" fill="#6a6a6a">2 m</text>`);

  p.push('</svg>');
  return p.join('\n');
}

function xml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
