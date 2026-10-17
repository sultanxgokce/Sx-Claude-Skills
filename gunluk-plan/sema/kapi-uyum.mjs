// kapi-uyum.mjs — kokpit kapısının ayrıştırıcısı (terminal-onar/kapi/bugun.mjs) ortak fikstürü
// beklenen.json ile AYNI okuyor mu? (gorev_01M54TNAQV · bağımsız göz tur 1: uyum yalnız iddiaydı)
//
// Kullanım: node kapi-uyum.mjs <bugun.mjs yolu> <ornek-cipa.md> <beklenen.json>
// Çıkış: 0 uyumlu · 1 uyumsuz (fark basılır) · 2 kullanım/okuma hatası
//
// Kapının 1.5.0'dan ÖNCEKİ ayrıştırıcısı iki şeyi bilmez; bunlar AÇIKÇA sayılır, sessizce yutulmaz:
//   · sahip / kanit alanları yoktur → onun metni "(sahip: …)" taşır, notu "kanıt: …" parçasını taşır
//   · "ertelendi" durumu yoktur → "-" imli her satır onda "geri"dir
// Bu iki fark "BİLİNEN EKSİK" diye basılır (rc 0); başka HER fark uyumsuzluktur (rc 1).
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [yol, ornek, beklenenYol] = process.argv.slice(2);
if (!yol || !ornek || !beklenenYol) { console.error('kullanım: node kapi-uyum.mjs <bugun.mjs> <ornek-cipa.md> <beklenen.json>'); process.exit(2); }
let kapi, bek, metin;
try {
  kapi = await import(pathToFileURL(yol).href);
  bek = JSON.parse(fs.readFileSync(beklenenYol, 'utf8'));
  metin = fs.readFileSync(ornek, 'utf8');
} catch (e) { console.error('okunamadı:', e.code || e.message); process.exit(2); }

const o = kapi.cipaAyristir(metin);
const fark = []; const eksik = new Set();
if (o.tarih !== bek.tarih) fark.push(`tarih: kapı=${o.tarih} beklenen=${bek.tarih}`);
if (o.maddeler.length !== bek.maddeler.length) fark.push(`madde sayısı: kapı=${o.maddeler.length} beklenen=${bek.maddeler.length} (kapı satır ATLIYOR)`);
const SAHIP = /\s*\(sahip:\s*[^)]+\)/;
bek.maddeler.forEach((b, i) => {
  const k = o.maddeler[i]; if (!k) return;
  const ad = b.etiket || String(i + 1);
  for (const f of ['etiket', 'tur', 'sonuc']) if (k[f] !== b[f]) fark.push(`${ad}.${f}: kapı=${JSON.stringify(k[f])} beklenen=${JSON.stringify(b[f])}`);
  if (JSON.stringify(k.gorevler) !== JSON.stringify(b.gorevler)) fark.push(`${ad}.gorevler farklı`);
  // metin: kapı sahibi ayırmıyorsa "(sahip: …)" metinde kalır — bilinen eksik
  const kMetin = 'sahip' in k ? k.metin : k.metin.replace(SAHIP, '').trim();
  if (!('sahip' in k) && SAHIP.test(k.metin)) eksik.add('sahip alanı yok (metinde kalıyor)');
  if (kMetin !== b.metin) fark.push(`${ad}.metin: kapı=${JSON.stringify(kMetin)} beklenen=${JSON.stringify(b.metin)}`);
  if ('sahip' in k && k.sahip !== b.sahip) fark.push(`${ad}.sahip: kapı=${JSON.stringify(k.sahip)} beklenen=${JSON.stringify(b.sahip)}`);
  // not + kanıt: kapı kanıtı ayırmıyorsa notu "…· kanıt: X" olur — bilinen eksik
  const birlesik = [b.not, b.kanit ? 'kanıt: ' + b.kanit : ''].filter(Boolean).join(' · ');
  if ('kanit' in k) {
    if (k.kanit !== b.kanit) fark.push(`${ad}.kanit: kapı=${JSON.stringify(k.kanit)} beklenen=${JSON.stringify(b.kanit)}`);
    if (k.not !== b.not) fark.push(`${ad}.not: kapı=${JSON.stringify(k.not)} beklenen=${JSON.stringify(b.not)}`);
  } else {
    if (b.kanit) eksik.add('kanit alanı yok (notta kalıyor)');
    if (k.not !== birlesik) fark.push(`${ad}.not: kapı=${JSON.stringify(k.not)} beklenen=${JSON.stringify(birlesik)}`);
  }
  // durum: "ertelendi" kuralını bilmeyen kapıda "-" satırı "geri"dir — bilinen eksik; başka her fark uyumsuz
  if (k.durum !== b.durum) {
    const eskiKapi = k.durum === 'geri' && b.sonuc === 'ERTELENDİ';
    if (eskiKapi) eksik.add('ertelendi kuralı yok ("-" + ERTELENDİ → geri)');
    else fark.push(`${ad}.durum: kapı=${k.durum} beklenen=${b.durum}`);
  }
});
for (const e of eksik) console.log('  ⚠ BİLİNEN EKSİK (kapı 1.5.0 dilbilgisini henüz benimsemedi):', e);
if (fark.length) { console.log('✗ UYUMSUZ —', fark.length, 'fark:'); fark.forEach((f) => console.log('  •', f)); process.exit(1); }
console.log(`✓ kapı ayrıştırıcısı ortak fikstürle uyumlu (${o.maddeler.length} madde${eksik.size ? `, ${eksik.size} bilinen eksik` : ', eksiksiz'})`);
