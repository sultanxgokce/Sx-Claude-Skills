---
name: cloudflare-erisim
type: agent
version: 1.1.0
description: >
  Cloudflare erişimi gereken işleri (Access self-hosted app + policy, proxied DNS/tünel rotası,
  subdomain'i giriş-kapısı arkasına alma) PANELE GİRMEDEN, saf API (curl+jq) ile yapar. Kimlik yoksa
  kullanıcıya BİR KERELİK gizli giriş sorar (Global API Key), kendi DAR-YETKİLİ token üretir, env'e
  kaydeder, sonra asıl işi yapar ve bir daha sormaz. İdempotent + sır-hijyenik. cloudflared GEREKMEZ.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [cloudflare, access, dns, tunnel, kimlik, erisim, token, setup, zero-trust]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Cloudflare Erişim — panele girmeden Access/DNS

## Bağlam
Bir ajan "Cloudflare erişimi gereken bir iş" (Access app, DNS, subdomain koruması) istediğinde
kullanıcının her seferinde dashboard'a girmesi angarya. Bu skill o işi **tek-sefer giriş + kalıcı
dar-yetkili token** ile devralır. cloudflared GEREKMEZ — saf Cloudflare API (curl+jq).

Kanonik CLI: kurulumdan sonra `~/.claude/skills/cloudflare-erisim/scripts/cf.sh`
(cloudtop'ta `.claude` ortak-mount → tüm konteynerlerde görünür).

## GERÇEK KISIT (dürüstçe söyle)
Cloudflare'ın **kullanıcı-adı+şifre → token** API'si YOKTUR (dashboard 2FA/CAPTCHA arkasında,
otomatize edilemez). Kullanılabilir tek "ana giriş" = **Global API Key** (ya da hazır bir API Token).
Kullanıcı yalnız onu **bir kez** kopyalar; gerisini skill yapar. Şifreyle giriş sözü VERME.

İki token türü ayrımı KRİTİK:
- **User token** (40 hane, önek yok) → `/user/tokens/verify` ile doğrulanır.
- **Account token** (`cfat_` önekli) → `/accounts/{id}/tokens/verify` ile doğrulanır (aksi halde
  "Invalid API Token" yanılsaması). `cf.sh doctor` bu ayrımı otomatik yapar.

## Akış

### 1. Önce doktor — kimlik zaten var mı?
```bash
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh doctor
```
- **Yeşil** (kimlik geçerli + zone/account çözüldü) → doğrudan **Adım 4**.
- **Kırmızı** (kimlik yok) → **Adım 2**.

### 2. Bir kerelik giriş — kullanıcıya NET yönerge ver
(Gizli TTY girişi; kendin çalıştıramazsın — kullanıcı bir **terminalde** yapar.)
> Cloudflare "ana anahtar"ını bir kez vereceksin (şifre değil):
> `dash.cloudflare.com` → **My Profile → API Tokens → Global API Key → View** ile anahtarı kopyala, sonra:
> ```bash
> bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh login   # e-posta + Global API Key (GİZLİ)
> bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh mint    # dar-yetkili token üret + kaydet, ana anahtarı bırak
> ```
- `login` girdiyi **gizli** okur (ekrana/geçmişe düşmez), `~/.config/cortex-access.env`'e (600) yazar.
- `mint` Global Key ile **Zone.DNS + Account.Access** yetkili token ÜRETİR, saklar, **Global Key'i siler**.
- Alternatif: kullanıcının hazır bir API Token'ı varsa → `cf.sh set-token` (yapıştır, gizli).

### 3. Doğrula
```bash
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh doctor   # yeşil bekle
```

### 4. Asıl işi yap (idempotent)
```bash
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh onboard mmex.mmepanel.com   # Access + DNS (var-ise no-op)
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh access-ensure <host> [email] # yalnız Access app + Allow-policy
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh dns-ensure <host>            # yalnız proxied DNS (tünel rotası)
bash ~/.claude/skills/cloudflare-erisim/scripts/cf.sh list                         # mevcut Access app'leri listele
```
Varsayılan izin = `sultanxgokce@gmail.com` (değiştir: 2. argüman e-posta).

### 5. Raporla + tünel ingress hatırlatması
- Çıktının `✓/•/✗` satırlarını kullanıcıya ilet.
- ⚠️ **Tünel INGRESS** (`hostname → http://localhost:PORT`) HOST'taki `/etc/cloudflared/config.yml`'de
  yaşar; bunu API DEĞİL, host'ta `setup-tunnel.sh` yazar (konteynerden erişilemez). Yeni subdomain'de
  Access+DNS bu skill'le biter; ingress için `ssh <host> 'bash .../setup-tunnel.sh'` adımını hatırlat.

## Kalıcılık & sır-hijyeni
- Token/anahtar YALNIZ `~/.config/cortex-access.env` (600) içinde; **değer asla stdout/log/chat/geçmişe düşmez**.
- Kanonik pointer: `Nexus/_agents/credentials.yaml` → `[SIR: Nexus/credential-registry → cloudflare-*]`.
- **Railway variables:** doktrin gereği `railway variables --set` YASAK (değer process-list'e sızar) →
  gerekiyorsa dashboard'dan. cloudtop ajanları için `cortex-access.env` yeterli (tüm konteynerlerde ortak).
- `~/.cache/cloudflare-access.json` yalnız ID'ler (zone/account/tunnel) — sır değil.

## Notlar / sınırlar
- `cloudtop.mmepanel.com` DNS-only (gri) — `dns-ensure` onu **reddeder** (proxied → SSH/Mutagen kopar).
- Token scope'ları: Zone.DNS:Edit + Account.Access(Apps&Policies):Edit (+ opsiyonel Zero-Trust:Read).
  Global Key ile `mint` bunları otomatik verir.
- Kaynak `scripts/cf.sh` (304 satır) skill ile birlikte gelir; ek kurulum gerekmez (jq + curl yeter).
