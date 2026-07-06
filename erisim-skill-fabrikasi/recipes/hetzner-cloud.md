---
platform: hetzner-cloud
confidence: high
verified: true
---

# hetzner-cloud — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): hetzner-cloud

## Özet

Hetzner Cloud'da erişim = Cloud Console'da PROJE-BAZLI insan eliyle üretilen bir API token'ı (Bearer); `hcloud` CLI ya da `Authorization: Bearer` ile api.hetzner.cloud/v1 çağrılır. Token yalnızca Console'da üretilir, Cloud API'de programatik token-mint yoktur.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre → token API'si YOK; device-flow/OAuth YOK. Hesap girişi (accounts.hetzner.com) 2FA/CAPTCHA arkasında ayrı bir dünya; Cloud Console (console.hetzner.cloud) ondan ayrı bir web app. API token'ı SADECE Console'dan (Security → API Tokens → Generate API token) insan eliyle bir kez üretilir ve token tam bir kez gösterilir (pencere kapanınca bir daha görülemez — resmi doküman). İkinci kritik kısıt: scope granülaritesi YOK — sadece iki seviye var: "Read" (yalnız GET) veya "Read & Write" (GET/POST/PUT/DELETE = projedeki HER ŞEYİ silebilir dahil). Kaynak-bazlı/servis-bazlı dar scope mümkün değil. Üçüncüsü: token PROJE'ye bağlıdır, hesaba değil — her proje için ayrı token gerekir ve token o projenin tamamına hükmeder. Ayrıca dikkat: "Hetzner Cloud" (sunucu/network/volume/firewall/LB) ile "Hetzner DNS" (dns.hetzner.com, ayrı `Auth-API-Token` header'ı) ve "Hetzner Robot" (dedicated sunucu, Basic-auth webservice user) TAMAMEN AYRI auth yüzeyleridir; bu reçete Cloud içindir. cloudtop host'u (cx53) bu API ile yönetiliyor.

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ hazır token yapıştırır (OAuth/device-flow yok). Adımlar: console.hetzner.cloud → ilgili projeyi seç → Security → API Tokens → "Generate API Token" → ad/açıklama ver → izin seç (Read | Read & Write) → üret → token'ı kopyala (bir daha gösterilmez). En az sürtünme + en iyi izolasyon için: otomasyon işleri için AYRI bir Hetzner projesi açıp token'ı O projeye bağlamak (blast-radius'u o projeyle sınırlar). Skill token'ı stdin/gizli-prompt ile alıp cortex-access.env'e (chmod 600) yazmalı; asla argv/echo/transcript'e düşürmeden.

## Token üretimi / alımı (token_mint)

dashboard-only. Cloud API'nin kendisinde (api.hetzner.cloud/v1) token oluşturma/yönetme endpoint'i YOKTUR — mevcut bir token'la yeni token üretilemez; resmi doküman yalnızca Console akışını (Security → API Tokens → Generate) tarif eder. (İstisna, bu senaryoya UYMAZ: hetznercloud/tps-action — TPS = "Temporary Project Service" [reçetenin "Token Provider Service" ifadesi YANLIŞTI, düzeltildi] — GitHub Actions OIDC federasyonuyla CI-run başına geçici PROJE + token üretir; ama repo kendisi "bu resmi bir Hetzner Cloud entegrasyonu DEĞİLDİR" der, Hetzner tarafında OIDC güven + `id-token: write` gerektirir, CI-only'dir, "kullanıcı bir kez credential verir" akışına uygulanamaz.) Dolayısıyla skill için: geniş kimlikten dar token programatik ÜRETİLEMEZ; insan panelden üretip yapıştırır.

## Scope (least-privilege)

İki seviye var, ikisi de proje-geneli: "Read" (yalnız GET — envanter/durum okuma işleri) ve "Read & Write" (GET+POST+PUT+DELETE — sunucu oluştur/resize/reboot/sil, firewall, network, volume, LB). Least-privilege pratiği: yalnız okuyacaksan Read; değiştirecek işler için Read & Write ama otomasyonu KENDİ projesine izole et (kaynak-bazlı kısıtlama olmadığı için projeyi sınır olarak kullan). Kaynak/servis-bazlı ince scope mevcut değildir (resmi doküman ile doğrulandı).

## 🚫 YASAK / sızıntı riskleri (forbidden)

1) Token'ı argv'ye koyma → process-list/`ps`/shell-history/transkript sızıntısı. hcloud zaten token'ı komut-başına flag ile ALMAZ (issue #808: "does not allow to pass the token per command") → token'ı HCLOUD_TOKEN env-var'ından ya da `hcloud context create`'in GİZLİ prompt'undan ver. 2) curl'de literal token gömme YOK → `-H "Authorization: Bearer $HCLOUD_TOKEN"` (env'den). 3) `echo $HCLOUD_TOKEN`/loglama YOK. 4) hcloud token'ı ~/.config/hcloud/cli.toml'a DÜZ METİN yazar (herhangi bir süreç okuyabilir; pinned issue #808 bunu güvenlik zaafı sayar) → dosyayı chmod 600 tut, git'e ASLA commit'leme, paylaşılan/çok-kullanıcılı kabuklarda context yerine env-var tercih et. 5) Terraform kullanılıyorsa token'ı .tf dosyasına yazma → TF_VAR_hcloud_token / env. 6) Read & Write token = projedeki her sunucuyu silebilir; yüksek-değerli sır gibi davran, gereksiz yere Read&Write üretme, otomasyonu ayrı projede izole et.

## Doğrulama (doctor / verify)

Ucuz read: `hcloud server list` (context/HCLOUD_TOKEN ayarlıysa) VEYA saf API: `curl -sf -H "Authorization: Bearer $HCLOUD_TOKEN" 'https://api.hetzner.cloud/v1/servers?per_page=1'` (200 + JSON = geçerli; 401 unauthorized = geçersiz). Adanmış whoami endpoint'i yoktur; `/v1/servers` ya da daha da hafif `/v1/ssh_keys` doğrulama için kullanılır. Bonus: yanıt header'ları `RateLimit-Limit: 3600` + `RateLimit-Remaining` (+ `RateLimit-Reset` UNIX ts) kotayı gösterir (proje başına 3600 istek/saat; aşımda 429 Too Many Requests).

## CLI aracı

hcloud (resmi — github.com/hetznercloud/cli; brew install hcloud / apt / binary). Kurulum: `hcloud context create <ad>` → gizli prompt'a token yapıştır (→ ~/.config/hcloud/cli.toml). Alternatif: HCLOUD_TOKEN env-var. Saf API de mümkün (Bearer + api.hetzner.cloud/v1).

## Env değişkeni (cortex-access.env)

HCLOUD_TOKEN

## Adversaryal düzeltmeler

1 düzeltme: token_mint içindeki tps-action açılımı "Token Provider Service" YANLIŞTI → resmi repo'ya göre TPS = "Temporary Project Service" (düzeltildi); ayrıca repo'nun kendini açıkça "resmi Hetzner entegrasyonu DEĞİL" ilan ettiği vurgulandı. Geri kalan tüm alanlar resmi dokümana karşı doğrulandı ve DEĞİŞMEDİ: (a) token_mint dashboard-only doğru — araştırmacı endpoint UYDURMADI, Cloud API'de token-create endpoint'i gerçekten yok; (b) honesty_constraint doğru — şifre→token API'si ve device-flow gerçekten yok, token bir kez gösteriliyor, iki-seviye scope, proje-bazlı; (c) forbidden gerçek — issue #808 (pinned/open) cli.toml düz-metin + komut-başına token geçilemediğini teyit ediyor, argv/log sızıntı riski geçerli; (d) env_var HCLOUD_TOKEN ve cli_tool hcloud resmi. Ek teyitler: base URL api.hetzner.cloud/v1, Authorization: Bearer, rate-limit 3600/saat + RateLimit-* header'ları + 429, whoami yok (/v1/servers|/v1/ssh_keys).

## Kaynaklar

- https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/
- https://docs.hetzner.com/cloud/api/getting-started/using-api/
- https://docs.hetzner.cloud/reference/cloud
- https://github.com/hetznercloud/cli
- https://github.com/hetznercloud/cli/blob/main/docs/tutorials/setup-hcloud-cli.md
- https://github.com/hetznercloud/cli/issues/808
- https://github.com/hetznercloud/tps-action
- https://community.hetzner.com/tutorials/howto-hcloud-cli/
