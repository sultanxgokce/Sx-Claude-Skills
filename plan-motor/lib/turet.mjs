// TÜRETME KATMANI (ŞAKÜL FAZ 1) — modelden mimari yargı için gereken eşlemeleri TÜRETİR.
// Modele hiçbir şey YAZMAZ; atılabilir görünümdür (kanonik olan CAD/model, bkz. model-sema.md).
// T1 oda↔duvar · T2 açıklık↔oda · erişim grafı · dar-kenar. Saf hesap — fs/model importu yok.
import { uzunluk, alanM2, bbox } from './geometri.mjs';

const TOL = 1; // cm — eşdoğrusallık + örtüşme toleransı (duvar/oda aynı nokta ızgarasını paylaşır)

// ── T1 · oda↔duvar ───────────────────────────────────────────────────────────
// Oda döngüsünün her kenarı için eşdoğrusal ve örtüşen duvarları bulur.
// Döner: duvarOdalari — duvarId → [{oda, t0, t1, taraf}] (t: duvar üstünde bas'tan cm
// cinsinden örtüşme aralığı; taraf: oda duvarın hangi yakasında — +1 sol-normal, -1 sağ,
// 0 belirlenemedi). Aralık VE taraf birlikte tutulur: aralıksız eşleme yanlış komşuluk,
// tarafsız eşleme HAYALET GEÇİT üretir (inceleme bulgusu 2026-08-04: dış duvarda iki
// AYNI-taraf odanın birleşim noktasına denk kapı "aradaki iç kapı" sanılıyordu).
export function odaDuvarEsle(model) {
  const noktalar = model.noktalar ?? {};
  const duvarOdalari = new Map();
  const EPS = 3 * TOL; // taraf-sondasının duvar çizgisinden içeri adımı
  for (const d of model.duvarlar ?? []) {
    const A = noktalar[d.bas], B = noktalar[d.son];
    if (!A || !B) continue;
    const L = uzunluk(A, B);
    if (L < TOL) continue;
    const ux = (B[0] - A[0]) / L, uy = (B[1] - A[1]) / L;
    const nx = -uy, ny = ux; // sol normal
    const kayitlar = [];
    for (const o of model.odalar ?? []) {
      const dongu = (o.dongu ?? []).map((n) => noktalar[n]);
      if (dongu.some((p) => !p)) continue;
      for (let i = 0; i < dongu.length; i++) {
        const P = dongu[i], Q = dongu[(i + 1) % dongu.length];
        // eşdoğrusallık: iki kenar ucu da duvar doğrusuna TOL içinde mi
        const dP = Math.abs((P[0] - A[0]) * uy - (P[1] - A[1]) * ux);
        const dQ = Math.abs((Q[0] - A[0]) * uy - (Q[1] - A[1]) * ux);
        if (dP > TOL || dQ > TOL) continue;
        const tP = (P[0] - A[0]) * ux + (P[1] - A[1]) * uy;
        const tQ = (Q[0] - A[0]) * ux + (Q[1] - A[1]) * uy;
        const t0 = Math.max(Math.min(tP, tQ), 0), t1 = Math.min(Math.max(tP, tQ), L);
        if (t1 - t0 <= TOL) continue;
        // taraf: örtüşme orta-noktasından ±normal yönünde EPS adım — hangisi odanın içindeyse
        const tm = (t0 + t1) / 2;
        const M = [A[0] + ux * tm, A[1] + uy * tm];
        const arti = noktaIcinde([M[0] + nx * EPS, M[1] + ny * EPS], dongu);
        const eksi = noktaIcinde([M[0] - nx * EPS, M[1] - ny * EPS], dongu);
        const taraf = arti && !eksi ? 1 : eksi && !arti ? -1 : 0;
        kayitlar.push({ oda: o.id, t0, t1, taraf });
      }
    }
    duvarOdalari.set(d.id, kayitlar);
  }
  return duvarOdalari;
}

// ── T2 · açıklık↔oda ─────────────────────────────────────────────────────────
// Açıklık merkezinin duvar-parametresi hangi odaların örtüşme aralığına düşüyorsa o odalara
// bakar. Döner: aciklikId → { odalar, dis, belirsiz }.
//   dis      = tek odaya bakıyor VE duvar tip=dis → dışarıya açılıyor (daire girişi / pencere)
//   belirsiz = geçit olduğu KANITLANAMAYAN her durum. İç geçit sayılmanın tek yolu: tam iki
//              oda, TARAFLARI KARŞIT (+1/-1) ve duvar iç. Aynı-taraf iki oda (birleşim
//              noktası), taraf belirlenemeyen çift, dış duvarda iki oda, 0 ya da >2 oda —
//              hepsi belirsiz. Fail-closed: belirsiz açıklık erişim grafına KENAR EKLEMEZ
//              ve oda kanat-sayımına GİRMEZ (kanıtsız geçit yok, kanıtsız kanat yok).
export function aciklikOdaEsle(model, duvarOdalari = odaDuvarEsle(model)) {
  const noktalar = model.noktalar ?? {};
  const duvarIdx = new Map((model.duvarlar ?? []).map((d) => [d.id, d]));
  const sonuc = new Map();
  for (const a of model.acikliklar ?? []) {
    const d = duvarIdx.get(a.duvar);
    const A = d && noktalar[d.bas], B = d && noktalar[d.son];
    if (!A || !B) { sonuc.set(a.id, { odalar: [], dis: false, belirsiz: true }); continue; }
    const t = a.oran * uzunluk(A, B);
    // oda-başına tek kayıt; t'yi TOL'süz (kesin) içeren aralık, sınır-bandındakine yeğlenir
    const enIyi = new Map();
    for (const k of duvarOdalari.get(d.id) ?? []) {
      if (t < k.t0 - TOL || t > k.t1 + TOL) continue;
      const kesin = t >= k.t0 && t <= k.t1;
      const mevcut = enIyi.get(k.oda);
      if (!mevcut || (kesin && !mevcut.kesin)) enIyi.set(k.oda, { ...k, kesin });
    }
    const kayitlar = [...enIyi.values()];
    const tekil = kayitlar.map((k) => k.oda);
    let dis = false, belirsiz = false;
    if (kayitlar.length === 1) {
      if (d.tip === 'dis') dis = true;
      else belirsiz = true; // iç duvarda tek oda — öbür taraf modellenmemiş
    } else if (kayitlar.length === 2) {
      const karsit = kayitlar[0].taraf * kayitlar[1].taraf === -1; // ikisi de bilinen VE zıt
      if (!karsit || d.tip === 'dis') belirsiz = true;
    } else {
      belirsiz = true; // 0 oda ya da >2 oda
    }
    sonuc.set(a.id, { odalar: tekil, dis, belirsiz });
  }
  return sonuc;
}

// ── Erişim grafı ─────────────────────────────────────────────────────────────
// Düğümler: odalar + "DIS". Kenar: kapi|gecis açıklığı (pencere geçit DEĞİL).
// BFS DIS'ten başlar → erisilemeyen listesi. belirsiz açıklıklar kenar üretmez, ayrıca raporlanır.
export function erisimGrafi(model, aciklikOda = aciklikOdaEsle(model)) {
  const komsu = new Map((model.odalar ?? []).map((o) => [o.id, new Set()]));
  komsu.set('DIS', new Set());
  const belirsizler = [];
  for (const a of model.acikliklar ?? []) {
    if (a.tip !== 'kapi' && a.tip !== 'gecis') continue;
    const e = aciklikOda.get(a.id);
    if (!e || e.belirsiz) { belirsizler.push(a.id); continue; }
    const [o1, o2] = e.dis ? [e.odalar[0], 'DIS'] : e.odalar;
    if (o1 && o2 && komsu.has(o1) && komsu.has(o2)) { komsu.get(o1).add(o2); komsu.get(o2).add(o1); }
  }
  const erisilen = new Set(['DIS']);
  const kuyruk = ['DIS'];
  while (kuyruk.length) {
    for (const k of komsu.get(kuyruk.shift()) ?? []) if (!erisilen.has(k)) { erisilen.add(k); kuyruk.push(k); }
  }
  const erisilemeyen = (model.odalar ?? []).map((o) => o.id).filter((id) => !erisilen.has(id));
  return { erisilemeyen, belirsizler };
}

// ── Oda-başına açıklık sayıları + doğrudan ışık ──────────────────────────────
// kapi = kanat (B-001'in aradığı) · gecis = ağız/boşluk · dogrudan_isik = dış duvarda
// pencere YA DA dışa açılan kapı (balkon kapısı ışık sayılır — PAİY md.32/(1) yorumu).
export function odaAciklikOzeti(model, duvarOdalari = odaDuvarEsle(model), aciklikOda = aciklikOdaEsle(model, duvarOdalari)) {
  const duvarIdx = new Map((model.duvarlar ?? []).map((d) => [d.id, d]));
  const ozet = new Map((model.odalar ?? []).map((o) => [o.id, { kapi: 0, gecis: 0, dogrudan_isik: false }]));
  for (const a of model.acikliklar ?? []) {
    const e = aciklikOda.get(a.id);
    if (!e || e.belirsiz) continue; // kanıtsız komşuluk → sayıma girmez (fail-closed)
    const d = duvarIdx.get(a.duvar);
    for (const oid of e.odalar) {
      const s = ozet.get(oid);
      if (!s) continue;
      if (a.tip === 'kapi') s.kapi++;
      if (a.tip === 'gecis') s.gecis++;
      if (d?.tip === 'dis' && e.odalar.length === 1 && (a.tip === 'pencere' || (a.tip === 'kapi' && e.dis))) s.dogrudan_isik = true;
    }
  }
  return ozet;
}

// ── Dar kenar (cm) ───────────────────────────────────────────────────────────
// Eksen-hizalı (rectilinear) poligonda GERÇEK en dar geçit: paralel-örtüşen kenar çiftleri
// arasından, aradaki şeridin merkezi poligonun İÇİNDE kalanların en küçük mesafesi.
// (Salt bbox U-biçimli koridorda çentiği "dar kenar" sanırdı — içeride-mi testi bunu keser.)
// Eksen-dışı kenar varsa dürüst geri-çekilme: bbox kısa kenarı + yaklasik=true (DÜŞÜK GÜVEN).
export function darKenarCm(koseler) {
  const kutu = bbox(koseler);
  const n = koseler.length;
  const yatay = [], dikey = [];
  for (let i = 0; i < n; i++) {
    const P = koseler[i], Q = koseler[(i + 1) % n];
    if (Math.abs(P[1] - Q[1]) <= TOL) yatay.push({ c: (P[1] + Q[1]) / 2, a: Math.min(P[0], Q[0]), b: Math.max(P[0], Q[0]) });
    else if (Math.abs(P[0] - Q[0]) <= TOL) dikey.push({ c: (P[0] + Q[0]) / 2, a: Math.min(P[1], Q[1]), b: Math.max(P[1], Q[1]) });
    else return { deger: Math.min(kutu.w, kutu.h), yaklasik: true };
  }
  let enDar = Infinity;
  const tara = (kenarlar, dikeyMi) => {
    for (let i = 0; i < kenarlar.length; i++) for (let j = i + 1; j < kenarlar.length; j++) {
      const e1 = kenarlar[i], e2 = kenarlar[j];
      const mesafe = Math.abs(e1.c - e2.c);
      if (mesafe <= TOL || mesafe >= enDar) continue;
      const o0 = Math.max(e1.a, e2.a), o1 = Math.min(e1.b, e2.b);
      if (o1 - o0 <= TOL) continue;
      const orta = dikeyMi ? [(e1.c + e2.c) / 2, (o0 + o1) / 2] : [(o0 + o1) / 2, (e1.c + e2.c) / 2];
      if (noktaIcinde(orta, koseler)) enDar = mesafe;
    }
  };
  tara(yatay, false);
  tara(dikey, true);
  return Number.isFinite(enDar)
    ? { deger: enDar, yaklasik: false }
    : { deger: Math.min(kutu.w, kutu.h), yaklasik: true };
}

// Işın-testi (ray casting). Şerit-merkezi üreten iki kenardan ≥TOL/2 uzakta olduğundan
// sınır-üstü belirsizliği pratikte doğmaz; üçüncü bir eşdoğrusal kenara denk gelme ihtimali
// bilinen sınırlılıktır (rectilinear planlarda gözlenmedi).
export function noktaIcinde([x, y], koseler) {
  let icinde = false;
  for (let i = 0, j = koseler.length - 1; i < koseler.length; j = i++) {
    const [xi, yi] = koseler[i], [xj, yj] = koseler[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) icinde = !icinde;
  }
  return icinde;
}

// ── Denetim bağlamı — kural motorunun tükettiği türetilmiş metrikler ─────────
export function denetimBaglami(model) {
  const duvarOdalari = odaDuvarEsle(model);
  const aciklikOda = aciklikOdaEsle(model, duvarOdalari);
  const ozet = odaAciklikOzeti(model, duvarOdalari, aciklikOda);
  const graf = erisimGrafi(model, aciklikOda);
  const odalar = (model.odalar ?? []).map((o) => {
    const koseler = (o.dongu ?? []).map((n) => model.noktalar[n]).filter(Boolean);
    const dk = koseler.length >= 3 ? darKenarCm(koseler) : { deger: 0, yaklasik: true };
    const s = ozet.get(o.id) ?? { kapi: 0, gecis: 0, dogrudan_isik: false };
    return {
      id: o.id, ad: o.ad ?? o.id, tip: o.tip,
      net_alan_m2: koseler.length >= 3 ? +alanM2(koseler).toFixed(2) : 0,
      dar_kenar_cm: +dk.deger.toFixed(1), dar_kenar_yaklasik: dk.yaklasik,
      kapi_sayisi: s.kapi, kapi_gecis_sayisi: s.kapi + s.gecis, dogrudan_isik: s.dogrudan_isik,
    };
  });
  const acikliklar = (model.acikliklar ?? []).map((a) => {
    const e = aciklikOda.get(a.id) ?? { odalar: [], dis: false, belirsiz: true };
    // belirsiz açıklıkta dis BİLİNMİYOR → undefined bırakılır ki kural motoru onu
    // "false" (iç kapı) sanıp yanlış eşiğe sokmasın — 'belirsiz' sayıp KÖR NOKTA bassın
    return { id: a.id, tip: a.tip, rol: a.rol, genislik_cm: a.genislik, dis: e.belirsiz ? undefined : e.dis, belirsiz: e.belirsiz, odalar: e.odalar };
  });
  return {
    odalar, acikliklar,
    plan: { oda_sayisi: odalar.length, erisilemeyen_oda_sayisi: graf.erisilemeyen.length },
    erisilemeyen: graf.erisilemeyen, belirsiz_acikliklar: graf.belirsizler,
  };
}
