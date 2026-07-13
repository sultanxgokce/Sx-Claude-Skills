---
name: erisim
type: agent
version: 1.0.0
description: >
  ERİŞİM-ZİNCİRİ dispatcher — ajanın TEK giriş-noktası. `erisim <platform>` → platform-erisim skill'i
  VAR ise ona delege eder (skill zaten vault-first: sırrı Infisical'dan çeker), YOK ise SERDAR'a
  Skill-İstek bırakır; sır-eksikse Sultan'a F5 Vault-İstek düşer. Ajan zinciri ezberlemez, dispatcher
  yürütür. Değer stdout/log/chat'e ASLA. `<platform> [arg…] · <platform> --sir-iste · doctor`.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [erisim, vault, credential, dispatcher, access-chain, on-demand]
---
# erisim — Erişim-Zinciri Dispatcher

`bash scripts/erisim.sh <platform> [iş-argümanları…]` — bir işe `<platform>` erişimi lazımsa **tek komut**.
Ajan zinciri ezberlemez; dispatcher yürütür (DESIGN §A karar-zinciri protokolü). E3 vault-first'ün üstüne oturur.

## Zincir (dispatcher'ın yürüttüğü refleks)
```
erisim <platform> [arg…]
 1. <platform>-erisim skill VAR MI?
    ├─ VAR → script'e DELEGE (argsız → doctor). Skill zaten vault-first → sırrı Infisical'dan çeker.
    │        └─ sır yok/geçersiz (rc≠0) → dispatcher dürüst-etiket + öneri: 'erisim <platform> --sir-iste'
    └─ YOK → SKILL-İstek EMIT (SERDAR-kuyruğu) → '⏳ bekliyor'-etiket (id) → hazır-olunca tekrar dene
```
⛔ **YASAK:** elle-UI'dan-token-alma · değeri-chat'e-yazma · protokol-dışı-workaround (Engel-Doğrulama emsali).

## Alt-komutlar
| Komut | Ne yapar |
|---|---|
| `erisim <platform> [arg…]` | skill-VAR→delege · skill-YOK→SKILL-İstek emit |
| `erisim <platform> --sir-iste [neden]` | skill-VAR ama sır-eksik → F5 Vault-İstek (sır-türü) emit |
| `erisim doctor` | dispatcher 3-durum: kurulu-skill listesi · emit-token var/yok · NEXUS_URL-reach |
| `erisim help` | yardım |

## Emit kanalı (F5 Vault-İstek — REUSE, yeni-uç YOK)
- **Uç:** `POST $NEXUS_URL/api/defter/vault-istek` (Bearer `VAULT_ISTEK_TOKEN`; default NEXUS_URL=`nexusapp.up.railway.app`).
- **Body:** `{key, path, env, neden, isteyen}` — **sır-DEĞERİ TAŞIMAZ** (route DEĞER-YOK-guard: `deger/value/secret/sifre/password/sir/token` alanı → 400). Token argv'ye düşmez (`curl --config -` stdin).
- **Skill-YOK → SKILL-İstek (geçici-konvansiyon):** `key="SKILL:<platform>"`, `path="/istek"`, `env="prod"`.
  ⚠️ **Tür-alanı (E1) henüz yok** → bu `key`-öneki geçici konvansiyondur; E1 `tur: sir|skill|erisim` alanı gelince **gerçek `tur=skill`'e migrate** edilir (SERDAR-poll o zaman öneki değil türü filtreler).
- **Sır-eksik → Vault-İstek (sır-türü):** `key="<PLATFORM>"`, `path="/shared"`, `env="prod"` (F5-mevcut sır-akışı).

## Emit-token çözüm-sırası (değer-basılmaz)
`VAULT_ISTEK_TOKEN`: env → `~/.config/cortex-access.env` → `/config/projects/Nexus/ui/.env` → yoksa **dürüst**:
"emit-token yok — bu container'a dağıtılmamış; SERDAR'a bildir". Token-DEĞERİ asla stdout/log/chat'e.

## `isteyen` tespiti
`$EKIP_UYE` → `$AGENT_NAME` → yoksa `bilinmiyor(<hostname>:<cwd>)` (uydurma-kimlik YOK; dürüst-kestirim kabul).

## Değişmezler
- Değer stdout/log/chat'e **ASLA** · mevcut skill-kontratlarına **dokunmaz** (yalnız delege).
- Delege-script çözümü: `scripts/<platform>.sh` → yoksa tek `scripts/*.sh` (⚠️ cloudflare-erisim script'i `cf.sh`≠`cloudflare.sh` — fallback bunu yakalar).
- Sır-eksik AYRIMI (missing≠invalid≠network) dispatcher'dan güvenilir yapılamaz → skill-VAR-fail'de **OTO-emit YOK**, açık `--sir-iste` önerisi (yanlış-emit önler).
- Yayım/Sx-port + CLAUDE.md-refleks-bloğu = **SERDAR (E4/E5)**; bu skill /config/.claude/skills/erisim'de canlı (ortak-mount → her-container).

## Doktrin bağları
- Erişim-Zinciri DESIGN: `_agents/handoff/mimserdar-erisim-zinciri-DESIGN.md` (§A karar-zinciri · §B F5-genişletme · §C SERDAR-prosedür · §E yetki-modeli).
- REUSE: `vault-cek` (E3 vault-first) · F5 `vault-istek` uç (PR#357) · `erisim-skill-fabrikasi` (yeni-platform mint).
