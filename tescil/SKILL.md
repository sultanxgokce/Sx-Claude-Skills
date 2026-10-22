---
name: tescil
type: agent
version: 0.6.0
description: >
  MÜHÜRDAR'ın el-kitabı: teslim edilen bir işi (kart) YAZILI gerekliliklere (GOAL + G1..Gn
  komut→beklenen/RC) karşı MAKİNE-KANITLI sınayan kör-protokol tescil-kabuğu. sert-teslim
  (trust_boundary kanıt-JSON + redaction) ve kesif (DOM↔API E2E) skill'lerini BESTELER, yeniden
  icat etmez. Girdi yalnız GEREKLILIK.md + worktree; motor-raporu/transkript okumak İHLAL.
  Verdikt = MUHUR.md + kanit/G<i>.json; kart-durum flip'i YAPMAZ. "/tescil <k####>",
  "/tescil tatbikat" çağrılarında kullanılır (DİVAN K5, k0054).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [tescil, muhurdar, divan, kor-protokol, makine-kanit, oracle, sert-teslim, kesif, anti-tiyatro]
requires: [sert-teslim, kesif]
status: v0.1
---

# /tescil — MÜHÜRDAR tescil-kabuğu (kör-protokol, makine-kanıt)

**NE-DİR:** DİVAN-anayasası Değişmez-3 ("tescilsiz bitti yok") ve Değişmez-11'in (oracle-bağımsızlığı:
tescil yalnız YAZILI gerekliliğe karşı; koddan/rapordan niyet-çıkarımı YASAK; kriter-yazarı ≠ icracı)
icra aracı. Teslim edilen işi, sevk-anında yazılmış `GEREKLILIK.md`'ye karşı **taze koşulan
komutlarla** sınar; verdikt yalnız şemalı kanıtla çıkar. Test-motoru İCAT ETMEZ — kanıt-üretimi
`sert-teslim/core/trust_boundary.mjs` + `core/redaction.mjs`, UI-çapraz-kanıt `kesif/scripts/e2e-run.mjs`
üzerinden KOMPOZİSYONdur.

## Tetikler

| Çağrı | Davranış |
|---|---|
| `/tescil <k####>` | Kartın tescil-koşusu: GEREKLILIK.md oku → G'leri taze koş → MUHUR.md + kanıt yaz. |
| `/tescil tatbikat` | Mühür-tatbikatı prosedürü (anti-tiyatro; aşağıda §Tatbikat). |

## 1 · Kör-protokol girdi-sözleşmesi (İHLAL = tescil geçersiz)

Tescil-koşusunun okuyabileceği girdi **yalnız İKİ şeydir**:

1. **`_agents/tescil/<k####>/GEREKLILIK.md`** — GOAL + G1..Gn (komut → beklenen/RC). Bu dosyayı
   **sevk-anında SERDAR/MİMSERDAR yazar**; motor DOKUNAMAZ (kriter-yazarı ≠ icracı, Değişmez-11).
2. **Motor-worktree'si** — yol + HEAD-SHA (koşu SHA'yı kendisi doğrular; uyuşmazlık = RED).

**Motorun raporunu, transkriptini, commit-mesajını OKUMAK İHLALDİR** — yargıçlar özgüvenli anlatıyla
kandırılır (verifier-literatürü: "One Token to Fool", arXiv 2507.08794); kör-protokol bu kanalı
yapısal olarak kapatır.

**İSİMLİ-RED sınıfları** (tescil koşulmaz, RED-MUHUR yazılır, kart SERDAR'a döner):
- **`gereklilik-eksik`** — GEREKLILIK.md yok ya da hiç G içermiyor.
- **`gereklilik-jenerik`** — kartta ≥1 **DAVRANIŞ-G** yok (yalnız `tsc`/`vitest`/dosya-var sınıfı
  kopyala-yapıştır-G'ler var). Tescil-tiyatrosu MÜHÜRDAR'dan değil jenerik-G'den doğar; kapı burada.
- **`worktree-sha-uyusmazligi`** — verilen HEAD-SHA ile worktree'nin gerçek HEAD'i farklı.

## 2 · GEREKLILIK.md sözleşmesi (parse edilir — serbest-metin değil)

```
KART: k0054
GOAL: <Sultan-dili tek-cümle hedef>
TIP: ui | kod | docs           # docs = docs/skill/infra sınıfı
VITES: TAM | HAFIF             # HAFİF = tek-G + tek-kanıt (küçük işin meşru ucuz yolu)

G1: <kısa açıklama>
  tur: cmd | api-check | e2e-check | llm-yargi | sultan-denemesi
  komut: <tek-satır shell — worktree kökünde koşulur>
  beklenen_rc: 0               # opsiyonel, default 0
  beklenen_desen: <ERE>        # opsiyonel; kırpılmamış çıktıda aranır
  davranis: evet               # DAVRANIŞ-G işareti (kart-başına ≥1 ZORUNLU)
  cwd: <göreli-alt-dizin>      # opsiyonel
  rubrik: <dosya>              # yalnız tur=llm-yargi (Katman-2)
  hedef: <dosya>               # yalnız tur=llm-yargi: yargıca verilen TEK iş parçası (worktree içinde; dışarı kaçış reddedilir)
  tarif: <10 sn'lik deneme>    # yalnız tur=sultan-denemesi: ZORUNLU; mühürdar sınamaz, koşmaz, GEÇTİ saymaz (S5)
```

`sultan-denemesi` (👤, Sultan S5 · 21 Eki): Sultan'ın kendi eliyle deneyeceği satır. Katman-1'de koşulmaz, verdikte girmez,
MUHUR'da `👤 sultan-denemesi | SULTANDA` satırıyla durur, `muhur-ozet.json → sultan_denemesi` listesine düşer; teslim
ekranında en üstte tarifiyle gösterilir. Ajan bu satırı yapamaz ve yapılmış sayamaz (A06). Davranış-G sayılmaz.

DAVRANIŞ-G = işin fiilen YAPTIĞI şeyi sınayan G (çalıştır→çıktı-gözle, uca-istek→cevap-doğrula,
DOM↔API çaprazı). `davranis: evet` işareti ya da `tur: api-check|e2e-check` bu şartı sağlar.

## 3 · İki katman

- **Katman-1 — mekanik-oracle (%100 şart):** her `cmd|api-check|e2e-check` G'sinin komutunu
  tescil-koşusu **KENDİSİ taze çalıştırır** (`scripts/tescil-run.sh`). Motorun yapıştırdığı çıktı
  kanıt DEĞİLDİR; eski denemenin kanıtı devralınmaz (kanıt-tazeliği). PASS/FAIL kararını LLM değil
  süreç verir: komut → RC + çıktı → şemalı `kanit/G<i>.json`. Pipe-maskeleme YASAK; RC her zaman
  kaydedilir. GEÇTİ için Katman-1'in tamamı şart.
- **Katman-2 — yalnız KAÇINILMAZ öznel G'ler** (`tur: llm-yargi`; ör. docs-tonu): boyut-başına
  **izole rubrik** (rubrik-dosyası GEREKLILIK'te işaret edilir; motor-çıktısı-dışı bağlam yüklenmez),
  sonuç `tescil-run.sh --katman2 "G<i>=GECTI|KALDI|EMIN-DEGILIM"` ile deterministik MUHUR'a işlenir.
  **"Emin değilim" → GEÇTİ DEĞİL, ESKALASYON.** Öznel-G sayısı MUHUR'a yazılır (kandırılabilir
  yüzey görünür kalır).

## 4 · İş-tipi asgari-kanıt tablosu (ZORLAYICI — tavsiye değil; `muhur-lint.sh` denetler)

| TIP | Asgari kanıt | Not |
|---|---|---|
| `ui` | ≥1 `e2e-check` G — kesif `scripts/e2e-run.mjs` DOM↔API çapraz-kanıt | **mock-only yeşil YASAK** |
| `kod` (davranış-fiilli) | ≥1 `api-check` (curl-canlı-yüzey / DB-satır / RC-oracle) | tsc/build/lint YETMEZ |
| `docs` (docs/skill/infra) | dosya-varlık / anchor-grep / lint / `bash -n` / `ahi check` | öznel boyut → Katman-2 |

**HAFİF-tescil sınıfı** (`VITES: HAFIF`): küçük iş = tek-G + tek-kanıt — meşru ucuz yol,
defter-dışı-bypass'ın panzehiri. Davranış-G şartı HAFİF'te de geçerlidir (o tek G davranışsal olmalı).

E2E-G örneği (UI-kartı; komut GEREKLILIK'e böyle yazılır, tescil-run normal G gibi taze koşar):
```
G2: panel canlı-listeyi API ile çapraz doğrular
  tur: e2e-check
  komut: sh /config/.claude/skills/kesif/scripts/e2e-env.sh node /config/.claude/skills/kesif/scripts/e2e-run.mjs --panel-url <url> --allowlist <origin> --senaryolar <proje>/senaryolar.mjs --kanit "$TESCIL_OUT/kesif"
  beklenen_desen: "kalan": 0
  davranis: evet
```

## 5 · Verdikt: MUHUR.md + kanıt-şeması

Çıktı-kökü (KONVANSİYON — dizini sevk-akışı yaratır, skill değil): `_agents/tescil/<k####>/deneme-<n>/`
- **`MUHUR.md`** — verdikt-kartı: kart · deneme · verdikt (GECTI|KALDI|ESKALASYON|RED) ·
  worktree_head_sha · gereklilik_sha256 · tip/vites · G-özet-tablosu (kanıt-dosyası + sha256) ·
  skill_version-damgası. **Git'e COMMIT edilir** (merge-anı damga).
- **`kanit/G<i>.json`** — şema: `{g_id, komut, komut_sha256, worktree_head_sha, zaman_utc,
  stdout_stderr_ham (64KB-tavan, redakte) + cikti_tam_sha256, exit_code, beklenen, gozlenen,
  sonuc, kanit_turu}`. Ham artefakt lokal kalır (`.gitignore`: `_agents/tescil/**/kanit/` —
  hash MUHUR'da yaşar; silinen artefaktın geriye-dönük doğrulanabilirliği zayıflar = kabul edilen
  ödünleşim). Redaction (sır-maskesi) **yazım-ÖNCESİ** koşar; sır-değer hiçbir çıktıya düşmez.
- Çıplak "geçti" beyanı şemaya uymaz → `scripts/muhur-lint.sh` otomatik-GEÇERSİZ sayar (RC≠0).

**Kart-durum flip'ini tescil YAPMAZ.** Verdikt raporlanır; flip `scripts/dongu-sayac.sh` (Nexus,
merged) → tek-boğaz GECISLER-route yolundadır. Entegrasyon-notu: dongu-sayac'ın `gecti|kaldi`
komutları **MUHUR.md-varlık şartlıdır** — MUHUR yoksa olay RC≠0 (sahte-verdikt için tam-şema
sahtelemek gerekir). Telemetri: **tescil-run OTOMATİK** (v0.2.0, K1 gözlem-hattı) her koşu-sonucunu
`scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl` `{kart, deneme, verdict, sure_sn,
g_sayisi, oznel_g_sayisi, tip}` satırıyla düşürür (RED-erken-çıkışlar dahil; report-only, RC'ye dokunmaz)
ve verdikt-sonrası `scripts/muhur-lint.sh --tescil-root`'u (şema + jenerik-G) çağırır. Elle-koşum artık
yalnız ad-hoc/yeniden-üretim için.

## 6 · KALDI-paketi (negatif yol — judge-hack hijyeni)

Motora dönen paket YALNIZ şudur: `{düşen-G, komut, beklenen-vs-gözlenen (ham-kuyruk + RC),
sınıf: İŞ-EKSİK | GEREKLİLİK-MUĞLAK}`. **Tescil-koşusunun iç-muhakemesi motora VERBATIM DÖNMEZ**
(motor yargıcı gam'lamayı değil işi düzeltmeyi öğrensin).

- **İŞ-EKSİK** (default): iş gerekliliği karşılamıyor → kart motora döner, deneme-sayacı yanar.
- **GEREKLİLİK-MUĞLAK:** false-red ayrıştırması — kart **SERDAR'a** döner, **deneme-sayacı YANMAZ**;
  MUĞLAK-teşhisi gerekçe + **gerekliliğe düzeltme-diff'i** şartıyla konur (diff karta damgalanır,
  MUĞLAK-verdikti gereklilik-yazarının karnesine işlenir). Aynı kartta **2. MUĞLAK = otomatik
  Sultan-eskalasyonu** ("gereklilik-yazımı sorunlu").
- 3. KALDI → eskalasyon dongu-sayac/köprü-cron tarafında (tescil yalnız verdikt üretir).

## 7 · Araç-seviyesi ayrım (tester ≠ fixer — yapısal)

Tescil-koşusu **ürün-koduna Edit/Write İZİNSİZDİR** — salt-okur + komut-koşucu. Yazma-yetkisi
YALNIZ `_agents/tescil/**` path'ine. Düşen G'yi tescil-koşusu DÜZELTMEZ (KALDI-paketi döner; fix
motorun işi). Her tescil TAZE oturum/subagent koşusudur (bayat-G-matrisi karışması sınıfı kapanır).

## 8 · Tatbikat — `/tescil tatbikat` (anti-tiyatro)

Her ~20 tescilde 1 (ya da ayda 1): SERDAR **bilinçli-BOZUK bir işi normal kart gibi sevk eder**
(tescil-koşusu tatbikat olduğunu BİLMEZ — kör kalır). Beklenen: **KALDI**.
- Verdikt **GEÇTİ dönerse = "tescil-hattı bozuk"** → otomatik Sultan-eskalasyonu.
- Sonuç telemetriye `tip=tatbikat` satırıyla işlenir: `telemetri-append.sh ... --tatbikat`.
- UI-işlerinde skill-içi eşdeğeri: kesif `enjeksiyon.mjs` ULTIMATE-dogfood (sahte-yeşil enjekte →
  E2E-kırmızı kanıtı).
- Tatbikat-fixture'larından en az biri dönem-içinde **öznel-G'li** olmalı (Katman-2 yüzeyi de
  örneklensin). Rubber-stamp alarmı (report-only): KALDI-oranı→0 ∧ median-süre→kısa birlikteliği.

## 9 · Kullanım

```bash
# Katman-1 koşusu (tam):
bash scripts/tescil-run.sh k0054 \
  --gereklilik _agents/tescil/k0054/GEREKLILIK.md \
  --worktree /path/to/motor-worktree --head-sha <sha> \
  --out _agents/tescil/k0054/deneme-1
# RC: 0=GECTI · 1=KALDI · 2=harness/kullanım · 3=KATMAN2-BEKLIYOR|ESKALASYON · 4=İSİMLİ-RED

# Katman-2 sonucu işleyip MUHUR'u yeniden üret (mekanik G'ler TAZE yeniden koşulur):
bash scripts/tescil-run.sh k0054 ... --katman2 "G3=GECTI"        # ya da KALDI / EMIN-DEGILIM

# Verdikt-lint (şemasız/çıplak-geçti = geçersiz; iş-tipi asgari-kanıt zorlanır):
bash scripts/muhur-lint.sh _agents/tescil/k0054/deneme-1 [--tescil-root _agents/tescil]

# Telemetri + muhur-lint: v0.2.0'dan beri tescil-run bunları OTOMATİK çağırır (K1 gözlem-hattı,
# report-only, RED-çıkışlar dahil); aşağıdaki elle-koşum yalnız ad-hoc/yeniden-üretim için:
bash scripts/telemetri-append.sh --file _agents/tescil/telemetri.jsonl \
  --kart k0054 --deneme 1 --verdict GECTI --sure 42 --g 3 --oznel 0 --tip kod
```

`muhur-lint.sh --tescil-root` verildiğinde **jenerik-G dedektörü** koşar: bu kartın G-komut-sha'ları
son-20 kartla >%70 örtüşüyorsa "jenerik-gereklilik" UYARI-satırı basılır (SERDAR-telemetri girdisi).

## 10 · Mühürdarlık akışı — `muhurdar.sh` (0.3.0 · G8 · Sultan D1 22 Eki "Üç alana böl")

Mühürdarlık uzmanlığının **Tescil** vazifesinin usulü (kadro şeması §4-§5 `tescil-teslim-sina`). tescil-run.sh'ı yeniden
yazmaz, üstüne kurar:

| Adım | Tür | Ne yapar | Nerede |
|---|---|---|---|
| 1 | kapı | biçimsiz gereklilik belgesini reddeder | tescil-run → gereklilik.py (İSİMLİ-RED) |
| 2 | kapı | yazan = mühürdar ise koşuyu reddeder — **kendi işini mühürleyemez** (casefold karşılaştırma) | muhurdar.sh → İSİMLİ-RED `kendi-isi`, hiçbir G koşulmaz |
| 3 | beceri | G'leri **kör** sınar; 👤 satırları atlar | mekanik: tescil-run · öznel: her G için **yeni** yargıç oturumu |
| 4 | beceri | kanıt JSON'u sınır + redaksiyonla mühürlenir | tescil-run → g-kosucu (sert-teslim) |
| 5 | 👤 Sultan eli | 👤 satırlarını teslim ekranında dener | YAPILMAZ — MUHUR'da `SULTANDA` |

- **Taşıyıcı:** Mühürdarlığı **MUHAKKİK** taşır (Sultan D1 22 Eki, "MUHAKKİK (önerim)"); koltuğu salt okurdur, kendi işini
  mühürleyemez. Başsız şapka (S14) yalnız yedektir.
- **Kimlik:** mühürdar = `AGENT_NAME` (yoksa rc 2, mühür basılmaz); yazan = `--yazan` (kartın `aldi`'sı; yoksa rc 2).
  Adlar **Türkçe harf katlamasıyla** karşılaştırılır (İ/ı/I/i aynı): `'MUHAKKİK'.casefold()` `'MUHAKKIK'` ile eşleşmez
  (ölçüldü) ve kayıtlarda iki yazım da yaşıyor — kendi-işi kapısı ve sicil eşleşmesi bu yüzden katlanmış adla bakar.
- **Kör:** yargıç istemi (`lib/kor-istem.py`) yalnız GOAL + o G'nin satırı + izole rubrik + `hedef:` dosyası + mühürdarın
  **kendi taze** mekanik kanıt tablosundan kurulur. İnşacının raporu, transkripti, commit mesajı açılmaz; rapor verecek
  bir argüman yoktur (bilinmeyen argüman rc 2). `hedef` iş ağacı dışına kaçarsa istem kurulmaz → EMIN-DEGILIM.
- **Temiz koşu:** her öznel G kendi oturumunda (`codex exec --ephemeral` / `claude -p`); bir G'nin yargısı ötekine taşınmaz.
- **Model:** Codex erişilebilirse Codex, değilse Claude (karar 2); Codex düşerse — zaman aşımı dahil — Claude'a yeni oturumla geçilir.
- **Tek ölçüm:** yargıcın gördüğü mekanik kanıt mühürde kullanılan kanıttır; mühürden önce G'ler YENİDEN KOŞULMAZ.
  `MUHURDAR_MODEL=claude` Codex'i bilerek atlar. Süre `MUHURDAR_ZAMAN_ASIMI` (900 sn, `-k 30`).
- **Bozuk cevap GEÇTİ sayılmaz:** geçersiz/eksik JSON ya da zaman aşımı → `EMIN-DEGILIM` → ESKALASYON (§3).
- **MUHUR başlığı:** `muhurdar · yazan · yargic (G=model) · kor` satırları; `g_sultan` sayısı.

```bash
AGENT_NAME=<mühürdar> bash scripts/muhurdar.sh <iş> --gereklilik <GEREKLILIK.md> --worktree <iş ağacı> \
  --out _agents/tescil/<iş>/deneme-<n> --yazan <inşacı> [--head-sha <sha>] [--deneme n] [--tatbikat]
# RC tescil-run ile aynı: 0 GECTI · 1 KALDI · 2 kullanım · 3 ESKALASYON · 4 İSİMLİ-RED (kendi-isi dahil)
#    · 5 mühür basıldı ama özlüğü olan mühürdarın siciline DÜŞMEDİ (verdikt özette; özette `sicil: dusmedi …`)
```

Sınav: `scripts/muhurdar.test.sh` (18 kapı + kontrol kopyası + 11 mutant; sahte yargıçlar, ağsız; usul sırası: biçim kapısı kendi-işinden önce — göz #409 tur 1; yargıç ve mühür aynı ölçüm, Codex zaman aşımında da Claude — tur 2). Sicil/ders çıkarma/askı
§11'de (G11 · S10), diploma §13'te (G13).

**Başsız şapka (S14 · 0.6.0):** taşıyan (MUHAKKİK) bekleme süresinde (tarif `yedek.bekleme_dk`, 30 dk) başlamazsa yedek koşu
`muhurdar.sh … --bassiz` ile başlar — **usul aynı** (biçim kapısı → kendi-işi → mekanik → kör taze yargıç), el kitabı aynı. Mühür
başlığına `bassiz: evet …`, özete `"bassiz": true` yazılır; sicilin mühür kaydı `bassiz: e` ile **taşıyanın siciline** düşer.
Başsız koşu kod yazmaz, birleştirmez; yalnız tescil. 🔴 **Çağıran bu sürümde YOK** — bayrak bugün yalnız elle verilir. Tetik
(Nexus boşta bekçisi turu, görev başına kilitle tek koşu — SERDAR 22 Eki 14:36) ayrı kartta; koşulu henüz kesin değil (hedef işi
mühürsüz `onay-bekliyor`a geçemiyor, şema §11c G9).

## 11 · Sicil · ders çıkarma · askı — `sicil.sh` (0.4.0 · G11 · S9 · S10)

Mühürdarın isabeti **Sicil**'dir (S9: "karne" değil): personelin özlük dosyası `_agents/federe/sicil/<personel_no>.yaml`
→ `isabet:` bölümü (append-only; yeni defter kurulmaz). Mühürdarlık vazifesi **Ders çıkarma** (S9; eski adı Kalibrasyon).

- **İsabet satırı** (kadro şeması §6 + `g_tur · neden · kaynak`): teslim ekranında Sultan bir satıra "sağlanmadı" ya da
  "katılıyorum" der → `sicil.sh isabet <mühürdar> …`. **Kaçırma** = mühürdar ✓ verdi, Sultan "sağlanmadı" dedi.
  🔴 A06: `--kaynak` Sultan'ın KAYDINA işaret eder ve **doğrulanır**: `SICIL_KAYNAK_DOGRULA <kaynak>` (teslim geçidi sağlar)
  Sultan'ın kayıtlı kararını JSON basar (`{"gorev", "satirlar": {"G1": {"sultan", "neden"}}}`); hüküm YALNIZ bu çıktıdan
  alınır — ajan kaynağı gösterebilir, içeriği uyduramaz (göz #411 tur 1). Doğrulayıcı yoksa rc 3, kayıt yok ya da satırı
  doğrulamıyorsa rc 2; ikisinde de yazılmaz. "Sağlanmadı"da Sultan'ın tek cümlesi zorunlu (kayıttan ya da `--neden`).
- **Teslim köprüsü:** `sicil.sh teslim-isle <mühürdar> --kaynak <ref> --muhur-dir <deneme-dir>` — geçit Sultan'ın TEK teslim
  kararıyla bir kez çağırır; mühürdarca sınanan her satır için isabet yazılır (👤 satırı atlanır, düşen G'de mühür ✗); aynı
  karar iki kez işlenmez, kısmi karar ve başkasının mühürü reddedilir.
- **Mühür kaydı:** `muhurdar.sh` her mühürde mühürdarın siciline `tur: muhur` satırı yazar (özlük yoksa söyler, mühür
  düşmez; özlük VARKEN yazım düşerse sessiz değil: rc 5 + özette `sicil: dusmedi …`). Yazım süreçler arası kilitli, tek
  seferde (ya hepsi ya hiçbiri); aynı karar/satır iki kez yazılmaz. Askı penceresi bu kayıtlardan sayılır — Sultan satırı gelmeyen temiz mühür de pencereyi ilerletir. Özlük dosyası yoksa yazılmaz (rc 3 — özlük KÂHYA'nın işi).
  Yazıcı satırı geri okuyarak doğrular; `isabet:` dosyanın sonunda değilse eklemez.
- **Askı** (S10): `sicil.sh durum <mühürdar>` son **10 mühürde** (mühür = görev teslimi) kaçırmalı mühür sayar —
  **1** = ders çıkarma (askı yok) · **2** = **askıda** + el kitabı güncelleme + yeniden sınav. Eşik tarif kaydındaki
  `muhurdarlik.sicil_esigi`'nden okunur, yoksa S10 varsayılanı. Diploma durumu buradan türetilir (saklanmaz).
- **Ders çıkarma** (G11, Sultan: "çok ama çok önemli"): `sicil.sh ders <mühürdar>` bağlanmamış kaçırmaları gereklilik
  türüne göre gruplar; **≥2 ayrı görevde** aynı tür = tekrar eden kaçırma → §12 ders günlüğüne `D-NNN` kural taslağı
  (Sultan'ın cümleleriyle). Kural el kitabına PR ile yazılır, tek kaynaktan bütün kutulara iner; sonra her kaçırma
  `sicil.sh ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN` ile bağlanır (ters kayıt; günlükte olmayan derse bağlanmaz).
  Ölçüm: sicil + bu günlük (G11).

Sınav: `scripts/sicil.test.sh`.

## 12 · Ders günlüğü (Mühürdarlık el kitabı değişiklik günlüğü — G11)

Biçim: `- **D-NNN** (YYYY-MM-DD · tür: <g_tur> · kaçırmalar: <mühürdar> <ts>, …) <kural cümlesi> — PR #<n>`.
Bugün kural yok: henüz Sultan'ın "sağlanmadı" dediği bir mühür kaydı düşmedi.

## 13 · Diploma — `diploma.sh` (0.5.0 · G13 · kadro şeması §1b `sinav.kume` · §6 diploma defteri)

Bir personel Mühürdarlık uzmanlığını **sınavla** alır; diploma saklanmaz, defterden **türetilir**.

- **Sınav kümesi:** `sinav/{dogru,kusurlu,uydurma}/<ad>/` — her türde en az bir örnek (biçim `sinav/README.md`). Her örnek
  mühürdarın GERÇEK usulüyle (`muhurdar.sh`, kör taze yargıç) geçici bir kökte koşulur; gerçek sicile ve telemetriye yazmaz.
- **`diploma.sh sina <personel> --kanit <dizin>`** — isabet: doğru → GEÇTİ · kusurlu/uydurma → KALDI **ve** beklenen G düşmüş.
  EMIN-DEGILIM isabet sayılmaz. Geçme = tam isabet. Iskalanan örnek **en çok bir kez** yeniden koşulur; iki koşu çelişirse
  sınav **ÖLÇÜLEMEDİ** (rc 3, kararsız) — deftere ne KALDI ne GEÇTİ yazılır. Satır §6 biçiminde
  (`ts personel uzmanlik el_kitabi el_kitabi_surum kume_sha sonuc gecti kanit`), kilitli ve yarım kalmadan yazılır (kısa yazımda defter eski boyuna kesilir), geri okunur.
- **`diploma.sh durum <personel>`** — esas SON koşudur: koşu yok ya da son koşu kaldı → **yok** · sicil askıda → **askida** (§11) ·
  el kitabı sürümü (katalog) ya da küme özeti değişti → **bayat** (yeniden sınav) · sicil okunamıyorsa (ör. özlük yok) →
  **ölçülemedi** (rc 3 — askıda olmadığı bilinmeden geçerli denmez) · aksi → **gecerli**. Defterde bozuk satır
  varsa `bozuk: N` deyip ölçülemedi döner (sessiz atlamaz); yarım kalmış satır `diploma.sh bozuk-kapat <N> --gerekce "…"` ile
  ters kayıtla kapatılır (satır silinmez, yalnız açık bozuk satır kapanır).
- 🔴 **Dürüst sınır — cevap anahtarı:** kör istem `beklenen.json`'u taşımaz, ama yargıç oturumu dosya sistemini **okuyabilir**;
  cevap anahtarını kendi arayıp bulan (ya da örnekleri ezberleyen) bir yargıcı bu sınav **ölçmez**. Bu bir sınırdır, kapı değil;
  kümenin gücü örnek sayısıyla ve örnekler yenilendikçe artar.

Sınav: `scripts/diploma.test.sh` (hermetik sahte yargıçlar + mutantlar). Ölçer: gerçek yargıçla 6/6 (PR #412 kanıtı).

## Tasarım-notu — dış-araç kararı (2026-07, DİVAN K5)

Dış-araç (**TestSprite**) 2026-07'de değerlendirildi, **4 gerekçeyle evde kalındı**:
(1) **kapsam** — motor-çıktılarının çoğu web-UI değil (skill/bash/infra/doküman/backend), dış-araç
göremez; (2) **oracle-kirlenmesi** — koddan-intent-çıkarımı, "yalnız YAZILI gerekliliğe karşı"
ilkesinin (Değişmez-11) tam tersi; (3) **önce-test-sonra-kullan + sır-hijyeni** — test edilmemiş
bulut-sandbox'a private-kod/credential çatışması; (4) **false-verdict maliyeti** — güvenilmez gate
her sahte-KALDI'da yeniden-çalışma + yanlış Sultan-eskalasyonu üretir. İleride YALNIZ Sultan-GO'lu
**İKİNCİL-SİNYAL** pilotu mümkündür (bulgu MUHUR'a "ek-gözlem" satırı olarak düşer);
**verdict-otoritesi ASLA dışarı verilmez** — bu kural tatbikat-denetimlidir.

## Kademe

Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
`requires: [sert-teslim, kesif]` — çekirdeklerine YAZMAZ, yalnız çağırır (owner-domain-dokunma).
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check tescil` · Kanon: `ahi doctrine`.
