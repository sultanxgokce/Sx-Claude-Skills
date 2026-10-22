/**
 * tarif.mjs — Kadro "Uzmanlıklar" + "Terimler" ekranının (Mühürdarlık G12 · E7) iki SALT-OKUR kaynağı. Kapı uçları: /api/kadro/tarif · /api/kadro/uzmanlik.
 *
 * SERDAR 22 Eki 05:10 (A): veri sahibinin kutusunda kalır, merkez bugünkü vekil yolundan okur — ikinci kopya yok, merkezin okuma alanı genişlemez.
 *   tarif  : Sx tarif-kaydi `veri/kadro-tarifleri.json` (uzmanlık · vazife · usul) + `veri/terim-kaydi.json` (terimler)
 *   uzmanlik: Nexus `agent-registry.json` personas[] (ad + uzmanliklar[]) + yanındaki `diploma-defteri.jsonl` (Nexus veri-semasi.md §6)
 *
 * 🔴 Şartlar (SERDAR):
 *   - YALNIZ okur; yazma yolu yok (uçlar GET dışını reddeder — sunucu.mjs).
 *   - Sır/yol sızmaz: çıktı BEYAZ LİSTEDİR. Kaynaktaki `kaynak` (depo yolları), `kapi_yolu`, persona `location/contact/runtime`,
 *     diploma `kanit`/`kume_sha` yanıta girmez; yeni bir alan kaynağa eklense de kendiliğinden sızmaz (alan seçilir, kopyalanmaz).
 *   - Kaynak okunamazsa o bölge `olc` nedeniyle döner, değeri `null` — BOŞ LİSTE DEĞİL ("hiç terim yok" ile "terimleri okuyamadım" ayrı şeylerdir).
 *     Boş diploma defteri ise ölçülmüş sıfırdır: `[]` (Nexus'ta bugün boş dosya — sınav koşulmadı).
 */
import fs from 'node:fs';
import path from 'node:path';

export const TARIF_DIZIN = '/config/.claude/skills/tarif-kaydi/veri';
export const AJAN_KAYDI = '/config/projects/Nexus/_agents/orchestration/agent-registry.json';

export function tarifYollari(ortam = process.env) {
  const d = ortam.TO_TARIF_DIZIN || TARIF_DIZIN;
  const kayit = ortam.TO_AJAN_KAYDI || AJAN_KAYDI;
  return { tarif: path.join(d, 'kadro-tarifleri.json'), terim: path.join(d, 'terim-kaydi.json'), beceri: ortam.TO_BECERI_DIZIN || path.resolve(d, '..', '..'),
    kayit, diploma: ortam.TO_DIPLOMA_DEFTERI || path.join(path.dirname(kayit), 'diploma-defteri.jsonl') };
}

// → { veri } | { olc: 'yok' | 'okunamadı' | 'bozuk JSON' }   (yol yanıta yazılmaz; neden Sultan dilinde kısa)
function jsonOku(yol) {
  let t; try { t = fs.readFileSync(yol, 'utf8'); } catch (e) { return { olc: e.code === 'ENOENT' ? 'kaynak yok' : 'kaynak okunamadı' }; }
  try { return { veri: JSON.parse(t) }; } catch { return { olc: 'kaynak bozuk (JSON değil)' }; }
}
const yazi = (v, n = 600) => (typeof v === 'string' ? v.slice(0, n) : null);
const idler = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string').map((x) => x.slice(0, 80)) : []);
const DIZI_DEGIL = 'kaynak biçimi beklenmedik';

function uzmanlikSec(u) {
  const e = u && u.sicil_esigi && typeof u.sicil_esigi === 'object' ? u.sicil_esigi : null;
  return { id: yazi(u.id, 80), ad: yazi(u.ad, 120), unvan: yazi(u.unvan, 120), vazifeler: idler(u.vazifeler), el_kitabi: yazi(u.el_kitabi, 80), durum: yazi(u.durum, 40),
    sicil_esigi: e ? { kacirma: Number(e.kacirma) || 0, pencere: Number(e.pencere) || 0 } : null };
}
function vazifeSec(v) {
  return { id: yazi(v.id, 80), ad: yazi(v.ad, 120), uzmanlik: yazi(v.uzmanlik, 80), usuller: idler(v.usuller), cakisir: idler(v.cakisir), denetler: idler(v.denetler),
    kor: v.kor === true, yedek: v.yedek && typeof v.yedek === 'object' ? { tur: yazi(v.yedek.tur, 60), bekleme_dk: Number(v.yedek.bekleme_dk) || 0 } : null };
}
const ADIM_TURLERI = ['beceri', 'kapi', 'sultan_eli'];
function adimSec(a, beceriDizin) {
  const tur = ADIM_TURLERI.includes(a && a.tur) ? a.tur : 'bilinmiyor';
  const b = tur === 'beceri' && typeof a.beceri_id === 'string' && /^[a-z0-9][a-z0-9-]{0,62}$/.test(a.beceri_id) ? a.beceri_id : null;
  // kurulu: beceri bu kutuda kurulu mu (SKILL.md var mı) — kataloğu değil KURULU kopyayı ölçer; ölçülemeyen ad (biçimsiz) null
  return { sira: Number(a && a.sira) || 0, tur, ne_yapar: yazi(a && a.ne_yapar), ...(tur === 'beceri' ? { beceri_id: b, kurulu: b ? fs.existsSync(path.join(beceriDizin, b, 'SKILL.md')) : null } : {}),
    ...(tur === 'sultan_eli' ? { sultan_eli_tarifi: yazi(a.sultan_eli_tarifi) } : {}) };
}
function usulSec(u, beceriDizin) {
  return { id: yazi(u.id, 80), ad: yazi(u.ad, 120), vazife: yazi(u.vazife, 80), tetik: yazi(u.tetik, 300),
    adimlar: (Array.isArray(u.adimlar) ? u.adimlar : []).map((a) => adimSec(a, beceriDizin)).sort((x, y) => x.sira - y.sira) };
}
function terimSec(t) {
  return { id: yazi(t.id, 80), ad: yazi(t.ad, 120), anlam: yazi(t.anlam), isleyis: yazi(t.isleyis), ornek: yazi(t.ornek), karistirilan: idler(t.karistirilan),
    ayirt_testi: yazi(t.ayirt_testi), sahip: yazi(t.sahip, 40), durum: yazi(t.durum, 40), katman: yazi(t.katman, 40) };
}

/** /api/kadro/tarif → { tarif: {uzmanliklar, vazifeler, usuller} | null, terim: {terimler} | null, olc: {tarif, terim} } */
export function tarifOku(ortam = process.env) {
  const y = tarifYollari(ortam), olc = { tarif: null, terim: null };
  let tarif = null, terim = null;
  const t = jsonOku(y.tarif);
  if (t.olc) olc.tarif = t.olc;
  else if (!['uzmanliklar', 'vazifeler', 'usuller'].every((k) => Array.isArray(t.veri && t.veri[k]))) olc.tarif = DIZI_DEGIL;
  else tarif = { uzmanliklar: t.veri.uzmanliklar.map(uzmanlikSec), vazifeler: t.veri.vazifeler.map(vazifeSec), usuller: t.veri.usuller.map((u) => usulSec(u, y.beceri)) };
  const r = jsonOku(y.terim);
  if (r.olc) olc.terim = r.olc;
  else if (!Array.isArray(r.veri && r.veri.terimler)) olc.terim = DIZI_DEGIL;
  else terim = { terimler: r.veri.terimler.map(terimSec) };
  return { tarif, terim, olc };
}

const UZ_DURUM = ['aday', 'aktif', 'askida'];
/** /api/kadro/uzmanlik → { personel: [{ad, uzmanliklar:[{uzmanlik, durum}]}] | null, diploma: [...] | null, olc: {personel, diploma} } */
export function uzmanlikOku(ortam = process.env) {
  const y = tarifYollari(ortam), olc = { personel: null, diploma: null };
  let personel = null, diploma = null;
  const k = jsonOku(y.kayit);
  if (k.olc) olc.personel = k.olc;
  else if (!Array.isArray(k.veri && k.veri.personas)) olc.personel = DIZI_DEGIL;
  else personel = k.veri.personas.filter((p) => p && typeof p.ad === 'string').map((p) => ({ ad: p.ad.slice(0, 40),
    uzmanliklar: (Array.isArray(p.uzmanliklar) ? p.uzmanliklar : []).filter((u) => u && typeof u.uzmanlik === 'string')
      .map((u) => ({ uzmanlik: u.uzmanlik.slice(0, 80), durum: UZ_DURUM.includes(u.durum) ? u.durum : 'bilinmiyor' })) }));
  let t = null;
  try { t = fs.readFileSync(y.diploma, 'utf8'); } catch (e) { olc.diploma = e.code === 'ENOENT' ? 'kaynak yok' : 'kaynak okunamadı'; }
  if (t !== null) {
    const satirlar = t.split('\n').filter((s) => s.trim()), l = [];
    for (const s of satirlar) { let d; try { d = JSON.parse(s); } catch { d = null; }
      if (!d || typeof d.personel !== 'string' || typeof d.uzmanlik !== 'string') { olc.diploma = 'kaynakta okunamayan satır var'; break; }
      l.push({ ts: yazi(d.ts, 40), personel: d.personel.slice(0, 40), uzmanlik: d.uzmanlik.slice(0, 80), el_kitabi_surum: yazi(d.el_kitabi_surum, 40), gecti: d.gecti === 'e' ? 'e' : d.gecti === 'h' ? 'h' : null }); }
    if (!olc.diploma) diploma = l;
  }
  return { personel, diploma, olc };
}
