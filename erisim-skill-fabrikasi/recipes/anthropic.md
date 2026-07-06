---
platform: anthropic
confidence: high
verified: true
---

# anthropic — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): anthropic

## Özet

Anthropic platformunda erişim = Console'da üretilen workspace-scoped API key (sk-ant-api03-…) YA DA `ant auth login` OAuth profili; her ikisini de `ant` CLI ve tüm resmi SDK'lar otomatik okur, işler /v1/messages (inference) ve /v1/organizations/* (Admin API) uçlarıyla panele girmeden yapılır. Dar-yetkili kısa-ömürlü token gerekiyorsa Workload Identity Federation ile OIDC JWT → sk-ant-oat01 access-token takası (programatik).

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre→token API'si YOKTUR. Inference API key'leri YALNIZCA Console'dan (dashboard) üretilir — Admin API bile API key ÜRETEMEZ (resmi FAQ, doğrulandı: "new API keys can only be created through the Claude Console for security reasons; the Admin API can only manage existing API keys"). İlk kimlik ya panelden bir kez kopyalanır ya da tarayıcı-tabanlı `ant auth login` (OAuth authorization-code; headless makinede `--no-browser` = URL bas + kodu terminale al) ile alınır — her iki durumda da bir insan bir kez etkileşir. İKİNCİ kısıt: Admin API + org/workspace/WIF yönetimi bir ORGANİZASYON gerektirir (bireysel hesaplarda kapalı) ve yalnız admin/owner rolüyle kullanılır. ÜÇÜNCÜ kısıt: bu bir LLM-API platformudur; DNS / sunucu yönetimi YOKTUR. Buradaki "işler" = model çağrıları (/v1/messages), org/workspace/üye yönetimi (Admin API), Managed Agents (agent/session/environment), Files/Skills. Olmayan bir "deploy/DNS" yeteneği vaat etme.

## Credential intake (kullanıcı BİR KEZ)

En az sürtünme + least-privilege: kullanıcı Console'da (platform.claude.com → Settings → API keys) HEDEF workspace'e scoped bir key (`sk-ant-api03-…`) üretip BİR KEZ yapıştırır → cortex-access.env'e ANTHROPIC_API_KEY=… (chmod 600) olarak yazılır; bir daha sorulmaz. Statik sır istemiyorsa/tarayıcısı olan makinede daha az sürtünmeli alternatif: `ant auth login` (tarayıcı OAuth; headless için `ant auth login --no-browser`) → profil ~/.config/anthropic/'e yazılır, hem `ant` hem SDK'lar (bare `Anthropic()`) otomatik okur, env var GEREKMEZ. Org-yönetimi gerekiyorsa ayrıca Admin key (Console → Settings → Admin keys, `sk-ant-admin…`, yalnız admin-rollü üye üretebilir) ya da `org:admin` scope'lu OAuth token.

## Token üretimi / alımı (token_mint)

HAYIR — skill inference API key'ini PROGRAMATİK üretemez (dashboard-only: Console → Settings → API keys → Create Key → workspace seç → değeri bir kez göster). Admin API'de create-key endpoint'i YOKTUR; yalnızca listele `GET /v1/organizations/api_keys`, tekil-getir `GET /v1/organizations/api_keys/{id}` ve güncelle (status/name) `POST /v1/organizations/api_keys/{id}` vardır. PROGRAMATİK olarak ÜRETİLEBİLENLER: (a) key'i izole etmek için yeni workspace — `POST /v1/organizations/workspaces` (Admin key VEYA org:admin OAuth token); (b) DAR-YETKİLİ KISA-ÖMÜRLÜ token için tam WIF kurulumu — bu uçlarda Admin API key KABUL EDİLMEZ, YALNIZ `org:admin` OAuth token ile: service account (`svac_…`) + federation issuer (`fdis_…`) + federation rule (`fdrl_…`) oluştur (bkz. wif-admin-api). ÇALIŞMA-ANINDA takas admin kimlik gerektirmez: workload'un OIDC/JWT'sini `POST /v1/oauth/token`'da (RFC 7523 jwt-bearer grant; body: federation_rule_id + organization_id + service_account_id [+ workspace_id kural çok-workspace kapsıyorsa]) kısa-ömürlü `sk-ant-oat01-…` access-token ile takas et; SDK'lar otomatik yeniler. Yani programatik dar-yetkili token = WIF service-account token'ı, konsol API key'i DEĞİL. Ek: `ant auth print-credentials --access-token` mevcut OAuth profilinden kısa-ömürlü Bearer basar. Self-hosted Managed-Agents için environment key (`sk-ant-oat01-…`) Console'dan üretilir (dashboard-only).

## Scope (least-privilege)

Anthropic API key'lerinin fine-grained scope'u YOKTUR; izolasyon birimi WORKSPACE'tir. Least-privilege deseni: iş için ayrı bir Workspace aç (`POST /v1/organizations/workspaces`) + o workspace'e scoped bir key ver → blast-radius = tek workspace. Admin key ORG-GENELİ ve kısıtlanamaz → yalnız org/üye/workspace yönetimi için ayrı profilde tut, günlük inference'a asla verme. OAuth'ta privileged scope `org:admin` yalnız Admin endpoint'leri için (login'de `--scope` ile açıkça verilir, rol yetmezse sunucu vermez); WIF federation rule varsayılan scope'u `workspace:developer`, token ömrü 60–86400s (varsayılan 3600). Managed-Agents self-hosted worker için `sk-ant-oat01-…` tek-environment scope'ludur. Org-rolleri (resmi tablo sırası): user < claude_code_user < developer (key yönetir) < billing < admin.

## 🚫 YASAK / sızıntı riskleri (forbidden)

Anti-pattern/sır-sızıntı riskleri (hepsi resmi dokümana karşı doğrulandı): (1) Key'i komut argümanında geçirme — process-list ve shell-history'ye sızar; env var ya da stdin kullan. (2) `ant auth print-credentials`'ı FLAG'SIZ çağırma — tüm credentials JSON'ını basar, header'a konunca bozuk/boş yanıt (HTTP/2 protocol error); HER ZAMAN `--access-token`. (3) `ANTHROPIC_API_KEY` ve `ANTHROPIC_AUTH_TOKEN`'ı BİRLİKTE set etme — SDK ikisini de gönderir, API 401 reddeder. (4) Env var'ı `""`'e "boşaltma" bile precedence slot'unu kazanıp profili/WIF'i gölgeler (bayat/boş-key tuzağı) → gerçekten `unset` et. (5) API key'i prompt/mesaj/system-prompt/Managed-Agents session içine gömme — event-history ve loglara kalıcı yazılır, `events.list()` ile geri okunur. (6) API key'i `Authorization: Bearer`'a koyma → o OAuth token içindir (401: "OAuth bearer token sent via x-api-key…"); API key `x-api-key` header'ında gider (karıştırma = 401). (7) Admin key'i (org-geneli, çok güçlü) workspace-seviyesi bir işe verme; WIF svac/fdis/fdrl uçlarında ise Admin key ZATEN kabul edilmez → org:admin OAuth token. (8) Key'leri repo'ya/CLAUDE.md'ye commit etme — cortex-access.env (600) tek yer.

## Doğrulama (doctor / verify)

Inference key (ucuz, token yakmaz): `curl -sS https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01"` → 200+model listesi = geçerli. CLI/OAuth profili: `ant auth status` (hangi kaynak/profil/workspace aktif; yalnız durum-raporu, exit-code'unu health-check gibi scriptleme) ya da `ant models list`. Admin key (hangi org'a ait): `curl -sS https://api.anthropic.com/v1/organizations/me -H "x-api-key: $ANTHROPIC_ADMIN_KEY" -H "anthropic-version: 2023-06-01"` → `{"id":…,"type":"organization","name":…}` (doğrulandı). org:admin OAuth token ile aynı uç: `-H "authorization: Bearer $ANTHROPIC_OAUTH_TOKEN"`.

## CLI aracı

ant (resmi Anthropic CLI — anthropics/anthropic-cli; `brew install anthropics/tap/ant` veya `go install github.com/anthropics/anthropic-cli/cmd/ant@latest`). Her API kaynağını subcommand olarak açar, control-plane (agents/environments/api-keys/org/WIF) için idealdir; data-plane (inference/sessions) için SDK önerilir. NOT: listede geçen `openai` bu platform için DEĞİLDİR. Salt-API'de `x-api-key` + `anthropic-version: 2023-06-01` header'lı curl+jq de yeterlidir (OAuth token'da `authorization: Bearer` + `anthropic-beta: oauth-2025-04-20`).

## Env değişkeni (cortex-access.env)

ANTHROPIC_API_KEY (inference; SDK+CLI default). Ek konvansiyonel adlar (SDK bunları OTOMATİK okumaz; docs'ta bu adlarla geçer, elle x-api-key'e verilir): ANTHROPIC_ADMIN_KEY (Admin API, `sk-ant-admin…`), ANTHROPIC_AUTH_TOKEN (kısa-ömürlü OAuth Bearer — bunu SDK okur), ANTHROPIC_ENVIRONMENT_KEY (self-hosted Managed-Agents worker, `sk-ant-oat01-…`). WIF için: ANTHROPIC_FEDERATION_RULE_ID + ANTHROPIC_ORGANIZATION_ID + ANTHROPIC_SERVICE_ACCOUNT_ID + ANTHROPIC_IDENTITY_TOKEN_FILE (veya _TOKEN) [+ ANTHROPIC_WORKSPACE_ID]. Precedence (resmi, doğrulandı): ANTHROPIC_API_KEY → ANTHROPIC_AUTH_TOKEN → ANTHROPIC_PROFILE/aktif OAuth profil → WIF env-var'ları → disk'teki default profil (ilk eşleşen kazanır; API_KEY/AUTH_TOKEN boş bile olsa WIF'i gölgeler).

## Adversaryal düzeltmeler

Reçetenin load-bearing iddialarının HEPSİ resmi dokümana karşı doğrulandı; MATERYAL HATA/UYDURMA ENDPOINT YOK. token_mint gerçekten doğru: inference key dashboard-only, Admin API create-key yok (FAQ birebir), WIF programatik yolu (svac_/fdis_/fdrl_ + POST /v1/oauth/token jwt-bearer) GERÇEK. Yapılan küçük netleştirmeler: (1) WIF svac/fdis/fdrl uçlarında Admin API key KABUL EDİLMEZ — yalnız org:admin OAuth token; reçete (b)'de bunu zaten belirtiyordu, başlıktaki "Admin key veya…" ifadesini yanlış-anlaşılmasın diye açık hale getirdim. (2) Çalışma-anı token takası admin kimlik gerektirmez (jwt-bearer); takas body alanları (federation_rule_id/organization_id/service_account_id[+workspace_id]) ve minted token'ın `sk-ant-oat01-` olduğu eklendi. (3) `ant auth login` = tarayıcı OAuth authorization-code + `--no-browser` headless varyantı (literal RFC 8628 device-flow değil) olarak düzeltildi. (4) Admin API'nin ORGANİZASYON gerektirdiği (bireysel hesapta kapalı) honesty-kısıtı olarak eklendi. (5) Admin key prefix: docs yalnız `sk-ant-admin…` gösteriyor; `01` son-eki isim-kalıbına uygun ama doküman-doğrulaması yok — kısaltılmış forma çekildi. (6) sources'a wif-admin-api eklendi. Env-var adları, precedence, forbidden patternleri (print-credentials JSON, çift-token 401, boş-string gölgeleme, x-api-key vs Bearer), verify uçları (/v1/models, /v1/organizations/me, ant auth status) ve cli_tool (`ant`) hepsi resmi.

## Kaynaklar

- https://platform.claude.com/docs/en/manage-claude/admin-api
- https://platform.claude.com/docs/en/api/admin-api/apikeys/get-api-key
- https://platform.claude.com/docs/en/manage-claude/workload-identity-federation
- https://platform.claude.com/docs/en/manage-claude/wif-admin-api
- https://platform.claude.com/docs/en/api/sdks/cli
- https://platform.claude.com/docs/en/manage-claude/authentication
- https://platform.claude.com/docs/en/build-with-claude/claude-platform-on-aws
