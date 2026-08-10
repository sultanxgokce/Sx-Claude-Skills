// FIXTURE ÜRETECİ — "eşdeğer ama farklı sıralı girdi" determinizm sınavı.
// Geometrik olarak BİREBİR AYNI daire; yalnız duvarlar/odalar/açıklıklar dizilerinin SIRASI ters.
// Determinizm iddiası ("aynı girdi → aynı sha256") yalnız bayt-aynı girdiyi değil,
// ANLAM-AYNI girdiyi de kapsamalıdır — aksi halde iddia, testin ölçtüğü kadar dardır.
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const KOK = join(dirname(fileURLToPath(import.meta.url)), '..');
const m = JSON.parse(readFileSync(join(KOK, 'demo', 'ornek-daire.json'), 'utf8'));

m.ad = 'Örnek Daire — 90 m² (plan-dekor demo)';   // ad aynı kalmalı: SVG başlığı determinizme girer
m.duvarlar.reverse();
m.odalar.reverse();
m.acikliklar.reverse();
// noktalar sözlüğünün anahtar sırasını da ters çevir
m.noktalar = Object.fromEntries(Object.entries(m.noktalar).reverse());

writeFileSync(join(KOK, 'fixtures', 'esdeger-daire.json'), JSON.stringify(m, null, 2));
console.log('eşdeğer fixture: duvarlar/odalar/açıklıklar/noktalar sırası ters, geometri AYNI');
