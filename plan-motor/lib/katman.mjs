// KATMAN ROLLERİ — sınır katmanlarının TEK kaynağı.
//
// 🔴 NEDEN VAR: sınır kümesi eskiden kodda sabitti ve İKİ AYRI KOPYA hâlinde yaşıyordu
// (`cli.mjs` + `lib/cad-cikar.mjs`). Bir gerçek müşteri çiziminde `Zone_Line` katmanı duvar
// sayıldı; oysa o katman mobilya taşıyordu → mobilya ayak izleri odadan oyuldu, 8 odada
// %20 alan kaybı oldu ve hata SESSİZDİ (lifting RC 0). Karar: eşleme VERİDE yaşar
// (`katman-rolleri.json`), kod yalnız uygular. Bkz. DEVIR-CEVAP.md 2026-08-12.
//
// DEĞİŞMEZ: veri dosyası hangi katmanın ne olduğunu söyleyebilir (DEĞER), ama
// "rolü beyan edilmemiş katman işlenemez" kuralını kapatamaz (KURAL).
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const PAKET = dirname(dirname(fileURLToPath(import.meta.url)));
export const VARSAYILAN_YOL = join(PAKET, 'katman-rolleri.json');

export class KatmanHata extends Error {
  constructor(mesaj, rc = 1) {
    super(mesaj);
    this.rc = rc;
  }
}

export function rolleriYukle(yol = VARSAYILAN_YOL) {
  let ham;
  try {
    ham = JSON.parse(readFileSync(yol, 'utf8'));
  } catch (e) {
    throw new KatmanHata(`katman rolleri okunamadı (${yol}): ${e.message}`);
  }
  for (const alan of ['roller', 'sinir_rolleri', 'rol_kumesi']) {
    if (!ham?.[alan]) throw new KatmanHata(`katman rolleri eksik alan: ${alan} (${yol})`);
  }
  const bilinmeyen = Object.entries(ham.roller).filter(([, r]) => !ham.rol_kumesi.includes(r));
  if (bilinmeyen.length) {
    throw new KatmanHata(
      `katman rolleri: tanınmayan rol → ${bilinmeyen.map(([k, r]) => `${k}=${r}`).join(', ')}\n` +
      `  geçerli roller: ${ham.rol_kumesi.join(' · ')}`,
    );
  }
  const sinirDisi = ham.sinir_rolleri.filter((r) => !ham.rol_kumesi.includes(r));
  if (sinirDisi.length) throw new KatmanHata(`katman rolleri: sinir_rolleri tanınmıyor → ${sinirDisi.join(', ')}`);
  return ham;
}

// Çizimdeki katmanları rollere böler; beyan edilmemiş katman varsa FAIL-CLOSED.
// entities: [{ tur|tip, katman, koseler, kapali }]
export function katmanlariCoz(entities, roller) {
  const geometri = {}, metin = {};
  for (const e of entities) {
    const k = e.katman ?? '?';
    const t = e.tur ?? e.tip;
    if (t === 'metin') metin[k] = (metin[k] || 0) + 1;
    else geometri[k] = (geometri[k] || 0) + 1;
  }
  const beyansiz = Object.keys(geometri).filter((k) => !(k in roller.roller));
  if (roller.kapi?.beyan_zorunlu && beyansiz.length) {
    const dokum = beyansiz.map((k) => `  · ${k}  (${geometri[k]} geometri varlığı)`).join('\n');
    throw new KatmanHata(
      `rolü BEYAN EDİLMEMİŞ katman var — çizim işlenmedi (fail-closed):\n${dokum}\n` +
      `  Bu katmanlar sınır mı, mobilya mı, not mu? Karar VERİDE beyan edilir:\n` +
      `  ${VARSAYILAN_YOL}  ya da  --katman-rolleri <dosya.json>\n` +
      `  Geçerli roller: ${roller.rol_kumesi.join(' · ')}   ("yok-say" da meşru bir beyandır)\n` +
      `  ⚠️ Sessiz varsayım yasak: bir katmanı sessizce duvar saymak 8 odada %20 alan kaybına\n` +
      `     yol açmıştı (bkz. DEVIR-CEVAP.md 2026-08-12).`,
    );
  }
  const sinirKatmanlari = Object.entries(roller.roller)
    .filter(([, r]) => roller.sinir_rolleri.includes(r))
    .map(([k]) => k);
  return { geometri, metin, beyansiz, sinirKatmanlari };
}

export function sinirKatmanlari(roller) {
  return Object.entries(roller.roller)
    .filter(([, r]) => roller.sinir_rolleri.includes(r))
    .map(([k]) => k);
}

// TANI — kural DEĞİL. Sınıra alınan katmanların kapalı poligon medyan alanını raporlar.
// Eşik YOK: küçük odalar (WC 2.38 m², duş 1.36 m²) mobilya ölçeğiyle örtüşür; ölçülmemiş
// eşiği sert kural ilan etmek yasak (K01). İnsan gözü için bilgi.
export function taniMedyanAlan(entities, roller) {
  const sinir = new Set(sinirKatmanlari(roller));
  const alanlar = {};
  for (const e of entities) {
    if (!(e.tur === 'poly' || e.tip === 'poly') || !e.kapali || !sinir.has(e.katman)) continue;
    const k = (e.koseler ?? []).map((v) => (Array.isArray(v) ? v : [v.x, v.y]));
    if (k.length < 3) continue;
    let a = 0;
    for (let i = 0; i < k.length; i++) {
      const [x1, y1] = k[i], [x2, y2] = k[(i + 1) % k.length];
      a += x1 * y2 - x2 * y1;
    }
    (alanlar[e.katman] ??= []).push(Math.abs(a) / 2 / 10000); // cm² → m²
  }
  return Object.entries(alanlar).map(([katman, dizi]) => {
    const s = dizi.slice().sort((x, y) => x - y);
    return { katman, adet: s.length, medyan_m2: +s[Math.floor(s.length / 2)].toFixed(2) };
  });
}
