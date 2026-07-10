---
name: erisim-skill-fabrikasi
type: agent
version: 1.1.0
description: >
  "Platforma-erişim skill'i ÜRETEN" meta-skill. Bir platform seçersin (Railway, GitHub, Google,
  Vercel, AWS, Hetzner…) → skill ortamı hazırlar, sana BİR KERELİK gizli giriş sorar, gerekiyorsa
  dar-yetkili token'ı kendi üretir/alır, cortex-access.env'e kaydeder ve o platform için tam bir
  `<platform>-erisim` skill'ini (cloudflare-erisim'i şablon + platformun auth-reçetesini kullanarak)
  Sx-Claude-Skills'e SCAFFOLD eder. Böylece o platforma erişim bir daha angarya olmaz. Sır-hijyenik.
install_target:
  commands: .claude/commands/
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [meta-skill, erisim, platform-access, token, scaffold, skill-uretici, cloudflare, railway, github, google, secret-hygiene]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Erişim-Skill Fabrikası (meta-skill)

## Ne işe yarar
Sultan bir platforma (Railway, GitHub, Google, Vercel, Supabase, AWS, Hetzner, OpenAI…) erişim
gerektiğinde her seferinde credential-akışını elle kurmaktan/anlatmaktan bıktı. Bu meta-skill o
kalıbı **bir kez damıtıp** her yeni platform için otomatik üretir:

> `/erisim-skill-fabrikasi <platform>` (veya "X platformu için erişim skill'i oluştur") →
> ortamı hazırla → bir-kerelik gizli giriş al → dar-yetkili token üret/kaydet → o platform için
> tam `<platform>-erisim` skill'ini scaffold et → Sx-Claude-Skills'e ekle → dağıt.

**Referans implementasyon = [`cloudflare-erisim`](../cloudflare-erisim/SKILL.md)** — bu meta-skill onu
şablon alır. Üretilen her skill onunla aynı omurgayı taşır (aşağıdaki "Ortak omurga").

## Ortak omurga (her üretilen platform-skill'inde AYNI)
1. **Tek-sefer GİZLİ credential intake** — TTY `read -rs`, değer chat/log/geçmişe **ASLA** düşmez.
   (Ajan kendisi giremez; kullanıcıya bir terminalde çalıştıracağı NET komutu verir.)
2. **Least-privilege scoped token** — platform programatik üretimi destekliyorsa skill **kendi üretir**
   (ör. Cloudflare `POST /user/tokens`); desteklemiyorsa kullanıcı dashboard'da üretir + `set-token`.
3. **VAULT-FIRST çözüm + fallback** → sır **merkezî vault'a** (Infisical, `vault-cek` seam) yazılır; skill
   çalışırken **vault-cek(Infisical) ÖNCE** çözer (env'e tazeler) → yoksa/erişilemezse
   `~/.config/cortex-access.env` (chmod 600, `export <ENV_VAR>=…`) **fallback**. Vault-outage'ta skill
   çalışmaya-DEVAM (fail-hard YOK). Çözüm-sırası `load_creds` içinde: `vault-cek get <KEY>` → dosyadan source.
4. **Registry pointer** → `Nexus/_agents/credentials.yaml` (`[SIR: … → <platform>-*]`). Sır DEĞERİ değil, pointer.
5. **`doctor` = 3-durum + vault-parite** — yeşil (geçerli) / kırmızı (fail:neden) / doğrulanmadı; + idempotent
   iş komutları. Doctor ayrıca `vault:yeşil|kırmızı|doğrulanmadı · env-fallback:… · token-geçerli:…` (değer-OKUMAZ).
6. **Dürüstlük guard'ı** — platformun GERÇEK auth kısıtını baştan söyle (çoğunda şifre→token API'si YOK).
7. **Saf API (curl+jq) tercih** — resmi CLI varsa kullan, yoksa/gereksizse HTTP.
8. **Mint→vault yazımı (folder-kuralı)** — üretilen/alınan dar-token merkezî vault'a da yazılır:
   platform-genel tek-hesap-token (tüm-ajan-aynı, ör. `CLOUDFLARE_API_TOKEN`) → **`/shared`** (default);
   proje-özel sır → **`/<proje>`**. Yazım **Sultan-eli/deep-link YA DA yetkili machine-identity CLI** ile
   (değer transkripte/log'a düşmeden). Bu adım **belgelenir, OTOMATİKLEŞTİRİLMEZ** (değer-sahipliği Sultan-gate).

## Akış (meta-skill çalıştırılınca)

### 1. Platformu belirle
Argüman verilmediyse sor: "Hangi platform?" (recipes/ altındaki bilinenleri listele).

### 2. Auth-reçetesini yükle
`recipes/<platform>.md` varsa oku. **Yoksa** → o platformun 2026 auth modelini web ile araştır
(WebSearch/WebFetch), aşağıdaki "Reçete şeması"na göre doldur, **`recipes/<platform>.md`'ye KAYDET**
(bilgi tabanı büyür → bir dahaki sefere hazır). Reçete = fabrikanın beyni; doğru olmalı, uydurma değil.

### 3. Ortamı hazırla
Reçetedeki `cli_tool` + `curl`/`jq` mevcut mu kontrol et; eksikse kur/kurulum yönergesi ver.

### 4. Bir-kerelik giriş (gizli)
Kullanıcıya, reçetenin `credential_intake` alanına göre NET yönerge ver (token yapıştır / OAuth
device-flow / service-account JSON). **Değer argv'ye/loga/chat'e girmemeli** → heredoc veya `read -rs`.

### 5. Token'ı al/üret + sakla
`token_mint` programatikse skill üretir; değilse kullanıcı verir. → `cortex-access.env` (600) `<env_var>`
→ registry pointer. Reçetenin `forbidden` maddelerine UY (ör. Railway'de `variables --set` YASAK → dashboard).

### 6. `<platform>-erisim` skill'ini SCAFFOLD et
```bash
bash erisim-skill-fabrikasi/scaffold.sh <platform>
```
→ `<platform>-erisim/` dizinini cloudflare-erisim'den şablonlayarak açar (SKILL.md iskeleti +
`scripts/<platform>.sh` iskeleti: login/set-token/doctor/<iş> idempotent stub'lar + sır-hijyen yardımcıları).
Sonra ajan, **reçeteye göre** API endpoint'lerini/scope'ları/iş komutlarını doldurur. cloudflare-erisim'in
`cf.sh`'i birebir referans (aynı `load_creds`/`api`/`doctor`/idempotent-ensure kalıbı).

### 7. Sx-Claude-Skills'e kaydet (Altın Kural — kaynak burası)
- `catalog.json`'a entry ekle · `sync-targets.json` `install`'a `<platform>-erisim: ["_global","nexus","cortex"]`
  ekle · README tablosuna satır.
- Dağıt: `node sync-skills.mjs --apply` → `_global` (bulutta her proje) + VPS hedefleri.

### 8. Doğrula + raporla
`bash ~/.claude/skills/<platform>-erisim/scripts/<platform>.sh doctor` → yeşil bekle. Kullanıcıya
`✓/•/✗` özetini ilet + varsa host-tarafı hatırlatması (ör. tünel ingress host'ta).

## Reçete şeması (`recipes/<platform>.md` frontmatter — bkz. [recipes/README.md](recipes/README.md))
`platform · summary · honesty_constraint · credential_intake · token_mint · scopes · forbidden ·
verify · cli_tool · env_var · confidence · sources`

## Bilinen reçeteler (`recipes/` — adversaryal-doğrulanmış, 6 Tem 2026)
Yeni platform = Adım 2 bilgi tabanını otomatik büyütür. Ortak gerçek: **hiçbirinde kullanıcı-adı+şifre
→ token API'si YOK** (dürüstlük guard'ı). "mint" = skill programatik dar-token üretebilir mi?

| Platform | env | mint | Kritik gotcha (tam: `recipes/<x>.md`) |
|---|---|---|---|
| [github](recipes/github.md) | `GITHUB_TOKEN` | dashboard (PAT) | Scoped programatik token YALNIZ GitHub App installation-token (JWT→`/app/installations/{id}/access_tokens`, 1sa); `gh auth login`=device-flow; **`gh secret set --body-file` diye bayrak YOK** → stdin |
| [google-cloud](recipes/google-cloud.md) | `GOOGLE_APPLICATION_CREDENTIALS` | ✅ (SA/impersonation) | service-account JSON / ADC; kısa-ömürlü = SA impersonation (`iamcredentials`); JSON anahtarı sızıntı riski |
| [railway](recipes/railway.md) | `RAILWAY_API_TOKEN` | dashboard | **`railway variables --set` YASAK** (argv→transkript); ACCOUNT vs WORKSPACE vs PROJECT token + env ayrımı (`RAILWAY_TOKEN`≠`RAILWAY_API_TOKEN`); CLI v5 workspace-token'ı reddedebilir (#845) |
| [vercel](recipes/vercel.md) | `VERCEL_TOKEN` | dashboard | Kişisel-token device-flow YOK; token dashboard'da üretilir; team/expiry scope |
| [supabase](recipes/supabase.md) | `SUPABASE_ACCESS_TOKEN` | dashboard (PAT) | Management-API PAT ≠ `service_role` key; service_role ASLA client'a; iki-katlı dürüstlük |
| [openai](recipes/openai.md) | `OPENAI_API_KEY` | dashboard | Project-scoped key + service-account; key basan OAuth akışı yok |
| [anthropic](recipes/anthropic.md) | `ANTHROPIC_API_KEY` | dashboard | **Admin API bile inference key ÜRETEMEZ**; key yalnız Console'dan; workspace-scoped |
| [aws](recipes/aws.md) | `AWS_ACCESS_KEY_ID` | ✅ (STS) | IAM access key; kısa-ömürlü = STS `AssumeRole`/session token tercih; long-lived key kaçın |
| [digitalocean](recipes/digitalocean.md) | `DIGITALOCEAN_ACCESS_TOKEN` | dashboard | Custom-scoped PAT (dashboard); `doctl` |
| [hetzner-cloud](recipes/hetzner-cloud.md) | `HCLOUD_TOKEN` | dashboard | Project-scoped token (read/write) dashboard-only; `hcloud`; token proje bazında izole |

## Doktrin bağları
- **Altın Kural:** üretilen/geliştirilen her skill **Sx-Claude-Skills'e** yazılır (tek kaynak), oradan
  `sync-skills.mjs` ile dağıtılır. Kurulu kopyayı yerinde düzenleme (drift) → senkron motoru uyarır.
- **Sır-hijyeni:** sır değeri asla dosya/chat/log/argv'ye — yalnız `cortex-access.env` (600) + registry pointer.
- **Dürüstlük:** olmayan yeteneği (şifre→token) vaat etme; 3-durumlu doctor ile kanıtla.
