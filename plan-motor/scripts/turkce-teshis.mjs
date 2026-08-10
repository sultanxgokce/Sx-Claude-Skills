#!/usr/bin/env node
// TÜRKÇE TEŞHİS DWG — dört kodlama varyantını yan yana yazar.
// Sebep: DWG metni bit-paketli saklanır, baytları grep'lenemez → hangi yolun AutoCAD'de
// çalıştığı KUTUDAN ölçülemez. Bu dosya insana gösterilir, o söyler. Tahmin etmiyoruz.
import { CadDocument, ACadVersion, DwgWriter, Layer, XYZ, TextEntity, MText } from '@node-projects/acad-ts';
import { writeFileSync } from 'fs';

const ORNEK = 'Giyinme Odası · Çift Kişilik · Gardırop · Tezgâh';
const doc = new CadDocument();
doc.header.version = ACadVersion.AC1027;
doc.header.insUnits = 5;
doc.header.codePage = 'ANSI_1254';           // Türkçe kod sayfası

const kat = new Layer('TEST'); doc.layers.add(kat);
const yaz = (metin, y, ent = 'text') => {
  const e = ent === 'mtext' ? new MText() : new TextEntity();
  e.value = metin; e.height = 18; e.insertPoint = new XYZ(0, y, 0); e.layer = kat;
  doc.entities.add(e);
};

yaz('1) TEXT + kod sayfasi ANSI_1254 (ham):', 400);
yaz(ORNEK, 360);

yaz('2) MTEXT + kod sayfasi ANSI_1254 (ham):', 280);
yaz(ORNEK, 240, 'mtext');

yaz('3) MTEXT + U+ kacis:', 160);
yaz('Giyinme Odas\\U+0131 \\U+00B7 \\U+00C7ift Ki\\U+015Filik', 120, 'mtext');

yaz('4) Harf cevirisi (her zaman calisir, kalite dusuk):', 40);
yaz('Giyinme Odasi - Cift Kisilik - Gardirop - Tezgah', 0);

yaz('HANGISI DOGRU GORUNUYOR? Numarasini soyle.', -100);

const buf = new ArrayBuffer(4 * 1024 * 1024);
const w = new DwgWriter(buf, doc); w.write();
writeFileSync(process.argv[2] ?? 'turkce-teshis.dwg', Buffer.from(buf.slice(0, w.bytesWritten)));
console.log(`✓ ${process.argv[2]} (${w.bytesWritten} bayt) — AutoCAD'de aç, hangi satır doğruysa söyle`);
