// Model yükleme + doğrulama. FAIL-CLOSED: hata varsa hiçbir çıktı üretilmez (RC≠0).
// Şema: model-sema.md — köşe(nokta) → duvar → oda grafı, açıklıklar {duvar, oran} ile duvara bağlı.
import { readFileSync } from 'fs';
import { uzunluk, alanM2 } from './geometri.mjs';
import { odaAciklikOzeti } from './turet.mjs';

export const GUVEN_DEGERLERI = ['normal', 'dusuk'];
export const ACIKLIK_TIPLERI = ['kapi', 'pencere', 'gecis'];
// oda.tip (opsiyonel, ŞAKÜL FAZ 1) — kural-seti "uygulanir" eşleşmesinin ayırt-edicisi.
// Tanınmayan tip = UYARI (hata değil: alan opsiyonel, eski modeller kırılmaz — additive söz).
export const ODA_TIPLERI = ['oturma_odasi', 'yatak_odasi', 'mutfak', 'banyo', 'wc', 'hol', 'antre', 'balkon', 'kiler', 'diger'];
// aciklik.rol (opsiyonel, ŞAKÜL FAZ 1) — kapının İŞLEVİ (geometriden türetilemez: daire girişi
// ile balkon kapısı ikisi de "dış duvarda kapı"dır; md.39 eşikleri işleve göre ayrışır)
export const ACIKLIK_ROLLERI = ['giris', 'balkon', 'servis', 'diger'];

// beyan_m2 ile hesaplanan alan arasındaki tolerans:
// guven=normal → aşılırsa HATA (fail-closed) · guven=dusuk → uyarı, çizimde DÜŞÜK-GÜVEN işareti
export const BEYAN_TOLERANSI = 0.05;

export function modelYukle(yol) {
  let ham;
  try {
    ham = readFileSync(yol, 'utf8');
  } catch {
    throw new MotorHata(`model dosyası okunamadı: ${yol}`, 1);
  }
  let model;
  try {
    model = JSON.parse(ham);
  } catch (e) {
    throw new MotorHata(`model JSON değil: ${yol} — ${e.message}`, 1);
  }
  return model;
}

export class MotorHata extends Error {
  constructor(mesaj, rc = 1) { super(mesaj); this.rc = rc; }
}

export function dogrula(model) {
  const hatalar = [];
  const uyarilar = [];
  const H = (m) => hatalar.push(m);
  const U = (m) => uyarilar.push(m);

  if (!model || typeof model !== 'object') return { hatalar: ['model bir nesne değil'], uyarilar };
  if (model.birim !== 'cm') H(`birim "cm" olmalı (gelen: ${JSON.stringify(model.birim)}) — ölçek doğrulanamıyor`);
  if (!model.surum) H('surum alanı yok');
  if (!model.olcek || !model.olcek.kaynak) H('olcek.kaynak yok — ölçünün nereden geldiği beyan edilmeli (tablo|saha|cad)');

  const noktalar = model.noktalar ?? {};
  for (const [id, p] of Object.entries(noktalar)) {
    if (!Array.isArray(p) || p.length !== 2 || !p.every(Number.isFinite)) H(`nokta "${id}" [x,y] sayı çifti değil`);
  }

  const duvarlar = model.duvarlar ?? [];
  const duvarIdx = new Map();
  for (const d of duvarlar) {
    if (!d.id) { H('id\'siz duvar var'); continue; }
    if (duvarIdx.has(d.id)) H(`duvar id tekrarı: ${d.id}`);
    duvarIdx.set(d.id, d);
    if (!noktalar[d.bas]) H(`duvar ${d.id}: bas noktası "${d.bas}" tanımsız`);
    if (!noktalar[d.son]) H(`duvar ${d.id}: son noktası "${d.son}" tanımsız`);
    if (noktalar[d.bas] && noktalar[d.son]) {
      const L = uzunluk(noktalar[d.bas], noktalar[d.son]);
      if (L < 1) H(`duvar ${d.id}: uzunluk ${L.toFixed(1)} cm — sıfıra yakın`);
    }
    if (!(d.kalinlik > 0)) H(`duvar ${d.id}: kalinlik > 0 olmalı`);
  }

  const odalar = model.odalar ?? [];
  const odaIds = new Set();
  if (odalar.length === 0) H('hiç oda yok');
  for (const o of odalar) {
    if (!o.id) { H('id\'siz oda var'); continue; }
    if (odaIds.has(o.id)) H(`oda id tekrarı: ${o.id}`);
    odaIds.add(o.id);
    const dongu = o.dongu ?? [];
    if (dongu.length < 3) { H(`oda ${o.id}: döngü ${dongu.length} noktalı — kapalı alan değil`); continue; }
    let eksik = false;
    for (const nid of dongu) if (!noktalar[nid]) { H(`oda ${o.id}: döngü noktası "${nid}" tanımsız`); eksik = true; }
    if (eksik) continue;
    for (let i = 0; i < dongu.length; i++) {
      if (dongu[i] === dongu[(i + 1) % dongu.length]) H(`oda ${o.id}: ardışık tekrar eden nokta "${dongu[i]}"`);
    }
    const koseler = dongu.map((nid) => noktalar[nid]);
    const alan = alanM2(koseler);
    if (alan < 0.25) H(`oda ${o.id}: alan ${alan.toFixed(2)} m² — kapalı döngü değil ya da dejenere`);
    if (o.guven && !GUVEN_DEGERLERI.includes(o.guven)) H(`oda ${o.id}: guven "${o.guven}" tanımsız (${GUVEN_DEGERLERI.join('|')})`);
    if (o.tip !== undefined && !ODA_TIPLERI.includes(o.tip)) U(`oda ${o.id}: tip "${o.tip}" tanınmıyor (${ODA_TIPLERI.join('|')}) — kural denetiminde eşleşmez`);
    if (Number.isFinite(o.beyan_m2) && alan > 0) {
      const sapma = Math.abs(alan - o.beyan_m2) / o.beyan_m2;
      const mesaj = `oda ${o.id}: hesaplanan ${alan.toFixed(2)} m² ↔ beyan ${o.beyan_m2} m² (sapma %${(sapma * 100).toFixed(1)})`;
      if (sapma > BEYAN_TOLERANSI) {
        if (o.guven === 'dusuk') U(`${mesaj} — DÜŞÜK GÜVEN işaretli, saha ölçümü bekliyor`);
        else H(`${mesaj} — tolerans %${BEYAN_TOLERANSI * 100} aşıldı. Ya geometri yanlış ya beyan; ölçek doğrulanamadan çıktı ÜRETİLMEZ`);
      }
    }
  }

  const acikliklar = model.acikliklar ?? [];
  const aIds = new Set();
  for (const a of acikliklar) {
    if (!a.id) { H('id\'siz açıklık var'); continue; }
    if (aIds.has(a.id)) H(`açıklık id tekrarı: ${a.id}`);
    aIds.add(a.id);
    if (!ACIKLIK_TIPLERI.includes(a.tip)) H(`açıklık ${a.id}: tip "${a.tip}" tanımsız (${ACIKLIK_TIPLERI.join('|')})`);
    if (a.rol !== undefined && !ACIKLIK_ROLLERI.includes(a.rol)) U(`açıklık ${a.id}: rol "${a.rol}" tanınmıyor (${ACIKLIK_ROLLERI.join('|')}) — kural denetiminde eşleşmez`);
    const d = duvarIdx.get(a.duvar);
    if (!d) { H(`açıklık ${a.id}: duvar "${a.duvar}" tanımsız`); continue; }
    if (!(a.oran > 0 && a.oran < 1)) H(`açıklık ${a.id}: oran (0,1) aralığında olmalı (gelen: ${a.oran})`);
    if (!(a.genislik > 0)) H(`açıklık ${a.id}: genislik > 0 olmalı`);
    if (noktalar[d.bas] && noktalar[d.son] && a.genislik > 0 && a.oran > 0 && a.oran < 1) {
      const L = uzunluk(noktalar[d.bas], noktalar[d.son]);
      const merkez = a.oran * L;
      if (merkez - a.genislik / 2 < -0.5 || merkez + a.genislik / 2 > L + 0.5) {
        H(`açıklık ${a.id}: duvar ${a.duvar} (${L.toFixed(0)} cm) dışına taşıyor (merkez ${merkez.toFixed(0)}, genişlik ${a.genislik})`);
      }
    }
  }

  // B-001 (SEDİR bulgusu, 2026-08-03): kapı KANADI olmayan hacim — mimari uyarı.
  // Hata DEĞİL (meşru istisna var: geçiş boşluğu, niş, açık plan) → RC değişmez, additive.
  // Yalnız geometrik taban sağlamken koşar; türetme çökerse sessiz-yeşil yerine dürüst uyarı.
  if (!hatalar.length && odalar.length) {
    try {
      const ozet = odaAciklikOzeti(model);
      for (const o of odalar) {
        const s = ozet.get(o.id);
        if (s && s.kapi === 0) U(`oda ${o.id}: hiç kapı kanadı yok${s.gecis ? ` (${s.gecis} geçiş boşluğu var)` : ''} — B-001; ayrıntı için: denetle`);
      }
    } catch (e) {
      U(`B-001 kanat-kontrolü koşulamadı: ${e.message} — kontrol edilmemiş sayın (yeşil DEĞİL)`);
    }
  }

  return { hatalar, uyarilar };
}

// Doğrula; hata varsa MotorHata fırlat (fail-closed tek kapı)
export function dogrulaVeyaDur(model, baglam = 'model') {
  const { hatalar, uyarilar } = dogrula(model);
  for (const u of uyarilar) console.error(`⚠ ${u}`);
  if (hatalar.length) {
    for (const h of hatalar) console.error(`✗ ${h}`);
    throw new MotorHata(`${baglam}: ${hatalar.length} doğrulama hatası — çıktı üretilmedi (fail-closed)`, 1);
  }
  return { uyarilar };
}

// Oda alan raporu (hesaplanan)
export function odaRaporu(model) {
  const rapor = [];
  for (const o of model.odalar ?? []) {
    const koseler = (o.dongu ?? []).map((nid) => model.noktalar[nid]).filter(Boolean);
    if (koseler.length < 3) continue;
    rapor.push({
      oda: o.id, ad: o.ad ?? o.id,
      m2: +alanM2(koseler).toFixed(2),
      beyan_m2: Number.isFinite(o.beyan_m2) ? o.beyan_m2 : null,
      guven: o.guven ?? 'normal',
    });
  }
  return rapor;
}
