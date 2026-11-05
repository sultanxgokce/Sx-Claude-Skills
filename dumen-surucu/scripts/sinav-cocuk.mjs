// sinav-cocuk.mjs — sınavın açtığı süreçleri (tarayıcı) ve geçici dizinleri sınav HANGİ YOLLA biterse bitsin kapatır/siler.
// Sorun: sınav tarayıcıyı yalnız başarı yolunda kill() ile kapatıyordu; sınav çökünce, zaman aşımına uğrayınca
//   ya da bir mutant sınavı ortasında kesince tarayıcı açık kalıyordu (görev …P6BY85C).
// Çare: çocuk yeni süreç grubunda açılır (tarayıcının alt süreçleri de grupta); çıkışta, çökmede ve
//   TERM/INT/HUP sinyalinde grubun hepsi KILL ile kapatılır.
import { spawn } from 'child_process';
import { mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const canli = new Set();
const dizinler = [];

// gecici('onek-'): geçici dizin açar; sınav hangi yolla biterse bitsin çıkışta (süreçler kapandıktan sonra) silinir (görev …NNDSSE)
export function gecici(onek) {
  const d = mkdtempSync(join(tmpdir(), onek));
  dizinler.push(d);
  return d;
}

export function cocukBaslat(komut, args, secenek = {}) {
  const c = spawn(komut, args, { ...secenek, detached: true });
  canli.add(c);
  c.once('exit', () => canli.delete(c));
  return c;
}

export function hepsiniKapat() {
  for (const c of canli) {
    try { process.kill(-c.pid, 'SIGKILL'); } catch { try { c.kill('SIGKILL'); } catch { /* zaten kapalı */ } }
  }
  canli.clear();
}

function dizinleriSil() {
  for (const d of dizinler) { try { rmSync(d, { recursive: true, force: true, maxRetries: 3 }); } catch { /* sonraki süpürme alır */ } }
  dizinler.length = 0;
}

function temizle() { hepsiniKapat(); dizinleriSil(); }

if (process.env.SINAV_COCUK_KAPATMA !== '0') {   // 0 yalnız mutant sınavı için: kapatma ve silme devre dışı
  process.on('exit', temizle);
  for (const s of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(s, () => { temizle(); process.exit(128); });
}
