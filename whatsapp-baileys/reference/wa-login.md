# reference/wa-login — generic QR→PNG login + status.json + 515-reconnect

> Kopyala-uyarla referans. **Generic çekirdek**: DB/proje-logger SIYRILMIŞ. QR'ı bir PNG'ye yazar,
> durumu değer-güvenli bir `status.json`'a düşer, `515`'te kayıtlı creds ile reconnect eder.
> **Auth-silme kuralı burada değişmez** — yalnız `401/500/411`'de sil; `515/408/428/440/503`'te KORU.
> Sır-hijyeni: QR PNG ve status.json auth-creds İÇERMEZ; auth-dizini yalnız `useMultiFileAuthState` okur.

```ts
import { Boom } from '@hapi/boom';
import * as QR from 'qrcode';          // qr → PNG
import { writeFile, rename } from 'node:fs/promises';
import { join } from 'node:path';
import { makeWaSocket } from './wa-socket'; // bkz reference/wa-socket

// AUTH_DIR + QR_DIR = proje-parametreleri. STATUS = <AUTH_DIR>/status.json (değer-güvenli ayak-izi).
export async function loginOnce(AUTH_DIR: string, QR_DIR: string) {
  const STATUS = join(AUTH_DIR, 'status.json');
  const writeStatus = async (s: string) => {
    // status = yalnız durum-etiketi; auth/numara/token ASLA yazılmaz.
    const tmp = STATUS + '.tmp';
    await writeFile(tmp, JSON.stringify({ status: s, at: new Date().toISOString() }));
    await rename(tmp, STATUS);                         // atomik
  };

  const { sock } = await makeWaSocket(AUTH_DIR);

  sock.ev.on('connection.update', async (u) => {
    const { connection, lastDisconnect, qr } = u;

    if (qr) {
      // QR'ı PNG'ye atomik yaz — kendini-tazeleyen relay bu PNG'yi 3sn'de kopyalar (SKILL §4).
      const tmp = join(QR_DIR, 'wa-qr.png.tmp');
      await QR.toFile(tmp, qr, { margin: 1, width: 320 });
      await rename(tmp, join(QR_DIR, 'wa-qr.png'));
      await writeStatus('qr');
    }

    if (connection === 'open') {
      await writeStatus('connected');
      // ⚠ 'open'-sonrası ≥4sn bekle (creds flush); sonra kalıcı daemon devralır (daemon-notlari.md).
      setTimeout(() => process.exit(0), 4000);
    }

    if (connection === 'close') {
      const code = (lastDisconnect?.error as Boom)?.output?.statusCode;
      if (code === 515) {
        // pair-sonrası NORMAL restart — kayıtlı creds ile YENİ socket, auth SİLME.
        await writeStatus('restart_required');
        return loginOnce(AUTH_DIR, QR_DIR);
      }
      if (code === 401 || code === 500 || code === 411) {
        // oturum düştü/bozuk — auth BİR KEZ sil (döngüye girme), sonra temiz re-pair.
        await writeStatus('logged_out');
        // NOT: auth-silme proje-tarafında, tek-sefer, backoff'lu yapılır (throttle #2691).
        return;
      }
      // 408/428/440/503 + diğerleri: auth KORU, backoff-reconnect (ilk-link döngüsündeyse SAATLERCE).
      await writeStatus('reconnecting');
      return loginOnce(AUTH_DIR, QR_DIR);
    }
  });
}
```

**Değişmez:** `requestPairingCode` yerine DAİMA QR-first (§3) — pairing-code optimistik döner, 408 riski (#2590).
