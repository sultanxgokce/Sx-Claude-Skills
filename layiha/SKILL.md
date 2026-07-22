---
name: layiha
version: 1.1.0
description: Bir konuyu kapsamlı ARAŞTIR, kalıcı bir tasarım-dokümanına (layiha) SABİTLE, inşayı SONRAYA bırak — kayıt-defterine işle, Sultan'a sabit-formatta teslim et + geri-dönüş-kolu bırak. "araştır inşayı sonra yaparız · bunu dökümana sabitle · layiha çıkar · aktif layihaları listele · bu haftaki layihalar" tetiğinde. GLOBAL (tüm container'lar).
allowed-tools: Bash, Read, Write, Edit, Agent, AskUserQuestion
---

# /layiha — araştır → kalıcı sabitle → inşayı sonraya bırak (+ kayıt-defteri)

> **Ad:** *layiha* (Osmanlıca لايحه) = bir mesele üzerine hazırlanıp karar-merciine sunulan yazılı rapor/tasarı.
> **GLOBAL skill** — her container'da çalışır; defter **per-container** (İ1: container'lar birbirinin layihasını görmez).

**Ne zaman:** Sultan "bunu araştır ama inşayı sonra yaparız / kapsamı net olsun şimdilik" dediğinde; VEYA
"aktif layihaları/bu haftakini listele" dediğinde. Amaç: iş **kaybolmasın** + Sultan'ın önüne tek-tuşla-devam gelsin.

## Değişmezler
- **SALT-ARAŞTIRMA — İNŞA YOK.** Doküman kod/host'a dokunmaz.
- **Kanıtsız-yeşil YASAK** (firsthand dosya:satır/URL). **Provenance-dürüstlüğü**: alt-ajan yaptıysa
  "kendi altımda araştırma alt-ajanı koşturdum" de; persona-adıyla sunma (ağır+persona-hafıza→gerçek-oturum).
- **Kayıp-riski panzehiri:** doküman ASLA yalnız untracked kalmaz → 3-kanal + **kayıt-defteri** zorunlu.

## MOD 1 — YENİ LAYİHA (araştır → sabitle → teslim)

### 0 · Kapsam (kısa)
konu · neden şimdi-inşa-değil · bakılacak mevcut-parçalar · efor (default yüksek). Slug = ASCII-kebab.

### 1 · Araştırmayı dispatch et
Varsayılan = SERDAR-altı araştırma alt-ajanı (Agent `general-purpose`, `model:opus`, `run_in_background`).
Prompt kalıbı (ZORUNLU): *"Araştırma alt-ajanısın, persona değilsin. SALT-ARAŞTIRMA — İNŞA YOK, host'a dokunma.
Her iddia firsthand dosya:satır. [1] problem-doğrulama [2] mevcut-parça envanteri [3] gap-listesi [4]
tasarım-seçenek+ÖNERİ [5] fazlama(additive/INERT) [6] açık Sultan-kararları [7] risk+panzehir. Dokümanı
`_agents/spec/<slug>-DESIGN.md`'e YAZ (başlık: 'Statü: SALT-ARAŞTIRMA — İNŞA YOK'), commit ETME. 12-15 satır
özet döndür."* Ağır+persona-hafıza→gerçek-oturum (aile-dispatch).

### 2 · Dönünce — 3-KANAL + DEFTER (ZORUNLU)
1. **git-durable:** origin/main worktree → doc kopyala → commit (scopeless `docs: <konu> araştırma DESIGN`) →
   PR → `scripts/wait-ci.sh <#> &` → yeşil → merge → worktree temizle.
2. **memory-topic:** `project_<slug>.md` + MEMORY.md pointer + RESUME-TETİK cümlesi.
3. **defter:** `append-note.sh` özet + resume.
4. **KAYIT-DEFTERİ (YENİ):** `bash <skill-dizini>/scripts/layiha-defteri.sh ekle --slug <slug> --konu "<konu>"
   --dokuman "<yol>" --pr "#<PR>" --resume "<resume-cümlesi>"` → durum=insa-bekliyor.

### 3 · Sultan'a TESLİM (SABİT FORMAT — birebir)
```
Araştırıldı: <2-3 cümle — verdikt + en-kritik bulgu>
Doküman: <_agents/spec/<slug>-DESIGN.md> (detay burada, git'te #<PR>)
Context-odak cümlesi: "<resume-tetik>" de → context'imi buna odaklarım
```
Birden çok araştırma → her birini AYRI blokla.

### 4 · İnşa ERTELENİR
Build YALNIZ Sultan resume-cümlesini söyleyince. İnşa BİTİNCE: `layiha-defteri.sh durum <kod|slug> insa-edildi`.
Her kayıt otomatik bir KOD alır (L01, L02… — karışmasın); `durum` komutu kod ya da slug kabul eder.

## MOD 2 — LİSTELE (önizleme + durum + zaman-filtresi)
Sultan "aktif layihaları listele / bugünküleri / bu haftakini / bu hafta bitmemişleri göster" deyince:
```
bash <skill-dizini>/scripts/layiha-defteri.sh liste [--aktif(default) | --bugun | --hafta | --hafta-bitmemis | --hepsi]
```
- **--aktif** (default): inşa-bekleyen tümü (Sultan "aktif tümünü listele").
- **--bugun** · **--hafta** · **--hafta-bitmemis** (bu hafta ∧ yapılmamış) · **--hepsi**.
Her satır: **[KOD]** + durum (⏳ inşa bekliyor / 🔨 inşa ediliyor / ✅ yapıldı) + konu + **oluşturulma-tarihi** +
"…de" devam-cümlesi. Çıktı zaten Sultan-dili → olduğu gibi bas. Defter boşsa "kayıt yok" — uydurma.

## Sınırlar / dürüstlük
- Skill kod-içermez (talimat + `layiha-defteri.sh` yardımcısı). İnşa-yetkisi VERMEZ; her build Sultan-GO.
- Defter per-container (İ1 yalnız-yerel); fleet-rollup gerekirse ayrı meta-iş.
