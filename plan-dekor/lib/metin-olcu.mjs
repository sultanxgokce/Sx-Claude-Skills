// METİN GENİŞLİĞİ KESTİRİMİ — TEK KAYNAK.
//
// 🔴 NEDEN AYRI DOSYA: bu katsayı üreticide (dekor-svg.mjs) ve denetimde (oz-denetim.mjs)
// AYRI AYRI tanımlıydı. Puanlayan-ajan 2026-08-13'te işaret etti: "sınav, sınadığı kodun
// kendi tahminini ELLE KOPYALAYARAK kullanıyor" — iki kopya sessizce ayrışabilir ve o an
// denetim, ölçtüğünü sandığı şeyi ölçmez olur (D038 ailesi: kendi kaynağından türeyen sınav).
//
// ⚠️ DÜRÜSTLÜK SINIRI: bu bir KESTİRİMDİR (±%8), gerçek font metriği değil. Tek kaynağa
// almak kopya-ayrışmasını bitirir ama kestirim hatasını BİTİRMEZ: denetim, üreticiyle aynı
// kestirimi kullandığı için üreticinin kestirim hatasını tanım gereği yakalayamaz.
// Bu yüzden taşma kapısı KABA taşmayı tutar; ince taşma hâlâ göze kalır.
// Gerçek çözüm font metriği ölçmektir (sharp/DejaVu elde var) — ölçülmedi, iş olarak açık.

// DejaVu Sans Bold yaklaşık genişlik katsayısı + letter-spacing 1.
// 0.62 ölçüldü ve YETERSİZ çıktı: etiketler BÜYÜK HARF + kalın çiziliyor, bu sınıf DejaVu'da
// belirgin daha geniştir ("EBEVEYN BANYO" 250 cm odada komşu odaya taşıyordu). 0.76'ya çekildi.
export const KARAKTER_ORANI = 0.76;

export function metinGenisligi(s, punto) {
  return s.length * punto * KARAKTER_ORANI + s.length;
}
