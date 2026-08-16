---
platform: notion
confidence: high
verified: 2026-08-16
---

# Notion erişim reçetesi

Kaynak-gerçek: bu kutuda (cloudtop-code) **canlı ölçüm** — `notion-erisim` skill'ini besledi.
Talep: SİNAN/MMEx (MENZİL filo-verisi Sultan'ın Notion'ında).

## Özet
Notion REST API (`https://api.notion.com`). Internal-integration jetonu + Bearer başlığı.
Bu ailede kapsam **SALT-OKUR**: `search` · `databases/{id}/query` · `pages/{id}` · files-eki indirme.

## Dürüstlük kısıtı (honesty_constraint)
Internal-integration jetonu **programatik ÜRETİLEMEZ** — `notion.so/profile/integrations` (Sultan-eli).
Ayrıca jeton geçerli olsa da sayfa/veritabanı **entegrasyona paylaşılmamışsa** `object_not_found` döner
(sayfa → ••• → Connections). Skill bu iki durumu ayırt eder; jeton yoksa "doğrulanmadı" der.

## credential_intake
Vault-first: `vault-cek get NOTION_TOKEN` (öneksiz ad kendi kiracıya çözülür — `secret/nexus/NOTION_TOKEN`,
`secret/mmex/NOTION_TOKEN`) → yoksa `~/.config/cortex-access.env` (600, `export NOTION_TOKEN=…`).

## token_mint
Programatik değil (dashboard). env_var: `NOTION_TOKEN`.

## scope / forbidden
- Scope: entegrasyona **paylaşılan** sayfalar; capability olarak Read content yeterlidir.
- **YASAK:** yazma uçları (`POST /v1/pages`, `PATCH /v1/pages|blocks`, `DELETE`) — Sultan'ın çalışma alanı.
- **YASAK:** jeton `-H "Authorization: Bearer $TOKEN"` ile geçirmek (argv → `ps`); `curl -K -` stdin şart.

## Kritik gotcha (saat yiyenler)
1. `Notion-Version: 2022-06-28` başlığı **zorunlu**; yoksa 400/validation_error gelir ve "jeton geçersiz"
   sanılır.
2. POST gövdesi `printf … | curl -K - --data-binary @-` ile **gitmez** (stdin'i heredoc tutar) → gövde boş,
   filtre/`start_cursor` uygulanmaz, sayfalama sonsuz döner. Gövdeyi geçici DOSYADAN ver.
3. `/v1/search` sayfalamasında **aynı nesne birden çok sayfada** dönebilir → tekilleştirme + imleç-tekrarı
   kalkanı gerekir.
4. files-alanı `type=file` URL'leri **imzalı ve ~1 saat ömürlü** → alındığı anda indir, URL'yi saklama.
   `type=external` (ör. pCloud CDN) URL'leri süresiz olabilir.

## verify (doctor)
`GET /v1/users/me` → `object!=error` ⇒ yeşil (bot adı + tip). Ek olarak `POST /v1/search {"page_size":1}`
ile "hiç paylaşım yok" hâli ayrıca raporlanır. Hata gövdesi `{object:"error",status,code,message}`.

## cli_tool
Yok/gereksiz — saf `curl`+`jq`.
