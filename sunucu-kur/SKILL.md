---
name: sunucu-kur
type: agent
version: 1.0.0
description: >
  Bir servis için yeni sunucu (Hetzner VPS) kurulmasını gereken TEK-akışa bağlar: ortam-probe →
  röportaj → dry-run önizleme-DURAK → Sultan-onay → değer-güvenli provizyon → healthz-doğrula →
  kayıt. İzole reis çağırırsa (VPS-erişimi yok) SERDAR'a istek-emit eder. Sunucu OLUŞTURMA yıkıcı →
  Sultan-gate. Sır-değer ASLA basılmaz. hcloud + Infisical, saf-CLI.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [vps, hetzner, provizyon, sunucu, deploy, infra, cloud-init, serdar, hcloud]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Sunucu-Kur — reis sunucu ister → şak şak şak

## Bağlam
İzole reisler (SİNAN/mmex · REİSÜLKÜTTAB/vekatip · HEKİMBAŞI/medigate · DEFTERDAR/huma) statik-IP
servis / daemon-host / prod-izole-kopya için VPS ister ama **kendileri kuramaz** (container host-SSH
yapamaz + Hetzner-token yalnız vault `/nexus`'ta SERDAR-only). Bu skill o akışı tek-standarda bağlar.
Kanonik komut-toolkit: kurulumdan sonra `~/.claude/skills/sunucu-kur/scripts/provision-vps.sh`.
Tam runbook: `Nexus/_agents/runbooks/vps-provizyon.md`.

## GERÇEK KISIT (dürüstçe söyle)
- Hetzner Cloud'da **şifre→token API'si YOK**; token panelden bir kez üretilir, scope yalnız iki-seviye
  (Read | Read&Write, proje-geneli). Reçete: `erisim-skill-fabrikasi/recipes/hetzner-cloud.md`.
- Provizyonu **yalnız SERDAR@nexus** yapabilir (token+context orada). İzole reis çağırırsa iş **istek-emit**e döner.
- **Bu skill iki VPS-arketipinden yalnız DOCKER-SERVİS tipini kurar** (auth-broker gibi). Systemd-ajan-filosu
  VPS'i ayrı yoldan: `Nexus/deploy/install.sh` + `_agents/runbooks/install-vps.md` (bu skill onu tekrar etmez).

## AKIŞ

### 0 · Ortam-probe (ground-truth — dallanma)
```bash
bash ~/.claude/skills/sunucu-kur/scripts/provision-vps.sh preflight
```
- **Yeşil** (hcloud erişimi canlı = SERDAR@nexus) → **provizyon-modu**, Adım 1.
- **Kırmızı** (erişim yok = izole-reis) → **istek-modu**: bu container VPS kuramaz. `erisim` dispatcher üzerinden
  SERDAR'a istek-emit et (erişim-zinciri; `/api/defter/vault-istek`, `key="SKILL:sunucu-kur"`, **değer-taşımaz**) →
  reise "SERDAR'a iletildi, o kuracak" de. DUR. (Doğrudan ssh/exec deneme — yapısal-yetki-sınırı.)

### 1 · Röportaj (AskUserQuestion) — talebi netleştir
Sultan/reis'e sor (varsayma): **servis-adı & amaç** · **sağlayıcı/boyut/bölge** (default Hetzner `cx23`/`hel1`) ·
**referans-repo** (lift-shift kaynağı) · **env hangi vault-folder'dan** (`/mmepanel`, `/mmex`, `/nexus`…) & hangi anahtarlar ·
**stabil-URL** (nip.io-direct mı, CF-named-tunnel mı — IP gizlenecekse tunnel) · **healthz port/path**.
8-blok talep-anatomisi + MUTLAK-SINIRLAR (eski/prod-sunucuya DOKUNMA, ayrı-temiz-IP, gated-canlı-adımlar) için runbook.

### 2 · Dry-run önizleme-DURAK (yazma-ÖNCESİ göster)
`provision-vps.sh preflight → context-ensure → sshkey-ensure` (bunlar güvenli/idempotent) koş, sonra:
```bash
provision-vps.sh create --name <ad> --ssh-key <keyad> --type <tip> --location <bölge> --cloud-init <şablon>
```
`--apply` OLMADAN → ne oluşturulacağını (tip/bölge/isim/keyler) basar, **oluşturmaz**. Bunu Sultan'a göster.

### 3 · Sultan-gate tek-soru (create = YIKICI/masraflı)
> "Şu sunucu oluşturulacak: `<özet>`. Onaylıyor musun? (evet/hayır)"
Sadece Sultan "evet" der (ajan onay-üretmez). **Evet → `create ... --apply`.** Yeni-sağlayıcı ilk-token / geniş-scope
= ayrıca Sultan-gate (erişim-zinciri §E).

### 4 · Provizyon (değer-güvenli) — create sonrası
```bash
# cloud-init bekle → ssh (root@<ip> -i ~/.ssh/nexus_vps)
provision-vps.sh env-inject <ip> /etc/<servis>.env <folder> <KEY1,KEY2,...> [extra-config]  # 600, değer-basmaz
# lift-shift (rsync yerel-YOK → tar):  tar czf - --exclude=.git . | ssh root@<ip> 'tar xzf - -C /opt/<servis>'
# /data uid-fix cloud-init-base'de (uid 1500); eski şablon kullanılıyorsa: ssh root@<ip> 'chown -R 1500:1500 /data'
# docker compose up -d --build --force-recreate   (restart YETMEZ — env değişince recreate)
```
Sürtünme-fix'leri (uid-1500 · uv-yok→infisical-direct · rsync-yok→tar · ssh-key-register) toolkit + cloud-init-base'de gömülü;
detay `known-errors.md → VPS-Provizyon Sürtünmeleri`.

### 5 · Doğrula + kayıt + rapor
```bash
provision-vps.sh healthz <ip> <port> [path]   # 200 bekle
```
- **Stabil-URL**: nip.io-direct (Caddy+LE) ya da CF-named-tunnel (`cloudflare-erisim` skill; IP-gizle) → URL'i vault'a yaz.
- **Kayıt**: yeni VPS'i `Nexus/_agents/credentials.yaml` envanterine + `SESSION`/serdar-defter anchor'a; lint koş.
- **Rapor**: Sultan-dili tek-satır + isteyen-reise "kuruldu, healthz-200, URL=<x>".

## Değişmezler (sır-hijyeni + yetki)
- Sır DEĞERİ stdout/argv/chat/log'a ASLA (toolkit infisical→shell-var→ssh-pipe; yalnız anahtar-adı+uzunluk).
- `hcloud`/vault token'ı argv'ye ASLA; `vault-cek get` KULLANMA (container'da uv-yok → sessiz-fail) → toolkit infisical-direct.
- Sunucu **OLUŞTURMA/SİLME = Sultan-gate** (dry-run + tek-soru); ajan onay-üretmez.
- Eski/prod sunuculara (ör. broker-prod 135.181.85.212) DOKUNMA; ayrı-temiz-IP.
- Canlı-dış-etkileşim (ör. gerçek 3P-login) = ayrı Sultan-onayı + isteyen-reis-teyidi (faz-ayrımı: risksiz-kurulum ≠ canlı-git).

## Sınırlar
- Toolkit `scripts/provision-vps.sh` (subcommand'lı) + `templates/cloud-init-base.yaml` skill ile gelir; hcloud+infisical+jq yeter.
- Multi-provider (DigitalOcean/AWS) genişleme = `erisim-skill-fabrikasi` reçete-deseni (reçeteler hazır); bu sürüm Hetzner-odaklı.
