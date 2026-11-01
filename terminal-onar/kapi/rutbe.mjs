// kapi/rutbe.mjs — koltuğun RÜTBESİ (kart rutbe-koltuk-alani · görev …1MXTDS · Sultan 1 Kas: üst sekmede reis, müdür, bağlı personel ayrışsın).
// Rütbe yeni bir alan DEĞİLDİR, ekip kaydındaki 'amir' ve 'oda_muduru' alanlarından türer; ikinci kayıt tutulmaz:
//   reis     : amiri Sultan olan ya da amiri boş ve oda müdürü olan üye (merkezde SERDAR, NAZIR'da ŞEHBENDER)
//   oda müdürü: oda müdürü alanı 'evet' olan ya da altında en az bir üye olan
//   personel : amiri kayıtta bulunan öteki üye
//   (alan yok): amiri de altı da olmayan üye. Rütbe uydurulmaz.
// Emekli, arşiv ve dondurulmuş üye amir sayılmaz. Çözülemeyen amir adı 'amir' alanına yazılmaz: koltuk adı olmayan değer bağ kuramaz.
import { adKatla, koltukEsle } from './oda.mjs';

const PASIF = new Set(['emekli', 'arsiv', 'dondurulmus']);

/** Üyeler → koltuk adı ⟶ { kademe, amir, amir_ad }. acik verilirse koltuk adı canlı koltuklarla eşlenir (kural koltukEsle). amir koltuk adıdır (şerit bağı onunla kurar), amir_ad görünen addır. */
export function rutbeHaritasi(uyeler, acik = []) {
  const aktif = (uyeler || []).filter((u) => u && u.id && !PASIF.has(u.durum) && !PASIF.has(u.hal));
  const koltuk = koltukEsle(aktif, acik), koltukAdi = (u) => koltuk.get(u) || adKatla(u.id);
  const dizin = new Map();
  for (const u of aktif) for (const a of [u.id, u.ad, koltukAdi(u)]) if (a) dizin.set(adKatla(a), u);
  const amirBul = (u) => dizin.get(adKatla(u.amir)) || null;
  const altSay = new Map();
  for (const u of aktif) { const a = amirBul(u); if (a && a !== u) altSay.set(a, (altSay.get(a) || 0) + 1); }
  const h = new Map();
  for (const u of aktif) {
    const ham = String(u.amir ?? '').trim(), a = amirBul(u), sultana = adKatla(ham) === 'sultan', mudur = u.oda_muduru === 'evet';
    const kademe = sultana || (!ham && mudur) ? 'reis' : mudur || altSay.get(u) ? 'oda müdürü' : a ? 'personel' : '';
    if (!kademe) continue;
    h.set(koltukAdi(u), { kademe, ...(a && a !== u ? { amir: koltukAdi(a), amir_ad: String(a.ad || a.id) } : {}) });
  }
  return h;
}

/** Koltuğun rütbesi: önce birebir ad, sonra katlanmış ad; yoksa {}. Ana koltukta rutbe olmaz (Sultan kararı): reisin koltuğu açık değilse bile rütbe anaya düşmez. */
export function rutbeBul(harita, koltuk) {
  const bul = (ad) => harita.get(ad) || [...harita].find(([k]) => adKatla(k) === adKatla(ad))?.[1];
  return bul(koltuk) || {};
}
