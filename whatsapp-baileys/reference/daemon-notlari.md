# reference/daemon-notlari — kalıcı daemon çekirdeği + statusCode tablosu + tek-instance-kilidi

> Kopyalama referansı — **genel çekirdek**. Login `connected` der demez uzun-ömürlü bir daemon
> devralır: linki tamamlar, auto-reconnect eder, iş-kuyruğunu tüketir. Proje-DB/logger SIYRILMIŞ.

## Neden zorunlu (yarım-link tuzağı)
Kısa-ömürlü login `connected` gösterse bile, son creds (`registered=true`) tam flush olmadan socket
ölürse telefon linki bitiremez ("giriş yapılıyor"da asılı; Vekâtip 6 Tem: `registered:false` ama `me`
dolu = yarım link). **Kalıcı daemon** devralınca telefonda **"Google Chrome (Ubuntu)"** bağlı görünür.

## statusCode → aksiyon tablosu (auth-silme değişmezi)

| statusCode | Anlam | Aksiyon |
|---|---|---|
| `515` restartRequired | İlk pair'den SONRA **NORMAL** | Kayıtlı creds ile YENİ socket. **Auth SİLME.** |
| `408`/`428`/`440`/`503` | Geçici kopma | Auth **KORU**, backoff-reconnect. İlk-link döngüsündeyse SAATLERCE backoff (throttle). |
| `401` loggedOut | Oturum düştü | Auth **bir kez** sil → temiz re-pair (döngüye GİRME). |
| `500` badSession / `411` mismatch | Bozuk creds | Auth sil → re-pair. |
| `403` forbidden | Hesap kısıtlı | **DURDUR**, insana bildir (ban olabilir). |

**Auth'u ASLA silme:** `515/408/428/440/503/403`. Sil-ve-hemen-yeniden-dene döngüsü YAPMA (#2691 throttle).

## Tek-instance-kilidi (mimari A çekirdeği)

Bir numara aynı anda yalnız TEK sıcak socket taşır. Daemon başlarken bir tek-instance-kilidi alır;
**alınamıyorsa başlamaz** (başka sahip canlı). Auth-dir paylaşan container'lar daemon ÇALIŞTIRMAZ,
yalnız iş-kuyruğuna yazar.

```ts
// Örnek: Postgres advisory-lock (DB varsa). Alternatif: node-stdlib flock (aşağıda).
// pg_try_advisory_lock non-blocking döner: true = bu instance sahip; false = başka sahip var.
const LOCK_KEY = 0x7761_0001; // sabit uygulama-anahtarı (numara-başına farklı seç)
const got = await db.query('SELECT pg_try_advisory_lock($1) AS ok', [LOCK_KEY]);
if (!got.rows[0].ok) { console.error('daemon: başka sahip canlı — çıkılıyor'); process.exit(0); }
// ... socket + iş-kuyruğu döngüsü ...
// process exit'te pg_advisory_unlock (ya da bağlantı kapanınca otomatik serbest).
```

```ts
// DB yoksa: dosya-tabanlı flock (tek-host). Farklı host'larda çalışmaz — o durumda A-mimari
// zaten tek sahip-container varsayar, bu yeterli.
import { open } from 'node:fs/promises';
import { constants } from 'node:fs';
// <LOCK_PATH> proje-parametresi (kalıcı yol). O_CREAT|O_EXCL ile atomik sahiplik:
try {
  const fh = await open(LOCK_PATH, constants.O_CREAT | constants.O_EXCL | constants.O_RDWR);
  await fh.writeFile(String(process.pid));
  process.on('exit', () => { try { require('node:fs').unlinkSync(LOCK_PATH); } catch {} });
} catch { console.error('daemon: kilit alınamadı — başka sahip canlı'); process.exit(0); }
```

## Devir kuralları
- **Daemon + login AYNI ANDA çalışmasın** (aynı auth-dir → çift socket çakışması). Kilit bunu garanti eder.
- Login script'in 'open'-sonrası çıkış gecikmesini ≥4 sn yap (800ms YETMEZ) — creds flush.
- Daemon `creds.update`'te `saveCreds`'i DAİMA çağırır; auth-dizini içeriğini loglamaz/basmaz.
