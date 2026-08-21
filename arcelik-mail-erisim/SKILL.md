---
name: arcelik-mail-erisim
version: 0.1.0
description: Arçelik servis Exchange posta kutusuna (yetkili-servis FİŞ PAKETİ mailleri) bağlanır, fiş paketi maillerini ve PDF eklerini bulur/indirir; bağlantı koptuğunda ONARIR. Arçelik Azure AD tenant'ı standart OAuth2'yi kapatmıştır — çalışan TEK yol Device Code Flow + EWS scope'tur (3 ay ölçülerek bulundu, 7 yol elendi). Kimlik yoksa dürüst-kırmızı verir, tahmin etmez. SALT-OKUR: mail silmez/göndermez/okundu-işaretlemez. "fiş paketi getir · Arçelik maili · mail bağlantısı koptu · token yenile · AADSTS hatası" tetiğinde.
---

# arcelik-mail-erisim — Arçelik posta kutusu (fiş paketi hattı)

**Kademe:** Kalfa (S2 · paketli) · **Doğum:** 2026-08-22, MUHASİP (MMEx)
**Niçin var:** Fatura kesmenin girdisi bu mailde. Hat koptuğunda "ne yapacağını bilmeyen"
konuma düşmemek için 3 aylık debugging burada damıtıldı.

## 🔴 Değişmez 1 — ÇALIŞAN TEK FORMÜL (7 yol elendi, bunu değiştirme)

```
Client ID : d3590ed6-52b3-4102-aeff-aad2292ab01c     (Outlook Desktop — first-party)
Scope     : https://outlook.office365.com/EWS.AccessAsUser.All offline_access
Flow      : Device Code Flow                          (MFA'yı destekler, headless gerekmez)
API       : https://outlook.office365.com/api/v2.0    (Outlook REST v2.0)
```

**Niçin Graph API DEĞİL:** Arçelik tenant'ında *"kullanıcılar üçüncü taraf uygulamalara consent
veremez"* politikası var ve Graph API resource'u (`00000003-…`) Device Code Flow'da **hiçbir**
first-party client için ön-yetkili değildir. Exchange Online (`00000002-0000-0ff1-ce00-000000000000`)
ise Outlook Desktop için **kesinlikle** ön-yetkilidir — Outlook'un kendi çalışma mekanizması budur.

**Elenen 7 yol (tekrar deneme):** ① OAuth2 Auth-Code → AADSTS65001 · ② +PKCE → 65001 ·
③ ROPC → AADSTS50076 (MFA) · ④ IMAP+Basic → Basic Auth kapalı · ⑤ Playwright/headless → MFA'da
takılır, güvenilmez · ⑥ DeviceCode+Graph (Office client) → AADSTS65002 · ⑦ DeviceCode+Graph
(Azure CLI client) → AADSTS65002.

### Altın kural (kısıtlı Azure AD tenant'ında)
1. Custom App Registration **KULLANMA** — admin consent alamazsın.
2. Graph API scope **KULLANMA** — first-party preauthorization yok.
3. Outlook Desktop client ID + **EWS scope KULLAN**.
4. **Device Code Flow** kullan — MFA destekler.

## 🔴 Değişmez 2 — SALT-OKUR sınırı
Bu skill **okur**. Mail **silmez · göndermez · okundu-işaretlemez · klasör taşımaz**.
Eski prod'a (Railway config · auth-broker VPS 135.181.85.212 · cron · prod DB **şeması**)
**YAZMAZ** — MMEx CLAUDE.md §3 YASAK listesi burada aynen geçerlidir. Prod DB'de yalnız `SELECT`
(sonda `SET default_transaction_read_only = on` ile kendi elini bağlar).

## 🔴 Değişmez 3 — sır-hijyeni
`access_token`/`refresh_token` **değeri** stdout/log/chat'e ASLA. Token'lar prod'da `AronCredential`
tablosunda **Fernet ile şifreli** durur; hangi `client_id` ile alındığı `cookie_map`'te saklanır
(refresh'te doğru client_id şart). Kimlik bu kutuda `~/.config/cortex-access.env` (600) →
`vault-cek` ile kasadan gelir. `.env` dosyalarında **grep ile sır avı YASAK**.

## Hesaplar ve hat

🔴 **Gerçek posta adresleri BU DOSYADA YOKTUR** — ortak raf 16 kutunun gördüğü yerdir (İ1) ve
adresin biri bir **kişiye** aittir. Adresler **kutu-yerel türevde** yaşar (aşağıdaki *Türev*).
*Ayırt edici test — bu rafa bir satır yazmadan önce sor:* **"bu satır ikinci bir tüzel kişide
de aynı mı kalır?"** Hayırsa buraya yazılmaz. (Client ID, scope, AADSTS kodları → evet, kalır.
Posta adresi, servis kodu, unvan, VKN → hayır, çıkar.)

Hat iki hesap tanır; ikisi de `exchange_mail_messages.account_key` ile ayrılır:
| rol | ne için |
|---|---|
| **fiş-paketi hesabı** | yetkili-servis fiş paketi mailleri — bu skill'in asıl hedefi |
| **genel hesap** | diğer yazışma |

**Fiş paketi 3 katmanlı sınıflanır** (`classify_mail_category`, kaynak: MMEpanel
`backend/services/integrations/exchange_mail.py`):
1. **Negatif önce** — `FIS_UYARI_PATTERN` ("Düzenlenmeyen", "Hatırlatma") → `fis_uyari`, **paket DEĞİL**.
2. **Kesin eşleşme** — subject'te "FIS PAKETI DOKUMU" / "İADE PAKETI DOKUMU" → `fis_paketi`.
3. **Geniş fallback** — gönderen belirsizse **güvenli tarafa** düşer (`fis_uyari`), pakete saymaz.
Ayrıca `fatura_talebi` (subject'te "fatura taleb") ayrı kategoridir.
→ Kategori `exchange_mail_messages.category` + `is_fis_paketi`; işlendi bayrağı `fis_paketi_processed`.

**PDF ekleri nerede:** `exchange_mail_attachments.content_bytes` (binary, DB içinde) —
`message_id` ile mail'e bağlı. Yani PDF'i ayrı bir dosya deposundan değil, **DB'den** alırsın.

## Arıza sözlüğü — hat koptuğunda BURAYA BAK

| Belirti | Anlamı | Ne yap |
|---|---|---|
| `AADSTS65001` | admin consent gerekiyor | custom app KULLANMA → first-party client ID |
| `AADSTS65002` | first-party preauthorization yok | Graph scope'u bırak → **EWS scope** |
| `AADSTS50076` | MFA gerekiyor | ROPC bırak → **Device Code Flow** |
| `AADSTS50079` | MFA kaydı gerekiyor | ROPC bırak |
| `AADSTS7000215` | geçersiz client secret | secret'ı kontrol et ya da PKCE |
| Graph'ta **401**, token taze | EWS token'ı Graph'ta geçmez | Outlook REST v2.0'a düş (kod bunu otomatik yapar) |
| "Unknown device code" | çok-worker in-memory state | `account_key` URL'den gelmeli (çözüldü) |
| 403 + `error code: 1010` | Cloudflare bot engeli | tarayıcı-benzeri `User-Agent` şart — kimlik hatası DEĞİL |
| 5xx / timeout | geçici | 3 deneme + üstel backoff (kodda var); 401/403 **retry'lanmaz** |

**Token ömrü:** refresh token **~90 gün**; sistem **50 dakikada bir** sessizce yeniler; başarısız
olursa **Telegram** bildirimi gider. İnsan yeniden bağlar: panelde **Sistem > Mail > Exchange Mail Bağla**.

### ⚠️ Bilinen borç (kapatılmadı — MMEpanel'de duruyor)
`_refresh_access_token()` yenilemede hâlâ **Graph** `SCOPES`'unu kullanıyor. EWS token'ı Graph
scope'uyla yenilenirse yeni token EWS yerine Graph için çıkabilir. Şu an 3-aşamalı fallback bunu
kompanse ediyor. **Hat açıklanamaz biçimde 401 veriyorsa ilk şüpheli budur.**
Ayrıca: Microsoft, Outlook REST v2.0'ı kaldırmayı planlıyor → o gün gelirse sıradaki aday
IMAP + OAuth (XOAUTH2). (Bugün gerekmiyor; erken göç etme.)

## Kullanım

```bash
bash scripts/mail.sh doctor        # 3-durum sağlık: yeşil / kırmızı / doğrulanmadı
bash scripts/mail.sh fis-listele [--gun N]   # son N günün fiş paketi mailleri (varsayılan 30)
bash scripts/mail.sh fis-indir <mail_id> [dizin]   # o mailin PDF eklerini diske yazar
```
Üçü de salt-okur. `doctor` kimlik yoksa **kırmızı** der, tahmin etmez.

## Türev — tüzel-kişiye özgü ne varsa BURADA yaşar (gövdede değil)
Gövde **şirketsiz ve kişisizdir**. Hangi posta kutusu, hangi servis kodu, hangi unvan/VKN —
bunlar kutu-yerel türevde ya da kasada durur, gövdeye **kopyalanmaz** (kopya bayatlar + İ1 sızar).
Türev, gövdeyi yalnız komut satırı sınırından çağırır.

| Türev anahtarı | Ne | Nerede |
|---|---|---|
| `ARCELIK_MAIL_FIS_HESAP` | fiş-paketi posta kutusunun `account_key`'i | kutu-yerel `cortex-access.env` (600) |
| (adresler) | tam posta adresleri | aynı yer — **gövdeye yazılmaz** |

## Kimlik — bu kutuda ne gerekiyor
| Anahtar | Ne için | Durum (2026-08-22, MMEx kutusu) |
|---|---|---|
| `MMEPANEL__PROD_DATABASE_URL` | depolanmış mail+PDF'i **okumak** (SELECT) | ❌ **kutuda YOK** — kasaya konmalı |
| Graph/EWS bearer | maili **canlı** çekmek | ❌ kutuda yok; prod'da AronCredential'da şifreli |

⚠️ Yerel `MMEPANEL__DATABASE_URL` **prod DEĞİL** — ölçüldü, değeri `sqlite:///./mme_panel.db`.
Prod'a bağlandığını sanıp yerel boş sqlite okumak, bu hattın en kolay **sahte-yeşil**idir.
`doctor` bunu ayrıca kontrol eder (sqlite ise kırmızı).

## 🔴 EKLER PDF DEĞİL — HTML (2026-08-22 firsthand düzeltmesi)
Kayıtlarda ve konuşmada "fiş paketi PDF'leri" geçiyor. **Ölçüldü: değil.** Her paket maili
**iki HTML** taşır:
| Ek | Ne | Tipik boy |
|---|---|---|
| `<SAPBelgeNo>_Ozet.html` | tek tablo: kalem türü × (Brüt·İndirim·İndirilmiş Brüt·KDV20·KDV10·Net) | ~5 KB |
| `<SAPBelgeNo>_Detay.html` | fiş fiş döküm | 9 KB – 700+ KB |
Faturaya gidecek **tüm tutarlar Özet'tedir**; Detay dayanaktır. PDF arayan kod boş döner.

### Özet'in kendi iç tutarlılığı — bedava çapraz-kontrol
Her pakette şu üç eşitlik **tutmak zorundadır** (ikisi ölçüldü, üçü de tuttu):
`brüt − indirim = indirilmiş brüt` · `net + KDV = indirilmiş brüt` · `Σbrüt = "Genel"`.
Tutmuyorsa ek bozuk ya da ayrıştırma yanlış → **fatura kesme, DUR.**
Ayrıca kalem türleri KDV20/KDV10 diye **ayrı satırlardır**; tek orana indirgeme yanlış fatura üretir.

## Ölçüm durumu — dürüstlük kaydı
- ✅ **Ölçüldü (firsthand, 2026-08-22):** çalışan formül · elenen 7 yol · AADSTS sözlüğü ·
  3-katmanlı sınıflandırma · PDF'in `content_bytes`'ta olduğu · yerel URL'nin sqlite olduğu.
  Kaynak: MMEpanel `exchange_mail.py` + `_agents/docs/mail_sync_problem_cozum.md` (17 Mart 2026, ÇÖZÜLDÜ).
- ✅ **CANLI KOŞULDU (2026-08-22):** Device Code Flow ile gerçek posta kutusuna bağlanıldı
  (insan onayı bir kez), token alındı (refresh VAR ~90 gün). Gelen kutusu **okundu**:
  Outlook REST v2.0 → **200** · Graph → **401 Invalid audience** (belgenin öngördüğü davranış,
  aynen çıktı). 150 mesaj tarandı → 42 paket maili, 3 uyarı, 2 fatura talebi; sınıflandırma
  yanlış-pozitif vermedi. Ekler indirildi ve aritmetiği çapraz-doğrulandı.
- ⏸ **Ölçülmedi:** prod DB yolu (`PROD_DATABASE_URL` host'u `*.railway.internal` = Railway iç
  ağı, bu kutudan DNS çözülmüyor). Mail yolu çalıştığı için kritik yolda **değil**.
- 🔴 **Tescil bekliyor:** `fis-listele`/`fis-indir` (DB yolu) hâlâ koşulmadı — o yol bloke.

## Negatif kapsam (neye DOKUNMAZ)
İki hesap dışındaki hiçbir posta kutusu · mail yazma fiilleri · eski prod'a yazma (§3 YASAK) ·
e-Fatura **kesme** (o `elogo-erisim`'in bölgesi; bu skill PDF'i getirir ve **DURUR**) ·
token değerini taşımak/basmak.
