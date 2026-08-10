// REVİZE — işin kalbi. Değişiklik listesi modele uygulanır; sonuç fail-closed doğrulamadan
// geçemezse HİÇBİR çıktı yazılmaz. Noktalar paylaşımlı olduğu için "duvarı taşı" komşu
// duvarları kendiliğinden esnetir; açıklıklar {duvar, oran} ile bağlı olduğundan bedavaya taşınır.
import { uzunluk, alanM2 } from './geometri.mjs';
import { MotorHata, odaRaporu } from './model.mjs';

// Desteklenen işlemler — her biri modeli YERİNDE değiştirir (derin kopya cli'de alınır)
const ISLEMLER = {
  nokta_tasi(model, k) {
    const p = model.noktalar[gerekli(k, 'nokta')];
    if (!p) throw new MotorHata(`nokta_tasi: nokta "${k.nokta}" yok`);
    p[0] += k.dx ?? 0; p[1] += k.dy ?? 0;
  },

  duvar_tasi(model, k) {
    const d = duvarBul(model, gerekli(k, 'duvar'));
    for (const nid of new Set([d.bas, d.son])) {
      const p = model.noktalar[nid];
      p[0] += k.dx ?? 0; p[1] += k.dy ?? 0;
    }
  },

  nokta_ekle(model, k) {
    const id = gerekli(k, 'id');
    if (model.noktalar[id]) throw new MotorHata(`nokta_ekle: "${id}" zaten var`);
    if (![k.x, k.y].every(Number.isFinite)) throw new MotorHata(`nokta_ekle ${id}: x/y sayı olmalı`);
    model.noktalar[id] = [k.x, k.y];
  },

  duvar_ekle(model, k) {
    const id = gerekli(k, 'id');
    if ((model.duvarlar ?? []).some((d) => d.id === id)) throw new MotorHata(`duvar_ekle: "${id}" zaten var`);
    model.duvarlar.push({ id, bas: gerekli(k, 'bas'), son: gerekli(k, 'son'), kalinlik: k.kalinlik ?? 10, tip: k.tip ?? 'ic' });
  },

  duvar_sil(model, k) {
    const id = gerekli(k, 'duvar');
    const i = model.duvarlar.findIndex((d) => d.id === id);
    if (i < 0) throw new MotorHata(`duvar_sil: "${id}" yok`);
    model.duvarlar.splice(i, 1);
    const dusen = (model.acikliklar ?? []).filter((a) => a.duvar === id);
    model.acikliklar = (model.acikliklar ?? []).filter((a) => a.duvar !== id);
    if (dusen.length) console.error(`⚠ duvar_sil ${id}: üstündeki ${dusen.length} açıklık da düştü (${dusen.map((a) => a.id).join(', ')})`);
  },

  oda_ekle(model, k) {
    const id = gerekli(k, 'id');
    if ((model.odalar ?? []).some((o) => o.id === id)) throw new MotorHata(`oda_ekle: "${id}" zaten var`);
    model.odalar.push({ id, ad: k.ad ?? id, dongu: gerekli(k, 'dongu'), guven: k.guven ?? 'normal', ...(Number.isFinite(k.beyan_m2) ? { beyan_m2: k.beyan_m2 } : {}) });
  },

  oda_sil(model, k) {
    const id = gerekli(k, 'oda');
    const i = model.odalar.findIndex((o) => o.id === id);
    if (i < 0) throw new MotorHata(`oda_sil: "${id}" yok`);
    model.odalar.splice(i, 1);
  },

  oda_guncelle(model, k) {
    const o = model.odalar.find((x) => x.id === gerekli(k, 'oda'));
    if (!o) throw new MotorHata(`oda_guncelle: "${k.oda}" yok`);
    if (k.ad !== undefined) o.ad = k.ad;
    if (k.guven !== undefined) o.guven = k.guven;
    if (k.beyan_m2 !== undefined) o.beyan_m2 = k.beyan_m2;
    if (k.dongu !== undefined) o.dongu = k.dongu;
  },

  aciklik_ekle(model, k) {
    const id = k.id ?? `${k.tip ?? 'aciklik'}_${(model.acikliklar ?? []).length + 1}`;
    if ((model.acikliklar ?? []).some((a) => a.id === id)) throw new MotorHata(`aciklik_ekle: "${id}" zaten var`);
    model.acikliklar = model.acikliklar ?? [];
    model.acikliklar.push({ id, tip: gerekli(k, 'tip'), duvar: gerekli(k, 'duvar'), oran: gerekli(k, 'oran'), genislik: gerekli(k, 'genislik'), ...(k.aci_yonu ? { aci_yonu: k.aci_yonu } : {}) });
  },

  aciklik_tasi(model, k) {
    const a = (model.acikliklar ?? []).find((x) => x.id === gerekli(k, 'aciklik'));
    if (!a) throw new MotorHata(`aciklik_tasi: "${k.aciklik}" yok`);
    if (k.oran !== undefined) a.oran = k.oran;
    if (k.duvar !== undefined) a.duvar = k.duvar;
    if (k.genislik !== undefined) a.genislik = k.genislik;
  },

  model_guncelle(model, k) {
    if (k.ad !== undefined) model.ad = k.ad;
    if (k.olcek_aciklama !== undefined) model.olcek = { ...model.olcek, aciklama: k.olcek_aciklama };
  },

  aciklik_sil(model, k) {
    const id = gerekli(k, 'aciklik');
    const i = (model.acikliklar ?? []).findIndex((a) => a.id === id);
    if (i < 0) throw new MotorHata(`aciklik_sil: "${id}" yok`);
    model.acikliklar.splice(i, 1);
  },
};

function gerekli(k, alan) {
  if (k[alan] === undefined || k[alan] === null) throw new MotorHata(`${k.islem}: "${alan}" alanı zorunlu`);
  return k[alan];
}

function duvarBul(model, id) {
  const d = (model.duvarlar ?? []).find((x) => x.id === id);
  if (!d) throw new MotorHata(`duvar "${id}" yok`);
  return d;
}

export function revizeUygula(model, degisiklikler) {
  if (!Array.isArray(degisiklikler) || degisiklikler.length === 0) {
    throw new MotorHata('değişiklik listesi boş ya da dizi değil', 2);
  }
  for (const [i, k] of degisiklikler.entries()) {
    const islem = ISLEMLER[k.islem];
    if (!islem) throw new MotorHata(`bilinmeyen işlem #${i + 1}: "${k.islem}" (var olanlar: ${Object.keys(ISLEMLER).join(', ')})`, 2);
    islem(model, k);
  }
  return model;
}

// Revizyon diff raporu: oda alanları + değişen duvar uzunlukları
export function farkRaporu(eski, yeni, degisiklikler) {
  const eskiOda = new Map(odaRaporu(eski).map((r) => [r.oda, r]));
  const yeniOda = new Map(odaRaporu(yeni).map((r) => [r.oda, r]));
  const odalar = [];
  for (const [id, y] of yeniOda) {
    const e = eskiOda.get(id);
    if (!e) { odalar.push({ oda: id, durum: 'eklendi', m2: y.m2 }); continue; }
    if (Math.abs(e.m2 - y.m2) > 0.005) odalar.push({ oda: id, eski_m2: e.m2, yeni_m2: y.m2, fark_m2: +(y.m2 - e.m2).toFixed(2) });
  }
  for (const id of eskiOda.keys()) if (!yeniOda.has(id)) odalar.push({ oda: id, durum: 'silindi' });

  const duvarlar = [];
  const eskiDuvar = new Map((eski.duvarlar ?? []).map((d) => [d.id, d]));
  for (const d of yeni.duvarlar ?? []) {
    const e = eskiDuvar.get(d.id);
    const yL = uzunluk(yeni.noktalar[d.bas], yeni.noktalar[d.son]);
    if (!e) { duvarlar.push({ duvar: d.id, durum: 'eklendi', uzunluk_cm: +yL.toFixed(1) }); continue; }
    const eL = uzunluk(eski.noktalar[e.bas] ?? [0, 0], eski.noktalar[e.son] ?? [0, 0]);
    const tasindi = ['bas', 'son'].some((uc) => {
      const eskiP = eski.noktalar[e[uc]], yeniP = yeni.noktalar[d[uc]];
      return eskiP && yeniP && (Math.abs(eskiP[0] - yeniP[0]) > 0.01 || Math.abs(eskiP[1] - yeniP[1]) > 0.01);
    });
    if (Math.abs(eL - yL) > 0.1 || tasindi) {
      duvarlar.push({ duvar: d.id, eski_cm: +eL.toFixed(1), yeni_cm: +yL.toFixed(1), ...(tasindi && Math.abs(eL - yL) <= 0.1 ? { durum: 'taşındı' } : {}) });
    }
  }
  for (const id of eskiDuvar.keys()) if (!(yeni.duvarlar ?? []).some((d) => d.id === id)) duvarlar.push({ duvar: id, durum: 'silindi' });

  return { islemler: degisiklikler.map((k) => k.islem), odalar, duvarlar };
}
