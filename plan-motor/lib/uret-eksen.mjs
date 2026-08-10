// FAZ B1 · AYRIK MİMARİ KARARLAR — adayı mimarın diliyle etiketler.
//
// Tasarım kararı (ve niçin): eksen değerleri BEYAN EDİLMEZ, MODELDEN ÖLÇÜLÜR. Üretim
// "bunu merkezi-hol olarak ürettim" deseydi etiket bir iddia olurdu; ölçülünce KANIT olur —
// üçüncü bir taraf aynı modelden aynı etiketi yeniden türetebilir. Bu, motorun her yerdeki
// kuralının (kanıtsız iddia yok) etiket katmanındaki karşılığıdır.
//
// ⚠️ Eksenler uydurulmadı. Her birinin dayanağı aşağıda AÇIKÇA yazılı ve hiçbiri mevzuat
// maddesi gibi gösterilmiyor: ikisi ÖLÇÜM-temelli mimari sonuç, biri PAİY'in tanıdığı hacim
// türüne (hol/antre, md.29/(3)) dayanıyor. Dayanağı olmayan eksen (ör. "cephe kurgusu")
// bilinçli olarak DIŞARIDA — bina ölçeği zaten kapsam dışı.
import { aciklikOdaEsle } from './turet.mjs';
import { bbox } from './geometri.mjs';

export const ISLAK_TIPLER = ['banyo', 'wc', 'mutfak'];
export const YASAM_TIPLER = ['oturma_odasi', 'mutfak'];
export const YATMA_TIPLER = ['yatak_odasi'];
export const HOL_TIPLER = ['hol', 'antre'];

const HOL_UZUN_ORAN = 2.5; // en/boy ≥ bu ise hol "doğrusal koridor" sayılır (ölçüm eşiği)

export const EKSENLER = [
  {
    id: 'islak_cekirdek',
    ad: 'Islak çekirdek',
    dayanak: 'ÖLÇÜM (mevzuat maddesi DEĞİL) — ıslak hacimlerin (banyo·wc·mutfak) bitişiklik kümesi + dış duvar teması. Tesisat şaftının toplanması mimari ve maliyet sonucu doğurur.',
    degerler: {
      yok: 'planda ıslak hacim yok',
      tekil: 'tek ıslak hacim — gruplama sorusu doğmuyor',
      dagitik: 'ıslak hacimler tek bitişik küme oluşturmuyor (ayrı şaftlar)',
      'gruplu-dis': 'tek bitişik küme; hepsinin dış duvarı var (doğal havalandırma mümkün)',
      'gruplu-ic': 'tek bitişik küme; en az biri tamamen iç (şaft/mekanik havalandırma gerekir)',
    },
  },
  {
    id: 'sirkulasyon',
    ad: 'Sirkülasyon',
    dayanak: 'PAİY md.29/(3) hol/koridor hacmini tanır (asgari genişlik kuralı oradan gelir); değerler kapı grafından ve hol en/boy oranından ÖLÇÜLÜR.',
    degerler: {
      koridorsuz: 'planda hol/antre yok — odalar birbirinden geçilir',
      'merkezi-hol': 'her oda hole doğrudan açılıyor, hol derli toplu (en/boy < 2.5)',
      'dogrusal-hol': 'her oda hole doğrudan açılıyor, hol uzun koridor (en/boy ≥ 2.5)',
      'karma-hol': 'hol var ama en az bir odaya başka odadan geçilerek varılıyor',
    },
  },
  {
    id: 'zonlama',
    ad: 'Zonlama',
    dayanak: 'ÖLÇÜM (mevzuat maddesi DEĞİL) — yatma (yatak odası) ile yaşam (oturma odası·mutfak) arasında DOĞRUDAN kapı var mı. Mahremiyet, mimarın somut kararıdır.',
    degerler: {
      'tek-bolge': 'iki bölgeden biri planda yok',
      ayrik: 'yatma ile yaşam arasında doğrudan kapı yok — geçiş sirkülasyon üzerinden',
      karisik: 'en az bir yatak odası doğrudan yaşam hacmine açılıyor',
    },
  },
  {
    id: 'giris',
    ad: 'Giriş kenarı',
    dayanak: 'ÖLÇÜM — giriş kapısının (rol=giris) hangi dış kenarda olduğu. Program kenarı sabitlemişse bu eksen tek değerlidir (çeşitlilik üretmez, kaydı yine tutulur).',
    degerler: { alt: 'y en küçük kenar', sag: 'x en büyük kenar', ust: 'y en büyük kenar', sol: 'x en küçük kenar', belirsiz: 'giriş kapısı dış kenara oturtulamadı' },
  },
];

// Oda döngüsünden eksen-hizalı dikdörtgen. Dikdörtgen değilse bbox'a düşer ve BUNU SÖYLER:
// yaklaşık kutu üstünden "bitişik" demek hayalet komşuluk üretir, o yüzden yaklasik bayrağı
// taşınır ve çağıran onu ölçüm güveni olarak raporlar.
function odaKutulari(model) {
  const kutular = new Map();
  for (const o of model.odalar ?? []) {
    const k = (o.dongu ?? []).map((n) => model.noktalar[n]).filter(Boolean);
    if (k.length < 3) continue;
    const b = bbox(k);
    const dikdortgen = k.length === 4 && new Set(k.map((p) => p[0])).size === 2 && new Set(k.map((p) => p[1])).size === 2;
    kutular.set(o.id, { id: o.id, tip: o.tip, x0: b.minX, y0: b.minY, x1: b.maxX, y1: b.maxY, yaklasik: !dikdortgen });
  }
  return kutular;
}

function bitisikMi(a, b, tol = 1) {
  const xOrt = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0);
  const yOrt = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0);
  const dikey = Math.min(Math.abs(a.x1 - b.x0), Math.abs(b.x1 - a.x0)) <= tol && yOrt > tol;
  const yatay = Math.min(Math.abs(a.y1 - b.y0), Math.abs(b.y1 - a.y0)) <= tol && xOrt > tol;
  return dikey || yatay;
}

// Kapı/geçiş grafı — KANITLI kenarlar (belirsiz açıklık kenar üretmez, turet.mjs kuralı).
function kapiGrafi(model) {
  const esle = aciklikOdaEsle(model);
  const kenarlar = [], disKapilar = [];
  for (const a of model.acikliklar ?? []) {
    if (a.tip !== 'kapi' && a.tip !== 'gecis') continue;
    const e = esle.get(a.id);
    if (!e || e.belirsiz) continue;
    if (e.dis) disKapilar.push({ aciklik: a, oda: e.odalar[0] });
    else if (e.odalar.length === 2) kenarlar.push([e.odalar[0], e.odalar[1]]);
  }
  return { kenarlar, disKapilar };
}

function bilesenler(idler, bitisik) {
  const kalan = new Set(idler), gruplar = [];
  while (kalan.size) {
    const kok = [...kalan][0];
    const grup = [kok], kuyruk = [kok];
    kalan.delete(kok);
    while (kuyruk.length) {
      const u = kuyruk.shift();
      for (const v of [...kalan]) if (bitisik(u, v)) { kalan.delete(v); grup.push(v); kuyruk.push(v); }
    }
    gruplar.push(grup);
  }
  return gruplar;
}

// MODELDEN eksen değerlerini ÖLÇ. Saf fonksiyon; modele hiçbir şey yazmaz.
export function eksenleriOlc(model) {
  const kutular = odaKutulari(model);
  const tumKose = Object.values(model.noktalar ?? {});
  const plan = bbox(tumKose);
  const { kenarlar, disKapilar } = kapiGrafi(model);
  const kapiKomsu = new Map([...kutular.keys()].map((id) => [id, new Set()]));
  for (const [a, b] of kenarlar) { kapiKomsu.get(a)?.add(b); kapiKomsu.get(b)?.add(a); }
  const bitisik = (a, b) => bitisikMi(kutular.get(a), kutular.get(b));
  const tipli = (tipler) => [...kutular.values()].filter((r) => tipler.includes(r.tip)).map((r) => r.id);
  const disTemas = (id) => {
    const r = kutular.get(id);
    return r.x0 <= plan.minX + 1 || r.x1 >= plan.maxX - 1 || r.y0 <= plan.minY + 1 || r.y1 >= plan.maxY - 1;
  };

  // ── ıslak çekirdek ─────────────────────────────────────────────────────────
  const islak = tipli(ISLAK_TIPLER);
  let islak_cekirdek;
  if (islak.length === 0) islak_cekirdek = 'yok';
  else if (islak.length === 1) islak_cekirdek = 'tekil';
  else {
    const gruplar = bilesenler(islak, bitisik);
    islak_cekirdek = gruplar.length > 1 ? 'dagitik' : (islak.every(disTemas) ? 'gruplu-dis' : 'gruplu-ic');
  }

  // ── sirkülasyon ────────────────────────────────────────────────────────────
  const holler = tipli(HOL_TIPLER);
  let sirkulasyon;
  if (!holler.length) sirkulasyon = 'koridorsuz';
  else {
    const digerleri = [...kutular.keys()].filter((id) => !holler.includes(id));
    const yildiz = digerleri.every((id) => [...(kapiKomsu.get(id) ?? [])].some((k) => holler.includes(k)));
    if (!yildiz) sirkulasyon = 'karma-hol';
    else {
      const enBuyukHol = holler
        .map((id) => kutular.get(id))
        .sort((a, b) => (b.x1 - b.x0) * (b.y1 - b.y0) - (a.x1 - a.x0) * (a.y1 - a.y0))[0];
      const w = enBuyukHol.x1 - enBuyukHol.x0, h = enBuyukHol.y1 - enBuyukHol.y0;
      sirkulasyon = Math.max(w, h) / Math.min(w, h) >= HOL_UZUN_ORAN ? 'dogrusal-hol' : 'merkezi-hol';
    }
  }

  // ── zonlama ────────────────────────────────────────────────────────────────
  const yatma = tipli(YATMA_TIPLER), yasam = tipli(YASAM_TIPLER);
  let zonlama;
  if (!yatma.length || !yasam.length) zonlama = 'tek-bolge';
  else zonlama = yatma.some((y) => [...(kapiKomsu.get(y) ?? [])].some((k) => yasam.includes(k))) ? 'karisik' : 'ayrik';

  // ── giriş kenarı ───────────────────────────────────────────────────────────
  let giris = 'belirsiz';
  const girisKapisi = disKapilar.find((d) => d.aciklik.rol === 'giris') ?? disKapilar[0];
  if (girisKapisi) {
    const d = (model.duvarlar ?? []).find((x) => x.id === girisKapisi.aciklik.duvar);
    const A = d && model.noktalar[d.bas], B = d && model.noktalar[d.son];
    if (A && B) {
      if (Math.abs(A[1] - B[1]) < 1) giris = Math.abs(A[1] - plan.minY) < 1 ? 'alt' : Math.abs(A[1] - plan.maxY) < 1 ? 'ust' : 'belirsiz';
      else if (Math.abs(A[0] - B[0]) < 1) giris = Math.abs(A[0] - plan.minX) < 1 ? 'sol' : Math.abs(A[0] - plan.maxX) < 1 ? 'sag' : 'belirsiz';
    }
  }

  const yaklasikOlcum = [...kutular.values()].some((r) => r.yaklasik);
  return { islak_cekirdek, sirkulasyon, zonlama, giris, yaklasik_olcum: yaklasikOlcum };
}

export function kombinasyonAnahtari(e) {
  return `${e.islak_cekirdek}|${e.sirkulasyon}|${e.zonlama}|${e.giris}`;
}

// Mimarın okuyacağı tek satır — model.ad ve SVG başlığı buradan kurulur.
// "Üç plan farklı" değil, "ıslak çekirdek gruplu-iç, sirkülasyon merkezi hol" denir.
export function kombinasyonMetni(e) {
  return `ıslak: ${e.islak_cekirdek} · sirkülasyon: ${e.sirkulasyon} · zon: ${e.zonlama} · giriş: ${e.giris}`;
}

// ── Seçim katmanı için UCUZ ön-sınıf (yalnız geometri; kapı grafı gerekmez) ──
// Niçin var: denetim bütçesi (TAVAN.denetim) ön-skorca en iyi N adayı alırsa hepsi AYNI
// mimari aileden çıkabilir — bütçe çeşitliliği sessizce öldürür. Bu anahtar, bütçeyi
// katmanlara bölüp her katmandan en iyileri almak için kullanılır (deterministik).
export function onSinif(parcalar) {
  const kutu = (p) => ({ id: p.oda.id, tip: p.oda.tip, x0: p.x0, y0: p.y0, x1: p.x1, y1: p.y1 });
  const hepsi = parcalar.map(kutu);
  const b = bbox(parcalar.flatMap((p) => [[p.x0, p.y0], [p.x1, p.y1]]));
  const idx = new Map(hepsi.map((r) => [r.id, r]));
  const bit = (a, c) => bitisikMi(idx.get(a), idx.get(c));
  const islak = hepsi.filter((r) => ISLAK_TIPLER.includes(r.tip)).map((r) => r.id);
  const disT = (id) => {
    const r = idx.get(id);
    return r.x0 <= b.minX + 1 || r.x1 >= b.maxX - 1 || r.y0 <= b.minY + 1 || r.y1 >= b.maxY - 1;
  };
  const i = islak.length === 0 ? 'yok' : islak.length === 1 ? 'tekil'
    : bilesenler(islak, bit).length > 1 ? 'dagitik' : (islak.every(disT) ? 'gruplu-dis' : 'gruplu-ic');
  const holler = hepsi.filter((r) => HOL_TIPLER.includes(r.tip));
  let h = 'yok';
  if (holler.length) {
    const en = holler.sort((x, y) => (y.x1 - y.x0) * (y.y1 - y.y0) - (x.x1 - x.x0) * (x.y1 - x.y0))[0];
    const w = en.x1 - en.x0, hh = en.y1 - en.y0;
    h = Math.max(w, hh) / Math.min(w, hh) >= HOL_UZUN_ORAN ? 'uzun' : 'derli';
  }
  // zonlama ön-vekili: BİTİŞİKLİK (kapı değil) — kapı grafı bu aşamada henüz yok
  const yatma = hepsi.filter((r) => YATMA_TIPLER.includes(r.tip)).map((r) => r.id);
  const yasam = hepsi.filter((r) => YASAM_TIPLER.includes(r.tip)).map((r) => r.id);
  const z = !yatma.length || !yasam.length ? 'tek' : (yatma.some((y) => yasam.some((s) => bit(y, s))) ? 'temas' : 'ayrik');
  // YILDIZ ön-vekili — hol TÜM odalara komşu mu (merkezi/doğrusal hol'ün geometrik ön şartı).
  // Bu ayrı bir katman olmak ZORUNDA: ölçtüm, 6 odalı programda 1629 yerleşimin yalnız 24'ü
  // (%1.5) yıldızdı ve ön-skor sıralaması onları bütçenin dışında bırakıyordu — sirkülasyon
  // ekseni tek değere çöküyordu. Kusur kapıda değil, ÖRNEKLEMEDEYDİ.
  const holIdler = holler.map((r) => r.id);
  const digerler = hepsi.filter((r) => !HOL_TIPLER.includes(r.tip)).map((r) => r.id);
  const y = holIdler.length && digerler.every((d) => holIdler.some((hh) => bit(hh, d))) ? 'yildiz' : 'zincir';
  return `${i}|${h}|${z}|${y}`;
}
