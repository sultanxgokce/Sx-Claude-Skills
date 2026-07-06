---
platform: github
confidence: high
verified: true
---

# github — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): github

## Özet

GitHub'da programatik erişim, kullanıcının bir kez verdiği fine-grained PAT (yalnız web dashboard'da üretilir) ya da `gh auth login` OAuth device-flow token'ı ile kurulur; gerçekten scoped+kısa-ömürlü token PROGRAMATİK üretmenin TEK yolu önceden kurulmuş bir GitHub App'in installation-token endpoint'idir (POST /app/installations/{id}/access_tokens).

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre → token API'si YOKTUR: temel-kimlik (Basic auth, şifreyle API) 2020-11-13'te kaldırıldı ve giriş 2FA/passkey/CAPTCHA arkasında olduğundan otomatize edilemez. Fine-grained ve classic PAT'leri PROGRAMATİK üreten API de aynı tarihte SUNSET edildi (eski OAuth Authorizations API `POST /authorizations` artık yok → 404/410) → bir PAT yalnızca web dashboard'ında elle üretilir. (Not: `/orgs/.../personal-access-tokens` REST endpoint'i VARDIR ama sadece org'un fine-grained PAT *isteklerini* onaylaması/iptali içindir, YENİ token ÜRETMEZ.) OAuth "device flow" ile kullanıcı-token'ı alınabilir ama bir OAuth/GitHub-App client_id gerektirir ve app'te device-flow'un etkin olması gerekir; `gh` CLI kendi gömülü client_id'sini (device-flow etkin) taşıdığı için app kaydı OLMADAN bunu sağlayan tek pratik yol odur. Genişten-dara "child token mint" yeteneği YALNIZCA bir GitHub App kurulmuşsa vardır (installation access token). App yoksa dürüst cevap: token üretimi dashboard-only, skill sadece hazır token'ı devralıp kullanır.

## Credential intake (kullanıcı BİR KEZ)

En az sürtünmeli, least-privilege iki yol (kullanıcı BİR KEZ yapar): (A) `gh auth login` → "Login with a web browser" seç → gh device-flow bir kod verir, kullanıcı github.com/login/device'a girip onaylar; token gh'nin sistem-keychain'ine yazılır (app kaydı gerekmez, gh'nin gömülü client_id'si kullanılır). (B) Dashboard'da fine-grained PAT üret (yalnız hedef repo + gereken permission'lar, kısa expiry) → gizli olarak yapıştır: `gh auth login --with-token < token.txt` (—with-token stdin'den okur) VEYA env dosyasına STDIN ile yaz. Önerilen = (B) fine-grained PAT çünkü scope'u repo+permission bazında daraltılabilir; (A) daha az sürtünmeli ama gh OAuth app'inin geniş scope'unu alır.

## Token üretimi / alımı (token_mint)

PAT için PROGRAMATİK ÜRETİM YOK → dashboard-only. Adımlar: github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token → Resource owner + Repository access (yalnız gerekli repolar) + Permissions seç + Expiration ver → Generate token → değeri BİR KEZ kopyala. TEK programatik scoped+kısa-ömürlü token yolu = GitHub App installation token: App'in private key'i (.pem) ile RS256 JWT imzala [iss = App ID VEYA (GitHub'ın güncel önerisi) Client ID; iat = şimdi−60sn (saat-kayması payı); exp ≤ şimdi+10dk] → `POST https://api.github.com/app/installations/{installation_id}/access_tokens` (Authorization: Bearer <JWT>); gövdede opsiyonel `repositories`/`repository_ids` (≤500) ve `permissions` alanlarıyla token AŞAĞI-DARALT (down-scope). Dönen token 1 saat geçerlidir. Bu yol yalnızca önceden bir GitHub App kurulup hedef repolara install edildiyse çalışır (installation_id: `GET /app/installations` veya `GET /repos/{owner}/{repo}/installation` ile bulunur).

## Scope (least-privilege)

Fine-grained permission adları ve seviyeleri (read/write) repo/org/account eksenlerinde tanımlı; en dar = fine-grained token, yalnız dokunulan repolar (Repository access → Only select repositories), minimum permission, kısa expiry. GitHub App yolunda `permissions` gövde alanıyla installation-token'ı App'in sahip olduğu izinlerin ALTINA daralt.

## 🚫 YASAK / sızıntı riskleri (forbidden)

SIR-SIZINTI ANTI-PATTERNLERİ: (1) `gh secret set NAME --body <deger>` → değer argv/process-list (`ps`) ve shell history'ye sızar (Railway `--set` sorununun birebir GitHub analoğu) → YASAK; yerine STDIN kullan: `printf %s "$v" | gh secret set NAME` (—body verilmezse stdin'den okur) VEYA `gh secret set NAME < token.txt`. ⚠️ DÜZELTME: `gh secret set`'te `--body-file` DİYE BİR BAYRAK YOKTUR (yalnızca çoklu-secret .env için `--env-file` var) → tekil değer için düz stdin/pipe kullan. (2) Token'ı git remote URL'ine gömme (`https://TOKEN@github.com/...`) → `.git/config` plaintext + `git remote -v` + process-list'e sızar; gh credential-helper ya da SSH kullan. (3) `GH_TOKEN=... komut` inline env / token'ı echo etme / CI log'una basma → transkript+log sızıntısı. (4) `...?access_token=TOKEN` query-param → sunucu erişim-log'una sızar; DAİMA `Authorization: Bearer` header. (5) GitHub App private key (.pem) veya PAT'i repoya commit'leme; long-lived classic PAT yerine fine-grained + kısa expiry tercih et. Token yalnız cortex-access.env (chmod 600) içinde dursun, stdout/chat/geçmişe düşmesin.

## Doğrulama (doctor / verify)

CLI: `gh auth status` (hangi hesap + scope) veya `gh api user --jq .login`. Saf API: `curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/user`. Classic PAT'te scope'lar response header'ında: `curl -sI -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user` → `x-oauth-scopes:` satırı. Hepsi ucuz, rate-limit dostu read.

## CLI aracı

gh (GitHub CLI) — resmi. Alternatif saf API: curl + jq (GitHub App installation-token JWT akışı için gerekli).

## Env değişkeni (cortex-access.env)

GITHUB_TOKEN (gh CLI hem GITHUB_TOKEN hem GH_TOKEN okur; cortex-access.env konvansiyonu = GITHUB_TOKEN. Not: github.com için İKİSİ birden set edilirse GH_TOKEN önceliklidir — tek değişken tutulduğunda çakışma olmaz. GitHub App yolu için ek: GITHUB_APP_ID + GITHUB_APP_PRIVATE_KEY + GITHUB_APP_INSTALLATION_ID; App JWT'sinde iss için Client ID önerildiğinden opsiyonel GITHUB_APP_CLIENT_ID)

## Adversaryal düzeltmeler

3 düzeltme yapıldı, teknik çekirdek doğrulandı (endpoint UYDURMA DEĞİL): (1) `gh secret set --body-file -` GEÇERSİZ — bu bayrak yok; doğru stdin biçimleri `printf %s "$v" | gh secret set NAME` veya `gh secret set NAME < token.txt` (çoklu-secret için ayrıca `--env-file` var, tekil için değil). (2) GitHub App JWT `iss` artık Client ID öneriliyor (App ID hâlâ geçerli) + iat = şimdi−60sn (saat kayması payı) netleştirildi. (3) env_var: github.com'da ikisi set edilirse GH_TOKEN'ın GITHUB_TOKEN'a önceliği notu eklendi. Ek doğrulama: installation-token endpoint/1-saat/down-scope, device-flow client_id şartı, Basic-auth ve OAuth Authorizations API'nin 2020-11-13 kaldırılması resmi dokümanla teyit edildi.

## Kaynaklar

- https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app
- https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app
- https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
- https://github.blog/changelog/2020-11-13-token-authentication-required-for-api-operations/
- https://docs.github.com/en/rest/orgs/personal-access-tokens
- https://cli.github.com/manual/gh_secret_set
- https://cli.github.com/manual/gh_help_environment
- https://cli.github.com/manual/gh_auth_login
- https://cli.github.com/manual/gh_auth_status
- https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api
- https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
