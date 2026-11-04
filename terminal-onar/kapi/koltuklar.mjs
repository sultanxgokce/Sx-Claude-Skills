// kapi/koltuklar.mjs — "hangi koltuk görünür" kararının kapı tarafındaki TEK kaynağı.
// /api/koltuklar (sunucu.mjs) ve fark ölçeri (koltuk-fark.mjs) AYNI fonksiyonu çağırır: ölçüm aracı API'nin
// kopyasını değil kendisini ölçer (kopya ölçüm ilk değişiklikte ayrışır, sessiz yeşil verir).
// Kabuk tarafının kuralı scripts/koltuk-adi.sh — iki dilin eşdeğerliği koltuk-adi.test.sh'te sınanır.

import { ODA_AD_DESEN } from './oda.mjs';

// tmux kuralı (. ve :) + tek tercihimiz (başta/sonda boşluk, kontrol karakteri yok); '/' gibi adlar DÜŞMEZ.
// /u: uzunluk KOD NOKTASI sayılır (kabukla aynı; emoji 2 değil 1).
export const KOLTUK_AD_DESEN = /^(?![\s$@%=])(?!.*\s$)[^\x00-\x1f\x7f:.]{1,200}$/u;

// soru sütunu (2.23.0 · K1): tek satır JSON {tur, metin, siklar, beri?}. Biçim tutmazsa alan YOK (bozuk ekran okuması soru uydurmaz);
//   yalnız hâl 'soru' iken kabul edilir — başka hâlde gelen soru eskidir, gösterilmez.
export function soruAyikla(ham, hal) {
  if (!ham || hal !== 'soru') return null;
  let s; try { s = JSON.parse(ham); } catch { return null; }
  if (!s || (s.tur !== 'menu' && s.tur !== 'serbest') || typeof s.metin !== 'string' || !s.metin || !Array.isArray(s.siklar)) return null;
  const siklar = s.siklar.filter((x) => x && Number.isInteger(x.no) && x.no > 0 && typeof x.metin === 'string').slice(0, 6).map((x) => ({ no: x.no, metin: x.metin.slice(0, 80) }));
  if (s.tur === 'menu' && siklar.length < 2) return null;
  const beri = typeof s.beri === 'string' && Number.isFinite(Date.parse(s.beri)) ? s.beri : '';
  return { tur: s.tur, metin: s.metin.slice(0, 300), siklar: s.tur === 'menu' ? siklar : [], ...(beri ? { beri } : {}) };
}
// koltuk-bagla.sh --liste çıktısı → koltuklar. Satır: ad · son · claude(1|0) · tür · hâl · ne · hesap · soru · dizin (tür/hâl/hesap/soru/dizin eski betikte yok → alan yok, uydurulmaz).
// dizin (2.33.0 · kutu–oda modeli 2): etkin bölmenin çalışma dizini — kapı odayı bundan bulur; API'ye YOLLANMAZ (sunucu.mjs düşürür).
export function koltukSatirlari(cikti) {
  return String(cikti || '').split('\n').filter(Boolean).map((l) => {
    const [ad, son, claude, tur, hal, ne, hesap, soruHam, dizin, pencereHam] = l.split('\t');
    // pencere (2.37.0): etkin pencerenin tmux boyu; telefon terminali bundan sığar (ignore-size istemci boyu etkilemez, fazla alan noktalı kalıyordu). Biçim tutmazsa alan YOK.
    const pm = /^(\d{1,4})x(\d{1,4})$/.exec(pencereHam || ''); const pencere = pm && +pm[1] > 0 && +pm[2] > 0 ? { sutun: +pm[1], satir: +pm[2] } : null;
    const soru = soruAyikla(soruHam, hal);
    // ne: dış olay bekliyorsa NE beklediği (2.7.0); başka hâlde yok (uydurulmaz)
    // hesap (2.14.0): koltuktaki Claude'un hesap ADI (kapi · varsayilan · <ad> · bilinmiyor:<neden>); Claude'suz koltukta yok — merkez rozeti bundan okur
    return { ad, son: +son || 0, claude: claude === '1', ...(tur ? { tur } : {}), ...(hal ? { hal } : {}), ...(ne ? { ne } : {}), ...(hesap ? { hesap } : {}), ...(pencere ? { pencere } : {}), ...(soru ? { soru } : {}), ...(dizin ? { dizin } : {}) };
  }).filter((k) => KOLTUK_AD_DESEN.test(k.ad));
}
// usta.sh liste çıktısı → uyuyan ustalar (2.40.0 · kart usta-seridi-api). Satır: ad · durum(uyuyor|uyanik|kayit-eksik) · klasör.
// Yalnız 'uyuyor' döner: uyanık usta zaten tmux koltuğudur (koltuklar'da), kayıt-eksik olan uyandırılamaz (sohbet kimliği yok → şeritte gösterilmez).
// Klasör YANITA YAZILMAZ. Koltuk adı süzgecinden geçmeyen ad atılır; aynı koltuk adı koltuklar'da varsa o zaten uyanıktır → atlanır.
export function uyuyanUstalar(cikti, acik = []) {
  const var_ = new Set(acik), gor = new Set();
  return String(cikti || '').split('\n').filter(Boolean).map((l) => l.split('\t')).filter(([ad, durum]) =>
    durum === 'uyuyor' && KOLTUK_AD_DESEN.test(ad || '') && !var_.has(ad) && !gor.has(ad) && gor.add(ad))
    .map(([ad, , , oda]) => (ODA_AD_DESEN.test(oda || '') ? { ad, hal: 'uyuyor', oda } : { ad, hal: 'uyuyor' }));   // 2.41.0: 4. sütun = kayıttaki oda (kurala uymayan ad alınmaz)
}
