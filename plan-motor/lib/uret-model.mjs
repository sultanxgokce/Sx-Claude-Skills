// ÜRETİM FAZ A · yerleşim (dikdörtgenler) → model.json
// Duvar grafı ATOMİK segmentlerden kurulur: her kesişim kırılma noktasıdır, bir segmentin iki
// yanında ya iki oda (→ tip "ic") ya bir oda (→ tip "dis") vardır. Bu, turet.mjs'in taraf
// hesabının KANIT istediği yerdir: aynı-taraf/tarafsız eşleme HAYALET GEÇİT üretir, o yüzden
// segmenti kaba değil atomik kesiyoruz — her iç kapı gerçekten iki odayı ayırır.
// Kapı yerleşim sırası (DOĞUM-PROMPTU §5): paylaşılan segment → erişim ağacı → orta nokta →
// sığmıyorsa kenarı ele → dış kapı → pencere. Sıra bozulursa erişim kuralı körleşir.
import { alanM2 } from './geometri.mjs';

const EPS = 0.25;   // taraf sondası — koordinatlar tam sayı, oda kenarları ≥ ~100 cm
const PAY = 10;     // açıklığın duvar ucuna asgari uzaklığı (cm) — köşeye dayalı kapı üretme

const nid = (x, y) => `p${x}_${y}`;

function odaIcinde(p, x, y) { return x > p.x0 && x < p.x1 && y > p.y0 && y < p.y1; }
function parcaBul(parcalar, x, y) { for (const p of parcalar) if (odaIcinde(p, x, y)) return p; return null; }

// ── Atomik duvar segmentleri ─────────────────────────────────────────────────
function segmentler(parcalar) {
  const dikey = new Map();   // x → [{a,b}] (y aralıkları)
  const yatay = new Map();   // y → [{a,b}] (x aralıkları)
  const ekle = (m, k, a, b) => { (m.get(k) ?? m.set(k, []).get(k)).push({ a, b }); };
  for (const p of parcalar) {
    ekle(dikey, p.x0, p.y0, p.y1); ekle(dikey, p.x1, p.y0, p.y1);
    ekle(yatay, p.y0, p.x0, p.x1); ekle(yatay, p.y1, p.x0, p.x1);
  }
  const cikti = [];
  const isle = (m, dikeyMi) => {
    for (const k of [...m.keys()].sort((x, y) => x - y)) {
      const araliklar = m.get(k);
      const kirilma = [...new Set(araliklar.flatMap((i) => [i.a, i.b]))].sort((x, y) => x - y);
      for (let i = 0; i + 1 < kirilma.length; i++) {
        const a = kirilma[i], b = kirilma[i + 1];
        if (b - a < 1) continue;
        if (!araliklar.some((iv) => iv.a <= a && iv.b >= b)) continue;
        const orta = (a + b) / 2;
        const [p1, p2] = dikeyMi
          ? [parcaBul(parcalar, k - EPS, orta), parcaBul(parcalar, k + EPS, orta)]
          : [parcaBul(parcalar, orta, k - EPS), parcaBul(parcalar, orta, k + EPS)];
        const yanlar = [p1, p2].filter(Boolean);
        if (!yanlar.length) continue;
        const tip = yanlar.length === 2 ? (p1.oda.id === p2.oda.id ? null : 'ic') : 'dis';
        if (!tip) continue; // aynı oda iki yanda: gerçek duvar değil (olmamalı, ama sessiz geçme)
        cikti.push({
          id: dikeyMi ? `w_d${k}_${a}_${b}` : `w_y${k}_${a}_${b}`,
          bas: dikeyMi ? nid(k, a) : nid(a, k),
          son: dikeyMi ? nid(k, b) : nid(b, k),
          basXY: dikeyMi ? [k, a] : [a, k],
          sonXY: dikeyMi ? [k, b] : [b, k],
          uzunluk: b - a, tip, dikeyMi, sabit: k, a, b,
          odalar: yanlar.map((p) => p.oda.id),
        });
      }
    }
  };
  isle(dikey, true);
  isle(yatay, false);
  return cikti.sort((x, y) => (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
}

// ── Erişim ağacı (BFS, deterministik) ────────────────────────────────────────
function erisimAgaci(odaIdler, kenarlar, kok) {
  const komsu = new Map(odaIdler.map((id) => [id, []]));
  for (const k of kenarlar) { komsu.get(k.a)?.push(k); komsu.get(k.b)?.push(k); }
  for (const [, liste] of komsu) liste.sort((x, y) => (x.anahtar < y.anahtar ? -1 : 1));
  const gorulen = new Set([kok]);
  const secilen = [];
  const kuyruk = [kok];
  while (kuyruk.length) {
    const u = kuyruk.shift();
    for (const k of komsu.get(u) ?? []) {
      const v = k.a === u ? k.b : k.a;
      if (gorulen.has(v)) continue;
      gorulen.add(v); secilen.push(k); kuyruk.push(v);
    }
  }
  return { secilen, erisilemeyen: odaIdler.filter((id) => !gorulen.has(id)) };
}

// Döner: { model, notlar } · üretilemiyorsa { model: null, sebep }
export function modelKur(parcalar, norm, esikler, opts = {}) {
  const segs = segmentler(parcalar);
  const kapiG = esikler.kapi.ic, girisG = esikler.kapi.giris;
  const odaIdler = norm.odalar.map((o) => o.id);

  // paylaşılan iç segmentler → oda çiftleri (çift başına EN UZUN segment)
  const ciftler = new Map();
  for (const s of segs) {
    if (s.tip !== 'ic') continue;
    const [a, b] = [...s.odalar].sort();
    const anahtar = `${a}|${b}`;
    const mevcut = ciftler.get(anahtar);
    if (!mevcut || s.uzunluk > mevcut.seg.uzunluk) ciftler.set(anahtar, { a, b, anahtar, seg: s });
  }
  const paylasilan = [...ciftler.values()];
  // kapı sığmayan kenar erişim grafında YOK sayılır (kanıtsız geçit üretmeyiz)
  const kapiliKenarlar = paylasilan.filter((c) => c.seg.uzunluk >= kapiG + 2 * PAY);

  const kokAday = norm.odalar.find((o) => o.tip === 'hol' || o.tip === 'antre') ?? norm.odalar[0];
  const { secilen, erisilemeyen } = erisimAgaci(odaIdler, kapiliKenarlar, kokAday.id);
  if (erisilemeyen.length) return { model: null, sebep: `erişilemeyen oda: ${erisilemeyen.join(', ')} (kapı sığan paylaşılan duvar yok)` };

  // dış segmentler oda başına
  const disler = new Map(odaIdler.map((id) => [id, []]));
  for (const s of segs) if (s.tip === 'dis') disler.get(s.odalar[0])?.push(s);
  for (const [, l] of disler) l.sort((x, y) => y.uzunluk - x.uzunluk || (x.id < y.id ? -1 : 1));

  // ── dış kapı (rol=giris) — kök odanın dış duvarına ────────────────────────
  // giris_kenari verilmişse ZORUNLUDUR, tavsiye değil: mimar bunu verdiğinde daireye hangi
  // yönden girildiği bir SAHA GERÇEĞİdir (kat holü/merdiven orada). Başka kenara kaçmak
  // "isteneni üretemedim"i sessizce "başka bir şey ürettim"e çevirirdi — ve giriş kenarını
  // sahte bir çeşitlilik ekseni hâline getiriyordu (ölçüldü: 4 adayın tek farkı buydu).
  const istenenKenarda = (s) => {
    if (norm.giris_kenari === undefined) return true;
    const r = norm.rect;
    return norm.giris_kenari === 0 ? (!s.dikeyMi && s.sabit === r.y0)
      : norm.giris_kenari === 1 ? (s.dikeyMi && s.sabit === r.x1)
        : norm.giris_kenari === 2 ? (!s.dikeyMi && s.sabit === r.y1)
          : (s.dikeyMi && s.sabit === r.x0);
  };
  const KENAR_ADI = ['alt', 'sağ', 'üst', 'sol'];
  const kokDis = [...(disler.get(kokAday.id) ?? [])]
    .filter((s) => s.uzunluk >= girisG + 2 * PAY && istenenKenarda(s))
    .sort((x, y) => y.uzunluk - x.uzunluk || (x.id < y.id ? -1 : 1));
  if (!kokDis.length) {
    const kenar = norm.giris_kenari === undefined ? '' : ` "${KENAR_ADI[norm.giris_kenari]}" kenarında`;
    return { model: null, sebep: `giriş kapısı yerleşemedi: "${kokAday.id}" odasının${kenar} ${girisG} cm kapı alacak dış duvarı yok` };
  }
  const girisSeg = kokDis[0];

  // ── açıklıklar ────────────────────────────────────────────────────────────
  const acikliklar = [];
  acikliklar.push({ id: 'a_giris', tip: 'kapi', rol: 'giris', duvar: girisSeg.id, oran: 0.5, genislik: girisG, aci_yonu: 1 });
  for (const k of [...secilen].sort((x, y) => (x.anahtar < y.anahtar ? -1 : 1))) {
    acikliklar.push({ id: `a_kapi_${k.a}__${k.b}`, tip: 'kapi', rol: 'diger', duvar: k.seg.id, oran: 0.5, genislik: kapiG, aci_yonu: 1 });
  }
  // ── pencereler: doğrudan-ışık şartına tabi tipler ZORUNLU, diğerleri fırsatçı ──
  for (const o of norm.odalar) {
    const adaylar = (disler.get(o.id) ?? []).filter((s) => s.id !== girisSeg.id && s.uzunluk >= 60 + 2 * PAY);
    const zorunlu = esikler.isikli.has(o.tip);
    if (!adaylar.length) {
      if (zorunlu) return { model: null, sebep: `doğrudan ışık: "${o.id}" (${o.tip}) odasına pencere alacak dış duvar yok` };
      continue;
    }
    const s = adaylar[0];
    const g = Math.min(140, Math.floor(s.uzunluk - 2 * PAY));
    acikliklar.push({ id: `a_pencere_${o.id}`, tip: 'pencere', duvar: s.id, oran: 0.5, genislik: g });
  }

  // ── model ─────────────────────────────────────────────────────────────────
  const kullanilanDuvar = new Set(acikliklar.map((a) => a.duvar));
  const duvarlar = segs.map((s) => ({ id: s.id, bas: s.bas, son: s.son, kalinlik: s.tip === 'dis' ? norm.duvar.dis : norm.duvar.ic, tip: s.tip }));
  const noktalar = {};
  for (const s of segs) { noktalar[s.bas] = s.basXY; noktalar[s.son] = s.sonXY; }
  const parcaIdx = new Map(parcalar.map((p) => [p.oda.id, p]));
  const odalar = norm.odalar.map((o) => {
    const p = parcaIdx.get(o.id);
    for (const [x, y] of [[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]) noktalar[nid(x, y)] = [x, y];
    return {
      id: o.id, ad: o.ad, tip: o.tip,
      // CCW döngü — turet.mjs taraf hesabı (sol normal) bunun tutarlılığına dayanır
      dongu: [nid(p.x0, p.y0), nid(p.x1, p.y0), nid(p.x1, p.y1), nid(p.x0, p.y1)],
      guven: 'normal',
      // beyan_m2 BİLEREK YAZILMAZ: hedef (program) ≠ geometrinin gerçeği; beyan yazmak
      // %5 tolerans kapısına yalan bir iddia sokar (DOĞUM-PROMPTU §3 tuzağı).
    };
  });

  const model = {
    surum: '1.0',
    ad: opts.ad ?? `PERGEL üretimi${norm.ad ? ` — ${norm.ad}` : ''}`,
    birim: 'cm',
    olcek: { kaynak: 'turetilmis', aciklama: `PERGEL FAZ A · slicing-tree · program: ${norm.ad ?? 'adsız'} · ${odalar.length} oda` },
    noktalar, duvarlar, odalar, acikliklar,
  };
  return {
    model,
    notlar: {
      segment_sayisi: segs.length,
      ic_segment: segs.filter((s) => s.tip === 'ic').length,
      paylasilan_cift: paylasilan.length,
      kapi_sigan_cift: kapiliKenarlar.length,
      kapi_sayisi: acikliklar.filter((a) => a.tip === 'kapi').length,
      pencere_sayisi: acikliklar.filter((a) => a.tip === 'pencere').length,
      kullanilmayan_duvar: duvarlar.length - kullanilanDuvar.size,
      komsu_ciftler: paylasilan.map((c) => [c.a, c.b]),
      oda_m2: Object.fromEntries(parcalar.map((p) => [p.oda.id, +alanM2([[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]).toFixed(2)])),
    },
  };
}
