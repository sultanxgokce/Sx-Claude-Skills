---
name: sert-döngü
type: agent
version: 0.2.0
description: >
  kesif(bul)×sert-teslim(oracle) besteleyen kapalı-döngü yürütücü. Bir feature/paneli kabul-kriterine
  (teslim-lint RC=0) varana dek otomatik-yineler: e2e-bul → (bug-varsa) Task-subagent-DÜZELT → mekanik-oracle.
  tester≠fixer HARD (fix daima ayrı-kimlik Task-subagent; sürücü ürün-kodu YAZMAZ). max_iter-tavan +
  aynı-tohum-2×-takıldı→Sultan-gate (otonom-devam-YOK). Durma-koşulu = YALNIZ F3 RC=0. Config-driven, proje-bilmez.
  "/sert-döngü <feature>", "/sert-döngü devam <feature>", "/sert-döngü durum" çağrılarında kullanılır.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [dongu, kesif, sert-teslim, tester-fixer-ayrimi, anti-false-green, oracle, portable]
---

# /sert-döngü — kesif×sert-teslim kapalı-döngü yürütücü

> **NE-DİR:** `/sert-döngü <feature>` çağrısıyla bir canlı-panel/feature'ı **kabul-kriterine
> (F3 `teslim-lint` RC=0) varana dek** otomatik-yineleyen sürücü. Her iterasyon: **bul → (bug-varsa)
> düzelt → mekanik-oracle-doğrula.** Durur ANCAK F3 RC=0'da (ya da tavan/dönme → Sultan-gate).
>
> **NE-DEĞİL:** yeni-test-motoru değil (`/kesif`+`/sert-teslim`'i *çağırır*, yeniden-yazmaz) ·
> SİNAN 3-ajan-adversarial değil (o ayrı milestone-katmanı — §6, döngü-içinde çağrılmaz) ·
> TEZGAH-config değil (bu bir Claude-sürücülü *yürütücü* SKILL — TEZGAH execute-etmez, doktrin).
>
> **Kaynak-spec:** `Nexus/_agents/handoff/mimserdar-sert-dongu.md` (MİMSERDAR, salt-plan) +
> `lonca-erisim/ARAYUZ-SOZLESMESI.md` (SİNAN, RC-semantiği kontrat-yüzeyi).

---

## Ne zaman çağrılır
- `/sert-döngü <feature>` — sıfırdan döngü-başlat (config yükle → ön-uçuş → yinele).
- `/sert-döngü devam <feature>` — post-compact/kesinti sonrası: DONGU-LEDGER son-satırdan sür.
- `/sert-döngü durum <feature>` — salt-okur döngü-kartı (iter/son-RC/dönme-sayacı); **dosya-dokunmaz**.

⛔ **USER-invoke.** Otonom-tetiklenmez (Sultan/SİNAN çağırır). Sync: `node sync-skills.mjs --apply`.

---

## 0 · ROLLER (SOYUT — sert-teslim emsali)
| Rol | Yapar | ASLA-yapmaz |
|---|---|---|
| **sürücü/tester** (SEN, ana-context) | döngüyü sürer · F1+F3 koşar · RC+kanıt-JSON okur · karar-verir · LEDGER yazar | **ürün-kodu/artifact YAZMAZ** (Edit/Write ürün-source'a = İHLAL) |
| **fixer** (Task-subagent, taze-kimlik) | yalnız kod/artifact değiştirir → döner | verdict-üretmez · "yeşil" demez (oracle sürücünün re-run'ıdır) |

Bu ayrım **yürütme-seviyesinde** zorlanır (§3) — TEZGAH execute-etmediği için config-seviyesi yoktur.

---

## 1 · ÖN-UÇUŞ (bir-kez, döngü-başı)

**A. Config yükle** (§4). `<kök>/tooling/sert-dongu.yaml` yoksa → **İSİMLİ-red**, dur, `aile-notify.sh SERDAR --waiting` (sessiz-varsayılan YOK). Kök = `git rev-parse --git-common-dir` ile ANA-repo (worktree-güvenli).

**B. Anti-false-green ön-koşul** — `enjeksiyon.mjs` (ULTIMATE-dogfood):
```
node <kesif>/scripts/enjeksiyon.mjs \
  --panel-url <panel_url> --allowlist <allowlist> \
  --senaryolar <senaryolar> --enjeksiyonlar <enjeksiyonlar> --kanit <kanit_dir>
```
- **RC=0** → test-apparatı sağlam (sahte-yeşil kaçan=0) → F1-yeşilleri **güvenilir** → DÖNGÜ'ye geç.
- **RC=1** → **APPARAT-boşluğu** (enjekte-edilen-sahte-yeşil kaçtı / src-kirli). Bu bir **TEST-APPARAT-fix**'tir (ürün-değil): fixer-target = senaryolar/apparat. F1-yeşiline **GÜVENME** → düzelt-sonra-devam ya da `--waiting`.
- `enjeksiyon_kadans: milestone` ise ön-uçuş yalnız milestone-başı koşulur (pahalıysa). MVP-varsayılan = `dongu-basi`.

---

## 2 · DÖNGÜ ALGORİTMASI

```
iter = 0  (devam ise LEDGER son-iter'den)
DÖNGÜ:
  iter++
  iter > max_iter → STOP  "⛔ max_iter-tavan"  + Sultan-escalate (sessiz-pes-etme YOK)

  ── F1  kesif-bul ────────────────────────────────────────────
     node <kesif>/scripts/e2e-run.mjs \
       --panel-url <panel_url> --allowlist <allowlist> \
       --senaryolar <senaryolar> [--api-base <api_base>] --kanit <kanit_dir>
     RC=2 → ABORT  "❌ F1-RC2-config"  (kullanım/config hatası, retry-anlamsız) → --waiting Sultan, iter-harcama
     RC=1 → FAIL   fail-senaryolar = <kanit_dir>/e2e-senaryolar.json .rapor.kalan  → düzelt-girdisi
     RC=0 → test-fail-yok → F3'e geç

  ── F3  oracle ───────────────────────────────────────────────
     sh <sert-teslim>/scripts/teslim-lint.sh <feature_dizini>
     RC=0 → 🎯 STOP  "F3-RC0-bitti"  (gate-temiz = KABUL-KRİTERİ) → LEDGER-mühür + Sultan-özet
     RC=1 → hangi-K stdout'ta (K1-matris / K3-A4 / K4-smoke / K6-veri-rejimi) → düzelt-girdisi

  ── DÜZELT  (yalnız F1-RC1 ∨ F3-RC1 varsa)  [⛔ tester≠fixer HARD — §3] ──
     girdi = { F1 fail-senaryo-listesi } ∪ { F3 K-ihlalleri }   (SCOPE-dar)
     Task-subagent SPAWN (taze-kimlik, run_in_background:false):
       agentType = general-purpose  (ya da agent-dashboard:build-error-resolver)
       prompt = dar-bug-listesi + "yalnız bu bug'ları düzelt, kapsam-dışına çıkma; test-yazma/verdict-verme"
     subagent döner → sürücü LEDGER'a fixer_subagent_id yazar.
     ⚠️ Sürücü fixer'ın "düzelttim"ine GÜVENMEZ → sonraki-iter'de F1+F3 TAZE yeniden-koşar (oracle=re-run).

  ── DÖNME-TESPİTİ ────────────────────────────────────────────
     imza = sort(F1 fail-senaryo-id'leri) ∪ sort(F3 K-kodları)
     imza == önceki-iter-imzası → dönme_sayaci++   ;  değilse dönme_sayaci=0
     dönme_sayaci >= 2 → STOP  "🔁 aynı-tohum-2×"  + Sultan-gate
                         ("aynı-tohum 2× çözülemedi — otonom-devam etmiyorum")
  → sonraki-iter
```

**Durma-koşulu = YALNIZ F3 RC=0.** F1/F2 sinyalleri iterasyon-içi; başlı-başına durma-koşulu DEĞİL (sözleşme).

---

## 3 · KRİTİK-INVARIANT — tester≠fixer (YÜRÜTME-seviyesi)
Sözleşme bunu agent-identity-constraint olarak istedi; TEZGAH execute-etmediği için **config-seviyesi yok → yürütme-seviyesinde zorlanır:**

1. **Sürücü ürün-kodunu/artifact'ı ASLA kendi-turunda yazmaz.** Edit/Write ürün-source'a = **İHLAL** (kendi-ödevini-notlama). Sürücünün tek-işi: F1/F3-koş · RC/kanıt-oku · karar · LEDGER.
2. **Her fix = ayrı `Task`-subagent** (taze-kimlik/context). Girdi = dar-bug-listesi. Bu "bul_agent ≠ düzelt_agent"ı **yapısal** kılar.
3. **Anti-false-green çekirdek:** fixer döndükten sonra sürücü F1+F3'ü **TAZE yeniden-koşar** — fixer'ın iddiasını oracle-saymaz. Yeşil ancak gerçek-re-run'dan gelir.
4. **Audit-kanıt:** LEDGER her düzelt-fazına `fixer_subagent_id` yazar → tester≠fixer denetlenebilir.
5. **İHLAL-tanımı:** sürücü inline-fix yaparsa ya da re-run-atlarsa = invariant-ihlali (kırmızı-bayrak).

---

## 4 · CONFIG (proje-bilmez; ince-manifest)
`<kök>/tooling/sert-dongu.yaml` (kök = `git rev-parse --git-common-dir` ANA-repo). Yoksa **İSİMLİ-red** (sessiz-varsayılan YOK):
```yaml
feature: <ad>                       # sert-teslim feature-dizini adı
kesif:
  panel_url: <url>
  api_base: <url|null>
  allowlist: <csv>                  # origin-EXACT
  senaryolar: <proje/senaryolar.mjs yolu>
  enjeksiyonlar: <proje/enjeksiyonlar.mjs yolu>
  kanit_dir: <dir>
sert_teslim:
  feature_dizini: <MATRIS.md+kanit/+a4/+TESLIM-RAPORU.md dizini>
dongu:
  max_iter: 20                      # "yeter-kadar" tavan; sonsuz-önleyici
  enjeksiyon_kadans: dongu-basi     # dongu-basi | milestone
```
- **CLI-override** kabul (`--panel-url`/`--max-iter`…) — config ana-kaynak, CLI üstün.
- **Kardeş-skill çözümü:** `<kesif>`=`.claude/skills/kesif`, `<sert-teslim>`=`.claude/skills/sert-teslim` (kurulu-skills-dizini; **vendoring-YOK**).

---

## 5 · STATE / RESUME / DÜRÜSTLÜK
- **`<state_root>/<feature>/DONGU-LEDGER.md`** — her iterasyon 1-satır:
  `iter · F1-RC · fail-senaryolar · fixer_subagent_id · F3-RC · K-ihlaller · karar`. **Disk-kalıcı** (transkript/compact'e GÜVENME — `devam` bunu okur).
- **`/sert-döngü devam <feature>`** → LEDGER son-satır + son-kanıt-JSON oku → kaldığı iter'den sür.
- **`/sert-döngü durum <feature>`** → salt-okur döngü-kartı (iter/son-RC/dönme-sayacı); dosya-dokunmaz.
- **Dürüst-yüzey — her STOP nedeni açık ve tekil:**
  - `🎯 F3-RC0-bitti` — kabul-kriteri sağlandı
  - `⛔ max_iter-tavan` — tavan doldu
  - `🔁 aynı-tohum-2×` — dönme-tespiti
  - `❌ F1-RC2-config` — config/kullanım hatası
  - `🕳️ apparat-boşluğu` — ön-uçuş RC1
  Uydurma-yeşil YOK; Sultan hangi-durakta olduğunu bilir.

### 5b · KABUL-emit (Lonca keystone-köprü · FAZ-5B-2b — v0.2.0, INERT)
HER STOP'ta (5 neden de) LEDGER-mühründen SONRA, curated özeti köprüye emit et:
```
bash <bu-skill>/scripts/lonca-emit-outcome.sh \
  --source sert-dongu --goal <feature> \
  --accepted <true|false>            # true YALNIZ 🎯 F3-RC0-bitti \
  --iterations <iter> --rc <son-F3-RC|-> \
  --agent <çağıran-kimlik> --fixer-audit "<fixer_subagent_id sayısı+listesi kısa>" \
  --detail "<STOP-neden etiketi (yukarıdaki 5'ten biri)>"
```
- **INERT:** `LONCA_BRIDGE_TOKEN` yoksa script sessiz no-op (exit 0) — döngü-davranışı byte-identical.
- **value-safe/curated:** HAM senaryo-çıktısı/kanıt-metni emit'e GİRMEZ — yalnız yukarıdaki alanlar
  (redaksiyon bu adımın işi). Emit-hatası STOP'u ASLA bozmaz (fail-safe exit 0).
- Emsal: /orkestra FAZ-7 emit (5B-2a) — script birebir port, kontrat aynı (`POST /api/lonca/outcome`).

---

## 6 · F3-oracle ≠ SİNAN 3-ajan-adversarial (AYRI-katman)
- **Döngü-içi (her-iterasyon):** F3 = `teslim-lint.sh` **ucuz+mekanik** (RC-check, saniyeler; dosya-varlığı+sayım+hash — LLM-judge DEĞİL). Döngünün durma-koşulu budur.
- **Milestone (pahalı, döngü-DIŞI):** SİNAN 3-ajan-adversarial (gate-runner + integrity-hunter + mutasyon) bir feature/tooling **mühürlenirken** koşar. **/sert-döngü bunu iterasyon-içinde ÇAĞIRMAZ.** Döngü F3-RC0'a varınca opsiyonel milestone-devir: SİNAN-adversarial ayrı-pass ile mühürler (el-değmez-sınır).

---

## 7 · RİSKLER & AZALTIM
1. **Sürücü inline-fix'e kayar** → sürücü=ürün-kodu-read/run-only; her-fix Task-zorunlu; `fixer_subagent_id` boşsa ihlal.
2. **Hollow F1-yeşil** → enjeksiyon.mjs ön-uçuş (kaçan=0 ∧ harness_hatali=0, v0.2.2); RC1→apparat-fix-önce. Ayrım (v0.1.1): `KAÇTI(!!)` (gerçek anti-false-green başarısızlığı) ≠ `HARNESS-HATA` (anchor-metni kaymış/mutant-build-fail — apparat-tamiri-gerekir, senaryo hollow-değildir). İkisi de RC1 üretir ama teşhis ayrı (operatör "hangi bug'ı bulacağım" ile "hangi tarifi düzelteceğim"i karıştırmaz).
3. **Sonsuz-döngü/thrash** → max_iter-tavan + aynı-tohum-2×-dönme → Sultan-gate.
4. **F1-RC2 config retry-döngüsü** → RC2=ABORT (retry-anlamsız), iter-harcamaz.
5. **F3-RC1 ama F1-RC0** (test-geçer, matris/kanıt-eksik) → düzelt-hedefi artifact-üretimi, yine Task-fixer (sürücü artifact-üretmez).
6. **Compact/resume döngü-ortasında** → DONGU-LEDGER disk-kalıcı + `devam` re-hydrate.
7. **Kardeş-skill sürüm-drift** → RC-sözleşmesi (ARAYUZ-SOZLESMESI) kontrat-yüzeyi sabit-kalmalı (regresyon-testi: BUGSERDAR).

---

## Build-notları
- (1) sürücü Task-spawn'ı `run_in_background:false` (sıralı; fix→re-run bariyeri).
- (2) enjeksiyon-ön-uçuş MVP = döngü-başı.
- (3) config-yoksa İSİMLİ-red.
- (4) LEDGER-şeması §5 sabit.
- **Sahiplik:** spec=MİMSERDAR · SKILL-gövde=SERDAR-ailesi · ilk-dogfood=SİNAN (`lonca-erisim` paneli) · RC-drift-guard=BUGSERDAR.
