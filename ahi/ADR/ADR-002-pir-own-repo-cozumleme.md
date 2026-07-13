# ADR-002 — Pîr/S4 own-repo hedef-çözümlemesi: pir-registry.json

> Statü: KABUL (2026-07-13, AHÎ FAZ-6 dogfood — Lonca-törpüleme) · Sahip: SERDAR

## Bağlam
Pîr-kademesi tanım gereği **kendi-repo**'da yaşar (tiers/pir.md dim-2); Sx-Claude-Skills'in
alt-dizini değildir. Ama V1'de `ahi check <hedef>` yalnız `Sx/<hedef>/` + cwd-göreli yol çözer,
`ahi health` yalnız `Sx/*/` alt-dizinlerini dolaşır, `ahi promote` manifest'i yalnız Sx-altında
arar. Sonuç: CANLI S4-örneği Lonca fabrikanın hiçbir yüzeyinde görünmüyordu (FAZ-6 dogfood'un
ilk bulgusu — kanon Lonca'yı İFADE EDİYOR, araç ERİŞEMİYORDU).

## Karar
`ahi/pir-registry.json` — own-repolu Pîr-sistemlerin `{name, repo}` kaydı; üç yüzey ondan okur:
- `ahi check <ad>`: Sx-altı + cwd-fallback bulunamazsa registry'deki `repo/ahi.manifest.yaml`.
- `ahi health`: Sx-taramasından sonra registry-Pîr'leri listeler (manifest var+valid → "aktif (own-repo)";
  yok → "manifest YOK — görünmez-mount/izole?" (unknown≠fail; izole-container'da repo görünmeyebilir)).
- `ahi promote <ad>`: manifest-çözümde aynı fallback; usta→pir kolunda mekanik ön-problar
  (own-repo-manifest / ROADMAP.md / git-remote) — **nihai-karar MANUEL-BEYAN/Sultan-gate KALIR** (pass=0).

## Sınırlar / bilinçli-kabuller
- **Mutlak-yol makine-bağımlıdır.** AHÎ dağıtımı `_global`-only (yalnız cloudtop-HOME, Nexus
  HOLDING-ATLAS §8 Sultan-kararı) olduğundan kabul edilebilir; dağıtım genişlerse bu ADR yeniden açılır.
- **`ahi new pir` şablonsuzluğu bilinçlidir** (değişmedi): Pîr Sx-altına scaffold edilmez; komut
  rehber basar (kendi-repo iskeleti + tiers/pir.md). templates/pir/ eklemek bu tasarımla çelişirdi.
- Registry AHÎ'nin owner-domain'i İÇİNDEDİR (ahi/ altı) — sync-skills.mjs / catalog.json /
  sync-targets.json'a dokunulmaz (ADR-001 korunur).
- Zero-dep korunur: registry-okuma `node -pe` (node zaten check/health önkoşulu); node yoksa
  registry sessiz devre-dışı (graceful).

## Doğrulama
`ahi check lonca` (cwd-bağımsız) exit=0 · `ahi health` PÎR-satırı "lonca pir aktif (own-repo)" ·
`ahi promote lonca` → "zaten Pîr — mezuniyet" (registry-çözümlü) · `ahi check ahi` dogfood-regresyonu
exit=0 · `validate-repo.mjs` davranışı değişmedi (registry parity-kapsamı dışı — Pîr catalog'a girmez,
girip girmeyeceği ayrı karar).
