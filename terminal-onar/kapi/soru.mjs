// kapi/soru.mjs — koltuk 'soru' hâlindeyken ekrandan SORUNUN KENDİSİNİ okur (2.23.0 · K1 · Engel kurgusu V6FJPZ · SERDAR 23 Eki 14:42).
// Bugüne kadar kapı yalnız "bu koltuk soru soruyor" diyordu; Sultan hangi soruyu, hangi şıklarla, ne zamandan beri sorduğunu
// görmek için ajanın ekranına gitmek zorundaydı. Bu modül salt okur: ekran metnini alır, tmux'a hiçbir şey yazmaz.
//
//   tur     'menu'    — en az iki numaralı şık var ("❯ 1. Evet" · "2. Hayır"): cevap şıkkın NUMARASIYLA verilir (K2 şart 3)
//           'serbest' — numaralı şık yok ("Do you want to …?" tek satır): cevap metin + Enter
//   metin   sorunun son bloğu, en çok 300 karakter (kod noktası); sır desen süzgecinden geçmiş
//   siklar  menüde [{no, metin}] (en çok 6, her biri en çok 80 karakter, süzülmüş); serbestte []
//   beri    bu sorunun (tür + metin + şıklar) bu koltukta İLK görüldüğü an — kapının durum dosyasından (aynı soru = aynı an)
//
// Bölge: son '⏺'/'●' mesaj satırından ya da '❯ …' istem satırından sonrası (2.36.1); soru kutusu oranın altında çizilir. Kutu çizgileri,
// altbilgi ("Enter to select · ↑/↓ to navigate · Esc to cancel" — nova-icerik 18 Eki ölçümü) ve ayraçlar metne girmez.
// Okunamayan soru UYDURULMAZ: metin çıkmazsa sonuç null, alan hiç yazılmaz.
//
// Komut satırı (koltuk-bagla.sh --liste çağırır):
//   node soru.mjs --oturum <ad>      stdin = ekran (capture-pane) → stdout tek satır JSON ya da boş
//   node soru.mjs --tut <ad> …       durum dosyasında yalnız verilen oturumlar kalır (soru hâlinden çıkanın 'beri'si silinir)
// Durum dosyası: TO_SORU_DURUM | $XDG_STATE_HOME/terminal-onar/soru-beri.json | ~/.local/state/terminal-onar/soru-beri.json
// Sınav saati: TO_SIMDI (ISO) verilirse 'şimdi' odur.
import { readFileSync, writeFileSync, mkdirSync, renameSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { sirSuz } from './sir-suz.mjs';

export const METIN_TAVAN = 300, SIK_TAVAN = 6, SIK_METIN_TAVAN = 80;
const ALTBILGI = /Enter to select|to navigate|Esc to cancel|Tab to amend|ctrl\+e to explain/i;
const AYRAC = /^[\s─━═╭╮╰╯┌┐└┘┄┈-]+$/;
const SIK = /^(?:[❯›>]\s*)?(\d{1,2})\.\s+(\S.*)$/;
// BÖLGE SINIRI (2.36.1 · canlı akar/MÜTEVELLİ, 29 Eki): Claude Code mesaj satırını '⏺' ya da '●' ile çizer; kullanıcı istemi '❯ <yazı>' satırıdır
//   (şık satırı '❯ 1.' DEĞİL). Yalnız '⏺' sınır sayılınca menünün üstündeki 6 satıra eski konuşma doluyordu ("User answered…", "Ran 1 shell command",
//   "❯ /gunluk-plan"). Kutu içindeki '│ ❯ 1. Yes' satırı '│' ile başladığı için sınır DEĞİL.
const SINIR = /^\s*(?:[⏺●]|❯(?!\s*\d{1,2}\.\s))/;
const SEKME = /^[←\s]*[☐☒✔✓]\s/;   // soru kutusunun sekme başlığı (" ☐ Canlı danışman") metin değildir
const SERBEST = /Do you want to|\?\s*(?:\((?:y\/n|Y\/n|y\/N)\)|\[(?:y\/N|Y\/n|y\/n)\])?\s*$/;

const kes = (s, n) => { const a = Array.from(s); return a.length > n ? a.slice(0, n - 1).join('') + '…' : s; };
const sik = (s) => s.replace(/\s+/g, ' ').trim();
function temizSatirlar(ekran) {
  return String(ekran || '').replace(/ /g, ' ').replace(/[​-‍﻿]/g, '').split(/\r?\n/)
    .map((l) => l.replace(/\s+$/, '')).filter((l) => l.trim() !== '');
}
const kutusuz = (l) => l.replace(/^\s*[│┃]\s?/, '').replace(/\s*[│┃]\s*$/, '').trim();

/** ekran metni → {tur, metin, siklar} | null (beri yok; o durum dosyasından gelir) */
export function soruCoz(ekran) {
  const tum = temizSatirlar(ekran);
  let bas = 0; for (let i = tum.length - 1; i >= 0; i--) if (SINIR.test(tum[i])) { bas = i + 1; break; }
  const bolge = tum.slice(bas).map(kutusuz).filter((l) => l && !AYRAC.test(l) && !ALTBILGI.test(l) && !SEKME.test(l));
  if (!bolge.length) return null;
  // menü: son numaralı şıktan geriye, 1 numaraya kadar (aradaki açıklama satırları şık değildir)
  let son = -1; for (let i = bolge.length - 1; i >= 0; i--) if (SIK.test(bolge[i])) { son = i; break; }
  if (son >= 0) {
    const siklar = []; let bir = -1;
    for (let i = son; i >= 0; i--) {
      const m = SIK.exec(bolge[i]); if (!m) continue;
      const no = +m[1];
      if (siklar.length && no !== siklar[0].no - 1) break;
      siklar.unshift({ no, metin: m[2] }); if (no === 1) { bir = i; break; }
    }
    if (bir >= 0 && siklar.length >= 2) {
      const ust = bolge.slice(Math.max(0, bir - 6), bir).filter((l) => !SIK.test(l));
      const metin = kes(sirSuz(sik(ust.join(' '))), METIN_TAVAN);
      if (!metin) return null;
      return { tur: 'menu', metin, siklar: siklar.slice(0, SIK_TAVAN).map((s) => ({ no: s.no, metin: kes(sirSuz(sik(s.metin)), SIK_METIN_TAVAN) })) };
    }
    // numaralı şık satırı VAR ama geçerli menü (1'den başlayan en az iki ardışık şık) çıkmadı → ekran OKUNAMADI; "serbest" sayılmaz (serbest = şık
    //   yok). Tek "❯ 1." ya da 1'e inmeyen "3." gören çözümleyici soruyu yanlış türle sunardı (göz #440 tur 2) — alan yazılmaz.
    return null;
  }
  let q = -1; for (let i = bolge.length - 1; i >= 0; i--) if (SERBEST.test(bolge[i])) { q = i; break; }
  if (q < 0) return null;
  const metin = kes(sirSuz(sik(bolge.slice(Math.max(0, q - 3), q + 1).join(' '))), METIN_TAVAN);
  return metin ? { tur: 'serbest', metin, siklar: [] } : null;
}

export function durumYolu(env = process.env) {
  if (env.TO_SORU_DURUM) return env.TO_SORU_DURUM;
  return join(env.XDG_STATE_HOME || join(env.HOME || homedir(), '.local', 'state'), 'terminal-onar', 'soru-beri.json');
}
function durumOku(yol) { try { const d = JSON.parse(readFileSync(yol, 'utf8')); return d && typeof d === 'object' && !Array.isArray(d) ? d : {}; } catch { return {}; } }
function durumYaz(yol, d) { mkdirSync(dirname(yol), { recursive: true }); const g = yol + '.' + process.pid + '.yeni'; writeFileSync(g, JSON.stringify(d)); renameSync(g, yol); }
export const imza = (s) => createHash('sha1').update(JSON.stringify([s.tur, s.metin, s.siklar])).digest('hex').slice(0, 16);

/** soru + oturum → beri eklenmiş soru; durum dosyası aynı soruda değişmez, yeni soruda tazelenir */
export function beriIsle(oturum, s, { yol = durumYolu(), simdi = process.env.TO_SIMDI || new Date().toISOString() } = {}) {
  const d = durumOku(yol), i = imza(s), eski = d[oturum];
  if (eski && eski.imza === i && eski.beri) return { ...s, beri: eski.beri };
  d[oturum] = { imza: i, beri: simdi }; durumYaz(yol, d);
  return { ...s, beri: simdi };
}
export function tut(oturumlar, { yol = durumYolu() } = {}) {
  if (!existsSync(yol)) return 0;
  const d = durumOku(yol), k = new Set(oturumlar); let n = 0;
  for (const o of Object.keys(d)) if (!k.has(o)) { delete d[o]; n++; }
  if (n) durumYaz(yol, d);
  return n;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const a = process.argv.slice(2);
  if (a[0] === '--oturum' && a[1]) {
    let ekran = ''; try { ekran = readFileSync(0, 'utf8'); } catch { process.exit(0); }
    const s = soruCoz(ekran);
    if (s) { try { process.stdout.write(JSON.stringify(beriIsle(a[1], s)) + '\n'); } catch { process.stdout.write(JSON.stringify(s) + '\n'); } }   // durum yazılamazsa beri'siz (uydurulmaz)
  } else if (a[0] === '--tut') { try { tut(a.slice(1)); } catch { /* temizlik yapılamadı: bir sonraki turda */ } }
  else { process.stderr.write('kullanım: soru.mjs --oturum <ad> < ekran | --tut <ad> …\n'); process.exit(2); }
}
