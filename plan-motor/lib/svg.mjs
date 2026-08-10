// SVG renderer — 1 SVG birimi = 1 cm. Koordinat düzeni: x sağa, y AŞAĞI (ekran düzeni).
// Model doğrulanmış gelir (fail-closed kapısı cli'de). Deterministiktir: aynı model → aynı SVG.
import { uzunluk, alanM2, agirlikMerkezi, bbox, duvarNoktasi } from './geometri.mjs';
import { sigdir } from './metin-olc.mjs';

const RENK = {
  disDuvar: '#26221d', icDuvar: '#3d3830',
  odaDolgu: '#faf8f4', odaDusuk: '#fdf6ec',
  kapi: '#a05a2c', pencere: '#4a7fa5', gecis: '#8a8378',
  etiket: '#57503f', metin: '#26221d', vurgu: '#9a6b2f',
};

function xml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function f(n) { return +n.toFixed(2); }

// Duvarı açıklık boşluklarıyla parçalara böl → [[t0,t1],...] (cm cinsinden aralıklar)
function duvarParcalari(L, acikliklar) {
  const boşluklar = acikliklar
    .map((a) => [a.oran * L - a.genislik / 2, a.oran * L + a.genislik / 2])
    .sort((x, y) => x[0] - y[0]);
  const parcalar = [];
  let imlec = 0;
  for (const [b0, b1] of boşluklar) {
    if (b0 > imlec + 0.1) parcalar.push([imlec, b0]);
    imlec = Math.max(imlec, b1);
  }
  if (imlec < L - 0.1) parcalar.push([imlec, L]);
  return parcalar;
}

export function svgUret(model, secenekler = {}) {
  const noktalar = model.noktalar;
  const tumNoktalar = Object.values(noktalar);
  const kutu = bbox(tumNoktalar);
  const kenar = 120; // cm pay — ölçek çubuğu + başlık sığar
  const vbX = kutu.minX - kenar, vbY = kutu.minY - kenar;
  const vbW = kutu.w + kenar * 2, vbH = kutu.h + kenar * 2 + 60;

  // px boyutu: uzun kenar ~2000 px
  const pxOlcek = 2000 / Math.max(vbW, vbH);
  const pxW = Math.round(vbW * pxOlcek), pxH = Math.round(vbH * pxOlcek);

  const p = [];
  p.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f(vbX)} ${f(vbY)} ${f(vbW)} ${f(vbH)}" width="${pxW}" height="${pxH}" font-family="DejaVu Sans, Helvetica, Arial, sans-serif">`);
  p.push(`<defs><pattern id="dusukGuven" width="30" height="30" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="30" height="30" fill="${RENK.odaDusuk}"/><line x1="0" y1="0" x2="0" y2="30" stroke="#d9b98a" stroke-width="3"/></pattern></defs>`);
  p.push(`<rect x="${f(vbX)}" y="${f(vbY)}" width="${f(vbW)}" height="${f(vbH)}" fill="#ffffff"/>`);

  // ---- odalar (dolgu + etiket) ----
  for (const o of model.odalar ?? []) {
    const koseler = o.dongu.map((nid) => noktalar[nid]);
    const yol = koseler.map(([x, y], i) => `${i ? 'L' : 'M'}${f(x)} ${f(y)}`).join(' ') + ' Z';
    const dusuk = o.guven === 'dusuk';
    p.push(`<path d="${yol}" fill="${dusuk ? 'url(#dusukGuven)' : RENK.odaDolgu}" stroke="none"/>`);
  }

  // ---- duvarlar (açıklık boşluklarıyla) ----
  const acikliklarDuvara = new Map();
  for (const a of model.acikliklar ?? []) {
    if (!acikliklarDuvara.has(a.duvar)) acikliklarDuvara.set(a.duvar, []);
    acikliklarDuvara.get(a.duvar).push(a);
  }
  for (const d of model.duvarlar ?? []) {
    const a = noktalar[d.bas], b = noktalar[d.son];
    const L = uzunluk(a, b);
    const u = [(b[0] - a[0]) / L, (b[1] - a[1]) / L];
    const renk = d.tip === 'dis' ? RENK.disDuvar : RENK.icDuvar;
    for (const [t0, t1] of duvarParcalari(L, acikliklarDuvara.get(d.id) ?? [])) {
      const x1 = a[0] + u[0] * t0, y1 = a[1] + u[1] * t0;
      const x2 = a[0] + u[0] * t1, y2 = a[1] + u[1] * t1;
      p.push(`<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${renk}" stroke-width="${d.kalinlik}" stroke-linecap="butt"/>`);
    }
  }

  // ---- açıklıklar (kapı yayı / pencere / geçiş) ----
  for (const a of model.acikliklar ?? []) {
    const d = (model.duvarlar ?? []).find((x) => x.id === a.duvar);
    if (!d) continue;
    const A = noktalar[d.bas], B = noktalar[d.son];
    const { nokta: merkez, u, L } = duvarNoktasi(A, B, a.oran);
    const g = a.genislik;
    const p1 = [merkez[0] - u[0] * g / 2, merkez[1] - u[1] * g / 2]; // menteşe tarafı
    const p2 = [merkez[0] + u[0] * g / 2, merkez[1] + u[1] * g / 2];
    const n = [-u[1], u[0]]; // duvara dik birim
    const yon = a.aci_yonu === -1 ? -1 : 1;

    if (a.tip === 'kapi') {
      const uc = [p1[0] + n[0] * g * yon, p1[1] + n[1] * g * yon];
      // n = u'nun sabit +90° dönüğü olduğundan yay yönü yalnız aci_yonu'na bağlıdır
      // (SVG uç-nokta yay parametrizasyonu dönme-bağımsız; large-arc-flag=0 küçük yayı garanti eder)
      const sweep = yon === 1 ? 1 : 0;
      p.push(`<path d="M${f(p2[0])} ${f(p2[1])} A${f(g)} ${f(g)} 0 0 ${sweep} ${f(uc[0])} ${f(uc[1])}" fill="none" stroke="${RENK.kapi}" stroke-width="2.5" stroke-dasharray="8 6"/>`);
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(uc[0])}" y2="${f(uc[1])}" stroke="${RENK.kapi}" stroke-width="5"/>`);
    } else if (a.tip === 'pencere') {
      const t = Math.max(4, (d.kalinlik ?? 10) * 0.35);
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(p2[0])}" y2="${f(p2[1])}" stroke="${RENK.pencere}" stroke-width="${f(t)}"/>`);
      for (const uçNokta of [p1, p2]) {
        p.push(`<line x1="${f(uçNokta[0] - n[0] * (d.kalinlik / 2))}" y1="${f(uçNokta[1] - n[1] * (d.kalinlik / 2))}" x2="${f(uçNokta[0] + n[0] * (d.kalinlik / 2))}" y2="${f(uçNokta[1] + n[1] * (d.kalinlik / 2))}" stroke="${RENK.pencere}" stroke-width="2.5"/>`);
      }
    } else {
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(p2[0])}" y2="${f(p2[1])}" stroke="${RENK.gecis}" stroke-width="2" stroke-dasharray="4 6"/>`);
    }
  }

  // ---- oda etiketleri (küçük odaya küçük yazı; nota yer yoksa ⚠ yeter) ----
  for (const o of model.odalar ?? []) {
    const koseler = o.dongu.map((nid) => noktalar[nid]);
    const [cx, cy] = agirlikMerkezi(koseler);
    const m2 = alanM2(koseler);
    const dusuk = o.guven === 'dusuk';
    const boy = m2 >= 8 ? 26 : m2 >= 3 ? 19 : 13;
    const alt = m2 >= 8 ? 24 : m2 >= 3 ? 19 : 14;
    p.push(`<text x="${f(cx)}" y="${f(cy - 6)}" text-anchor="middle" font-size="${boy}" font-weight="600" fill="${RENK.metin}">${xml(o.ad ?? o.id)}</text>`);
    p.push(`<text x="${f(cx)}" y="${f(cy + alt)}" text-anchor="middle" font-size="${Math.round(boy * 0.85)}" fill="${RENK.etiket}">${m2.toFixed(1)} m²${dusuk ? ' ⚠' : ''}</text>`);
    if (dusuk && m2 >= 5) p.push(`<text x="${f(cx)}" y="${f(cy + alt + 26)}" text-anchor="middle" font-size="15" fill="${RENK.vurgu}">saha ölçümü bekliyor</text>`);
  }

  // ---- başlık + ölçek beyanı + ölçek çubuğu ----
  // B-003: başlık çerçeveden TAŞIYORDU. Sığdırma sırası: tek satırda küçült → iki satıra böl →
  // taban puntoda kırp. Taban punto ve iki-satır puntoları, başlık bloğunun üst payı (120 cm)
  // içinde kalacak ve çizime binmeyecek şekilde seçildi.
  // ⚠ Sığan başlıkta çıktı BAYT-EŞ kalır (punto 34, tek satır) — determinizm çıpası korunur.
  const kullanilirW = vbW - 60; // sol 30 + sağ 30 pay
  const bas = sigdir(model.ad ?? 'Plan', {
    genislik: kullanilirW, puntolar: [34, 31, 28, 25, 22], cokSatirPuntolar: [26, 23, 20, 18], satir: 2, kalin: true,
  });
  let y = vbY + 45;
  for (const satir of bas.satirlar) {
    p.push(`<text x="${f(vbX + 30)}" y="${f(y)}" font-size="${bas.punto}" font-weight="700" fill="${RENK.metin}">${xml(satir)}</text>`);
    y += Math.round(bas.punto * 1.2);
  }
  const beyanHam = `birim: cm · 1 birim = 1 cm · ölçü kaynağı: ${model.olcek?.kaynak ?? '?'}${secenekler.notu ? ' · ' + secenekler.notu : ''}`;
  // Ölçü kaynağı çıktıda BİREBİR geçmek zorunda (render-denetle kapısı) → beyan satırı
  // kırpılamaz; yalnız punto küçültülür. Kaynak metni tek başına sığmıyorsa punto tabana iner
  // ve öz-denetim taşmayı uyarı olarak bildirir (sessiz kesme yok).
  const beyan = sigdir(beyanHam, { genislik: kullanilirW, puntolar: [17, 15, 14, 13, 12, 11], kirpmaYok: true });
  const beyanY = bas.satirlar.length === 1 ? vbY + 72 : y + 2;
  p.push(`<text x="${f(vbX + 30)}" y="${f(beyanY)}" font-size="${beyan.punto}" fill="${RENK.etiket}">${xml(beyan.satirlar[0])}</text>`);

  const cX = vbX + 30, cY = vbY + vbH - 40;
  for (let i = 0; i < 4; i++) {
    p.push(`<rect x="${f(cX + i * 50)}" y="${f(cY)}" width="50" height="10" fill="${i % 2 ? '#ffffff' : RENK.metin}" stroke="${RENK.metin}" stroke-width="1.5"/>`);
  }
  p.push(`<text x="${f(cX)}" y="${f(cY - 8)}" font-size="15" fill="${RENK.etiket}">0</text>`);
  p.push(`<text x="${f(cX + 100)}" y="${f(cY - 8)}" font-size="15" fill="${RENK.etiket}">1 m</text>`);
  p.push(`<text x="${f(cX + 200)}" y="${f(cY - 8)}" font-size="15" fill="${RENK.etiket}">2 m</text>`);

  p.push('</svg>');
  return p.join('\n');
}
