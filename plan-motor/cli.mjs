#!/usr/bin/env node
// plan-motor — tek giriş noktası, dosya-tabanlı sözleşme (MEDDAH md.2).
// Komutlar: ciz · olc · revize · oku · dogrula
// Çıkış kodları: 0 başarı · 1 doğrulama/fail-closed · 2 kullanım hatası · 3 iç hata
// FAIL-CLOSED: ölçek/geometri doğrulanamıyorsa çıktı dosyası YAZILMAZ.
import { writeFileSync, readFileSync, mkdirSync } from 'fs';
import { modelYukle, dogrulaVeyaDur, dogrula, odaRaporu, MotorHata } from './lib/model.mjs';
import { uzunluk, cevreCm } from './lib/geometri.mjs';
import { svgUret } from './lib/svg.mjs';
import { metrikBas } from './lib/metrik.mjs';

const baslangic = performance.now();
const [, , komut, ...ham] = process.argv;

// Üretilen çizimi YAZMADAN önce sına — kusurluysa hiç yazma (MEDDAH md.5).
async function ozDenetle(svg, baglam) {
  const { renderDenetle } = await import('./lib/render-denetle.mjs');
  const { hata, uyari } = renderDenetle(svg, baglam);
  for (const u of uyari) console.error(`⚠ ${u}`);
  if (hata.length) {
    for (const h of hata) console.error(`✗ ${h}`);
    throw new MotorHata(`çizim öz-denetimi: ${hata.length} kusur — çıktı YAZILMADI`, 1);
  }
}

function bayrak(ad) { return ham.includes(`--${ad}`); }

// B-002 (SEDİR bulgusu): PNG varsayılanı truecolor+alfa idi. Ürettiğimiz şey TEKNİK ÇİZİM —
// avuç içi kadar renk. Palet kodlaması dosyayı ~3 kat küçültür (297 KB → 92 KB ölçüldü) ve
// Sultan'ın önizleyicisi büyük dosyayı açamıyordu. Gerçek fotoğraf/gradyan gerekirse
// --png-truecolor eski davranışı geri verir (davranış kaybı yok, yalnız varsayılan değişti).
async function pngYaz(svg, yol) {
  const sharp = (await import('sharp')).default;
  const s = sharp(Buffer.from(svg));
  await (bayrak('png-truecolor') ? s.png({ compressionLevel: 9 }) : s.png({ palette: true, compressionLevel: 9 })).toFile(yol);
}

function argAl(ad, zorunlu = false) {
  const i = ham.indexOf(`--${ad}`);
  if (i < 0 || i + 1 >= ham.length || ham[i + 1].startsWith('--')) {
    if (zorunlu) throw new MotorHata(`--${ad} zorunlu`, 2);
    return undefined;
  }
  return ham[i + 1];
}

const KULLANIM = `plan-motor — kat planı motoru (birim: cm, fail-closed)
  ciz     --model m.json --cikti plan.svg [--png plan.png] [--dxf plan.dxf] [--not "..."]
          (--png palet kodlar ~3x kucuk; gercek gradyan gerekirse --png-truecolor)
  olc     --model m.json [--oda id | --duvar id | --mesafe n1,n2]
  revize  --model m.json --degisiklik d.json --cikti yeni.json [--rapor fark.json] [--ciz yeni.svg]
  goster  --dosya x.dwg|x.dxf --cikti plan.svg [--png p.png] [--baslik "..."] [--alt "..."]
          [--vurgu v.json] [--duzenle d.json] [--kirp x0,y0,x1,y1] [--cikar-json g.json]
          (çizimi KENDİ geometrisiyle çizer — mevcut planı GÖSTERMEK için; ciz ise modelden üretir)
  oku     --dosya x.dxf|x.dwg [--rapor r.json]
  dogrula --model m.json
  denetle --model m.json --kural-seti k.json [--rapor r.json]
          (mimari kural denetimi — eşikler kural VERİSİNDEN gelir; hata-ihlali = RC 1)
  uret    --program p.json --kural-seti k.json --cikti-dizin d/ [--adet 3]
          (boş sınır + oda programı → aday model.json'lar; her aday dogrula+denetle'den
           GEÇMİŞTİR. Sığmayan program = dürüst RC 1, sahte plan üretilmez)
  ortak:  [--metrik defter.jsonl] [--png-truecolor]`;

async function ana() {
  switch (komut) {
    case 'ciz': {
      const model = modelYukle(argAl('model', true));
      dogrulaVeyaDur(model);
      const svg = svgUret(model, { notu: argAl('not') });
      await ozDenetle(svg, { model });                    // fail-closed: kusurlu çizim YAZILMAZ
      const cikti = argAl('cikti', true);
      writeFileSync(cikti, svg);
      console.log(`✓ SVG: ${cikti}`);
      const pngYolu = argAl('png');
      if (pngYolu) {
        const { fontHazirla } = await import('./lib/font.mjs');
        fontHazirla();
        await pngYaz(svg, pngYolu);
        console.log(`✓ PNG: ${pngYolu}`);
      }
      const dxfYolu = argAl('dxf');
      if (dxfYolu) {
        const { dxfUret } = await import('./lib/dxf.mjs');
        const { icerik, uyarilar } = dxfUret(model);
        for (const u of uyarilar) console.error(`⚠ ${u}`);
        writeFileSync(dxfYolu, icerik);
        console.log(`✓ DXF: ${dxfYolu} (katmanlar: A-WALL A-DOOR A-GLAZ A-AREA-IDEN A-ANNO-DIMS · birim cm)`);
      }
      const dwgYolu = argAl('dwg');
      if (dwgYolu) {
        // Mobilya katmanı opsiyonel: plan-dekor yerleşimi verilirse A-FURN'e yazılır.
        let yerlesimler = [];
        const yerlesimYolu = argAl('yerlesim');
        if (yerlesimYolu && yerlesimYolu !== true) {
          const y = JSON.parse(readFileSync(yerlesimYolu, 'utf8'));
          const no = Number(argAl('aday') || 1);
          const aday = y.adaylar?.find((a) => a.no === no) ?? y.adaylar?.[0];
          yerlesimler = aday?.yerlesimler ?? [];
        }
        const { dwgUret } = await import('./lib/dwg.mjs');
        const { bayt, sihir, sayac, uyarilar } = dwgUret(model, { yerlesimler });
        for (const u of uyarilar) console.error(`⚠ ${u}`);
        writeFileSync(dwgYolu, bayt);
        console.log(`✓ DWG: ${dwgYolu} (${sihir} · ${bayt.length} bayt · duvar ${sayac.duvar} · kapı ${sayac.kapi} · pencere ${sayac.pencere} · etiket ${sayac.etiket} · mobilya ${sayac.mobilya})`);
      }
      return { girdi: argAl('model'), cikti };
    }

    case 'olc': {
      const model = modelYukle(argAl('model', true));
      dogrulaVeyaDur(model);
      const oda = argAl('oda'), duvar = argAl('duvar'), mesafe = argAl('mesafe');
      let sonuc;
      if (oda) {
        const o = model.odalar.find((x) => x.id === oda);
        if (!o) throw new MotorHata(`oda "${oda}" yok (var: ${model.odalar.map((x) => x.id).join(', ')})`, 2);
        const koseler = o.dongu.map((n) => model.noktalar[n]);
        const r = odaRaporu(model).find((x) => x.oda === oda);
        sonuc = { ...r, cevre_cm: +cevreCm(koseler).toFixed(1) };
      } else if (duvar) {
        const d = model.duvarlar.find((x) => x.id === duvar);
        if (!d) throw new MotorHata(`duvar "${duvar}" yok`, 2);
        sonuc = { duvar, uzunluk_cm: +uzunluk(model.noktalar[d.bas], model.noktalar[d.son]).toFixed(1), kalinlik_cm: d.kalinlik, tip: d.tip };
      } else if (mesafe) {
        const [a, b] = mesafe.split(',');
        if (!model.noktalar[a] || !model.noktalar[b]) throw new MotorHata(`mesafe: nokta bulunamadı (${mesafe})`, 2);
        sonuc = { noktalar: [a, b], mesafe_cm: +uzunluk(model.noktalar[a], model.noktalar[b]).toFixed(1) };
      } else {
        const odalar = odaRaporu(model);
        sonuc = {
          odalar,
          toplam_m2: +odalar.reduce((s, r) => s + r.m2, 0).toFixed(2),
          duvar_sayisi: model.duvarlar.length,
          aciklik_sayisi: (model.acikliklar ?? []).length,
        };
      }
      console.log(JSON.stringify(sonuc, null, 2));
      return { girdi: argAl('model') };
    }

    case 'revize': {
      const modelYolu = argAl('model', true);
      const eski = modelYukle(modelYolu);
      dogrulaVeyaDur(eski, 'mevcut model');
      const degisiklikler = JSON.parse(readFileSync(argAl('degisiklik', true), 'utf8'));
      const { revizeUygula, farkRaporu } = await import('./lib/revize.mjs');
      const yeni = revizeUygula(structuredClone(eski), degisiklikler);
      dogrulaVeyaDur(yeni, 'revize sonrası model'); // fail-closed: bozan revizyon yazılmaz
      const cikti = argAl('cikti', true);
      const fark = farkRaporu(eski, yeni, degisiklikler);
      writeFileSync(cikti, JSON.stringify(yeni, null, 2) + '\n');
      console.log(`✓ yeni model: ${cikti}`);
      const raporYolu = argAl('rapor');
      if (raporYolu) writeFileSync(raporYolu, JSON.stringify(fark, null, 2) + '\n');
      console.log(JSON.stringify(fark, null, 2));
      const svgYolu = argAl('ciz');
      if (svgYolu) {
        const revizeSvg = svgUret(yeni, { notu: 'revize edilmiş' });
        await ozDenetle(revizeSvg, { model: yeni });      // bu yol da denetimden kaçamaz
        writeFileSync(svgYolu, revizeSvg);
        console.log(`✓ SVG: ${svgYolu}`);
      }
      return { girdi: modelYolu, cikti };
    }

    case 'goster': {
      // Bir CAD dosyasını KENDİ geometrisiyle çiz (model üretmeden, sadık gösterim).
      const dosya = argAl('dosya', true);
      const { cadEntities, cadSvg, duvarGovdeleri, duzenleUygula } = await import('./lib/cad-render.mjs');
      let ents = await cadEntities(dosya);
      const duzYolu = argAl('duzenle');
      if (duzYolu) {
        const { entities, gunluk } = duzenleUygula(ents, JSON.parse(readFileSync(duzYolu, 'utf8')));
        for (const g of gunluk) console.log(`  · ${g}`);
        ents = entities;
      }
      if (!ents.length) throw new MotorHata(`${dosya}: çizilebilir nesne yok`, 1);
      // Duvarlar kapalı gövde olarak çizilmemişse gövdeyi çizgilerden kapat (dolgu için).
      // ⚠️ "BİR TANE kapalı varsa atla" YANLIŞ: bir dosyada 47 duvarın 8'i kapalı, 39'u
      // açıktı; o 39'u dolgusuz bıraktı. Ölçüt HEPSİ kapalı mı olmalı.
      const duvarPoly = ents.filter((e) => e.tur === 'poly' && e.katman === 'px_walls');
      const hepsiKapali = duvarPoly.length > 0 && duvarPoly.every((e) => e.kapali);
      const govdeler = hepsiKapali ? null : duvarGovdeleri(ents);
      if (govdeler?.length) console.log(`  · duvar gövdesi çizgilerden kapatıldı: ${govdeler.length} parça`);
      const vurguYolu = argAl('vurgu');
      const vurgu = vurguYolu ? JSON.parse(readFileSync(vurguYolu, 'utf8')) : null;
      const kirpArg = argAl('kirp');
      const kirp = kirpArg ? kirpArg.split(',').map(Number) : null;
      const cikarYolu = argAl('cikar-json');
      if (cikarYolu) {
        // ölçüm hattına (lifting) girdi: düzenleme uygulanmış haliyle sınır + etiket
        const sinir = [];
        for (const e of ents) {
          if (e.tur !== 'poly' || !['px_walls', 'px_openings', 'px_columns', 'Zone_Line'].includes(e.katman)) continue;
          const k = e.koseler, son = e.kapali ? k.length : k.length - 1;
          for (let i = 0; i < son; i++) sinir.push([[k[i].x, k[i].y], [k[(i + 1) % k.length].x, k[(i + 1) % k.length].y]]);
        }
        const etiketler = ents.filter((e) => e.tur === 'metin').map((e) => {
          const t = e.metin.replace(/^\{/, '').replace(/\}$/, '').replace(/\\f[^;]*;/g, '').split(/\\P/);
          return { ad: (t[0] || '').trim(), m2: null, x: e.x, y: e.y };
        });
        writeFileSync(cikarYolu, JSON.stringify({ sinir, etiketler }));
        console.log(`✓ ölçüm girdisi: ${cikarYolu} (${sinir.length} segment, ${etiketler.length} etiket)`);
      }
      const svg = cadSvg(ents, { baslik: argAl('baslik'), altbaslik: argAl('alt'), govdeler, vurgu, kirp });
      await ozDenetle(svg, { entities: ents });           // fail-closed: kusurlu çizim YAZILMAZ
      const cikti = argAl('cikti', true);
      writeFileSync(cikti, svg);
      console.log(`✓ SVG: ${cikti} (${ents.length} nesne, ${new Set(ents.map((e) => e.katman)).size} katman)`);
      const pngYolu = argAl('png');
      if (pngYolu) {
        const { fontHazirla } = await import('./lib/font.mjs');
        fontHazirla();
        await pngYaz(svg, pngYolu);
        console.log(`✓ PNG: ${pngYolu}`);
      }
      return { girdi: dosya, cikti };
    }

    case 'oku': {
      const dosya = argAl('dosya', true);
      const { dosyaOku } = await import('./lib/oku.mjs');
      const rapor = await dosyaOku(dosya);
      console.log(JSON.stringify(rapor, null, 2));
      const raporYolu = argAl('rapor');
      if (raporYolu) writeFileSync(raporYolu, JSON.stringify(rapor, null, 2) + '\n');
      return { girdi: dosya, cikti: raporYolu };
    }

    case 'dogrula': {
      const model = modelYukle(argAl('model', true));
      const { hatalar, uyarilar } = dogrula(model);
      for (const u of uyarilar) console.error(`⚠ ${u}`);
      for (const h of hatalar) console.error(`✗ ${h}`);
      if (hatalar.length) throw new MotorHata(`${hatalar.length} hata`, 1);
      console.log(`✓ geçerli (${model.odalar.length} oda, ${model.duvarlar.length} duvar, ${(model.acikliklar ?? []).length} açıklık; ${uyarilar.length} uyarı)`);
      return { girdi: argAl('model') };
    }

    case 'denetle': {
      // ŞAKÜL: mimari kural denetimi. Geometrik taban sağlam değilse mimari yargı anlamsız →
      // önce dogrula (fail-closed), sonra kural motoru. Uyarı RC'yi değiştirmez, hata-ihlali RC 1.
      const model = modelYukle(argAl('model', true));
      dogrulaVeyaDur(model);
      const { kuralSetiYukle, denetleKos } = await import('./lib/denetle.mjs');
      const ks = kuralSetiYukle(argAl('kural-seti', true));
      const { ihlaller, uyarilar, bilgiler, baglam } = denetleKos(model, ks);
      console.log(`denetle — kural-seti: ${ks.ad ?? argAl('kural-seti')} (${ks.surum ?? 'sürümsüz'}) · ${ks.kurallar.length} kural · ${baglam.plan.oda_sayisi} oda`);
      for (const b of bilgiler) console.log(`  · ${b}`);
      for (const u of uyarilar) console.error(`⚠ ${u}`);
      for (const h of ihlaller) console.error(`✗ ${h}`);
      const raporYolu = argAl('rapor');
      if (raporYolu) writeFileSync(raporYolu, JSON.stringify({ kural_seti: ks.ad ?? null, surum: ks.surum ?? null, ihlaller, uyarilar, bilgiler, baglam }, null, 2) + '\n');
      if (ihlaller.length) throw new MotorHata(`${ihlaller.length} kural ihlali (hata şiddetinde)`, 1);
      console.log(`✓ ihlal yok (${uyarilar.length} uyarı, ${bilgiler.length} bilgi)`);
      return { girdi: argAl('model'), cikti: raporYolu };
    }

    case 'uret': {
      // PERGEL FAZ A — ÜRETİM. Sözleşme additive: mevcut komutların davranışı değişmedi.
      // Zincir: program kapısı → slicing enumerasyonu → model kurma → dogrula+denetle → sırala.
      // Hiçbir aday sınavı geçemiyorsa RC 1: "üretemedim" demek, geçemeyen planı yazmaktan iyidir.
      const programYolu = argAl('program', true);
      const ksYolu = argAl('kural-seti', true);
      const ciktiDizin = argAl('cikti-dizin', true);
      const adetHam = argAl('adet') ?? '3';
      const adet = Number(adetHam);
      if (!Number.isInteger(adet) || adet < 1) throw new MotorHata(`--adet pozitif tam sayı olmalı (gelen: ${adetHam})`, 2);

      const { programYukle, programDogrula, kuralEsikleri } = await import('./lib/uret-program.mjs');
      const { kuralSetiYukle } = await import('./lib/denetle.mjs');
      const { yerlesimUret, TAVAN } = await import('./lib/uret-yerlesim.mjs');
      const { modelKur } = await import('./lib/uret-model.mjs');
      const { puanla } = await import('./lib/uret-puan.mjs');
      const { EKSENLER, eksenleriOlc, kombinasyonAnahtari, kombinasyonMetni } = await import('./lib/uret-eksen.mjs');

      const ks = kuralSetiYukle(ksYolu);              // bozuk kural-seti = RC 1 (aynı kapı)
      const esikler = kuralEsikleri(ks);              // eşikler kural VERİSİNDEN okunur
      const program = programYukle(programYolu);
      const { hatalar, uyarilar, norm } = programDogrula(program, esikler);
      for (const u of uyarilar) console.error(`⚠ ${u}`);
      if (hatalar.length) {
        for (const h of hatalar) console.error(`✗ ${h}`);
        throw new MotorHata(`program reddedildi: ${hatalar.length} hata — üretim BAŞLAMADI (fail-closed)`, 1);
      }

      const { yerlesimler, istatistik } = yerlesimUret(norm);
      if (istatistik.enumerasyon_budandi) {
        const nasil = istatistik.sinir_parcasi > 1
          ? `${istatistik.atama_incelenen}/${istatistik.atama_toplam} oda-parça ataması incelendi, ${istatistik.atama_basarili} tanesi yerleşim verdi`
          : `${istatistik.permutasyon_denenen}/${istatistik.permutasyon_toplam} oda sırası denendi`;
        console.error(`⚠ enumerasyon budandı: ${nasil} (yerleşim tavanı ${TAVAN.yerlesim}) — arama TAM DEĞİL, "en iyi" yereldir`);
      }
      // ── Denetim bütçesini KATMANLI dağıt (FAZ B1) ────────────────────────────
      // Ön-skorca en iyi N'i almak, bütçeyi tek mimari aileye harcar: çeşitliliği kapı
      // değil BÜTÇE öldürür ve kimse fark etmez. Bu yüzden adaylar ucuz geometrik ön-sınıfa
      // bölünür ve her katmandan sırayla en iyiler alınır (deterministik round-robin).
      const katmanlar = new Map();
      for (const y of yerlesimler) (katmanlar.get(y.sinif) ?? katmanlar.set(y.sinif, []).get(y.sinif)).push(y);
      const katmanSirasi = [...katmanlar.keys()].sort();
      const denetlenecek = [];
      for (let i = 0; denetlenecek.length < TAVAN.denetim; i++) {
        let eklendi = false;
        for (const k of katmanSirasi) {
          const y = katmanlar.get(k)[i];
          if (!y) continue;
          denetlenecek.push(y);
          eklendi = true;
          if (denetlenecek.length >= TAVAN.denetim) break;
        }
        if (!eklendi) break;
      }
      if (yerlesimler.length > denetlenecek.length) {
        console.error(`⚠ ${yerlesimler.length} eşsiz yerleşimin ${denetlenecek.length}'i denetlendi (tavan ${TAVAN.denetim}) — bütçe ${katmanSirasi.length} geometrik katmana eşit dağıtıldı`);
      }

      const elenen = { kurulamadi: 0, dogrula: 0, denetle: 0, olculemedi: 0 };
      const ornekSebep = { kurulamadi: null, dogrula: null, denetle: null, olculemedi: null };
      const gecen = [];
      for (const y of denetlenecek) {
        const { model, sebep, notlar } = modelKur(y.parcalar, norm, esikler);
        if (!model) { elenen.kurulamadi++; ornekSebep.kurulamadi ??= sebep; continue; }
        const p = puanla({ model, parcalar: y.parcalar }, norm, ks);
        if (!p.gecerli) { elenen[p.sebep]++; ornekSebep[p.sebep] ??= p.ayrinti[0]; continue; }
        // Mimari kararlar BEYAN edilmez, MODELDEN ÖLÇÜLÜR — etiket iddia değil kanıt olsun.
        let eksen;
        try { eksen = eksenleriOlc(model); }
        catch (e) { elenen.olculemedi++; ornekSebep.olculemedi ??= e.message; continue; }
        gecen.push({ model, puan: p, notlar, imza: y.imza, eksen, kombinasyon: kombinasyonAnahtari(eksen) });
      }
      gecen.sort((a, b) => a.puan.skor - b.puan.skor || (a.imza < b.imza ? -1 : 1));

      // MİMARİ KOMBİNASYONA GÖRE TEKİLLEŞTİRME (FAZ B1) — mimar "şu üç plan farklı" demez,
      // "ıslak çekirdek içeride, sirkülasyon halka" der. Bir seçenek = bir KARAR KOMBİNASYONU.
      // Aynı kombinasyondan iki plan aynı fikrin varyasyonudur; en iyisi yazılır, ötekiler
      // sayılır ama yazılmaz. (Bu, FAZ A'nın ayna-tekilleştirmesini de kapsar: ayna, aynı
      // kombinasyonu ölçer.)
      const kombinasyonlar = new Map();
      for (const g of gecen) {
        const mevcut = kombinasyonlar.get(g.kombinasyon);
        if (!mevcut) kombinasyonlar.set(g.kombinasyon, { en_iyi: g, adet: 1 });
        else { mevcut.adet++; if (g.puan.skor < mevcut.en_iyi.puan.skor) mevcut.en_iyi = g; }
      }
      const tekil = [...kombinasyonlar.values()]
        .sort((a, b) => a.en_iyi.puan.skor - b.en_iyi.puan.skor || (a.en_iyi.imza < b.en_iyi.imza ? -1 : 1))
        .map((k) => ({ ...k.en_iyi, ayni_kombinasyondan: k.adet }));

      // Hangi eksen değerleri HİÇ görülmedi — çeşitliliğin sınırı da bilgidir (sessiz kalmaz).
      const gorulenDegerler = {};
      for (const e of EKSENLER) gorulenDegerler[e.id] = [...new Set(gecen.map((g) => g.eksen[e.id]))].sort();

      const rapor = {
        program: programYolu, kural_seti: ks.ad ?? ksYolu, kural_seti_surum: ks.surum ?? null,
        istatistik: {
          ...istatistik, denetlenen: denetlenecek.length, geometrik_katman: katmanSirasi.length,
          gecen: gecen.length, essiz_kombinasyon: tekil.length, istenen_adet: adet, elenen, elenme_ornegi: ornekSebep,
        },
        // Eksenlerin TANIMI ve DAYANAĞI raporla birlikte gider: mimar etiketi okurken neye
        // dayandığını da görsün, "uydurulmuş kategori" şüphesi doğmasın.
        eksenler: EKSENLER.map((e) => ({ id: e.id, ad: e.ad, dayanak: e.dayanak, degerler: e.degerler })),
        gorulen_eksen_degerleri: gorulenDegerler,
        kombinasyon_dagilimi: [...kombinasyonlar.entries()]
          .map(([anahtar, v]) => ({ kombinasyon: anahtar, plan_sayisi: v.adet, en_iyi_skor: v.en_iyi.puan.skor }))
          .sort((a, b) => a.en_iyi_skor - b.en_iyi_skor),
        adaylar: [],
      };

      if (!gecen.length) {
        for (const [k, v] of Object.entries(ornekSebep)) if (v) console.error(`  · elenme örneği (${k}): ${v}`);
        throw new MotorHata(`hiçbir aday dogrula+denetle'den geçemedi (${istatistik.essiz_yerlesim} eşsiz yerleşim denendi) — sahte plan YAZILMADI`, 1);
      }

      mkdirSync(ciktiDizin, { recursive: true });
      const secilen = tekil.slice(0, adet);
      if (secilen.length < adet) {
        console.error(`⚠ ${adet} aday istendi, ${secilen.length} EŞSİZ MİMARİ KOMBİNASYON bulundu — kalanlar aynı karar kombinasyonunun varyasyonuydu ve yazılmadı (${gecen.length} geçen plan → ${tekil.length} kombinasyon)`);
      }
      for (let i = 0; i < secilen.length; i++) {
        const ad = `aday-${String(i + 1).padStart(2, '0')}.json`;
        const yol = `${ciktiDizin.replace(/\/$/, '')}/${ad}`;
        const s = secilen[i];
        // Kararlar modele DAMGALANIR: dosya tek başına dolaşınca da hangi fikirden geldiği
        // okunur. `ad` SVG başlığına düşer (ciz), `mimari_kararlar` makine tarafına.
        s.model.ad = `${norm.ad ?? 'PERGEL'} · A${i + 1} — ${kombinasyonMetni(s.eksen)}`;
        s.model.mimari_kararlar = { ...s.eksen, kombinasyon: s.kombinasyon, olcum: 'modelden TÜRETİLDİ (beyan değil) — lib/uret-eksen.mjs' };
        writeFileSync(yol, JSON.stringify(s.model, null, 2) + '\n');
        rapor.adaylar.push({
          dosya: ad, skor: s.puan.skor, mimari_kararlar: s.eksen, kombinasyon: s.kombinasyon,
          ayni_kombinasyondan_plan: s.ayni_kombinasyondan,
          detay: s.puan.detay, notlar: s.notlar, uyarilar: s.puan.uyarilar,
        });
        console.log(`✓ ${ad} — ${kombinasyonMetni(s.eksen)}`);
        console.log(`    skor ${s.puan.skor} · alan-sapma ${s.puan.detay.alan_sapma_ort} · komşuluk ${s.puan.detay.komsuluk_karsilanan} · ${s.notlar.kapi_sayisi} kapı, ${s.notlar.pencere_sayisi} pencere · aynı kombinasyondan ${s.ayni_kombinasyondan} plan`);
      }
      const raporYolu = `${ciktiDizin.replace(/\/$/, '')}/rapor.json`;
      writeFileSync(raporYolu, JSON.stringify(rapor, null, 2) + '\n');
      console.log(`✓ rapor: ${raporYolu} — ${istatistik.denenen_yerlesim} yerleşim denendi, ${istatistik.essiz_yerlesim} eşsiz, ${gecen.length} sınavı geçti, ${secilen.length} yazıldı`);
      return { girdi: programYolu, cikti: ciktiDizin };
    }

    default:
      console.error(KULLANIM);
      throw new MotorHata(komut ? `bilinmeyen komut: ${komut}` : 'komut verilmedi', 2);
  }
}

try {
  const { girdi, cikti } = (await ana()) ?? {};
  metrikBas({ komut, baslangicMs: baslangic, rc: 0, girdi, cikti, dosya: argAl('metrik') });
  process.exit(0);
} catch (e) {
  const rc = e instanceof MotorHata ? e.rc : 3;
  console.error(`✗ ${e.message}`);
  if (rc === 3 && process.env.PLAN_MOTOR_DEBUG) console.error(e.stack);
  metrikBas({ komut: komut ?? '?', baslangicMs: baslangic, rc, dosya: argAl('metrik') });
  process.exit(rc);
}
