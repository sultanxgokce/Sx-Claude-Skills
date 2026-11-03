// pazar.mjs — pazaryeri-mesaj çekirdeği: sayfa haritası · KVKK kırpma · onay damgası · Amazon gönderme kilidi · Dümen üstünde okuma/gönderme.
// Dümen'e YALNIZ dumen-surucu kapısından gider (goto/fill/click + salt-okur metinler/nitelikler/adres) — ham page/CDP yok, parola/kod alanına yazım yok.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const KOK = dirname(dirname(fileURLToPath(import.meta.url)));
export const HARITA_YOLU = process.env.PAZARYERI_HARITA || join(KOK, 'HARITA.json');
export const PAZARLAR = ['amazon', 'trendyol'];

export class MesajHata extends Error { constructor(kod, mesaj, rc = 2) { super(mesaj); this.kod = kod; this.rc = rc; } }

export function haritaYukle(yol = HARITA_YOLU) {
  const h = JSON.parse(readFileSync(yol, 'utf8'));
  for (const p of PAZARLAR) if (!h[p] || !h[p].secici || !h[p].gelen_kutusu) throw new MesajHata('harita', `harita eksik: ${p}`, 3);
  return h;
}

// İnsan hızı: gerçek sayfada aralar rastgele (3–8 sn); sınavda PAZARYERI_BEKLE=0 ile kapalı.
export const bekle = (a, b) => (process.env.PAZARYERI_BEKLE === '0' ? Promise.resolve() : new Promise((r) => setTimeout(r, a + Math.random() * (b - a))));

// KVKK: müşteri adı kaynaktan HİÇ alınmaz (seçici yalnız mesaj gövdesini hedefler); gövdedeki telefon/e-posta/IBAN/kart desenleri kırpılır,
// uzunluk tavanlanır. Bu çıktı terminale ve görev defterine gider — kişisel veri taşımaz.
export function kirp(metin, enCok = 160) {
  let m = String(metin || '').replace(/\s+/g, ' ').trim();
  m = m.replace(/\bTR\d{2}(?:[ ]?\d){22}\b/g, '<iban>')
    .replace(/\b(?:\d[ -]?){13,19}\b/g, '<kart>')
    .replace(/(?:\+?\d[\d .()-]{8,}\d)/g, '<numara>')
    .replace(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g, '<e-posta>');
  return m.length > enCok ? m.slice(0, enCok - 1) + '…' : m;
}

// Onay damgası (D1 · A06): ajan Sultan'ın sözünü ÜRETMEZ, gördüğünü referanslar.
//   YYYY-MM-DD Sultan: onay (<kaynak> · <ref> · "<≤15 kelime kırpık>" · beyan:<AJAN>)   — ve damga metni sohbet kimliğini anmalı.
export const DAMGA = /^(\d{4}-\d{2}-\d{2}) Sultan: (onay|tamam|gönder|gonder)\b[^(]*\(([^·]+)·([^·]+)·\s*"([^"]{3,})"\s*·\s*beyan:([A-ZÂÇĞİÖŞÜ]{2,})\)\s*$/u;
// Cevap metninin parmak izi: taslakta üretilir, görev notuna girer, Sultan onu görüp onaylar; damga bu izi anmalı → onaydan sonra değişen metin gitmez.
export function parmakIzi(metin) { return 'cevap#' + createHash('sha256').update(String(metin || '').replace(/\s+/g, ' ').trim()).digest('hex').slice(0, 10); }
export function damgaDogrula(damga, sohbet, cevapMetni, bugun = new Date()) {
  const metin = String(damga || '').trim();
  const m = DAMGA.exec(metin);
  if (!m) throw new MesajHata('damga-bicim', 'onay damgası biçimsiz — beklenen: YYYY-MM-DD Sultan: onay (<kaynak> · <ref> · "<kırpık>" · beyan:<AJAN>)', 2);
  const gun = new Date(bugun.getTime() - bugun.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
  if (m[1] !== gun) throw new MesajHata('damga-tarih', `onay damgası bugünün tarihini taşımıyor (${m[1]} ≠ ${gun}) — dünkü onay bugünkü gönderime yetmez`, 2);
  if (!sohbet || !metin.includes(sohbet)) throw new MesajHata('damga-sohbet', `onay damgası bu sohbeti (${sohbet}) anmıyor — başka mesajın onayı bu mesaja taşınmaz`, 2);
  const iz = parmakIzi(cevapMetni);
  if (!metin.includes(iz)) throw new MesajHata('damga-metin', `onay damgası gönderilecek metnin parmak izini (${iz}) anmıyor — onaylanan taslak ile dosya içeriği aynı değil ya da damga izi taşımıyor`, 2);
  return { tarih: m[1], kaynak: m[3].trim(), ref: m[4].trim(), kirpik: m[5], beyan: m[6] };
}

// Amazon'da gönderme: Sultan'ın risk kararı dosyada olmadan KAPALI. Dosya: {"gonderme":"acik","karar":"<Sultan D1 damgası>"}
export function gondermeAcikMi(harita, pazar) {
  const yol = harita[pazar]?.gonderme_karari;
  if (yol === null || yol === undefined) return { acik: true, neden: 'karar gerekmez' };
  try {
    const j = JSON.parse(readFileSync(yol, 'utf8'));
    const m = /^(\d{4}-\d{2}-\d{2}) Sultan:/.exec(String(j.karar || ''));
    if (j.gonderme !== 'acik' || !m) return { acik: false, neden: `karar dosyası var ama gönderme açık değil (${yol})` };
    const gecerliGun = Number.isInteger(j.gecerli_gun) && j.gecerli_gun > 0 ? Math.min(j.gecerli_gun, 365) : 90;   // karar süresiz değil: varsayılan 90 gün, en çok 365
    const yas = Math.floor((Date.now() - Date.parse(m[1])) / 86400000);
    if (!(yas >= 0 && yas <= gecerliGun)) return { acik: false, neden: `Sultan'ın ${pazar} kararı ${yas} günlük, geçerlilik ${gecerliGun} gün — karar tazelenmeli (${yol})` };
    return { acik: true, neden: `Sultan kararı (${m[1]}, ${yas} gün): ` + String(j.karar).slice(0, 60) };
  } catch { return { acik: false, neden: `Sultan'ın ${pazar} gönderme kararı yok (${yol}) — okuma ve taslak açık, gönderme kapalı` }; }
}

export function sohbetCoz(arg) {
  const m = /^(amazon|trendyol):([\w.-]{1,80})$/.exec(String(arg || ''));
  if (!m) throw new MesajHata('sohbet', 'sohbet "<pazar>:<kimlik>" biçiminde verilir (ör. trendyol:12345)', 2);
  return { pazar: m[1], sohbet: m[2] };
}

async function girisKontrol(d, harita, pazar) {
  const adres = await d.adres();
  if (new RegExp(harita[pazar].giris_deseni).test(adres)) throw new MesajHata('giris', `${harita[pazar].ad}: oturum kapalı (giriş sayfası) — parola ajan yazmaz; Sultan Dümen'de girsin`, 10);
}

// Cevapsız mesajları oku → [{pazar, sohbet, ozet}] — adres, başlık, müşteri adı dönmez.
export async function cevapsizlariOku(d, harita, pazar) {
  const p = harita[pazar];
  await d.goto(p.gelen_kutusu, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await bekle(2000, 4000);
  await girisKontrol(d, harita, pazar);
  const kimlikler = await d.nitelikler(p.secici.sohbet_cevapsiz, p.secici.sohbet_kimlik);
  const alt = (x) => String(x).split(',').map((s) => s.trim()).filter(Boolean);
  const onizlemeSec = alt(p.secici.sohbet_cevapsiz).flatMap((a) => alt(p.secici.son_mesaj).map((b) => `${a} ${b}`)).join(', ');   // her alternatif çifti (göz tur 1: yalnız ilk alternatif alınıyordu)
  const onizlemeler = await d.metinler(onizlemeSec);
  if (kimlikler.length !== onizlemeler.length) throw new MesajHata('olculemedi', `${p.ad}: ${kimlikler.length} sohbet kimliği, ${onizlemeler.length} önizleme — harita bu sayfayı tanımıyor (HARITA.json ${p.olculdu ? '' : 'henüz ölçülmedi, '}seçicileri düzelt, bulgu yaz)`, 3);
  return kimlikler.map((k, i) => ({ pazar, sohbet: String(k || '').trim(), ozet: kirp(onizlemeler[i]) })).filter((x) => x.sohbet);
}

// Onaylı cevabı gönder: sohbet sayfası → cevap alanı → gönder düğmesi → sayfada cevabın izi aranır.
// Gönderim kilidi: gönder düğmesine basılmadan ÖNCE kilit yazılır; iz doğrulanınca 'gonderildi', doğrulanamazsa 'belirsiz' kalır.
// Aynı sohbete ikinci gönderim kilit varken REDDEDİLİR (çift mesaj riski) — yalnız --yeniden "<Dümen'den bakıldı, gitmemiş>" ile açılır.
export const KILIT_DIZIN = () => process.env.PAZARYERI_KILIT || '/config/.claude/pazaryeri-mesaj/gonderim';
export function kilitYolu(pazar, sohbet) { return join(KILIT_DIZIN(), `${pazar}-${sohbet}.json`); }
export function kilitOku(pazar, sohbet) { try { return JSON.parse(readFileSync(kilitYolu(pazar, sohbet), 'utf8')); } catch { return null; } }
export function kilitYaz(pazar, sohbet, veri) { mkdirSync(KILIT_DIZIN(), { recursive: true }); writeFileSync(kilitYolu(pazar, sohbet), JSON.stringify({ ...veri, pazar, sohbet, an: new Date().toISOString() })); }

export async function cevapGonder(d, harita, pazar, sohbet, metin, { parmak = '' } = {}) {
  const p = harita[pazar];
  await d.goto(p.sohbet_adresi.replace('{sohbet}', encodeURIComponent(sohbet)), { waitUntil: 'domcontentloaded', timeout: 45000 });
  await bekle(2000, 4000);
  await girisKontrol(d, harita, pazar);
  const iz = metin.replace(/\s+/g, ' ').trim().slice(0, 40);
  const duz = (g) => g.replace(/\s+/g, ' ');
  const once = duz(await d.metin('body', { enCok: 40000 }));
  if (once.includes(iz)) throw new MesajHata('iz-zaten-var', `cevabın izi ("${iz}") sayfada ZATEN var — daha önce gönderilmiş olabilir; Dümen'den bak`, 2);
  await d.fill(p.secici.cevap_alani, metin);
  await bekle(800, 2000);
  kilitYaz(pazar, sohbet, { durum: 'belirsiz', parmak, iz });   // düğmeye basmadan önce: çökersek bile ikinci deneme kilide takılır
  await d.click(p.secici.gonder);
  await bekle(2000, 4000);
  const sonra = duz(await d.metin('body', { enCok: 40000 }));
  const gonderildi = sonra.includes(iz);
  kilitYaz(pazar, sohbet, { durum: gonderildi ? 'gonderildi' : 'belirsiz', parmak, iz });
  return { gonderildi, iz };
}
