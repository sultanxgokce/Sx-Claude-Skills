---
platform: digitalocean
confidence: high
verified: true
---

# digitalocean — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): digitalocean

## Özet

DigitalOcean erişimi = kullanıcının dashboard'da ÜRETTİĞİ dar-kapsamlı (custom-scoped) bir Personal Access Token (dop_v1_...) → cortex-access.env'e DIGITALOCEAN_ACCESS_TOKEN olarak yaz → doctl CLI (native env var okur) veya saf API (Bearer) ile deploy/DNS/droplet/app işlerini panele girmeden yap. Programatik token ÜRETME yoktur; skill verilen hazır token'ı saklar+kullanır.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre→token API'si YOK (dashboard login 2FA/CAPTCHA arkasında). Cloudflare'daki gibi "geniş bir ana anahtardan programatik dar token ÜRETME" YETENEĞİ DE YOK: DigitalOcean'ın public API'sinde token OLUŞTURAN bir endpoint yoktur (POST /v2/tokens dokümante DEĞİL; create-personal-access-token dokümanı yalnız Control Panel UI akışını anlatır). Personal Access Token (dop_v1_...) yalnız Control Panel'den (dashboard) üretilir. Tek programatik alternatif = OAuth uygulama akışı (doo_v1_ access + dor_v1_ refresh token'lar) ama DigitalOcean OAuth yalnız authorization-code + implicit grant destekler → KAYITLI bir OAuth app + client_id/client_secret + tarayıcı-redirect ister; DEVICE-FLOW YOK (doğrulandı: oauth dokümanında device authorization grant hiç geçmiyor) → "bir kez yapıştır" skill'i için fazla ağır. Bu yüzden kullanıcının BİR KEZ verdiği şey doğrudan hazır scoped token'ın kendisidir; skill token türetmez, verilen token'ı saklar+kullanır. Not: custom scope token OLUŞTUKTAN SONRA DÜZENLENEMEZ (kapsam değişikliği = yeni token). Nisan-2025 breaking change (DOĞRULANDI): eksik-kaynak-yetkilendirmesi düzeltmesi nedeniyle eski token'lar ek scope ile yeniden üretilmesi gerekebilir.

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ dashboard'da dar-yetkili bir Personal Access Token üretip yapıştırır (least-privilege, en az sürtünme). Adım: Control Panel (cloud.digitalocean.com) → sol menüde API (Tokens/Keys) → "Generate New Token" → İsim ver + Expiration seç (ör. 90 gün) + "Custom Scopes" ile SADECE gerekli scope'ları işaretle (bkz scopes) → dop_v1_... değerini kopyala (yalnız bir kez gösterilir). Sonra terminalde gizli-giriş: `doctl auth init` (token'ı MASKELİ/gizli prompt ile ister — kaynak: auth.go input.WithHidden — argv'ye düşmez) VEYA skill değeri okuyup ~/.config/cortex-access.env'e (600) DIGITALOCEAN_ACCESS_TOKEN olarak yazar. Şifre/e-posta İSTEME; sadece hazır token.

## Token üretimi / alımı (token_mint)

dashboard-only — programatik token üretilemez (public API'de token-create endpoint'i YOK; POST /v2/tokens dokümante değil, DOĞRULANDI). Adımlar: (1) cloud.digitalocean.com → sol menü API → Tokens sekmesi; (2) "Generate New Token"; (3) Name + Expiration (ör. 90 gün); (4) "Custom Scopes" seç → resource:action scope'larını işaretle (bulk/CRUD toplu seçim mevcut); (5) Generate → dop_v1_ ile başlayan değeri KOPYALA (tekrar gösterilmez). Kapsam sonradan düzenlenemez → değişiklik gerekince yeni token üret, eskisini sil. (İleri seviye/opsiyonel: OAuth app kaydı ile doo_v1_ token authorization-code/implicit akışıyla alınabilir, ama client_secret+redirect gerektirir, device-flow YOK → skill için önerilmez.)

## Scope (least-privilege)

Format: resource:action (DOĞRULANDI). Least-privilege örnekleri — DNS/domain işleri: domain:read, domain:create, domain:update, domain:delete (ör. sadece DNS kaydı ekleme ≈ domain:create + domain:read). Droplet/sunucu yönetimi: droplet:read/create/update/delete. App Platform deploy: app:read, app:create, app:update. Env config genelde app:update (App Platform) ya da ilgili resource:update. HER token'a account:read EKLE — whoami/doğrulama çağrısı GET /v2/account (ve `doctl account get`) bunu gerektirir; yoksa 403 döner. (DÜZELTME: `doctl auth init`'in KENDİSİ güncel doctl'de token'ı OAuth token-info introspection ile doğrular [auth.go: OAuth().TokenInfo], /v2/account ile DEĞİL → account:read OLMADAN da auth init geçebilir; ama gerçek hesap/whoami komutları account:read ister → yine de her token'a ekle.) Kısayol alias'lar: api:read (tüm-okuma read-only), api:write (TAM erişim = tüm scope'lar; yeni endpoint'ler eklendikçe OTOMATİK genişler → yalnız gerçekten gerekliyse). Kaçınılması gereken: gereksiz yere api:write vermek.

## 🚫 YASAK / sızıntı riskleri (forbidden)

argv/process-list sızıntısı (Railway `variables --set` muadili): (1) `doctl ... --access-token <deger>` veya `-t <deger>` bayrağı YASAK (ikisi de geçerli global bayrak, DOĞRULANDI) — token argv'ye düşer, `ps`/transkript/shell-history'e sızar; bunun yerine `doctl auth init` (maskeli gizli prompt) veya DIGITALOCEAN_ACCESS_TOKEN env var kullan. (2) curl'de `-H "Authorization: Bearer dop_v1_LITERAL"` YAZMA — literal token komut satırına ve geçmişe düşer; hep `-H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN"` değişken-genişletmesiyle kullan (yine de anlık /proc/<pid>/cmdline'da görünebilir → mümkünse doctl'i tercih et). (3) Token değerini asla stdout/echo/log/chat'e basma. (4) ~/.config/doctl/config.yaml token'ı PLAINTEXT saklar (DOĞRULANDI: doctl issue #378) → repoya/CloudBridge'e/git'e commit'leme, yedek-dışına çıkarma. (5) Token'ı ekran görüntüsü/paste-history'de bırakma; üretimden sonra dashboard'da bir daha görünmez, sızarsa hemen revoke.

## Doğrulama (doctor / verify)

Ucuz whoami (account:read gerektirir): `curl -sf -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" https://api.digitalocean.com/v2/account` → 200 + JSON account (email, uuid, status) = geçerli; 401 = geçersiz/eksik token; 403 = token'da account:read yok. CLI eşdeğeri: `doctl account get` (env var'ı otomatik okur). Rate-limit header'ları (RateLimit-Remaining / RateLimit-Limit / RateLimit-Reset) da yanıtta gelir.

## CLI aracı

doctl (resmi DigitalOcean CLI). Native env var: DIGITALOCEAN_ACCESS_TOKEN. Auth: `doctl auth init` (maskeli gizli prompt) → ~/.config/doctl/config.yaml (Linux/XDG, PLAINTEXT). --access-token/-t bayrağı yalnız default context'te dikkate alınır. Alternatif: saf API curl+jq (Bearer header).

## Env değişkeni (cortex-access.env)

DIGITALOCEAN_ACCESS_TOKEN

## Adversaryal düzeltmeler

Reçete büyük ölçüde DOĞRU ve güncel; tüm ana iddialar resmi dokümanla doğrulandı: token_mint dashboard-only (POST /v2/tokens YOK) ✓, OAuth device-flow YOK / yalnız authorization-code+implicit + kayıtlı app+client_secret+redirect ✓, dop_v1_/doo_v1_/dor_v1_ prefiksleri ✓, Nisan-2025 breaking change ✓, scope resource:action + api:read/api:write auto-expand ✓, --access-token/-t argv sızıntısı ✓, doctl auth init maskeli prompt (input.WithHidden) ✓, config.yaml plaintext (issue #378) ✓, env_var DIGITALOCEAN_ACCESS_TOKEN + cli doctl ✓, verify /v2/account + RateLimit header'ları ✓. TEK DÜZELTME (scopes alanı): 'doctl auth init account:read gerektirir' iddiası güncel doctl (main) için yanlıştı — auth init token'ı OAuth token-info introspection (OAuth().TokenInfo) ile doğruluyor, Account().Get()/v2/account ile DEĞİL; dolayısıyla account:read olmadan da auth init geçebilir. account:read asıl olarak GET /v2/account whoami / `doctl account get` doğrulaması için gerekli (403 riski); 'her token'a account:read ekle' önerisi geçerli kaldı, sadece gerekçe düzeltildi. Ayrıca credential_intake'te dashboard navigasyonu 'sağ-üst hesap menüsü' yerine 'sol menü API' olarak netleştirildi.

## Kaynaklar

- https://docs.digitalocean.com/reference/api/create-personal-access-token/
- https://docs.digitalocean.com/reference/api/scopes/
- https://docs.digitalocean.com/reference/api/oauth/
- https://www.digitalocean.com/blog/updated-api-tokens-new-management-features
- https://docs.digitalocean.com/reference/doctl/reference/auth/init/
- https://github.com/digitalocean/doctl/blob/main/commands/auth.go
- https://github.com/digitalocean/doctl/issues/378
- https://docs.digitalocean.com/reference/api/reference/account/index.html.md
