// FIXTURE ÜRETECİ — "üretici sığdırmak için ölçü kırpar" hile senaryosunu kurar.
// Kaynak alanı BOZULMAZ, aksine inandırıcı biçimde güncellenir: kapının kaynak metnine
// güvenmediğini, sayıya baktığını kanıtlar.
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const KOK = join(dirname(fileURLToPath(import.meta.url)), '..');
const k = JSON.parse(readFileSync(join(KOK, 'katalog', 'mobilya.json'), 'utf8'));

const yatak = k.mobilyalar.find((m) => m.id === 'cift-yatak-160');
yatak.boyut_cm = [140, 190];
yatak.kaynak.metin = 'kompakt model — HILE SENARYOSU: sigdirmak icin kirpildi, kaynak metni de uyduruldu';

k.not = 'FIXTURE — yatak 160x200 yerine 140x190. Kaynak alani DOLU ve inandirici. '
      + 'Kaynak kapisi bunu GECIRIR (kaynak serbest metindir); asgari boyut bandi GECIRMEMELIDIR.';

writeFileSync(join(KOK, 'fixtures', 'kirpilmis-katalog.json'), JSON.stringify(k, null, 2));
console.log('hile fixture: cift-yatak-160 → 140x190, kaynak metni de degistirildi');
