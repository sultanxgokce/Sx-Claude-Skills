// Fail-closed render öz-denetimi: çizim YAZILMADAN ÖNCE sınanır, kusurluysa dosya HİÇ OLUŞMAZ.
// Desen: plan-motor lib/render-denetle.mjs. "Çizdim" iddiası çıktının kendisinden doğrulanır.

export function renderDenetle(svg, { model, yerlesimler, tema, lejant = true }) {
  const hatalar = [];
  const uyarilar = [];

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

  // METİN TAŞMASI — çizilen etiketi YENİDEN ölçüp odasına sığıp sığmadığına bak.
  // Bu kapı plan-motor'da vardı (render-denetle.mjs), plan-dekor'a konmamıştı; B-006
  // (oda etiketinin komşu odaya taşması) tam bu sınıftandı ve gözle yakalandı, kapıyla değil.
  // Ölçüm bir TAHMİNDİR (±%8) → fail-closed değil, uyarı. Üreticinin kendi sığdırmasına
  // güvenmez, çıktının kendisini ölçer.
  for (const o of model.odalar ?? []) {
    const ad = (o.ad ?? o.id).toLocaleUpperCase('tr-TR');
    const kacis = ad.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const desen = new RegExp(`font-size="(\\d+)"[^>]*font-weight="700"[^>]*>${kacis}<`);
    const m = svg.match(desen);
    if (!m) continue;   // iki satıra bölünmüş ya da kırpılmış — sığdırma zaten devreye girmiş
    const punto = Number(m[1]);
    const genislik = ad.length * punto * 0.76 + ad.length;
    const koseler = o.dongu.map((nid) => model.noktalar[nid]);
    const xs = koseler.map((k) => k[0]);
    const odaGenisligi = Math.max(...xs) - Math.min(...xs);
    if (genislik > odaGenisligi) {
      uyarilar.push(`oda etiketi odasına sığmıyor: "${ad}" ~${Math.round(genislik)} cm > oda ${Math.round(odaGenisligi)} cm`);
    }
  }

  // Mobilyasız oda varsa bu bir uyarıdır (kırmızı değil — program boş olabilir)
  const mobilyaliOdalar = new Set(yerlesimler.map((y) => y.oda));
  for (const o of model.odalar ?? []) {
    if (!mobilyaliOdalar.has(o.id)) uyarilar.push(`oda mobilyasız çizildi: ${o.id}`);
  }

  return { gecti: hatalar.length === 0, hatalar, uyarilar };
}
