# ADR-001 · Drift-otorite ayrımı: `sync-skills.mjs` vs `ahi check`

**Statü:** KABUL (FAZ-0a) · **Tarih:** 2026-07-13 · **Bağlam:** AHÎ inşası, 3-tur plan-modu (BLOCKER-1/R5).

## Sorun
`Sx-Claude-Skills`'te skilleri dağıtan **canlı** bir araç var: `sync-skills.mjs` — `version:` alanını `SKILL.md`
frontmatter'ından regex-okur ve dağıtım/drift kararını YALNIZ buna dayandırır. AHÎ'nin `ahi check`'i de drift
denetleyecek. İki araç aynı yüzeyde (version/parity) **çelişen verdict** üretebilir → "manifest-tek-kaynak" değişmezi ihlal.

Ek keşif (Tur-3, firsthand): Tur-2'nin önerdiği "`ahi check` sync-skills'i `--check` modunda sarmalayıp RC'sini
devralır" çözümü ELENDİ — sync-skills'in process exit/stdout-kontratı **sessiz-yeşil** üretebiliyor (drift-tespiti kaybolur).

## Karar
1. **`sync-skills.mjs` = version-karşılaştır + kopya/apply OTORİTESİ** (owner-domain, **DEĞİŞMEZ**; AHÎ dokunmaz).
2. **`version` semver'in TEK evi = `SKILL.md` frontmatter** (sync-skills'in regex-okuduğu yer). `ahi.manifest.yaml`
   version TAŞIMAZ (ya salt-okur türetir); iki-yerde varsa `ahi check` **eşitlik-assert** eder (drift-1).
3. **`ahi check` = TAMAMLAYICI** (rakip değil): YALNIZ
   - `catalog.json` ↔ `sync-targets.json` ↔ `README` **parity**,
   - tier / `requires[]` / `deprecated` **semantiği**,
   - manifest-**şema-geçerliliği**.
   Version'ı sync-skills'e **salt-okur-delege** eder (aynı regex; sarmalamaz — sessiz-yeşil riski). `sync-targets`/`catalog`'a
   **ASLA YAZMAZ** — yalnız drift **RAPORLAR**; düzeltmeyi insan/PR uygular.

## Sonuç
İki araç tamamlayıcı olur, rakip değil: sync-skills = version+kopya; ahi check = parity+semantik. "Çift-muhasebe yasak"
(motor-invaryantı) korunur. Kalan-risk: sync-stdout-parse kırılgan (versiyonsuz-kontrat) → izlenecek (residual).
