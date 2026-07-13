# sert-teslim DOKTRİNİ — değişmezler (kapalı-liste, MOTOR)

Bu liste KAPALIDIR; değişiklik = major-semver + iş-sahibi-gate + CHANGELOG/LEDGER-gerekçesi.
Metin GENERIC'tir: gerçek proje-adı / port / roster-adı geçmez; roller soyuttur
(**orkestra · builder · dogrulayici · is-sahibi**). Matris-grameri + `durum`/`kanıt-türü` enum'ları +
kanıt-JSON şeması + dörtlü-denetim: `FORMAT.md` (bu doküman tekrar etmez, referansla konuşur).

## 1. Beş gaming-savunması (hepsi MEKANİK — niyet değil, lint)

### 1.1 Kanıt-gücü-lint'i
Görünürlük/davranış-fiilli cümlede (çekirdek fiil-listesi MOTOR: göster/görün/listelen/çalış;
config `ek_fiiller` yalnız GENİŞLETEBİLİR, daraltamaz) kanıt-türü ∈ {build/lint `komut`} = lint-FAIL —
en az `api-check`, UI-fiilinde `e2e-check`. ONAY-1 kartına kanıt-türü dağılım-özeti girer.
A4 alt-görevi: "bu komut, gereklilik HİÇ yapılmamışken de geçer mi?" — cevap evet = bloker.

### 1.2 Kırmızı-kanıt şartı
`kanitli` için kanıt-JSON'da ≥1 FAIL-kanıtı referansı zorunlu: özellik-öncesi commit'te ya da
A3-mutasyon altında FAILED-koşum. **Hiç FAIL edemeyen test KANIT SAYILMAZ.**

### 1.3 Durum = türetilmiş-veri (tek-yazar) + dörtlü-denetim
`durum` kolonu ELLE YAZILAMAZ; `durum_uret` kanit/-JSON'larından REJENERE eder. Dörtlü-denetim
(FORMAT.md §4): geçerli-JSON + komut-hash-eşleşmesi + rc==0 + tazelik — biri eksik = lint-FAIL,
teslim-raporu üretilemez. Komut↔satır eşlemesi LLM'den yalnız ÖNERİ olarak gelir; A4 her teslimde
rastgele 2-3 satırda eşleme-denetimi yapar (davranışı boz → eşlenen komut FAIL vermeli).

### 1.4 Kanıt-invalidasyonu (git-diff × etki-alanı)
Her iter-sonu git-diff, satırların etki-alanı-glob'larıyla kesiştirilir; kesişen satır OTOMATİK
`kanitli→bekliyor`. `gorsel-onay` satırları meta taşır: "son-onay iter#N, sonrası M dokunuş";
M>0 → yeniden-onay zorunlu.

### 1.5 Sayaç-baseline (KODLANDI — `core/sayac_baseline.mjs`, F1)
skipped-delta>0 VEYA collected-düşüşü = gate-FAIL (tek istisna: iş-sahibi-görünür allowlist +
LEDGER-gerekçe). Teslim-gate tam-kapsam komutları komut-hash'le SABİT — filtreli-koşum
hash-uyuşmazlığından FAIL. Counter-parse başarısız ⇒ `counters: null` = ZAYIF-kanıt; **parse-fail
ASLA PASS'e default'lanamaz.** `gate_cmds` içinde hiç sayaçlı-runner yoksa teslim-raporu İLK-SATIR
"SAYAÇ-KANITSIZ" manşeti basar + kanitli-satırların kanıt-gücü üst-sınırı "zayıf" etiketlenir.

**Baseline-store `<feature>/baseline.json`** (KUR üretir; JSON — YAML-parse YOK). Şema:
```json
{ "olusturuldu": "ISO", "gate_cmds": [
  { "id": "<gate-id>", "komut": "<tam-suite komut>", "komut_sha256": "<64-hex>",
    "runner": "<pytest|vitest|node-test|generic-rc>",
    "min_collected": <n>, "max_skipped": <n> } ] }
```
`min_collected`/`max_skipped` YALNIZ sayaçlı-runner'da (yokluğu = generic-rc = sayaçsız). teslim-lint
her `gate-<id>.json` kanıtını denetler: (a) baseline-integrity (entry.komut_sha256 == sha256(entry.komut));
(b) **HASH-SABİT** kanıt.komut_sha256 == baseline (filtreli/değiştirilmiş komut → uyuşmazlık → FAIL);
(c) rc==0; (d) counter-floor collected≥min ∧ skipped≤max (counters=null → İHLAL). Hiç sayaçlı-gate
geçmezse `sayac_kanitsiz` → rapor-manşet ZORUNLU. **Grandfather:** baseline.json yoksa §1.5 atlanır
+ görünür-UYARI (F1-öncesi mühürlü-teslimler geçer; yeni-teslimlerde KUR baseline.json ZORUNLU üretir).

## 2. Tek-kadans (üç-ad / iki-gramer / üç-frekans YASAK)

- **A1 gate-runner:** HER iter, deterministik-TAM (`gate_cmds` + teslim-lint; token≈0 — ekonomik bel-kemiği).
- **MUTABAKAT-REJENERASYON:** HER iter (`durum_uret`); pahalı kanıt-tipleri yalnız dokunulan-satırda,
  tam-tarama yalnız teslimde.
- **A2 safety:** yalnız TETİKLİ iter'de MİNİ-kapsam (tetik: yeni-guard / şema-değişikliği /
  güvenlik-yüzeyi); girdisi D-CORE ∪ D-LOCAL + "test neyi GÖREMEZ" sorusu. Teslimde TAM.
- **A3 mutasyon:** yalnız guard-ekleyen/değiştiren iter'de; worktree-izole, byte-revert. Teslimde TAM.
- **A4 MUTABAKAT:** yalnız TESLİM-GATE'te (taze-subagent + sayımsal-lint; ara-tarama yok — ekonomi).

## 3. Cost-vanaları (kapalı-liste)

1. **Ön-bütçe-gate:** >40 M-satır ∨ tahmin>15-iter → başlamadan iş-sahibi-onayı.
2. **İter/token-tavanı:** STATE'te (config'ten opsiyonel); aşım = DUR + iş-sahibi-onayı.
3. **Dönme-gate:** aynı M-satırı `donme_gate_iter` iter üst-üste fail → iş-sahibi-gate.
4. **Deterministik-önce:** kırmızı-A1-gate'te LLM-çağrısı yapılmaz — önce mekanik neden raporu.
5. **Taze-context-iter:** her iter DİSKTEN okur (STATE/MATRIS/LEDGER), transkriptten/özetten değil.
6. **Model-hiyerarşi-kilidi:** iter-içi üst-model yalnız İSİMLİ-gerekçeyle; gerekçe LEDGER'a yazılır.

## 4. Yol-çözüm-kontratı

Tüm config/state yolları `git rev-parse --git-common-dir` üzerinden ANA-repo-köküne pinlenir
(worktree'de bile). A3-worktree yalnız KOD-mutasyonu içindir; verdict-JSON'lar HER ZAMAN ana-tree
`state_root`'una yazılır; tazelik-denetimi ana-tree git-geçmişine bakar (false-fresh kapalı).
Her verdict-JSON'a `proje_koku` + `config_yolu` damgası; teslim-lint uyuşmazlıkta FAIL.
Config bulunamadı ⇒ İSİMLİ-red ("bu projede KUR koşulmamış") + en-yakın config-yolu önerisi;
sessiz-varsayılan YOK.

## 5. Eskalasyon-kuralları

- Gate'ler: **dönme-gate** (§3.3) · **flip-gate** (aynı satır `kanitli↔fail` 2-flip) · **scope-gate**
  (kapsam > 2×ONAY-1-satır-sayısı) · **10-iter-checkpoint** (hard-stop değil; durum-kartı sunulur).
  Gate'e çarpınca OTONOM-DEVAM YASAK — karar iş-sahibinindir.
- Eskalasyon-kartı teslim-raporundan YAPISAL-AYRI belgedir; gövdesinde "teslim" kelimesi GEÇEMEZ
  (yarım-işin bitmiş-gibi-algılanması yapısal-kapalı).
- `engelli`-park otomatik tohum/backlog-sahipli + yeniden-değerlendirme-tarihli akar; kümülatif
  engelli-sayacı iş-sahibi-kartında trend-satırı olarak görünür.
- ONAY-1-sonrası gereklilik-gevşetme YALNIZ iş-sahibi-gate + LEDGER-gerekçeyle (GEREKLİLİK-DOKUNULMAZ).

## 6. STATE.json şeması

```json
{
  "feature": "ornek-feature",
  "vites": "HAFIF|TAM",
  "iter_no": 0,
  "faz": "KUR|HEDEFLE|UYGULA|A1|MUTABAKAT|EKSIK|KARAR|TESLIM-GATE|ESKALASYON",
  "aktif_m_satirlari": ["M1", "M2"],
  "hipotez": "[X yapılırsa] → [Y olur] → [Z: hedeflenen satırların doğrulama-komutu-PASS'i]",
  "engeller": [],
  "compact_carry": null,
  "updated_at": "ISO-8601"
}
```

Kurallar: alan-adı `iter_no` — ASLA `cycle_no` (harness ad-uzayı çakışması yapısal-kapalı).
`compact_carry` motor-etiketlidir: `{"motor": "sert-teslim", "kaldigi_yer": "...", "yarim_isler": []}`.
STATE her faz-geçişinde diske yazılır; resume DAİMA STATE + MATRIS + LEDGER'dan (disk = SSOT).

## 7. LEDGER-satır-biçimi (append-only)

```
| iter#<N> | <ISO-tarih> | hedef: <M-listesi> | sonuç: kanitli+<n> fail+<n> engelli+<n> | kanıt-ref: <wf-id|kanit-yolu> | not: <tek-cümle> |
```

Kurallar: append-only — satır silinemez/değiştirilemez. Her iter'in KARAR fazı tam-1 satır yazar.
Gate/eskalasyon/ONAY-1/gereklilik-gevşetme olayları da birer gerekçeli satır alır. LEDGER-satırı
olmayan iter kanıt-zincirinde YOK sayılır.

## 8. FAZ-1 statü-açıklamaları (implementasyon-tavanı — §1-7 değişmezleri değiştirmez)

Bu maddeler mevcut değişmezleri GEVŞETMEZ; yalnız hangi mekaniğin bu fazda BAĞLI, hangisinin
sonraki-faza rezerve olduğunu şeffaflaştırır (sessiz-varsayılan yerine yazılı-tavan).

- **Redaction statüsü:** FAZ-1'de opt-in kütüphane (redakte/karantinaTara); emit-öncesi
  ZORUNLU-geçiş (artefakt-emit-gate) FAZ-2 — şimdilik doğrulayıcı-artefaktları elle-redaksiyon-
  disiplinine tabi.
- **Runner-katalog tavanı:** trust_boundary runner-kataloğu (pytest/vitest/node-test/generic-rc)
  kapalı; katalog-DIŞI runner = config-supplied adapter FAZ-2'ye kadar YOK → o dilde teslim
  şimdilik generic-rc (ZAYIF-sınıf) ile.
- **§1.5 durumu:** sayaç-baseline (skipped-delta/collected-düşüş) kural YAZILI, mekanik-store
  FAZ-2 — fix-now'da counters=null→ZAYIF + parse-fail=FAIL kodlu; tam-baseline bir-sonraki-
  teslimde koşulmalı.
