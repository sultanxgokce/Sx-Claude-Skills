---
platform: aws
confidence: high
verified: true
---

# aws — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · adversaryal-doğrulanmış (workflow, 6 Tem 2026).
> Reçete adı (araştırmacı): aws

## Özet

AWS erişimi = AWS CLI v2 (`aws`) + IAM kimliği; kimlik BİR KEZ alınır (tercihen IAM Identity Center `aws configure sso` OAuth PKCE/tarayıcı akışı → geçici+otomatik-yenilenen creds; evrensel fallback = dar-yetkili IAM user Access Key ID+Secret'ı interaktif `aws configure` ile yapıştır), doğrulama `aws sts get-caller-identity`, sır cortex-access.env(600)'te; uzun-ömürlü IAM-user kimliğinden dar-scoped GEÇİCİ token PROGRAMATİK üretilebilir (`aws sts get-federation-token --policy`).

## ⚠️ Dürüstlük kısıtı (baştan söyle)

AWS'de kullanıcı-adı+şifre → API-token üreten bir endpoint YOKTUR. Konsol girişi (root ya da IAM-user şifresi) MFA/CAPTCHA arkasındadır ve otomatize edilemez; şifreyle programatik giriş sözü VERME. Kullanılabilir tek "ana giriş" kullanıcının BİR KEZ elle ürettiği bir kimliktir: ya (a) IAM Identity Center (SSO) tarayıcı OAuth akışı (org/admin bunu etkinleştirmişse — geçici, otomatik-yenilenen, uzun-ömürlü sır YOK, TERCİH EDİLEN), ya da (b) her hesapta çalışan evrensel fallback: konsolda IAM-user için Access Key ID + Secret Access Key üretmek. Root hesabı için access key üretmek AWS tarafından KESİNLİKLE caydırılır (Organizations üye hesaplarında varsayılan olarak yoktur ve "Disallow root access key" guardrail'i ile org-düzeyinde engellenebilir; standalone hesapta teknik olarak hâlâ mümkün ama yapılmamalı). (b)'deki Secret yalnızca oluşturma anında bir kez gösterilir, sonra bir daha görülemez.

## Credential intake (kullanıcı BİR KEZ)

EN AZ SÜRTÜNME + least-privilege iki yol: (1) TERCİH — hesapta IAM Identity Center varsa OAuth akışı: `aws configure sso` (SSO start URL + region + `sso:account:access` scope girilir; AWS CLI ≥2.22.0'da varsayılan PKCE tarayıcı akışı aynı-cihazda onaylanır, tarayıcısız/ikinci-cihaz için `--use-device-code` device-authorization) sonra `aws sso login`; uzun-ömürlü sır diske YAZILMAZ, token ~/.aws/sso/cache'te kısa ömürlü + otomatik yenilenir. (2) EVRENSEL fallback — kullanıcı konsolda dar-yetkili özel bir IAM user açar (IAM → Users → Security credentials → Create access key → "Command Line Interface (CLI)"), çıkan Access Key ID + Secret'ı BİR KEZ interaktif `aws configure` ile (soru-cevap, argv'ye düşmez) girer; skill bunu ~/.config/cortex-access.env(600)'e taşır. Kullanıcıya "şifreni ver" DEME; "SSO ise tarayıcıda onayla / değilse konsolda access-key üret ve yapıştır" de.

## Token üretimi / alımı (token_mint)

EVET — programatik dar-scope üretilebilir (AWS'nin güçlü yanı). Uzun-ömürlü IAM-user creds'inden GEÇİCİ scoped kimlik: `aws sts get-federation-token --name <ad> --policy file://session-policy.json --duration-seconds 3600` → dönen geçici AccessKeyId/SecretAccessKey/SessionToken, IAM-user'ın kalıcı politikası İLE session-policy'nin KESİŞİMİNE kısıtlıdır (session-policy daha fazla yetki VEREMEZ, yalnız daraltır; süre 900s–129600s, default 43200s). ÖNEMLİ: get-federation-token yalnız uzun-ömürlü IAM-user creds ile çağrılmalıdır — assumed-role/geçici creds (SessionToken'lı) ile ÇAĞRILAMAZ; root creds ile teknik olarak çağrılabilir ama AWS caydırır + root oturumu 1 saatle (3600s) sınırlanır, root kullanma. Ayrıca get-federation-token'ın ürettiği geçici creds ile IAM işlemleri ve GetCallerIdentity dışında STS işlemleri çağrılamaz. Bir rol varsa alternatif `aws sts assume-role --role-arn <arn> --role-session-name <ad> [--policy ...]`. `aws iam create-access-key --user-name <u>` ise YENİ bir uzun-ömürlü anahtar üretir (scoped DEĞİL — daraltma değil, ikinci anahtar). En temiz "kalıcı least-privilege" = kullanıcının dar-politikalı özel IAM-user'ı; her operasyonu get-federation-token session-policy ile sarmak ekstra sertleştirme (geçici olduğundan kalıcı saklama için değil).

## Scope (least-privilege)

whoami: sts:GetCallerIdentity (hiç izin gerektirmez — explicit deny olsa bile çalışır). İş-bazlı least-privilege: Route53 DNS → route53:ListHostedZones/ChangeResourceRecordSets/ListResourceRecordSets/GetChange (belirli zone ARN); S3 deploy → s3:ListBucket + s3:GetObject/PutObject/DeleteObject (bucket + bucket/*); EC2 → ec2:Describe* + ec2:Start/Stop/RebootInstances (tag-koşullu); genel dev default = yönetilen PowerUserAccess (IAM/Org hariç — AWS'nin SSO dokümanında da önerilen least-privilege developer seti). AdministratorAccess/`*:*`'dan kaçın.

## 🚫 YASAK / sızıntı riskleri (forbidden)

(1) SIR ARGV/ENV SIZINTISI — `aws configure set aws_secret_access_key <DEGER>` Secret'ı POZİSYONEL argv'ye koyar → shell history + `ps`/`/proc/<pid>/cmdline` + transkripte sızar. YASAK. Aynı şekilde inline `AWS_SECRET_ACCESS_KEY=... aws ...` env-öneki → `/proc/<pid>/environ`'dan okunabilir, YASAK. Yerine: interaktif `aws configure` (soru-cevap, argv'ye düşmez) ya da ~/.aws/credentials dosyasını doğrudan chmod-600 ile yaz; sırrı 600'lük dosyadan `source`la. (Not: AWS CLI'da global `--secret-access-key` bayrağı zaten yoktur.) (2) ROOT access key üretmek/kullanmak — AWS kesinlikle caydırır (Organizations üye hesaplarında varsayılan yok + "Disallow root access key" guardrail'i ile engellenebilir); asla üretme/kullanma. (3) ~/.aws/credentials ya da Secret'ı git'e commit'lemek / stdout/log/chat'e echo'lamak (get-caller-identity çıktısı sır DEĞİL, güvenle gösterilir; Secret'ı ASLA gösterme). (4) AdministratorAccess / `"Action":"*","Resource":"*"` geniş politika. (5) Hiç dönmeyen uzun-ömürlü anahtarlar — iş bitince rotate/`aws iam delete-access-key`; mümkünse STS geçici creds tercih et. (6) get-federation-token/get-session-token süresini gereksiz uzun tutmak.

## Doğrulama (doctor / verify)

`aws sts get-caller-identity` — ucuz, salt-okunur; Account, Arn, UserId döner. Resmi dokümana göre hiçbir IAM izni gerektirmez (explicit deny politikası olsa bile çalışır), herhangi bir geçerli kimlikle döner → kanonik whoami. (Belirli profil/SSO için `aws sts get-caller-identity --profile <ad>`.)

## CLI aracı

aws (AWS CLI v2)

## Env değişkeni (cortex-access.env)

AWS_ACCESS_KEY_ID (+ AWS_SECRET_ACCESS_KEY, geçici creds için AWS_SESSION_TOKEN, AWS_DEFAULT_REGION); SSO yolunda sır env yerine AWS_PROFILE + ~/.aws/config[+~/.aws/sso/cache]

## Adversaryal düzeltmeler

3 düzeltme: (1) token_mint — "get-federation-token root ile ÇAĞRILAMAZ" YANLIŞTI: resmi dokümana göre root creds ile teknik olarak çağrılabilir (ama AWS caydırır + root oturumu 1 saatle sınırlı); ÇAĞRILAMAZ olan yalnızca assumed-role/geçici creds'tir — düzeltildi + geçici creds'in IAM & (GetCallerIdentity hariç) STS çağıramama kısıtı eklendi. (2) Root access key ifadesi fazla katıydı: "AWS'nin kendisi yasaklar" → gerçek = kesinlikle caydırılır, standalone hesapta hâlâ mümkün, yalnız Organizations üye hesaplarında varsayılan yok + guardrail ile engellenebilir (honesty_constraint + forbidden yumuşatıldı). (3) forbidden — var olmayan global `--secret-access-key` bayrağı iddiası kaldırıldı; gerçek iki sızıntı vektörü netleştirildi (positional argv `aws configure set ... <deger>` + inline `AWS_SECRET_ACCESS_KEY=... aws` env → /proc/environ). Diğer tüm alanlar (get-federation-token 900–129600s/default 43200s + kesişim semantiği, aws configure sso PKCE/device + sso:account:access + ~/.aws/sso/cache, get-caller-identity izin gerektirmez, env_var/cli_tool adları) resmi dokümanla BİREBİR doğrulandı.

## Kaynaklar

- https://docs.aws.amazon.com/STS/latest/APIReference/API_GetFederationToken.html
- https://docs.aws.amazon.com/STS/latest/APIReference/API_GetCallerIdentity.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_request.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html
- https://aws.amazon.com/blogs/security/secure-root-user-access-for-member-accounts-in-aws-organizations/
- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
