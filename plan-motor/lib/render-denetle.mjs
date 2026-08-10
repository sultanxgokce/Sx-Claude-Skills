// RENDER ÖZ-DENETİMİ — üretilen çizim, yazılmadan ÖNCE sınanır (MEDDAH md.5: fail-closed).
//
// Niçin: yanlış çizim hata VERMEZ, sadece yanlış görünür. 2026-08-03'te üç sessiz kusur
// birden çıktı (yaylar kiriş çizildi, duvar gövdeleri dolmadı, yüzlerin yarısı elendi) ve
// hiçbiri RC≠0 üretmedi — insan gözü yakaladı. Bu modül onları makineye yakalatır.
// Buradaki kurallar JENERİKTİR (proje bilgisi yok) — paketlenebilirlik korunur.

import { metinGenisligi } from './metin-olc.mjs';

// B-003 · METİN ÇERÇEVEDEN TAŞIYOR MU. Öz-denetim metnin VARLIĞINI denetliyordu, SIĞDIĞINI
// denetlemiyordu — uzun başlık pafta dışında kaldı ve tek kapı görmedi.
// Bu kontrol üreticinin kararını TEKRARLAMAZ: üretilmiş SVG'deki <text> öğelerini ayrıştırıp
// gerçek x/punto/hizalama ile yeniden ölçer. Yani svg.mjs punto seçimini bozarsa da yakalar.
// Ortak olan yalnız ÖLÇÜ ALETİ (metin-olc) — karar değil. Alet bir TAHMİN olduğu için sonuç
// UYARI'dır, hata değil: meşru uzun başlık vardır, çizimi bloke etmek yanlış olur.
function metinTasmasi(svg) {
  const vb = svg.match(/viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"/);
  if (!vb) return [];
  const vbX = +vb[1], vbW = +vb[3];
  const tolerans = vbW * 0.02;
  const bulgular = [];
  for (const m of svg.matchAll(/<text\b([^>]*)>([^<]*)<\/text>/g)) {
    const oz = m[1];
    const metin = m[2].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
    if (!metin.trim()) continue;
    const x = +(oz.match(/\bx="(-?[\d.]+)"/)?.[1] ?? NaN);
    const punto = +(oz.match(/font-size="([\d.]+)"/)?.[1] ?? NaN);
    if (!Number.isFinite(x) || !Number.isFinite(punto)) continue;
    const kalin = /font-weight="[67]00"/.test(oz);
    const hiza = oz.match(/text-anchor="(\w+)"/)?.[1] ?? 'start';
    const w = metinGenisligi(metin, punto, kalin);
    const bas = hiza === 'middle' ? x - w / 2 : hiza === 'end' ? x - w : x;
    const tasma = Math.max(vbX - bas, (bas + w) - (vbX + vbW));
    if (tasma > tolerans) {
      const kisa = metin.length > 40 ? metin.slice(0, 40) + '…' : metin;
      bulgular.push(`"${kisa}" (punto ${punto}) çerçeveden ~${Math.round(tasma)} birim TAŞIYOR — genişlik ~${Math.round(w)}, çerçeve ${Math.round(vbW)}`);
    }
  }
  return bulgular;
}

export function renderDenetle(svg, { entities = null, model = null } = {}) {
  const hata = [];
  const uyari = [];

  for (const t of metinTasmasi(svg)) uyari.push(`metin çerçeve dışında: ${t}`);

  if (!svg || svg.length < 400) hata.push(`çıktı neredeyse boş (${svg?.length ?? 0} bayt)`);
  const ogeSayisi = (svg.match(/<path/g) || []).length + (svg.match(/<line/g) || []).length + (svg.match(/<rect/g) || []).length;
  if (ogeSayisi < 8) hata.push(`çıktıda yalnız ${ogeSayisi} çizim öğesi var`);
  if (!/viewBox=/.test(svg)) hata.push('viewBox yok — ölçek tanımsız');

  if (entities) {
    // YAY TUZAĞI: bulge taşıyan köşe varsa çıktıda yay komutu bulunmalı
    let bulgeli = 0;
    for (const e of entities) {
      if (e.tur !== 'poly') continue;
      for (const v of e.koseler) if (Math.abs(v.bulge ?? 0) > 1e-9) bulgeli++;
    }
    const yay = (svg.match(/[ "]A[0-9]/g) || []).length;
    if (bulgeli > 0 && yay === 0) {
      hata.push(`çizimde ${bulgeli} yay (bulge) var ama çıktıda tek yay yok — yaylar kiriş çizilmiş`);
    }
    // ETİKET KAYBI
    const metin = entities.filter((e) => e.tur === 'metin').length;
    const svgMetin = (svg.match(/<text/g) || []).length;
    if (metin > 0 && svgMetin < metin) uyari.push(`çizimde ${metin} etiket var, çıktıda ${svgMetin} metin`);
    // KATMAN KAYBI
    const kat = new Set(entities.filter((e) => e.tur !== 'metin').map((e) => e.katman));
    if (kat.size && ogeSayisi < kat.size * 3) hata.push(`çıktı ${kat.size} katmana göre fazla seyrek (${ogeSayisi} öğe)`);

    // DUVAR DOLGUSU: açık duvar çizgisi varsa gövde dolgusu da olmalı, yoksa duvarlar
    // ince çizgi kalır. (Bir dosyada 47 duvarın 8'i kapalıydı ve kural "biri kapalıysa
    // atla" olduğu için 39'u dolgusuz kaldı — sessiz kusur.)
    const duvarPoly = entities.filter((e) => e.tur === 'poly' && e.katman === 'px_walls');
    if (duvarPoly.length >= 5 && duvarPoly.some((e) => !e.kapali) && !/fill="#9d9d9d"/.test(svg)) {
      hata.push(`${duvarPoly.filter((e) => !e.kapali).length} duvar çizgisi kapalı gövde değil ve çıktıda dolgu yok — duvarlar ince çizgi kalmış`);
    }
  }

  if (model) {
    if (model.olcek?.kaynak && !svg.includes(model.olcek.kaynak)) {
      hata.push(`ölçü kaynağı ("${model.olcek.kaynak}") çıktıda beyan edilmemiş`);
    }
    const dusuk = (model.odalar || []).filter((o) => o.guven === 'dusuk');
    if (dusuk.length && !/⚠/.test(svg)) {
      hata.push(`${dusuk.length} oda DÜŞÜK GÜVEN işaretli ama çıktıda uyarısı yok — ölçüsüz veri kesin gibi görünür`);
    }
  }

  return { hata, uyari };
}
