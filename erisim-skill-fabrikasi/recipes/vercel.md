---
platform: vercel
confidence: high
verified: true
---

# vercel — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): vercel

## Özet

Kullanıcı vercel.com/account/tokens'tan BİR KEZ (team + kısa expiration ile) bir Access Token üretip yapıştırır; skill onu VERCEL_TOKEN env'ine koyar ve resmi `vercel` CLI ile (token'ı argv'ye koymadan) deploy/env/dns/API işlerini yapar. Kimlik doğrulama tek biçim: `Authorization: Bearer <token>`. Daha dar kapsam gerekiyorsa token'ı `vercel tokens add "ad" --project prj_id` ile programatik olarak tek-projeye daraltır.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Vercel'de kullanıcı-adı+şifre→token API'si YOKTUR ve kişisel token için OAuth device-flow YOKTUR (OAuth yalnızca 'Sign in with Vercel' / entegrasyon uygulaması içindir; `vercel login` tarayıcı-tabanlı authorization-code akışıdır, token basmaz). Token almanın yolu: kullanıcının dashboard'da bir Access Token üretmesi VEYA elindeki hesap-düzeyli KLASİK PAT'tan yeni token türetmesidir. Kapsamda GERÇEK kısıt şudur: EYLEM-BAZLI (read-only vs write) fine-grained scope Vercel'de HİÇBİR YERDE (dashboard dahil) YOKTUR — token, üreten kimliğin izinlerini team/proje kapsamı içinde tam miras alır. AMA 'programatik daraltma imkânsız / SADECE dashboard' iddiası YANLIŞTIR: tek-PROJE daraltma CLI ile programatik yapılır (`vercel tokens add "ad" --project prj_...` → CLI bu değeri doğrudan API'ye iletir), team bağlamı ise API'de `?teamId=`/`?slug=` query'si ile verilir. `POST /v3/user/tokens` istek GÖVDESİ gerçekten yalnız `name`+`expiresAt` alır (proje/team gövdede değil; query veya CLI --project ile).

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ dashboard'da hazır bir Access Token üretip yapıştırır (en az sürtünme + least-privilege): vercel.com/account/tokens → Create Token → (1) açıklayıcı ad, (2) SCOPE = ilgili Team'i seç (hesabın tamamı değil), (3) Expiration ver (ör. 90 gün). 'Create Token' sonrası bearerToken YALNIZCA bir kez gösterilir → hemen kopyalatıp cortex-access.env'e (600) yaz. OAuth/parola sorma; sadece bu tek token'ı iste. NOT: Daha sıkı tek-proje kapsamı isteniyorsa, kullanıcının verdiği hesap-düzeyli klasik token'dan skill sonradan `vercel tokens add "cortex-ajan" --project prj_id` ile daha dar bir token da mint edebilir.

## Token üretimi / alımı (token_mint)

EVET (küçük bir kısıtla). Programatik minting mümkün. API: `POST https://api.vercel.com/v3/user/tokens`, gövde `{"name":"cortex-ajan","expiresAt":<ms-epoch>}` (gövde YALNIZ name+expiresAt), opsiyonel `?teamId=<id>` / `?slug=<team-slug>` query = team bağlamı. Yanıt `bearerToken` (yalnız bir kez) + `token.id`. CLI eşdeğeri: `vercel tokens add "cortex-ajan"` (plaintext stdout'a basılır). Tek-PROJE'ye daraltma PROGRAMATİK MÜMKÜN: `vercel tokens add "cortex-ajan" --project prj_abc123` (CLI --project'i doğrudan API'ye iletir, blast-radius'u düşürür). KRİTİK ÖN-KOŞUL (resmi, verbatim): bu komut hesap-düzeyli KLASİK personal access token gerektirir — `vercel login` ile açılan OAuth oturumları ve team-only/project-only token'lar (bazı `vcp_…` değerleri) yeni token MINT EDEMEZ/REDDEDİLİR; yoksa önce dashboard'dan klasik token üret, VERCEL_TOKEN'a koy, komutu tekrar çalıştır. Var-olmayan TEK şey: eylem-bazlı read/write fine-grained scope (hiçbir arayüzde yok, dashboard dahil).

## Scope (least-privilege)

Vercel'de eylem-bazlı (read/write) scope toggle'ı HİÇ YOKTUR. Least-privilege kaldıraçları: (1) tek TEAM bağlamı (dashboard 'Scope' seçimi ya da API `?teamId=`/`?slug=`); (2) tek PROJE'ye daraltma — `vercel tokens add "ad" --project prj_id` (programatik, sızıntı-yarıçapını azaltır); (3) her zaman EXPIRATION ver (süresiz token verme). Kanonik seçim: 'ilgili team + mümkünse tek proje + kısa expiration'. PREFIX'LER (resmi 'new token formats' changelog): `vcp_` = personal access token (STANDART PAT; kendisi account/team/proje-kapsamlı olabilir), `vca_` = app access token (OAuth uygulaması), `vci_` = integration token, `vcr_` = app refresh token, `vck_` = API key. DİKKAT: prefix ≠ kapsam; `vcp_` hem geniş hem dar olabilir (recipe'in eski `vca_=account, vcp_=project` haritası YANLIŞTI).

## 🚫 YASAK / sızıntı riskleri (forbidden)

(1) `--token`/`-t` bayrağını gündelik kullanma: `vercel deploy --token vcp_xxx` → resmi doküman uyarısı 'command-line arguments... visible in process lists and logs'. Yerine `export VERCEL_TOKEN=...` (CLI native okur; CI için resmi öneri). (2) Sır değerini verirken `echo "literal-secret" | vercel env add ...` KULLANMA — Vercel'in KENDİ dokümanı 'this will save the value in bash history, so this is not recommend for secrets' diye açıkça uyarır. DOĞRUsu: dosya-yönlendirme `vercel env add NAME production < gizli-dosya` ya da değişkenden `printf '%s' "$VALUE" | vercel env add NAME production` (komut satırına düz-metin sır yazma). NOT: `vercel env add` değeri ZATEN positional argüman olarak almaz (positional'lar name/environment/gitbranch) — değer daima stdin/interaktiftir; yani 'değeri argümana koyma' uyarısının kapsamı esasen `echo` kaynaklı history sızıntısıdır. (3) Token'ı source-control'e giren .env'e yazma; cortex-access.env dışına koyma, izin 600. (4) bearerToken yalnız bir kez döner — log'a/transkripte basma, echo'lama. (5) Unlinked dizinde `vercel link`/`vercel project inspect` çalıştırma → interaktif prompt veya sessiz proje-link yan-etkisi; otomasyonda `--non-interactive` + `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` kullan. (6) Geniş account-kapsamlı token'ı gündelik kullanma — team/proje-kapsamlı üret.

## Doğrulama (doctor / verify)

CLI: `vercel whoami` (kimliği/kullanıcı adını döner). Saf API: `curl -s -H "Authorization: Bearer $VERCEL_TOKEN" https://api.vercel.com/v2/user | jq .user.username` (200 + kullanıcı = geçerli). Team erişimini doğrulamak için ucuz read: `curl -s -H "Authorization: Bearer $VERCEL_TOKEN" https://api.vercel.com/v2/teams | jq '.teams[].slug'`. Token listesini/kapsamını görmek için: `vercel tokens ls --format json`.

## CLI aracı

vercel (resmi CLI; `npm i -g vercel`). VERCEL_TOKEN env'ini native okur (global-options doku ile doğrulandı), --token'a gerek yok; team için `--scope <slug>` (-S) veya `--team` (-T), proje için `--project <id>` global option'ları var. Alternatif: none (saf API curl+jq, base https://api.vercel.com, Bearer header) — token/env/dns dahil her şey REST ile de yapılabilir.

## Env değişkeni (cortex-access.env)

VERCEL_TOKEN

## Adversaryal düzeltmeler

3 önemli düzeltme yapıldı. (a) token_mint + honesty_constraint: 'kapsam programatik daraltılamaz / SADECE dashboard' iddiası YANLIŞTI — tek-proje daraltma CLI ile programatik yapılıyor (`vercel tokens add "ad" --project prj_id`; CLI bu değeri doğrudan API'ye iletiyor, resmi cli/tokens dokusunda 'forwards this value directly to the API'). GERÇEK kısıt: eylem-bazlı read/write fine-grained scope'un HİÇBİR YERDE olmaması (bu doğru şekilde vurgulandı). (b) PREFIX haritası ters/yanlıştı: resmi 'new token formats' changelog'una göre `vcp_` = personal access token (recipe'in dediği gibi 'project-scoped' DEĞİL, standart PAT), `vca_` = OAuth app access token (recipe'in dediği 'account/team-scoped' DEĞİL). Düzeltildi + vci_/vcr_/vck_ eklendi. (c) forbidden env-add: recipe'in 'güvenli' önerdiği `echo value | vercel env add` formunu Vercel'in KENDİ env dokusu 'saves value in bash history, not recommend for secrets' diye uyarıyor → dosya-yönlendirme `< dosya` veya `printf '%s' "$VAR" |` doğrusu; ayrıca env add değeri zaten positional argüman olarak ALMAZ. DOĞRULANANLAR (değişmedi): POST /v3/user/tokens gövdesi yalnız name+expiresAt + ?teamId/?slug query; `vercel tokens add` mevcut ve klasik-PAT-gerektirir/OAuth-team-only-project-only-reddedilir caveat'ı verbatim; `--token` argv sızıntısı ('visible in process lists and logs') resmi uyarı; VERCEL_TOKEN native okuma; `--scope`(-S)/`--team`(-T) global option; `vercel whoami` + /v2/user + /v2/teams verify; şifre→token API yokluğu ve kişisel-token OAuth device-flow yokluğu doğru.

## Kaynaklar

- https://vercel.com/docs/rest-api/authentication/create-an-auth-token
- https://vercel.com/docs/cli/tokens
- https://vercel.com/docs/cli/env
- https://vercel.com/docs/cli/global-options
- https://vercel.com/changelog/new-token-formats-and-secret-scanning
- https://vercel.com/kb/guide/how-do-i-use-a-vercel-api-access-token
- https://github.com/vercel-labs/agent-skills/blob/main/skills/vercel-cli-with-tokens/SKILL.md
