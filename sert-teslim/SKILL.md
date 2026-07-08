---
name: sert-teslim
type: agent
version: 0.2.1
description: >
  Gereklilik-matrisli sert-teslim MOTORU (motor-v1) — iş-sahibi talimatı VERBATIM diske iner,
  deterministik C-ID'lere bölünür, her normatif cümle test-edilebilir M-satırına bağlanır; "bitti"
  yalnız matris %100 makine-üretimi kanıt + 6-koşul TESLİM-GATE'inden çıkabilir. Döngülü (iter),
  diskten-resume, iki-vites (HAFİF/TAM), A1-A4 doğrulama-kadansı, eskalasyon-gate'li.
  "/sert-teslim <feature>", "/sert-teslim devam <feature>", "/sert-teslim durum" çağrılarında kullanılır.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [teslim, gereklilik-matrisi, dogrulama-motoru, iki-vites, adversarial, motor-v1]
---

# /sert-teslim — gereklilik-matrisli teslim motoru (motor-v1)

Değişmezler kanonu: `reference/DOCTRINE.md` (kapalı-liste — her çağrıda geçerli). Matris-biçimi:
`reference/FORMAT.md`. Şablonlar: `templates/`. Tasarım-kanonu: kaynak-projenin kapsamlı-tasarım
analiz-dokümanı (proje-lokal; bu motor-metni ona yol vermez — GENERIC).

Roller SOYUTTUR: **orkestra** (döngüyü sürer; verdict üretmez/yorumlamaz) · **builder** (uygular;
verdict/durum yazamaz) · **dogrulayici** (taze-subagent; yalnız disk + komut görür) · **is-sahibi**
(onay/gate/bütçe). Somut adlar YALNIZ proje-config'inde yaşar.
Çekirdek-araçlar: `core/cumle_bolucu.mjs` · `core/durum_uret.mjs` · `core/trust_boundary.mjs` (A1
kanıt-JSON) · `core/a4_dogrula.mjs` (A4 sayımsal-lint) · `core/sayac_baseline.mjs` (§1.5 sayaç-baseline
gate) · `core/redaction.mjs` · `core/jargon-lint.sh` (MOTOR proje-bilmezlik) · `core/selftest/` —
en-yüksek-rigor sınıfı; adversarial-doğrulamasız değiştirilemez.

## Tetikler

| Çağrı | Davranış |
|---|---|
| `/sert-teslim <feature-adı>` | Yeni teslim-sözleşmesi → KUR akışı. Aynı-adlı açık sözleşme varsa REDDET, `devam` öner. |
| `/sert-teslim devam <feature-adı>` | Diskten-resume: STATE.json + MATRIS.md + son LEDGER-satırı oku → kaldığı fazdan sür. Transkripte/özete GÜVENME. |
| `/sert-teslim durum` | Salt-okur durum kartı (tüm açık sözleşmeler); hiçbir dosyaya dokunma. |

## KUR (sözleşme başına 1 kez)

1. **Config yükle:** kök = `git rev-parse --git-common-dir` ile ANA-repo kökü (worktree'de bile);
   config = `<kök>/tooling/teslim/teslim-config.yaml`. Yoksa İSİMLİ-red: "bu projede KUR koşulmamış"
   — sessiz-varsayılan YOK (DOCTRINE §4).
2. **State-dizini:** `<config.state_root>/<feature>/` oluştur: `PLAN.md · TALIMAT-GUNLUGU.md ·
   MATRIS.md · STATE.json · LEDGER.md · kanit/` (hepsi `templates/`den).
3. **Girdi-sözleşmesi (üçü de zorunlu):**
   - **(a) Bağlam-pointer** — harness-kriteri ya da tek-cümle hedef.
   - **(b) KAYNAK-TALİMAT** = iş-sahibinin HAM SÖZÜ verbatim (paraphrase YASAK) + **TAMLIK-ONAYI**
     açıkça sorulur: "bu iş için söylediklerinin TAMAMI bu mu?" — cevap PLAN.md frontmatter'ına TARİHLİ.
   - **(c) Plan-dökümanı** — yoksa KUR-röportajıyla üret + iş-sahibine onaylat.
4. **Matris üretimi:** `core/cumle_bolucu.mjs` plan + talimatı C-ID'li cümlelere böler (deterministik,
   diske). Her normatif cümle → M-satırı: kanıt-türü + doğrulama-komutu(+hash) + etki-alanı +
   veri-rejimi + yuzey (şema: FORMAT.md). TAM-viteste çıkarım İKİ bağımsız geçiş — ikincisi
   ters-perspektif prompt'la ("kapsam-DIŞI / atlanmış-olabilecek her şeyi listele").
   - **Kanıt-gücü-kuralı:** görünürlük/davranış-fiilli cümlede (göster/görün/listelen/çalış +
     config-ek-fiiller) build/lint-komutu YETMEZ — en az `api-check`, UI-fiilinde `e2e-check`.
   - **Ölçülemez cümle** sessizce düşmez: `OLCULEMEZ`-etiketiyle iş-sahibi-gate'e.
   - **§1.5 baseline üretimi (ZORUNLU, sayaçlı-gate varsa):** `config.gate_cmds` içinde sayaçlı-runner
     (pytest/vitest/node-test) varsa, KUR o komutu TAM-SUITE (filtresiz) koşup `<feature>/baseline.json`
     üretir (şema: DOCTRINE §1.5): her gate-cmd `{id, komut, komut_sha256, runner, min_collected, max_skipped}`.
     Bu, filtreli-koşum gaming'ini hash-sabitle kapatır. Baseline.json'suz sayaçlı-teslim = §1.5 atlanır (UYARI).
5. **İKİ-VİTES kararı:** HAFİF ≤ `config.vites.hafif_max_m` M-satır; **kapalı-liste TAM'a zorlar:**
   UI-görünür-yeni-özellik · çok-dosyalı · iş-sahibi-"önemli".
6. **ONAY-1:** TAM'da açık-onay (kart: M-satır-sayısı + kanıt-türü dağılım-özeti); HAFİF'te async
   itiraz-penceresi ("itiraz-yoksa-başlandı"). Ön-bütçe-gate: >40 M-satır ∨ tahmin>15-iter →
   başlamadan iş-sahibi-onayı (DOCTRINE §3). **ONAY-1 sonrası GEREKLİLİK-DOKUNULMAZ** — gevşetme =
   iş-sahibi-gate + LEDGER-gerekçe; yeni gereklilik append-only.

## İTER-DÖNGÜSÜ (ONAY-1 sonrası — bir gate'e çarpana dek SORMADAN zincirle)

0. **FAZ-0-kontrol:** işlenmemiş iş-sahibi-talimatı var mı → `TALIMAT-GUNLUGU.md`'ye VERBATIM append
   (her append zorunlu M-satırı türetir); STATE + MATRIS + LEDGER'ı DİSKTEN tazele.
1. **HEDEFLE:** 1-5 `bekliyor/fail` M-satırı seç; hipotez-Z = o satırların doğrulama-komutu-PASS'i.
2. **UYGULA:** builder uygular. UI-tasarım-işiyse `/frontend-design` ZORUNLU (test-KODU muaf).
3. **A1-GATE:** `config.gate_cmds` HEPSİ, `trust_boundary` üzerinden kanıt-JSON'lu koşulur
   (deterministik; token≈0). Sayaç-kuralları: DOCTRINE §1.5.
4. **MUTABAKAT-REJENERASYON:** `core/durum_uret.mjs` koş → `durum` kolonu kanit/-JSON'lardan rejenere;
   diff raporla. Pahalı kanıt-tipleri yalnız dokunulan-satırda; tam-tarama yalnız teslimde.
5. **EKSİK-LİSTE:** her eksik ya mevcut satırı `fail`e çevirir ya YENİ M-satırı doğurur.
   Serbest-metin "KALAN:" notu YASAK.
6. **KARAR:** `0-bekliyor ∧ 0-fail ∧ adversarial-temiz` → TESLİM-GATE'e; değilse STATE güncelle +
   LEDGER'a 1-satır append → sonraki iter'e SORMADAN dön.

**A2/A3 tetik-kuralları (tek-kadans; DOCTRINE §2):** A2-safety MİNİ yalnız yeni-guard / şema-değişikliği /
güvenlik-yüzeyi iter'inde; A3-mutasyon yalnız guard-ekleyen/değiştiren iter'de (worktree-izole,
byte-revert). İkisi de teslimde TAM.

## TESLİM-GATE — 6 mekanik koşul (tümü diskte; teslim-lint denetler)

1. **Matris-temiz:** 0-bekliyor 0-fail (`engelli` varsa yalnız KISMİ-etiketle çıkılabilir).
2. **Adversarial-TAM:** A1 + A2-tam + A3-tam (worktree-izole) + önceki guard-suite'ler intact; tek wf-kimliği.
3. **A4-MUTABAKAT:** taze dogrulayici-subagent, builder-transkriptini GÖRMEDEN, her C-ID için
   `{normatif?, eşlenen-M#}` sınıflandırma-tablosu emit eder → `core/a4_dogrula.mjs` SAYIMSAL doğrular:
   her C-ID tam-1-kez + normatif→≥1 M#; eşlenmemiş normatif cümle = FAIL; "normatif-değil" listesi
   iş-sahibine İSİMLİ (veto-yüzeyi).
4. **Canlı-smoke:** `config.stack_script` kontratıyla (up → RC=0 + stdout TSV `surface_id → base_url`;
   down temizler; idempotent) + dürüst kapsam-beyanı (neyi sınadı / neyi SINAMADI).
5. **Açık-bulgu-kesişimi:** dokunulan yüzeyle kesişen açık keşif-bulguları raporda İSİMLİ.
6. **Veri-rejimi-disclaimer:** sentetik/mock kanıt kalıcı-satırla beyan (metin config'ten).

## TESLİM-RAPORU

`templates/teslim-raporu.md`den üret: matris kanıt-linkli + adversarial-wf-ref + A4-ref + smoke-ref +
disclaimers + **cost-özeti** + **skill_version-damgası**. KISMİ'de İLK-SATIR zorunlu manşet:
"X/Y gereklilik KANITSIZ — TESLİM EDİLMEDİ" (lint denetler).
**"bitti/tamam/hazır" İDDİASI TESLİM-RAPORU-LİNKSİZ GEÇERSİZDİR.**

## ESKALASYON (otonom-devam YASAK olan hâller)

- Aynı M-satırı `config.donme_gate_iter` iter üst-üste fail → iş-sahibi-gate.
- Aynı satır `kanitli↔fail` 2-flip → gate. · Kapsam > 2×ONAY-1-satır-sayısı → scope-gate.
- 10-iter checkpoint (hard-stop değil; durum-kartı sunulur).
Kart: `templates/eskalasyon-karti.md` — teslim-raporundan YAPISAL-AYRI; içinde "teslim" KELİMESİ GEÇEMEZ.

## VERDICT-DİSİPLİNİ

Doğrulayıcı çıktıları yapısal-JSON olarak DOĞRUDAN diske (kapalı-enum TEMIZ/SUPHELI/SORUNLU +
boolean-iddialar); orkestra-özeti karar-girdisi OLAMAZ; doğrulayıcı spawn-prompt'u sabit-şablon +
disk-pointer (builder-iddiası şablona giremez). Matris `durum`-hücresi ELLE YAZILAMAZ —
`durum_uret` tek-yazar (dörtlü-denetim: FORMAT.md §4).

## Harness + ekip entegrasyonu (config'ten)

`config.harness: goal` → sert-teslim üst-döngünün UYGULA+DOĞRULA fazları İÇİNDE atomik yaşar; kapanış-onayı
üst-harness seviyesinde tekil. `standalone` → kapanış-onayı iş-sahibine doğrudan. Onaysız-kapanış hiçbir
modda yok. `config.ekip.mod: multi-ajan` → tetikler notify + roster-pointer ile; `tek-ajan` → orkestra
firsthand koşabilir AMA deterministik-çekirdek + A4 + 6-koşul ATLANAMAZ.

## Doktrin-bağları (özet — kanon: reference/DOCTRINE.md)

disk=SSOT + diskten-resume · kanıtsız-"bitti"-YASAK · GEREKLİLİK-DOKUNULMAZ (ONAY-1 sonrası; gevşetme =
iş-sahibi-gate + LEDGER) · reset-YOK (çözülmemiş iş STATE/LEDGER'da devreder) · Sx-Altın-Kural:
PROMOTE-eşiği sonrası kaynak Sx'tedir — proje-lokal kopya kaldırılır, `min_skill_version` ihlali = FAIL.
Dağıtım-notu: PROMOTE-eşiği (gerçek-prova + fixture-matrisi + jargon-lint + adversarial-doğrulama +
iş-sahibi-onayı) geçilmeden bu paket proje-lokal kalır.

## Durum kartı formatı

```
SERT-TESLIM · <feature> · vites=<HAFIF|TAM> · iter#<iter_no> · faz=<faz>
   matris: <kanitli>/<toplam> kanitli · <fail> fail · <bekliyor> bekliyor · <engelli> engelli · <olculemez> OLCULEMEZ
   aktif-M: <aktif_m_satirlari>   |   hipotez-Z: <hipotez>
   engel: <engeller> · güncel=<updated_at>
Mod: /sert-teslim devam <feature> · /sert-teslim durum   (kanon: reference/DOCTRINE.md)
```
