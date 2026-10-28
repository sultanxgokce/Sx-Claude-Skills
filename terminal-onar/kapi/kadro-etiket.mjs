// kapi/kadro-etiket.mjs — KADRO ETİKETİ (2.33.0 · görev …ZDV · Sultan 28 Eki 09:49: "bir kayda not ekleyebileyim, isim ve açıklama
// ayrı ayrı düzenlenebilir olsun"). Sultan'ın bir kayda kendi dilinde koyduğu üç alan: görünen ad · açıklama · not.
// 🔴 KAYIT DOSYASINA YAZILMAZ. Kayıttaki ad (id) kimliktir: ULAK, kancalar ve kayıt yönlendirmesi ona bakar, ekrandan değişmez.
//    Kayıt dosyaları da üretilmiş bölge + derleyici kuralına bağlı ("yeni alan açılmaz", kadro-yaz.mjs). Etiket kapının durum
//    dizininde AYRI dosyada yaşar, yalnız Kadro'da görünür; boş değer alanı siler (her yazım geri alınabilir).
// 🔴 Okunamayan dosyanın ÜSTÜNE yazılmaz: bozuk dosyayı "boş" sayıp yazmak Sultan'ın bütün notlarını sessizce silerdi.
import fs from 'node:fs';
import path from 'node:path';

export const ALANLAR = { ad: 40, aciklama: 200, not: 1000 };   // alan → en çok karakter (kod noktası)
const ID_DESEN = /^[^\u0000-\u001F\u007F]{1,64}$/u;   // biçim gevşek: asıl şart kimliğin kayıtta OLMASI (uç onu sınar)

export class EtiketHata extends Error { constructor(kod, mesaj) { super(mesaj); this.kod = kod; } }

export const etiketYolu = (diz) => path.join(diz, 'kadro-etiket.json');

// → { etiketler: { <id>: { ad?, aciklama?, not?, zaman } }, okunamadi: bool }
export function etiketOku(diz) {
  const y = etiketYolu(diz);
  if (!fs.existsSync(y)) return { etiketler: {}, okunamadi: false };
  try {
    const j = JSON.parse(fs.readFileSync(y, 'utf8'));
    if (!j || typeof j !== 'object' || Array.isArray(j) || typeof j.etiketler !== 'object' || Array.isArray(j.etiketler)) return { etiketler: {}, okunamadi: true };
    return { etiketler: j.etiketler, okunamadi: false };
  } catch { return { etiketler: {}, okunamadi: true }; }
}

// Değer temizliği: denetim karakterleri atılır; ad ve açıklama tek satırdır, not satır sonu taşıyabilir. Baştaki/sondaki boşluk atılır.
export function degerTemizle(alan, deger) {
  let s = String(deger == null ? '' : deger).normalize('NFC');
  s = alan === 'not' ? s.replace(/\r\n?/g, '\n').replace(/[\u0000-\u0009\u000B-\u001F\u007F]/g, '') : s.replace(/[\u0000-\u001F\u007F]+/g, ' ');
  return s.trim();
}

// Tek alan yazar; boş değer alanı siler, kaydın hiç alanı kalmazsa kayıt da silinir. Dönen: kaydın yeni hâli ya da null.
export function etiketYaz(diz, id, alan, deger, simdi = new Date()) {
  if (!Object.hasOwn(ALANLAR, alan)) throw new EtiketHata(400, 'Alan: ad · aciklama · not.');
  if (typeof id !== 'string' || !ID_DESEN.test(id) || ['__proto__', 'constructor', 'prototype'].includes(id)) throw new EtiketHata(400, 'Kimlik geçersiz.');
  const v = degerTemizle(alan, deger);
  if ([...v].length > ALANLAR[alan]) throw new EtiketHata(400, `En çok ${ALANLAR[alan]} karakter.`);
  const { etiketler, okunamadi } = etiketOku(diz);
  if (okunamadi) throw new EtiketHata(500, 'Etiket dosyası okunamadı — üstüne yazılmadı (notlar korunuyor).');
  const yeni = { ...etiketler };
  const kayit = { ...(yeni[id] || {}) };
  if (v) kayit[alan] = v; else delete kayit[alan];
  const dolu = Object.keys(ALANLAR).some((a) => kayit[a]);
  if (dolu) { kayit.zaman = simdi.toISOString(); yeni[id] = kayit; } else delete yeni[id];
  const y = etiketYolu(diz), gecici = y + '.' + process.pid + '.gecici';
  fs.mkdirSync(diz, { recursive: true });
  fs.writeFileSync(gecici, JSON.stringify({ etiketler: yeni }, null, 1) + '\n', { mode: 0o600 });
  fs.renameSync(gecici, y);
  return dolu ? kayit : null;
}
