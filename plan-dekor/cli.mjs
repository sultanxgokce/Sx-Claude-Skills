#!/usr/bin/env node
// plan-dekor — tek giriş. Dosya-tabanlı sözleşme: girdi dosyası → çıktı dosyası + RC.
// RC: 0 başarı · 1 doğrulama/fail-closed (çıktı YAZILMAZ) · 2 kullanım · 3 iç hata.
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve, extname } from 'path';

import { metrikBas, SURUM } from './lib/metrik.mjs';
import { modeliDogrula, PLAN_MOTOR, motorKos } from './lib/plan-motor.mjs';
import { kuralSetiYukle, ihlalleriBul } from './lib/kural.mjs';
import { katalogYukle, plaMobilyala, odaBaglami } from './lib/yerlesim.mjs';
import { temaYukle, dekorSvgUret } from './lib/dekor-svg.mjs';
import { renderDenetle } from './lib/oz-denetim.mjs';
import { cipalariYukle, cipalariDogrula, VARSAYILAN_TOLERANS_YUZDE } from './lib/cipa.mjs';

const KOK = dirname(fileURLToPath(import.meta.url));
const baslangic = performance.now();

const argv = process.argv.slice(2);
const komut = argv[0];

function argAl(ad, varsayilan = undefined) {
  const i = argv.indexOf(`--${ad}`);
  if (i === -1) return varsayilan;
  const d = argv[i + 1];
  if (d === undefined || d.startsWith('--')) return true;
  return d;
}
const bayrak = (ad) => argv.includes(`--${ad}`);

function kullanim() {
  console.error(`plan-dekor ${SURUM.split('@')[1]} — 2B planı renkli, mobilyalı sunum planına çevirir

  node cli.mjs mobilya --model m.json --cikti y.json [--adet 3] [--kural-seti k.json] [--oda id,id]
  node cli.mjs ciz     --model m.json [--yerlesim y.json] --cikti p.svg [--png p.png] [--tema T] [--lejant-yok]
  node cli.mjs revize  --yerlesim y.json --model m.json --degisiklik d.json --cikti yeni.json
  node cli.mjs cipa    --model m.json --cipa c.json [--tolerans 3] [--rapor r.json]
  node cli.mjs denetle --model m.json --yerlesim y.json [--kural-seti k.json] [--rapor r.json]
  node cli.mjs akis    --model m.json --cikti-dizin d/ [--adet 3] [--tema T]
  node cli.mjs temalar
  node cli.mjs katalog

Temalar: ${temaListesi().join(' · ')}
plan-motor: ${PLAN_MOTOR ?? 'BULUNAMADI'}`);
}

function temaListesi() {
  try {
    return readdirSync(join(KOK, 'tema')).filter((x) => x.endsWith('.json')).map((x) => x.replace('.json', ''));
  } catch { return []; }
}

function temaYolu(ad) {
  const t = ad ?? 'modern-sicak';
  const yol = t.endsWith('.json') ? resolve(t) : join(KOK, 'tema', `${t}.json`);
  if (!existsSync(yol)) throw new Error(`tema bulunamadı: ${t} (mevcut: ${temaListesi().join(', ')})`);
  return yol;
}

function kuralSetiYolu(ad) {
  return ad ? resolve(ad) : join(KOK, 'kural-seti', 'mobilya-TR.json');
}

// KATALOG OVERRIDE — kutu-yerel ALAN bilgisi için (F0/E, 2026-08-10).
// Sebep: mobilya ölçüleri projeden projeye değişir ("BU müşterinin buzdolabı 90 cm").
// Bu bir ALAN bilgisidir ve merkeze taşınmaz; kutu kendi kataloğunu verebilmeli.
//
// 🔴 HİLE KAPISI AÇILMIYOR: `katalogYukle` kural-setini de alır ve `asgari_boyut_cm`
// bandını override edilen kataloğa da uygular. Yani kutu DEĞER verebilir, KURAL veremez —
// merkezin birleştirme kuralı (merkezî üste biner) burada mekanik olarak korunuyor.
function katalogPaketi(kuralSeti, { katalogYol, programYol } = {}) {
  return katalogYukle(
    katalogYol ? resolve(katalogYol) : join(KOK, 'katalog', 'mobilya.json'),
    programYol ? resolve(programYol) : join(KOK, 'katalog', 'program.json'),
    kuralSeti,
  );
}

function modelYukle(yol) {
  // plan-motor'un KENDİ kapısı — plan-dekor kendi doğrulamasını icat etmez.
  const d = modeliDogrula(yol);
  if (!d.gecti) {
    console.error(`✗ plan-motor dogrula kırmızı (rc=${d.rc}) — plan-dekor hiçbir şey yazmadı:\n${d.cikti}`);
    return null;
  }
  return JSON.parse(readFileSync(yol, 'utf8'));
}

async function pngYaz(svg, hedef) {
  if (!PLAN_MOTOR) throw new Error('PNG için plan-motor node_modules gerekir (sharp)');
  const { pathToFileURL } = await import('url');
  const sharpYolu = join(PLAN_MOTOR, 'node_modules', 'sharp', 'lib', 'index.js');
  const { default: sharp } = await import(pathToFileURL(sharpYolu).href);
  await sharp(Buffer.from(svg)).png({ palette: true }).toFile(hedef);
}

// ---------------------------------------------------------------- komutlar

async function cmdMobilya() {
  const modelYol = argAl('model'), ciktiYol = argAl('cikti');
  if (!modelYol || !ciktiYol) { kullanim(); return 2; }
  const model = modelYukle(modelYol);
  if (!model) return 1;

  const kuralSeti = kuralSetiYukle(kuralSetiYolu(argAl('kural-seti')));
  const paket = katalogPaketi(kuralSeti, { katalogYol: argAl('katalog'), programYol: argAl('program') });
  const adet = Number(argAl('adet', 3));
  const odaSuzgeci = argAl('oda') ? String(argAl('oda')).split(',').map((s) => s.trim()) : undefined;

  const { raporlar, planAdaylari } = plaMobilyala(model, paket, kuralSeti, { adet, odalar: odaSuzgeci });

  const sigmayan = raporlar.filter((r) => r.durum === 'sigmadi');
  const programsiz = raporlar.filter((r) => r.durum === 'program-yok');

  for (const r of programsiz) console.error(`⚠ ${r.oda}: ${r.not}`);

  if (planAdaylari.length === 0) {
    console.error('✗ Hiçbir yerleşim adayı üretilemedi — dosya YAZILMADI.');
    for (const r of sigmayan) console.error(`  · ${r.oda}: ${r.not}`);
    return 1;
  }

  // FAIL-CLOSED: bir odanın ZORUNLU programı sığmadıysa plan eksiktir. Eksik planı sessizce
  // yazmak, "döşedim" iddiasını çürütür. Bilinçli kısmi teslim isteniyorsa --kismi-kabul
  // AÇIKÇA verilir — böylece eksiklik bir karar olur, bir kaza değil.
  if (sigmayan.length) {
    console.error(`⚠ ${sigmayan.length} oda döşenemedi (dürüst rapor, uydurulmadı):`);
    for (const r of sigmayan) console.error(`  · ${r.oda}: ${r.not}`);
    if (!bayrak('kismi-kabul')) {
      console.error('✗ Eksik plan YAZILMADI. Bilerek kısmi teslim istiyorsan: --kismi-kabul');
      return 1;
    }
    console.error('  → --kismi-kabul verildi: eksik plan bilinçli olarak yazılıyor.');
  }

  const cikti = {
    surum: '1.0',
    uretici: SURUM,
    model_ref: modelYol,
    kural_seti: kuralSeti.id,
    katalog_surum: paket.katalog.surum,
    uretim_notu: 'Deterministik yerleşim — Math.random kullanılmadı. kaynak_bekleyen kalemler ELEME yapmaz, yalnız skor cezasıdır.',
    // rapor sırası da kanonik (model.odalar dizisinin sırasından bağımsız) — B-012
    oda_raporlari: raporlar
      .map((r) => ({ oda: r.oda, durum: r.durum, m2: r.m2, denenen: r.denenen, not: r.not }))
      .sort((a, b) => String(a.oda).localeCompare(String(b.oda))),
    adaylar: planAdaylari.map((a, i) => ({ no: i + 1, yerlesimler: a.yerlesimler })),
  };
  writeFileSync(ciktiYol, JSON.stringify(cikti, null, 2));
  console.error(`✓ ${planAdaylari.length} yerleşim adayı → ${ciktiYol}`);
  console.error(`  odalar: ${raporlar.filter((r) => r.durum === 'ok').length} döşendi · ${sigmayan.length} sığmadı · ${programsiz.length} programsız`);
  return 0;
}

async function cmdCiz() {
  const modelYol = argAl('model'), ciktiYol = argAl('cikti');
  if (!modelYol || !ciktiYol) { kullanim(); return 2; }
  const model = modelYukle(modelYol);
  if (!model) return 1;

  const tema = temaYukle(temaYolu(argAl('tema')));
  const lejant = !bayrak('lejant-yok');

  let yerlesimler = [];
  const yerlesimYol = argAl('yerlesim');
  if (yerlesimYol) {
    const y = JSON.parse(readFileSync(yerlesimYol, 'utf8'));
    const no = Number(argAl('aday', 1));
    const aday = y.adaylar?.find((a) => a.no === no) ?? y.adaylar?.[0];
    if (!aday) { console.error(`✗ yerleşim dosyasında aday yok: ${yerlesimYol}`); return 1; }
    yerlesimler = aday.yerlesimler;
  }

  const svg = dekorSvgUret(model, yerlesimler, tema, { lejant, notu: argAl('not') || undefined });

  // FAIL-CLOSED: öz-denetim geçmeden dosya YAZILMAZ
  const dd = renderDenetle(svg, { model, yerlesimler, tema, lejant });
  for (const u of dd.uyarilar) console.error(`⚠ ${u}`);
  if (!dd.gecti) {
    console.error('✗ render öz-denetimi kırmızı — hiçbir dosya YAZILMADI:');
    for (const h of dd.hatalar) console.error(`  · ${h}`);
    return 1;
  }

  writeFileSync(ciktiYol, svg);
  console.error(`✓ ${ciktiYol} (${yerlesimler.length} mobilya · tema ${tema.id})`);

  const pngYol = argAl('png');
  if (pngYol && pngYol !== true) {
    await pngYaz(svg, pngYol);
    console.error(`✓ ${pngYol}`);
  }
  return 0;
}

async function cmdDenetle() {
  const modelYol = argAl('model'), yerlesimYol = argAl('yerlesim');
  if (!modelYol || !yerlesimYol) { kullanim(); return 2; }
  const model = modelYukle(modelYol);
  if (!model) return 1;

  const kuralSeti = kuralSetiYukle(kuralSetiYolu(argAl('kural-seti')));
  const y = JSON.parse(readFileSync(yerlesimYol, 'utf8'));
  const no = Number(argAl('aday', 1));
  const aday = y.adaylar?.find((a) => a.no === no) ?? y.adaylar?.[0];
  if (!aday) { console.error('✗ aday bulunamadı'); return 1; }

  const tumIhlaller = [];
  for (const oda of model.odalar ?? []) {
    const baglam = odaBaglami(model, oda);
    const odaYerlesimleri = aday.yerlesimler.filter((v) => v.oda === oda.id);
    if (!odaYerlesimleri.length) continue;
    for (const i of ihlalleriBul(odaYerlesimleri, baglam, kuralSeti)) tumIhlaller.push({ oda: oda.id, ...i });
  }

  const rapor = {
    kural_seti: kuralSeti.id,
    aday: aday.no,
    ihlaller: tumIhlaller.filter((i) => i.siddet === 'hata'),
    uyarilar: tumIhlaller.filter((i) => i.siddet === 'uyari'),
    kaynak_bekleyen_not: 'Aşağıdaki kalemler sert eşik DEĞİLDİR (kaynak doğrulanmadı): ' +
      (kuralSeti.kaynak_bekleyen ?? []).map((k) => k.id).join(', '),
  };
  const raporYol = argAl('rapor');
  if (raporYol && raporYol !== true) writeFileSync(raporYol, JSON.stringify(rapor, null, 2));

  console.log(JSON.stringify(rapor, null, 2));
  if (rapor.ihlaller.length) { console.error(`✗ ${rapor.ihlaller.length} sert ihlal`); return 1; }
  console.error('✓ sert ihlal yok');
  return 0;
}

async function cmdRevize() {
  const yerlesimYol = argAl('yerlesim'), degisiklikYol = argAl('degisiklik'), ciktiYol = argAl('cikti');
  const modelYol = argAl('model');
  if (!yerlesimYol || !degisiklikYol || !ciktiYol || !modelYol) { kullanim(); return 2; }
  const model = modelYukle(modelYol);
  if (!model) return 1;

  const y = JSON.parse(readFileSync(yerlesimYol, 'utf8'));
  const degisiklikler = JSON.parse(readFileSync(degisiklikYol, 'utf8'));
  const no = Number(argAl('aday', 1));
  const adayIndeks = y.adaylar.findIndex((a) => a.no === no);
  if (adayIndeks === -1) { console.error('✗ aday bulunamadı'); return 1; }

  const kuralSetiErken = kuralSetiYukle(kuralSetiYolu(argAl('kural-seti')));
  const paket = katalogPaketi(kuralSetiErken, { katalogYol: argAl('katalog'), programYol: argAl('program') });
  let yerlesimler = structuredClone(y.adaylar[adayIndeks].yerlesimler);

  for (const d of degisiklikler) {
    switch (d.islem) {
      case 'mobilya_sil': {
        const n = yerlesimler.length;
        yerlesimler = yerlesimler.filter((v) => !(v.oda === d.oda && v.mobilya === d.mobilya));
        if (yerlesimler.length === n) { console.error(`✗ silinecek mobilya yok: ${d.oda}/${d.mobilya}`); return 1; }
        break;
      }
      case 'mobilya_tasi': {
        const hedef = yerlesimler.find((v) => v.oda === d.oda && v.mobilya === d.mobilya);
        if (!hedef) { console.error(`✗ taşınacak mobilya yok: ${d.oda}/${d.mobilya}`); return 1; }
        hedef.kutu = { ...hedef.kutu, x: hedef.kutu.x + (d.dx ?? 0), y: hedef.kutu.y + (d.dy ?? 0) };
        break;
      }
      case 'mobilya_dondur': {
        const hedef = yerlesimler.find((v) => v.oda === d.oda && v.mobilya === d.mobilya);
        if (!hedef) { console.error(`✗ döndürülecek mobilya yok: ${d.oda}/${d.mobilya}`); return 1; }
        hedef.yon = ((hedef.yon + (d.adim ?? 1)) % 4 + 4) % 4;
        const { g, d: der } = hedef.kutu;
        hedef.kutu = { ...hedef.kutu, g: der, d: g };
        break;
      }
      case 'mobilya_ekle': {
        const mob = paket.indeks.get(d.mobilya);
        if (!mob) { console.error(`✗ katalogda yok: ${d.mobilya}`); return 1; }
        const [G, D] = mob.boyut_cm;
        const yon = d.yon ?? 1;
        yerlesimler.push({
          mobilya: mob.id, ad: mob.ad, sembol: mob.sembol, oda: d.oda, yon,
          kutu: { x: d.x, y: d.y, g: yon % 2 === 0 ? D : G, d: yon % 2 === 0 ? G : D },
          yerlesimTipi: mob.yerlesim, pencereOnuYasak: !!mob.pencere_onu_yasak,
          temizAlan: mob.temiz_alan_cm ?? {}, dayandigiDuvarSayisi: null,
        });
        break;
      }
      default:
        console.error(`✗ bilinmeyen işlem: ${d.islem}`);
        return 1;
    }
  }

  // Revizyon sonrası kural denetimi ZORUNLU — ihlalliyse eski dosya BOZULMAZ
  const kuralSeti = kuralSetiErken;
  const ihlaller = [];
  for (const oda of model.odalar ?? []) {
    const odaY = yerlesimler.filter((v) => v.oda === oda.id);
    if (!odaY.length) continue;
    const baglam = odaBaglami(model, oda);
    // dayanma bilgisi taşındıysa yeniden ölçülemez → yerleşim-tipi kuralını bu yolda uygulama
    const uygulanabilir = { ...kuralSeti, kurallar: kuralSeti.kurallar.filter((k) => k.olcut !== 'yerlesim_tipi_ihlali') };
    for (const i of ihlalleriBul(odaY, baglam, uygulanabilir)) {
      if (i.siddet === 'hata') ihlaller.push({ oda: oda.id, ...i });
    }
  }
  if (ihlaller.length) {
    console.error('✗ revizyon kural ihlali üretti — çıktı YAZILMADI:');
    for (const i of ihlaller) console.error(`  · [${i.oda}] ${i.kural}: ${i.detay}`);
    return 1;
  }

  const yeni = structuredClone(y);
  yeni.adaylar[adayIndeks].yerlesimler = yerlesimler;
  yeni.revizyon_gecmisi = [...(y.revizyon_gecmisi ?? []), { ts: new Date().toISOString(), degisiklikler }];
  writeFileSync(ciktiYol, JSON.stringify(yeni, null, 2));
  console.error(`✓ revize edildi → ${ciktiYol} (${yerlesimler.length} mobilya)`);
  return 0;
}

async function cmdCipa() {
  const modelYol = argAl('model'), cipaYol = argAl('cipa');
  if (!modelYol || !cipaYol) { kullanim(); return 2; }
  const model = modelYukle(modelYol);
  if (!model) return 1;

  const cipalar = cipalariYukle(cipaYol);
  const tolerans = Number(argAl('tolerans', VARSAYILAN_TOLERANS_YUZDE));
  const s = cipalariDogrula(model, cipalar, { tolerans });

  for (const o of s.olcumler) {
    console.error(`  ${o.gecti ? '✓' : '✗'} ${o.ad.padEnd(28)} model ${String(o.model_cm).padStart(7)} cm · beyan ${String(o.gercek_cm).padStart(7)} cm · sapma %${o.sapma_yuzde} (${o.eksen})`);
  }
  for (const u of s.uyarilar) console.error(`⚠ ${u}`);

  const raporYol = argAl('rapor');
  if (raporYol && raporYol !== true) {
    writeFileSync(raporYol, JSON.stringify({ model: modelYol, tolerans_yuzde: tolerans, ...s }, null, 2));
  }

  if (!s.gecti) {
    console.error('✗ ÖLÇEK ÇIPASI KAPISI KIRMIZI — bu model ölçü kanıtı taşımıyor:');
    for (const h of s.hatalar) console.error(`  · ${h}`);
    console.error('  → Model ölçüsü doğrulanmadan mobilya/çizim aşamasına GEÇME.');
    return 1;
  }
  console.error(`✓ ölçek çıpası geçti (${s.olcumler.length} çıpa, tavan %${tolerans}) — model ölçüsü çapraz doğrulandı`);
  return 0;
}

async function cmdAkis() {
  const modelYol = argAl('model');
  const dizin = argAl('cikti-dizin');
  if (!modelYol || !dizin) { kullanim(); return 2; }
  mkdirSync(dizin, { recursive: true });

  const adet = Number(argAl('adet', 3));
  const temaAd = argAl('tema') || 'modern-sicak';

  // 1) mobilya
  const yerlesimYol = join(dizin, 'yerlesim.json');
  const eskiArgv = argv.slice();
  argv.length = 0;
  argv.push('mobilya', '--model', modelYol, '--cikti', yerlesimYol, '--adet', String(adet));
  const rcM = await cmdMobilya();
  argv.length = 0; argv.push(...eskiArgv);
  if (rcM !== 0) return rcM;

  // 2) her aday için çizim
  const y = JSON.parse(readFileSync(yerlesimYol, 'utf8'));
  const model = JSON.parse(readFileSync(modelYol, 'utf8'));
  const tema = temaYukle(temaYolu(temaAd));

  for (const aday of y.adaylar) {
    const svg = dekorSvgUret(model, aday.yerlesimler, tema, { lejant: true });
    const dd = renderDenetle(svg, { model, yerlesimler: aday.yerlesimler, tema, lejant: true });
    if (!dd.gecti) {
      console.error(`✗ aday-${aday.no} öz-denetimi kırmızı — YAZILMADI: ${dd.hatalar.join(' · ')}`);
      return 1;
    }
    const svgYol = join(dizin, `aday-${String(aday.no).padStart(2, '0')}.svg`);
    writeFileSync(svgYol, svg);
    await pngYaz(svg, svgYol.replace(/\.svg$/, '.png'));
    console.error(`✓ ${svgYol} (+png)`);
  }

  // 3) köken beyanı
  writeFileSync(join(dizin, 'KOKEN.md'), kokenMetni(model, y, tema, modelYol));
  console.error(`✓ ${join(dizin, 'KOKEN.md')}`);
  return 0;
}

function kokenMetni(model, y, tema, modelYol) {
  return `# KÖKEN BEYANI

Bu teslimattaki planlar **nasıl** üretildi — hangi adım ölçüme, hangi adım yoruma dayanıyor.

| Adım | Yöntem | Kaynak |
|---|---|---|
| Geometri (duvar/oda/açıklık) | ${model.olcek?.kaynak === 'cad' ? 'CAD dosyasından okundu' : model.olcek?.kaynak === 'gorsel' ? 'Görselden dijitalleştirildi + ölçek çıpasıyla doğrulandı' : 'Elle kurulan model'} | \`${modelYol}\` · ölçü kaynağı: **${model.olcek?.kaynak ?? '?'}** |
| Alan hesapları | Shoelace formülü, poligondan ölçüldü | deterministik · beyan değil |
| Mobilya yerleşimi | Kural-tabanlı deterministik yerleştirici (Math.random YOK) | \`${y.kural_seti}\` · katalog ${y.katalog_surum} |
| Renk / doku | Tema verisi | \`${tema.id}\` — ${tema.ad} |

## Ne İDDİA EDİLMİYOR

Bu plan **yönetmeliğe uygunluk belgesi değildir.** Mobilya yerleşiminde uygulanan sert kurallar
yalnız geometriden türeyenlerdir (çakışma · oda dışına taşma · kapı kanadı süpürme alanı ·
açıklık önü · yerleşim tipi). Sirkülasyon genişliği, dolap kapak payı, yatak yanı boşluk gibi
**konfor eşiklerinin sayıları kaynağa bağlanmadığı için sert kural olarak uygulanmamıştır** —
yalnız adayları sıralamakta kullanılmıştır.

Üretici: \`${y.uretici}\` · ${new Date().toISOString().slice(0, 10)}
`;
}

// ---------------------------------------------------------------- ana

let rc = 0;
try {
  switch (komut) {
    case 'mobilya': rc = await cmdMobilya(); break;
    case 'ciz': rc = await cmdCiz(); break;
    case 'denetle': rc = await cmdDenetle(); break;
    case 'revize': rc = await cmdRevize(); break;
    case 'cipa': rc = await cmdCipa(); break;
    case 'akis': rc = await cmdAkis(); break;
    case 'temalar': console.log(temaListesi().join('\n')); rc = 0; break;
    case 'katalog': {
      const p = katalogPaketi(kuralSetiYukle(kuralSetiYolu(argAl('kural-seti'))), { katalogYol: argAl('katalog'), programYol: argAl('program') });
      console.log(p.katalog.mobilyalar.map((m) => `${m.id.padEnd(20)} ${m.boyut_cm.join('×').padEnd(10)} ${m.yerlesim.padEnd(14)} ${m.oda_tipleri.join(',')}`).join('\n'));
      rc = 0; break;
    }
    default: kullanim(); rc = komut ? 2 : 2;
  }
} catch (e) {
  console.error(`✗ iç hata: ${e.message}`);
  if (process.env.PLAN_DEKOR_DEBUG) console.error(e.stack);
  rc = 3;
}

metrikBas({ komut: komut ?? '-', baslangicMs: baslangic, rc, girdi: argAl('model') ?? argAl('yerlesim') ?? null, cikti: argAl('cikti') ?? argAl('cikti-dizin') ?? null, dosya: argAl('metrik') && argAl('metrik') !== true ? argAl('metrik') : undefined });
process.exit(rc);
