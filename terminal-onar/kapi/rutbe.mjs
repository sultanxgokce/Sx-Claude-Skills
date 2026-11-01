// kapi/rutbe.mjs — koltuğun RÜTBESİ (kart rutbe-koltuk-alani · görev …1MXTDS · Sultan 1 Kas: üst sekmede reis, müdür, bağlı personel ayrışsın).
// Rütbe yeni bir alan DEĞİLDİR, ekip kaydındaki 'amir' ve 'oda_muduru' alanlarından türer; ikinci kayıt tutulmaz:
//   reis     : amiri Sultan olan ya da amiri boş ve oda müdürü olan üye (merkezde SERDAR, NAZIR'da ŞEHBENDER)
//   mudur    : oda müdürü ya da altında en az bir üye olan
//   personel : amiri kayıtta bulunan öteki üye
//   (alan yok): amiri de altı da olmayan üye. Rütbe uydurulmaz.
// Emekli, arşiv ve dondurulmuş üye amir sayılmaz. Çözülemeyen amir adı 'amir' alanına yazılmaz: koltuk adı olmayan değer bağ kuramaz.
import { adKatla } from './oda.mjs';

const PASIF = new Set(['emekli', 'arsiv', 'dondurulmus']);
const koltukAdi = (u) => String(u.tmux ?? '').split(':')[0] || adKatla(u.id);

/** Üyeler → koltuk adı ⟶ { kademe, amir, amir_ad }. amir koltuk adıdır (şerit bağı onunla kurar), amir_ad görünen addır. */
export function rutbeHaritasi(uyeler) {
  const aktif = (uyeler || []).filter((u) => u && u.id && !PASIF.has(u.durum) && !PASIF.has(u.hal));
  const dizin = new Map();
  for (const u of aktif) for (const a of [u.id, u.ad, koltukAdi(u)]) if (a) dizin.set(adKatla(a), u);
  const amirBul = (u) => dizin.get(adKatla(u.amir)) || null;
  const altSay = new Map();
  for (const u of aktif) { const a = amirBul(u); if (a && a !== u) altSay.set(a, (altSay.get(a) || 0) + 1); }
  const h = new Map();
  for (const u of aktif) {
    const ham = String(u.amir ?? '').trim(), a = amirBul(u), sultana = adKatla(ham) === 'sultan', mudur = u.oda_muduru === 'evet';
    const kademe = sultana || (!ham && mudur) ? 'reis' : mudur || altSay.get(u) ? 'mudur' : a ? 'personel' : '';
    if (!kademe) continue;
    h.set(koltukAdi(u), { kademe, ...(a && a !== u ? { amir: koltukAdi(a), amir_ad: String(a.ad || a.id) } : {}) });
  }
  return h;
}

/** Koltuğun rütbesi: önce birebir ad, sonra katlanmış ad; yoksa {}. Reisin kendi koltuğu açık değilse reislik ana koltuğa düşer (reis oradadır). */
export function rutbeBul(harita, koltuk, { ana = '', acik = [] } = {}) {
  const bul = (ad) => harita.get(ad) || [...harita].find(([k]) => adKatla(k) === adKatla(ad))?.[1];
  const r = bul(koltuk);
  if (r) return r;
  if (koltuk !== ana) return {};
  const reis = [...harita].find(([, v]) => v.kademe === 'reis');
  if (!reis || acik.some((a) => adKatla(a) === adKatla(reis[0]))) return {};
  return reis[1];
}
