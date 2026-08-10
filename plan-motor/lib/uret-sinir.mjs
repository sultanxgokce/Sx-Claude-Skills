// FAZ B2 · REKTİLİNEER SINIR AYRIŞTIRMA — L/U biçimli sınırı dikdörtgenlere böler.
// BAĞIMLILIKSIZ (MEDDAH kararı: FAZ B'de yeni npm paketi yok). Klasik dikey süpürme:
// köşe x'leri dilim sınırıdır; her dilimin ortasında yatay kenarları toplayıp çift-çift
// eşleyince (even-odd) poligonun İÇİNDE kalan y aralıkları çıkar.
//
// Niçin polygon-clipping gerekmiyor: burada yalnız EKSEN-HİZALI (rektilineer) poligon var.
// Genel/eğik/yaylı poligon kütüphane ister — o zaten kapsam dışımız (eğik duvar desteklenmiyor).
// Bu dosya 130 satır; kütüphane 60 KB gelirdi ve emsal maliyeti (DEVIR-CEVAP S2) doğardı.
import { alanCm2 } from './geometri.mjs';

const TOL = 0.5;

// Poligon eksen-hizalı, kapalı, dejenere olmayan mı? Değilse SEBEBİ döner (sessiz kabul yok).
export function rektilineerDenetle(poligon) {
  if (!Array.isArray(poligon) || poligon.length < 4) return 'en az 4 köşe gerekli';
  if (poligon.length % 2 !== 0) return `köşe sayısı ${poligon.length} — rektilineer poligonda köşe sayısı ÇİFT olmalı`;
  if (!poligon.every((p) => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite))) return 'her köşe [x,y] sonlu sayı çifti olmalı';
  const n = poligon.length;
  for (let i = 0; i < n; i++) {
    const A = poligon[i], B = poligon[(i + 1) % n];
    const dx = Math.abs(A[0] - B[0]), dy = Math.abs(A[1] - B[1]);
    if (dx < TOL && dy < TOL) return `köşe ${i} ile ${(i + 1) % n} çakışık — sıfır uzunluklu kenar`;
    if (dx > TOL && dy > TOL) return `kenar ${i}→${(i + 1) % n} eksen-hizalı DEĞİL (eğik kenar kapsam dışı)`;
    // ardışık iki kenar aynı doğrultuda olmamalı (gereksiz köşe → ayrıştırma bozulmaz ama şema kirlenir)
    const C = poligon[(i + 2) % n];
    const yatay1 = dy < TOL, yatay2 = Math.abs(B[1] - C[1]) < TOL;
    if (yatay1 === yatay2) return `köşe ${(i + 1) % n} gereksiz — ardışık iki kenar aynı doğrultuda`;
  }
  const kume = new Set(poligon.map((p) => `${p[0]},${p[1]}`));
  if (kume.size !== n) return 'tekrar eden köşe var — poligon basit değil';
  if (alanCm2(poligon) < 1) return 'alan sıfıra yakın — dejenere poligon';
  return null;
}

// Dikey süpürme ile dikdörtgenlere ayır. Döner: [{x0,y0,x1,y1}]
export function dikeyAyristir(poligon) {
  const xs = [...new Set(poligon.map((p) => p[0]))].sort((a, b) => a - b);
  const yataylar = [];
  for (let i = 0; i < poligon.length; i++) {
    const A = poligon[i], B = poligon[(i + 1) % poligon.length];
    if (Math.abs(A[1] - B[1]) < TOL) yataylar.push({ y: (A[1] + B[1]) / 2, x0: Math.min(A[0], B[0]), x1: Math.max(A[0], B[0]) });
  }
  const parcalar = [];
  for (let i = 0; i + 1 < xs.length; i++) {
    const x0 = xs[i], x1 = xs[i + 1];
    if (x1 - x0 < TOL) continue;
    const xm = (x0 + x1) / 2;
    // Bu dilimi kesen yatay kenarların y'leri — sıralı, çift-çift içeriyi verir (even-odd).
    const ysHam = yataylar.filter((h) => h.x0 < xm && h.x1 > xm).map((h) => h.y).sort((a, b) => a - b);
    if (ysHam.length % 2 !== 0) continue; // tek sayı = tutarsız poligon; dilimi atla (denetim zaten yakalar)
    for (let k = 0; k + 1 < ysHam.length; k += 2) {
      const y0 = ysHam[k], y1 = ysHam[k + 1];
      if (y1 - y0 < TOL) continue;
      parcalar.push({ x0, y0, x1, y1 });
    }
  }
  return yataybirlestir(parcalar);
}

// Yan yana duran ve y aralığı AYNI olan dilimleri birleştir — parça sayısı azalır,
// oda-parça ataması küçülür (L için 2, U için 3 parça kalır).
function yataybirlestir(parcalar) {
  const kalan = [...parcalar].sort((a, b) => a.y0 - b.y0 || a.x0 - b.x0);
  const sonuc = [];
  while (kalan.length) {
    const p = kalan.shift();
    for (;;) {
      const i = kalan.findIndex((q) => Math.abs(q.y0 - p.y0) < TOL && Math.abs(q.y1 - p.y1) < TOL && Math.abs(q.x0 - p.x1) < TOL);
      if (i < 0) break;
      p.x1 = kalan[i].x1;
      kalan.splice(i, 1);
    }
    sonuc.push(p);
  }
  return sonuc.sort((a, b) => a.x0 - b.x0 || a.y0 - b.y0);
}

// İki parça duvar paylaşıyor mu (oda atamasının bağlanabilirliğini önceden elemek için).
export function parcalarBitisik(a, b) {
  const xOrt = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0);
  const yOrt = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0);
  return (Math.abs(a.x1 - b.x0) < TOL || Math.abs(b.x1 - a.x0) < TOL) && yOrt > TOL
    ? true
    : (Math.abs(a.y1 - b.y0) < TOL || Math.abs(b.y1 - a.y0) < TOL) && xOrt > TOL;
}

// Parçalar tek bir bağlı küme mi? Değilse yerleşim üretmenin anlamı yok (erişim kurulamaz).
export function parcalarBagliMi(parcalar) {
  if (parcalar.length <= 1) return true;
  const gorulen = new Set([0]), kuyruk = [0];
  while (kuyruk.length) {
    const u = kuyruk.shift();
    for (let i = 0; i < parcalar.length; i++) {
      if (gorulen.has(i) || !parcalarBitisik(parcalar[u], parcalar[i])) continue;
      gorulen.add(i); kuyruk.push(i);
    }
  }
  return gorulen.size === parcalar.length;
}
