// LIFTING → MODEL KÖPRÜSÜ.
//
// 🔴 NEDEN VAR: `lifting.py` bir oda GRAFI üretiyordu (poligon + kapı/pencere ağzı mühürleri),
// plan-motor MODELİ değil. Aradaki köprü YOKTU — iki pakette de lifting çıktısını okuyan tek
// tüketici bile yoktu. Sonuç: modeller elle kuruluyor, `acikliklar` boş kalıyor ve "kapı önü
// boş kalsın" kuralı denetleyecek veri bulamadığı için SESSİZCE geçiyordu. Gerçek müşteri
// dosyasında ölçüldü (2026-08-13): açıklıklar modele girer girmez o teslimat 13 SERT İHLAL
// verdi. Boş küme üstünde koşan denetim, geçtiğini değil BAKMADIĞINI söyler.
//
// NE YAPAR:
//   1. Halkaları sadeleştirir (ızgara kuantizasyon artıklarını atar) — alan sapması denetlenir.
//   2. Düğümleri odalar arasında ortaklaştırır.
//   3. Her oda yüzünü duvara çevirir; KARŞI yüz bulunanı `ic` işaretler ve kalınlığı ÖLÇER,
//      bulunamayanı `dis` işaretler (dış kalınlık ölçülemez — beyan edilir, ölçülmüş gibi sunulmaz).
//   4. Mühürleri duvarlara bağlayıp `acikliklar` üretir. `tip` daima `gecis`:
//      kapı mı pencere mi olduğu graftan BİLİNMEZ ve UYDURULMAZ.
//
// FAIL-CLOSED: alan sapması payı aşarsa · mühürlerin yarısından azı bağlanabiliyorsa → hata.
// Eşikler `lifting-koprusu.json`'da yaşar (bkz. o dosyanın `gerekce` alanı).
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const PAKET = dirname(dirname(fileURLToPath(import.meta.url)));
export const VARSAYILAN_AYAR = join(PAKET, 'lifting-koprusu.json');

export class KopruHata extends Error {
  constructor(mesaj, rc = 1) { super(mesaj); this.rc = rc; }
}

export function ayarYukle(yol = VARSAYILAN_AYAR) {
  try { return JSON.parse(readFileSync(yol, 'utf8')); }
  catch (e) { throw new KopruHata(`köprü ayarı okunamadı (${yol}): ${e.message}`); }
}

// Nokta halka içinde mi (ışın sayma). `dis` teşhisi için: bir yüzün DIŞ tarafında oda içi
// varsa o yüz dış duvar değildir.
const noktaHalkaIcinde = ([px, py], h) => {
  let ic = false;
  for (let i = 0, j = h.length - 1; i < h.length; j = i++) {
    const [xi, yi] = h[i], [xj, yj] = h[j];
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) ic = !ic;
  }
  return ic;
};

const alan = (h) => {
  let a = 0;
  for (let i = 0; i < h.length; i++) {
    const [x1, y1] = h[i], [x2, y2] = h[(i + 1) % h.length];
    a += x1 * y2 - x2 * y1;
  }
  return Math.abs(a) / 2;
};

// Eş-doğrusal köşe temizliği: bir köşe, komşularının doğrusuna `tol`dan yakınsa atılır.
// Izgara merdivenlerini (2 cm'lik basamaklar) düz duvara indirir.
function sadelestir(halka, tol) {
  let h = halka.map(([x, y]) => [x, y]);
  let degisti = true;
  while (degisti && h.length > 3) {
    degisti = false;
    for (let i = 0; i < h.length && h.length > 3; i++) {
      const a = h[(i - 1 + h.length) % h.length], p = h[i], b = h[(i + 1) % h.length];
      const dx = b[0] - a[0], dy = b[1] - a[1];
      const uzun = Math.hypot(dx, dy);
      if (uzun < 1e-9) continue;
      const uzaklik = Math.abs((p[0] - a[0]) * dy - (p[1] - a[1]) * dx) / uzun;
      if (uzaklik <= tol) { h.splice(i, 1); degisti = true; i--; }
    }
  }
  return h;
}

// İki doğru parçasının ORTAK doğrultudaki örtüşme boyu (paralel varsayımıyla).
function ortusmeBoyu(a1, a2, b1, b2) {
  const dx = a2[0] - a1[0], dy = a2[1] - a1[1];
  const L = Math.hypot(dx, dy);
  if (L < 1e-9) return 0;
  const u = [dx / L, dy / L];
  const t = (p) => (p[0] - a1[0]) * u[0] + (p[1] - a1[1]) * u[1];
  const [b0, b3] = [t(b1), t(b2)].sort((x, y) => x - y);
  return Math.max(0, Math.min(L, b3) - Math.max(0, b0));
}

// Nokta → doğru parçası uzaklığı.
function noktaSegmentUzaklik(p, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const uzun2 = dx * dx + dy * dy;
  let t = uzun2 === 0 ? 0 : ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / uzun2;
  t = Math.max(0, Math.min(1, t));
  return { uzaklik: Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy)), oran: t };
}

const kimlik = (ad, kullanilan) => {
  let temel = String(ad).toLocaleLowerCase('tr-TR')
    .replace(/[çğıöşü]/g, (c) => ({ ç: 'c', ğ: 'g', ı: 'i', ö: 'o', ş: 's', ü: 'u' })[c])
    .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'oda';
  let id = temel, n = 2;
  while (kullanilan.has(id)) id = `${temel}_${n++}`;
  kullanilan.add(id);
  return id;
};

/**
 * @param graf  lifting çıktısı: { odalar:[{ad, m2_poligon, poligon}], muhurler:[{a,b}] }
 * @param secenekler { ayar, tipler: {odaAdı: tip}, ad, olcekAciklama }
 * @returns { model, rapor }
 */
export function grafiModeleCevir(graf, secenekler = {}) {
  const ayar = secenekler.ayar ?? ayarYukle();
  const tipler = secenekler.tipler ?? {};
  if (!Array.isArray(graf?.odalar) || !graf.odalar.length) {
    throw new KopruHata('graf içinde oda yok — köprü kuracak veri bulunamadı');
  }

  // ── 1) Sadeleştirme + alan denetimi (fail-closed) ──
  const sapmalar = [];
  const halkalar = graf.odalar.map((o) => {
    const ham = o.poligon;
    const sade = sadelestir(ham, ayar.esdogrusal_tolerans_cm);
    const a0 = alan(ham), a1 = alan(sade);
    const sapma = a0 > 0 ? Math.abs(a1 - a0) / a0 * 100 : 0;
    sapmalar.push({ oda: o.ad, kose_once: ham.length, kose_sonra: sade.length, alan_sapmasi_yuzde: +sapma.toFixed(3) });
    if (sapma > ayar.azami_alan_sapmasi_yuzde) {
      throw new KopruHata(
        `sadeleştirme '${o.ad}' odasının alanını %${sapma.toFixed(2)} değiştirdi ` +
        `(pay %${ayar.azami_alan_sapmasi_yuzde}) — model YAZILMADI.\n` +
        `  Sessizce yanlış m² üretmektense hiç üretmemek doğrudur. ` +
        `Toleransı düşür: lifting-koprusu.json · esdogrusal_tolerans_cm`,
      );
    }
    return sade;
  });

  // ── 1b) EKSEN DÖNÜŞÜMÜ: CAD (Y yukarı) → MODEL (Y aşağı) ──
  // 🔴 MODEL SÖZLEŞMESİ Y-AŞAĞIDIR. Dört tüketici bunda hemfikir:
  //   lib/svg.mjs · plan-dekor/lib/dekor-svg.mjs  → model Y'sini SVG'ye DOĞRUDAN yazar (SVG Y aşağı)
  //   lib/dxf.mjs:23 · lib/dwg.mjs:159            → CAD'e yazarken `Y = (y) => -y` ile ÇEVİRİR
  // lifting grafı ise ham CAD koordinatıdır (Y YUKARI). Çevirmezsek model sözleşmeyi ihlal eder
  // ve sonuç yalnız "PNG ters" değildir: `ciz --dxf/--dwg` çıktısı da AYNALANIR, yani mimara
  // ters bir CAD dosyası teslim edilir. Ölçüldü (2026-08-14): çevirmesiz köprü modelinden
  // üretilen DXF'te SALON, WC'nin GÜNEYİNE düşüyordu; kaynakta KUZEYİNDE.
  const tumY = halkalar.flat().map(([, y]) => y);
  const YCEV = Math.min(...tumY) + Math.max(...tumY);
  const cevir = ([x, y]) => [x, YCEV - y];
  for (let i = 0; i < halkalar.length; i++) halkalar[i] = halkalar[i].map(cevir);
  // genislik (kapi olcu yazisi beyani) DONUSUMDE DUSMEMELI — olculdu 2026-09-23: dusuyordu,
  // acikliklar sessizce duvar parcasi boyundan turetiliyordu (90 cm kapi 66 cm oldu).
  const muhurlerCevrik = (graf.muhurler ?? []).map((m) => ({ a: cevir(m.a), b: cevir(m.b), ...(Number.isFinite(m.genislik) ? { genislik: m.genislik } : {}) }));

  // ── 2) Düğüm ortaklaştırma ──
  const noktalar = {}, kayit = new Map();
  const yap = ayar.dugum_yapisma_cm;
  const nid = (x, y) => {
    const k = `${Math.round(x / yap)},${Math.round(y / yap)}`;
    if (!kayit.has(k)) { const id = `n${kayit.size + 1}`; kayit.set(k, id); noktalar[id] = [+x.toFixed(1), +y.toFixed(1)]; }
    return kayit.get(k);
  };

  const kullanilan = new Set();
  const odalar = graf.odalar.map((o, i) => ({
    id: kimlik(o.ad, kullanilan),
    ad: o.ad,
    dongu: halkalar[i].map(([x, y]) => nid(x, y)),
    guven: 'normal',
    ...(tipler[o.ad] ? { tip: tipler[o.ad] } : {}),
  }));

  // Aynı düğüme yapışan ardışık köşeler tekilleşsin (dejenere kenar üretmesin).
  for (const o of odalar) {
    o.dongu = o.dongu.filter((n, i, d) => n !== d[(i + 1) % d.length]);
    if (o.dongu.length < 3) throw new KopruHata(`'${o.ad}' odası sadeleştirmeden sonra kapanmıyor (${o.dongu.length} köşe)`);
  }

  // ── 3) Yüzler → duvarlar; karşı yüz varsa `ic` + kalınlık ÖLÇÜLÜR ──
  // `disTeshis` BAYRAĞI (varsayılan KAPALI — canlı tüketici SEDİR'in davranışı değişmesin):
  // açıkken (a) aynı odanın sardığı gerçek duvar çiftleri de eşleşir, (b) hâlâ karşı yüzü
  // olmayan yüzler SINIFLANIR. Kapalıyken bu dosyanın eski davranışı birebir korunur.
  const disTeshis = !!secenekler.disTeshis;
  const halkaAl = (o) => o.dongu.map((n) => noktalar[n]);
  const yuzler = [];
  for (const o of odalar) {
    for (let i = 0; i < o.dongu.length; i++) {
      const a = o.dongu[i], b = o.dongu[(i + 1) % o.dongu.length];
      yuzler.push({ oda: o.id, a, b, A: noktalar[a], B: noktalar[b] });
    }
  }
  const de = ayar.duvar_esleme;
  const [kMin, kMax] = de.kalinlik_araligi_cm;
  const duvarlar = [], kalinliklar = [];
  const komsuOda = new Map();   // duvar id → karşı yüzün odası (yoksa null) — kaydırma kuralının oda-çifti denetimi için
  yuzler.forEach((y, i) => {
    const dx = y.B[0] - y.A[0], dy = y.B[1] - y.A[1];
    const L = Math.hypot(dx, dy);
    let esles = null, enYakin = Infinity;
    if (L >= 1e-6) {
      for (const z of yuzler) {
        if (z.oda === y.oda && !disTeshis) continue;
        const zx = z.B[0] - z.A[0], zy = z.B[1] - z.A[1];
        const zL = Math.hypot(zx, zy);
        if (zL < 1e-6) continue;
        const sinus = Math.abs(dx * zy - dy * zx) / (L * zL);
        if (sinus > de.paralellik_sinus_tavani) continue;
        if (ortusmeBoyu(y.A, y.B, z.A, z.B) < de.asgari_ortusme_cm) continue;
        // yüzler arası mesafe: karşı yüzün orta noktasının bu yüzün DOĞRUSUNA uzaklığı
        const orta = [(z.A[0] + z.B[0]) / 2, (z.A[1] + z.B[1]) / 2];
        const u = Math.abs((orta[0] - y.A[0]) * dy - (orta[1] - y.A[1]) * dx) / L;
        if (u < kMin || u > kMax) continue;
        if (z.oda === y.oda) {
          // AYNI ODA: bu yüz ile karşı yüz arasındaki ŞERİT oda içiyse bu bir duvar çifti DEĞİL,
          // aynı odanın karşı duvarıdır (3 m'lik odanın iki yüzü) → eşleştirilmez. Şerit oda dışıysa
          // ikisi GERÇEK bir duvarın iki yüzüdür. Ölçüldü 2026-09-24: satış salonu duvarı SARDIĞI
          // için bu tür 12 gerçek çift eşleşemiyor ve ikisi de dış-duvar varsayılanını (uydurma
          // 20 cm) alıyordu; 20 cm'lik gövdeler üst üste binip 3B ölçü kapısında sapma üretiyordu.
          const om = [(y.A[0] + y.B[0]) / 2, (y.A[1] + y.B[1]) / 2];
          const nl = Math.hypot(dx, dy), nxq = -dy / nl, nyq = dx / nl;
          const yon = ((orta[0] - om[0]) * nxq + (orta[1] - om[1]) * nyq) > 0 ? 1 : -1;
          const ara = [om[0] + nxq * yon * u / 2, om[1] + nyq * yon * u / 2];
          if (odalar.some((o) => noktaHalkaIcinde(ara, halkaAl(o)))) continue;
        }
        if (u < enYakin) { enYakin = u; esles = z; }
      }
    }
    const ic = !!esles;
    komsuOda.set(`d${i + 1}`, esles ? esles.oda : null);
    if (ic) kalinliklar.push(+enYakin.toFixed(1));
    duvarlar.push({
      id: `d${i + 1}`, bas: y.a, son: y.b,
      kalinlik: ic ? Math.max(1, Math.round(enYakin)) : ayar.dis_duvar_varsayilan_kalinlik_cm,
      tip: ic ? 'ic' : 'dis',
    });
  });

  // ── 3b) `dis` TEŞHİSİ (bayrak) — karşı yüzü olmayan yüz gerçekten dış duvar mı? ──
  // 🔴 NİÇİN: `tip` tek soruyla veriliyordu (karşı yüzü var mı?) ve yoksu doğrudan DIŞ duvar
  // varsayılanını alıyordu. Ölçüldü (2026-09-24, Siirt marketi): 264 duvarın 236'sı `dis` ve
  // 236'sının kalınlığı aynı 20,0 cm = ayar BEYANI, ölçüm değil. Ölçülebilir 43 `dis` duvarın
  // yalnız 13'ü gerçekten çeperde; 30'u binanın 330-414 cm İÇİNDE (raf/tefriş konturu). Yani
  // binanın ortasındaki raf konturuna "dış duvar" deyip 20 cm et veriliyordu; bu gövdeler üst
  // üste binince 3B ölçü kapısı 18 kalınlık sapması basıyordu (gömülülük).
  //
  // ÖLÇÜT (uydurma eşik YOK — yalnız nokta-halka testi ve ayardaki ızgara payı):
  //   yüzün DIŞ tarafındaki nokta (yarım ızgara hücresi kadar dışarıda)
  //     · YALNIZ kendi odasının içinde  → KILÇIK: oda sınırının raf/tefriş konturu, duvar DEĞİL → DÜŞER
  //     · BAŞKA bir odanın içinde       → iki oda bu yüzü aralıksız PAYLAŞIYOR: gerçek bölme,
  //                                        kalınlığı BİLİNMİYOR → SORU (asla düşürülmez)
  //     · hiçbir odanın içinde değil    → CEPHE: dış duvar, kalınlık beyan (eski davranış)
  // Ters mutasyon şartı (MEDDAH 24 Eyl, şart 5): iki yanında oda olan yüz KILÇIK sayılamaz.
  const teshis = { ic_olculdu: 0, cephe: 0, soru_paylasilan_yuz: 0, dusen_kilcik: 0, kilcik_ama_aciklik_tasiyor: 0 };
  const teshisKayit = [];
  const dusecek = new Map();   // kılçık adayları — DÜŞÜRME mühür eşleşmesinden SONRA (açıklık taşıyan yüz düşmez)
  if (disTeshis) {
    const eps = ayar.dugum_yapisma_cm / 2;   // yarım ızgara hücresi — kuantizasyondan TÜRETİLDİ
    // Oda başına iç-taraf işareti: en uzun kenarda sol-normal (+1) mi iç?
    const icTaraf = new Map();
    for (const o of odalar) {
      const h = halkaAl(o);
      let enUzun = 0, bi = 0;
      for (let i = 0; i < h.length; i++) {
        const [ax, ay] = h[i], [bx, by] = h[(i + 1) % h.length];
        const uz = Math.hypot(bx - ax, by - ay);
        if (uz > enUzun) { enUzun = uz; bi = i; }
      }
      const [ax, ay] = h[bi], [bx, by] = h[(bi + 1) % h.length];
      const dx_ = bx - ax, dy_ = by - ay, L_ = Math.hypot(dx_, dy_);
      const sol = [(ax + bx) / 2 + (-dy_ / L_) * eps, (ay + by) / 2 + (dx_ / L_) * eps];
      icTaraf.set(o.id, noktaHalkaIcinde(sol, h) ? 1 : -1);
    }
    const tutulan = [];
    duvarlar.forEach((d, i) => {
      const y = yuzler[i];
      if (d.tip === 'ic') { teshis.ic_olculdu++; tutulan.push(d); return; }
      const dx = y.B[0] - y.A[0], dy = y.B[1] - y.A[1], L = Math.hypot(dx, dy);
      if (L < 1e-6) { tutulan.push(d); return; }
      // DIŞ taraf hangisi? Halka yönü sözleşmesine körü körüne güvenmiyoruz (ölçüldü 2026-09-24:
      // hem yön çıkarımı hem "kendi odasının dışı" testi tek başına yanlış sınıf verdi — biri
      // cephe 0, öteki kılçık 0). Doğrusu: yön ODA BAŞINA KALİBRE edilir (`icTaraf`): o odanın EN
      // UZUN kenarında sol-normal noktası halkanın içinde mi diye BİR KEZ ölçülür; simple-polygon
      // için iç taraf her kenarda aynı taraftır, dolayısıyla bu işaret odanın tamamı için geçerli.
      const s_ = -icTaraf.get(y.oda);
      const om = [(y.A[0] + y.B[0]) / 2, (y.A[1] + y.B[1]) / 2];
      const disNokta = [om[0] + (-dy / L) * eps * s_, om[1] + (dx / L) * eps * s_];
      const icindeOdalar = odalar.filter((o) => noktaHalkaIcinde(disNokta, halkaAl(o))).map((o) => o.id);
      if (icindeOdalar.length && icindeOdalar.every((id) => id === y.oda)) {
        dusecek.set(d.id, { duvar: d.id, sinif: 'kilcik', oda: y.oda, beyan_cm: d.kalinlik, boy_cm: +L.toFixed(1),
          gerekce: 'dış tarafında YALNIZ kendi odası var → oda sınırının iç konturu, duvar değil' });
        tutulan.push(d); return;
      }
      if (icindeOdalar.length) {
        teshis.soru_paylasilan_yuz++;
        d.teshis = { sinif: 'soru_paylasilan_yuz', paylasan: icindeOdalar.filter((id) => id !== y.oda),
          gerekce: 'iki oda bu yüzü aralıksız paylaşıyor — gerçek bölme, kalınlığı BİLİNMİYOR (beyan kullanıldı)' };
        teshisKayit.push({ duvar: d.id, sinif: 'soru_paylasilan_yuz', oda: y.oda, ...d.teshis });
        tutulan.push(d); return;
      }
      teshis.cephe++;
      tutulan.push(d);
    });
    duvarlar.length = 0; duvarlar.push(...tutulan);
  }

  // ── 4) Mühürler → açıklıklar (tip DAİMA `gecis`: kapı mı pencere mi BİLİNMİYOR) ──
  const ac = ayar.aciklik;
  const acikliklar = [];
  const kirpilan = [];
  const kaydirilan = [];
  const kapiSorulari = [];
  const kapiKaydir = !!secenekler.kapiKaydir;
  const yuzOda = new Map(duvarlar.map((d, i) => [d.id, yuzler[i]?.oda ?? null]));
  const muhurler = muhurlerCevrik;
  let eslesmeyen = 0;
  muhurler.forEach((m, mi) => {
    const boy = Math.hypot(m.b[0] - m.a[0], m.b[1] - m.a[1]);
    const orta = [(m.a[0] + m.b[0]) / 2, (m.a[1] + m.b[1]) / 2];
    if (boy < ac.asgari_genislik_cm) { eslesmeyen++; return; }
    let enIyi = null, enYakin = Infinity;
    for (const d of duvarlar) {
      const P = noktalar[d.bas], Q = noktalar[d.son];
      const dx = Q[0] - P[0], dy = Q[1] - P[1];
      const L = Math.hypot(dx, dy);
      if (L < ac.asgari_genislik_cm) continue;
      const mdx = m.b[0] - m.a[0], mdy = m.b[1] - m.a[1];
      if (Math.abs(mdx * dy - mdy * dx) / (Math.hypot(mdx, mdy) * L) > de.paralellik_sinus_tavani) continue;
      const { uzaklik, oran } = noktaSegmentUzaklik(orta, P, Q);
      if (uzaklik > ac.eslesme_uzaklik_tavani_cm) continue;
      if (uzaklik < enYakin) { enYakin = uzaklik; enIyi = { d, L, oran }; }
    }
    if (!enIyi) { eslesmeyen++; return; }
    // ── KIRPIK KAPI KAYDIRMA (MEDDAH onayı 2026-09-23, bayrak `--kapi-kaydir`) ──
    // Beyan edilen genişlik eşleşen duvar parçasına sığmıyorsa kapı en yakın SIĞAN duvara kaydırılır.
    // 🔴 Kaydırma SESSİZ OLAMAZ: mesafe (cm) + eski/yeni duvar + iki odanın adı çıktıya yazılır.
    // 🔴 Kaydırma kapıyı BAŞKA İKİ ODANIN arasına taşıyorsa RC 1: yanlış odayı birbirine açmak,
    //    kapıyı kırpmaktan kötüdür (kırpma görünür bir eksiklik, yanlış kapı görünmez bir yalandır).
    const beyanG = Number.isFinite(m.genislik) ? Math.round(m.genislik) : null;
    if (kapiKaydir && beyanG && Math.floor(enIyi.L - 2) < beyanG) {
      const odaCifti = (id, oda) => [oda, komsuOda.get(id) ?? null].filter(Boolean).sort().join('↔') || '(dış)';
      const eskiCift = odaCifti(enIyi.d.id, yuzOda.get(enIyi.d.id));
      // Adaylar: mühüre paralel ve beyanı TAŞIYABİLEN duvarlar. AYNI oda çiftindekiler ÖNCELİKLİ —
      // kural kapıyı yanlış odaya taşımasın diye önce meşru yer aranır; meşru yer yoksa en yakın
      // sığan duvar seçilir ve oda çifti denetimi onu RC 1 ile durdurur.
      const adaylar = [];
      for (const d of duvarlar) {
        const P = noktalar[d.bas], Q = noktalar[d.son];
        const dx = Q[0] - P[0], dy = Q[1] - P[1], L = Math.hypot(dx, dy);
        if (Math.floor(L - 2) < beyanG) continue;                       // sığmıyor
        const mdx = m.b[0] - m.a[0], mdy = m.b[1] - m.a[1];
        if (Math.abs(mdx * dy - mdy * dx) / (Math.hypot(mdx, mdy) * L) > de.paralellik_sinus_tavani) continue;
        const { uzaklik, oran } = noktaSegmentUzaklik(orta, P, Q);
        adaylar.push({ d, L, oran, uzaklik, cift: odaCifti(d.id, yuzOda.get(d.id)) });
      }
      adaylar.sort((x, y) => x.uzaklik - y.uzaklik);
      let aday = adaylar.find((x) => x.cift === eskiCift) ?? adaylar[0] ?? null;
      const adayUzak = aday ? aday.uzaklik : Infinity;
      if (aday && aday.d.id !== enIyi.d.id) {
        const yeniCift = odaCifti(aday.d.id, yuzOda.get(aday.d.id));
        const kayit = { beyan: beyanG, eski_duvar: enIyi.d.id, eski_duvar_boyu_cm: +enIyi.L.toFixed(1),
          yeni_duvar: aday.d.id, yeni_duvar_boyu_cm: +aday.L.toFixed(1),
          mesafe_cm: +adayUzak.toFixed(1), eski_odalar: eskiCift, yeni_odalar: yeniCift };
        if (yeniCift !== eskiCift) {
          throw new KopruHata(
            `kapı kaydırma BAŞKA İKİ ODANIN arasına taşıyor — model YAZILMADI.\n` +
            `  beyan ${beyanG} cm · ${enIyi.d.id} (${eskiCift}) → ${aday.d.id} (${yeniCift}) · ${kayit.mesafe_cm} cm\n` +
            `  Yanlış odayı birbirine açmak, kapıyı kırpmaktan KÖTÜDÜR. Kapı yazısının yerini düzeltin ya da bayrağı kapatın.`,
          );
        }
        // MESAFE SINIRI sert korumadan SONRA (MEDDAH kararı 24 Eyl, seçenek b): oda çifti denetimi
        // ÖNCE gelir — yanlış odayı açmak her mesafede yasaktır. Oda çifti doğruysa ve kaydırma
        // mesafesi ESKİ DUVARIN BOYUNU aşıyorsa kaydırma YAPILMAZ: kapı cephenin bambaşka bir
        // yerine taşınmış olurdu (Kozluk'ta 343 ve 529 cm ölçüldü). Kırpmaya dönülür VE kapı SORU
        // sınıfına yazılır: hem uzak kaydırma hem kırpma bir TAHMİNDİR; tahmini kullanıcıya
        // göstermenin yolu sorudur. Sınır türetilmiştir (eski duvarın kendi boyu), yeni sabit YOK (K01).
        if (adayUzak > enIyi.L) {
          kapiSorulari.push({ beyan: beyanG, duvar: enIyi.d.id, duvar_boyu_cm: +enIyi.L.toFixed(1),
            en_yakin_sigan: aday.d.id, mesafe_cm: +adayUzak.toFixed(1), odalar: eskiCift,
            soru: `çizimde ${beyanG} cm yazıyor, oturduğu duvar ${Math.round(enIyi.L)} cm; en yakın sığan duvar ${Math.round(adayUzak)} cm uzakta — bu kapı nerede?` });
        } else {
          kaydirilan.push(kayit);
          enIyi = aday;
        }
      }
    }
    // BEYAN EDİLEN GENİŞLİK ÖNCELİKLİ (2026-09-23): kapı ölçü yazısı varsa açıklık genişliği
    // ondan gelir. Duvar parçası beyandan kısaysa kırpmak zorunludur (model doğrulaması
    // açıklığın duvarı taşmasını reddeder) ama SESSİZ OLAMAZ: her kırpma rapora yazılır.
    const beyan = Number.isFinite(m.genislik) ? Math.round(m.genislik) : null;
    const tavan = Math.floor(enIyi.L - 2);
    const istenen = beyan ?? Math.round(boy);
    const genislik = Math.min(istenen, tavan);
    if (beyan && genislik < beyan) kirpilan.push({ beyan, uygulanan: genislik, duvar: enIyi.d.id, duvar_boyu_cm: +enIyi.L.toFixed(1) });
    if (genislik < ac.asgari_genislik_cm) { eslesmeyen++; return; }
    const yari = genislik / 2 / enIyi.L;
    const oran = Math.min(1 - yari - 0.001, Math.max(yari + 0.001, enIyi.oran));
    acikliklar.push({ id: `a${mi + 1}`, tip: 'gecis', duvar: enIyi.d.id, oran: +oran.toFixed(4), genislik,
      ...(beyan ? { genislik_beyan: beyan } : {}) });
  });

  const oran = muhurler.length ? (muhurler.length - eslesmeyen) / muhurler.length : 1;
  if (kapiSorulari.length) {
    console.error(`  ? ${kapiSorulari.length} kapı SORU sınıfında (uzak kaydırma yapılmadı, kırpıldı):`);
    for (const k of kapiSorulari) console.error(`     ${k.soru} · duvar ${k.duvar} · odalar ${k.odalar}`);
  }
  if (kaydirilan.length) {
    console.error(`  ↔ ${kaydirilan.length} kapı SIĞAN duvara KAYDIRILDI (--kapi-kaydir):`);
    for (const k of kaydirilan) console.error(`     beyan ${k.beyan} cm · ${k.eski_duvar} (boy ${k.eski_duvar_boyu_cm}) → ${k.yeni_duvar} (boy ${k.yeni_duvar_boyu_cm}) · ${k.mesafe_cm} cm · odalar ${k.eski_odalar}`);
  }
  if (kirpilan.length) {
    console.error(`  ⚠ ${kirpilan.length} açıklık BEYAN EDİLEN genişlikten dar kırpıldı (duvar parçası kısa):`);
    for (const k of kirpilan.slice(0, 8)) console.error(`     beyan ${k.beyan} → ${k.uygulanan} cm · duvar ${k.duvar} boyu ${k.duvar_boyu_cm} cm`);
  }
  if (muhurler.length && oran < ac.asgari_eslesme_orani) {
    throw new KopruHata(
      `mühürlerin yalnız %${(oran * 100).toFixed(0)}'i duvara bağlanabildi ` +
      `(asgari %${ac.asgari_eslesme_orani * 100}) — model YAZILMADI.\n` +
      `  Yarım açıklık kümesi, açıklıksız modelden TEHLİKELİDİR: eksikliği görünmez kılar.`,
    );
  }

  // ── 4b) Kılçık DÜŞÜRME (mühür eşleşmesinden SONRA) ──
  // Açıklık taşıyan bir yüz kılçık bile olsa DÜŞMEZ: kapıyı sessizce kaybetmek, fazla duvardan
  // kötüdür. Böyle bir yüz kayda `kilcik_ama_aciklik_tasiyor` olarak geçer ve raporda görünür.
  if (disTeshis && dusecek.size) {
    const acikliktaki = new Set(acikliklar.map((a) => a.duvar));
    const kalan = [];
    for (const d of duvarlar) {
      const k = dusecek.get(d.id);
      if (!k) { kalan.push(d); continue; }
      if (acikliktaki.has(d.id)) {
        teshis.kilcik_ama_aciklik_tasiyor++;
        d.teshis = { sinif: 'kilcik_ama_aciklik_tasiyor', gerekce: `${k.gerekce} — AMA açıklık taşıyor, düşürülmedi` };
        teshisKayit.push({ ...k, sinif: 'kilcik_ama_aciklik_tasiyor' });
        kalan.push(d); continue;
      }
      teshis.dusen_kilcik++; teshisKayit.push(k);
    }
    // FAIL-CLOSED: teşhis bütün duvarları yutarsa model yazılmaz (sessiz boş plan YASAK)
    if (!kalan.length) throw new KopruHata('`dis` teşhisi bütün duvarları düşürdü — model YAZILMADI');
    duvarlar.length = 0; duvarlar.push(...kalan);
  }

  const icSayi = duvarlar.filter((d) => d.tip === 'ic').length;
  kalinliklar.sort((a, b) => a - b);
  const model = {
    surum: '1.0',
    ad: secenekler.ad ?? 'lifting köprüsü',
    birim: 'cm',
    olcek: { kaynak: 'cad', aciklama: secenekler.olcekAciklama ?? 'lifting oda grafından türetildi (graf-koprusu)' },
    noktalar, duvarlar, odalar, acikliklar,
    ...(disTeshis ? { dis_teshis: { ozet: teshis, kayit: teshisKayit } } : {}),
    ...(kapiKaydir && kaydirilan.length ? { kapi_kaydirma: kaydirilan } : {}),
    ...(kapiKaydir && kapiSorulari.length ? { kapi_sorulari: kapiSorulari } : {}),
  };
  const rapor = {
    oda: odalar.length,
    dugum: Object.keys(noktalar).length,
    duvar: duvarlar.length,
    duvar_ic: icSayi,
    duvar_dis: duvarlar.length - icSayi,
    olculen_ic_kalinlik_cm: kalinliklar.length
      ? { en_az: kalinliklar[0], ortanca: kalinliklar[Math.floor(kalinliklar.length / 2)], en_cok: kalinliklar[kalinliklar.length - 1] }
      : null,
    dis_duvar_kalinligi: { deger: ayar.dis_duvar_varsayilan_kalinlik_cm, durum: 'ÖLÇÜLMEDİ — beyan (dış yüz grafta yok)' },
    muhur: muhurler.length,
    aciklik: acikliklar.length,
    aciklik_eslesmeyen: eslesmeyen,
    aciklik_tipi: 'hepsi `gecis` — kapı/pencere ayrımı graftan BİLİNMEZ, uydurulmadı',
    tipsiz_oda: odalar.filter((o) => !o.tip).map((o) => o.ad),
    sadelestirme: sapmalar,
    ...(kapiKaydir ? { kapi_kaydirma: kaydirilan, kapi_sorulari: kapiSorulari } : {}),
    ...(disTeshis ? { dis_teshis: teshis } : {}),
  };
  return { model, rapor };
}
