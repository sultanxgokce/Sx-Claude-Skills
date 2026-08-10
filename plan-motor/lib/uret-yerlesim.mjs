// ÜRETİM FAZ A · yerleşim enumerasyonu — slicing-tree, BAĞIMLILIKSIZ, DETERMİNİST.
// Dikdörtgen sınırda kesim konumu alan oranından DOĞRUDAN hesaplanır; kısıt çözücü (Cassowary)
// ancak L/U sınırda ve çakışan kısıtlarda kazandırır → FAZ B'ye ertelendi (DOĞUM-PROMPTU §5).
// Math.random YOKTUR: aynı program → aynı sıra → aynı sha256. Çeşitlilik rastgelelikten değil,
// AYRIK MİMARİ KARARLARDAN (oda sırası · kesim ağacı · kesim yönü) gelir.
import { alanM2 } from './geometri.mjs';
import { onSinif } from './uret-eksen.mjs';

export const TAVAN = { yerlesim: 200000, denetim: 500 };

// ── Deterministik permütasyonlar (leksikografik) ─────────────────────────────
function permutasyonlar(n) {
  const idx = [...Array(n).keys()];
  const sonuc = [[...idx]];
  // Narayana next-permutation — leksikografik sıra garantili, rastgelelik yok
  for (;;) {
    let i = n - 2;
    while (i >= 0 && idx[i] >= idx[i + 1]) i--;
    if (i < 0) break;
    let j = n - 1;
    while (idx[j] <= idx[i]) j--;
    [idx[i], idx[j]] = [idx[j], idx[i]];
    for (let a = i + 1, b = n - 1; a < b; a++, b--) [idx[a], idx[b]] = [idx[b], idx[a]];
    sonuc.push([...idx]);
  }
  return sonuc;
}

// ── Sıralı ikili ağaç şekilleri (Catalan(n-1) adet) ──────────────────────────
const AGAC_BELLEK = new Map();
function agacSekilleri(n) {
  if (AGAC_BELLEK.has(n)) return AGAC_BELLEK.get(n);
  let sonuc;
  if (n === 1) sonuc = [null];
  else {
    sonuc = [];
    for (let k = 1; k < n; k++) {
      for (const sol of agacSekilleri(k)) for (const sag of agacSekilleri(n - k)) sonuc.push({ k, sol, sag });
    }
  }
  AGAC_BELLEK.set(n, sonuc);
  return sonuc;
}

function hedefToplam(dilim) {
  let s = 0;
  for (const o of dilim) s += o.hedef_m2;
  return s;
}

// Ağacı rect'e yerleştir. yonlar[i]: 0 = dikey kesim (x'te böl) · 1 = yatay kesim (y'de böl).
// Kesim koordinatı 1 cm'e yuvarlanır — determinizm + temiz ızgara.
function yerlestir(dugum, dilim, rect, yonlar, sayac, out) {
  if (dugum === null) { out.push({ oda: dilim[0], x0: rect.x0, y0: rect.y0, x1: rect.x1, y1: rect.y1 }); return true; }
  const yon = yonlar[sayac.i++];
  const sol = dilim.slice(0, dugum.k), sag = dilim.slice(dugum.k);
  const a1 = hedefToplam(sol), a2 = hedefToplam(sag);
  const oran = a1 / (a1 + a2);
  if (yon === 0) {
    const xk = Math.round(rect.x0 + (rect.x1 - rect.x0) * oran);
    if (xk <= rect.x0 || xk >= rect.x1) return false;
    if (!yerlestir(dugum.sol, sol, { ...rect, x1: xk }, yonlar, sayac, out)) return false;
    return yerlestir(dugum.sag, sag, { ...rect, x0: xk }, yonlar, sayac, out);
  }
  const yk = Math.round(rect.y0 + (rect.y1 - rect.y0) * oran);
  if (yk <= rect.y0 || yk >= rect.y1) return false;
  if (!yerlestir(dugum.sol, sol, { ...rect, y1: yk }, yonlar, sayac, out)) return false;
  return yerlestir(dugum.sag, sag, { ...rect, y0: yk }, yonlar, sayac, out);
}

// Ucuz ön-eleme: kural asgarileri + program dar-kenar hedefi. Denetimden ÖNCE eler
// (denetleKos pahalı); elemesi kural VERİSİNE dayanır, kuralı gevşetmez.
function onEleme(parcalar) {
  for (const p of parcalar) {
    const w = p.x1 - p.x0, h = p.y1 - p.y0;
    if (Math.min(w, h) < p.oda.min_dar_kenar_cm) return false;
    if (alanM2([[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]) < p.oda.asgari_m2) return false;
  }
  return true;
}

function imza(parcalar) {
  return parcalar.map((p) => `${p.oda.id}:${p.x0},${p.y0},${p.x1},${p.y1}`).sort().join('|');
}

// Ön-skor (düşük = iyi): hedef-alan sapması + biçim oranı cezası. Denetim tavanı devreye
// girdiğinde HANGİ adayların denetleneceğini deterministik olarak seçer.
function onSkor(parcalar) {
  let sapma = 0, bicim = 0;
  for (const p of parcalar) {
    const w = p.x1 - p.x0, h = p.y1 - p.y0;
    const m2 = alanM2([[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]);
    sapma += Math.abs(m2 - p.oda.hedef_m2) / p.oda.hedef_m2;
    bicim += Math.max(w, h) / Math.min(w, h) - 1;
  }
  const n = parcalar.length;
  return { sapma: sapma / n, bicim: bicim / n, toplam: (3 * sapma + bicim) / n };
}

// TEK dikdörtgen parça içinde tüm slicing yerleşimlerini üretir (FAZ A çekirdeği).
// Döner: { liste: [rectDizisi], denenen, gecen, budandi, istatistik }
function parcaYerlesimleri(odalar, rect, tavan) {
  const n = odalar.length;
  const agaclar = agacSekilleri(n);
  const yonSayisi = 1 << (n - 1);
  const tumPerm = permutasyonlar(n);
  const permBasi = agaclar.length * yonSayisi;
  const permTavan = Math.max(1, Math.floor(tavan / permBasi));
  const permler = tumPerm.slice(0, permTavan);

  const gorulen = new Map();
  let denenen = 0, onGecen = 0;
  for (const perm of permler) {
    const dilim = perm.map((i) => odalar[i]);
    for (const agac of agaclar) {
      for (let maske = 0; maske < yonSayisi; maske++) {
        const yonlar = [];
        for (let b = 0; b < n - 1; b++) yonlar.push((maske >> b) & 1);
        const out = [];
        denenen++;
        if (!yerlestir(agac, dilim, rect, yonlar, { i: 0 }, out)) continue;
        if (!onEleme(out)) continue;
        onGecen++;
        const im = imza(out);
        if (!gorulen.has(im)) gorulen.set(im, out);
      }
    }
  }
  const liste = [...gorulen.entries()]
    .sort((a, b) => onSkor(a[1]).toplam - onSkor(b[1]).toplam || (a[0] < b[0] ? -1 : 1))
    .map(([, v]) => v);
  return {
    liste, denenen, onGecen,
    budandi: permler.length < tumPerm.length,
    perm_toplam: tumPerm.length, perm_denenen: permler.length, agac_sekli: agaclar.length, yon_kombinasyonu: yonSayisi,
  };
}

// ── Oda → sınır-parçası atamaları (FAZ B2) ───────────────────────────────────
// Her parça en az bir oda almalı. Atama, parça alan oranı ile grup hedef-alan oranı
// arasındaki UYUMSUZLUĞA göre sıralanır: slicing parçayı TAMAMEN doldurduğundan, oranı
// tutmayan atama odaları hedefinden uzaklaştırır (ihlal değil ama kötü plan).
function atamalar(odaSayisi, parcaSayisi) {
  const sonuc = [];
  const toplam = parcaSayisi ** odaSayisi;
  for (let kod = 0; kod < toplam; kod++) {
    const atama = [];
    let k = kod;
    for (let i = 0; i < odaSayisi; i++) { atama.push(k % parcaSayisi); k = Math.floor(k / parcaSayisi); }
    if (new Set(atama).size !== parcaSayisi) continue; // boş parça kalamaz
    sonuc.push(atama);
  }
  return sonuc;
}

// Döner: { yerlesimler: [{parcalar, imza, on, sinif}], istatistik }
export function yerlesimUret(norm) {
  const sinirParcalari = norm.parcalar ?? [{ ...norm.rect }];
  const n = norm.odalar.length;

  // ── Tek parça (dikdörtgen sınır): FAZ A yolu, davranış AYNEN korunur ───────
  if (sinirParcalari.length === 1) {
    const r = parcaYerlesimleri(norm.odalar, sinirParcalari[0], TAVAN.yerlesim);
    const yerlesimler = r.liste.map((out) => ({ parcalar: out, imza: imza(out), on: onSkor(out), sinif: onSinif(out) }))
      .sort((a, b) => a.on.toplam - b.on.toplam || (a.imza < b.imza ? -1 : 1));
    return {
      yerlesimler,
      istatistik: {
        oda_sayisi: n, sinir_parcasi: 1,
        permutasyon_toplam: r.perm_toplam, permutasyon_denenen: r.perm_denenen,
        agac_sekli: r.agac_sekli, yon_kombinasyonu: r.yon_kombinasyonu,
        denenen_yerlesim: r.denenen, on_elemeden_gecen: r.onGecen,
        essiz_yerlesim: yerlesimler.length, enumerasyon_budandi: r.budandi,
      },
    };
  }

  // ── Çok parça (L/U sınır) ─────────────────────────────────────────────────
  const K = sinirParcalari.length;
  const parcaAlan = sinirParcalari.map((p) => alanM2([[p.x0, p.y0], [p.x1, p.y0], [p.x1, p.y1], [p.x0, p.y1]]));
  const alanToplam = parcaAlan.reduce((s, a) => s + a, 0);
  const hedefToplam = norm.odalar.reduce((s, o) => s + o.hedef_m2, 0);

  const ATAMA_TAVAN = 30;      // N BAŞARILI atama toplanana dek yürünür (deterministik sıra)
  const ATAMA_INCELEME = 2000; // en fazla bu kadar atama gözden geçirilir (kombinatorik tavan)
  const KOMBINE_TAVAN = 4000;  // atama başına birleştirilecek yerleşim üst sınırı
  const tumAtamalar = atamalar(n, K)
    .map((atama) => {
      let uyumsuzluk = 0;
      for (let p = 0; p < K; p++) {
        const grupHedef = norm.odalar.reduce((s, o, i) => s + (atama[i] === p ? o.hedef_m2 : 0), 0);
        uyumsuzluk += Math.abs(grupHedef / hedefToplam - parcaAlan[p] / alanToplam);
      }
      return { atama, uyumsuzluk, anahtar: atama.join('') };
    })
    .sort((a, b) => a.uyumsuzluk - b.uyumsuzluk || (a.anahtar < b.anahtar ? -1 : 1));
  const gorulen = new Map();
  let denenen = 0, onGecen = 0, budandi = false;
  let incelenen = 0, basarili = 0;
  const parcaBasi = Math.max(1, Math.floor(KOMBINE_TAVAN ** (1 / K)));

  // ⚠️ Tavan "denenen atama" değil "BAŞARILI atama" üzerinden sayılır. İlk yazımda en uyumlu
  // 30 atamayı alıp kesmiştim ve U sınırda SIFIR yerleşim çıktı: alan oranı en iyi tutan
  // atamalar geometrik olarak çıkmazdı (400×300 parçaya mutfak+banyo → biri 144 cm, asgari
  // 150'nin altı). Alan-uyumu FİZİBİLİTE demek değil; çalışan atamalar listenin derinindeydi.
  for (const { atama } of tumAtamalar) {
    if (basarili >= ATAMA_TAVAN || incelenen >= ATAMA_INCELEME || denenen >= TAVAN.yerlesim) {
      budandi = budandi || basarili >= ATAMA_TAVAN || incelenen < tumAtamalar.length;
      break;
    }
    incelenen++;
    const listeler = [];
    let olabilir = true;
    for (let p = 0; p < K; p++) {
      const grup = norm.odalar.filter((_, i) => atama[i] === p);
      const r = parcaYerlesimleri(grup, sinirParcalari[p], Math.floor(TAVAN.yerlesim / (K * ATAMA_TAVAN)) || 1);
      denenen += r.denenen;
      if (r.budandi) budandi = true;
      if (!r.liste.length) { olabilir = false; break; }
      listeler.push(r.liste.slice(0, parcaBasi));
    }
    if (!olabilir) continue;
    basarili++;
    // Kartezyen birleştirme — deterministik sıra (her parçanın ön-skorca en iyileri)
    const sayaclar = new Array(K).fill(0);
    for (;;) {
      const out = listeler.flatMap((l, p) => l[sayaclar[p]]);
      onGecen++;
      const im = imza(out);
      if (!gorulen.has(im)) gorulen.set(im, { parcalar: out, imza: im, on: onSkor(out), sinif: onSinif(out) });
      let p = K - 1;
      while (p >= 0 && ++sayaclar[p] >= listeler[p].length) { sayaclar[p] = 0; p--; }
      if (p < 0) break;
    }
  }

  const yerlesimler = [...gorulen.values()].sort((a, b) => a.on.toplam - b.on.toplam || (a.imza < b.imza ? -1 : 1));
  return {
    yerlesimler,
    istatistik: {
      oda_sayisi: n, sinir_parcasi: K,
      atama_toplam: tumAtamalar.length, atama_incelenen: incelenen, atama_basarili: basarili,
      parca_basina_alinan: parcaBasi,
      denenen_yerlesim: denenen, on_elemeden_gecen: onGecen,
      essiz_yerlesim: yerlesimler.length, enumerasyon_budandi: budandi,
    },
  };
}
