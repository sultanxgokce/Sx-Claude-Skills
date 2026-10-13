// kapi/koltuklar.mjs — "hangi koltuk görünür" kararının kapı tarafındaki TEK kaynağı.
// /api/koltuklar (sunucu.mjs) ve fark ölçeri (koltuk-fark.mjs) AYNI fonksiyonu çağırır: ölçüm aracı API'nin
// kopyasını değil kendisini ölçer (kopya ölçüm ilk değişiklikte ayrışır, sessiz yeşil verir).
// Kabuk tarafının kuralı scripts/koltuk-adi.sh — iki dilin eşdeğerliği koltuk-adi.test.sh'te sınanır.

// tmux kuralı (. ve :) + tek tercihimiz (başta/sonda boşluk, kontrol karakteri yok); '/' gibi adlar DÜŞMEZ.
// /u: uzunluk KOD NOKTASI sayılır (kabukla aynı; emoji 2 değil 1).
export const KOLTUK_AD_DESEN = /^(?![\s$@%=])(?!.*\s$)[^\x00-\x1f\x7f:.]{1,200}$/u;

// koltuk-bagla.sh --liste çıktısı → koltuklar. Satır: ad · son · claude(1|0) · tür · hâl (tür/hâl eski betikte yok → alan yok, uydurulmaz).
export function koltukSatirlari(cikti) {
  return String(cikti || '').split('\n').filter(Boolean).map((l) => {
    const [ad, son, claude, tur, hal] = l.split('\t');
    return { ad, son: +son || 0, claude: claude === '1', ...(tur ? { tur } : {}), ...(hal ? { hal } : {}) };
  }).filter((k) => KOLTUK_AD_DESEN.test(k.ad));
}
