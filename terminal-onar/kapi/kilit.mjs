// kilit.mjs — süreçler arası kayıt kilidi (Parça B7). Kapı ve günlük bekçi turu AYNI kayda yazar; ikisi de bu kilidi alır.
// Sınav: kilit.test.mjs (DV32–j) · dava.test.mjs DV32–DV32d. Kullanan: kadro-yaz.mjs (kadroYaz tüm okuma-yazma boyunca tutar) ·
// sunucu.mjs hal ucu ve dava-bekci.mjs (bütün işlem boyunca tutar, içeride kadroYazKilitAltinda).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { KadroHata } from './kadro-yaz.mjs';

// 🔴 Kernel kilidi (flock(1); bağımsız göz tur 1–3: dosya yaşı, pid ve devral mantığı yarışları bu yüzden kalktı):
//   · Kilidi yardımcı bir sh süreci tutar: kilit dosyası üzerinde flock -x. Süreç ölünce (SIGKILL dahil) kernel kilidi kendiliğinden düşer.
//   · Yardımcının stdin'i borudur: çağıran süreç ölürse boru kapanır, yardımcı çıkar, kilit düşer (yetim kilit kalmaz).
//   · Bekleme 'flock -n' yoklamasıdır (50 ms); her turda çağıranın hâlâ yaşadığına bakılır (kill -0). Çağıran öldüyse yardımcı
//     kilidi ALMADAN çıkar (denetim tur 1: bekleyen yardımcı ölü çağıran adına kilit alıp ack bırakıyordu).
//   · Ack dosyası (kilit alındı işareti) yardımcı tarafından da temizlenir: SIGTERM ile bırakmada trap onu siler.
//   · Bırakma senkron SIGTERM ile. Kilit dosyası silinmez (silinirse iki inode üzerinde yarış çıkar); içeriği anlamsızdır.
//   · Yardımcı kilidi alınca ack dosyası yazar; çağıran Atomics.wait ile bekler. 30 sn'de alınamazsa KadroHata 503.
const uyu = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const TUTUCU = `exec 9>>"$1"; n=0; until flock -n 9; do n=$((n+1)); [ "$n" -gt "$2" ] && exit 3; kill -0 "$4" 2>/dev/null || exit 3; sleep 0.05; done; trap 'rm -f "$3"; exit 0' TERM HUP INT; : > "$3"; read _; rm -f "$3"`;
export function dosyaKilit(dizin, { bekleMs = 30000 } = {}) {
  const y = path.join(dizin, 'kadro.kilit');
  const ack = y + '.ack-' + process.pid + '-' + Math.random().toString(36).slice(2);
  const bas = Date.now();
  const t = spawn('sh', ['-c', TUTUCU, 'sh', y, String(Math.ceil(bekleMs / 50)), ack, String(process.pid)], { stdio: ['pipe', 'ignore', 'ignore'] });
  t.on('error', () => {});
  const birak = () => { try { t.kill('SIGTERM'); } catch {} };
  for (;;) {
    if (fs.existsSync(ack)) { fs.rmSync(ack, { force: true }); return birak; }
    if (Date.now() - bas > bekleMs) { birak(); throw new KadroHata(503, 'Kayıt başka bir işlemce kilitli — biraz sonra yeniden dene.'); }
    uyu(20);
  }
}
