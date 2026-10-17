// kapi/dava.mjs — Dava Rafı (Parça B · SERDAR 16 Eki 16:26): bir davayı DONDURMANIN tek yolu. İki çağıranı var: kapının Aç'ı
// (tavan doluyken yer açar, B4) ve günlük bekçi turu (N gün dokunulmayan davayı dondurur, B7). Sözleşme E2 dondurunkiyle aynı:
// kayda yaz → oturumu kapat → kapanmazsa kaydı geri al (kayıt "kapalı" derken oturum çalışırsa ekran yalan söyler).
import { kadroYaz, KadroHata } from './kadro-yaz.mjs';

// Dondururken son hareket kayda yazılır (B3: dondurulmuş satırda "13 gün önce" buradan); kural işareti yalnız bekçi turunda.
// Geri açılırken kural işareti kalkar (son_calisma kalır: açık satırda oturumun kendi `son`u önce gelir).
export function davaEk(kisi, eylem, kural = false, simdi = Math.floor(Date.now() / 1000)) {
  if (eylem === 'dondur') return { son_calisma: String((kisi.oturum && kisi.oturum.son) || kisi.son_calisma || simdi), dondurma: kural ? 'kural' : null };
  if (eylem === 'geri-ac') return { dondurma: null };
  return null;
}
// Dondurma GERİ ALINIRKEN (oturum kapanmadı) ek alanlar da önceki hâline döner — kayıt bayt bayt eski hâl (dava.test DV20)
export const davaGeriEk = (kisi) => ({ dondurma: null, son_calisma: kisi.son_calisma ? String(kisi.son_calisma) : null });

// kapat: async (oturumAdı) → bool · iz: (satır) → void. Hata: KadroHata (502 kapanmadı/geri alındı · 500 geri alınamadı).
export async function davaDondur({ proje, kisi, kural = false, kapat, iz = () => {}, neden = '' }) {
  const s = kadroYaz({ proje, id: kisi.id, eylem: 'dondur', ek: davaEk(kisi, 'dondur', kural) });
  iz(`dondur ${JSON.stringify(kisi.id)} ${s.onceki || '-'}→${s.yeni} ${s.dosya}${neden ? ' (' + neden + ')' : ''}`);
  if (kisi.oturum && !(await kapat(kisi.oturum.ad))) {
    try { kadroYaz({ proje, id: kisi.id, eylem: 'geri-ac', ek: davaGeriEk(kisi) }); iz(`geri-al ${JSON.stringify(kisi.id)} (oturum kapatılamadı)`); }
    catch (e) { iz(`GERI-ALINAMADI ${JSON.stringify(kisi.id)} ${String(e.message || e)}`); throw new KadroHata(500, 'oturumu kapatılamadı VE kaydı geri alınamadı — elle düzeltilmeli'); }
    throw new KadroHata(502, 'oturumu kapatılamadı, kaydı eski hâline döndü');
  }
  return s;
}
