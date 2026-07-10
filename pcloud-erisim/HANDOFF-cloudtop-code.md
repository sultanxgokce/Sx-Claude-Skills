# HANDOFF — `pcloud-erisim` global-paketleme (cloudtop-code'da koşulacak)

> Bu skill **izole `cloudtop-mmex`** konteynerinde yazıldı + CANLI kanıtlandı. Ama `Sx-Claude-Skills`
> reposu + `sync-skills.mjs`/`sync-targets.json`/`catalog.json` yalnız **`cloudtop-code`**'da → global
> fan-out oradan koşulur. Aşağıdaki adımlar cloudtop-code'da yapılır.

## Kaynak dosyalar (bu build'in ürettiği — birebir kopyalanacak)
- `pcloud-erisim/SKILL.md`  (frontmatter'da `version: 1.0.0` — sync semver-karşılaştırır)
- `pcloud-erisim/scripts/pcloud.sh`

Bunlar bu konteynerde `/config/.claude/skills/pcloud-erisim/` altında. mmex'in instance-kopyası bu
build'le **zaten yerinde**; upstream'e taşımak diğer konteynerler/gelecek-sync'ler için gerekir.

## Adımlar (cloudtop-code · Sx-Claude-Skills klonu)
1. `pcloud-erisim/SKILL.md` + `pcloud-erisim/scripts/pcloud.sh`'i klona **birebir** ekle (drift-önler:
   upstream = tek-kaynak; kurulu-kopyayı yerinde düzenleme).
2. `catalog.json` → bir skill-entry ekle (diğer `*-erisim` girişlerinin şekliyle).
3. `README.md` → katalog-tablosuna bir satır.
4. `sync-targets.json` → `install["pcloud-erisim"] = ["_global","nexus","cortex", ...]` — **`_global` DAHİL**
   (her hedefe iner). ⚠️ mmex/medigate hedefi yoksa izole-konteynerler sync'i ayrı koşar.
5. `node sync-skills.mjs --apply` → cloudtop-code'un `_global`'i + VPS hedefleri (nexus/cortex).
6. `git commit + push` → izole konteynerler (mmex/vekatip/medigate) `git pull` ile alır (cross-container
   veri-yolu = git; tek-konteyner sync yetmez).
7. **Registry consumer-pointer:** `Nexus/_agents/credentials.yaml → id: pcloud`'a
   `consumer: pcloud-erisim skill` satırı ekle (pointer, DEĞER-değil). Bu bu konteynerde yapılamadı
   (registry burada yok).

## Sürüm-güncelleme kuralı (ALTIN-KURAL)
İyileştirme daima **upstream** (Sx-Claude-Skills) → `version:` bump → tekrar `node sync-skills.mjs --apply`.
Kurulu-kopyayı yerinde düzenleme = drift (sync motoru uyarır).

## Bu konteynerdeki kanıt (referans)
- `doctor` yeşil: userinfo `result==0`, email-domain + kota — DEĞER-yok.
- `list 0` root klasörü döndürdü.
- Sır-değer hiçbir çıktıda yok (token yalnız `curl --config -` stdin'inde; argv/log temiz).
