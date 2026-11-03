#!/usr/bin/env node
// mesaj.mjs — NARH'ın tek komutu: pazaryeri müşteri mesajlarını Dümen'den oku · cevap taslağını Sultan onayına sun · yalnız onaylı cevabı gönder.
//   node mesaj.mjs oku    [--pazar amazon|trendyol|hepsi] [--json]
//   node mesaj.mjs taslak <pazar:sohbet> --metin "<cevap>" [--ozet "<müşteri mesajı özeti>"]      → görev defterinde 'sıra sende · onay' kaydı (Sultan ekranı)
//   node mesaj.mjs gonder <pazar:sohbet> --metin-dosya <yol> --onay "<Sultan D1 damgası>" [--gorev <gorev_id>]
// rc: 0 tamam · 2 ret (onaysız/damga/karar) · 3 ölçülemedi (harita tutmadı, Dümen kopuk) · 10 giriş lazım · 20 Dümen Sultan'da
// Ortam: DUMEN_MERKEZ (zorunlu) · DUMEN_CDP (varsayılan http://127.0.0.1:9222) · PAZARYERI_HARITA · PAZARYERI_GOREV_SH · PAZARYERI_BEKLE=0 (sınav)
// Kütük YOK: mesaj metni yalnız terminale ve (taslakta) görev defterine kırpılmış gider; müşteri adı hiçbir yere.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { haritaYukle, cevapsizlariOku, cevapGonder, damgaDogrula, gondermeAcikMi, sohbetCoz, kirp, MesajHata, PAZARLAR } from './pazar.mjs';

const BURASI = dirname(fileURLToPath(import.meta.url));
const DUMEN_LIB = process.env.DUMEN_LIB || resolve(BURASI, '..', '..', 'dumen-surucu', 'scripts', 'dumen.mjs');
const argv = process.argv.slice(2);
const komut = argv[0];
const sec = (ad, vars) => { const i = argv.indexOf(ad); return i > 0 && i + 1 < argv.length ? argv[i + 1] : vars; };
const bayrak = (ad) => argv.includes(ad);
const yaz = (s) => process.stdout.write(s + '\n');
const hata = (s) => process.stderr.write(s + '\n');

function gorevSh() {
  return process.env.PAZARYERI_GOREV_SH || ['/config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh', '/config/.claude/skills/gunluk-plan/scripts/gorev.sh'].find((y) => { try { readFileSync(y); return true; } catch { return false; } }) || null;
}

async function dumenAc() {
  const merkez = process.env.DUMEN_MERKEZ;
  if (!merkez) throw new MesajHata('ortam', 'DUMEN_MERKEZ verilmedi (Dümen kimde kapısı bu adresten okunur)', 3);
  const { Dumen } = await import(DUMEN_LIB);
  return Dumen.baglan({ cdpUrl: process.env.DUMEN_CDP || 'http://127.0.0.1:9222', merkez, zamanAsimiMs: 3000, yaz: (s) => hata(s) });
}

function kapiHatasi(e) {   // dumen-surucu KapiHata → rc
  if (e && (e.name === 'KapiHata' || (e.constructor && e.constructor.name === 'KapiHata') || typeof e.neden === 'string')) {   // KapiHata .name taşımaz; neden alanı ayırt eder
    if (e.neden === 'sultanda') { hata("⏸ Dümen Sultan'da · bekliyorum (mesaj komutu eylem yapmadı)"); return 20; }
    if (e.neden === 'durak') { hata(`⏸ Dümen durma noktası: ${e.message} — ajan bu alana yazmaz`); return 2; }
    hata(`ÖLÇÜLEMEDİ: Dümen ${e.neden || ''} ${e.message}`); return 3;
  }
  return null;
}

async function oku() {
  const harita = haritaYukle();
  const istenen = sec('--pazar', 'hepsi');
  const pazarlar = istenen === 'hepsi' ? PAZARLAR : [istenen];
  if (!pazarlar.every((p) => PAZARLAR.includes(p))) throw new MesajHata('pazar', `pazar: ${PAZARLAR.join('|')}|hepsi`, 2);
  const d = await dumenAc(); const sonuc = []; const sorunlar = [];
  try {
    for (const p of pazarlar) {
      try { sonuc.push(...await cevapsizlariOku(d, harita, p)); }
      catch (e) { const rc = kapiHatasi(e); if (rc === 20) throw e; if (e instanceof MesajHata) sorunlar.push({ pazar: p, kod: e.kod, rc: e.rc, mesaj: e.message }); else if (rc) sorunlar.push({ pazar: p, kod: 'dumen', rc, mesaj: e.message }); else throw e; }
    }
  } finally { await d.kapat().catch(() => {}); }
  if (bayrak('--json')) yaz(JSON.stringify({ cevapsiz: sonuc, sorunlar }));
  else {
    for (const p of pazarlar) { const n = sonuc.filter((x) => x.pazar === p).length; const s = sorunlar.find((x) => x.pazar === p); yaz(`${harita[p].ad}: ${s ? s.mesaj : n + ' cevapsız'}${harita[p].olculdu ? '' : ' · (harita ölçülmedi: ilk gerçek tur)'}`); }
    for (const x of sonuc) yaz(`  ${x.pazar}:${x.sohbet} · "${x.ozet}"`);
    if (sonuc.length) yaz(`sonraki adım: node mesaj.mjs taslak <pazar:sohbet> --metin "<cevap>"`);
  }
  if (sorunlar.length) return Math.max(...sorunlar.map((s) => s.rc));
  return 0;
}

function taslak() {
  const { pazar, sohbet } = sohbetCoz(argv[1]);
  const metin = sec('--metin', ''); const ozet = kirp(sec('--ozet', ''), 160);
  if (metin.trim().length < 5) throw new MesajHata('metin', '--metin "<cevap>" en az 5 harf', 2);
  const harita = haritaYukle(); const k = gondermeAcikMi(harita, pazar);
  const g = gorevSh();
  if (!g) throw new MesajHata('defter', 'görev defteri komutu bulunamadı (PAZARYERI_GOREV_SH ver)', 3);
  const baslik = `Pazaryeri cevabı onayı · ${harita[pazar].ad} · sohbet ${sohbet}`;
  const not = `Müşteri mesajı: ${ozet || '(özet verilmedi)'} | Cevap taslağı: ${kirp(metin, 600)}${k.acik ? '' : ' | DİKKAT: bu pazarda gönderme kapalı (' + k.neden + ')'}`;
  const r = spawnSync('bash', [g, 'ac', baslik, '--durum', 'sira-bende', '--kapi', 'karar', '--eylem', 'onay', '--not', not, '--ozet', `Sultan'ın onayı bekleniyor: ${harita[pazar].ad} sohbet ${sohbet} cevabı`], { encoding: 'utf8' });
  process.stdout.write(r.stdout || ''); process.stderr.write(r.stderr || '');
  if (r.status !== 0) throw new MesajHata('defter', `görev defteri yazımı başarısız (rc ${r.status})`, 3);
  yaz(`taslak Sultan'a sunuldu · onaylayınca: node mesaj.mjs gonder ${pazar}:${sohbet} --metin-dosya <yol> --onay "<Sultan D1 damgası (sohbet ${sohbet} anılsın)>"`);
  return 0;
}

async function gonder() {
  const { pazar, sohbet } = sohbetCoz(argv[1]);
  const dosya = sec('--metin-dosya', ''); const onay = sec('--onay', '');
  if (!dosya) throw new MesajHata('metin', '--metin-dosya <yol> gerekir (cevap metni dosyadan okunur, komut satırına yazılmaz)', 2);
  const metin = readFileSync(dosya, 'utf8').trim();
  if (metin.length < 5) throw new MesajHata('metin', 'cevap metni boş', 2);
  const harita = haritaYukle();
  const k = gondermeAcikMi(harita, pazar);
  if (!k.acik) throw new MesajHata('karar', `${harita[pazar].ad}: gönderme KAPALI — ${k.neden}`, 2);
  const dmg = damgaDogrula(onay, sohbet);
  const gorev = sec('--gorev', '');
  const d = await dumenAc();
  let s;
  try { s = await cevapGonder(d, harita, pazar, sohbet, metin); }
  catch (e) { const rc = kapiHatasi(e); if (rc) return rc; throw e; }
  finally { await d.kapat().catch(() => {}); }
  if (!s.gonderildi) { hata(`ÖLÇÜLEMEDİ: gönder düğmesine basıldı ama cevabın izi ("${s.iz}") sayfada görülmedi — Dümen'den bak, bulgu yaz`); return 3; }
  yaz(`gönderildi · ${pazar}:${sohbet} · onay ${dmg.tarih} (${dmg.kaynak} · ${dmg.ref}) · beyan:${dmg.beyan}`);
  const g = gorevSh();
  if (gorev && g) { const r = spawnSync('bash', [g, 'adim', gorev, `[gönderildi] ${harita[pazar].ad} sohbet ${sohbet} · onay: ${String(onay).slice(0, 160)}`], { encoding: 'utf8' }); if (r.status !== 0) hata(`⚠ görev adımı yazılamadı (rc ${r.status}) — gönderim oldu, defter kaydı elle`); }
  return 0;
}

try {
  const rc = komut === 'oku' ? await oku() : komut === 'taslak' ? taslak() : komut === 'gonder' ? await gonder() : (hata('kullanım: mesaj.mjs oku|taslak|gonder (başlık yorumuna bak)'), 2);
  process.exit(rc);
} catch (e) {
  if (e instanceof MesajHata) { hata(`✗ ${e.kod}: ${e.message}`); process.exit(e.rc); }
  const rc = kapiHatasi(e); if (rc) process.exit(rc);
  hata(`ÖLÇÜLEMEDİ: ${e && e.message ? e.message.split('\n')[0] : e}`); process.exit(3);
}
