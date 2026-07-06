---
platform: google-cloud
confidence: high
verified: true
---

# google-cloud — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): google-cloud (Google Cloud Platform / GCP)

## Özet

GCP'de headless erişim = gcloud CLI + Application Default Credentials; kullanıcı BİR KEZ dar-yetkili bir service-account JSON anahtarı verir (ya da headless OAuth ile giriş yapar), skill onunla oturum açar ve sonrasında gcloud/REST ile işleri panele girmeden yapar; gerçek least-privilege IAM rolleriyle, gerekirse programatik kısa-ömürlü impersonation token'larıyla sürdürülür.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Google'ın kullanıcı-adı+şifre → token API'si YOKTUR (ROPC/password grant Google hesapları için desteklenmez). Google girişi OAuth 2.0 + 2FA + rıza (consent) ekranı arkasındadır; şifreyle otomatik token alınamaz. Headless bir ajan için gerçekçi TEK-SEFER intake iki seçenek: (a) dedike bir service-account'un JSON anahtarı (long-lived sır — Google'ın KENDİSİ bunu ÖNERMEZ: sızan SA anahtarı bulut ihlallerinin en yaygın sebebi), ya da (b) headless kullanıcı-OAuth (dosya yok ama geniş kullanıcı-scope'u). Google'ın önerdiği anahtarsız yol (Workload Identity Federation) bir dış OIDC IdP + kurulum ister → rastgele bir Hetzner kutusunda "bir kez yapıştır" akışı DEĞİLDİR; onu vaat etme. Dürüst pozisyon: dedike-SA + DAR IAM rolleri + anahtar-süre-sonu + rotasyon ile SA-JSON kullan, veya headless kullanıcı-OAuth. Basit "şifre ver, gerisini ben hallederim" YOK.

## Credential intake (kullanıcı BİR KEZ)

En az sürtünme + least-privilege: kullanıcı konsolda BİR KEZ dedike bir service account oluşturur (ör. cortex-agent@PROJECT.iam.gserviceaccount.com), ona SADECE gereken predefined IAM rollerini verir (owner/editor DEĞİL), tek bir JSON anahtar üretip indirir. Anahtar dosyasını bir kez kutuya bırakır (ör. CloudBridge/evraklar üzerinden), skill: `gcloud auth activate-service-account --key-file=KEY.json` ile oturum açar ve yolu `GOOGLE_APPLICATION_CREDENTIALS`'a yazar (ADC). Alternatif (dosyasız, ama geniş scope): headless kullanıcı-OAuth → `gcloud auth login --no-launch-browser` (çıkan `https://accounts.google.com/o/oauth2/auth...` URL'sini kullanıcı telefonda/başka cihazda açar, doğrulama kodunu terminale yapıştırır; port/tarayıcı gerekmez). NOT: `--no-launch-browser` Şub-2022'de resmen "deprecated" işaretlendi ama HÂLÂ çalışır ve bu senaryo (ikinci makineye gcloud kuramıyorsun, tarayıcı yalnız telefonda) için Google'ın önerdiği doğru bayrak budur; yeni `--no-browser` bayrağı ise browser'lı makinede AYRICA gcloud kurulu olmasını ister (bu kutu için uygun değil). Ajan-daemon için SA-JSON tercih; kurumsal/anahtarsız isteniyorsa WIF.

## Token üretimi / alımı (token_mint)

EVET — GCP burada Cloudflare'dan güçlü: programatik kısa-ömürlü, dar-yetkili token üretimi birinci-sınıf. (1) Aktif kimlikle 1 saatlik OAuth2 access token: `gcloud auth print-access-token` (impersonation için `--impersonate-service-account=SA_EMAIL`, süre için `--lifetime` maks 43200s). (2) IAM Credentials API ile doğrudan: `POST https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/SA_EMAIL:generateAccessToken` gövde `{"scope":["https://www.googleapis.com/auth/cloud-platform"],"lifetime":"3600s"}` — çağıran kimliğin hedef SA üzerinde `roles/iam.serviceAccountTokenCreator` rolü olmalı; varsayılan max 1s, org-policy `constraints/iam.allowServiceAccountCredentialLifetimeExtension` ile 12s (43200s). (3) Kaynak-bazlı DAHA dar token (Credential Access Boundary / downscoped) STS ile: `POST https://sts.googleapis.com/v1/token` (grant_type=urn:ietf:params:oauth:grant-type:token-exchange) — AMA yalnız Cloud Storage destekler. Yani geniş bir kimlikten (kullanıcı-OAuth veya ayrıcalıklı SA) daha dar bir SA'ya impersonation ile kısa-ömürlü token BASILABİLİR; scope-daraltma esasen IAM rolleriyle yapılır. Uzun-ömürlü statik anahtar üretme; kısa-ömürlü impersonation token'ları tercih et.

## Scope (least-privilege)

Least-privilege GCP'de OAuth scope ile DEĞİL, SA'ya verilen predefined IAM rolleriyle sağlanır (OAuth scope genelde geniş `https://www.googleapis.com/auth/cloud-platform`). Yaygın iş → rol: Deploy (Cloud Run) → roles/run.admin + roles/cloudbuild.builds.editor + roles/artifactregistry.writer + roles/iam.serviceAccountUser (runtime SA'yı actAs); Depolama/env → roles/storage.objectAdmin (veya objectViewer); DNS → roles/dns.admin; Sunucu/VM yönetimi → roles/compute.instanceAdmin.v1; Secret okuma → roles/secretmanager.secretAccessor; Token basma → hedef SA üzerinde roles/iam.serviceAccountTokenCreator. KAÇIN: temel roller roles/owner ve roles/editor (blast-radius devasa). Rolleri proje değil mümkünse kaynak düzeyinde bağla.

## 🚫 YASAK / sızıntı riskleri (forbidden)

(1) SA JSON anahtarını git'e/argv'ye/log'a sokma — sızan anahtar = kalıcı doğrudan erişim, bulut ihlallerinin #1 sebebi; anahtarı asla `cat` ile stdout'a dökme, asla commit etme, içeriğini başka aracın CLI argümanı yapma. (2) Railway'deki `railway variables --set <deger>` argv-sızıntısının GCP karşılığı: `gcloud auth print-access-token` çıktısını başka bir komutun argümanına gömme (process-list/`ps`/shell-history'ye düşer) → env veya pipe kullan; token'ı `?access_token=` query-param olarak GERÇEK API çağrılarında verme (sunucu/proxy loglarına düşer) → `Authorization: Bearer` header kullan (query-param sadece atılık tokeninfo doğrulamasında, bilinçli riskle). (3) roles/owner|roles/editor verme. (4) Süre-sonu/rotasyon olmayan uzun-ömürlü anahtar bırakma; iş bitince anahtarı disable→delete. (5) gcloud sırları `~/.config/gcloud`'da yaşar (credentials.db, access_tokens.db, application_default_credentials.json) — 600 tut, bu dizini/anahtar dosyasını CloudBridge gibi çift-yönlü senkron/paylaşılan mount'a KOYMA. (6) GOOGLE_APPLICATION_CREDENTIALS'ı senkronlanan bridge klasörüne işaret ettirme.

## Doğrulama (doctor / verify)

En ucuz whoami: `gcloud auth list` (aktif hesabı gösterir, ağ gerektirmez). Token'ın geçerliliği + scope/email/expiry: `curl "https://oauth2.googleapis.com/tokeninfo?access_token=$(gcloud auth print-access-token)"` (veya `https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=...`). Gerçek yetki teyidi (bir read işi çalışıyor mu): `gcloud projects describe PROJECT_ID` ya da `curl -H "Authorization: Bearer $(gcloud auth print-access-token)" https://cloudresourcemanager.googleapis.com/v1/projects` — 200 = yeşil.

## CLI aracı

gcloud (Google Cloud CLI / Cloud SDK; gsutil + bq paketli — depolama için `gcloud storage` gsutil'in modern muadili). Saf REST de mümkün ama gcloud kanonik.

## Env değişkeni (cortex-access.env)

GOOGLE_APPLICATION_CREDENTIALS (SA JSON anahtar / ADC dosya YOLU — sırrın kendisi JSON dosyada, env değişkeni sadece yolu tutar). İkincil: GOOGLE_CLOUD_PROJECT (veya CLOUDSDK_CORE_PROJECT) = varsayılan proje kimliği.

## Adversaryal düzeltmeler

Tek düzeltme (küçük): `gcloud auth login --no-launch-browser` bayrağı Şub-2022'de resmen "deprecated" işaretlendi (yerine `--no-browser` önerildi) — reçetenin "telefonda URL aç, kodu geri yapıştır, port/tarayıcı yok" tarifi ise TAM olarak `--no-launch-browser` davranışıdır ve Google bunu hâlâ "ikinci makineye gcloud KURAMIYORSAN doğru bayrak budur" diye belgeliyor (yeni `--no-browser` browser'lı makinede AYRICA gcloud ister → bu headless kutu için uygun değil). Bu deprecation nüansı credential_intake'e eklendi; bayrak bu senaryo için geçerli kaldı. Diğer HER ŞEY güncel resmi dokümana karşı doğrulandı ve DOĞRU: (a) token_mint'in üç yolu da (print-access-token +--impersonate-service-account/--lifetime maks 43200s; iamcredentials generateAccessToken endpoint'i + roles/iam.serviceAccountTokenCreator + 12s org-policy constraint adı `constraints/iam.allowServiceAccountCredentialLifetimeExtension`; STS `https://sts.googleapis.com/v1/token` + grant-type token-exchange, YALNIZ Cloud Storage downscoping) birebir teyit edildi; (b) şifre→token API yok / OAuth+2FA+consent + WIF harici-IdP gerçeği doğru; (c) argv/ps + ?access_token= query-param log sızıntısı + ~/.config/gcloud sır dosyaları gerçek; (d) GOOGLE_APPLICATION_CREDENTIALS / GOOGLE_CLOUD_PROJECT / CLOUDSDK_CORE_PROJECT ve gcloud adları resmi.
