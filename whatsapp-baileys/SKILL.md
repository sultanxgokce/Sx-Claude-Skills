---
name: whatsapp-baileys
type: agent
version: 1.1.0
description: >
  Bir Baileys (@whiskeysockets/baileys) WhatsApp botunu telefona GÜVENİLİR bağlama
  playbook'u. Günlerce süren pairing cebelleşmesinden çıkarılmış kesin dersler:
  bayat-sürüm bug'ı (#2679), auth-churn throttle'ı (#2691), 515-normal, QR-first,
  CloudBridge rotation-proof QR relay, bağlantı-sonrası daemon devri. Stack bağımsız.
install_target:
  skills: .claude/skills/
  commands: .claude/commands/
stacks: ["*"]
author: sultanxgokce
tags: [whatsapp, baileys, pairing, qr, bot, throttle, cloudbridge, dev-infra]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# WhatsApp (Baileys) Bot Bağlama — Kesin Playbook

Bir **ayrı bot numarasını** Baileys ile telefona "bağlı cihaz" olarak eklemenin
**güvenilir** yolu. Bu skill, Vekâtip'te günlerce süren pairing savaşından (6 Tem 2026,
ilk tam başarı) çıkarılmış derslerdir. Baileys kullanan HER projede geçerlidir; proje-özel
yollar §7'de parametredir.

> **Bot AYRI numaradır** (kişisel hat değil) — Baileys gayrıresmî olduğundan düşük hacim +
> tek sıcak bağlantı ilkesi. Meta Cloud API grup DESTEKLEMEZ (yalnız 1:1) → grup yönetimi
> yalnız Baileys ile mümkün, bu yüzden bu yola mecburuz.

---

## ⚡ İKİ KÖK NEDEN (ikisi de kanıtlı — önce bunları bil)

Pairing "çalışmıyor"un neredeyse tüm sebebi bu ikisidir. Karıştırma:

### 1. Bayat-sürüm bug'ı → 408 / "cihaz bağlanamadı" (KOD HATASI, [Baileys #2679](https://github.com/WhiskeySockets/Baileys/issues/2679))
`fetchLatestBaileysVersion()` (rc13'te) WA-Web sürümünü **GitHub master'dan** çeker; bu değer
**bayat** ve `isLatest:true` diye döner. WhatsApp **bayat sürümle cihaz-link'i sessizce
tamamlamaz** → telefonda **"cihaz bağlanamadı"** + socket **408**.
- **FIX:** `fetchLatestWaWebVersion()` kullan (canlı `client_revision`'ı `web.whatsapp.com/sw.js`'ten
  çeker). Gömülü fallback tuple'ı GÜNCEL tut (bayatlarsa 408 nüksler).
- **Kanıt (Vekâtip, 6 Tem 2026):** `fetchLatestBaileysVersion → [2,3000,1035194821]` (bayat) vs
  `fetchLatestWaWebVersion → [2,3000,1042657073]` (canlı). Bu tek değişiklik pairing'i açtı.

### 2. Auth-churn throttle'ı → "Şu anda yeni cihaz bağlanamıyor" ([Baileys #2691](https://github.com/WhiskeySockets/Baileys/issues/2691))
Denemeler arası auth dizinini silip yeniden register etmek = her seferinde YENİ device-link
kaydı → WhatsApp'ın yeni-cihaz throttle'ı, **24s+ sürebilir**. (Vekâtip'te 20 dk'da 6 deneme →
günlerce kilit.) **Kod değil, OPERATÖR davranışı.**
- **FIX:** Auth'u KALICI tut. Auth **yalnız** gerçek `401 loggedOut` / `500 badSession` /
  `411 multideviceMismatch`'te silinir. `515`/`408`/`428`/`440`'ta **KORU + reconnect.**
- **Disiplin:** BİR oturumda BİR deneme. "Şu anda yeni cihaz bağlanamıyor" görürsen **ANINDA DUR**,
  24-48 saat SIFIR deneme. Her ek deneme kilidi UZATIR. Hiçbir kod aktif throttle'ı bypass etmez.

---

## 1. Sağlam `makeWASocket` konfigürasyonu

```ts
import makeWASocket, {
  useMultiFileAuthState, fetchLatestWaWebVersion,
  makeCacheableSignalKeyStore, Browsers,
} from '@whiskeysockets/baileys';

const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
const logger = pino({ level: 'silent' });

// CANLI sürüm (fetchLatestBaileysVersion DEĞİL — o bayat, #2679). Fallback GÜNCEL tuple.
let version: [number,number,number] = [2, 3000, 1042466098]; // ⚠ zamanla bayatlar · son doğrulama: 2026-07-22 · yenile: scripts/wa-version-check.mjs
try { const r = await fetchLatestWaWebVersion(); if (r.isLatest) version = r.version; } catch {}

const sock = makeWASocket({
  version,
  auth: { creds: state.creds, keys: makeCacheableSignalKeyStore(state.keys, logger) },
  logger,
  browser: Browsers.ubuntu('Chrome'),   // ⚠ Linux/Docker'da DOĞRU. Browsers.macOS KULLANMA (#2306/#1761).
  markOnlineOnConnect: false,
  syncFullHistory: false,
  shouldSyncHistoryMessage: () => false,
  connectTimeoutMs: 60_000,
  defaultQueryTimeoutMs: 60_000,
  keepAliveIntervalMs: 25_000,
  getMessage: async () => undefined,
});
sock.ev.on('creds.update', saveCreds);   // creds'i DAİMA kaydet
```

- `browser[0]` özel bir ad ("Vekatip" gibi) OLMASIN — companion_hello doğrulaması reddeder → 408.
- `printQRInTerminal` v7'de kaldırıldı; QR string'i `connection.update`'ten oku, kendin çiz.

## 2. Doğru reconnect / auth-silme kuralları

`connection.update` → `connection === 'close'` → `statusCode`'a göre:

| statusCode | Anlam | Aksiyon |
|---|---|---|
| `515` restartRequired | İlk pair'den SONRA **NORMAL** | Kayıtlı creds ile YENİ socket. **Auth SİLME.** |
| `408`/`428`/`440`/`503` | Geçici kopma | Auth KORU, backoff-reconnect. İlk-link döngüsündeyse SAATLERCE backoff (throttle). |
| `401` loggedOut | Oturum düştü | Auth **bir kez** sil → temiz re-pair (döngüye girme). |
| `500` badSession / `411` mismatch | Bozuk creds | Auth sil → re-pair. |
| `403` forbidden | Hesap kısıtlı | **Durdur**, insana bildir (ban olabilir). |

**Auth'u ASLA silme:** 515/408/428/440/503/403. **Sil-ve-hemen-yeniden-dene döngüsü YAPMA** (throttle).

## 3. QR-first (eşleştirme-kodu SON ÇARE)
İlk bağlanmayı **DAİMA QR** ile yap. `requestPairingCode` (rc13) sunucu-doğrulaması olmadan
optimistik döner → "cihaz bağlanamadı" + 408 ([#2590](https://github.com/WhiskeySockets/Baileys/issues/2590),
[PR #2559](https://github.com/WhiskeySockets/Baileys/pull/2559)). Yalnız kamera/QR gerçekten imkânsızsa kod kullan.

## 4. CloudBridge rotation-proof QR relay (AI'ın QR'ı kullanıcıya göstermesi)
**Sorun:** QR ~20-25 sn'de yenilenir; AI'ın "QR'ı gör → yayınla → kullanıcı aç → okut" turu bu
pencereyi aşar → QR bayatlar. Hosted-artifact yolları da rotation'ı kovalayamaz.
**Çözüm — AI tur-gecikmesini denklemden çıkar:** QR'ı kullanıcının bir **paylaşımlı klasörüne**
(ör. Mutagen/Dropbox/iCloud senkron), **kendi kendini tazeleyen** bir HTML ile koy:
1. `wa-qr.html`: `<meta http-equiv="refresh" content="4">` + cache-bust'lı `<img src="wa-qr.png?t="+Date.now()>`.
2. Arka planda **3 sn'de bir** taze `qr.png`'yi o klasöre kopyala (atomik: `.tmp`→`mv`); `connected`/`logged_out` olunca dur.
3. Kullanıcı `wa-qr.html`'i **bir kez** açar; sayfa 4 sn'de tazelenir → ekranda hep ~5-8 sn'lik taze QR.
   Kullanıcı acele etmeden okur; AI'ın tur gecikmesi önemsizleşir.

## 5. Bağlandıktan SONRA → kalıcı daemon devri (ZORUNLU)
⚠ Kısa-ömürlü login script'i `connected` gösterse bile telefon **"giriş yapılıyor"da asılı kalabilir:**
'open'dan birkaç sn sonra script kapanır, son creds (`registered=true`) tam flush olmadan socket ölürse
telefon linki bitiremez (Vekâtip 6 Tem: `registered:false` ama `me` dolu = yarım link).
- **FIX:** login `connected` der demez **kalıcı bir daemon** başlat (uzun-ömürlü socket, auto-reconnect).
  Daemon devralır, linki tamamlar; telefonda **"Google Chrome (Ubuntu)"** bağlı cihaz olarak görünür.
- Login script'in 'open'-sonrası çıkış gecikmesini ≥4 sn yap (800ms YETMEZ).
- **Daemon + login AYNI ANDA çalışmasın** (aynı auth-dir → çift socket çakışması). Advisory-lock ile tek daemon.

## 6. Semptom sözlüğü (yanlış yola sapma)
| Görülen | Anlam | Ne yap |
|---|---|---|
| "cihaz bağlanamadı" + 408 | Bayat sürüm (#2679) | `fetchLatestWaWebVersion` devrede mi? Fallback tuple'ı yenile. |
| "Şu anda yeni cihaz bağlanamıyor" | Throttle (#2691) | DUR + 24-48s bekle. Kod çözmez. |
| `515` (pair'den sonra) | Normal restart | Kayıtlı creds ile reconnect, auth silme. |
| Telefon "giriş yapılıyor"da asılı | Yarım link (login erken kapandı) | Daemon başlat (§5). |
| `401` bağlantıdan hemen sonra | Oturum reddi | Döngüye girme; auth bir kez sil, uzun backoff. |

## 7. Proje-özel parametreler (kuran Claude doldurur)
Bu skill stack-bağımsızdır; kuran proje şunları sağlar:
- `AUTH_DIR` — multi-file auth dizini (kalıcı, container-recreate'e dayanıklı bir yol; ör. `/config/.vekatip/wa-auth`).
- Login script'i (QR relay + status.json yazan) + kalıcı daemon (job kuyruğu tüketen).
- QR relay için paylaşımlı klasör yolu (CloudBridge/Dropbox/iCloud).
- Baileys sürümü: `@whiskeysockets/baileys@7.0.0-rc13` (exact pin) — rc10 stabilite + güvenlik yaması taşır.
- **Referans implementasyon:** Vekâtip `server/src/whatsapp/{socket,daemon}.ts` + `scripts/wa-login.ts`
  + `.claude/skills/whatsapp-baglan` (proje-özel tam koreografi + grup sync/link/rename).

## 8. Parametre-sözleşmesi (doldurulabilir form — kuran Claude/proje doldurur)

Bu skill **proje-agnostiktir**: hiçbir hedef-proje değeri gömülü DEĞİLdir. Aşağıdaki tablo bir
**form**dur; "Örnek" sütunundaki değerler yalnız Vekâtip'ten alınmış ÖRNEKtir (kopyalanacak değil,
yalnız şablon). Gerçek deployment-değerleri (numara, kalıcı auth-dizini, canlı-QR klasörü) **F5
deployment-gate'ine ertelenir** ve Sultan tarafından hedef-projede doldurulur.

| Parametre | Ne | Değişmez / kural | Örnek (Vekâtip — kopyalama, şablon) |
|---|---|---|---|
| `WA_AUTH_DIR` | multi-file auth dizini | **SIR** · kalıcı + container-recreate-dayanıklı · `/tmp` altı YASAK · skill okumaz/basmaz/silmez | `/config/.vekatip/wa-auth` |
| QR-relay klasörü | kendini-tazeleyen QR'ın konduğu paylaşımlı dizin (§4) | senkron-görünür (Mutagen/Dropbox/iCloud) · atomik `.tmp`→`mv` | `<paylaşımlı>/wa-qr/` |
| `status.json` | login/daemon durum ayak-izi (connected/logged_out) | proje-tarafında yazılır · değer-güvenli | `<WA_AUTH_DIR>/status.json` |
| bot-no | AYRI bot numarası (kişisel hat DEĞİL) | tek-sıcak-bağlantı ilkesi | `<hedef-proje sağlar>` |
| login-script | QR-relay + status.json yazan kısa-ömürlü giriş | 'open'-sonrası çıkış ≥4 sn (§5) | `scripts/wa-login.ts` |
| daemon-script | uzun-ömürlü socket, iş-kuyruğu tüketen | login ile AYNI ANDA çalışmaz | `server/src/whatsapp/daemon.ts` |
| tek-instance-kilidi | numarayı tek daemon sahiplensin | `pg_try_advisory_lock` / `flock` | advisory-lock |
| baileys-pin | exact sürüm pin'i | `@whiskeysockets/baileys@7.0.0-rc13` | rc13 |

## 9. Kurulum-koreografisi (proje-agnostik · varsayılan mimari = A)

"Sultan'ın WhatsApp'ı" tek numaradır; bir numara aynı anda yalnız **tek sıcak socket** taşır. İki
meşru mimari var — **varsayılan A**, skill B'yi de parametrik destekler:

- **A · Tek-numara + tek-sahip-daemon (VARSAYILAN):** BİR container numarayı sahiplenir, daemon'u
  **tek-instance-kilidiyle** (`pg_try_advisory_lock` / `flock`) tutar. Diğer container'lar `WA_AUTH_DIR`'i
  **PAYLAŞMAZ**; sahip-daemon'a bir **iş-kuyruğuyla** (DB tablosu / dosya-kuyruğu) mesaj bırakır, o gönderir.
  Auth tek yerde, çift-socket çakışması ve auth-churn throttle (#2691) yapısal olarak engellenir.
- **B · Proje-başına ayrı bot-numarası:** her tenant kendi numarası + kendi `WA_AUTH_DIR`'i. Basit
  ama her numara ayrı hat/pairing ister. Yalnız gerçekten ayrı-numara isteniyorsa.

**A koreografisi (adımlar):**
1. Sahip-container seç → `WA_AUTH_DIR`'i orada kalıcılaştır (§8 form).
2. Daemon'u tek-instance-kilidiyle başlat; kilit alınamıyorsa **başlama** (başka sahip canlı).
3. Diğer container'lar auth-dir'e DOKUNMAZ → yalnız iş-kuyruğuna yazar; sahip-daemon tüketir.
4. İlk pairing yalnız sahip-container'da, QR-first (§3-§4), tek-deneme disipliniyle (#2691).

## 10. Yeni projede 3 adım

1. **Parametreleri doldur** (§8 formu) — `WA_AUTH_DIR` kalıcı-yol seç, mimariyi (A/B, varsayılan A) seç.
2. **Çekirdeği uyarla** — `reference/wa-socket.md` + `reference/wa-login.md` + `reference/daemon-notlari.md`
   kodunu proje-logger/DB/kontratını EKLEYEREK uyarla (referanslar generic, sıyrılmış çekirdek).
3. **Preflight koştur** — `bash scripts/wa-preflight.sh <proje-kökü>` KIRMIZI vermemeli; tuple
   bayatladıysa `node scripts/wa-version-check.mjs`. Canlı pairing = ayrı Sultan-gate (F5), statik-üretimde YASAK.

## Kaynaklar
Baileys issue'ları: [#2679](https://github.com/WhiskeySockets/Baileys/issues/2679) (bayat sürüm),
[#2691](https://github.com/WhiskeySockets/Baileys/issues/2691) (churn throttle),
[#2590](https://github.com/WhiskeySockets/Baileys/issues/2590) / [PR #2559](https://github.com/WhiskeySockets/Baileys/pull/2559) (pairing-code kırılganlığı),
[#2306](https://github.com/WhiskeySockets/Baileys/issues/2306)/[#1761](https://github.com/WhiskeySockets/Baileys/issues/1761) (browser imzası).
[wiki/connecting](https://baileys.wiki/docs/socket/connecting/).
