#!/usr/bin/env node
// DWG öz-denetleyici — üretilen DWG'yi geri okuyup iddiaları ÖLÇER.
// Kapı-testleri bunu çağırır; inline `node -e` kullanmak modül-çözümü yüzünden
// SAHTE KIRMIZI üretiyordu (betik paket dizini dışından koşunca import düşüyor,
// çıkış kodu 1 oluyor ve "kusur bulundu" gibi okunuyordu — ölçüldü 2026-08-07).
//
// Kullanım: node scripts/dwg-denetle.mjs <dosya.dwg> [--json]
// Çıkış: 0 temiz · 1 kusur bulundu · 2 okunamadı
import { DwgReader } from '@node-projects/acad-ts';
import { readFileSync } from 'fs';

const yol = process.argv[2];
if (!yol) { console.error('kullanım: dwg-denetle.mjs <dosya.dwg> [--json]'); process.exit(2); }

let doc;
try {
  const b = readFileSync(yol);
  // Sihirli bayt — ezdxf gibi kütüphaneler .dwg uzantısıyla DXF yazabiliyor.
  const sihir = b.subarray(0, 6).toString('ascii');
  if (!/^AC10\d\d$/.test(sihir)) {
    console.error(`✗ DWG değil — sihirli bayt "${sihir}"`);
    process.exit(1);
  }
  doc = new DwgReader(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)).read();
} catch (e) {
  console.error(`✗ okunamadı: ${e.message}`);
  process.exit(2);
}

const ents = [...doc.entities];
const envanter = {};
for (const e of ents) envanter[e.constructor.name] = (envanter[e.constructor.name] ?? 0) + 1;
const katmanlar = [...doc.layers].map((l) => l.name).sort();
const metinler = ents.filter((e) => e.constructor.name === 'TextEntity').map((e) => e.value ?? '');

// Ham Latin-1-dışı karakter TEK BAŞINA kusur DEĞİLDİR — kod sayfasına bağlıdır.
//   · codePage ANSI_1252 (Latin-1) + ham ş/ı/ğ  → AutoCAD "?" gösterir  → KUSUR
//   · codePage ANSI_1254 (Türkçe)  + ham ş/ı/ğ  → doğru gösterir        → temiz
// (Bu ayrım ölçülerek öğrenildi: acad-ts varsayılanı 1252, Türkçe bu yüzden düşüyordu.)
const kodSayfasi = String(doc.header?.codePage ?? '').toLowerCase();
const turkceKS = kodSayfasi.includes('1254');
const hamTr = metinler.filter((m) => /[^\x00-\xFF]/.test(m));

const kusurlar = [];
if (hamTr.length && !turkceKS) {
  kusurlar.push(`ham Latin-1 dışı karakter + kod sayfası "${kodSayfasi}" (AutoCAD "?" gösterir): ${hamTr.slice(0, 3).join(' | ')}`);
}
// Kaçış kalıntısı: \U+ AutoCAD'in düz TEXT'inde ÇÖZÜLMÜYOR (ölçüldü) — harfiyen basılır.
const kacisliKalinti = metinler.filter((m) => m.includes('\\U+'));
if (kacisliKalinti.length) {
  kusurlar.push(`\\U+ kaçışı kaldı (AutoCAD düz TEXT'te çözmez, harfiyen basar): ${kacisliKalinti.slice(0, 2).join(' | ')}`);
}
if (!ents.length) kusurlar.push('çizim boş');

// --- Çizim TEKNİĞİ raporu (referans çizim analizinden türedi, 2026-08-07) ---
// Bunlar KUSUR listesine girmez; kapılar bunlara --json üstünden bakar. Sebep: bu dosya
// başkasının çizimini de denetleyebilmeli, ve onun ANSI31 kullanma zorunluluğu yok.
const katmanDetay = {};
for (const l of doc.layers) {
  katmanDetay[l.name] = { kalem: l.lineWeight, renk: l.color?._color ?? null };
}
const metinStilleri = [...(doc.textStyles ?? [])].map((s) => ({ ad: s.name, dosya: s.filename ?? '' }));
const taramalar = ents.filter((e) => e.constructor.name === 'Hatch').map((e) => ({
  katman: e.layer?.name ?? null,
  desen: e.pattern?.name ?? null,
  kati: !!e.isSolid,
  iliskili: !!e.isAssociative,
  olcek: e._patternScale ?? null,
  yol_sayisi: (e.paths ?? []).length,
}));
// Duvar konturu KAPALI olmalı: birleşik gövde tekniğinin imzası budur. Açık polyline
// "kalın merkez hattı" dönemine geri düşüldüğünü gösterir.
const duvarPl = ents.filter((e) => e.constructor.name === 'LwPolyline' && e.layer?.name === 'A-WALL');
const duvarKontur = {
  toplam: duvarPl.length,
  kapali: duvarPl.filter((p) => p.isClosed).length,
  genisligi_olan: duvarPl.filter((p) => (p.vertices ?? []).some((v) => (v.startWidth ?? 0) > 0)).length,
};

const rapor = {
  dosya: yol,
  entity_toplam: ents.length,
  envanter,
  katmanlar,
  katman_detay: katmanDetay,
  metin_stilleri: metinStilleri,
  taramalar,
  duvar_kontur: duvarKontur,
  metin_sayisi: metinler.length,
  kod_sayfasi: kodSayfasi,
  turkce_kod_sayfasi: turkceKS,
  ham_turkce_metin: hamTr.length,
  kusurlar,
};

if (process.argv.includes('--json')) console.log(JSON.stringify(rapor, null, 2));
else {
  console.log(`${ents.length} varlık · ${JSON.stringify(envanter)}`);
  console.log(`katmanlar: ${katmanlar.join(' ')}`);
  console.log(`metin ${metinler.length} · kod sayfası ${kodSayfasi}${turkceKS ? ' (Türkçe ✓)' : ''} · ham Türkçe ${hamTr.length}`);
  for (const k of kusurlar) console.error(`✗ ${k}`);
  if (!kusurlar.length) console.log('✓ kusur yok');
}
process.exit(kusurlar.length ? 1 : 0);
