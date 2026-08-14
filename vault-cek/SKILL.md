---
name: vault-cek
type: agent
version: 1.3.0
description: >
  Merkezî Vault'tan (OpenBao central-vault; 2026-08-07 L54 cutover) sır çeker → cortex-access.env. On-demand:
  Sultan sırları bir kez vault'a koyar, her container kendi AppRole kimliğiyle self-servis çeker.
  KEY→path: `<KAYNAK>__<KEY>`→/kaynak; `__`-siz→/shared. Değer stdout/log/chat'e ASLA.
  `doctor · resolve · list · get <KEY> · put <KEY> · backend`.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [vault, openbao, infisical, credential, secret, on-demand, central-vault, mmex]
---
# vault-cek — On-demand Merkezî Vault (OpenBao · CUTOVER-DONE 2026-08-07)
`bash scripts/vault-cek.sh get <KEY>` → `<KEY>`'i merkezî kasadan çeker, `cortex-access.env`'e (600)
yazar (değer basmadan). KEY→path: `<KAYNAK>__<KEY>` → `<kaynak>` klasörü + `<KEY>`; `__`-siz → `shared`
(ör. `CLOUDFLARE_API_TOKEN`, `VEKATIP__DATABASE_URL`). Değer stdout/log/chat'e ASLA.
Komutlar: `doctor` (3-durum) · `resolve` · `get <KEY>` · `list [<kaynak>]` (KEY-adları, değer-yok) ·
`put <KEY>` (kasaya YATIR) · `backend` (hangi kasa aktif — teşhis).

## `put` — kasaya yatıran kalem (L68/F1 · yalnız openbao backbone'unda)
```
vault-cek put <KEY> [--tenant <ad>] [--uzerine-yaz] [--stdin]
```
- **Değer argv'ye ASLA düşmez.** İki kaynak var: `--stdin` (borudan) ya da ortamdaki `<KEY>` değişkeni.
  `--deger <x>` gibi bir bayrak **yoktur** — süreç listesine sızardı. Boru: `jq -Rs` → `curl --data-binary @-`
  (`faz4-tasi.sh` deseni; `jq --arg` YASAK). `set -x` altında bile değer görünmez.
- **Üzerine-yazma fail-closed:** hedefte kayıt varsa komut DURUR; ezmek `--uzerine-yaz` ister.
- **Çıktı yalnız** `hedef=<mount>/<klasör>/<anahtar> http=<kod> version=<n>`.
  🔴 "değer doğru yazıldı" **denmez** — merkez kiracı kasasına *yazar ama okuyamaz* (ölü-kutu deseni),
  o iddia kanıtlanamaz. Dürüst ifade: **yazıldı, doğrulaması alıcıda.**
- Yol, `get` ile **aynı** KEY→path kuralından çözülür; `--tenant` hedef klasörü ezer.
- Kabul testi: `bash scripts/kabul-testi-put.sh` (A1..A8, canlı kasa · yalnız kanarya anahtarları).

## Seam — swappable backbone (3. cutover TAMAM)
`scripts/vault-cek.sh` bir **DİSPATCHER**'dır; kontrat backbone'dan bağımsızdır → 91+ tüketici
rewire-YOK (seam kanıtı: Railway → Infisical → OpenBao).

| Backbone | Adaptör | Durum |
|---|---|---|
| **openbao** | `scripts/vault-cek-openbao.sh` | ✅ **CANLI VARSAYILAN** (2026-08-07) |
| infisical | `scripts/vault-cek-infisical.sh` | 🟡 fallback — 30 gün salt-okur, sonra emekli |
| railway | `scripts/vault-cek-railway.sh` | ⚪ legacy |

**Seçim önceliği:** `$VAULT_BACKEND` → `~/.config/vault-backend` (kutu-başına, tek kelime) → varsayılan `openbao`.
**Geri dönüş:** `echo infisical > ~/.config/vault-backend` (o kutu anında eski kasaya döner).
**Sessiz fallback YOK:** openbao düşerse hata döner, gizlice Infisical'a kaçmaz (yanlış-yeşil kalkanı).

> ⚠️ Skill-dizini 13 konteynerde TEK ve ORTAK mount'tur (aynı inode) — buradaki dosyayı değiştirmek
> filoyu tek anda çevirir. `~/.config` kutu-başına ayrıdır; cutover'ın tenant-tenant yürüyebilmesi
> ve tek-kelimeyle geri alınabilmesi bu ayrımdan gelir.

## Kimlik provizyonu (artık panel-siz)
Her consumer-container'a `~/.config/openbao/identity.env` gerekir (`BAO_ADDR`/`BAO_ROLE_ID`/`BAO_SECRET_ID`, 600).
Üretimi **tek komut**: host'ta `BAO_PROVIZYON_GO=1 bash cloudtop/infra/openbao/bao-provizyon.sh <tenant> --apply`
→ teslim-dosyası `/root/l13-tenant-out/<tenant>-identity.env`. Infisical'ın "yalnız Sultan, web panelinden,
kimlik tavanı 4/4 dolu" sürtünmesi bu yüzden ortadan kalktı. identity.env yoksa `vault-cek` açık
remediation'la durur (silent-break YOK).

## İzolasyon (ÜÇ-ÇİT / İ1)
Her tenant `tenant-<ad>` policy'siyle YALNIZ kendi klasörünü + `shared`'ı (salt-okur) görür; çapraz-kiracı
path'ler explicit `deny`. Ölçüm 2026-08-07: 12 çapraz denemeden 11'i reddedildi, izin verilen tek satır
kimliğin KENDİ kapsamıydı.
