// OKU — dış çizim dosyası raporu. DXF: dxf-parser · DWG: @node-projects/acad-ts
// (yedek: dwgdxf WASM ile DXF'e çevirip dxf-parser). Rapor: envanter + katman + birim + bbox.
// Bu v1'de dış çizim SEMANTİK MODELE otomatik çevrilmez (lifting yok — bilinçli kapsam);
// rapor, altlık ve elle model kurulumu için gereken gerçekleri verir.
import { readFileSync } from 'fs';
import { MotorHata } from './model.mjs';

const INSUNITS_ADI = { 0: 'birimsiz', 1: 'inç', 2: 'fit', 4: 'mm', 5: 'cm', 6: 'm' };

export async function dosyaOku(yol) {
  const uzanti = yol.toLowerCase().split('.').pop();
  if (uzanti === 'dxf') return dxfOku(yol);
  if (uzanti === 'dwg') return dwgOku(yol);
  throw new MotorHata(`desteklenmeyen uzantı: .${uzanti} (dxf | dwg)`, 2);
}

async function dxfOku(yol) {
  const DxfParser = (await import('dxf-parser')).default;
  const metin = readFileSync(yol, 'utf8');
  const d = new DxfParser().parse(metin);
  return raporla('dxf', 'dxf-parser', d.entities ?? [], {
    katmanlar: Object.keys(d.tables?.layer?.layers ?? {}),
    insunits: d.header?.$INSUNITS ?? null,
  }, (e) => e.type, dxfKoordinatlar);
}

async function dwgOku(yol) {
  const veri = readFileSync(yol);
  try {
    const acad = await import('@node-projects/acad-ts');
    const dwg = new acad.DwgReader(veri.buffer.slice(veri.byteOffset, veri.byteOffset + veri.byteLength)).read();
    const entities = [...(dwg.modelSpace?.entities ?? [])];
    const katmanlar = [...new Set(entities.map((e) => e.layer?.name ?? e.layerName).filter(Boolean))];
    return raporla('dwg', '@node-projects/acad-ts', entities, {
      katmanlar,
      insunits: dwg.header?.insUnits ?? null,
    }, (e) => e?.constructor?.name ?? '?', acadKoordinatlar);
  } catch (e) {
    console.error(`⚠ acad-ts okuyamadı (${e.message?.slice(0, 120)}) — dwgdxf WASM yedeğine geçiliyor`);
    const m = await import('dwgdxf');
    if (m.init) await m.init();
    const dxfMetin = await m.convertDwgToDxf(new Uint8Array(veri));
    const DxfParser = (await import('dxf-parser')).default;
    const d = new DxfParser().parse(dxfMetin.toString());
    return raporla('dwg', 'dwgdxf→dxf-parser', d.entities ?? [], {
      katmanlar: Object.keys(d.tables?.layer?.layers ?? {}),
      insunits: d.header?.$INSUNITS ?? null,
    }, (e) => e.type, dxfKoordinatlar);
  }
}

function raporla(format, arac, entities, ek, tipAl, koordinatAl) {
  const envanter = {};
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, koordinatSayisi = 0;
  for (const e of entities) {
    const t = tipAl(e);
    envanter[t] = (envanter[t] || 0) + 1;
    for (const [x, y] of koordinatAl(e)) {
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      koordinatSayisi++;
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
    }
  }
  const birimKodu = ek.insunits;
  return {
    format, arac,
    entity_toplam: entities.length,
    envanter,
    katmanlar: ek.katmanlar,
    birim: { kod: birimKodu, ad: INSUNITS_ADI[birimKodu] ?? 'bilinmiyor' },
    bbox: koordinatSayisi
      ? { minX: +minX.toFixed(1), minY: +minY.toFixed(1), genislik: +(maxX - minX).toFixed(1), yukseklik: +(maxY - minY).toFixed(1) }
      : null,
    not: 'v1: dış çizim otomatik modele çevrilmez (lifting yok); bu rapor altlık + elle model kurulumu içindir.',
  };
}

// Daire/yay/elips MERKEZ noktasıyla temsil edilirse bbox yalancı-küçük çıkar
// (mimari çizimde kolon, armatür, kapı yayı hep böyledir) → yarıçap kadar genişlet.
function merkezliUclar(merkez, yaricap, majorEksen) {
  const r = Number.isFinite(yaricap)
    ? yaricap
    : (majorEksen ? Math.hypot(majorEksen.x ?? 0, majorEksen.y ?? 0) : null);
  if (!Number.isFinite(r) || r <= 0) return [[merkez.x, merkez.y]];
  return [
    [merkez.x - r, merkez.y - r],
    [merkez.x + r, merkez.y + r],
  ];
}

function dxfKoordinatlar(e) {
  const k = [];
  if (e.vertices) for (const v of e.vertices) k.push([v.x, v.y]);
  if (e.startPoint) k.push([e.startPoint.x, e.startPoint.y]);
  if (e.endPoint) k.push([e.endPoint.x, e.endPoint.y]);
  if (e.position) k.push([e.position.x, e.position.y]);
  if (e.center) k.push(...merkezliUclar(e.center, e.radius, e.majorAxisEndPoint));
  return k;
}

function acadKoordinatlar(e) {
  const k = [];
  if (e.vertices) for (const v of e.vertices) { const p = v.location ?? v; if (p?.x !== undefined) k.push([p.x, p.y]); }
  if (e.startPoint?.x !== undefined) k.push([e.startPoint.x, e.startPoint.y]);
  // elipste endPoint MERKEZE GÖRELİ major-eksen vektörüdür, mutlak nokta değil
  if (e.endPoint?.x !== undefined && e.center?.x === undefined) k.push([e.endPoint.x, e.endPoint.y]);
  if (e.insertionPoint?.x !== undefined) k.push([e.insertionPoint.x, e.insertionPoint.y]);
  if (e.center?.x !== undefined) k.push(...merkezliUclar(e.center, e.radius, e.endPoint));
  return k;
}
