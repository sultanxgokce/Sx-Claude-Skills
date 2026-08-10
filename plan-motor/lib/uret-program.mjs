// ÜRETİM FAZ A · girdi kapısı — "program"ı (boş sınır + oda listesi) doğrular.
// FAIL-CLOSED: sığmayan/tanınmayan/kural-altı program için üretim BAŞLAMAZ (RC 1).
// Sığmayan programa "sığdım" demek, motorun tüm disiplinini çürütür (DOĞUM-PROMPTU §6/V6).
// Eşikler burada YAŞAMAZ: kural-seti VERİSİNDEN okunur (kuralEsikleri) — sınavı okumak serbest,
// DEĞİŞTİRMEK yasak (AGENT.md "sınavı değiştiremezsin").
import { readFileSync } from 'fs';
import { alanM2, alanCm2 } from './geometri.mjs';
import { MotorHata, ODA_TIPLERI } from './model.mjs';
import { rektilineerDenetle, dikeyAyristir, parcalarBagliMi } from './uret-sinir.mjs';

export const TAVAN_ODA = 8;   // FAZ A enumerasyon tavanı — üstü dürüst RC 1
export const TAVAN_PARCA = 4; // FAZ B2 sınır parçası tavanı (L=2, U=3; üstü kombinatorik patlar)

export function programYukle(yol) {
  let ham;
  try { ham = readFileSync(yol, 'utf8'); }
  catch { throw new MotorHata(`program dosyası okunamadı: ${yol}`, 1); }
  try { return JSON.parse(ham); }
  catch (e) { throw new MotorHata(`program JSON değil: ${yol} — ${e.message}`, 1); }
}

// ── Kural-setinden eşik ÇIKARIMI (salt-okur) ─────────────────────────────────
// Üretici, geçmesi gereken sınavın sayılarını kural VERİSİNDEN öğrenir; kodda sabit sayı
// tutmaz. Kural-seti değişirse üretici kendiliğinden ona uyar.
export function kuralEsikleri(ks) {
  const oda = {};   // tip → { m2, dar }
  const kapi = { ic: 0, giris: 0 };
  const isikli = new Set(); // doğrudan ışık şartına tabi tipler
  for (const k of ks.kurallar ?? []) {
    const u = k.uygulanir ?? {};
    const tipler = u['oda.tip'] === undefined ? [] : [].concat(u['oda.tip']);
    for (const t of tipler) {
      const e = (oda[t] ??= { m2: 0, dar: 0 });
      for (const s of k.sart ?? []) {
        if (s.op !== '>=' || typeof s.deger !== 'number') continue;
        if (s.olcut === 'net_alan_m2') e.m2 = Math.max(e.m2, s.deger);
        if (s.olcut === 'dar_kenar_cm') e.dar = Math.max(e.dar, s.deger);
      }
      if ((k.sart ?? []).some((s) => s.olcut === 'dogrudan_isik' && s.deger === true)) isikli.add(t);
    }
    if (u['aciklik.tip'] === 'kapi') {
      const g = (k.sart ?? []).find((s) => s.olcut === 'genislik_cm' && s.op === '>=');
      if (!g) continue;
      if (u['aciklik.rol'] === 'giris') kapi.giris = Math.max(kapi.giris, g.deger);
      else if (u['aciklik.dis'] === false) kapi.ic = Math.max(kapi.ic, g.deger);
    }
  }
  // Kural-seti bir eşik beyan etmiyorsa üretim yine de mimari bir kanat genişliği seçmek
  // zorunda: 90/100 üretim-varsayılanıdır, kural DEĞİLDİR (kural varsa o üstündür).
  return { oda, kapi: { ic: Math.max(kapi.ic, 90), giris: Math.max(kapi.giris, 100) }, isikli };
}

// Sınır EKSEN-HİZALI (rektilineer) olmak zorunda; dikdörtgen olmak zorunda DEĞİL (FAZ B2).
// L/U sınır dikey süpürmeyle dikdörtgen parçalara ayrılır (lib/uret-sinir.mjs) ve yerleşim
// her parçada FAZ A motoruyla yürür. Eğik/yaylı sınır hâlâ kapsam DIŞI ve dürüstçe reddedilir.
function sinirCoz(sinir) {
  const hata = rektilineerDenetle(sinir);
  if (hata) return { hata };
  const parcalar = dikeyAyristir(sinir);
  if (!parcalar.length) return { hata: 'sınır dikdörtgen parçalara ayrıştırılamadı' };
  if (parcalar.length > TAVAN_PARCA) {
    return { hata: `sınır ${parcalar.length} dikdörtgen parçaya ayrıştı — FAZ B tavanı ${TAVAN_PARCA} (oda-parça ataması kombinatorik olarak patlar; girintili sınırı sadeleştirin)` };
  }
  if (!parcalarBagliMi(parcalar)) return { hata: 'sınır parçaları duvar paylaşmıyor — kopuk sınırdan tek daire planı üretilemez' };
  const xs = sinir.map((p) => p[0]), ys = sinir.map((p) => p[1]);
  const kutu = { x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) };
  return { parcalar, kutu, dikdortgen: parcalar.length === 1, alan_m2: alanCm2(sinir) / 10000 };
}

export function programDogrula(program, esikler) {
  const hatalar = [], uyarilar = [];
  const H = (m) => hatalar.push(m);
  const U = (m) => uyarilar.push(m);

  if (!program || typeof program !== 'object') return { hatalar: ['program bir nesne değil'], uyarilar, norm: null };
  if (program.birim !== 'cm') H(`program.birim "cm" olmalı (gelen: ${JSON.stringify(program.birim)})`);

  // ── ÖLÇEK KAPISI (Sultan kararı 2026-08-04) ────────────────────────────────
  // Bu motor İÇ MEKÂN ölçeğindedir: bir katın/dairenin içi. BİNA ölçeği (emsal · TAKS ·
  // çekme mesafesi · kat adedi · cephe · taşıyıcı · çekirdek · otopark) AYRI BİR SİSTEM
  // olacak ve bu paket o alana GİRMEZ. Bina-ölçeği bir girdiyi sessizce yok saymak, iç
  // mekân cevabını bina cevabı sanmaya yol açardı — o yüzden dürüstçe reddedilir.
  const BINA_OLCEGI = {
    emsal: 'emsal/KAKS', kaks: 'emsal/KAKS', taks: 'taban alanı kat sayısı (TAKS)',
    cekme_mesafesi: 'çekme mesafesi', cekme_mesafeleri: 'çekme mesafesi',
    kat_adedi: 'kat adedi', kat_yuksekligi: 'kat yüksekliği', bina_derinligi: 'bina derinliği',
    parsel: 'parsel/imar durumu', imar_durumu: 'parsel/imar durumu',
    cephe: 'cephe', cati: 'çatı', tasiyici: 'taşıyıcı sistem', tasiyici_sistem: 'taşıyıcı sistem',
    cekirdek: 'merdiven/asansör çekirdeği', merdiven: 'merdiven', asansor: 'asansör',
    otopark: 'otopark', siginak: 'sığınak', vaziyet: 'vaziyet planı',
  };
  const binaAlanlari = Object.keys(program).filter((k) => BINA_OLCEGI[k]);
  if (binaAlanlari.length) {
    H(`KAPSAM DIŞI — bina ölçeği: ${binaAlanlari.map((k) => `"${k}" (${BINA_OLCEGI[k]})`).join(', ')}. ` +
      'Bu motor İÇ MEKÂN ölçeğinde çalışır (bir katın/dairenin içi: oda yerleşimi, sirkülasyon, kapı-pencere, ' +
      'PAİY iç mekân asgarileri). Bina ölçeği AYRI BİR SİSTEMdir — ayrı kural tabanı, ayrı girdi (parsel + imar ' +
      'durumu), ayrı çıktı (kütle/vaziyet planı). Bu alanları yok sayıp plan üretmek, iç mekân cevabını bina ' +
      'cevabı sanmanıza yol açardı.');
  }

  const sinir = sinirCoz(program.sinir);
  if (sinir.hata) H(`sinir: ${sinir.hata}`);

  const odalar = program.odalar ?? [];
  if (!Array.isArray(odalar) || odalar.length === 0) H('odalar: en az 1 oda gerekli');
  if (odalar.length > TAVAN_ODA) H(`odalar: ${odalar.length} oda — FAZ A tavanı ${TAVAN_ODA} (enumerasyon patlar; budanmış arama sessizce kötü plan üretir)`);

  const idler = new Set();
  const norm = [];
  for (const o of odalar) {
    if (!o || !o.id) { H('id\'siz oda var'); continue; }
    if (idler.has(o.id)) H(`oda id tekrarı: ${o.id}`);
    idler.add(o.id);
    if (!ODA_TIPLERI.includes(o.tip)) { H(`oda ${o.id}: tip "${o.tip}" tanımsız (${ODA_TIPLERI.join('|')}) — tipsiz oda denetimde KÖR NOKTA düşer`); continue; }
    if (!(o.hedef_m2 > 0)) { H(`oda ${o.id}: hedef_m2 > 0 olmalı (gelen: ${o.hedef_m2})`); continue; }
    const e = esikler.oda[o.tip] ?? { m2: 0, dar: 0 };
    if (o.hedef_m2 < e.m2) H(`oda ${o.id} (${o.tip}): hedef_m2 ${o.hedef_m2} — kural asgarisi ${e.m2} m² altında; bu program TANIMI GEREĞİ denetimden geçemez`);
    const minDar = Math.max(e.dar, Number.isFinite(o.min_dar_kenar_cm) ? o.min_dar_kenar_cm : 0);
    if (Number.isFinite(o.min_dar_kenar_cm) && o.min_dar_kenar_cm < e.dar) {
      U(`oda ${o.id}: min_dar_kenar_cm ${o.min_dar_kenar_cm} kural asgarisi ${e.dar} cm'in altında — kural üstün sayıldı (${e.dar})`);
    }
    // Bir oda hem asgari alanı hem asgari dar kenarı sağlamalı → asgari alan en az dar²
    const zeminM2 = Math.max(e.m2, alanM2([[0, 0], [minDar, 0], [minDar, minDar], [0, minDar]]));
    norm.push({ id: o.id, ad: o.ad ?? o.id, tip: o.tip, hedef_m2: o.hedef_m2, min_dar_kenar_cm: minDar, asgari_m2: zeminM2 });
  }

  for (const c of program.komsuluk ?? []) {
    if (!Array.isArray(c) || c.length !== 2 || !idler.has(c[0]) || !idler.has(c[1])) H(`komsuluk ${JSON.stringify(c)}: iki tanınan oda id'si olmalı`);
  }
  if (program.giris_kenari !== undefined && ![0, 1, 2, 3].includes(program.giris_kenari)) {
    H(`giris_kenari ${JSON.stringify(program.giris_kenari)} — 0..3 olmalı (0 alt, 1 sağ, 2 üst, 3 sol)`);
  }

  // ── Sığma kapısı — V6'nın kalbi ────────────────────────────────────────────
  if (!sinir.hata && norm.length && !hatalar.length) {
    // Alan POLİGONDAN (shoelace) hesaplanır, bbox'tan DEĞİL: L sınırda bbox alanı gerçek
    // alandan büyüktür ve sığmayan programı "sığdı" sanırdık (fail-open olurdu).
    const sinirM2 = sinir.alan_m2;
    const asgariToplam = norm.reduce((s, o) => s + o.asgari_m2, 0);
    const hedefToplam = norm.reduce((s, o) => s + o.hedef_m2, 0);
    if (asgariToplam > sinirM2) {
      H(`SIĞMIYOR: ${norm.length} odanın kural-asgari toplamı ${asgariToplam.toFixed(2)} m² > sınır ${sinirM2.toFixed(2)} m² — bu program hiçbir yerleşimle geçemez`);
    } else if (hedefToplam > sinirM2) {
      H(`SIĞMIYOR: hedef alan toplamı ${hedefToplam.toFixed(2)} m² > sınır ${sinirM2.toFixed(2)} m²`);
    } else if (hedefToplam < sinirM2 * 0.5) {
      U(`hedef toplam ${hedefToplam.toFixed(2)} m², sınırın %${((hedefToplam / sinirM2) * 100).toFixed(0)}'i — odalar hedefin çok üstünde çıkacak (slicing sınırı tamamen böler)`);
    }
    // Dar kenar × sınır: oda TEK BİR parçanın içinde yaşar → en geniş parçanın kısa kenarını
    // aşan oda hiçbir bölmede sığmaz. (Dikdörtgen sınırda bu, eski davranışın aynısıdır.)
    const enGenisKisa = Math.max(...sinir.parcalar.map((p) => Math.min(p.x1 - p.x0, p.y1 - p.y0)));
    for (const o of norm) {
      if (o.min_dar_kenar_cm > enGenisKisa) H(`SIĞMIYOR: oda ${o.id} dar kenar asgarisi ${o.min_dar_kenar_cm} cm > en geniş sınır parçasının kısa kenarı ${enGenisKisa} cm`);
    }
    // Her parça en az bir oda almalı; oda sayısı parça sayısından azsa yerleşim kurulamaz
    if (norm.length < sinir.parcalar.length) {
      H(`SIĞMIYOR: sınır ${sinir.parcalar.length} dikdörtgen parçaya ayrılıyor ama ${norm.length} oda var — her parça en az bir oda almalı`);
    }
  }

  return { hatalar, uyarilar, norm: hatalar.length ? null : { rect: sinir.kutu, parcalar: sinir.parcalar, dikdortgen: sinir.dikdortgen, sinir_m2: sinir.alan_m2, odalar: norm, komsuluk: (program.komsuluk ?? []).map((c) => [...c]), giris_kenari: program.giris_kenari, ad: program.ad ?? null, duvar: { dis: program.duvar_kalinlik?.dis ?? 20, ic: program.duvar_kalinlik?.ic ?? 10 } } };
}
