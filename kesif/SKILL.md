---
name: kesif
type: agent
version: 0.2.1
description: >
  Canlı web-panel/SPA'yı Playwright (root-suz Chromium) ile insan-gibi çok-senaryo test eden kesif-mini
  apparatı. DOM↔API çapraz-kanıtla panel-yalanını (yanlış-renk/bayat-yeşil) kandırılamayan-saf-kodla yakalar;
  ULTIMATE-dogfood ile sahte-yeşil enjekte edip senaryoların GERÇEKTEN-test-ettiğini kanıtlar (E2E-kırmızı).
  GENERIC/config-driven: endpoint/selector/allowlist/senaryolar proje-config'ten; çekirdek proje-bilmez.
  Güvenlik-omurgası: origin-EXACT allowlist tek-boğaz, artefakt-lokal, canlı-panel garantili-geri-al.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [test, kesif, e2e, playwright, dom-api-caprazi, false-green, enjeksiyon, portable, config-driven]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# /kesif — canlı-panel kesif-mini E2E apparatı (config-driven, proje-bilmez)

Kanon: bu skill GENERIC çekirdek taşır; **proje-değerleri (endpoint/selector/senaryolar/enjeksiyonlar/allowlist)
proje-config'te yaşar** — çekirdeğe sızmaz. İlk-uygulama: MMEx kontrol-paneli.

## Bileşenler (generic çekirdek — `scripts/`)

- `pw/bootstrap.sh` — Playwright'ı ROOT-SUZ canlandırır (micromamba+conda-forge pw-libs zinciri) + Chromium indirir. İdempotent.
- `pw/launch_check.mjs` — güvenlik-selftest: headless-chromium launch + render + **origin-allowlist DENY-zorlanımı** (allowlist-dışı istek BLOKLANIR-kanıtlı).
- `kesif_lib.mjs` — `acStandart()` allowlist-zorlanımlı tarayıcı-oturumu (**origin-EXACT**: `URL.origin` tam-eşleşme; `8000@evil.com`/`8000.evil.com` bypass KAPALI) + trace-lokal.
- `e2e-run.mjs` — senaryo-runner: canlı-panele `goto`, senaryoları koşar (DOM↔API çapraz-kanıt), kanıt-JSON + trace emit. Endpoint/ready-selector senaryo-modülünden (`apiEndpoints`/`readySelector`).
- `enjeksiyon.mjs` — ULTIMATE-dogfood: sahte-yeşil enjekte (bos-asset / mutant-build scratch-outDir), hedef-senaryonun KIRMIZI-döndüğünü kanıtlar; **canlı panel/dist ASLA-dokunulmaz** (mutant Playwright-route ile YERİNDE sunulur), panel/src **garantili-geri-al** (backup+finally + git-diff-temiz teyidi).
- `e2e-env.sh` — LD_LIBRARY_PATH + PW_RUNTIME_DIR kurup node-komutu koşar.
- `selftest/` — allowlist origin-exact bypass-kilit testleri. `fixture-matrix/` — portability-kanıtı (MMEx-dışı statik-panel + config-swap).

## Proje-config (çekirdeğe GÖMÜLMEZ — her proje kendi yazar)

Bir `<proje>/senaryolar.mjs` şu üçünü export eder:
- `apiEndpoints` — `{ key: "/path" }` panelin tükettiği uçlar (runner bağımsız-çeker, `api[key]`).
- `readySelector` — panel-hazır sinyali (React-mount beklenir).
- `senaryolar` — `[{ ad, aciklama, async calistir(page, api) → {gecti, detay} }]` (karar saf-kod, LLM-judge değil).
Ve bir `<proje>/enjeksiyonlar.mjs` → `[{ ad, tip: 'bos-asset'|'mutant-build', dosya?, ara?, yerine?, hedef_senaryo }]`.

## Kullanım (generic — değerler proje-config/CLI'dan)

```bash
# 1) Chromium root-suz canlandır (bir kez):
KESIF_ALLOWLIST="<panel-origin>" bash .claude/skills/kesif/scripts/pw/bootstrap.sh
# 2) Senaryolar (DOM↔API çapraz-kanıt):
sh .claude/skills/kesif/scripts/e2e-env.sh node .claude/skills/kesif/scripts/e2e-run.mjs \
  --panel-url "<panel-url>" --allowlist "<panel-origin>" --senaryolar "<proje>/senaryolar.mjs" --kanit "<dir>"
# 3) ULTIMATE-dogfood (sahte-yeşil enjeksiyon → E2E-kırmızı kanıtı):
sh .claude/skills/kesif/scripts/e2e-env.sh node .claude/skills/kesif/scripts/enjeksiyon.mjs \
  --panel-url "<panel-url>" --allowlist "<panel-origin>" \
  --senaryolar "<proje>/senaryolar.mjs" --enjeksiyonlar "<proje>/enjeksiyonlar.mjs" --kanit "<dir>" --scratch "<scratch>"
```

## Güvenlik-omurgası (değişmez)

- **origin-EXACT allowlist** yalnız panel-origin(ler)i; auth-broker/diğer-servis BLOK. İkinci-port (mutant-serve gerekmez — Playwright-route YERİNDE) → allowlist'e eklenmedikçe ASLA.
- **Dış-test-SaaS YOK** (tek-egress = kendi-LLM-API). Panel-verisi/artefakt dışarı ASLA; trace lokal + redaction-pass.
- **Canlı-panel ASLA-bozuk-bırakma:** enjeksiyon mutant-build scratch-outDir + Playwright-route (canlı-dist korunur) + panel/src garantili-geri-al.

## Portability

`fixture-matrix/kos.sh` — MMEx-dışı statik-panel + config-swap → generic-core değişmeden koşar (endpoint/selector/origin farklı). Promote-öncesi çalıştır: `PORTABILITY-PASS` bekle.

## Kalan (dürüst)

- `/assets/` yol-öneki Vite-varsayımı (mutant-serve); Vite-dışı bundler için config-alanı = gelecek-iş.
- Persona-kütüphanesi / FSM / axe-a11y-tam = Aşama-3/4 (bu skill kesif-MİNİ; canlı-yüzey kapsamlı-tarar, tam-keşif-motoru değil).
