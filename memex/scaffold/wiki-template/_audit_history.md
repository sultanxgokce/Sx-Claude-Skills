---
sayfa_id: wiki._audit_history
kategori: meta
son_guncelleme: 2026-05-05
guvenilirlik: yüksek
önem: 3
etiketler: [meta, audit, kpi, trend]
---

# Cortex Audit Geçmişi — Sistem Sağlığı Trend

Her `/memory-audit` run'ı sonrası KPI snapshot'ı buraya append edilir.

---

## 2026-05-05 — Baseline (İlk Audit)

**Tetikleyici:** Sultan'ın "AI için ideal mi yoksa çöplük mü?" sorusu sonrası.

### KPI Snapshot

| Metrik | Değer | Hedef |
|--------|-------|-------|
| Toplam markdown (`wiki/`) | 29 | — |
| Toplam satır | ~2,100 | — |
| Frontmatter ✓ | 20/29 (%69) | %95+ |
| `ilgili:` field dolu | 16/29 (%55) | %90+ |
| Tarih bilgisi var | 23/29 (%79) | %100 |
| Cross-reference link sayısı | 54 | 80+ |
| Backlink (geri yön) coverage | ~%30 | %80+ |
| Açık soru | 7 | < 10 |
| 200+ satır dosya | 1 (`2-gun-takip-notlari.md` 286 satır) | 0 |
| Master `_index.md` | ❌ → ✅ (bu run'da eklendi) | ✓ |

### Kategori Skoru (100 üzerinden)

| Boyut | Puan |
|-------|------|
| Atomicity | 12/20 |
| Bağlantı/Yapı | 14/20 |
| Metadata/Keşfedilebilirlik | 13/20 |
| Güncellik/Conflict | 11/20 |
| AI-Readiness | 13/20 |
| **TOPLAM** | **63/100** |

### 🔴 Acil Sorunlar

1. **`2-gun-takip-notlari.md`** — 286 satır, 6+ farklı konu karışık. Atomicity ihlali. **Bölünmesi** veya **distill edilip arşivlenmesi** gerek.
2. **Backlinks yok** — Tek-yönlü `ilgili:` linkleri var, "B'yi kim referans ediyor?" cevaplanamıyor.
3. **dream.py parse hatası — çelişki** (S1 açık soru) — DREAM_REPORT vs log.md uyumsuzluğu.
4. **MMEpanel duplikasyon** — `mmepanel/profil.md` ve `mmepanel/aktif-gorevler.md` aynı 3 görev. Cortex master mı, Veri Genom master mı netleşmedi.
5. **Açık sorular hiç kapanmamış** — `_open_questions.md` yok'tu, S1/S2/S3 wiki'de dağınık duruyordu. Bu run'da tek dosyaya konsolide edildi ✅.

### ✅ Bu Run'da Uygulananlar

- `wiki/_index.md` master oluşturuldu (branch tablosu + ⭐ önem skorları)
- `wiki/_open_questions.md` oluşturuldu (S1/S2/S3 + 4 ek soru)
- `wiki/_audit_history.md` oluşturuldu (bu dosya, trend takibi)

### 🟡 Bir Sonraki Run İçin Önerilen

- **`2-gun-takip-notlari.md` çözümü** — bölünme veya distill kararı
- **Frontmatter normalize** — 9 dosyada eksik alan
- **Backlinks otomatize** — script ile her dosyaya `geri_baglantilar:` field'ı
- **Faz 2 başlat** — pgvector + bi-temporal schema (önceki turun planı)
- **Senkron netleşmesi** — MMEpanel master truth: Veri Genom mu Cortex mi?

---

## Format

```markdown
## YYYY-MM-DD — [Kısa açıklama]

**Tetikleyici:** ...

### KPI Snapshot
...

### Kategori Skoru
...

### 🔴 Acil Sorunlar
...

### ✅ Bu Run'da Uygulananlar
...

### 🟡 Bir Sonraki Run İçin Önerilen
...
```

---

## 📈 Skor Trendi (manual chart)

```
2026-05-05: ████████████████████████████████████████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 63/100
```

**Hedef:** Aşama 1 sonrası 75+. Aşama 2 (bi-temporal + namespace) sonrası 80+. Aşama 3 (pgvector + memify) sonrası 85+.

---

## 🔧 Bakım Notu

`/memory-audit` slash komutu (haftalık önerilen) bu dosyaya append eder. Trend negatife dönerse alarm — yeni karmaşa veya stale birikimi başlamış demektir.

## 2026-05-05 — Otomatik Snapshot (Cortex)

**Tetikleyici:** Cron / `audit_snapshot.py` (otomatik metric)

### KPI

| Metrik | Değer |
|--------|-------|
| Toplam dosya | 32 |
| Frontmatter ✓ | 23/32 (71.9%) |
| `ilgili:` field dolu | 20/32 (62.5%) |
| Tarih bilgisi | 23/32 |
| Toplam link | 94 |
| İzole dosya (linksiz) | 0 (0.0%) |
| 200+ satır dosya | 1 |
| Açık soru pattern | 0 |
| DRY ihlali (2+ yerde sabit) | 0 |
| **Otomatik skor** | **81.0/100** |

### En büyük dosya
- 2-gun-takip-notlari.md: 286 satır

### ⚠️ 200+ satır (atomicity ihlali şüphesi)
- 2-gun-takip-notlari.md (286 satır)

### 🟡 Frontmatter eksik (9)
- _index.md
- _index.md
- karar-pipeline-vizyonu.md
- _index.md
- _index.md
- aktif-gorevler.md
- _index.md
- aktif-gorevler.md
- _index.md

**Sonraki adım:** Manuel `/memory-audit fix` ile tamirat (Sultan onayı gerek).

## 2026-05-05 — Otomatik Snapshot (Cortex)

**Tetikleyici:** Cron / `audit_snapshot.py` (otomatik metric)

### KPI

| Metrik | Değer |
|--------|-------|
| Toplam dosya | 32 |
| Frontmatter ✓ | 32/32 (100.0%) |
| `ilgili:` field dolu | 20/32 (62.5%) |
| Tarih bilgisi | 32/32 |
| Toplam link | 94 |
| İzole dosya (linksiz) | 0 (0.0%) |
| 200+ satır dosya | 1 |
| Açık soru pattern | 0 |
| DRY ihlali (2+ yerde sabit) | 0 |
| **Otomatik skor** | **87.0/100** |

### En büyük dosya
- 2-gun-takip-notlari.md: 286 satır

### ⚠️ 200+ satır (atomicity ihlali şüphesi)
- 2-gun-takip-notlari.md (286 satır)

**Sonraki adım:** Manuel `/memory-audit fix` ile tamirat (Sultan onayı gerek).
