---
name: notion-erisim
type: agent
version: 1.0.0
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
description: Notion erişimi gereken OKUMA işlerini (veritabanı listele/sorgula, sayfa oku, ek dosya indir) PANELE GİRMEDEN, saf API (curl+jq) ile yapar. SALT-OKUR — yazma fiili YOKTUR. Vault-first: jetonu önce vault-cek (secret/<kiracı>/NOTION_TOKEN), sonra cortex-access.env'den DEĞER-görmeden çözer. Zorunlu Notion-Version başlığı + gerçek sayfalama (has_more/next_cursor) + imzalı-süreli dosya URL'lerini anında indirme. (erisim-skill-fabrikasi · pcloud-erisim emsali.)
tags: [notion, erisim, platform-access, salt-okur, read-only, vault-first, setup]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# notion-erisim (SALT-OKUR)

Notion API'sine **panele girmeden** saf `curl`+`jq` ile eriş. Jeton ortam-store'undan
**değer-görülmeden** çözülür. Talep: SİNAN/MMEx (MENZİL filo-verisi Sultan'ın Notion'ında).

## 🔴 KAPSAM: yalnız OKUMA
`create/update/delete/append` **yoktur ve eklenmeyecek** — Notion Sultan'ın kendi çalışma alanı,
ajan yazması karışıklık üretir (SİNAN talebi md.3, Sultan-onaylı). Yazma gerekirse ayrı irade
+ ayrı sürüm ister. Tek POST ucu `databases/{id}/query`'dir; o Notion'da **okuma**dır (filtre
gövdede taşınır). Bu değişmez testle kilitli (`notion.test.sh` T2/T5).

## Kullanım
```bash
S=~/.claude/skills/notion-erisim/scripts/notion.sh
bash $S doctor                                   # 3-durum: yeşil / kırmızı(fail:neden) / doğrulanmadı
bash $S db-list [--limit N] [--sayfa-tavani N]   # erişilebilen veritabanları (tekilleştirilmiş)
bash $S db-query <db_id> [--limit N] [--json]    # satırlar (tam sayfalama; --json = saf JSONL)
bash $S page-get <page_id> [--json]              # sayfanın alanları (insan-okur döküm)
bash $S file-download <page_id> <alan_adı> <hedef_dizin>   # files-tipi alanın eklerini indir
bash $S fingerprint                              # jeton kimlik-teyidi (sha256 ilk-12, DEĞER-yok)
```
`erisim` dispatcher'ı üzerinden de çalışır: `erisim notion db-query <db_id>`.

## 🔴 Üç tuzak (saat yiyenler — ölçülmüş)
1. **`Notion-Version: 2022-06-28` başlığı ZORUNLU.** Yoksa Notion **400** döner ve mesaj
   "jeton geçersiz" gibi okunur. Skill başlığı her istekte gönderir; `doctor` kırmızıya düşerse
   400/validation_error'ın jeton sorunu **olmadığını** açıkça yazar. (Test T8 bunu kilitler.)
2. **POST gövdesi `printf … | curl --data-binary @-` ile GİTMEZ** — stdin'i `-K -` heredoc'u tutar,
   gövde sessizce **boş** gider: Notion 200 döner ama filtre ve `start_cursor` uygulanmaz →
   sayfalama aynı ilk sayfayı sonsuz döndürür. Bu canlıda yakalandı; gövde artık geçici dosyadan
   verilir. (Test T9/T11 kilitler.)
3. **Sayfa entegrasyona paylaşılmamışsa** jeton geçerli olsa da `object_not_found` gelir.
   `doctor` "paylaşım" satırıyla bunu ayırt eder; `db-query`/`page-get` hatasına ipucu ekler.
   **Ölçüm (2026-08-16, bu kutu):** hedef veritabanı `265b0342a61180c99c81ce13e300eca1`
   (**"Araçlarımız"**) → `GET /v1/databases/{id}` **200** · `POST …/query` **200, 13 satır** →
   paylaşım tuzağı bu veritabanında **YOK**, Sultan-eli ek adım gerekmiyor.

## Sayfalama (gerçek, sessiz kesme yok)
- `db-query`: `has_more`/`next_cursor` döngüsü sonuna kadar sürer. Kesilirse **söyler**
  (`--limit` verilmişse "sonuç KESİLDİ" uyarısı). 100'de sessiz kesme yoktur.
- `db-list`: Notion `/v1/search` **aynı nesneyi birden çok sayfada** döndürebiliyor (canlı gözlendi)
  → id-bazlı tekilleştirme + **imleç-tekrarı kalkanı** (sonsuz döngü olurdu) + `--limit` (öntanımlı 200)
  ve `--sayfa-tavani` (öntanımlı 20). Kesildiğinde "LİSTE KESİLDİ: <neden>" basar.

## İmzalı-süreli dosya URL'leri
Notion-barındırmalı (`type=file`) ek URL'leri **imzalı ve ~1 saat ömürlüdür**. `file-download`
URL'yi alır ve **hemen** indirir; URL diske/loga/ekrana **yazılmaz**. Süre dolmuş/erişilemezse
yarım dosya **silinir** ve dürüst hata verilir ("komutu yeniden çalıştır — URL taze alınır").
`type=external` ekler (ör. pCloud CDN) aynı yolla iner, `[external]` etiketiyle raporlanır.

## Sır-hijyeni
- Jeton **argv'ye/loga/ekrana ASLA** düşmez: `Authorization` başlığı `curl -K -` ile **stdin**'den
  verilir (`-H "…$TOKEN"` yasaktır — `ps` çıktısında görünür). Test T3 bunu kilitler.
- Çözüm sırası: `vault-cek get NOTION_TOKEN` (öneksiz ad kendi kiracıya çözülür:
  `secret/nexus/NOTION_TOKEN` · `secret/mmex/NOTION_TOKEN`) → yoksa `~/.config/cortex-access.env` (600).
  Vault yok/erişilemez → **sessiz geç**, fail-hard yok.
- Jeton **programatik üretilemez**: notion.so/profile/integrations (Sultan-eli). `doctor` jeton
  yoksa "doğrulanmadı" der — **uydurma-yeşil yok** (rc=2).

## Kanıt (bu kutuda canlı ölçüldü · 2026-08-16)
| Fiil | Sonuç |
|---|---|
| `doctor` | ✓ yeşil — bot "MMEpanel" · vault:yeşil · paylaşım: en az 1 nesne |
| `db-list --limit 30` | ✓ 30 tekil veritabanı, 1 istek, başlıklar dolu |
| `db-query 265b…eca1` | ✓ **13 satır**, 1 istek (plakalar: 47LL253, 47LL013, …) |
| `page-get <plaka-sayfası>` | ✓ alanlar: Name · Geçerlilik Tarihi · IlkTescilTarihi · AracSahibi · Ruhsat? · Cinsi · TescilTarihi · **Ruhsat[files]** · Formula · **MuayeneBelgesi[files]** · Marka · Tescil Seri No |
| `file-download … Ruhsat …` | ✓ 5.686.666 B PNG (2400×1792, PNG imzası doğrulandı) — dosya sınavdan sonra **shred** edildi |
| negatif: olmayan alan / files-olmayan alan / olmayan db / `page-create` | ✓ dördü de dürüst hata, rc≠0 |
| `notion.test.sh` (çevrimdışı) | ✓ **16/16** |

## Testler
`bash scripts/notion.test.sh` — ağ/Notion/kasa **gerektirmez**: sahte-Notion (`notion-stub.py`)
127.0.0.1'de koşar. CI'da gerçek Notion yoktur; canlı çağrı bağlanmak **sahte-yeşil** üretirdi.
Kapsam: salt-okur değişmezi · argv-sır-hijyeni · Notion-Version (iki dal + yanlış-sürüm negatifi) ·
sayfalama · tekilleştirme+imleç-kalkanı · saf-JSONL · 404 dürüstlüğü · indirme negatifleri
(yarım dosya bırakmama) · jetonsuz "doğrulanmadı".

## Notlar
- Ruhsat/muayene görselleri **Sultan'ın özel belgeleridir** — depoya/ortak dizine konmaz,
  indirildikleri yerde tutulur (MENZİL arşivi gibi sahibi belli bir dizin).
- `credentials.yaml`'a yeni env EKLENMEZ (jeton zaten kasada) — yalnız tüketici-pointer.
