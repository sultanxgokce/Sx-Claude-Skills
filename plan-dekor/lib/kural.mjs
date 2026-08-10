// Mobilya kural motoru. Eşikler MOTORDA DEĞİL, kural-seti verisinde yaşar (plan-motor doktrini).
// Bu dosya kural-setini OKUR; yazmaz. (PERGEL doktrini: üreten sınavı değiştiremez.)
import { readFileSync } from 'fs';
import { dikdortgenCakisir, dikdortgenIcinde, sektorDikdortgenKesisir, temizAlanlaBuyut } from './geo.mjs';

const OLCUTLER = new Set([
  'mobilya_cakismasi', 'oda_disina_tasma', 'kapi_yayi_ihlali',
  'aciklik_onu_ihlali', 'yerlesim_tipi_ihlali',
]);

export function kuralSetiYukle(yol) {
  let ham;
  try { ham = JSON.parse(readFileSync(yol, 'utf8')); }
  catch (e) { throw new Error(`kural-seti okunamadı (${yol}): ${e.message}`); }

  if (!Array.isArray(ham.kurallar)) throw new Error('kural-seti: "kurallar" dizisi yok');
  const gorulen = new Set();
  for (const k of ham.kurallar) {
    // plan-motor lib/denetle.mjs:36 ile aynı disiplin — kaynaksız kural kabul edilmez.
    if (!k.id) throw new Error('kural-seti: id alanı olmayan kural');
    if (gorulen.has(k.id)) throw new Error(`kural-seti: id tekrarı — ${k.id}`);
    gorulen.add(k.id);
    if (!k.kaynak) throw new Error(`kural-seti: ${k.id} kaynaksız — K01 gereği reddedildi`);
    if (!OLCUTLER.has(k.olcut)) throw new Error(`kural-seti: ${k.id} bilinmeyen ölçüt "${k.olcut}"`);
    if (!['hata', 'uyari'].includes(k.siddet)) throw new Error(`kural-seti: ${k.id} geçersiz şiddet`);
  }
  return ham;
}

// Bir yerleşim adayını kural setine karşı sına.
// baglam: { odaPoligon, duvarlar:[{a,b,id}], acikliklar:[{tip,merkez,u,genislik,aci_yonu,n}] }
export function ihlalleriBul(yerlesimler, baglam, kuralSeti) {
  const ihlaller = [];
  const ekle = (kural, detay) => ihlaller.push({ kural: kural.id, siddet: kural.siddet, detay });

  for (const kural of kuralSeti.kurallar) {
    switch (kural.olcut) {
      case 'mobilya_cakismasi':
        for (let i = 0; i < yerlesimler.length; i++) {
          for (let j = i + 1; j < yerlesimler.length; j++) {
            if (dikdortgenCakisir(yerlesimler[i].kutu, yerlesimler[j].kutu)) {
              ekle(kural, `${yerlesimler[i].mobilya} ↔ ${yerlesimler[j].mobilya}`);
            }
          }
        }
        break;

      case 'oda_disina_tasma':
        for (const y of yerlesimler) {
          if (!dikdortgenIcinde(y.kutu, baglam.odaPoligon)) ekle(kural, `${y.mobilya} oda dışına taşıyor`);
        }
        break;

      case 'kapi_yayi_ihlali':
        for (const a of baglam.acikliklar) {
          if (a.tip !== 'kapi') continue;
          const { merkez, u, n, genislik, aci_yonu } = a;
          // menteşe = açıklığın bir ucu; kanat genislik kadar, duvardan aci_yonu tarafına 90° süpürür
          const mentese = [merkez[0] - u[0] * genislik / 2, merkez[1] - u[1] * genislik / 2];
          const yon = aci_yonu === -1 ? -1 : 1;
          const a0 = Math.atan2(u[1], u[0]);
          const a1 = Math.atan2(n[1] * yon, n[0] * yon);
          // a0'dan a1'e 90°lik sektör (yön işaretine göre sırala)
          let bas = a0, son = a1;
          let fark = son - bas;
          while (fark <= -Math.PI) fark += Math.PI * 2;
          while (fark > Math.PI) fark -= Math.PI * 2;
          if (fark < 0) { bas = a1; }
          for (const y of yerlesimler) {
            if (sektorDikdortgenKesisir(mentese, genislik, bas, bas + Math.abs(fark), y.kutu)) {
              ekle(kural, `${y.mobilya} kapı kanadının süpürme alanında`);
            }
          }
        }
        break;

      case 'aciklik_onu_ihlali': {
        // ⚠ Bant derinliği MOTORDA SABİT DEĞİL — kural verisinden gelir (plan-motor doktrini:
        // "eşikler motor kodunda YAŞAMAZ"). Kuralda yoksa kural eksiktir, sessizce varsayılmaz.
        const BANT = kural.bant_cm;
        if (!(BANT > 0)) throw new Error(`kural-seti: ${kural.id} "bant_cm" taşımıyor — eşik motorda uydurulamaz`);
        for (const a of baglam.acikliklar) {
          if (a.tip === 'pencere') continue;
          const { merkez, u, n, genislik } = a;
          // açıklığın önündeki bandı iki tarafa da kur (hangi taraf oda ise orası sayılır)
          for (const isaret of [1, -1]) {
            const koseler = [
              [merkez[0] - u[0] * genislik / 2, merkez[1] - u[1] * genislik / 2],
              [merkez[0] + u[0] * genislik / 2, merkez[1] + u[1] * genislik / 2],
            ];
            const bantKutu = kutuyaCevir([
              koseler[0], koseler[1],
              [koseler[1][0] + n[0] * BANT * isaret, koseler[1][1] + n[1] * BANT * isaret],
              [koseler[0][0] + n[0] * BANT * isaret, koseler[0][1] + n[1] * BANT * isaret],
            ]);
            for (const y of yerlesimler) {
              if (dikdortgenCakisir(y.kutu, bantKutu, 2)) {
                ekle(kural, `${y.mobilya} ${a.tip} açıklığının önünü kapatıyor`);
              }
            }
          }
        }
        break;
      }

      case 'yerlesim_tipi_ihlali':
        for (const y of yerlesimler) {
          if (y.yerlesimTipi === 'serbest') continue;
          const gereken = y.yerlesimTipi === 'kose' ? 2 : 1;
          if ((y.dayandigiDuvarSayisi ?? 0) < gereken) {
            ekle(kural, `${y.mobilya} '${y.yerlesimTipi}' olmasına rağmen ${y.dayandigiDuvarSayisi ?? 0} duvara dayanıyor`);
          }
        }
        break;
    }
  }
  return ihlaller;
}

function kutuyaCevir(koseler) {
  const xs = koseler.map((k) => k[0]), ys = koseler.map((k) => k[1]);
  const x = Math.min(...xs), y = Math.min(...ys);
  return { x, y, g: Math.max(...xs) - x, d: Math.max(...ys) - y };
}

// kaynak_bekleyen kalemler: ELEME YAPMAZ, yalnız skor cezası üretir.
export function konforCezasi(yerlesimler, baglam, kuralSeti) {
  const bekleyen = kuralSeti.kaynak_bekleyen ?? [];
  const eslesen = (id) => bekleyen.find((b) => b.id === id);
  let ceza = 0;
  const notlar = [];

  const sirk = eslesen('MB-K-01-sirkulasyon');
  if (sirk?.onerilen_cm) {
    for (let i = 0; i < yerlesimler.length; i++) {
      for (let j = i + 1; j < yerlesimler.length; j++) {
        const bosluk = kutuArasiBosluk(yerlesimler[i].kutu, yerlesimler[j].kutu);
        if (bosluk !== null && bosluk < sirk.onerilen_cm) {
          ceza += (sirk.onerilen_cm - bosluk) / sirk.onerilen_cm;
          notlar.push(`sirkülasyon dar (${Math.round(bosluk)} cm < ${sirk.onerilen_cm}): ${yerlesimler[i].mobilya} ↔ ${yerlesimler[j].mobilya}`);
        }
      }
    }
  }

  const pencere = eslesen('MB-K-04-pencere-onu');
  if (pencere?.bant_cm > 0) {
    const PB = pencere.bant_cm;   // veriden — motorda sabit sayı yok
    for (const y of yerlesimler) {
      if (!y.pencereOnuYasak) continue;
      for (const a of baglam.acikliklar) {
        if (a.tip !== 'pencere') continue;
        const { merkez, u, n, genislik } = a;
        for (const isaret of [1, -1]) {
          const bant = kutuyaCevir([
            [merkez[0] - u[0] * genislik / 2, merkez[1] - u[1] * genislik / 2],
            [merkez[0] + u[0] * genislik / 2, merkez[1] + u[1] * genislik / 2],
            [merkez[0] + u[0] * genislik / 2 + n[0] * PB * isaret, merkez[1] + u[1] * genislik / 2 + n[1] * PB * isaret],
            [merkez[0] - u[0] * genislik / 2 + n[0] * PB * isaret, merkez[1] - u[1] * genislik / 2 + n[1] * PB * isaret],
          ]);
          if (dikdortgenCakisir(y.kutu, bant, 2)) {
            ceza += 0.5;
            notlar.push(`${y.mobilya} pencere önünü kapatıyor`);
          }
        }
      }
    }
  }

  // Katalogdaki `temiz_alan_cm` payları (yatağın yanı, dolabın önü, klozetin önü…).
  // ⚠ Bunlar SERT KURAL DEĞİL: sayıları katalog yazarının beyanıdır, dış kaynağa bağlanmadı
  // (layiha L02). Bu yüzden ELEME yapmazlar — ihlal skoru düşürür, adayı öldürmez.
  // (v0.2.0'a kadar bu 72 sayı HİÇ değerlendirilmiyordu: `temizAlanlaBuyut` tanımlıydı ama
  //  hiçbir yerden çağrılmıyordu → katalogda ölü veri duruyordu.)
  for (let i = 0; i < yerlesimler.length; i++) {
    const y = yerlesimler[i];
    const temiz = y.temizAlan;
    if (!temiz || Object.values(temiz).every((v) => !v)) continue;
    const genisletilmis = temizAlanlaBuyut(y.kutu, temiz, y.yon);
    for (let j = 0; j < yerlesimler.length; j++) {
      if (i === j) continue;
      if (dikdortgenCakisir(genisletilmis, yerlesimler[j].kutu, 2)) {
        ceza += 0.4;
        notlar.push(`${y.mobilya} temiz-alan payına ${yerlesimler[j].mobilya} giriyor`);
      }
    }
  }

  return { ceza, notlar };
}

function kutuArasiBosluk(a, b) {
  // Yalnız eksende ÖRTÜŞEN çiftler için geçit boşluğu anlamlıdır
  const xOrtusme = Math.min(a.x + a.g, b.x + b.g) - Math.max(a.x, b.x);
  const yOrtusme = Math.min(a.y + a.d, b.y + b.d) - Math.max(a.y, b.y);
  if (xOrtusme > 0) return Math.max(a.y, b.y) - Math.min(a.y + a.d, b.y + b.d);
  if (yOrtusme > 0) return Math.max(a.x, b.x) - Math.min(a.x + a.g, b.x + b.g);
  return null;
}
