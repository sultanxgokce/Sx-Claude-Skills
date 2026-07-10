---
name: pcloud-erisim
type: agent
version: 1.1.0
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
description: pCloud erişimi gereken işleri (dosya listele/yükle/indir, public-link) PANELE GİRMEDEN, saf API (curl+jq) ile yapar. Token'ı ortam-store'undan DEĞER-görmeden çözer (cortex-access.env → MMEpanel/.env); yoksa gizli set-token ister, bir daha sormaz. OAuth access_token (kalıcı, TFA-bağımsız, query-param — Bearer değil) + EU/eapi host. Sır-hijyenik (token argv/log/chat'e ASLA düşmez) + R7-farkında (iç-belge public-folder-DIŞI). (erisim-skill-fabrikasi · cloudflare-erisim şablonundan üretildi.)
tags: [pcloud, storage, erisim, platform-access, oauth, filedn, setup]
---

# pcloud-erisim

pCloud API'sine **panele girmeden** saf `curl`+`jq` ile eriş. Token ortam-store'undan
**değer-görülmeden** çözülür; bir ajan `doctor`/`list`/`upload`/`download`/`publink` yapabilir.

## Ne zaman
- "pCloud'a dosya yükle / listele / indir", "şu fileid için public link", "pCloud kotası ne" gibi işler.
- Her ajanın "credential nerede" diye sormasını bitirmek için tek-kapı.

## Kullanım
```bash
S=/config/.claude/skills/pcloud-erisim/scripts/pcloud.sh
bash $S doctor                      # 3-durum sağlık: yeşil / kırmızı / doğrulanmadı
bash $S list 0                      # klasör listele (root=0)
bash $S upload ./rapor.pdf 22311016127   # dosyayı folderid'ye yükle
bash $S download 123456789 ./out.pdf     # fileid'yi indir
bash $S publink 123456789          # public download link (R7 uyarısıyla)
bash $S set-token                  # OAuth access_token'ı GİZLİ yapıştır (yeni ortam)
bash $S fingerprint                # token kimlik-teyidi (tersine-çevrilemez hash, DEĞER-yok)
```

## Omurga (erisim-skill-fabrikasi · 7-madde)
1. **Tek-sefer gizli intake** — `set-token` `read -rsp` ile; değer chat/log/geçmişe düşmez.
2. **Token mint** — pCloud OAuth token'ı **programatik ÜRETİLEMEZ** (dashboard/OAuth-app akışı) →
   yeni ortamda `set-token`; mint-doc: `MMEpanel/docs/pcloud-oauth-token-mint.md`.
3. **Sakla** — `~/.config/cortex-access.env` (chmod 600), `export PCLOUD_ACCESS_TOKEN=…` + `PCLOUD_REGION`.
4. **Registry pointer** — kanonik kayıt `Nexus/_agents/credentials.yaml → id: pcloud` (değer değil, pointer).
5. **`doctor` 3-durum** — yeşil (userinfo `result==0` + email-domain + kota) / kırmızı (`fail:<result>`) /
   doğrulanmadı (token yok → hangi store'a bakılacağını söyler, uydurma-yeşil YOK).
6. **Dürüstlük guard'ı** — pCloud'un "kullanıcı+şifre → kalıcı token" API'si TFA açıkken çalışmaz; kalıcı
   erişim OAuth `access_token` ile → doctor bunu açıkça söyler.
7. **Saf API** — resmi CLI yerine `curl`+`jq` (rclone `[mmepcloud]` opsiyonel alternatif).

## API kontratı (kaynak: `MMEpanel/backend/services/integrations/pcloud.py`)
- **Host:** `https://{region}.pcloud.com` — region `eapi` (EU, **default**) / `api` (US). `PCLOUD_REGION`'a göre.
- **Auth:** QUERY-PARAM, **Bearer DEĞİL** — OAuth→`access_token=`, legacy→`auth=`. Token query-param olduğundan
  `curl --config -` (stdin heredoc) ile geçirilir → `ps`/argv/log'da **görünmez**.
- **Endpoint:** `userinfo` · `listfolder` · `uploadfile` (multipart `-F file=@`) · `getfilelink`(+indir) ·
  `getpublink`.

## ⚠️ R7 (kritik kural)
Arçelik iç-belgeleri **Public-Folder DIŞINDA** tutulur (`getfilelink`/`getpublink` public-folder içinde
`2284` döner — bu normaldir, dosya public-folder-dışına konumlanmalı). `publink` bu uyarıyı basar.

## Sır-hijyeni
- Token DEĞERİ STDOUT/chat/argv/commit'e **ASLA** — yalnız konum/şema/`result==0`/email-domain/kota/fingerprint.
- Store: `cortex-access.env` → yoksa `/config/projects/MMEpanel/.env` (**yerinde-oku, kopyalama YOK**).
- `fingerprint` ile kimlik doğrulanır (sha256 ilk-12, tersine-çevrilemez).

## Notlar
- `credentials.yaml`'a yeni-env EKLENMEZ (token zaten kayıtlı) — yalnız consumer-pointer.
- Kendi ortamının store'unu kullan; başka ortamın dosyasını varsayma → yoksa "doğrulanmadı" de.
