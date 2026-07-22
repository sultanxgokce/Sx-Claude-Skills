# reference/wa-socket — generic Baileys socket çekirdeği

> Kopyala-uyarla referans. **Generic çekirdek**: proje-logger/DB/kontratı SIYRILMIŞ.
> Uyarlarken kendi logger/pino seviyeni ve hata-raporlamanı EKLE. Sır-değeri (auth) burada YOK —
> `AUTH_DIR` proje-parametresidir, socket onu yalnız `useMultiFileAuthState` ile okur, içeriğini basmaz.

İki değişmez bu dosyanın varlık-sebebi:
- **`fetchLatestWaWebVersion`** kullan — `fetchLatestBaileysVersion` DEĞİL (bayat → 408, #2679).
- **`Browsers.ubuntu('Chrome')`** — Linux/Docker'da doğru; `Browsers.macOS` KULLANMA (#2306/#1761).

```ts
import makeWASocket, {
  useMultiFileAuthState, fetchLatestWaWebVersion,
  makeCacheableSignalKeyStore, Browsers,
} from '@whiskeysockets/baileys';
import pino from 'pino';

// AUTH_DIR = proje-parametresi (kalıcı, container-recreate-dayanıklı yol).
// Bu çekirdek AUTH_DIR içeriğini ASLA loglamaz/basmaz.
export async function makeWaSocket(AUTH_DIR: string) {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const logger = pino({ level: 'silent' });   // ← projede kendi seviyeni ver

  // CANLI sürüm. Gömülü fallback tuple ⚠ zamanla bayatlar — son doğrulama: 2026-07-22.
  // Bayatlarsa 408 nüksü (#2679); scripts/wa-version-check.mjs ile denetle.
  let version: [number, number, number] = [2, 3000, 1042466098];
  try {
    const r = await fetchLatestWaWebVersion();
    if (r.isLatest) version = r.version;
  } catch { /* ağ yoksa fallback tuple ile devam */ }

  const sock = makeWASocket({
    version,
    auth: { creds: state.creds, keys: makeCacheableSignalKeyStore(state.keys, logger) },
    logger,
    browser: Browsers.ubuntu('Chrome'),   // özel ad ("Vekatip" vb.) YASAK → companion_hello reddi → 408
    markOnlineOnConnect: false,
    syncFullHistory: false,
    shouldSyncHistoryMessage: () => false,
    connectTimeoutMs: 60_000,
    defaultQueryTimeoutMs: 60_000,
    keepAliveIntervalMs: 25_000,
    getMessage: async () => undefined,
  });
  sock.ev.on('creds.update', saveCreds);   // creds'i DAİMA kaydet
  return { sock, saveCreds, version };
}
```

**Notlar (uyarlama):**
- `printQRInTerminal` v7'de kaldırıldı — QR string'ini `connection.update`'ten oku, kendin çiz (bkz wa-login).
- QR relay için `reference/wa-login.md`; kalıcı devir için `reference/daemon-notlari.md`.
