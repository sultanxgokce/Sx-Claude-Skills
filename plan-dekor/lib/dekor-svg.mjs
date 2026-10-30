// Renkli sunum planı çizici. 1 SVG birimi = 1 cm. Deterministik: aynı girdi → aynı SVG.
// plan-motor'un svgUret'i sabit paletlidir ve mobilya bilmez; bu yüzden ayrı çizici.
import { readFileSync } from 'fs';
import { agirlikMerkezi, alanM2, bbox, icNokta, aciklikOlc } from './geo.mjs';
import { sembolCiz } from './sembol.mjs';
import { metinGenisligi } from './metin-olcu.mjs';

const f = (n) => +n.toFixed(2);
const xml = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function temaYukle(yol) {
  const t = JSON.parse(readFileSync(yol, 'utf8'));
  for (const alan of ['zemin', 'duvar', 'aciklik', 'metin', 'oda_tipleri', 'mobilya']) {
    if (!t[alan]) throw new Error(`tema ${yol}: "${alan}" alanı eksik`);
  }
  return t;
}

// Genişlik kestirimi TEK KAYNAKTAN gelir (lib/metin-olcu.mjs) — denetim de aynı dosyayı
// kullanır; iki kopya sessizce ayrışamasın diye.

// Sığdırma sırası: tek satırda küçült → iki satıra böl → taban puntoda bırak.
function sigdir(metin, genislik, baslangicPunto) {
  const tabanPunto = Math.max(9, Math.round(baslangicPunto * 0.55));
  for (let punto = baslangicPunto; punto >= tabanPunto; punto -= 1) {
    if (metinGenisligi(metin, punto) <= genislik) return { satirlar: [metin], punto };
  }
  const kelimeler = metin.split(' ');
  if (kelimeler.length > 1) {
    for (let punto = baslangicPunto; punto >= tabanPunto; punto -= 1) {
      for (let kes = 1; kes < kelimeler.length; kes++) {
        const a = kelimeler.slice(0, kes).join(' '), b = kelimeler.slice(kes).join(' ');
        if (metinGenisligi(a, punto) <= genislik && metinGenisligi(b, punto) <= genislik) {
          return { satirlar: [a, b], punto };
        }
      }
    }
    return { satirlar: [kelimeler.slice(0, 1).join(' '), kelimeler.slice(1).join(' ')], punto: tabanPunto };
  }
  return { satirlar: [metin], punto: tabanPunto };
}

function odaBicimi(tema, tip) {
  return tema.oda_tipleri[tip ?? 'diger'] ?? tema.oda_tipleri.diger;
}

// Yön'e göre mobilya sembolünü yerine oturtan transform.
// Sembol yerel (0,0)-(G,D) çizer; yon 0=+x bakıyor → 90° döndürülür.
function mobilyaTransform(y) {
  const { x, g, d } = y.kutu;
  const yy = y.kutu.y;
  switch (y.yon) {
    case 1: return { t: `translate(${f(x)} ${f(yy)})`, G: g, D: d };                                  // +y (aşağı bakıyor)
    case 3: return { t: `translate(${f(x + g)} ${f(yy + d)}) rotate(180)`, G: g, D: d };              // -y (yukarı)
    case 0: return { t: `translate(${f(x + g)} ${f(yy)}) rotate(90)`, G: d, D: g };                   // +x (sağa)
    default: return { t: `translate(${f(x)} ${f(yy + d)}) rotate(-90)`, G: d, D: g };                 // -x (sola)
  }
}

export function dekorSvgUret(model, yerlesimler, tema, secenekler = {}) {
  // 🔴 DETERMİNİZM ÇIPASI (B-012). Çizim, model dizilerinin SIRASINI izler; eşdeğer ama farklı
  // sıralı bir model aynı resmi farklı BAYT sırasıyla üretiyordu → sha256 tutmuyordu.
  // id'ye göre kanonik sıralama bunu çözer. Odalar çakışmaz (dolgu sırası görüntüyü etkilemez);
  // duvar/açıklık da id-kararlı çizilir.
  model = {
    ...model,
    noktalar: Object.fromEntries(Object.entries(model.noktalar).sort((a, b) => a[0].localeCompare(b[0]))),
    odalar: [...(model.odalar ?? [])].sort((a, b) => String(a.id).localeCompare(String(b.id))),
    duvarlar: [...(model.duvarlar ?? [])].sort((a, b) => String(a.id).localeCompare(String(b.id))),
    acikliklar: [...(model.acikliklar ?? [])].sort((a, b) => String(a.id).localeCompare(String(b.id))),
  };
  const noktalar = model.noktalar;
  const kutu = bbox(Object.values(noktalar));
  const kenar = 140;
  const lejantYuksekligi = secenekler.lejant === false ? 0 : 150;
  const vbX = kutu.minX - kenar, vbY = kutu.minY - kenar;
  const vbW = kutu.w + kenar * 2, vbH = kutu.h + kenar * 2 + lejantYuksekligi;
  const pxOlcek = 2000 / Math.max(vbW, vbH);

  const p = [];
  p.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f(vbX)} ${f(vbY)} ${f(vbW)} ${f(vbH)}" width="${Math.round(vbW * pxOlcek)}" height="${Math.round(vbH * pxOlcek)}" font-family="${(tema && tema.yazi_tipi) || 'DejaVu Sans, Helvetica, Arial, sans-serif'}">`);

  // ---- defs: dokular + gölge ----
  p.push('<defs>');
  const gorulenDoku = new Set();
  for (const o of model.odalar ?? []) {
    const b = odaBicimi(tema, o.tip);
    const anahtar = `${b.doku}-${b.doku_renk.replace('#', '')}`;
    if (b.doku === 'yok' || gorulenDoku.has(anahtar)) continue;
    gorulenDoku.add(anahtar);
    if (b.doku === 'parke') {
      p.push(`<pattern id="d-${anahtar}" width="120" height="20" patternUnits="userSpaceOnUse"><rect width="120" height="20" fill="${b.dolgu}"/><line x1="0" y1="20" x2="120" y2="20" stroke="${b.doku_renk}" stroke-width="1.6"/><line x1="60" y1="0" x2="60" y2="20" stroke="${b.doku_renk}" stroke-width="1.6"/></pattern>`);
    } else if (b.doku === 'fayans') {
      p.push(`<pattern id="d-${anahtar}" width="33" height="33" patternUnits="userSpaceOnUse"><rect width="33" height="33" fill="${b.dolgu}"/><path d="M33 0 L33 33 L0 33" fill="none" stroke="${b.doku_renk}" stroke-width="1.6"/></pattern>`);
    }
  }
  if (tema.golge?.acik) {
    p.push(`<filter id="golge" x="-20%" y="-20%" width="150%" height="150%"><feDropShadow dx="${f(tema.golge.kayma_cm)}" dy="${f(tema.golge.kayma_cm)}" stdDeviation="${f(tema.golge.bulanik_cm)}" flood-color="${tema.golge.renk}" flood-opacity="${tema.golge.opaklik}"/></filter>`);
  }
  p.push('</defs>');

  p.push(`<rect x="${f(vbX)}" y="${f(vbY)}" width="${f(vbW)}" height="${f(vbH)}" fill="${tema.zemin}"/>`);

  // ---- oda zeminleri (doku dolgusu) ----
  for (const o of model.odalar ?? []) {
    const koseler = o.dongu.map((nid) => noktalar[nid]);
    const yol = koseler.map(([x, y], i) => `${i ? 'L' : 'M'}${f(x)} ${f(y)}`).join(' ') + ' Z';
    const b = odaBicimi(tema, o.tip);
    const anahtar = `${b.doku}-${b.doku_renk.replace('#', '')}`;
    const dolgu = b.doku === 'yok' ? b.dolgu : `url(#d-${anahtar})`;
    p.push(`<path d="${yol}" fill="${dolgu}" stroke="none" data-oda="${xml(o.id)}"/>`);
  }

  // ---- mobilyalar (gölgeli) ----
  const golgeAttr = tema.golge?.acik ? ' filter="url(#golge)"' : '';
  for (const y of yerlesimler) {
    const { t, G, D } = mobilyaTransform(y);
    p.push(`<g transform="${t}"${golgeAttr} data-mobilya="${xml(y.mobilya)}" data-oda="${xml(y.oda ?? '')}">`);
    p.push(sembolCiz(y.sembol, G, D, tema.mobilya));
    p.push('</g>');
  }

  // ---- duvarlar (poché — açıklık boşluklarıyla) ----
  const acikliklarDuvara = new Map();
  for (const a of model.acikliklar ?? []) {
    if (!acikliklarDuvara.has(a.duvar)) acikliklarDuvara.set(a.duvar, []);
    acikliklarDuvara.get(a.duvar).push(a);
  }
  for (const d of model.duvarlar ?? []) {
    const a = noktalar[d.bas], b = noktalar[d.son];
    const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const u = [(b[0] - a[0]) / L, (b[1] - a[1]) / L];
    const renk = d.tip === 'dis' ? tema.duvar.dis : tema.duvar.ic;
    for (const [t0, t1] of duvarParcalari(L, acikliklarDuvara.get(d.id) ?? [])) {
      p.push(`<line x1="${f(a[0] + u[0] * t0)}" y1="${f(a[1] + u[1] * t0)}" x2="${f(a[0] + u[0] * t1)}" y2="${f(a[1] + u[1] * t1)}" stroke="${renk}" stroke-width="${d.kalinlik}" stroke-linecap="butt"/>`);
    }
  }

  // ---- açıklıklar ----
  for (const a of model.acikliklar ?? []) {
    const d = (model.duvarlar ?? []).find((x) => x.id === a.duvar);
    if (!d) continue;
    const A = noktalar[d.bas], B = noktalar[d.son];
    const L = Math.hypot(B[0] - A[0], B[1] - A[1]);
    const u = [(B[0] - A[0]) / L, (B[1] - A[1]) / L];
    const merkez = [A[0] + u[0] * L * a.oran, A[1] + u[1] * L * a.oran];
    const g = a.genislik;
    const p1 = [merkez[0] - u[0] * g / 2, merkez[1] - u[1] * g / 2];
    const p2 = [merkez[0] + u[0] * g / 2, merkez[1] + u[1] * g / 2];
    const n = [-u[1], u[0]];
    const yon = a.aci_yonu === -1 ? -1 : 1;

    if (a.tip === 'kapi') {
      const uc = [p1[0] + n[0] * g * yon, p1[1] + n[1] * g * yon];
      p.push(`<path d="M${f(p2[0])} ${f(p2[1])} A${f(g)} ${f(g)} 0 0 ${yon === 1 ? 1 : 0} ${f(uc[0])} ${f(uc[1])}" fill="none" stroke="${tema.aciklik.kapi}" stroke-width="2" stroke-dasharray="8 6" opacity="0.8"/>`);
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(uc[0])}" y2="${f(uc[1])}" stroke="${tema.aciklik.kapi}" stroke-width="5"/>`);
    } else if (a.tip === 'pencere') {
      const t = Math.max(4, (d.kalinlik ?? 10) * 0.35);
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(p2[0])}" y2="${f(p2[1])}" stroke="${tema.aciklik.pencere}" stroke-width="${f(t)}"/>`);
      for (const uc of [p1, p2]) {
        p.push(`<line x1="${f(uc[0] - n[0] * d.kalinlik / 2)}" y1="${f(uc[1] - n[1] * d.kalinlik / 2)}" x2="${f(uc[0] + n[0] * d.kalinlik / 2)}" y2="${f(uc[1] + n[1] * d.kalinlik / 2)}" stroke="${tema.aciklik.pencere}" stroke-width="2.5"/>`);
      }
    } else {
      p.push(`<line x1="${f(p1[0])}" y1="${f(p1[1])}" x2="${f(p2[0])}" y2="${f(p2[1])}" stroke="${tema.aciklik.gecis}" stroke-width="2" stroke-dasharray="4 6"/>`);
    }
  }

  // ---- oda etiketleri (odaya SIĞDIRILIR — komşu odaya taşan etiket planı okunamaz kılar) ----
  // Oda başına mobilya kutuları — etiket bunların ÜSTÜNE binmemeli (müşteri bulgusu 2026-08-13:
  // salonda m² yazısı yemek masasının üstündeydi).
  const odaMobilyalari = new Map();
  for (const y of yerlesimler) {
    if (!y.oda) continue;
    if (!odaMobilyalari.has(y.oda)) odaMobilyalari.set(y.oda, []);
    odaMobilyalari.get(y.oda).push(y.kutu);
  }

  for (const o of model.odalar ?? []) {
    const koseler = o.dongu.map((nid) => noktalar[nid]);
    // U/L odada merkez dışarı düşer ("UIT ODA"); mobilyalı odada merkez masanın üstüne düşer.
    const [cx, cy] = icNokta(koseler, { engeller: odaMobilyalari.get(o.id) ?? [] });
    const m2 = alanM2(koseler);
    const odaKutu = bbox(koseler);

    // Etiketin sığabileceği yarıçap: çapanın kenarlara uzaklığı. Küçük/dar odada bu yarıçap
    // puntoyu VE satır sayısını kısar — yoksa yazı duvara taşıp yarım kalıyor (DUŞ 1.4 m²).
    const aciklik = aciklikOlc([cx, cy], koseler);
    const kullanilir = Math.max(40, Math.min(odaKutu.w - 24, aciklik * 2 - 10));
    const kullanilirYukseklik = Math.max(14, aciklik * 2 - 10);

    const ad = (o.ad ?? o.id).toLocaleUpperCase('tr-TR');
    // Başlangıç puntosu hem alana hem DAR KENARA bağlıdır: geniş ama sığ bir oda büyük punto
    // kaldırmaz. (Yalnız m²'ye bakmak, ince uzun odalarda taşmaya yol açıyordu.)
    const darKenar = Math.min(odaKutu.w, odaKutu.h);
    const tavanPunto = Math.min(m2 >= 8 ? 27 : m2 >= 3 ? 20 : 14, Math.max(11, Math.round(darKenar / 9)));
    const { satirlar, punto } = sigdir(ad, kullanilir, tavanPunto);

    // Dikey sığdırma: ad satırları + m² satırı yüksekliğe sığmıyorsa önce m² DÜŞÜRÜLÜR
    // (oda adı m²'den önce gelir), o da yetmezse ad tek satıra indirilir.
    const adYuksekligi = satirlar.length * punto * 1.15;
    const m2Yuksekligi = punto * 0.9;
    const m2Goster = adYuksekligi + m2Yuksekligi <= kullanilirYukseklik;
    const gosterilecek = adYuksekligi <= kullanilirYukseklik ? satirlar : [satirlar.join(' ')];

    // `data-etiket-oda`: öz-denetim etiketi ODASIYLA eşleştirebilsin. Eskiden denetim
    // etiketi ADINA göre regex'le arıyordu; iki satıra bölünen adı bulamayıp SESSİZCE
    // atlıyordu (`if (!m) continue`). Damga, "hangi metni ölçüyorum" sorusunu kesinleştirir.
    let ty = cy - 4 - (gosterilecek.length - 1) * punto * 0.55;
    for (const satir of gosterilecek) {
      p.push(`<text x="${f(cx)}" y="${f(ty)}" text-anchor="middle" font-size="${punto}" font-weight="700" fill="${tema.metin.oda}" letter-spacing="1" data-etiket-oda="${xml(o.id)}">${xml(satir)}</text>`);
      ty += punto * 1.15;
    }
    if (m2Goster) {
      p.push(`<text x="${f(cx)}" y="${f(ty + punto * 0.1)}" text-anchor="middle" font-size="${Math.round(punto * 0.8)}" fill="${tema.metin.alan}" data-etiket-oda="${xml(o.id)}">${m2.toFixed(1)} m²</text>`);
    }
  }

  // ---- başlık + ölçek beyanı ----
  p.push(`<text x="${f(vbX + 32)}" y="${f(vbY + 52)}" font-size="36" font-weight="700" fill="${tema.metin.baslik}">${xml(model.ad ?? 'Plan')}</text>`);
  const beyan = `birim: cm · 1 birim = 1 cm · ölçü kaynağı: ${model.olcek?.kaynak ?? '?'} · tema: ${tema.id}${secenekler.notu ? ' · ' + secenekler.notu : ''}`;
  p.push(`<text x="${f(vbX + 32)}" y="${f(vbY + 80)}" font-size="16" fill="${tema.metin.alan}">${xml(beyan)}</text>`);

  // ---- kuzey oku — YALNIZ model kuzeyi BEYAN ETMİŞSE ----
  // 🔴 Eskiden KOŞULSUZ basılıyordu, hep yukarı. Model şemasında kuzey alanı yok, girdi
  // çiziminde de kuzey verisi yoktu → her plan "kuzey yukarıdadır" diye ASILSIZ bir iddia
  // taşıyordu. Emlak sunum planında yön, alıcının güvendiği bilgidir; bilinmeyen yön
  // beyan edilmez. (Kuru koşu bulgusu, 2026-08-13 · DERS-ADAYI 7.)
  // `kuzey_azimut`: kuzeyin saat yönünde derecesi (0 = yukarı). Yoksa ok ÇİZİLMEZ.
  const azimut = model.kuzey_azimut;
  if (typeof azimut === 'number' && Number.isFinite(azimut)) {
    const kx = vbX + vbW - 80, ky = vbY + 80;
    p.push(`<g transform="translate(${f(kx)} ${f(ky)})"><circle r="34" fill="none" stroke="${tema.metin.lejant}" stroke-width="2" opacity="0.5"/><g transform="rotate(${f(azimut)})"><path d="M0 -28 L11 12 L0 4 L-11 12 Z" fill="${tema.metin.baslik}"/><text x="0" y="-38" text-anchor="middle" font-size="18" font-weight="700" fill="${tema.metin.lejant}">K</text></g></g>`);
  }

  // ---- ölçek çubuğu ----
  const cX = vbX + 32, cY = vbY + vbH - lejantYuksekligi - 34;
  for (let i = 0; i < 4; i++) {
    p.push(`<rect x="${f(cX + i * 50)}" y="${f(cY)}" width="50" height="10" fill="${i % 2 ? tema.zemin : tema.metin.baslik}" stroke="${tema.metin.baslik}" stroke-width="1.5"/>`);
  }
  p.push(`<text x="${f(cX)}" y="${f(cY - 8)}" font-size="15" fill="${tema.metin.alan}">0</text>`);
  p.push(`<text x="${f(cX + 200)}" y="${f(cY - 8)}" font-size="15" fill="${tema.metin.alan}">2 m</text>`);

  // ---- lejant ----
  if (lejantYuksekligi > 0) {
    const kalemler = lejantKalemleri(model, yerlesimler, tema);
    const ly = vbY + vbH - lejantYuksekligi + 18;
    p.push(`<text x="${f(vbX + 32)}" y="${f(ly)}" font-size="19" font-weight="700" fill="${tema.metin.lejant}">LEJANT</text>`);
    const sutun = Math.max(1, Math.floor((vbW - 64) / 320));
    kalemler.forEach((k, i) => {
      const sx = vbX + 32 + (i % sutun) * 320;
      const sy = ly + 30 + Math.floor(i / sutun) * 30;
      p.push(`<rect x="${f(sx)}" y="${f(sy - 13)}" width="20" height="16" fill="${k.renk}" stroke="${tema.mobilya.cizgi}" stroke-width="1.4"/>`);
      p.push(`<text x="${f(sx + 30)}" y="${f(sy)}" font-size="17" fill="${tema.metin.lejant}">${xml(k.etiket)}</text>`);
    });
  }

  p.push('</svg>');
  return p.join('\n');
}

function lejantKalemleri(model, yerlesimler, tema) {
  const kalemler = [];
  const gorulen = new Set();
  for (const o of model.odalar ?? []) {
    const tip = o.tip ?? 'diger';
    if (gorulen.has(tip)) continue;
    gorulen.add(tip);
    kalemler.push({ etiket: tipAdi(tip), renk: odaBicimi(tema, tip).dolgu });
  }
  const mobSayisi = new Map();
  for (const y of yerlesimler) mobSayisi.set(y.ad, (mobSayisi.get(y.ad) ?? 0) + 1);
  for (const [ad, sayi] of [...mobSayisi.entries()].sort((a, b) => a[0].localeCompare(b[0], 'tr'))) {
    kalemler.push({ etiket: `${ad} ×${sayi}`, renk: tema.mobilya.dolgu });
  }
  return kalemler;
}

const TIP_ADLARI = {
  oturma_odasi: 'Oturma Odası', yatak_odasi: 'Yatak Odası', mutfak: 'Mutfak',
  banyo: 'Banyo', wc: 'WC', hol: 'Hol', antre: 'Antre', balkon: 'Balkon',
  kiler: 'Kiler', giyinme: 'Giyinme Odası', diger: 'Diğer',
};
function tipAdi(t) { return TIP_ADLARI[t] ?? t; }

function duvarParcalari(L, acikliklar) {
  const bosluklar = acikliklar
    .map((a) => [a.oran * L - a.genislik / 2, a.oran * L + a.genislik / 2])
    .sort((x, y) => x[0] - y[0]);
  const parcalar = [];
  let imlec = 0;
  for (const [b0, b1] of bosluklar) {
    if (b0 > imlec + 0.1) parcalar.push([imlec, b0]);
    imlec = Math.max(imlec, b1);
  }
  if (imlec < L - 0.1) parcalar.push([imlec, L]);
  return parcalar;
}
