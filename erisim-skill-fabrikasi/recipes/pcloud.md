---
platform: pcloud
confidence: high
verified: 2026-07-09
---

# pCloud erişim reçetesi

Kaynak-gerçek: MMEpanel canlı-implementasyonu `backend/services/integrations/pcloud.py` +
registry `Nexus/_agents/credentials.yaml → id: pcloud`. Bu reçete `pcloud-erisim` skill'ini besledi.

## Özet
pCloud dosya-depolama API'si. Dosya listele/yükle/indir + public-link. EU (`eapi`) / US (`api`) iki host.
MMEpanel 2026-06-26'da pCloud desteğiyle `MMEpanelDocStore` OAuth-app'ini açtı (EU/eapi).

## Dürüstlük kısıtı (honesty_constraint)
pCloud OAuth `access_token`'ı **programatik ÜRETİLEMEZ** — dashboard/OAuth-app authorize akışıyla alınır.
Plain kullanıcı+şifre login TFA açıkken `result=1022` ("provide code") ile kırılır; OAuth token ise
**kalıcı** (expire-yok) + TFA-bağımsız + logout-bağışık. → skill token yoksa "doğrulanmadı" der, uydurma-
yeşil YOK; kullanıcı mint-doc'tan alıp `set-token` verir.

## credential_intake
`set-token` → `read -rsp` ile OAuth access_token gizli-yapıştır → `cortex-access.env` (600). Değer chat/log/
argv/geçmişe düşmez. Ayrıca yerinde-oku: `cortex-access.env` → yoksa `/config/projects/MMEpanel/.env`.

## token_mint
Programatik değil. Mint-doc: `MMEpanel/docs/pcloud-oauth-token-mint.md`.
Authorize host = **`e.pcloud.com/oauth2/authorize`** (⚠️ `my.pcloud.com` "Invalid client_id" verir — EU-app).
`oauth2_token` endpoint dönen `locationid` (1=US/api, 2=EU/eapi) ile region eşlenir.

## scope / forbidden
- Scope: OAuth token tam-hesap (fine-grained scope yok). Skill salt-okur+yükle işlerine kendini sınırlar.
- **YASAK (forbidden):** token DEĞERİ STDOUT/chat/argv/commit'e ASLA. **R7:** Arçelik iç-belgeleri
  Public-Folder DIŞINDA (`getfilelink`/`getpublink` public-folder'da `2284` döner). Depolama-protokolü:
  `MMEpanel/_agents/docs/veri-genom/wiki/kavramlar/pcloud-depolama-protokolu.md`.

## verify (doctor)
`GET https://{region}.pcloud.com/userinfo` + auth-param → JSON `.result==0` ⇒ yeşil (email-domain + kota).
`.result!=0` (ör. `2000` invalid-token) ⇒ kırmızı `fail:<result>`.

## cli_tool
Saf `curl`+`jq`. Alternatif: `rclone [mmepcloud]` (cloudtop `~/.config/rclone`, mode 600).
**Kritik:** auth QUERY-PARAM (Bearer DEĞİL) — OAuth→`access_token=`, legacy→`auth=`. Query-param token
`curl --config -` (stdin heredoc) ile geçer → argv'de görünmez.

## env_var
Asıl: `PCLOUD_ACCESS_TOKEN` + `PCLOUD_REGION` (=eapi). Legacy geri-uyum: `PCLOUD_AUTH_TOKEN` /
`PCLOUD_USERNAME` / `PCLOUD_PASSWORD` / `PCLOUD_FOLDER_ID` (default 22311016127) / `PCLOUD_PUBLIC_ID`.
Store-haritası (ortama göre): Railway env · VPS `/etc/nexus/agent.env` · cloudtop `MMEpanel/.env` ·
local rclone.conf `[mmepcloud]` · GitHub Actions gh-secrets-nexus.

## Kaynaklar
- `MMEpanel/backend/services/integrations/pcloud.py` (canlı impl — API çağrı şekli)
- `MMEpanel/scripts/pcloud_oauth_exchange.py` (OAuth mint)
- `MMEpanel/docs/pcloud-oauth-token-mint.md` · `.../wiki/kavramlar/pcloud-depolama-protokolu.md`
- `Nexus/_agents/credentials.yaml → id: pcloud`
