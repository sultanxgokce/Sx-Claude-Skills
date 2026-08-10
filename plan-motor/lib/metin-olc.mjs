// METİN ÖLÇÜMÜ — B-003. "Yanlış çizim hata vermez, sadece yanlış görünür" sınıfının metin
// hâli: başlık çerçeveden taşıyordu, hiçbir kapı görmedi (öz-denetim metnin VARLIĞINI
// denetliyordu, SIĞDIĞINI değil).
//
// Burası bir TAHMİN katmanıdır ve öyle olduğunu söyler: gerçek font metriği çalışma anında
// elimizde yok (SVG'yi biz üretiyoruz, rasterleştiren sharp). Aşağıdaki em-genişlikleri
// DejaVu Sans'ın (paketle gelen ve SVG'de ilk sırada beyan edilen font) gerçek advance
// değerlerinden alındı; bilinmeyen karakter varsayılana düşer. Hata payı ±%5 mertebesinde,
// bu yüzden sığdırma GÜVENLİK PAYI ile çalışır ve fail-closed DEĞİL uyarı üretir: meşru uzun
// başlık vardır, çizimi bloke etmek yanlış olur.
//
// Determinizm: saf fonksiyon, tablo sabit → aynı metin+punto = aynı sayı.

const EM = {
  ' ': 0.318, ' ': 0.318,
  'i': 0.278, 'j': 0.278, 'l': 0.278, 'ı': 0.278, 'I': 0.295, 'İ': 0.295,
  '.': 0.318, ',': 0.318, ':': 0.337, ';': 0.337, '!': 0.361, '|': 0.337,
  "'": 0.275, '"': 0.453, '`': 0.5, '·': 0.337, '-': 0.361, '‑': 0.361,
  '(': 0.39, ')': 0.39, '[': 0.39, ']': 0.39, '{': 0.4, '}': 0.4, '/': 0.337, '\\': 0.337,
  'f': 0.352, 't': 0.392, 'r': 0.411, 'ŕ': 0.411,
  'm': 0.974, 'w': 0.818, 'M': 0.863, 'W': 0.989, '@': 1.0, '—': 1.0, '–': 0.636, '…': 1.0,
  '²': 0.4, '³': 0.4, '°': 0.5, '⚠': 1.0, '×': 0.838,
  'A': 0.684, 'B': 0.686, 'C': 0.698, 'D': 0.77, 'E': 0.632, 'F': 0.575, 'G': 0.775,
  'H': 0.752, 'J': 0.295, 'K': 0.656, 'L': 0.557, 'N': 0.748, 'O': 0.787, 'P': 0.603,
  'Q': 0.787, 'R': 0.695, 'S': 0.635, 'T': 0.611, 'U': 0.732, 'V': 0.684, 'X': 0.685,
  'Y': 0.611, 'Z': 0.685, 'Ç': 0.698, 'Ğ': 0.775, 'Ö': 0.787, 'Ş': 0.635, 'Ü': 0.732,
};
const VARSAYILAN = 0.62;            // küçük harf/rakam ortalaması (DejaVu Sans)
const KALIN_CARPANI = 1.07;         // bold advance farkı (ölçülmüş yaklaşık)
export const GUVENLIK_PAYI = 0.97;  // tahmin hata payını yutar

// Metnin yaklaşık genişliği (SVG kullanıcı birimi = punto ile aynı ölçek).
export function metinGenisligi(metin, punto, kalin = false) {
  let em = 0;
  for (const ch of String(metin)) em += EM[ch] ?? VARSAYILAN;
  return em * punto * (kalin ? KALIN_CARPANI : 1);
}

// Metni n satıra DENGELİ böl (yalnız boşluktan). Bölünemiyorsa null.
function satirBol(metin, n) {
  if (n === 1) return [metin];
  const kelimeler = String(metin).split(/\s+/).filter(Boolean);
  if (kelimeler.length < n) return null;
  const hedef = metin.length / n;
  const satirlar = [];
  let cari = [], birikim = 0;
  for (let i = 0; i < kelimeler.length; i++) {
    const kalanSatir = n - satirlar.length;
    const kalanKelime = kelimeler.length - i;
    cari.push(kelimeler[i]);
    birikim += kelimeler[i].length + 1;
    const doldu = birikim >= hedef && kalanSatir > 1 && kalanKelime > kalanSatir;
    if (doldu) { satirlar.push(cari.join(' ')); cari = []; birikim = 0; }
  }
  if (cari.length) satirlar.push(cari.join(' '));
  return satirlar.length === n ? satirlar : null;
}

function kirp(metin, punto, kalin, genislik) {
  let s = String(metin);
  while (s.length > 1 && metinGenisligi(s + '…', punto, kalin) > genislik) s = s.slice(0, -1);
  return s.trimEnd() + '…';
}

// Metni verilen genişliğe SIĞDIR. Sıra: (1) tek satırda en büyük sığan punto,
// (2) çok satırda en büyük sığan punto, (3) taban puntoda kırp.
// Döner: { satirlar[], punto, kirpildi, sigdi }
// kirpmaYok: metin hiçbir puntoda sığmasa bile KIRPILMAZ (taban puntoyla olduğu gibi döner,
// sigdi:false). Çıktıda birebir geçmesi gereken beyanlar (ör. ölçü kaynağı) için — kırpmak
// başka bir kapıyı sessizce kırardı.
export function sigdir(metin, { genislik, puntolar, cokSatirPuntolar = [], satir = 2, kalin = false, kirpmaYok = false }) {
  const sinir = genislik * GUVENLIK_PAYI;
  const olcu = (s, p) => metinGenisligi(s, p, kalin);

  for (const punto of puntolar) {
    if (olcu(metin, punto) <= sinir) return { satirlar: [metin], punto, kirpildi: false, sigdi: true };
  }
  for (const punto of cokSatirPuntolar) {
    for (let n = 2; n <= satir; n++) {
      const satirlar = satirBol(metin, n);
      if (satirlar && satirlar.every((s) => olcu(s, punto) <= sinir)) {
        return { satirlar, punto, kirpildi: false, sigdi: true };
      }
    }
  }
  const taban = (cokSatirPuntolar.length ? cokSatirPuntolar : puntolar).at(-1);
  const satirlar = satirBol(metin, cokSatirPuntolar.length ? satir : 1) ?? [metin];
  if (kirpmaYok) return { satirlar, punto: taban, kirpildi: false, sigdi: false };
  let kirpildi = false;
  for (let i = 0; i < satirlar.length; i++) {
    if (olcu(satirlar[i], taban) <= sinir) continue;
    satirlar[i] = kirp(satirlar[i], taban, kalin, sinir);
    kirpildi = true;
  }
  return { satirlar, punto: taban, kirpildi, sigdi: false };
}
