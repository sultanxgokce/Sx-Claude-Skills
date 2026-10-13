#!/usr/bin/env node
/**
 * koltuk-fark.mjs — kutudaki HER tmux oturumu terminal sayfasında görünüyor mu? (G-BANI-0007 · Sultan 13 Eki: "sessiz düşürme yok")
 * Kutunun İÇİNDE koşar. Görünür liste /api/koltuklar'ın kullandığı AYNI yoldan üretilir: koltuk-bagla.sh --liste → koltuklar.mjs
 * (kopya mantık yok). Her oturum TEK hüküm alır:
 *   görünür · gizli:<neden> (koltuk-bagla.sh --gizli, altyapı) · gizli:ad-süzgeci (koltuklar.mjs KOLTUK_AD_DESEN) · DÜŞEN (gerekçesiz)
 * Ayrıca: HAYALET = listede var, tmux'ta yok · SEKME = bir istemci tmux'a BAŞKA bir adla bağlanmış (ör. code-server sekmesi
 * 'tmux attach -t yenileme' açılmış, oturum sonradan '2026/85' olmuş → sekme adı ≠ oturum adı; YargiYenileme vakası). Bilgi, hata değil.
 *   node koltuk-fark.mjs [--json]
 * rc: 0 düşen=0 ∧ hayalet=0 · 1 en az bir düşen ya da hayalet · 2 ölçülemedi (ölçülemeyen "temiz" sayılmaz)
 *     · 3 terminalsiz kutu (tmux kurulu değil — koltuk kavramı yok; ne temiz ne kirli)
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { KOLTUK_AD_DESEN, koltukSatirlari } from './koltuklar.mjs';
const KOK = dirname(fileURLToPath(import.meta.url));
const BETIK = process.env.KAPI_KOLTUK_BETIK || join(KOK, '../scripts/koltuk-bagla.sh');
const TMUX = (process.env.KOLTUK_FARK_TMUX || 'tmux').split(' ');
const JSONC = process.argv.includes('--json');
const kos = (k, a) => { try { return { rc: 0, out: execFileSync(k, a, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) }; }
  catch (e) { return { rc: e.status ?? 1, out: String(e.stdout || ''), err: String(e.stderr || e.message || '') }; } };
const olculemedi = (n) => { if (JSONC) console.log(JSON.stringify({ olculemedi: n })); else console.log('ÖLÇÜLEMEDİ: ' + n); process.exit(2); };

const t = kos(TMUX[0], [...TMUX.slice(1), 'list-sessions', '-F', '#{session_name}']);
let tum = [];
if (/ENOENT/.test(t.err || '')) { if (JSONC) console.log(JSON.stringify({ terminalsiz: 'tmux kurulu değil' })); else console.log('TERMİNALSİZ: tmux kurulu değil'); process.exit(3); }
if (t.rc === 0) tum = t.out.split('\n').filter(Boolean);
else if (!/no server running|No such file or directory/.test(t.err)) olculemedi('tmux listesi alınamadı: ' + t.err.trim());
const l = kos('bash', [BETIK, '--liste']); if (l.rc !== 0) olculemedi('koltuk-bagla.sh --liste rc=' + l.rc);
const g = kos('bash', [BETIK, '--gizli']); if (g.rc !== 0) olculemedi('koltuk-bagla.sh --gizli rc=' + g.rc + ' (eski betik mi?)');
const gorunur = new Set(koltukSatirlari(l.out).map((k) => k.ad));
const gizli = new Map(g.out.split('\n').filter(Boolean).map((s) => { const [ad, n] = s.split('\t'); return [ad, n]; }));

const oturumlar = tum.map((ad) => {
  if (gorunur.has(ad)) return { ad, hukum: 'gorunur' };
  if (gizli.has(ad)) return { ad, hukum: 'gizli', neden: gizli.get(ad) };
  if (!KOLTUK_AD_DESEN.test(ad)) return { ad, hukum: 'gizli', neden: 'ad süzgeci (tmux/kapı ad kuralı)' };
  return { ad, hukum: 'DUSEN', neden: 'gerekçesiz — listede yok, gizli listesinde yok, ad kuralına uyuyor' };
});
const hayalet = [...gorunur].filter((ad) => !tum.includes(ad));

// istemci ⟷ oturum: sekme açılırken verilen hedef ad bugünkü oturum adından farklı mı?
// Bilgi katmanıdır (rc'yi değiştirmez) ama SESSİZCE kaybolmaz (bağımsız göz tur 1): istemci listesi alınamazsa
// 'sekme_olculemedi', tek bir istemcinin komut satırı okunamazsa 'sekme_okunamayan' sayısı görünür.
const sekme = []; let sekme_okunamayan = 0, sekme_olculemedi = '';
const c = kos(TMUX[0], [...TMUX.slice(1), 'list-clients', '-F', '#{client_pid}\t#{session_name}']);
if (c.rc !== 0 && !/no server running|No such file or directory/.test(c.err || '')) sekme_olculemedi = (c.err || 'list-clients rc=' + c.rc).trim();
else for (const s of c.out.split('\n').filter(Boolean)) {
  const [pid, oturum] = s.split('\t'); let av = [];
  try { av = readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0').filter(Boolean); } catch { sekme_okunamayan++; continue; }
  const i = av.findIndex((x) => x === '-t' || x === '-s');
  const hedef = (i >= 0 ? av[i + 1] || '' : '').replace(/^=/, '');   // '=ad' kesin eşleşme biçimi: karşılaştırmada önek sökülür
  if (hedef && hedef !== oturum) sekme.push({ pid: +pid, acilis_adi: hedef, oturum });
}

const say = (h) => oturumlar.filter((o) => o.hukum === h).length;
const ozet = { toplam: tum.length, gorunur: say('gorunur'), gizli: say('gizli'), dusen: say('DUSEN'), hayalet: hayalet.length, sekme: sekme.length,
  sekme_okunamayan, ...(sekme_olculemedi ? { sekme_olculemedi } : {}) };
if (JSONC) console.log(JSON.stringify({ ozet, oturumlar, hayalet, sekme }));
else {
  for (const o of oturumlar) console.log(`  ${o.hukum === 'gorunur' ? '✓' : o.hukum === 'gizli' ? '·' : '✗'} ${o.ad}${o.neden ? '  — ' + (o.hukum === 'gizli' ? 'gizli: ' : '') + o.neden : ''}`);
  for (const h of hayalet) console.log(`  ✗ ${h}  — HAYALET: listede var, tmux'ta yok`);
  for (const s of sekme) console.log(`  ⓘ istemci ${s.pid}: '${s.acilis_adi}' adıyla açılmış → bugün '${s.oturum}' oturumunda (sekme adı ≠ oturum adı)`);
  if (sekme_olculemedi) console.log(`  ? istemci listesi ölçülemedi (sekme bilgisi YOK, temiz sayılmaz): ${sekme_olculemedi}`);
  if (sekme_okunamayan) console.log(`  ? ${sekme_okunamayan} istemcinin açılış komutu okunamadı (sekme bilgisi eksik)`);
  console.log(`== ${ozet.toplam} oturum · görünür ${ozet.gorunur} · gizli ${ozet.gizli} · DÜŞEN ${ozet.dusen} · hayalet ${ozet.hayalet} · başka adla bağlı istemci ${ozet.sekme} ==`);
}
process.exit(ozet.dusen || ozet.hayalet ? 1 : 0);
