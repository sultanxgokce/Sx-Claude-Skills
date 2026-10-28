// kadro-etiket.test.mjs — Kadro etiketi yazıcısı (2.33.0 · görev …ZDV): üç alan · sınırlar · silme · bozuk dosyaya yazılmaz. Hermetik.
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { etiketOku, etiketYaz, etiketYolu, degerTemizle, EtiketHata, ALANLAR } from './kadro-etiket.mjs';

let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const hata = (f) => { try { f(); return null; } catch (e) { return e; } };
const D = mkdtempSync(join(tmpdir(), 'kadro-etiket-')), T0 = new Date('2026-10-28T07:00:00Z');

kapi('E1 dosya yokken okuma boş ve okunamadı değil', JSON.stringify(etiketOku(D)) === '{"etiketler":{},"okunamadi":false}');
const r1 = etiketYaz(D, 'BASIRET', 'not', 'sabah raporunu o yazıyor', T0);
kapi('E2 not yazılır, kayıt döner (zaman damgalı)', r1 && r1.not === 'sabah raporunu o yazıyor' && r1.zaman === T0.toISOString(), JSON.stringify(r1));
etiketYaz(D, 'BASIRET', 'ad', 'Gözcü', T0); etiketYaz(D, 'BASIRET', 'aciklama', 'Kutunun nabzını tutar', T0);
const o2 = etiketOku(D).etiketler.BASIRET;
kapi('E3 üç alan AYRI ayrı yazılır, biri ötekini ezmez', o2.ad === 'Gözcü' && o2.aciklama === 'Kutunun nabzını tutar' && o2.not === 'sabah raporunu o yazıyor', JSON.stringify(o2));
etiketYaz(D, 'BASIRET', 'ad', '   ', T0);
const o3 = etiketOku(D).etiketler.BASIRET;
kapi('E4 boş değer yalnız o alanı siler (ad gitti, açıklama ve not duruyor)', !('ad' in o3) && o3.aciklama && o3.not, JSON.stringify(o3));
etiketYaz(D, 'BASIRET', 'aciklama', '', T0); const r5 = etiketYaz(D, 'BASIRET', 'not', '', T0);
kapi('E5 son alan da silinince kayıt tümden kalkar (dönen null)', r5 === null && !('BASIRET' in etiketOku(D).etiketler));
kapi('E6 bilinmeyen alan 400', hata(() => etiketYaz(D, 'X', 'rol', 'a'))?.kod === 400);
kapi('E7 prototip kimlikleri 400 (__proto__ · constructor)', hata(() => etiketYaz(D, '__proto__', 'not', 'a'))?.kod === 400 && hata(() => etiketYaz(D, 'constructor', 'not', 'a'))?.kod === 400);
kapi('E8 sınırlar karakterle sayılır (ad 40 · açıklama 200 · not 1000): tam sınır geçer, bir fazlası 400',
  etiketYaz(D, 'K', 'ad', 'ç'.repeat(40), T0)?.ad.length === 40 && hata(() => etiketYaz(D, 'K', 'ad', 'ç'.repeat(41)))?.kod === 400
  && hata(() => etiketYaz(D, 'K', 'aciklama', 'a'.repeat(201)))?.kod === 400 && hata(() => etiketYaz(D, 'K', 'not', 'a'.repeat(1001)))?.kod === 400
  && ALANLAR.ad === 40 && ALANLAR.aciklama === 200 && ALANLAR.not === 1000);
kapi('E9 ad ve açıklama tek satır (satır sonu boşluk olur), not satır sonunu taşır, denetim karakteri atılır',
  degerTemizle('ad', 'a\nb') === 'a b' && degerTemizle('not', 'a\r\nb\u0007') === 'a\nb' && degerTemizle('aciklama', '\u0000x\ty') === 'x y');
writeFileSync(etiketYolu(D), '{bozuk');
const once = readFileSync(etiketYolu(D), 'utf8'), e10 = hata(() => etiketYaz(D, 'BASIRET', 'not', 'yeni'));
kapi('E10 okunamayan dosyanın ÜSTÜNE yazılmaz: 500 ve dosya bayt bayt aynı', e10 instanceof EtiketHata && e10.kod === 500 && readFileSync(etiketYolu(D), 'utf8') === once && etiketOku(D).okunamadi === true);
rmSync(etiketYolu(D)); etiketYaz(D, 'A', 'not', 'x', T0);
kapi('E11 yazım atomik: geçici dosya kalmaz, dosya izni 600', !readFileSync(etiketYolu(D), 'utf8').includes('gecici') && existsSync(etiketYolu(D))
  && ((await import('node:fs')).statSync(etiketYolu(D)).mode & 0o777) === 0o600 && (await import('node:fs')).readdirSync(D).every((f) => !f.includes('.gecici')));
rmSync(D, { recursive: true, force: true });
console.log(`SONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
