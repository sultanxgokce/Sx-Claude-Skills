// Fail-closed render öz-denetimi: çizim YAZILMADAN ÖNCE sınanır, kusurluysa dosya HİÇ OLUŞMAZ.
// Desen: plan-motor lib/render-denetle.mjs. "Çizdim" iddiası çıktının kendisinden doğrulanır.

import { metinGenisligi } from './metin-olcu.mjs';
import { noktaIcinde } from './geo.mjs';

// `teslim`: MÜŞTERİYE GİDEN çıktı mı? Puanlayan-ajan 2026-08-13:
//   "Bir kapı, kırmızıya dönmediği sürece kapı değildir."
// Müşterinin gözüyle gördüğü kusurlar (etiket taşması, açıklıksız plan) uyarı sınıfında
// kalıp teslim oluyordu. Teslim yolunda uyarı YOKTUR: ya temizdir ya kırmızıdır.
// İç/taslak koşularda uyarı uyarı kalır — çalışırken önümüz kesilmesin.
export function renderDenetle(svg, { model, yerlesimler, tema, lejant = true, teslim = false }) {
  const hatalar = [];
  const uyarilar = [];   // KUSUR sınıfı — teslim kipinde hataya yükselir
  const bilgiler = [];   // BİLGİ sınıfı — meşru durumlar; teslimatı bloklamaz

  if (!svg || svg.length < 200) hatalar.push('SVG boş ya da anlamsız kısa');
  if (!/viewBox="/.test(svg)) hatalar.push('viewBox yok — ölçek taşınamaz');
  if (!svg.trimEnd().endsWith('</svg>')) hatalar.push('SVG kapanmamış');

  // Her oda çizimde temsil edilmiş mi
  for (const o of model.odalar ?? []) {
    if (!svg.includes(`data-oda="${o.id}"`)) hatalar.push(`oda çizimde yok: ${o.id}`);
  }

  // Her yerleşim çizimde temsil edilmiş mi (sayı bazlı — sessiz düşme yasak)
  const cizilenMobilya = (svg.match(/data-mobilya="/g) ?? []).length;
  if (cizilenMobilya !== yerlesimler.length) {
    hatalar.push(`mobilya sayısı tutmuyor: yerleşim ${yerlesimler.length}, çizim ${cizilenMobilya}`);
  }

  // Ölçü kaynağı beyanı çıktıda BİREBİR geçmeli (plan-motor'un aynı kapısı)
  const kaynak = model.olcek?.kaynak;
  if (!kaynak) hatalar.push('model.olcek.kaynak yok');
  else if (!svg.includes(`ölçü kaynağı: ${kaynak}`)) hatalar.push(`ölçü kaynağı beyanı çıktıda geçmiyor (${kaynak})`);

  // Tema kimliği beyan edilmeli — hangi temayla üretildiği çıktıdan okunabilsin
  if (!svg.includes(`tema: ${tema.id}`)) hatalar.push(`tema kimliği çıktıda beyan edilmemiş (${tema.id})`);

  // Lejant istendiyse gerçekten çizilmiş mi
  if (lejant && !svg.includes('LEJANT')) hatalar.push('lejant istendi ama çizimde yok');

  // Ölçek çubuğu
  if (!svg.includes('2 m')) uyarilar.push('ölçek çubuğu etiketi bulunamadı');

  // METİN TAŞMASI — çizilen etiketi ÇAPASINDAN ölç.
  // 🔴 Eskiden iki kusur vardı (puanlayan-ajan, 2026-08-13):
  //   (a) sığma, odanın BBOX GENİŞLİĞİYLE karşılaştırılıyordu; oysa metin `text-anchor=middle`
  //       ile ÇAPADAN iki yana açılır. Çapa kutu merkezinde değilse metin, genişlik testini
  //       GEÇTİĞİ hâlde duvarı aşar — DUŞ (1.4 m²) tam böyle taştı, müşteri gördü.
  //   (b) etiket ADINA göre regex'le aranıyordu; iki satıra bölünen ad bulunamayınca kapı
  //       SESSİZCE atlıyordu. Artık üretici etiketi `data-etiket-oda` ile damgalıyor.
  const etiketler = [];
  for (const m of svg.matchAll(/<text([^>]*data-etiket-oda="([^"]+)"[^>]*)>([^<]*)<\/text>/g)) {
    const nitelik = m[1];
    const x = Number(/\bx="([\d.\-]+)"/.exec(nitelik)?.[1]);
    const y = Number(/\by="([\d.\-]+)"/.exec(nitelik)?.[1]);
    const punto = Number(/font-size="([\d.]+)"/.exec(nitelik)?.[1]);
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(punto)) continue;
    // XML kaçışı ÇÖZÜLÜR: "&amp;" 5 karakter sayılırsa genişlik şişer ve kapı YANLIŞ
    // POZİTİF verir ("CAFE & MUTFAK" 13 yerine 17 karakter sayılmıştı — ölçüldü).
    const metin = m[3].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
    etiketler.push({ oda: m[2], x, y, punto, metin });
  }
  const odaDongusu = new Map((model.odalar ?? []).map((o) => [o.id, o.dongu.map((nid) => model.noktalar[nid])]));
  for (const e of etiketler) {
    const koseler = odaDongusu.get(e.oda);
    if (!koseler) { hatalar.push(`etiket tanınmayan odaya damgalı: ${e.oda}`); continue; }
    const yari = metinGenisligi(e.metin, e.punto) / 2;
    // Metnin İKİ UCU da odanın içinde olmalı (çapadan ölçüm — kutu genişliğinden DEĞİL).
    const sol = [e.x - yari, e.y - e.punto * 0.35];
    const sag = [e.x + yari, e.y - e.punto * 0.35];
    if (!noktaIcinde(sol, koseler) || !noktaIcinde(sag, koseler)) {
      const mesaj = `oda etiketi odasının DIŞINA taşıyor: "${e.metin}" (oda ${e.oda}, ~${Math.round(yari * 2)} cm)`;
      if (teslim) hatalar.push(mesaj); else uyarilar.push(mesaj);
    }
  }

  // ETİKET ↔ MOBİLYA ÇAKIŞMASI — müşteri bulgusu 2026-08-13: "salonda metrekare yazısı
  // yemek masasının üstüne binmiş". Veri zaten elde (`yerlesimler`); eşik icat edilmiyor,
  // kesişim alanı > 0 yeter. Bu HATA'dır: üstü çizili etiket okunamaz, uyarıyla teslim edilemez.
  const odaMobilya = new Map();
  for (const y of yerlesimler) {
    if (!y.oda) continue;
    if (!odaMobilya.has(y.oda)) odaMobilya.set(y.oda, []);
    odaMobilya.get(y.oda).push(y.kutu);
  }
  for (const e of etiketler) {
    const yari = metinGenisligi(e.metin, e.punto) / 2;
    const kutu = { x0: e.x - yari, x1: e.x + yari, y0: e.y - e.punto * 0.8, y1: e.y + e.punto * 0.2 };
    for (const m of odaMobilya.get(e.oda) ?? []) {
      const kesisir = kutu.x0 < m.x + m.g && kutu.x1 > m.x && kutu.y0 < m.y + m.d && kutu.y1 > m.y;
      if (kesisir) {
        hatalar.push(`oda etiketi mobilyanın üstüne biniyor: "${e.metin}" (oda ${e.oda})`);
        break;
      }
    }
  }

  // Mobilyasız oda varsa bu bir uyarıdır (kırmızı değil — program boş olabilir)
  const mobilyaliOdalar = new Set(yerlesimler.map((y) => y.oda));
  for (const o of model.odalar ?? []) {
    // BİLGİ, kusur değil: programsız oda (ör. duş kabini) meşru olarak boş kalabilir.
    // Teslimatı bloklamaz — yoksa kapı, doğru davranışı cezalandırır.
    if (!mobilyaliOdalar.has(o.id)) bilgiler.push(`oda mobilyasız çizildi: ${o.id}`);
  }

  // TESLİM KAPISI — açıklık verisi olmayan plan sunum planı olarak teslim EDİLEMEZ.
  // Müşteri (2026-08-13) bunu ilk sıraya koydu: "kapılar ve pencereler görünmüyor…
  // müşteriye gösterse ilk bunu sorar". Eksiği BEYAN ETMEK kusuru kapatmıyordu; ayrıca
  // açıklık kümesi boşken "kapı önü boş kalsın" kuralı denetleyecek veri bulamayıp
  // SESSİZCE geçiyordu (aynı teslimat, açıklıklar girince 13 sert ihlal verdi).
  if (teslim && !(model.acikliklar ?? []).length) {
    hatalar.push('açıklık verisi YOK — kapı/pencere içermeyen çıktı sunum planı olarak teslim edilemez ' +
                 '(iç koşu için --teslim bayrağını kullanma)');
  }
  // Teslim yolunda uyarı YOKTUR: ya temiz ya kırmızı.
  if (teslim && uyarilar.length) {
    for (const u of uyarilar) hatalar.push(`teslim kipinde uyarı kabul edilmez: ${u}`);
    uyarilar.length = 0;
  }

  return { gecti: hatalar.length === 0, hatalar, uyarilar, bilgiler };
}
