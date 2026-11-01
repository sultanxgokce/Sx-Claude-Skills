/**
 * ajan-adlari.mjs — ajan adı TEK YAZIM (YG1 · SERDAR 22 Eki, verim araştırması).
 *
 * Ölçüm (canlı defter, 764 görev): aynı ajan iki-üç yazımla kayıtlı — atanan'da BÂNİ 71 / BANI 9, BASİRET 7 / BASIRET 15,
 * BERİD 18 / BERID 4, MİRAHUR 35 / MIRAHUR 2; kaynak_kim'de MÜTEVELLİ 78 / MUTEVELLI 12, MUAVİN 5 / MUAVIN 11. Aynı gün açılan
 * GQYBP yine "MIRAHUR" (noktasız) yazıldı: sorun üretilmeye devam ediyordu. Sayaçlar ve süzgeçler adı ikiye bölüyordu.
 *
 * Kural: gelen ad, harf/işaret/büyük-küçük farkı silinince (katla) bu listedeki bir adla eşleşirse LİSTEDEKİ yazımla saklanır.
 * Listede olmayan ad AYNEN geçer (red yok): kutu ajanlarının kanonik yazımı merkezde tek bir kayıtta durmuyor; bilmediğimiz
 * adı reddetmek kutuların yazımını kırardı. Liste büyüdükçe kapsam büyür.
 * Yazım: merkezin üye kaydındaki (aile-registry) Türkçe yazım; ASCII kimlikli üyelerde defterdeki çoğunluk yazımı
 * (MUHAKKİK, MÜMEYYİZ). Okuyan araçlar (bekçi, panel) zaten katlayarak eşler — seçim onları kırmaz.
 */

export const AJAN_ADLARI = [
  'SERDAR', 'UISERDAR', 'PAZARBASI', 'MÜMEYYİZ', 'BUGSERDAR', 'AHENKSERDAR', 'MIMSERDAR', 'MOTORSERDAR',
  'MUAVİN', 'YAVER', 'NAKKAŞ', 'BASİRET', 'BÂNİ', 'BERİD', 'MUHAKKİK', 'MİRAHUR', 'HENDESE', 'HEZARFEN',
  'MÜTEVELLİ', 'MEDDAH', 'HAZİNEDAR', 'İMAR',
  'NECCÂR', 'BENNÂ',   // mihenk ekip kaydındaki yazım (id: NECCÂR · BENNÂ, 29 Eki ölçüldü); eski 'NECCAR' aynı katlanır → girdi NECCÂR'a çevrilir
  'EMANETÇİ', 'MÜZEHHİP', 'ŞAKİRD', 'ÇAPAR', 'TATAR', 'MESSÂH', 'MEREMMETÇİ', 'MÜCERRİB', 'MÜTEFENNİN',   // merkez kaydında olup listede eksikti: mektup alici_bilinmiyor ile reddedilip zile düşüyordu (1 Kas)
  'Sultan',
];

/** Yalnız karşılaştırma için: işaretler silinir (İ → I, Â → A), büyük harf (ı → I), harf-rakam dışı atılır. */
export function katla(ad) {
  const s = String(ad ?? '').normalize('NFKD').replace(/\p{M}/gu, '');
  return s.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

const HARITA = new Map(AJAN_ADLARI.map((a) => [katla(a), a]));
if (HARITA.size !== AJAN_ADLARI.length) throw new Error('ajan-adlari: iki ad aynı katlanıyor — liste çatallı');

/** Bilinen bir ajanın başka yazımıysa listedeki yazım; değilse gelen değer aynen. */
export function tekYazim(ad) {
  if (typeof ad !== 'string' || !ad.trim()) return ad;
  return HARITA.get(katla(ad)) ?? ad;
}

export const AD_ALANLARI = ['atanan', 'kaynak_kim'];

/**
 * Gövdedeki ad alanlarını YERİNDE tek yazıma çevirir (dizi değerlerde her öğe). Dönen liste değişenler: [{alan, gelen, yazilan}].
 * Alan kapısından ÖNCE çağrılır: kapı saklanacak yazımı sınar.
 */
export function adlariTekYazimla(govde) {
  const degisen = [];
  if (!govde || typeof govde !== 'object') return degisen;
  for (const alan of AD_ALANLARI) {
    if (!(alan in govde)) continue;
    const v = govde[alan];
    const cevir = (x) => { const y = tekYazim(x); if (y !== x) degisen.push({ alan, gelen: x, yazilan: y }); return y; };
    govde[alan] = Array.isArray(v) ? v.map(cevir) : cevir(v);
  }
  return degisen;
}
