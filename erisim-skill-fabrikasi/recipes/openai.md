---
platform: openai
confidence: high
verified: true
---

# openai — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): openai

## Özet

OpenAI erişimi = Bearer API anahtarı; en az sürtünme için kullanıcı dashboard'da BİR KEZ Admin key (sk-admin-) üretip yapıştırır, sonra skill Admin API ile proje bazlı dar-yetkili service-account anahtarları (sk-svcacct-) programatik üretir/döndürür. Sadece inference isteniyorsa admin bile gerekmez, tek bir proje/service-account anahtarı yeter.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre → token API'si YOK (giriş 2FA/CAPTCHA arkasında; platform API'sinde key basan bir /oauth/authorize akışı yoktur. ChatGPT "Sign in with OpenAI" OAuth'u yalnız son-kullanıcı uygulamaları içindir — Apps SDK / GPT Actions kimlik doğrular, YÖNETİM/inference anahtarı ÜRETMEZ). BOOTSTRAP anahtarı mutlaka dashboard'dan gelir: Org Owner, platform.openai.com/settings/organization/admin-keys → "Create new admin key" ile sk-admin-... üretir. Programatik "ilk anahtar" üretimi mümkün değil — çünkü Admin API'yi çağırmak için zaten bir admin anahtarı gerekir (yumurta-tavuk). Ayrıca: normal PROJE-KULLANICI anahtarları (sk-proj-) API ile ÜRETİLEMEZ (yalnız list/retrieve/delete var; DOĞRULANDI); programatik anahtar üretiminin tek yolu service-account'tur. Anahtar başına ince-granül izinler (read-only / read-write / kaynak-bazlı restricted key) yalnız DASHBOARD'dan ayarlanır, service_accounts create çağrısı izin/scope parametresi almaz.

## Credential intake (kullanıcı BİR KEZ)

En az sürtünme + least-privilege: kullanıcı BİR KEZ hazır bir anahtar yapıştırır (gizli giriş, stdin — asla argv). İki senaryo: (A) İş sadece inference/tek-proje ise → doğrudan bir proje anahtarı (sk-proj-...) veya tercihen tek projeye bağlı service-account anahtarı (sk-svcacct-...) yapıştır; admin gücü gerekmez, blast-radius = o proje. (B) Skill'in kendisi anahtar/proje ÜRETMESİ-döndürmesi gerekiyorsa → dashboard'dan bir kez üretilmiş Admin key (sk-admin-...) yapıştır; skill bununla her iş için taze scoped service-account anahtarı basar. Varsayılan öneri: dar iş için (A); sadece gerçekten org/proje yönetimi gerekince (B) admin iste. OAuth device-flow yok, service-account JSON yok — sadece Bearer anahtar yapıştırma.

## Token üretimi / alımı (token_mint)

EVET (Admin key varsa) — service-account anahtarı programatik üretilir. DOĞRULANMIŞ endpoint (resmi Admin API): POST https://api.openai.com/v1/organization/projects/{project_id}/service_accounts  -H "Authorization: Bearer $OPENAI_ADMIN_KEY"  -H "Content-Type: application/json"  -d '{"name":"<isim>"}'  → yanıt .api_key.value içinde sk-svcacct-... anahtarını REDAKTE-EDİLMEMİŞ olarak SADECE BİR KEZ döner (kaybolursa kurtarma yok, rotate şart; jq ile doğrudan env dosyasına çek, stdout'a basma). Proje yoksa önce POST /v1/organization/projects {"name":...}. Admin key de programatik basılabilir: POST /v1/organization/admin_api_keys (yanıt .value içinde sk-admin-... bir kez döner) — ama yine mevcut bir admin key ister → bootstrap dashboard-only. ÜRETİLEMEYENLER: sk-proj- kullanıcı anahtarı (API'de create yok, DOĞRULANDI) ve anahtar-başına ince izin scope'u (dashboard-only). Yani least-privilege sınırı anahtar-izni değil, PROJE izolasyonudur: iş başına ayrı proje + ayrı service-account.

## Scope (least-privilege)

PROJE-izolasyonu birincil sınır: iş başına ayrı proje + tek service-account. Anahtar-izni varsayılanı read+write (proje kaynakları); daraltma (restricted key) yalnız dashboard'dan. Admin key = tüm-org yönetim (proje/kullanıcı/anahtar/fatura/audit-log/rate-limit/spend-alert) — Yalnız Org Owner üretip kullanabilir; runtime'a koyma.

## 🚫 YASAK / sızıntı riskleri (forbidden)

(1) Anahtar değerini ASLA argv/process-list'e koyma — `Authorization: Bearer $VAR` env'den; gerekirse `curl -H @headerfile` veya `--config`. Cloudflare/Railway'deki `--set <deger>` sızıntısının OpenAI karşılığı: anahtarı bir CLI pozisyonel argümanı ya da inline `-H "Authorization: Bearer sk-..."` literali olarak vermek (ps/shell-history/CI-log'a düşer). (2) service_accounts create yanıtı anahtarı düz-metin SADECE BİR KEZ döner → bu JSON'u stdout/chat/CI-log'a BASMA; doğrudan `jq -r .api_key.value` ile 600'lük env dosyasına yaz. (3) Admin key'i (sk-admin-) runtime konteynerine/uygulamaya/CI'a çalışma-anahtarı olarak GÖNDERME — org ana anahtarıdır; onunla scoped service-account bas, onu gönder. (4) Tek org-geneli anahtarı tüm uygulamalarda paylaşma (izolasyon yok, sızıntıda toplu-revoke şart) → proje+service-account başına ayır. (5) Anahtarı repoya commit'leme / imaja gömme / URL query'sine koyma; .env 600 + registry-pointer.

## Doğrulama (doctor / verify)

Inference/proje anahtarı: `curl -s -o /dev/null -w '%{http_code}' https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"` → 200 = geçerli (opsiyonel openai CLI: `openai api models.list`). Admin anahtarı: `curl -s https://api.openai.com/v1/organization/projects?limit=1 -H "Authorization: Bearer $OPENAI_ADMIN_KEY"` → 200 + proje listesi = geçerli admin (401/403 = admin değil veya Org Owner değil). Her ikisi de ucuz, ücretsiz, salt-okunur.

## CLI aracı

none (saf API — curl + jq). Token-mint / proje / service-account YÖNETİM-düzlemi (admin_api_keys, projects, service_accounts) resmi `openai` CLI'da YOKTUR. Resmi `openai` CLI (pip install openai) yalnız inference/dosya/fine-tune/batch kapsar ve bu skill'de yalnız opsiyonel inference-verify (`openai api models.list`) için kullanılabilir.

## Env değişkeni (cortex-access.env)

OPENAI_API_KEY (çalışma/inference anahtarı — SDK+CLI konvansiyonu). Admin akışında ek: OPENAI_ADMIN_KEY (OpenAI'nin resmi Admin API kılavuzundaki örnek ad — DOĞRULANDI). Opsiyonel: OPENAI_ORG_ID, OPENAI_PROJECT_ID. cortex-access.env için birincil = OPENAI_API_KEY (+ admin-mint kullanılıyorsa OPENAI_ADMIN_KEY).

## Adversaryal düzeltmeler

Özünde düzeltme YOK — tüm alanlar güncel resmi dokümana karşı doğrulandı. (a) token_mint gerçek: POST /v1/organization/projects/{project_id}/service_accounts endpoint'i resmi API Reference'ta mevcut, gizli anahtar `.api_key.value` yolunda, `sk-svcacct-` önekli, yalnız bir kez döner (kaybolursa rotate). admin_api_keys create endpoint'i de gerçek ama mevcut admin key ister → bootstrap dashboard-only doğru. (b) honesty_constraint doğru: şifre→token API yok, "Sign in with OpenAI" yalnız son-kullanıcı uygulaması (Apps SDK/GPT Actions), yönetim anahtarı basmaz; sk-proj- API ile üretilemez teyit edildi. (c) forbidden argv/CI-log sızıntı patternleri geçerli. (d) OPENAI_API_KEY + OPENAI_ADMIN_KEY resmi adlar; yönetim-düzlemi CLI'da yok → cli_tool=none doğru. Küçük netleştirmeler: (i) resmi create-yanıt ÖRNEĞİ jenerik `sk-...` placeholder gösterir, ama üretimde service-account anahtarları `sk-svcacct-` önekini gerçekten taşır (başka kaynaklarla teyit); (ii) cli_tool birincil değeri net olsun diye "none (saf API)" öne alındı, openai CLI yalnız opsiyonel inference-verify.

## Kaynaklar

- https://developers.openai.com/api/reference/resources/organization/subresources/projects/subresources/service_accounts/methods/create
- https://developers.openai.com/api/reference/resources/organization/subresources/audit_logs/subresources/admin_api_keys/methods/create
- https://developers.openai.com/api/docs/guides/admin-apis
- https://platform.openai.com/docs/api-reference/administration
- https://platform.openai.com/settings/organization/admin-keys
- https://help.openai.com/en/articles/9186755-managing-your-work-in-the-api-platform-with-projects
- https://vibekit.bot/openai-api-key-format
- https://developers.openai.com/apps-sdk/build/auth
- https://community.openai.com/t/how-to-programmatically-create-a-project-api-key-after-creating-a-project/1051339
