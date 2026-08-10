// ÖLÇEK ÇIPASI KAPISI — görselden/elle kurulan modelin uydurma olmadığını kanıtlar.
//
// Neden var: CAD'den türeyen model ölçüsünü dosyadan alır, kanıtı içindedir. Görselden kurulan
// model ise bir İDDİADIR. Tek bir bilinen ölçüye uydurmak kolaydır (o ölçüyü tuttururum, gerisi
// serbest). Bu yüzden EN AZ İKİ çıpa istenir ve BİRİ ÖTEKİNİ ÇAPRAZ DOĞRULAR: model tutarlıysa
// her iki çıpanın sapması küçük olur; ölçek uydurulmuşsa ikinci çıpa tutmaz.
//
// Fail-closed: çıpa sayısı < 2 · sapma > tolerans · çıpa modele bağlanamıyor → RC 1.
import { readFileSync } from 'fs';
import { uzunluk } from './geo.mjs';

export const VARSAYILAN_TOLERANS_YUZDE = 3;

export function cipalariYukle(yol) {
  const ham = JSON.parse(readFileSync(yol, 'utf8'));
  const liste = Array.isArray(ham) ? ham : ham.cipalar;
  if (!Array.isArray(liste)) throw new Error('çıpa dosyası: dizi ya da {cipalar:[...]} bekleniyor');
  return liste;
}

// Bir çıpayı modelden ÖLÇ. Çıpa iki biçimde verilebilir:
//   { ad, duvar: "d_sol_1", gercek_cm: 355 }
//   { ad, noktalar: ["n_0_0","n_450_0"], gercek_cm: 450 }
function cipayiOlc(cipa, model) {
  if (cipa.duvar) {
    const d = (model.duvarlar ?? []).find((x) => x.id === cipa.duvar);
    if (!d) throw new Error(`çıpa "${cipa.ad}": modelde duvar yok — ${cipa.duvar}`);
    const a = model.noktalar[d.bas], b = model.noktalar[d.son];
    if (!a || !b) throw new Error(`çıpa "${cipa.ad}": duvar ${cipa.duvar} tanımsız noktaya bakıyor`);
    return uzunluk(a, b);
  }
  if (Array.isArray(cipa.noktalar) && cipa.noktalar.length === 2) {
    const [p, q] = cipa.noktalar.map((n) => model.noktalar[n]);
    if (!p || !q) throw new Error(`çıpa "${cipa.ad}": modelde nokta yok — ${cipa.noktalar.join(', ')}`);
    return uzunluk(p, q);
  }
  throw new Error(`çıpa "${cipa.ad}": "duvar" ya da iki elemanlı "noktalar" gerekir`);
}

// Çıpanın ekseni — çapraz doğrulamanın dik eksende olması tercih edilir (aynı eksende iki çıpa
// aynı hatayı iki kez ölçebilir; dik eksen bağımsız kanıttır).
function eksen(cipa, model) {
  let a, b;
  if (cipa.duvar) {
    const d = model.duvarlar.find((x) => x.id === cipa.duvar);
    a = model.noktalar[d.bas]; b = model.noktalar[d.son];
  } else {
    [a, b] = cipa.noktalar.map((n) => model.noktalar[n]);
  }
  const dx = Math.abs(b[0] - a[0]), dy = Math.abs(b[1] - a[1]);
  if (dx < 1e-6) return 'dikey';
  if (dy < 1e-6) return 'yatay';
  return 'egik';
}

export function cipalariDogrula(model, cipalar, { tolerans = VARSAYILAN_TOLERANS_YUZDE } = {}) {
  const hatalar = [];
  const uyarilar = [];

  if (cipalar.length < 2) {
    hatalar.push(`en az 2 ölçek çıpası gerekir, ${cipalar.length} verildi — tek çıpa ölçeği DOĞRULAMAZ, yalnız tanımlar`);
    return { gecti: false, hatalar, uyarilar, olcumler: [] };
  }

  const olcumler = [];
  for (const c of cipalar) {
    if (!c.ad) { hatalar.push('adsız çıpa'); continue; }
    if (!(c.gercek_cm > 0)) { hatalar.push(`çıpa "${c.ad}": gercek_cm pozitif olmalı`); continue; }
    let modelCm;
    try { modelCm = cipayiOlc(c, model); }
    catch (e) { hatalar.push(e.message); continue; }
    const sapmaYuzde = Math.abs(modelCm - c.gercek_cm) / c.gercek_cm * 100;
    olcumler.push({
      ad: c.ad, kaynak: c.kaynak ?? null,
      gercek_cm: c.gercek_cm, model_cm: +modelCm.toFixed(1),
      sapma_yuzde: +sapmaYuzde.toFixed(2),
      eksen: eksen(c, model),
      gecti: sapmaYuzde <= tolerans,
    });
  }

  for (const o of olcumler) {
    if (!o.gecti) {
      hatalar.push(`çıpa "${o.ad}": model ${o.model_cm} cm, beyan ${o.gercek_cm} cm → %${o.sapma_yuzde} sapma (tavan %${tolerans})`);
    }
  }

  const eksenler = new Set(olcumler.map((o) => o.eksen));
  if (olcumler.length >= 2 && eksenler.size === 1 && !eksenler.has('egik')) {
    uyarilar.push(`tüm çıpalar aynı eksende (${[...eksenler][0]}) — dik eksende bir çıpa daha, ölçeği bağımsız olarak doğrulardı`);
  }
  if (olcumler.some((o) => o.eksen === 'egik')) {
    uyarilar.push('eğik çıpa var — eksen-hizalı çıpa daha güvenilir ölçüm verir');
  }

  return { gecti: hatalar.length === 0, hatalar, uyarilar, olcumler, tolerans };
}
