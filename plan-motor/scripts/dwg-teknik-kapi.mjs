#!/usr/bin/env node
// DWG ÇİZİM TEKNİĞİ kapısı — referans çizim analizinden türeyen iddiaları ölçer.
//
// Neden ayrı betik: bu iddialar kabuk içine gömülü `node -e` ile yazılmıştı ve tırnak
// katmanları regex'i bozup SAHTE KIRMIZI üretti (ölçüldü 2026-08-07). Kapı yardımcısı
// test ettiği paketin İÇİNDE yaşar — bu ders daha önce de alınmıştı.
//
// Kullanım:
//   dwg-teknik-kapi.mjs teknik <a.dwg>          → çizim tekniği iddiaları
//   dwg-teknik-kapi.mjs ayni   <a.dwg> <b.dwg>  → GEOMETRİ aynılığı (bayt DEĞİL)
// Çıkış: 0 tuttu · 1 tutmadı · 2 okunamadı
import { DwgReader } from '@node-projects/acad-ts';
import { readFileSync } from 'fs';
import { createHash } from 'crypto';

const oku = (yol) => {
  const b = readFileSync(yol);
  return new DwgReader(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)).read();
};

// 🔴 DWG BAYT-DETERMİNİSTİK DEĞİLDİR (ölçüldü 2026-08-07): aynı model iki kez yazıldığında
// dosyalar 14. bayttan itibaren ayrışıyor — başlıkta zaman damgası var. plan-motor'un
// "aynı girdi = aynı sha256" doktrini bu yüzden DWG kolunda BAYT üzerinden kurulamaz.
// Determinizm GEOMETRİ üzerinden ölçülür: aşağıdaki özet zamandan bağımsızdır.
function geometriOzeti(doc) {
  const satirlar = [];
  for (const e of doc.entities) {
    const p = [];
    for (const v of e.vertices ?? []) {
      const n = v.location ?? v;
      p.push(`${(+n.x).toFixed(4)},${(+n.y).toFixed(4)}`);
    }
    for (const alan of ['insertPoint', 'startPoint', 'endPoint', 'center']) {
      const n = e[alan];
      if (n && typeof n.x === 'number') p.push(`${alan}:${n.x.toFixed(4)},${n.y.toFixed(4)}`);
    }
    for (const yol of e.paths ?? []) {
      for (const kenar of yol.edges ?? []) {
        for (const v of kenar.vertices ?? []) p.push(`h${v.x.toFixed(4)},${v.y.toFixed(4)}`);
      }
    }
    satirlar.push(`${e.constructor.name}|${e.layer?.name ?? ''}|${e.value ?? ''}|${p.join(' ')}`);
  }
  // Sıralama YOK: varlık sırası da çıktının parçasıdır ve deterministik olmalı.
  return createHash('sha256').update(satirlar.join('\n')).digest('hex');
}

const komut = process.argv[2];
const iddialar = [];
const iddia = (ad, kosul) => iddialar.push({ ad, ok: !!kosul });

try {
  if (komut === 'ayni') {
    const [a, b] = [oku(process.argv[3]), oku(process.argv[4])];
    const ha = geometriOzeti(a), hb = geometriOzeti(b);
    iddia(`geometri özeti aynı (${ha.slice(0, 12)} = ${hb.slice(0, 12)})`, ha === hb);
  } else if (komut === 'teknik') {
    const doc = oku(process.argv[3]);
    const ents = [...doc.entities];
    const duvar = ents.filter((e) => e.constructor.name === 'LwPolyline' && e.layer?.name === 'A-WALL');
    const tarama = ents.filter((e) => e.constructor.name === 'Hatch');
    const katman = {};
    for (const l of doc.layers) katman[l.name] = l;
    const stil = [...(doc.textStyles ?? [])];

    iddia('duvar konturu var', duvar.length > 0);
    iddia('duvar konturlarının HEPSİ kapalı (birleşik gövde)', duvar.length > 0 && duvar.every((p) => p.isClosed));
    iddia('kalın-merkez-hattı YOK (eski strateji terk edildi)',
      duvar.every((p) => (p.vertices ?? []).every((v) => !(v.startWidth > 0))));
    iddia('duvar dolgusu ayrı katmanda + ilişkisiz',
      tarama.length > 0 && tarama.every((h) => h.layer?.name === 'A-WALL-PATT' && !h.isAssociative));
    // 🔴 Sıklık desen çizgisinin OFSETİNDE yaşamalı. `_patternScale` alanına yazmak
    // AutoCAD'de düz dolgu üretiyordu (TESHIS-3'te beş varyant da beyaz çıktı, TESHIS-4'te
    // ofsete gömülünce düzeldi). Bu kapı o dersi tutar: ANSI31 taramada ofset, kanonik
    // 0.125'ten belirgin biçimde BÜYÜK olmalı — yani gerçek ölçek gömülmüş olmalı.
    const desenli = tarama.filter((h) => !h.isSolid && h.pattern?.name === 'ANSI31');
    if (desenli.length) {
      iddia('tarama sıklığı OFSETE gömülü (ölçek alanına değil)',
        desenli.every((h) => {
          const o = h.pattern?.lines?.[0]?.offset;
          return o && Math.hypot(o.x, o.y) > 0.5;
        }));
    }
    // 🔴 ADA KULLANMA. Delikli tek sınır yazdığımızda AutoCAD delikleri ada saymadı ve
    // taramayı bütün daireye yaydı (Sultan ekranda gördü, 2026-08-07). Her dolgu TEK dış
    // sınırlı basit bölge olmalı. Bu kapı o dersi tutar.
    iddia('her dolgu TEK sınırlı basit bölge (ada yolu elenmişti)',
      tarama.every((h) => (h.paths ?? []).length === 1));
    // 🔴 Dolgu parçaları ÖRTÜŞMEMELİ. Katı dolguda örtüşme görünmez ama TARAMADA görünür:
    // köşelerde çift tarama, kirli birleşim (Sultan v9'da gördü, 2026-08-08).
    // Çıktının KENDİSİNDEN ölçülür — sınır poligonları okunup ızgara örneklemesi yapılır.
    if (tarama.length > 1) {
      const halkalar = tarama.map((h) => (h.paths?.[0]?.edges?.[0]?.vertices ?? [])
        .map((v) => [v.x, v.y])).filter((h) => h.length >= 3);
      const icinde = (p, h) => {
        let s = false;
        for (let i = 0, j = h.length - 1; i < h.length; j = i++) {
          const [xi, yi] = h[i], [xj, yj] = h[j];
          if (((yi > p[1]) !== (yj > p[1])) && (p[0] < (xj - xi) * (p[1] - yi) / (yj - yi) + xi)) s = !s;
        }
        return s;
      };
      const xs = halkalar.flat().map((p) => p[0]), ys = halkalar.flat().map((p) => p[1]);
      let cakisan = 0;
      for (let x = Math.min(...xs) + 1; x < Math.max(...xs); x += 4) {
        for (let y = Math.min(...ys) + 1; y < Math.max(...ys); y += 4) {
          let n = 0;
          for (const h of halkalar) if (icinde([x, y], h)) { if (++n > 1) break; }
          if (n > 1) cakisan++;
        }
      }
      iddia(`dolgu parçaları örtüşmüyor (${cakisan} çakışan örnek)`, cakisan === 0);
    }
    iddia('metin stili TrueType (.ttf)',
      stil.some((s) => String(s.filename ?? '').toLowerCase().endsWith('.ttf')));
    // Türkçe HAM yazılmalı — harf çevirisi TTF stiliyle çözüldü (TESHIS-2 şerit A).
    // Çeviriye geri düşülürse metinlerde Latin-1 dışı karakter kalmaz; kapı bunu yakalar.
    const odaMetni = ents.filter((e) => e.constructor.name === 'TextEntity'
      && (e.layer?.name === 'A-AREA-IDEN' || e.layer?.name === 'A-FURN'));
    iddia('Türkçe HAM yazılıyor (harf çevirisine geri düşülmedi)',
      odaMetni.some((e) => /[şığŞİĞçöüÇÖÜ]/.test(String(e.value ?? ''))));
    iddia('kalem katmanda: açıklık duvardan ince',
      katman['A-DOOR'] && katman['A-WALL'] && katman['A-DOOR'].lineWeight < katman['A-WALL'].lineWeight);
    iddia('katman renkleri ayrışık (sessiz atama hatası yok)',
      new Set(Object.values(katman).map((l) => l.color?._color)).size > 2);

    // Mobilya etiketi duvar gövdesine GİRMEMELİ. Sultan'ın AutoCAD ekran görüntüsünde
    // etiketler duvarın altında kayboluyordu; ölçüldü → 24 etiketin 9'u ihlaldeydi.
    // Model dosyası verilirse gövde hesaplanıp gerçekten sınanır (4. argüman).
    const modelYolu = process.argv[4];
    if (modelYolu) {
      const { duvarGovdesi } = await import('../lib/duvar-govde.mjs');
      const { readFileSync: oku2 } = await import('fs');
      const { halkalar } = duvarGovdesi(JSON.parse(oku2(modelYolu, 'utf8')));
      const icinde = (p, h) => {
        let s = false;
        for (let i = 0, j = h.length - 1; i < h.length; j = i++) {
          const [xi, yi] = h[i], [xj, yj] = h[j];
          if (((yi > p[1]) !== (yj > p[1])) && (p[0] < (xj - xi) * (p[1] - yi) / (yj - yi) + xi)) s = !s;
        }
        return s;
      };
      const duvarda = (p) => halkalar.some((h) => icinde(p, h.dis) && !h.delikler.some((d) => icinde(p, d)));
      const kacak = ents.filter((e) => e.constructor.name === 'TextEntity' && e.layer?.name === 'A-FURN')
        .filter((e) => {
          const x = e.insertPoint.x, y = -e.insertPoint.y;
          const g = String(e.value).length * e.height * 0.72;
          return duvarda([x, y]) || duvarda([x + g, y]);
        });
      iddia(`mobilya etiketi duvara girmiyor (${kacak.length} ihlal)`, kacak.length === 0);

      // 🔴 AÇIKLIKLAR duvar gövdesinden KESİLMİŞ olmalı. Sultan v10'da gördü: kapı yayı
      // çiziliyordu ama duvar arkasından kesintisiz geçiyordu ("kapı boşlukları yok").
      // Ölçüm: her açıklığın merkezi dolgunun DIŞINDA olmalı.
      const model = JSON.parse(oku2(modelYolu, 'utf8'));
      const dolgular = ents.filter((e) => e.constructor.name === 'Hatch')
        .map((h) => (h.paths?.[0]?.edges?.[0]?.vertices ?? []).map((v) => [v.x, -v.y]))
        .filter((h) => h.length >= 3);
      const kesilmeyen = (model.acikliklar ?? []).filter((ac) => {
        const d = (model.duvarlar ?? []).find((x) => x.id === ac.duvar);
        if (!d) return false;
        const a = model.noktalar[d.bas], b = model.noktalar[d.son];
        if (!a || !b) return false;
        const p = [a[0] + (b[0] - a[0]) * ac.oran, a[1] + (b[1] - a[1]) * ac.oran];
        return dolgular.some((h) => icinde(p, h));
      });
      iddia(`açıklıklar duvardan kesilmiş (${kesilmeyen.length} kesilmemiş)`, kesilmeyen.length === 0);

      // 🔴 PENCERE CAM ÇİZGİSİ — çırak hasadından (2026-08-10, `ders-hasadi/cirak-pencere-cam.md`).
      // Referans ölçümü: `px_openings`ta 20 Line = 10 ÇİFT, her çift Δ=3.0 cm, ve çizgiler
      // duvar kalınlığının İÇİNDE (eksende değil). Eskiden biz açıklığın ortasına TEK çizgi
      // çekiyorduk — plan okuyan mimar için o bir pencere değil, sadece bir çizgidir.
      // Kapıyı ÜRETEN yazmadı: çırak öneriyi bıraktı, kapıyı MEDDAH yazdı (ders-bulan ≠ kapı-yazan).
      const camlar = ents.filter((e) => e.constructor.name === 'Line' && e.layer?.name === 'A-GLAZ');
      const pencereler = (model.acikliklar ?? []).filter((a) => a.tip === 'pencere');
      if (pencereler.length) {
        let eksik = 0, eksende = 0;
        for (const ac of pencereler) {
          const d = (model.duvarlar ?? []).find((x) => x.id === ac.duvar);
          if (!d) continue;
          const a = model.noktalar[d.bas], b = model.noktalar[d.son];
          if (!a || !b) continue;
          const mx = a[0] + (b[0] - a[0]) * ac.oran, my = a[1] + (b[1] - a[1]) * ac.oran;
          const L = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
          const ux = (b[0] - a[0]) / L, uy = (b[1] - a[1]) / L;   // duvar doğrultusu
          const yakin = camlar.filter((e) => {
            const cx = (e.startPoint.x + e.endPoint.x) / 2, cy = -(e.startPoint.y + e.endPoint.y) / 2;
            return Math.hypot(cx - mx, cy - my) < (Number(ac.genislik) || 100);
          });
          if (yakin.length < 4) eksik++;
          // Eksende çizgi: merkeze dik ofseti ~0 olan. Tek çizgili eski çizim tam buydu.
          for (const e of yakin) {
            const cx = (e.startPoint.x + e.endPoint.x) / 2, cy = -(e.startPoint.y + e.endPoint.y) / 2;
            const dik = Math.abs(-(cy - my) * ux + (cx - mx) * uy);
            if (dik < 0.5) eksende++;
          }
        }
        iddia(`pencerede cam çizgisi var, ≥4 (${eksik} eksik pencere)`, eksik === 0);
        iddia(`hiçbir cam çizgisi duvar EKSENİNDE değil (${eksende} eksende)`, eksende === 0);
      }
    }
  } else if (komut === 'kunye') {
    // YERİNDE GÜNCELLEME kayıp denetimi. Müşterinin çizimini geri verirken hiçbir şeyini
    // kaybetmediğimizi ÖLÇER. (N4 testi, 2026-08-07: gerçek 168 varlıklı mimar çizimi.)
    // ⚠️ Bu kapı yalnız SAYABİLDİĞİ boyutları tutar. Dosya boyutu düşebilir — okuyucunun
    // görmediği bölümler (önizleme küçük-resmi vb.) buradan görünmez ve KAYIP SAYILMAZ,
    // ama sessizce geçiştirilmez: aşağıda açıkça bildirilir.
    const [a, b] = [oku(process.argv[3]), oku(process.argv[4])];
    const kunye = (doc) => {
      const e = [...doc.entities];
      const say = (k) => { try { return [...(doc[k] ?? [])].length; } catch { return -1; } };
      return {
        katmanlar: [...doc.layers].map((l) => l.name).sort(),
        bloklar: [...(doc.blockRecords ?? [])].map((x) => x.name).sort(),
        stiller: [...(doc.textStyles ?? [])].map((s) => `${s.name}:${s.filename}`).sort(),
        mtext: e.filter((x) => x.constructor.name === 'MText').map((x) => x.value).sort(),
        tarama: e.filter((x) => x.constructor.name === 'Hatch')
          .map((x) => `${x.pattern?.name}/${(x.paths ?? []).length}`).sort(),
        tablolar: ['layouts', 'dimensionStyles', 'lineTypes', 'vPorts', 'appIds'].map((k) => `${k}=${say(k)}`),
      };
    };
    const [ka, kb] = [kunye(a), kunye(b)];
    for (const alan of Object.keys(ka)) {
      const eksik = ka[alan].filter((x) => !kb[alan].includes(x));
      iddia(`${alan}: kayıp yok (${ka[alan].length} kalem)`, eksik.length === 0);
      if (eksik.length) console.error(`    kaybolan: ${eksik.slice(0, 3).join(' | ')}`);
    }
    const { statSync } = await import('fs');
    const [sa, sb] = [statSync(process.argv[3]).size, statSync(process.argv[4]).size];
    if (sb < sa) {
      console.log(`ℹ boyut ${sa} → ${sb} bayt (%${Math.round((1 - sb / sa) * 100)} küçüldü). ` +
        'Sayılan boyutlarda kayıp YOK; fark okuyucunun görmediği bölümlerde — ölçülemedi, GÖZLE doğrulanmalı.');
    }
  } else {
    console.error('kullanım: dwg-teknik-kapi.mjs teknik <a.dwg> [model.json] | ayni <a> <b> | kunye <once> <sonra>');
    process.exit(2);
  }
} catch (e) {
  console.error(`✗ okunamadı: ${e.message}`);
  process.exit(2);
}

let kirik = 0;
for (const i of iddialar) {
  console.log(`${i.ok ? '✓' : '✗'} ${i.ad}`);
  if (!i.ok) kirik++;
}
process.exit(kirik ? 1 : 0);
