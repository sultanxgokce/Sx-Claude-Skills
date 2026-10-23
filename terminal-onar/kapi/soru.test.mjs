// soru.test.mjs — kapi/soru.mjs + kapi/sir-suz.mjs + koltuklar.mjs soruAyikla (2.23.0 · K1 Engel kurgusu). Hermetik: geçici durum dosyası.
// Fikstür biçimleri: menü altbilgisi "Enter to select · ↑/↓ to navigate · Esc to cancel" (nova-icerik koltuğu 18 Eki ölçümü, gorev
// …MUHARRİR kayıt adımı) · izin sorusu "Do you want to proceed? ❯ 1. Yes / 2. … / 3. No, and tell Claude …" (Claude Code izin kutusu) ·
// yazı kutusu satırları BÂNİ koltuğunun 23 Eki 15:02 gerçek ekranından ('─' çizgisi · '❯'+U+00A0 · '─' çizgisi · alt çubuk).
import { mkdtempSync, existsSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { soruCoz, beriIsle, tut, imza } from './soru.mjs';
import { sirSuz, GIZLI } from './sir-suz.mjs';
import { soruAyikla, koltukSatirlari } from './koltuklar.mjs';
import { kadroBirlestir } from './kadro.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + (ek ? ' — ' + ek : '')); } };
const T = mkdtempSync(join(tmpdir(), 'soru-')); const DUR = join(T, 'beri.json');

const IZIN = [
  '⏺ Önceki iş bitti; şimdi temizlik yapıyorum. Adımlar:', '  1. eski dalı sil', '  2. dizini temizle',
  '⏺ Bash(git branch -D eski-dal)',
  '╭──────────────────────────────────────────────╮',
  '│ Bash command                                 │',
  '│   git branch -D eski-dal                     │',
  '│   Eski dalı sil                              │',
  '│ Do you want to proceed?                      │',
  '│ ❯ 1. Yes                                     │',
  "│   2. Yes, and don't ask again for git branch │",
  '│   3. No, and tell Claude what to do differently (esc) │',
  '╰──────────────────────────────────────────────╯',
].join('\n');
const SECIM = [
  '⏺ Hangi yolu seçelim?',
  '───────────────────────────────────────',
  ' ☐ Yol',
  '',
  'Kart cümlesindeki sürüm hangisi olsun?',
  '',
  '❯ 1. 0.20.0 (önerim)',
  '     SERDAR sırasına uyar',
  '  2. 0.19.0',
  '     kart cümlesine harfiyen uyar',
  '  3. Type something.',
  '',
  'Enter to select · ↑/↓ to navigate · Esc to cancel',
].join('\n');

console.log('════ S · soru çözümleme (menü · serbest · bölge) ════');
const a = soruCoz(IZIN);
kapi('S1 izin kutusu → tur menu, 3 şık, numaralar 1-3', a && a.tur === 'menu' && a.siklar.map((x) => x.no).join() === '1,2,3', JSON.stringify(a));
kapi('S1b soru metni kutunun içinden: komut + "Do you want to proceed?" (kutu çizgisi │ ╭ ╰ metne girmez)', a && a.metin.includes('git branch -D eski-dal') && a.metin.includes('Do you want to proceed?') && !/[│╭╰]/.test(a.metin), a && a.metin);
kapi('S1c ajanın mesajındaki "1. eski dalı sil" listesi (son ⏺ ÜSTÜ) şık sayılmaz', a && !a.siklar.some((x) => /eski dalı sil/.test(x.metin)));
const b = soruCoz(SECIM);
kapi('S2 seçim sorusu (altbilgili) → menu, 3 şık; şık altı açıklama satırı şık değil', b && b.tur === 'menu' && b.siklar.length === 3 && b.siklar[0].metin === '0.20.0 (önerim)', JSON.stringify(b));
kapi('S2b altbilgi ("Enter to select · …") ve şık açıklamaları soru metnine girmez', b && b.metin.includes('Kart cümlesindeki sürüm hangisi olsun?') && !/Enter to select|SERDAR sırasına/.test(b.metin), b && b.metin);
const c = soruCoz('⏺ Kurulumu bitirdim.\nDo you want to continue with the migration? (y/n)');
kapi('S3 numarasız soru → tur serbest, şık yok', c && c.tur === 'serbest' && c.siklar.length === 0 && c.metin.includes('migration'), JSON.stringify(c));
kapi('S4 soru metni çıkmayan ekran → null (uydurulmaz)', soruCoz('⏺ Bitti.\nhiçbir soru yok burada') === null && soruCoz('') === null);
kapi('S5 numaralı şık var ama menü geçersiz → null, "serbest" DEĞİL (göz #440 tur 2): 1\'e inmeyen "3. foo" · tek "❯ 1. Yes" · arası kopuk "1." "3."',
  soruCoz('⏺ x\nBir şey?\n  3. foo') === null && soruCoz('⏺ x\nDo you want to proceed?\n❯ 1. Yes') === null && soruCoz('⏺ x\nDo you want to proceed?\n❯ 1. Yes\n  3. No') === null);
kapi('S5b numarasız soru yine serbest (S5 düzeltmesi serbest yolu kapatmadı)', (soruCoz('⏺ x\nDo you want to proceed? (y/n)') || {}).tur === 'serbest');
const uzun = soruCoz('⏺ x\n' + 'ğüşıöç '.repeat(80) + 'Do you want to proceed?\n❯ 1. ' + 'Evet '.repeat(40) + '\n  2. Hayır\n  3. a\n  4. b\n  5. c\n  6. d\n  7. e\n  8. f');
kapi('S6 metin ≤300 kod noktası (Türkçe harfle), şık metni ≤80, şık ≤6', uzun && Array.from(uzun.metin).length <= 300 && uzun.siklar.length === 6 && uzun.siklar.every((x) => Array.from(x.metin).length <= 80), uzun && Array.from(uzun.metin).length + '/' + uzun.siklar.length);

console.log('════ Z · sır süzgeci (SERDAR şart 4) ════');
const JET = 'sk-ant-api03-' + 'A'.repeat(40), GH = 'ghp_' + 'b'.repeat(36), PEM = '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----';
const z = soruCoz('⏺ Bash(curl)\nBash command\n  curl -H "Authorization: Bearer ' + JET + '" https://u:gizliparola@api.x/v\n  token=abcdef1234567 ' + PEM.replace(/\n/g, ' ') + '\nDo you want to proceed?\n❯ 1. Yes (' + GH + ')\n  2. No');
kapi('Z1 anahtar / Bearer / url parolası / token=… / PEM soru metninde gizlenir', z && !z.metin.includes('AAAAAAAAAAAA') && !z.metin.includes('gizliparola') && !z.metin.includes('abcdef1234567') && !z.metin.includes('b3BlbnNzaC1') && z.metin.includes(GIZLI), z && z.metin);
kapi('Z2 şık metnindeki jeton (ghp_…) da gizlenir', z && !z.siklar[0].metin.includes('bbbbbbbb') && z.siklar[0].metin.includes(GIZLI), z && z.siklar[0].metin);
kapi('Z3 sır olmayan metin aynen kalır (süzgeç her şeyi silmez)', sirSuz('Kart cümlesindeki sürüm hangisi olsun? 0.20.0') === 'Kart cümlesindeki sürüm hangisi olsun? 0.20.0');
kapi('Z4 anahtar=değer biçiminde ad görünür kalır ("token=••• gizlendi")', sirSuz('token=abcdef1234567') === 'token=' + GIZLI, sirSuz('token=abcdef1234567'));
for (const [ad, x] of [['aws', 'AKIA' + 'Q'.repeat(16)], ['slack', 'xoxb-' + '1'.repeat(20)], ['jwt', 'eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.SflKxwRJSMeKKF2Q'], ['uzun', 'Zm9v'.repeat(12)]])
  kapi('Z5 ' + ad + ' deseni gizlenir', !sirSuz('önce ' + x + ' sonra').includes(x));

console.log('════ B · beri (ilk görüldüğü an, durum dosyası) ════');
const s1 = soruCoz(SECIM);
const b1 = beriIsle('BASIRET', s1, { yol: DUR, simdi: '2026-10-23T12:00:00.000Z' });
const b2 = beriIsle('BASIRET', soruCoz(SECIM), { yol: DUR, simdi: '2026-10-23T12:05:00.000Z' });
kapi('B1 aynı soru ikinci okumada aynı an (beri taşınır)', b1.beri === '2026-10-23T12:00:00.000Z' && b2.beri === b1.beri, b2.beri);
const b3 = beriIsle('BASIRET', soruCoz(IZIN), { yol: DUR, simdi: '2026-10-23T12:07:00.000Z' });
kapi('B2 yeni soru → yeni an', b3.beri === '2026-10-23T12:07:00.000Z', b3.beri);
beriIsle('ZAKIR', soruCoz(IZIN), { yol: DUR, simdi: '2026-10-23T12:08:00.000Z' });
tut(['ZAKIR'], { yol: DUR });
const d = JSON.parse(readFileSync(DUR, 'utf8'));
kapi('B3 --tut: soru hâlinden çıkan koltuğun kaydı silinir, kalanınki durur', !d.BASIRET && d.ZAKIR && d.ZAKIR.imza === imza(soruCoz(IZIN)), JSON.stringify(d));
const b4 = beriIsle('BASIRET', soruCoz(IZIN), { yol: DUR, simdi: '2026-10-23T12:30:00.000Z' });
kapi('B4 silinen koltuk AYNI soruyu yeniden sorarsa an tazelenir (eski an taşınmaz)', b4.beri === '2026-10-23T12:30:00.000Z', b4.beri);
kapi('B5 durum dosyası yoksa --tut dosya YARATMAZ', (() => { const y = join(T, 'yok.json'); tut([], { yol: y }); return !existsSync(y); })());

console.log('════ A · ayrıştırıcı (koltuklar.mjs soruAyikla) ════');
const satir = (hal, soru) => ['BASIRET', '1760000000', '1', 'ajan', hal, '', 'kapi', soru].join('\t');
const J = JSON.stringify(b2);
kapi('A1 hâl soru + geçerli JSON → koltukta soru alanı (tur · metin · şıklar · beri)', (() => { const x = koltukSatirlari(satir('soru', J))[0]; return x.soru && x.soru.tur === 'menu' && x.soru.siklar.length === 3 && x.soru.beri === b1.beri; })());
kapi('A2 hâl soru DEĞİLSE gelen soru alanı yok sayılır (eski okuma gösterilmez)', !koltukSatirlari(satir('calisiyor', J))[0].soru);
kapi('A3 bozuk JSON / bilinmeyen tür / tek şıklı menü → alan yok', !soruAyikla('{bozuk', 'soru') && !soruAyikla(JSON.stringify({ tur: 'x', metin: 'm', siklar: [] }), 'soru') && !soruAyikla(JSON.stringify({ tur: 'menu', metin: 'm', siklar: [{ no: 1, metin: 'a' }] }), 'soru'));
kapi('A4 7 sütunlu eski satır (soru sütunu yok) çalışmaya devam eder, alan yok', (() => { const x = koltukSatirlari(['A', '1', '1', 'ajan', 'soru', '', 'kapi'].join('\t'))[0]; return x && x.hal === 'soru' && !x.soru; })());

kapi('A5 /api/kadro gövdesi (kadroBirlestir): kayıtsız koltukta soru alanı taşınır, soru hâlinde olmayanda alan yok', (() => {
  const kd = kadroBirlestir({ uyeler: [], koltuklar: koltukSatirlari([satir('soru', J), ['ZAKIR', '1', '1', 'ajan', 'calisiyor', '', 'kapi', ''].join('\t')].join('\n')), ana: 'yok-ana', kimlikler: new Map() });
  const ks = (kd.kayitsiz || []); const x = ks.find((o) => o.ad === 'BASIRET'), y = ks.find((o) => o.ad === 'ZAKIR');
  return x && x.soru && x.soru.tur === 'menu' && y && !('soru' in y);
})());

rmSync(T, { recursive: true, force: true });
console.log(`\n── SONUÇ: ${g} geçti · ${k} kaldı ──`);
process.exit(k ? 1 : 0);
