// NAZIR'ın gerçek kayıt biçimiyle (yalnız ad, tmux, amir, oda) canlı yedi koltuktan kaçı rütbe ve oda alıyor. Kullanım: node <betik> <kapi dizini>
import path from 'node:path';
const k = path.resolve(process.argv[2]) + '/';
const { rutbeHaritasi, rutbeBul } = await import(k + 'rutbe.mjs'); const { kayitOdaHaritasi, kayitOdaBul } = await import(k + 'oda.mjs');
const u = (id, ad, tmux, amir, oda_muduru, oda) => ({ id, ad, tmux, amir, oda_muduru, oda });
const KAYIT = [u('nazir-yon', 'ŞEHBENDER', 'nazir-yon:0', 'Sultan', 'evet', 'nezaret'), u('nazir-motor1', 'HARRAT', 'nazir-motor1:0', 'RASATÇI', 'hayır', 'omnirouter'), u('nazir-mim', 'MÜSTENSİH', 'nazir-mim:0', 'CİHANNÜMA', 'hayır', 'hermes'),
  u('nazir-rasatci', 'RASATÇI', 'nazir-rasatci:0', 'ŞEHBENDER', 'evet', 'omnirouter'), u('nazir-seyyah', 'CİHANNÜMA', 'nazir-seyyah:0', 'ŞEHBENDER', 'evet', 'hermes'), u('nazir-hafizadar', 'HAFIZADAR', 'nazir-hafizadar:0', 'CİHANNÜMA', 'hayır', 'hermes'),
  u('nazir-seritdar', 'ŞERİTDAR', 'nazir-seritdar:0', 'ŞEHBENDER', 'hayır', 'nezaret'), u('nazir-mizanci', 'MİZANCI', 'nazir-mizanci:0', 'ŞEHBENDER', 'hayır', 'nezaret'), u('nazir-kilavuz', 'KILAVUZ', 'kilavuz:0', 'ŞEHBENDER', 'evet', 'paperclip')];
const ACIK = ['nazir-yon', 'rasatci', 'cihannuma', 'mizanci', 'seritdar', 'kilavuz'], r = rutbeHaritasi(KAYIT, ACIK), o = kayitOdaHaritasi(KAYIT, ACIK);
let dolu = 0; for (const a of ACIK) { const b = rutbeBul(r, a, { ana: 'nazir-yon', acik: ACIK }), d = kayitOdaBul(o, a); if (b.kademe && d) dolu++; console.log(a.padEnd(11), (b.kademe || '-').padEnd(11), (b.amir || '-').padEnd(10), d || 'oda dışı'); }
console.log(`rutbe_ve_oda_dolu=${dolu}/${ACIK.length}`);
