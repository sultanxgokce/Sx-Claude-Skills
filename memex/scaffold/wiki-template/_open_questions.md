---
sayfa_id: wiki._open_questions
kategori: meta
son_guncelleme: 2026-05-05
guvenilirlik: yüksek
önem: 4
etiketler: [meta, soru, beklemede, audit]
---

# Açık Sorular Arşivi (Cortex)

Yanıt bekleyen sorular. **Cevap geldikçe ilgili karar/konu dosyasına taşı + buradan kaldır.**

---

## 🟡 S1 — dream.py parse hatası (DREAM_REPORT.md ↔ log.md çelişkisi)

**Soru:** dream.py JSON parse hatası gerçekten çözüldü mü?

**Çelişki kaynağı:**
- DREAM_REPORT.md: U1 uyarı — "çözülmedi"
- cortex/log.md: "cortex_sync.ts, lib/cortex.ts loader prodüksiyon"

**Çözüm yolu:** Hangisi güncel? Manuel kontrol ile kapat (gerçek dream çıktısı parse oluyor mu?).

**Tarih:** 2026-05-05 audit'te tespit edildi.

---

## 🟡 S2 — MMEpanel görev senkronizasyonu (Cortex vs Veri Genom çift truth)

**Soru:** MMEpanel görevleri hangi sistemde master truth?

**Mevcut durum:**
- Cortex: `wiki/mmepanel/aktif-gorevler.md` (2026-05-01, taze)
- Veri Genom: `_agents/docs/veri-genom/wiki/aksiyonlar/veri-saglik-90-yolhartasi.md`
- İkisi ayrı repo, manuel senkron riski

**Karar önerisi:** Veri Genom master (commit history avantajı), Cortex aynalı (`/api/cortex/pull-mmepanel` zaten çekiyor).

**Tarih:** 2026-05-05 — netleşmesi bekleniyor.

---

## 🟡 S3 — Karar Pipeline (Sultan'ın 5⭐ vizyonu) durum

**Soru:** `karar-pipeline-vizyonu.md` (Faz A/B/C) implementasyon ne durumda?

**Mevcut:** Vizyon yazılı (74 satır), ama "nereye uygulandı?" notu yok. Kanıt linki yok.

**Çözüm yolu:** Implementasyon kontrolü — hangi commit'lerle nereye eklendi? Yoksa hâlâ vizyon mu?

**Tarih:** 2026-05-05.

---

## 🟢 Cortex Faz 2 — pgvector entegrasyon (kapanmamış kart)

**Soru:** pgvector ne zaman aktif olacak?

**Mevcut:** Schema'da reserved alan yok, `konular/pgvector-entegrasyon.md` plan yazılı. BM25 keyword-only şu an.

**Tetikleyici:** 200+ wiki sayfasına ulaşınca ihtiyaç keskinleşir (şu an 29 sayfa).

**Tarih:** 2026-05-05 — ileri.

---

## 🟢 Bi-temporal schema (Graphiti pattern, önceki audit önerisi)

**Soru:** `cortex_captures.valid_from / valid_to / superseded_by` ne zaman eklensin?

**Bağlam:** "6 yıllık ufuk" hedefi için kritik. Endüstri konsensüsü (Zep/Graphiti).

**Karar:** Aşama 2'ye planlandı (Faz Soon, 1 hafta).

**Tarih:** 2026-05-05.

---

## 🟢 Multi-AI memory ledger (Sultan + Claude + Codex)

**Soru:** Birden fazla AI aynı capture'a yazınca conflict nasıl çözülür?

**Önerilen pattern:** `author` + `confidence` + `source_session_id` her capture'da. `_agents/CONTEXT.md` zaten doğru yönde.

**Tarih:** 2026-05-05 — Aşama 2-3 ile uyumlu.

---

## 🟢 EK_GARANTI hikayesi 3 dosyada (DRY ihlali, Veri Genom)

**Soru:** sku-mapping.md + yanlis-kategorize.md + validation-gap.md → tek storyline mi 3 ayrı kavram mı?

**Bağlam:** Aynı bug zinciri 3 dosyaya bölünmüş. Atomicity vs hikaye akışı dengesi.

**Karar önerisi:** Mevcut yapı kabul edilebilir — her dosya ayrı bir teknik bug. Cross-reference güçlendir.

**Tarih:** 2026-05-05.

---

## Format

```markdown
## [Durum] [Soru Adı]

**Soru:** Net soru cümlesi
**Bilinen:** Şimdiye kadar ne biliyoruz
**Çözüm yolu:** Cevap nasıl bulunacak
**Tarih:** Ne zaman yazıldı
```

**Durum sembolleri:**
- 🔴 Acil — şu an blocker
- 🟡 Beklemede — veri/onay bekliyor
- 🟢 Tarihsel kayıt — kapanmış / ertelendi, referans için duruyor
