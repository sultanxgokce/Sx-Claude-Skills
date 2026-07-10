---
name: railway-erisim
type: agent
version: 1.1.0
description: >
  Railway erişimi gereken işleri (staging/prod DB provision & DATABASE_URL alma, servis/değişken
  sorgusu, deploy durumu, ham GraphQL) PANELE GİRMEDEN, saf API (curl+jq) ile yapar. Kimlik yoksa
  kullanıcıya BİR KERELİK gizli token girişi sorar (Railway token programatik ÜRETİLEMEZ →
  dashboard-only), cortex-access.env'e (600) kaydeder, sonra asıl işi idempotent + sır-hijyenik yapar.
  (erisim-skill-fabrikasi · cloudflare-erisim şablonundan üretildi.)
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [railway, erisim, platform-access, token, database, graphql, setup]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Railway Erişim — panele girmeden proje/servis/DB

## Bağlam
Bir ajan "Railway erişimi gereken bir iş" (proje/servis listesi, bir servisin `DATABASE_URL`'i,
deploy durumu, ham GraphQL sorgusu) istediğinde kullanıcının her seferinde dashboard'a girmesi
angarya. Bu skill o işi **tek-sefer token girişi + kalıcı env** ile devralır. `railway` CLI GEREKMEZ —
saf Railway GraphQL API (curl+jq, endpoint `backboard.railway.com/graphql/v2`).

Kanonik CLI: kurulumdan sonra `~/.claude/skills/railway-erisim/scripts/railway.sh`.

## GERÇEK KISIT (dürüstçe söyle)
Railway'in **kullanıcı-adı+şifre → token** API'si YOKTUR. Kalıcı token'lar YALNIZ dashboard'da
(`railway.com/account/tokens`, login+2FA arkasında) elle üretilir; geniş kimlikten dar token türeten
belgelenmiş public mutation da YOK. Yani skill token **üretemez/daraltamaz** → doğru-kapsamlı token'ı
kullanıcıdan **bir kez** hazır alır. Şifreyle giriş / otomatik token üretimi sözü VERME.
(`railway login --browserless` bir device-pairing akışıdır → taşınabilir API token değil, CLI'nin yerel
oturum anahtarını üretir; headless senaryoda işe yaramaz.)

### Token türleri (least-privilege — dardan genişe)
| Tür | Kapsam | Header | Env | `set-token` |
|---|---|---|---|---|
| **PROJECT** | tek proje+ortam | `Project-Access-Token` | `RAILWAY_TOKEN` | `set-token project` |
| **WORKSPACE** | bir workspace'in tüm projeleri | `Authorization: Bearer` | `RAILWAY_API_TOKEN` | `set-token` |
| **ACCOUNT** | tüm workspace+kaynaklar | `Authorization: Bearer` | `RAILWAY_API_TOKEN` | `set-token` |

Bu skill'in ağırlığı **ham GraphQL API işi** → WORKSPACE/ACCOUNT (Bearer) ana yol; tek proje işi için
PROJECT token (en dar) tercih et. **İkisini birlikte kaydetme** (öncelik belirsiz) → `set-token` her
zaman diğerini siler.

## Akış

### 1. Önce doktor — kimlik zaten var mı?
```bash
bash ~/.claude/skills/railway-erisim/scripts/railway.sh doctor
```
- **Yeşil** (token geçerli, kapsam ACCOUNT/WORKSPACE olarak ayırt edildi) → doğrudan **Adım 4**.
- **Kırmızı** (token yok) → **Adım 2**.

### 2. Bir kerelik token — kullanıcıya NET yönerge ver
(Gizli TTY girişi; kendin çalıştıramazsın — kullanıcı bir **terminalde** yapar. Panelde `!` önekiyle.)
> Railway token'ını bir kez vereceksin (şifre değil):
> `railway.com/account/tokens` → **Create Token** (least-privilege: tek proje işi ise Proje → Settings
> → Tokens'tan **PROJECT** token) → kopyala, sonra:
> ```bash
> bash ~/.claude/skills/railway-erisim/scripts/railway.sh set-token          # account/workspace (Bearer)
> # veya tek proje için:
> bash ~/.claude/skills/railway-erisim/scripts/railway.sh set-token project  # PROJECT (Project-Access-Token)
> ```
- Girdi **gizli** okunur (ekrana/geçmişe düşmez), `~/.config/cortex-access.env`'e (600) yazılır.

### 3. Doğrula
```bash
bash ~/.claude/skills/railway-erisim/scripts/railway.sh doctor   # yeşil bekle
```

### 4. Asıl işi yap
```bash
bash ~/.claude/skills/railway-erisim/scripts/railway.sh projects                       # görünür projeler (id'ler)
bash ~/.claude/skills/railway-erisim/scripts/railway.sh services <projectId>           # ortam+servis id'leri
bash ~/.claude/skills/railway-erisim/scripts/railway.sh pg-url <pid> <eid> <sid> [ENV] # DATABASE_URL → env'e YAZ (basmaz)
bash ~/.claude/skills/railway-erisim/scripts/railway.sh gql '<query>' '[vars-json]'    # ham GraphQL kaçış-kapısı
```
`pg-url` DATABASE_URL'i `cortex-access.env`'e (varsayılan `DATABASE_URL` anahtarı, ya da `[ENV]` ile
verdiğin ad) **yazar** ve **DEĞERİ stdout'a BASMAZ**. Değişken bulunamazsa yalnız anahtar *adlarını*
listeler (değer yok).

### 5. Raporla
Çıktının `✓/•/✗` satırlarını kullanıcıya ilet. Değer içeren ham `gql` çıktısını log/transkripte dökme.

## Kalıcılık & sır-hijyeni
- Token YALNIZ `~/.config/cortex-access.env` (600) içinde; **değer asla stdout/log/chat/geçmişe düşmez**.
- Kanonik pointer: `Nexus/_agents/credentials.yaml` → `[SIR: … railway-*]`.
- **🚫 `railway variables --set "KEY=VALUE"` YASAK** — değer argv'ye → `ps`/process-list + shell history +
  ajan transkriptine SIZAR. Sır set etmek gerekiyorsa dashboard (mümkünse SEALED variable). `railway
  variables` / `railway run` sealed-olmayan değerleri stdout'a düz-metin basar → çıktıyı dökme.
- Token'ı curl argv'sine `-H 'Authorization: Bearer <tok>'` diye YAZMA → skript env'den okur.

## ⚠️ Token CONTAINER-YERELDİR (en sık tekrarlayan tuzak)
`cortex-access.env` her container'ın kendi kalıcı `/config`'inde yaşar ve **container'lar arası
senkronlanmaz** (sync-skills SKILL dosyalarını dağıtır, sırrı DEĞİL). Sonuç: skill her yerde yüklü
görünse de, **her aktif container'da bir kez `set-token` gerekir** (izole vekatip/mmex/medigate dâhil).
Bir container "railway'e ulaşamıyorum / kimlik yok" diyorsa neden neredeyse her zaman budur → o
container'da `set-token` çalıştır. (Tüm container'lara tek broad token'ı elle-tekrarsız yaymak =
"paylaşımlı-sır senkronu"; host-aracılı stdin-pipe ile değer-sızdırmadan yapılır — NÂZIR/host işi.)

## Notlar / sınırlar
- `me { email }` sorgusu **SADECE ACCOUNT token** ile çalışır (WORKSPACE/PROJECT'te değil) → `doctor`
  önce `me`, olmazsa `projects` sorgusuyla doğrular ve kapsamı otomatik ayırt eder.
- Mevcut `railway` CLI (v5) **WORKSPACE-scoped** token'ı reddedebilir (upstream issue #845) → CLI işi
  için ACCOUNT/PROJECT token daha güvenli; bu skill ham API kullandığından etkilenmez.
- Kaynak `scripts/railway.sh` skill ile birlikte gelir; ek kurulum gerekmez (jq + curl yeter).
