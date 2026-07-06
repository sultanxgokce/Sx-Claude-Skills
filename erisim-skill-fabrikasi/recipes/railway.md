---
platform: railway
confidence: high
verified: true
---

# railway — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): railway

## Özet

Railway erişimi = dashboard'da BİR KEZ üretilen bir Account/Workspace token'ı (railway.com/account/tokens) → cortex-access.env'e RAILWAY_API_TOKEN olarak koy → hem `railway` CLI hem GraphQL API (backboard.railway.com/graphql/v2, header `Authorization: Bearer`) bu env'i otomatik kullanır; token programatik ÜRETİLEMEZ (belgelenmiş public API/CLI yok), kullanıcıdan hazır alınır.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre → token API'si YOKTUR. Railway'de kalıcı token'lar SADECE dashboard'da (login+2FA arkasında Account Settings → Tokens, railway.com/account/tokens) elle üretilir. Geniş kimlikten dar token türeten belgelenmiş public GraphQL mutation'ı da YOK → skill mevcut token'ı daraltamaz, doğru-kapsamlı token'ı baştan ister. `railway login --browserless` bir pairing-code (device) akışıdır: yine başka bir cihazın tarayıcısında interaktif onay ister ve taşınabilir API token'ı değil, CLI'nin yerel oturum anahtarını (~/.railway config) üretir. Headless senaryoda tek gerçekçi yol: kullanıcının önceden dashboard'da ürettiği token'ı yapıştırması.

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ railway.com/account/tokens'te ürettiği hazır token'ı yapıştırır (OAuth app kaydı GEREKMEZ → en az sürtünme). Least-privilege sırası: tek proje+ortam → PROJECT token (proje → Settings → Tokens); tek workspace çoklu-proje → WORKSPACE token (oluştururken workspace seç); zorunluysa → ACCOUNT token (workspace BOŞ bırak). Öneri KULLANIMA GÖRE: ağırlıklı ham GraphQL API işi ise WORKSPACE token; ağırlıklı `railway` CLI işi (up/run/deploy) ise tek proje için PROJECT token, çok-projeli CLI için ACCOUNT token — çünkü mevcut CLI v5 workspace-scoped token'ı reddedebiliyor (bkz. verify + CLI issue #845).

## Token üretimi / alımı (token_mint)

dashboard-only — programatik token üretimi için belgelenmiş public API/CLI YOK. Adımlar: (1) railway.com/account/tokens → 'Create Token' → ad ver → Workspace seçimi BOŞ = Account-scoped, workspace seç = Workspace-scoped → token'ı BİR KEZ kopyala (bir daha gösterilmez). (2) Project token: proje → Settings → Tokens → ortam seç. Skill geniş→dar daraltma yapamaz; doğru-kapsamlı token'ı intake'te ister, cortex-access.env'e yazar, bir daha sormaz.

## Scope (least-privilege)

Least-privilege merdiveni (dardan genişe): PROJECT token = tek proje + tek ortam; header `Project-Access-Token: <TOK>`; env `RAILWAY_TOKEN`; `railway up`/`railway run`/o ortamın değişkenleri. → WORKSPACE token = tek workspace'in tüm projeleri; header `Authorization: Bearer <TOK>`; env `RAILWAY_API_TOKEN`; ham GraphQL API'de tam çalışır ANCAK mevcut CLI (v5) workspace-scoped token'ı reddedebiliyor (issue #845) → CLI-ağırlıklı işte PROJECT ya da ACCOUNT tercih et. → ACCOUNT token = tüm workspace+kaynaklar; header `Authorization: Bearer <TOK>`; env `RAILWAY_API_TOKEN`; hem CLI hem API'de sorunsuz. Kural: işi kapsayan EN DAR olanı seç. RAILWAY_TOKEN ve RAILWAY_API_TOKEN'ı birlikte export ETME (ikisi setse öncelik/çakışma belirsiz; proje komutlarında RAILWAY_TOKEN öne geçer).

## 🚫 YASAK / sızıntı riskleri (forbidden)

1) `railway variables --set "KEY=VALUE"` (ve eski `railway variables set KEY=VALUE`) → değer argv'ye girer → `ps`/process-list, shell history ve AJAN TRANSKRİPTİNE SIZAR. Sır set etmek için dashboard kullan; mümkünse SEALED variable (API/CLI ile asla geri okunamaz). 2) `railway variables` / `railway run` sealed-olmayan değerleri stdout'a düz-metin basar → çıktıyı log/transkripte dökme. 3) Token'ı curl komut satırına `--header 'Authorization: Bearer <tok>'` diye YAZMA (ps/history'ye düşer) → env'den oku: `-H \"Authorization: Bearer $RAILWAY_API_TOKEN\"`. 4) İçinde sır olan variable-group'u frontend/PR ortamıyla PAYLAŞMA (build-anında client bundle'a veya public preview URL'ine sızar; canlı Stripe anahtarı örn.). 5) Token'ı repoya commit etme → cortex-access.env 0600. 6) RAILWAY_TOKEN + RAILWAY_API_TOKEN'ı birlikte export etme (çakışma/öncelik belirsizliği + yanlış-kapsam kazası).

## Doğrulama (doctor / verify)

ACCOUNT token — CLI: `railway whoami`; ham API: `curl -s -X POST https://backboard.railway.com/graphql/v2 -H \"Authorization: Bearer $RAILWAY_API_TOKEN\" -H 'Content-Type: application/json' --data '{\"query\":\"query { me { name email } }\"}'`. DİKKAT: `me` sorgusu SADECE ACCOUNT token ile çalışır — WORKSPACE ve PROJECT token ile ÇALIŞMAZ (dönen veri kişisel-hesap kapsamlı). WORKSPACE token — `me` ile doğrulama; ham API'de workspace/projeler sorgusuyla doğrula, ör. `--data '{\"query\":\"query { projects { edges { node { name } } } }\"}'` (Bearer header); mevcut CLI `railway whoami` workspace-scoped token'ı reddedebilir (issue #845), bu yüzden CLI'ye güvenme. PROJECT token — `me`/whoami çalışmaz; `RAILWAY_TOKEN=<tok> railway status` ile ya da bir environment/proje sorgusuyla (`Project-Access-Token: <TOK>` header) doğrula.

## CLI aracı

railway (Railway CLI, güncel v5.x — Temmuz 2026 itibarıyla v5.23.3; @railway/cli npm) — RAILWAY_API_TOKEN / RAILWAY_TOKEN env'lerini otomatik okur; ham GraphQL için CLI şart değil (backboard.railway.com/graphql/v2 + curl da olur). Not: v5 CLI workspace-scoped token'ı reddedebiliyor (issue #845) — CLI işinde account/project token daha güvenli.

## Env değişkeni (cortex-access.env)

RAILWAY_API_TOKEN

## Adversaryal düzeltmeler

4 düzeltme: (1) cli_tool v4.x → v5.x (güncel v5.23.3, 30 Haz 2026). (2) verify: `me` sorgusu SADECE account token ile çalışır; resmi doküman "workspace veya project token ile kullanılamaz" diyor — reçetenin 'account/workspace' iddiası yanlıştı. (3) `railway whoami` + WORKSPACE token: mevcut CLI (issue #845) workspace-scoped token'ı reddediyor (GraphQL API'de geçerli olsa da) → verify/scopes'a CLI-uyumsuzluk uyarısı ve kullanım-bazlı öneri eklendi. (4) 'RAILWAY_TOKEN ve RAILWAY_API_TOKEN aynı anda set EDİLEMEZ' belgelenmiş kesin bir kural değil → 'ikisini birlikte export etme, öncelik belirsiz' cautionuna yumuşatıldı. Doğru çıkan alanlar (değişmedi): endpoint backboard.railway.com/graphql/v2, token türleri+header'lar, dashboard-only mint, env_var adları, honesty_constraint (şifre→token yok + browserless=yerel oturum), forbidden #1 argv sızıntısı (`railway variables --set` gerçekten güncel v5 sözdizimi).

## Kaynaklar

- https://docs.railway.com/reference/public-api
- https://docs.railway.com/guides/public-api
- https://docs.railway.com/reference/cli-api
- https://docs.railway.com/cli
- https://docs.railway.com/cli/login
- https://docs.railway.com/integrations/oauth/login-and-tokens
- https://github.com/railwayapp/cli
- https://github.com/railwayapp/cli/releases
- https://github.com/railwayapp/cli/issues/845
- https://www.npmjs.com/package/@railway/cli
- https://railway.com/account/tokens
