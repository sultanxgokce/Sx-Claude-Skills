---
name: vault-cek
type: agent
version: 1.4.0
description: >
  Merkezî Vault'tan (OpenBao central-vault; 2026-08-07 L54 cutover) sır çeker → cortex-access.env. On-demand:
  Sultan sırları bir kez vault'a koyar, her container kendi AppRole kimliğiyle self-servis çeker.
  KEY→path: `<KAYNAK>__<KEY>`→/kaynak (açık hedef); `__`-siz→ÖNCE kutunun kendi kiracı klasörü,
  bulunamazsa /shared (L68/F3). Değer stdout/log/chat'e ASLA.
  `doctor · resolve · list · get <KEY> · put <KEY> · backend`.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [vault, openbao, infisical, credential, secret, on-demand, central-vault, mmex]
---
# vault-cek — On-demand Merkezî Vault (OpenBao · CUTOVER-DONE 2026-08-07)
`bash scripts/vault-cek.sh get <KEY>` → `<KEY>`'i merkezî kasadan çeker, `cortex-access.env`'e (600)
yazar (değer basmadan). Değer stdout/log/chat'e ASLA.

## KEY → yol çözümü (v1.4.0 · KENDİ-KİRACI-ÖNCE)
| KEY biçimi | Nereye bakılır | Not |
|---|---|---|
| `<KAYNAK>__<KEY>` (ör. `VEKATIP__DATABASE_URL`) | `secret/<kaynak>/<KEY>` | **AÇIK HEDEF — daima kazanır**, bu kuraldan etkilenmez |
| `--path <p>` / `$VAULT_PATH` | `secret/<p>/<KEY>` | override; öneksiz-yolu kapatır |
| `<KEY>` (öneksiz, ör. `PCLOUD_AUTH_TOKEN`) | **1.** `secret/<kendi-kiracı>/<KEY>` → **2.** `secret/shared/<KEY>` | v1.4.0'da eklenen adım 1 |

**Niçin:** bir anahtarı bir ajana vermek tek komut olsun diye — `vault-cek put SEDIR__PCLOUD_AUTH_TOKEN`
yeter; alıcı beceri **hiç değişmeden** onu bulur. Öncesinde beceriler `shared`'a bakıyor, anahtar ise
kiracının kendi klasöründe duruyordu (canlı vaka 2026-08-14: SEDİR pCloud'a giremedi — *izin doğruydu,
adres yanlıştı*).

**Kutu kendi kiracı adını nereden bilir:** AppRole login **yanıtından** — `token_policies` içinde tek bir
`tenant-<ad>` varsa ondan, yoksa `metadata.role_name`'den. Provizyon değişmezi bunu garanti eder
(`bao-provizyon.sh`: policy = `tenant-<ad>` ∧ AppRole rol adı = `<ad>`). **Ek ağ turu YOKTUR** —
`lookup-self` çağrılmaz, bilgi zaten yapılan login'in yanıtındadır. Saklanan yanıt token'dan
arındırılmıştır (yalnız policy adları + rol adı; ikisi de sır değil).

**Fail-open değil, fail-BACK:** kiracı türetilemezse (policy yok · birden çok `tenant-*` ∧ rol-adı da yok ·
jq yok · login JSON'u okunamadı) ya da kendi klasöründe okuma yasak/boşsa **sessizce eski davranışa
(`shared`) düşülür** — hata basılmaz, kimse kırılmaz. Elle sabitleme gerekirse: `VAULT_TENANT=<ad>`.

**Geriye uyum:** kendi klasöründe kopyası olmayan kutu bugünkü gibi `shared` görür. `put` **değişmedi** —
öneksiz `put` hâlâ `shared`'a yazar; kiracıya yazmak için `<KAYNAK>__<KEY>` ya da `--tenant` kullanılır.

**Maliyet (ölçüldü 2026-08-14, bu kutu):** login **+0** istek. Öneksiz anahtar kendi klasöründe bulunursa
toplam 2 istek (**değişmedi**); yalnız `shared`'da varsa 3 istek (**+1 KV okuması**). Açık hedefli
`<KAYNAK>__<KEY>` 2 istek (**değişmedi**).

**Hangi yol çözüldü:** `get` çıktısı sonunda `yol=kendi-kiracı|shared|açık-hedef` der; `resolve` kutunun
türetilmiş kiracı adını basar (`kiracı: nexus`) ya da türetilemediğini söyler.

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
- Çevrimdışı sınamalar (CI): `scripts/vault-cek-put.test.sh` (T1..T10) ·
  `scripts/vault-cek-tenant.test.sh` (T1..T12 — kendi-kiracı-önce ad-türetmesi, traversal kalkanı,
  geriye-uyum değişmezi, token-sızmazlığı).

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
