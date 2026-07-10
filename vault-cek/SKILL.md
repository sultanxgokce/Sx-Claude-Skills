---
name: vault-cek
type: agent
version: 1.0.0
description: >
  Railway "Vault" projesinden (shared-var, namespace'li) sır çeker → cortex-access.env. On-demand vault
  (SERDAR+SİNAN mimarisi): Sultan sırları bir kez Vault'a koyar, her container RAILWAY_API_TOKEN ile
  self-servis çeker. Değer stdout/log/chat'e ASLA basılmaz. `doctor · resolve · list · get <KEY>`.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [vault, railway, credential, secret, on-demand, mmex]
---
# vault-cek — On-demand Railway Vault
`bash scripts/vault-cek.sh get <KEY>` → `<KEY>`'i Railway "Vault" projesinden (shared-var) çeker,
`cortex-access.env`'e (600) yazar (değer basmadan). Namespace: `<KAYNAK>__<KEY>` (ör. `VEKATIP__DATABASE_URL`).
Env: `RAILWAY_VAULT_PROJECT` (default 'Vault'). Bağımlılık: railway-erisim (RAILWAY_API_TOKEN).
Mimari: broker'a YAZMAK §3-YASAK olduğu için vault = ayrı Railway projesi (shared-var, skipDeploys, servissiz).

## F2 · Infisical adaptörü (staged — cutover=SERDAR)
`scripts/vault-cek-infisical.sh` = merkezî-vault seam re-point (Railway→Infisical). **Kontrat BİREBİR aynı** (`doctor·resolve·get <KEY>·list`) → consumer'lar rewire-YOK. Auth=machine-identity Universal Auth (`~/.config/infisical/identity.env` → CID/CSEC/PROJECT_ID; hardcode-yok). Cloud/self-host agnostik (`INFISICAL_DOMAIN`/`--domain`). Değer stdout/log/chat'e ASLA (get→`cortex-access.env` 600). KEY→path: `<KAYNAK>__<KEY>`→`/kaynak`+`<KEY>`; `__`-siz→`/shared`. **CUTOVER** (F1/F3 provision hazır olunca, SERDAR): `mv scripts/vault-cek-infisical.sh scripts/vault-cek.sh` + `infisical` CLI kur (`npm i -g @infisical/cli`). Şu an Railway-adaptör canlı (non-breaking).
