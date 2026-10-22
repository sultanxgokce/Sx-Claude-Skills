// kapi/dava-bekci.mjs — Dava Rafı kendiliğinden dondurma turu (Parça B7). bekci.sh günde BİR kez çağırır (ayrı cron yok).
//   node dava-bekci.mjs [--kuru]       --kuru: kimin dondurulacağını yazar, hiçbir şeye dokunmaz
// Kural kayıt kökündeki dava_kurali.gun: açık, oturumu olan ve tmux bölmesi `gun` gündür kıpırdamayan dava dondurulur
// (dondurma: kural). Kural yoksa (davası olmayan kutu) hiçbir şey yapılmaz. İz: <durum dizini>/kadro-hal.log — kapının iziyle aynı.
// Kapıyla aynı kaydı yazdığı için süreçler arası kilidi alır (dosyaKilit); koltuk listesi ve kimlik ölçümü kapıyla aynı kaynaktan.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { kayitOku, kadroBirlestir, kendiligindenDondurulacak } from './kadro.mjs';
import { KadroHata } from './kadro-yaz.mjs';
import { dosyaKilit } from './kilit.mjs';
import { davaDondur } from './dava.mjs';
import { koltukSatirlari } from './koltuklar.mjs';
import { oturumKimlikleri, oturumDizinleri } from './kimlik.mjs';

const KOK = path.dirname(fileURLToPath(import.meta.url));
const KUTU = process.env.TO_KUTU || '';
const PROJE = process.env.TO_PROJE || ('/config/projects/' + (KUTU || 'kutu'));
const ANA = process.env.TO_ANA_TMUX || (KUTU + '-ana');
const DURUM_DIZ = process.env.TO_DURUM_DIZ || '/config/.terminal-onar';
const LISTE = process.env.KAPI_KOLTUK_BETIK || path.resolve(KOK, '../scripts/koltuk-bagla.sh');
const KURU = process.argv.includes('--kuru');
const iz = (s) => { try { fs.appendFileSync(path.join(DURUM_DIZ, 'kadro-hal.log'), new Date().toISOString() + ' bekci ' + s + '\n'); } catch {} };

const kayit0 = kayitOku(PROJE);
if (!kayit0.dava_kurali) { console.log('dava kuralı yok — tur yok'); process.exit(0); }
// Kilit: kapıyla AYNI dosya (kilit.mjs, PROJE). Alınamazsa (kapı yazıyor) tur yapılmaz, rc 3; yarın yeniden denenir.
let birak = () => {};
if (!KURU) { try { birak = dosyaKilit(PROJE, { bekleMs: +process.env.KADRO_KILIT_BEKLE_MS || 30000 }); } catch (e) { console.error(e.message); process.exit(3); } }
let rc = 0;
try {
  let out; try { out = execFileSync('bash', [LISTE, '--liste'], { encoding: 'utf8', timeout: 60000 }); }
  catch { console.error('koltuklar ölçülemedi — hiçbir şey yapılmadı'); process.exit(3); }
  const kayit = kayitOku(PROJE);   // kilit altında yeniden oku (kapı arada yazmış olabilir)
  if (kayit.okunamadi.length || !kayit.dava_kurali) { console.error('kayıt okunamadı ya da kural kalktı — hiçbir şey yapılmadı'); process.exit(3); }
  const kd = kadroBirlestir({ uyeler: kayit.uyeler, koltuklar: koltukSatirlari(out), ana: ANA,
    kimlikler: oturumKimlikleri({ dizinler: oturumDizinleri(), procKok: process.env.KAPI_PROC_KOK || '/proc', ...(process.env.KAPI_PID_ALANI ? { pidAlani: process.env.KAPI_PID_ALANI } : {}) }) });
  const liste = kendiligindenDondurulacak(kd.kisiler, kayit.dava_kurali);
  if (!liste.length) console.log(`dondurulacak dava yok (kural: ${kayit.dava_kurali.gun} gün)`);
  for (const k of liste) {
    if (KURU) { console.log('dondurulur: ' + k.id); continue; }
    const kapat = async (ad) => { try { execFileSync('tmux', ['kill-session', '-t', '=' + ad], { stdio: 'ignore' }); return true; } catch { return false; } };
    try { await davaDondur({ proje: PROJE, kisi: k, kural: true, kapat, iz, neden: `${kayit.dava_kurali.gun} gün dokunulmadı` }); console.log('donduruldu: ' + k.id); }
    catch (e) { rc = 1; console.error(`${k.id} dondurulamadı: ${e instanceof KadroHata ? e.message : String(e)}`); }
  }
} finally { birak(); }
process.exit(rc);
