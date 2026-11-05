// sinav-cocuk.mjs — sınavın açtığı süreçleri (tarayıcı) sınav HANGİ YOLLA biterse bitsin kapatır.
// Sorun: sınav tarayıcıyı yalnız başarı yolunda kill() ile kapatıyordu; sınav çökünce, zaman aşımına uğrayınca
//   ya da bir mutant sınavı ortasında kesince tarayıcı açık kalıyordu (görev …P6BY85C).
// Çare: çocuk yeni süreç grubunda açılır (tarayıcının alt süreçleri de grupta); çıkışta, çökmede ve
//   TERM/INT/HUP sinyalinde grubun hepsi KILL ile kapatılır.
import { spawn } from 'child_process';

const canli = new Set();

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

if (process.env.SINAV_COCUK_KAPATMA !== '0') {   // 0 yalnız mutant sınavı için: kapatma devre dışı
  process.on('exit', hepsiniKapat);
  for (const s of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(s, () => { hepsiniKapat(); process.exit(128); });
}
