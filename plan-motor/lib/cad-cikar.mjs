// CAD çıkarıcı — DWG/DXF'ten sınır segmentleri + metin etiketleri.
// lifting.py'nin girdisini üretir.
//
// ⚠️ KAPALI POLİGON TUZAĞI: LwPolyline'ın `isClosed` bayrağı varsa son köşe ilk köşeye
// döner ve bu kenar köşe listesinde GÖRÜNMEZ. Atlanırsa her kapalı gövde (kolonlar,
// duvar gövdeleri) bir kenarı eksik kalır; oda sınırı kapanmaz, boyama içeriden sızar.
// Bu dosyada 153 polyline'ın 74'ü kapalıdır — sessiz ve ölümcül bir hata sınıfıdır.
import { readFileSync } from 'fs';

const SINIR_KATMANLARI = ['px_walls', 'px_openings', 'px_columns', 'Zone_Line'];

export async function cadCikar(yol, { katmanlar = SINIR_KATMANLARI } = {}) {
  const uzanti = yol.toLowerCase().split('.').pop();
  const ents = uzanti === 'dwg' ? await dwgEntities(yol) : await dxfEntities(yol);

  const segmentler = [];
  const etiketler = [];
  const katmanSayim = {};

  for (const e of ents) {
    const k = e.katman ?? '?';
    katmanSayim[k] = (katmanSayim[k] || 0) + 1;
    if (e.tip === 'metin') {
      etiketler.push(e);
      continue;
    }
    if (!katmanlar.includes(k)) continue;
    const v = e.koseler;
    for (let i = 0; i < v.length - 1; i++) segmentler.push([v[i], v[i + 1]]);
    if (e.kapali && v.length > 2) segmentler.push([v[v.length - 1], v[0]]); // ← kapanış kenarı
  }
  return { segmentler, etiketler, katmanSayim };
}

async function dwgEntities(yol) {
  const acad = await import('@node-projects/acad-ts');
  const veri = readFileSync(yol);
  const dwg = new acad.DwgReader(veri.buffer.slice(veri.byteOffset, veri.byteOffset + veri.byteLength)).read();
  const cikti = [];
  for (const e of [...(dwg.modelSpace?.entities ?? [])]) {
    const katman = e.layer?.name ?? e.layerName ?? '?';
    const t = e.constructor?.name ?? '';
    if (/MText|^Text/.test(t)) {
      const ham = (e.value ?? e.text ?? e.contents ?? '').toString();
      const p = e.insertPoint ?? e.insertionPoint ?? e.position;
      if (!p) continue;
      cikti.push({ tip: 'metin', katman, ...metniAyikla(ham), x: p.x, y: p.y });
    } else if (/LwPolyline|Polyline/.test(t)) {
      const koseler = [...e.vertices].map((v) => {
        const p = v.location ?? v;
        return [p.x, p.y];
      });
      cikti.push({ tip: 'poly', katman, koseler, kapali: !!e.isClosed });
    } else if (/^Line/.test(t)) {
      cikti.push({ tip: 'poly', katman, koseler: [[e.startPoint.x, e.startPoint.y], [e.endPoint.x, e.endPoint.y]], kapali: false });
    }
  }
  return cikti;
}

async function dxfEntities(yol) {
  const DxfParser = (await import('dxf-parser')).default;
  const d = new DxfParser().parse(readFileSync(yol, 'utf8'));
  const cikti = [];
  for (const e of d.entities ?? []) {
    const katman = e.layer ?? '?';
    if (e.type === 'MTEXT' || e.type === 'TEXT') {
      const p = e.position ?? e.startPoint;
      if (!p) continue;
      cikti.push({ tip: 'metin', katman, ...metniAyikla(e.text ?? ''), x: p.x, y: p.y });
    } else if (e.type === 'LWPOLYLINE' || e.type === 'POLYLINE') {
      cikti.push({ tip: 'poly', katman, koseler: (e.vertices ?? []).map((v) => [v.x, v.y]), kapali: !!(e.shape || e.closed) });
    } else if (e.type === 'LINE') {
      cikti.push({ tip: 'poly', katman, koseler: [[e.startPoint.x, e.startPoint.y], [e.endPoint.x, e.endPoint.y]], kapali: false });
    }
  }
  return cikti;
}

// "{\fArial|b1;SALON\P27 m2}" → { ad: "SALON", m2: 27 }
function metniAyikla(ham) {
  const temiz = ham
    .replace(/^\{/, '')
    .replace(/\}$/, '')
    .replace(/\\f[^;]*;/g, '')
    .replace(/\\[A-Za-z][^;\\]*;/g, '');
  const parcalar = temiz.split(/\\P/);
  const ad = (parcalar[0] ?? '').trim();
  const m2 = parcalar[1] ? parseFloat(parcalar[1].replace(',', '.')) : null;
  return { ad, m2: Number.isFinite(m2) ? m2 : null };
}
