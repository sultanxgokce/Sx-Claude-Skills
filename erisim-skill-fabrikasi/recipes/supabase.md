---
platform: supabase
confidence: high
verified: true
---

# supabase — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): supabase

## Özet

Erişim = Supabase Personal Access Token (PAT, sbp_...) → Management API'ye (https://api.supabase.com/v1) Bearer header'ıyla; resmi `supabase` CLI bunu SUPABASE_ACCESS_TOKEN env'inden native okur. PAT dashboard'da bir kez üretilir; deploy/edge-function/secrets/db/custom-domain işleri hem CLI hem saf curl ile tekrar dashboard'a girmeden yapılır.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

İki katı dürüstlük gerekli. (1) Standart kısıt: kullanıcı-adı+şifre→token API'si YOK — PAT yalnız dashboard'dan (2FA arkasında) üretilir. (2) Supabase'e ÖZGÜ kritik kısıt: PAT granüler SCOPE ALMAZ — kullanıcı hesabının TAM yetkisini taşır (resmi doküman birebir: "personal access tokens carry the same privileges as your user account"). Yani üretilen PAT = kullanıcının üye olduğu tüm org/projelerde god-mode; Cloudflare'daki gibi "geniş anahtardan dar token türet" YOK. DEVICE-FLOW da YOK — tek scoped/programatik alternatif ağır OAuth2 authorization_code akışı (aşağıda) ya da PAT'i yalnız hedef projeye erişimi olan/Developer(read-only)/Read-Only rollü ayrı bir Supabase hesabı altında üretmek. Şifreyle giriş, device-flow ya da "PAT'ten dar token türetme" SÖZÜ VERME.

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ hazır bir PAT yapıştırır (en az sürtünme). Yönerge: dashboard → Account → Access Tokens (https://supabase.com/dashboard/account/tokens) → "Generate new token" → ad ver (ör. "cortex-agent") → `sbp_...` değerini kopyala (SADECE bir kez gösterilir). Skill bunu gizli TTY/stdin ile okuyup ~/.config/cortex-access.env'e (600) SUPABASE_ACCESS_TOKEN olarak yazsın; asla argv/echo/log'a düşürmesin. Least-privilege notu: token, üretildiği hesabın erişebildiği org/projelerle sınırlıdır — hassas ortamda PAT'i dar-rollü/tek-proje hesabından ürettir.

## Token üretimi / alımı (token_mint)

PROGRAMATİK PAT ÜRETİMİ YOK — dashboard-only (resmi dokümanla DOĞRULANDI). Management API'de PAT oluşturan hiçbir /v1 endpoint'i bulunmuyor; PAT yalnız https://supabase.com/dashboard/account/tokens → "Generate new token" ile üretilir ve tek seferlik gösterilir. (Not: v1'deki "Create a warehouse token" AYRI bir analytics özelliğidir, hesap PAT'i DEĞİL.) Dolayısıyla "ana kimlikten dar-token türet" adımı Supabase'de UYGULANAMAZ. Tek scoped/kısa-ömürlü programatik yol = OAuth2 authorization_code akışı: önce dashboard'da Org → OAuth Apps → "Add application" ile bir OAuth App KAYIT ET (client_id/client_secret + scope seç), sonra kullanıcıyı GET https://api.supabase.com/v1/oauth/authorize'a yönlendir (PKCE önerilir), dönen code'u POST https://api.supabase.com/v1/oauth/token (grant_type=authorization_code, client_id/secret basic-auth header) ile access+refresh token'a çevir; refresh de aynı /v1/oauth/token ile. Bu üçüncü-taraf entegrasyon senaryosu için; tek-kullanıcı otomasyon skill'i için aşırı ağır → pratikte PAT (dashboard-only) kullan.

## Scope (least-privilege)

PAT: granüler scope YOK — hesabın tam yetkisi (üye olunan tüm org+proje). Least-privilege kaldıraçları PAT'in DIŞINDA: (a) org üye rolü — Owner(her şeye tam) / Administrator(org-ayarları+proje-transferi+yeni-owner HARİÇ tam) / Developer(org'a read-only + atanan projeye içerik erişimi, ayar değiştiremez) / Read-Only(org+proje read-only; Team+Enterprise); (b) proje-scoped roller (yalnız atanan projeler görünür). Skill'i dar tutmak istiyorsan PAT'i Developer/Read-Only rollü ya da yalnız hedef projeye üye bir hesaptan ürettir. OAuth2 rotasına gidilirse scope'lar kaynak-grubu bazında read ve/veya write olarak verilir; güncel gruplar: Auth(r/w), Database(r/w), Domains(r/w), Edge Functions(r/w), Environment(r/w), Organizations(YALNIZ read), Projects(r/w), Rest(r/w), Secrets(r/w), Storage(YALNIZ read) — tam liste: docs/guides/integrations/build-a-supabase-oauth-integration/oauth-scopes.

## 🚫 YASAK / sızıntı riskleri (forbidden)

Railway `variables --set` sızıntısının Supabase karşılıkları: (1) `supabase login --token sbp_...` → PAT argv'ye düşer → process-list/shell-history/transcript'e SIZAR → YASAK (--token flag'i gerçekten var, doğrulandı); bunun yerine `export SUPABASE_ACCESS_TOKEN=...` (CLI diğer komutlarda otomatik okur) ya da gizli stdin kullan. (2) CLI native-keyring yoksa token'ı `~/.supabase/access-token` dosyasına DÜZ METİN yazar (dokümanla doğrulandı) → buna güvenme; kaynak-of-truth cortex-access.env (600) olsun. (3) PAT = tam-hesap yetkisi → asla commit/echo/URL-query'ye koyma; sızarsa dashboard'dan o adlı token'ı revoke et. (4) AYRI ve TEHLİKELİ: proje `service_role` API key'i (data-plane, RLS'i BYPASS eder) — bu management PAT'i DEĞİL; onu da asla log'a/repo'ya/anon-yerine koyma. (5) PAT'i DB connection string / SUPABASE_DB_PASSWORD ile karıştırma.

## Doğrulama (doctor / verify)

CLI: `supabase projects list` (SUPABASE_ACCESS_TOKEN'ı okur; 200+liste = geçerli). Saf API: `curl -s -o /dev/null -w '%{http_code}' https://api.supabase.com/v1/organizations -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN"` → 200 = geçerli, 401 = geçersiz. Alternatif read: GET https://api.supabase.com/v1/projects.

## CLI aracı

supabase (resmi Supabase CLI; npm i -g supabase / brew install supabase/tap/supabase / scoop). Management API'yi tümüyle sarar; ek olarak saf API curl+jq ile de erişilebilir (curl+jq).

## Env değişkeni (cortex-access.env)

SUPABASE_ACCESS_TOKEN

## Adversaryal düzeltmeler

Kritik alanların (token_mint, honesty_constraint, forbidden, env_var, cli_tool, verify, OAuth endpoint'leri) HEPSİ resmi dokümanla doğrulandı ve DOĞRU çıktı — araştırmacı endpoint uydurmamış, dashboard-only'yi doğru saptamış; "carry the same privileges as your user account" birebir resmi ifade; `supabase login --token` flag'i ve düz-metin `~/.supabase/access-token` fallback'ı gerçek; device-flow gerçekten YOK (yalnız authorization_code + refresh_token). TEK düzeltme: OAuth scopes listesi bayattı — reçete "Analytics" grubunu saymış (güncel scope listesinde YOK) ve "Environment" ile "Storage"ı atlamıştı; ayrıca Organizations ve Storage'ın YALNIZ-read olduğu belirtilmemişti. Güncel liste düzeltildi: Auth/Database/Domains/Edge Functions/Environment/Projects/Rest/Secrets = read+write, Organizations + Storage = yalnız read. Honesty_constraint'e device-flow'un da olmadığı açıkça eklendi; token_mint'e warehouse-token'ın ayrı bir özellik olduğu ve OAuth app kaydının dashboard Org→OAuth Apps yolu netleştirildi.

## Kaynaklar

- https://supabase.com/docs/reference/api/introduction
- https://supabase.com/docs/reference/cli/supabase-login
- https://supabase.com/docs/guides/platform/access-control
- https://supabase.com/docs/guides/integrations/build-a-supabase-oauth-integration
- https://supabase.com/docs/guides/integrations/build-a-supabase-oauth-integration/oauth-scopes
- https://supabase.com/docs/guides/deployment/managing-environments
- https://supabase.com/dashboard/account/tokens
- https://supabase.com/docs/reference/api/v1-list-all-projects
- https://supabase.com/docs/reference/api/list-all-organizations
