// Deterministik mobilya yerleştirici. Math.random YOKTUR — aynı girdi → aynı çıktı.
// Desen: plan-motor lib/uret-yerlesim.mjs + uret-puan.mjs (enumerasyon → sına → puanla → tekilleştir).
// Bu dosya kural-setini OKUR, DEĞİŞTİREMEZ (PERGEL doktrini).
import { readFileSync } from 'fs';
import { alanM2, bbox, duvarNoktasi, uzunluk } from './geo.mjs';
import { ihlalleriBul, konforCezasi } from './kural.mjs';

// Enumerasyon tavanları. Tam ızgara taramak kombinatorik patlamaya yol açar (ölçüldü: 450×400 cm
// odada 4 yön × 10 cm ızgara = 7200 aday/mobilya → çift döngüde >2 dk). Bu yüzden yerleşim tipine
// göre AYRIŞTIRILMIŞ enumerasyon: duvara dayalı mobilya yalnız duvar boyunca kayar (~1B problem),
// serbest mobilya kaba ızgarada taranır. Mimari gerçeğe de bu daha yakındır.
export const TAVAN = {
  duvarAdimCm: 10,      // duvar boyunca kayma adımı
  serbestAdimCm: 30,    // serbest mobilyanın ızgara adımı
  kararKovasi: 12,      // ilk mobilyanın (yön × ana-duvar) karar kovası tavanı
  toplamAday: 20000,
};

const KAYNAK_KADEMELERI = new Set(['beyan', 'olculdu', 'standart']);

export function katalogYukle(mobilyaYolu, programYolu, kuralSeti) {
  const m = JSON.parse(readFileSync(mobilyaYolu, 'utf8'));
  const p = JSON.parse(readFileSync(programYolu, 'utf8'));

  // KATALOG KAYNAK KAPISI — kural-setindeki kaynak kapısının katalog karşılığı.
  // Katalog masum bir veri dosyası gibi durur ama SINAVIN GİZLİ PARÇASIDIR: yerleştirici
  // kendi kataloğunu düzenleyebiliyorsa, sığmayan yatağı 160'tan 140'a çeker ve "sığdı" der —
  // sınavı kimse fark etmeden değiştirmiş olur. Kaynak alanı bu hileyi SESSİZ olmaktan çıkarır:
  // ölçüyü değiştirenin kaynağı da değiştirmesi gerekir, o da git diff'inde görünür.
  const gorulen = new Set();
  for (const x of m.mobilyalar) {
    if (!x.id) throw new Error('katalog: id alanı olmayan kalem');
    if (gorulen.has(x.id)) throw new Error(`katalog: id tekrarı — ${x.id}`);
    gorulen.add(x.id);
    if (!Array.isArray(x.boyut_cm) || x.boyut_cm.length !== 2 || !x.boyut_cm.every((n) => n > 0)) {
      throw new Error(`katalog: ${x.id} geçersiz boyut_cm`);
    }
    if (!x.kaynak?.kademe) throw new Error(`katalog: ${x.id} kaynak beyanı taşımıyor — ölçü kaynaksız kabul edilmez`);
    if (!KAYNAK_KADEMELERI.has(x.kaynak.kademe)) {
      throw new Error(`katalog: ${x.id} bilinmeyen kaynak kademesi "${x.kaynak.kademe}" (${[...KAYNAK_KADEMELERI].join('|')})`);
    }
    if (!x.kaynak.metin?.trim()) throw new Error(`katalog: ${x.id} kaynak metni boş`);
  }

  // ASGARİ BOYUT BANDI — kaynak alanının tek başına kapatamadığı deliği kapatır.
  // Kaynak serbest METİNDİR: ölçüyü kırpan yanına "kompakt model" yazıp geçebilir.
  // Bant SAYIDIR ve üreticinin dokunamadığı kural-setinde durur → kırpma mekanik olarak yakalanır.
  const bant = kuralSeti?.katalog_bandi?.asgari_boyut_cm;
  if (bant) {
    for (const x of m.mobilyalar) {
      const asgari = bant[x.id];
      if (!asgari) continue;
      const [g, d] = x.boyut_cm, [ag, ad] = asgari;
      if (g < ag || d < ad) {
        throw new Error(
          `katalog: ${x.id} ölçüsü asgari bandın ALTINDA — ${g}×${d} < ${ag}×${ad}. ` +
          'Sığdırmak için ölçü kırpılamaz; bant kural-setindedir ve üretici tarafından değiştirilemez.'
        );
      }
    }
  }

  const indeks = new Map(m.mobilyalar.map((x) => [x.id, x]));
  return { katalog: m, program: p, indeks };
}

// Modelden bir odanın yerleşim bağlamını çıkar (poligon, duvarlar, açıklıklar)
export function odaBaglami(model, oda) {
  const noktalar = model.noktalar;
  const poligon = oda.dongu.map((nid) => noktalar[nid]);
  const koseKumesi = new Set(oda.dongu);

  // Odanın döngüsüne ait duvarlar: iki ucu da bu odanın köşesi olan duvarlar
  const duvarlar = (model.duvarlar ?? []).filter((d) => koseKumesi.has(d.bas) && koseKumesi.has(d.son));

  const acikliklar = [];
  for (const a of model.acikliklar ?? []) {
    const d = duvarlar.find((x) => x.id === a.duvar);
    if (!d) continue;
    const A = noktalar[d.bas], B = noktalar[d.son];
    const { nokta: merkez, u } = duvarNoktasi(A, B, a.oran);
    acikliklar.push({
      id: a.id, tip: a.tip, merkez, u, n: [-u[1], u[0]],
      genislik: a.genislik, aci_yonu: a.aci_yonu ?? 1,
    });
  }

  return { odaPoligon: poligon, duvarlar, acikliklar, model };
}

// Odanın eksen-hizalı iç sınırı (yerleştirme ızgarasının çerçevesi)
function odaKutusu(poligon) {
  const b = bbox(poligon);
  return { x: b.minX, y: b.minY, g: b.w, d: b.h };
}

// Bir mobilya için aday konumları üret. Yerleşim tipine göre AYRIŞTIRILMIŞ enumerasyon:
//   duvar-dayali/duvar-ortali → yalnız duvar boyunca kayma (1B)
//   kose                      → yalnız oda köşeleri (4 nokta × 4 yön)
//   serbest                   → kaba ızgara (2B ama iri adım)
// Yön 0=+x, 1=+y, 2=-x, 3=-y — mobilyanın ÖN yüzünün baktığı global yön. Eğik yerleşim kapsam dışı.
function adaylariUret(mob, baglam) {
  const [G, D] = mob.boyut_cm;
  const noktalar = baglam.model.noktalar;
  const adaylar = [];

  const kutuKur = (x, y, yon) => {
    const g = (yon % 2 === 0) ? D : G;
    const d = (yon % 2 === 0) ? G : D;
    return { x: +x.toFixed(2), y: +y.toFixed(2), g, d };
  };
  const ekle = (kutu, yon) => {
    adaylar.push({
      mobilya: mob.id, ad: mob.ad, sembol: mob.sembol,
      kutu, yon,
      yerlesimTipi: mob.yerlesim,
      pencereOnuYasak: !!mob.pencere_onu_yasak,
      temizAlan: mob.temiz_alan_cm ?? {},
      dayandigiDuvarSayisi: duvaraDayanma(kutu, baglam.duvarlar, noktalar),
    });
  };

  if (mob.yerlesim === 'serbest') {
    const oda = odaKutusu(baglam.odaPoligon);
    const adim = TAVAN.serbestAdimCm;
    for (let yon = 0; yon < 4; yon++) {
      const g = (yon % 2 === 0) ? D : G, d = (yon % 2 === 0) ? G : D;
      for (let x = oda.x; x <= oda.x + oda.g - g + 1e-9; x += adim) {
        for (let y = oda.y; y <= oda.y + oda.d - d + 1e-9; y += adim) ekle(kutuKur(x, y, yon), yon);
      }
    }
    return adaylar;
  }

  // duvar-dayali / duvar-ortali / kose → duvar boyunca
  const adim = TAVAN.duvarAdimCm;
  for (const duvar of baglam.duvarlar) {
    const A = noktalar[duvar.bas], B = noktalar[duvar.son];
    const yatay = Math.abs(A[1] - B[1]) < 1e-6;
    const dikey = Math.abs(A[0] - B[0]) < 1e-6;
    if (!yatay && !dikey) continue; // eğik duvar kapsam dışı

    // Duvarın hangi tarafı oda? Duvar ekseninden 1 cm içeri bakıp test et.
    const orta = [(A[0] + B[0]) / 2, (A[1] + B[1]) / 2];
    const n = yatay ? [0, 1] : [1, 0];
    const icTaraf = noktaIcindeGuvenli([orta[0] + n[0] * 2, orta[1] + n[1] * 2], baglam.odaPoligon) ? 1 : -1;

    // Mobilyanın ÖN yüzü odanın içine bakar → yon, duvarın iç normalinin yönüdür
    const yon = yatay ? (icTaraf === 1 ? 1 : 3) : (icTaraf === 1 ? 0 : 2);
    const g = (yon % 2 === 0) ? D : G;
    const d = (yon % 2 === 0) ? G : D;

    // ⚠ Oda döngüsü duvar EKSENİNDEN geçer; duvar gövdesinin yarısı odanın "içinde" görünür.
    // Mobilyayı eksene yaslamak, duvarın içine yerleştirmek olurdu — hem çizimde duvar altında
    // kalır hem de "sığdı" iddiası şişer. Bu yüzden iç yüze (eksen + kalınlık/2) yaslanır.
    const pay = (duvar.kalinlik ?? 0) / 2;

    if (yatay) {
      const duvarY = A[1] + pay * icTaraf;
      const y = icTaraf === 1 ? duvarY : duvarY - d;
      const x0 = Math.min(A[0], B[0]), x1 = Math.max(A[0], B[0]);
      for (let x = x0; x <= x1 - g + 1e-9; x += adim) ekle(kutuKur(x, y, yon), yon);
      if (x1 - x0 >= g) ekle(kutuKur(x1 - g, y, yon), yon); // duvar sonuna hizalı
    } else {
      const duvarX = A[0] + pay * icTaraf;
      const x = icTaraf === 1 ? duvarX : duvarX - g;
      const y0 = Math.min(A[1], B[1]), y1 = Math.max(A[1], B[1]);
      for (let y = y0; y <= y1 - d + 1e-9; y += adim) ekle(kutuKur(x, y, yon), yon);
      if (y1 - y0 >= d) ekle(kutuKur(x, y1 - d, yon), yon);
    }
  }
  return kanonikSirala(adaylar);
}

// 🔴 DETERMİNİZM ÇIPASI (B-012). Adaylar duvar dizisinin SIRASINA göre üretilir; skor eşitliğinde
// "ilk gelen kazanır" kuralı, girdi dizilerinin sırası değişince BAŞKA yerleşim seçtiriyordu —
// geometrik olarak birebir aynı daire, `duvarlar` ters çevrilince küvet başka duvara geçiyordu
// (ölçüldü). Yani "aynı girdi → aynı sha256" iddiası yalnız BAYT-aynı girdi için doğruydu,
// ANLAM-aynı girdi için değil. Kanonik sıralama eşitliği girdi-sırasından bağımsız çözer.
function kanonikSirala(adaylar) {
  return adaylar.sort((a, b) =>
    a.kutu.x - b.kutu.x ||
    a.kutu.y - b.kutu.y ||
    a.kutu.g - b.kutu.g ||
    a.kutu.d - b.kutu.d ||
    a.yon - b.yon ||
    String(a.mobilya).localeCompare(String(b.mobilya))
  );
}

function noktaIcindeGuvenli(p, poligon) {
  let ic = false;
  for (let i = 0, j = poligon.length - 1; i < poligon.length; j = i++) {
    const [xi, yi] = poligon[i], [xj, yj] = poligon[j];
    if ((yi > p[1]) !== (yj > p[1]) && p[0] < ((xj - xi) * (p[1] - yi)) / (yj - yi) + xi) ic = !ic;
  }
  return ic;
}

// Kutunun kaç duvara yaslandığı (tolerans 6 cm)
function duvaraDayanma(kutu, duvarlar, noktalar) {
  const TOL = 6;
  let sayi = 0;
  for (const d of duvarlar) {
    const A = noktalar[d.bas], B = noktalar[d.son];
    const yatay = Math.abs(A[1] - B[1]) < 1e-6;
    if (yatay) {
      const duvarY = A[1];
      const x0 = Math.min(A[0], B[0]), x1 = Math.max(A[0], B[0]);
      const ortusme = Math.min(kutu.x + kutu.g, x1) - Math.max(kutu.x, x0);
      if (ortusme > 10 && (Math.abs(kutu.y - duvarY) < TOL || Math.abs(kutu.y + kutu.d - duvarY) < TOL)) sayi++;
    } else if (Math.abs(A[0] - B[0]) < 1e-6) {
      const duvarX = A[0];
      const y0 = Math.min(A[1], B[1]), y1 = Math.max(A[1], B[1]);
      const ortusme = Math.min(kutu.y + kutu.d, y1) - Math.max(kutu.y, y0);
      if (ortusme > 10 && (Math.abs(kutu.x - duvarX) < TOL || Math.abs(kutu.x + kutu.g - duvarX) < TOL)) sayi++;
    }
  }
  return sayi;
}

// Bir odayı döşe. Açgözlü + geri-izlemeli: zorunlular önce, sığmazsa ODA BAŞARISIZ (dürüst).
export function odayiDose(model, oda, { indeks, program }, kuralSeti, { adet = 3 } = {}) {
  const baglam = odaBaglami(model, oda);
  const tip = oda.tip ?? 'diger';
  const m2 = alanM2(baglam.odaPoligon);

  let prog = program.programlar[tip];
  if (!prog) return { oda: oda.id, durum: 'program-yok', adaylar: [], not: `oda tipi '${tip}' için program tanımlı değil` };

  // küçük oda varyantı (ör. dar yatak odasına tek kişilik yatak)
  let zorunlu = prog.zorunlu;
  if (prog.kucuk_oda_m2 && m2 < prog.kucuk_oda_m2 && prog.kucuk_oda_zorunlu) {
    zorunlu = prog.kucuk_oda_zorunlu;
  }

  const zorunluListe = genislet(zorunlu, indeks);
  const opsiyonelListe = genislet(prog.opsiyonel ?? [], indeks)
    .sort((a, b) => (b._oncelik ?? 0) - (a._oncelik ?? 0));

  if (zorunluListe.length === 0 && opsiyonelListe.length === 0) {
    return { oda: oda.id, durum: 'bos-program', adaylar: [{ yerlesimler: [], skor: 0, karar: 'mobilyasız' }] };
  }

  // Zorunluların farklı "ana duvar" kararlarını ayrı ADAY sayarız (plan-motor: bir seçenek = bir karar kombinasyonu)
  const sonuclar = [];
  const gorulenKombinasyon = new Set();
  let toplamDenenen = 0;

  const ilkMob = zorunluListe[0] ?? opsiyonelListe[0];
  const ilkHamAdaylar = ilkMob ? adaylariUret(ilkMob, baglam) : [];

  // KARAR KOVALARI: pahalı iç döngüye girmeden önce, ilk mobilyanın adaylarını
  // (yön × ana-duvar) kombinasyonuna göre kovala ve her kovadan YALNIZ en iyisini al.
  // Aynı kovadaki 40 pozisyon aynı mimari kararın varyasyonudur — plan-motor'un
  // "bir seçenek = bir karar kombinasyonu" ilkesi (uret, v1.3).
  const kovalar = new Map();
  for (const a of ilkHamAdaylar) {
    toplamDenenen++;
    if (toplamDenenen > TAVAN.toplamAday) break;
    const ihlal0 = ihlalleriBul([a], baglam, kuralSeti).filter((i) => i.siddet === 'hata');
    if (ihlal0.length) continue;
    const anahtar = `${a.mobilya}|${a.yon}|${anaDuvarEtiketi(a, baglam)}`;
    const { ceza } = konforCezasi([a], baglam, kuralSeti);
    const skor = (a.dayandigiDuvarSayisi ?? 0) * 3 - ceza * 5 - (a.kutu.x + a.kutu.y) * 1e-5;
    const mevcutKova = kovalar.get(anahtar);
    if (!mevcutKova || skor > mevcutKova.skor) kovalar.set(anahtar, { aday: a, skor, anahtar });
  }

  const ilkAdaylar = [...kovalar.values()]
    .sort((a, b) => b.skor - a.skor || a.anahtar.localeCompare(b.anahtar))
    .slice(0, TAVAN.kararKovasi)
    .map((k) => k.aday);

  for (const ilk of ilkAdaylar) {
    const kararAnahtari = `${ilk.mobilya}|${ilk.yon}|${anaDuvarEtiketi(ilk, baglam)}`;
    if (gorulenKombinasyon.has(kararAnahtari)) continue;

    const yerlesimler = [ilk];
    let eksikZorunlu = null;

    // `ilk` hangi listeden geldiyse ORADAN düşülür — yoksa aynı mobilya iki kez konur.
    const kalanZorunlu = zorunluListe.length ? zorunluListe.slice(1) : [];
    const kalanOpsiyonel = zorunluListe.length ? opsiyonelListe : opsiyonelListe.slice(1);

    for (const mob of kalanZorunlu) {
      const yer = enIyiKonum(mob, baglam, yerlesimler, kuralSeti);
      if (!yer) { eksikZorunlu = mob.id; break; }
      yerlesimler.push(yer);
    }
    toplamDenenen++;
    if (eksikZorunlu) continue;

    // opsiyoneller — sığdıkça
    for (const mob of kalanOpsiyonel) {
      const yer = enIyiKonum(mob, baglam, yerlesimler, kuralSeti);
      if (yer) yerlesimler.push(yer);
    }

    const { ceza, notlar } = konforCezasi(yerlesimler, baglam, kuralSeti);
    const skor = yerlesimler.length * 10 - ceza * 5;
    gorulenKombinasyon.add(kararAnahtari);
    sonuclar.push({ yerlesimler, skor: +skor.toFixed(2), karar: kararAnahtari, konfor_notlari: notlar });
  }

  if (sonuclar.length === 0) {
    return {
      oda: oda.id, durum: 'sigmadi', adaylar: [],
      not: `zorunlu program (${zorunluListe.map((z) => z.id).join(', ')}) bu odaya (${m2.toFixed(1)} m²) yerleşmedi`,
      denenen: toplamDenenen,
    };
  }

  sonuclar.sort((a, b) => b.skor - a.skor || a.karar.localeCompare(b.karar));
  return { oda: oda.id, durum: 'ok', m2: +m2.toFixed(1), adaylar: sonuclar.slice(0, adet), denenen: toplamDenenen };
}

function genislet(liste, indeks) {
  const cikti = [];
  for (const kalem of liste) {
    const mob = indeks.get(kalem.mobilya);
    if (!mob) throw new Error(`program: katalogda olmayan mobilya "${kalem.mobilya}"`);
    for (let i = 0; i < (kalem.adet ?? 1); i++) cikti.push({ ...mob, _oncelik: kalem.oncelik ?? 0, _kopya: i });
  }
  return cikti;
}

// Verili yerleşimlerin üstüne bu mobilya için en iyi (deterministik) konumu bul.
// `eslenik` tanımlıysa (komodin↔yatak, sehpa↔kanepe) çapa mobilyaya YAKINLIK zorunlu tercihtir:
// önce yalnız çapanın yanındaki adaylar denenir; hiçbiri geçmezse serbest aramaya düşülür.
function enIyiKonum(mob, baglam, mevcut, kuralSeti) {
  const tumAdaylar = adaylariUret(mob, baglam);
  const capa = mob.eslenik ? mevcut.find((v) => v.mobilya === mob.eslenik.mobilya) : null;

  const kumeler = [];
  if (capa) {
    const yakinlikEsigi = mob.eslenik.mesafe_cm ?? 45;
    const yakin = tumAdaylar.filter((a) => kutuMesafesi(a.kutu, capa.kutu) <= yakinlikEsigi);
    if (yakin.length) kumeler.push({ liste: yakin, bonus: 100 });
  }
  kumeler.push({ liste: tumAdaylar, bonus: 0 });

  for (const { liste, bonus } of kumeler) {
    let enIyi = null, enIyiSkor = -Infinity;
    for (const a of liste) {
      const hepsi = [...mevcut, a];
      const ihlal = ihlalleriBul(hepsi, baglam, kuralSeti).filter((i) => i.siddet === 'hata');
      if (ihlal.length) continue;
      const { ceza } = konforCezasi(hepsi, baglam, kuralSeti);
      // duvara dayanmak iyi · konfor cezası kötü · çapaya yakınlık iyi
      // eşitlikte sol-üst öncelikli (determinizm çıpası — rastgelelik YOK)
      let skor = (a.dayandigiDuvarSayisi ?? 0) * 3 - ceza * 5 - (a.kutu.x + a.kutu.y) * 1e-5 + bonus;
      if (capa) {
        skor -= kutuMesafesi(a.kutu, capa.kutu) * 0.05;
        // hizala:"arka" → çapayla AYNI duvarda ve arka kenarı hizalı olsun
        // (komodin yatağın başucunda durur, ayakucunda değil)
        if (mob.eslenik.hizala === 'arka') {
          if (a.yon === capa.yon) skor += 20;
          const arkaFark = a.yon % 2 === 0
            ? Math.abs((a.yon === 0 ? a.kutu.x : a.kutu.x + a.kutu.g) - (capa.yon === 0 ? capa.kutu.x : capa.kutu.x + capa.kutu.g))
            : Math.abs((a.yon === 1 ? a.kutu.y : a.kutu.y + a.kutu.d) - (capa.yon === 1 ? capa.kutu.y : capa.kutu.y + capa.kutu.d));
          skor -= arkaFark * 0.08;
        }
      }
      if (skor > enIyiSkor) { enIyiSkor = skor; enIyi = a; }
    }
    if (enIyi) return enIyi;
  }
  return null;
}

// İki eksen-hizalı kutu arasındaki en kısa mesafe (çakışıyorsa 0)
function kutuMesafesi(a, b) {
  const dx = Math.max(0, Math.max(a.x, b.x) - Math.min(a.x + a.g, b.x + b.g));
  const dy = Math.max(0, Math.max(a.y, b.y) - Math.min(a.y + a.d, b.y + b.d));
  return Math.hypot(dx, dy);
}

function anaDuvarEtiketi(y, baglam) {
  const kutu = odaKutusu(baglam.odaPoligon);
  const yakinlik = [
    Math.abs(y.kutu.y - kutu.y),                                  // üst
    Math.abs(kutu.x + kutu.g - (y.kutu.x + y.kutu.g)),            // sağ
    Math.abs(kutu.y + kutu.d - (y.kutu.y + y.kutu.d)),            // alt
    Math.abs(y.kutu.x - kutu.x),                                  // sol
  ];
  const adlar = ['ust', 'sag', 'alt', 'sol'];
  return adlar[yakinlik.indexOf(Math.min(...yakinlik))];
}

// Tüm planı döşe
export function plaMobilyala(model, katalogPaketi, kuralSeti, { adet = 3, odalar: sadeceOdalar } = {}) {
  const hedefOdalar = (model.odalar ?? []).filter((o) => !sadeceOdalar || sadeceOdalar.includes(o.id));
  const raporlar = hedefOdalar.map((o) => odayiDose(model, o, katalogPaketi, kuralSeti, { adet }));

  // Aday N: her odanın N'inci adayı (yoksa en iyisine düşer)
  const planAdaylari = [];
  for (let i = 0; i < adet; i++) {
    const yerlesimler = [];
    let eksik = false;
    for (const r of raporlar) {
      if (r.durum === 'sigmadi') { eksik = true; continue; }
      const a = r.adaylar[Math.min(i, r.adaylar.length - 1)];
      if (!a) continue;
      for (const y of a.yerlesimler) yerlesimler.push({ ...y, oda: r.oda });
    }
    // Hiç mobilya yerleşmediyse bu bir "aday" değildir — boş adayı listeye sokmak,
    // sığmayan planı "üretildi" göstermek olurdu.
    if (yerlesimler.length === 0) continue;
    // Çıktı sırası da KANONİK olmalı: model.odalar dizisinin sırası değişince dosya
    // bayt-farklı çıkmasın (aynı yerleşim, farklı sha256 = determinizm iddiasının delinmesi).
    yerlesimler.sort((a, b) =>
      String(a.oda).localeCompare(String(b.oda)) ||
      a.kutu.x - b.kutu.x || a.kutu.y - b.kutu.y ||
      String(a.mobilya).localeCompare(String(b.mobilya))
    );
    const anahtar = yerlesimler.map((y) => `${y.oda}:${y.mobilya}:${y.kutu.x},${y.kutu.y},${y.yon}`).join('|');
    if (planAdaylari.some((p) => p._anahtar === anahtar)) continue;
    planAdaylari.push({ _anahtar: anahtar, yerlesimler });
  }

  return { raporlar, planAdaylari };
}
