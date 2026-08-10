// Duvar GÖVDESİ — merkez hatlarından birleşik (union) kontur üretir.
//
// 🔴 NEDEN VAR: DWG'ye duvarları "kalın genişlikli merkez polyline" olarak yazıyorduk.
// Kalın polyline'ın ucu DÜZ KESİKTİR; iki duvar köşede buluşunca uçlar birbirine girer,
// dışarıda çentik / içeride bindirme kalır. AutoCAD bunları birleştirmez — ayrı varlıklardır.
// Sultan çıktıya bakıp "kenar birleşimleri kötü duruyor" dedi (2026-08-07); sebebi budur.
//
// Referans çizim (`tellal/ss/ornekcizim.dwg`) ölçüldü: duvar gövdesi ağın BİRLEŞİK DIŞ
// KONTURU olarak çizilmiş — en büyük taramanın sınırı 20 yol / 125 kenar, yani tüm duvar
// ağı TEK taralı bölge. Köşede kesişen çizgi yok. Analiz: tellal/_agents/spec/REFERANS-CIZIM-ANALIZI.md
//
// Model DEĞİŞMEZ: ölçü merkez hatlarında yaşamaya devam eder. Burada yapılan yalnız ÇİZİM
// stratejisi — "çizim, modelin ölçtüğünden fazlasını iddia edemez" değişmezi korunur.
import * as pc from 'polygon-clipping';
import { duvarNoktasi } from './geometri.mjs';

const birlestir = pc.union ?? pc.default?.union;
const cikar = pc.difference ?? pc.default?.difference;
if (typeof birlestir !== 'function' || typeof cikar !== 'function') {
  throw new Error('polygon-clipping union/difference bulunamadı — bağımlılık bozuk');
}

// Ondalık gürültü kapısı: kayan-nokta artıkları union'ı sahte kenarlara böler.
// 1e-6 cm = 10 nanometre; mimari ölçüde anlamsız, sayısal olarak kritik.
const YUVARLA = (v) => Math.round(v * 1e6) / 1e6;

/**
 * Duvar merkez hatlarından gövde poligonlarını üretir.
 * @param {object} model plan-motor modeli (noktalar + duvarlar)
 * @returns {{halkalar: Array<{dis: number[][], delikler: number[][][]}>, uyarilar: string[]}}
 */
export function duvarGovdesi(model) {
  const uyarilar = [];
  const noktalar = model.noktalar ?? {};
  const duvarlar = model.duvarlar ?? [];
  if (!duvarlar.length) return { halkalar: [], uyarilar };

  // --- 1) Uç DERECESİ: bir nokta kaç duvarın ucu? ---
  // Yalnız BAŞKA duvarla buluşan uçlar uzatılır. Serbest uç uzatılırsa duvar havada
  // yarım kalınlık taşar — bu, olmayan bir duvarı iddia etmek olur.
  const derece = {};
  for (const d of duvarlar) {
    derece[d.bas] = (derece[d.bas] ?? 0) + 1;
    derece[d.son] = (derece[d.son] ?? 0) + 1;
  }

  // --- 2) Her duvar → dikdörtgen (birleşen uçlarda kalınlık/2 uzatılmış) ---
  const dikdortgenler = [];
  for (const d of duvarlar) {
    const a = noktalar[d.bas], b = noktalar[d.son];
    if (!a || !b) { uyarilar.push(`duvar ${d.id}: tanımsız nokta — gövdeye katılmadı`); continue; }
    const t = Number(d.kalinlik);
    if (!(t > 0)) { uyarilar.push(`duvar ${d.id}: kalınlık yok — gövdeye katılmadı`); continue; }

    let dx = b[0] - a[0], dy = b[1] - a[1];
    const uzunluk = Math.hypot(dx, dy);
    if (!(uzunluk > 0)) { uyarilar.push(`duvar ${d.id}: sıfır uzunluk — gövdeye katılmadı`); continue; }
    dx /= uzunluk; dy /= uzunluk;

    // Köşe dolgusu: birleşen uçta kalınlığın yarısı kadar uzat ki union köşeyi kapatsın.
    // Uzatmasız iki dik duvar, dış köşede t/2 × t/2'lik bir kare BOŞLUK bırakır — çentiğin
    // kaynağı tam olarak budur.
    const uzBas = (derece[d.bas] ?? 0) > 1 ? t / 2 : 0;
    const uzSon = (derece[d.son] ?? 0) > 1 ? t / 2 : 0;
    const ax = a[0] - dx * uzBas, ay = a[1] - dy * uzBas;
    const bx = b[0] + dx * uzSon, by = b[1] + dy * uzSon;

    const nx = -dy * (t / 2), ny = dx * (t / 2);
    dikdortgenler.push([[
      [YUVARLA(ax + nx), YUVARLA(ay + ny)],
      [YUVARLA(bx + nx), YUVARLA(by + ny)],
      [YUVARLA(bx - nx), YUVARLA(by - ny)],
      [YUVARLA(ax - nx), YUVARLA(ay - ny)],
    ]]);
  }
  if (!dikdortgenler.length) return { halkalar: [], uyarilar };

  // --- 2b) AÇIKLIKLARI KES ---
  // 🔴 Sultan v10'da gördü (2026-08-08): "kapı boşlukları yok". Duvar gövdesi açıklıklardan
  // KESİLMİYORDU; kapı yayı çiziliyor ama duvar arkasından kesintisiz geçiyordu. Planda
  // duvarın orada kesilmesi ve söve (jamb) çizgilerinin görünmesi gerekir.
  // Model açıklıkları zaten taşıyordu — gövde hesabına dahil edilmemişti.
  const acikliklar = [];
  for (const ac of model.acikliklar ?? []) {
    const d = duvarlar.find((x) => x.id === ac.duvar);
    if (!d) { uyarilar.push(`açıklık ${ac.id}: duvar yok — kesilmedi`); continue; }
    const a = noktalar[d.bas], b = noktalar[d.son];
    if (!a || !b) continue;
    const g = Number(ac.genislik);
    const t = Number(d.kalinlik);
    if (!(g > 0) || !(t > 0)) { uyarilar.push(`açıklık ${ac.id}: genişlik/kalınlık yok — kesilmedi`); continue; }
    const { nokta: merkez, u } = duvarNoktasi(a, b, ac.oran);
    // Dik yönde kalınlığın biraz DIŞINA taşır: tam kalınlıkta kesmek kayan-nokta artığı
    // bırakıp saç-teli kalınlığında duvar parçası üretebilir. Fazlalık boşluğa taşar, zararsız.
    const pay = t * 0.51;
    const n = [-u[1], u[0]];
    const kose = ([s, p]) => [
      YUVARLA(merkez[0] + u[0] * s + n[0] * p),
      YUVARLA(merkez[1] + u[1] * s + n[1] * p),
    ];
    acikliklar.push([[
      kose([-g / 2, -pay]), kose([g / 2, -pay]), kose([g / 2, pay]), kose([-g / 2, pay]),
    ]]);
  }

  // --- 3) Birleştir ---
  // ⚠️ DETERMİNİZM: girdi sırası çıktı sırasını etkileyebilir. Aynı geometri farklı sırayla
  // verildiğinde aynı dosya çıkmalı (bu ders plan-dekor'da ölçülerek öğrenildi) → hem girdiyi
  // hem çıktıyı kanonik sıraya sokuyoruz.
  dikdortgenler.sort(kanonikKarsilastir);
  acikliklar.sort(kanonikKarsilastir);
  let sonuc;
  try {
    sonuc = birlestir(...dikdortgenler);
    // Açıklıklar birleşik gövdeden ÇIKARILIR → kontur açıklıkta kesilir, söveler oluşur.
    if (acikliklar.length) sonuc = cikar(sonuc, ...acikliklar);
  } catch (e) {
    throw new Error(`duvar gövdesi birleştirilemedi: ${e.message}`);
  }

  // FAIL-CLOSED: duvar var ama gövde çıkmadıysa sessizce duvarsız çizim yazma.
  if (!Array.isArray(sonuc) || !sonuc.length) {
    throw new Error(`duvar gövdesi boş döndü (${dikdortgenler.length} duvar girdi) — çizim YAZILMADI`);
  }

  const halkalar = sonuc.map((poligon) => ({
    dis: kanonikHalka(poligon[0]),
    delikler: poligon.slice(1).map(kanonikHalka).sort(kanonikKarsilastir),
  }));
  halkalar.sort((p, q) => kanonikKarsilastir(p.dis, q.dis));

  // Duvar DOLGUSU parçaları — birleşik halkalardan DEĞİL, AYRIK basit bölgelerden çizilir.
  //
  // Sebep 1 (2026-08-07): delikli tek tarama sınırı yazdığımızda AutoCAD delikleri ADA olarak
  // tanımadı ve taramayı bütün daireye yaydı. Referans çizim de ada bayrağı kullanmıyor.
  // → Her dolgu TEK dış sınırlı basit bölge olmalı.
  //
  // Sebep 2 (2026-08-08, Sultan v9'da gördü): parçalar ÜST ÜSTE BİNİYORSA katı dolguda
  // görünmez ama TARAMADA görünür — köşelerde çift tarama, kirli birleşim. Bu yüzden
  // dikdörtgenler doğrudan verilmez; her biri kendinden ÖNCEKİLERİN birleşiminden ÇIKARILIR.
  // Sonuç: birbirine değen ama örtüşmeyen parçalar → tarama köşede de tek katman.
  const parcalar = [];
  const birikmis = [];
  for (const dik of dikdortgenler) {
    let kalan;
    try {
      // Hem önceki parçalar (örtüşme) hem AÇIKLIKLAR (kapı boşluğu) çıkarılır.
      const cikarilacak = [...birikmis, ...acikliklar];
      kalan = cikarilacak.length ? cikar(dik, ...cikarilacak) : [dik];
    } catch (e) {
      uyarilar.push(`dolgu parçası ayrıştırılamadı (${e.message}) — bindirmeli yazıldı`);
      kalan = [dik];
    }
    for (const poligon of kalan ?? []) {
      if (!poligon?.length) continue;
      // Delikli parça ada anlambilimini geri getirir — bu tam olarak elediğimiz yol.
      // Duvar dikdörtgenlerinde olmaması gerekir; olursa SESSİZ geçmesin.
      if (poligon.length > 1) {
        uyarilar.push('dolgu parçasında delik oluştu — ada yolu elenmişti, bu parça ATLANDI');
        continue;
      }
      parcalar.push(kanonikHalka(poligon[0]));
    }
    birikmis.push(dik);
  }
  parcalar.sort(kanonikKarsilastir);

  return { halkalar, dikdortgenler: parcalar, uyarilar };
}

// Halkayı kanonik biçime sok: kapanış tepesini at, en küçük tepeden başlat.
// polygon-clipping halkayı kapatarak döndürür (ilk == son); DWG kapalı polyline'da
// tekrar eden tepe istemez.
function kanonikHalka(halka) {
  const h = halka.slice();
  if (h.length > 1) {
    const [x0, y0] = h[0], [xn, yn] = h[h.length - 1];
    if (x0 === xn && y0 === yn) h.pop();
  }
  if (h.length < 3) return h;
  let en = 0;
  for (let i = 1; i < h.length; i++) {
    if (h[i][0] < h[en][0] || (h[i][0] === h[en][0] && h[i][1] < h[en][1])) en = i;
  }
  return h.slice(en).concat(h.slice(0, en));
}

function kanonikKarsilastir(a, b) {
  const ha = Array.isArray(a[0]?.[0]) ? a[0] : a;
  const hb = Array.isArray(b[0]?.[0]) ? b[0] : b;
  for (let i = 0; i < Math.min(ha.length, hb.length); i++) {
    if (ha[i][0] !== hb[i][0]) return ha[i][0] - hb[i][0];
    if (ha[i][1] !== hb[i][1]) return ha[i][1] - hb[i][1];
  }
  return ha.length - hb.length;
}
