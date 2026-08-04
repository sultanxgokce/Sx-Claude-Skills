---
name: vault-cek
type: agent
version: 1.1.1
description: >
  Merkezî Vault'tan (Infisical central-vault; 2026-07-10 cutover) sır çeker → cortex-access.env. On-demand:
  Sultan sırları bir kez vault'a koyar, her container machine-identity (Universal Auth) ile self-servis çeker.
  KEY→path: `<KAYNAK>__<KEY>`→/kaynak; `__`-siz→/shared. Değer stdout/log/chat'e ASLA. `doctor · resolve · list · get <KEY>`.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [vault, infisical, credential, secret, on-demand, central-vault, mmex]
---
# vault-cek — On-demand Merkezî Vault (Infisical · CUTOVER-DONE 2026-07-10)
`bash scripts/vault-cek.sh get <KEY>` → `<KEY>`'i Infisical `central-vault` projesinden çeker,
`cortex-access.env`'e (600) yazar (değer basmadan). KEY→path: `<KAYNAK>__<KEY>` → `/kaynak` folder + `<KEY>`; `__`-siz → `/shared` (ör. `CLOUDFLARE_API_TOKEN`, `VEKATIP__DATABASE_URL`).
Auth = machine-identity Universal Auth: consumer-node başına `~/.config/infisical/identity.env` (CID/CSEC/PROJECT_ID, 600; hardcode-YOK). Bağımlılık: `infisical` CLI (`npm i -g @infisical/cli`). Cloud/self-host agnostik (`INFISICAL_DOMAIN`/`--domain`). Değer stdout/log/chat'e ASLA.
Komutlar: `doctor` (3-durum) · `resolve` · `get <KEY>` · `list [<kaynak>]` (KEY-adları, değer-yok).

## Seam — swappable backbone (cutover-DONE)
Canlı `scripts/vault-cek.sh` = Infisical adaptörü (2026-07-10 cutover; nexus'ta uçtan-uca kanıtlandı). **Kontrat backbone'dan bağımsız** → consumer rewire-YOK (seam kanıtı). Rollback: `scripts/vault-cek-railway.sh` (eski Railway-Vault adaptörü). Kaynak-adaptör: `scripts/vault-cek-infisical.sh`.
**F3 provizyon (Sultan-kapısı):** her consumer-container'a `identity.env` gerekli — serdar-cli identity-CREATE yetkisiz (403), Sultan Infisical-UI'da machine-identity açar + `/shared` read verir + CID/CSEC'i o container'a koyar. identity.env yoksa `vault-cek` açık remediation'la durur (silent-break YOK).
