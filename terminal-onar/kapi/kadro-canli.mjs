// kapi/kadro-canli.mjs — KADRO canlı ölçümü (salt-okur): bu kutunun kaydı ⟂ koltuk listesi, insan okur biçimde.
//   node kadro-canli.mjs [--proje <dizin>] [--kutu <ad>] [--ana <ana-oturum>]
// Varsayılanlar ortak.sh kuralıyla: proje = TO_PROJE | /config/projects/<kutu>; kutu = TO_KUTU; ana = TO_ANA_TMUX | <kutu>-ana.
// Kanıt üretir, hiçbir şey yazmaz. Göreli içe aktarma: hangi kopya koşarsa onun kadro.mjs'i ölçülür (göz tur 2).
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { kayitOku, kadroBirlestir } from './kadro.mjs';
import { koltukSatirlari } from './koltuklar.mjs';
const arg = (a, v) => { const i = process.argv.indexOf(a); return i > 0 ? process.argv[i + 1] : v; };
const KUTU = arg('--kutu', process.env.TO_KUTU || '');
if (!KUTU) { console.error('kutu adı gerekli: --kutu <ad> ya da TO_KUTU'); process.exit(2); }
const PROJE = arg('--proje', process.env.TO_PROJE || '/config/projects/' + KUTU);
const ANA = arg('--ana', process.env.TO_ANA_TMUX || KUTU + '-ana');
const BETIK = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../scripts/koltuk-bagla.sh');
let out;
try { out = execFileSync('bash', [BETIK, '--liste'], { env: { ...process.env, TO_KUTU: KUTU }, encoding: 'utf8' }); }
catch (e) { console.error('koltuk listesi ölçülemedi: ' + (e.stderr || e.message).toString().trim()); process.exit(3); }
const kayit = kayitOku(PROJE);
if (kayit.okunamadi.length) { console.error('kayıt okunamadı: ' + kayit.okunamadi.join(', ')); process.exit(3); }
const k = kadroBirlestir({ uyeler: kayit.uyeler, koltuklar: koltukSatirlari(out), ana: ANA });
console.log('kutu: ' + KUTU + ' · proje: ' + PROJE + ' · kaynak: ' + (kayit.kaynak.join(', ') || '(kayıt yok)'));
console.log('sayilar: ' + JSON.stringify(k.sayilar));
for (const p of k.kisiler) console.log(`${p.grup.padEnd(24)} ${(p.id || p.tmux).padEnd(12)} rol=${p.rol.slice(0, 30).padEnd(30)} hal_kayit=${p.hal_kayit.padEnd(10)} oturum=${p.oturum ? p.oturum.ad + '/' + p.oturum.hal + (p.oturum.ne ? ' (' + p.oturum.ne + ')' : '') : '-'}`);
console.log('kayitsiz: ' + (k.kayitsiz.map((x) => x.ad + '/' + x.hal).join(' · ') || '-'));
