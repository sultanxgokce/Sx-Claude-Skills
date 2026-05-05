---
description: Cortex (canlı) → Memex paketi (Sx-Claude-Skills) tek-yön senkron
---

# /memex-sync — Cortex → Memex Paketi Senkron

## Amaç

Cortex sürekli evolüe eden canlı sistem. Memex (Sx-Claude-Skills/memex/) onun
**parametrik kopyası — paketlenmiş template**. Cortex değiştikçe Memex'in geride
kalmaması için bu komutla periyodik senkron yapılır.

> **Continuous Memex Synchronization Pattern** — source-of-truth (Cortex) →
> derived template (Memex). One-way, idempotent, versioned.

---

## Tetikleme Senaryoları

| Tetikleyici | Sıklık |
|-------------|--------|
| Cortex schema değişikliği | Hemen |
| Yeni API endpoint Cortex'e eklendi | Hemen |
| Yeni slash komut, yeni script | Hemen |
| Yeni özellik (pgvector, memify, vs) | Hemen |
| Dokümantasyon güncellemesi | Haftalık veya hemen |
| Hiçbir değişiklik yok | Atla (komut sessiz çıkar) |

---

## Çalıştırma

```bash
/memex-sync                         # interactive (önce göster, sonra onayla)
/memex-sync --dry-run               # sadece raporla
/memex-sync --auto                  # otomatik (cron uyumlu, sadece güvenli değişiklikler)
/memex-sync --bump=patch            # versiyon: 1.0.0 → 1.0.1
/memex-sync --bump=minor            # 1.0.0 → 1.1.0
/memex-sync --bump=major            # 1.0.0 → 2.0.0
```

---

## Senkron Edilecek Bileşenler

### A. Schema (Prisma)
- Source: `Nexus/ui/prisma/schema.prisma` (CortexCapture, CortexPage, vd.)
- Target: `Sx-Claude-Skills/memex/scaffold/prisma/schema-fragment.prisma`
- **Dönüşüm:** Model isimlerini parametrik yap (`MemexCapture` → template `{{InstanceName}}Capture`)
- **Diff:** Sadece schema fragment'ları değişti mi? Yeni alan eklendi mi?

### B. Library Files
- Source: `Nexus/ui/lib/cortex/*.ts` (memex.ts, extractor.ts, distill.ts, vd.)
- Target: `Sx-Claude-Skills/memex/scaffold/lib/*.ts.tpl`
- **Dönüşüm:** `cortex` → `{{nameLower}}`, `Cortex` → `{{InstanceName}}`
- **Skip:** Sultan-spesifik kod (TR strings, Sultan'ın profili, vd.)

### C. API Endpoints
- Source: `Nexus/ui/app/api/cortex/**/*.ts`
- Target: `Sx-Claude-Skills/memex/scaffold/api/**/*.ts.tpl`
- **Dönüşüm:** Path'ler `/cortex/` → `/memex/` veya `{{instancePath}}/`

### D. Scripts
- Source: `Nexus/scripts/audit_*.py`, `Nexus/scripts/com.sultan.memory-audit.plist`
- Target: `Sx-Claude-Skills/memex/scaffold/scripts/`
- **Dönüşüm:** Hard-coded path'leri `{{projectRoot}}` placeholder'ına çevir
- `com.sultan.memory-audit.plist` → `com.{{user}}.memory-audit.plist.tpl`

### E. Slash Komutları
- Source: `Nexus/.claude/commands/{memory-audit,cortex,dream,memex-sync}.md`
- Target: `Sx-Claude-Skills/memex/scaffold/.claude/commands/`

### F. Dokümantasyon
- SKILL.md changelog'a yeni özellik notu
- INSTALL.md upgrade adımları (yeni schema değişikliği için)
- catalog.json: version bump + tags güncelle

---

## Akış (Steps)

```
1. Cortex commit history'sinden son senkron sonrası değişikleri çıkar
   git log <last-sync-commit>..HEAD --name-only -- ui/prisma/ ui/lib/cortex/ \
                                                   ui/app/api/cortex/ scripts/

2. Her dosya için:
   - Source path → Target path eşle
   - İçeriği oku
   - Parametrik dönüşüm uygula (cortex → {{nameLower}})
   - Diff göster (Sultan'a)
   - Onaylanırsa target'a yaz

3. Migration dosyası gerekirse:
   - Cortex DB'den şema değişikliklerini SQL olarak oluştur
   - Sx-Claude-Skills/memex/scaffold/migrations/ altına kaydet
   - Versiyon: cortex_to_memex_v1_to_v{N}.sql

4. Versiyon bump:
   - SKILL.md: version: 1.0.0 → 1.X.0
   - catalog.json: aynı
   - INSTALL.md: changelog section'ına ekle
     "## v1.1.0 (2026-XX-XX)
      - Yeni: pgvector aktivasyonu
      - Yeni: memify cycle endpoint
      - Schema: cortex_captures.embedding kolonu opsiyonel olarak"

5. Git commits:
   - Sx-Claude-Skills repo'da:
     "chore(memex): sync from Cortex v1.X (commit XXXXX..YYYYY)"
   - Optional: Nexus repo'da last_sync_commit metadata güncelle
     (.memex-sync-state dosyasında)

6. Smoke test (opsiyonel):
   - Memex paketinden geçici bir test instance kur
   - Migration uygula
   - Audit script çalıştır
   - Skor kontrol
```

---

## Versiyonlama

**Semver kuralları:**
- **patch (1.0.X)**: Bug fix, dokümantasyon, minor template tweak
- **minor (1.X.0)**: Yeni özellik (geriye uyumlu)
  - Yeni API endpoint
  - Yeni schema kolonu (NULL-default)
  - Yeni slash komut
- **major (X.0.0)**: Breaking change
  - Schema kolonu kaldırıldı / tipi değişti
  - API contract değişti
  - Migration zorunlu

---

## Diğer Memex Instance'larına Notify (opsiyonel)

Eğer Sultan başka projelerde Memex instance kurmuşsa (örn. MMEpanel-memex,
Atlas, Codex), `--notify` flag ile bunlara bildirim gider:

```bash
/memex-sync --bump=minor --notify

# .memex-instances.json içindeki tüm instance'lara webhook ya da
# manuel git PR oluşturulur
```

`.memex-instances.json` (Sultan'ın kişisel registry'si):
```json
{
  "instances": [
    {"name": "Cortex", "repo": "Nexus", "version": "1.0.0", "primary": true},
    {"name": "MMEpanel-memex", "repo": "MMEpanel", "version": "1.0.0"},
    {"name": "Atlas", "repo": "personal-atlas", "version": "1.0.0"}
  ]
}
```

---

## Akıllı Diff (LLM yargısı)

Bazı dosyalar pure copy değil — Cortex'te Sultan'a özel kod var.
Memex template'i için **genel form** çıkarılmalı. Bu LLM yargısı gerek:

| Cortex'te | Memex template'inde olmalı |
|-----------|---------------------------|
| `Sultan'ın TR sade dil tarzında` | `{{user_writing_style}}` placeholder |
| `Mitoz Bölünme vizyonu...` | Atla (Sultan-spesifik) |
| `MMEpanel federation` | `{{federation_target}}` opsiyonel |

`--auto` modunda sadece **deterministic** dönüşümler yapılır (path,
isim parametreleri). LLM yargısı isteyen dosyalar Sultan'a sorulur.

---

## Sonuç Raporu

```
✅ Memex Sync Tamam — v1.0.0 → v1.1.0
─────────────────────────────────────
Senkronlanan dosyalar:
  + scaffold/prisma/schema-fragment.prisma  (3 yeni alan eklendi)
  + scaffold/lib/embedding.ts.tpl           (yeni dosya)
  + scaffold/.claude/commands/memify.md     (yeni dosya)
  ~ SKILL.md                                 (changelog)
  ~ catalog.json                             (version bump)

Atlanan dosyalar (Sultan-spesifik):
  - cortex/wiki/sultan/mitoz-bolunme-vizyonu.md
  - lib/cortex/sultan-greetings.ts

Migration üretildi:
  + scaffold/migrations/cortex_to_memex_v1_to_v1_1.sql

Sx-Claude-Skills commit: abc1234
Nexus state güncellendi: .memex-sync-state son_sync=abc1234
```

---

## Otomatize Edilemeyenler (Manuel)

- **Yeni özellik için INSTALL.md adımları** — Sultan yazmalı (LLM önerebilir)
- **Breaking change migration test** — production-like ortamda test şart
- **Endüstri kaynak referansları** (Mem0, Letta, Cognee yeni paper'lar) — manuel ekle

---

## Uyarılar

- ⚠️ Memex paketinde **Sultan'a özel veri olmamalı** (privacy)
- ⚠️ Schema fragment **idempotent** olmalı (`IF NOT EXISTS`)
- ⚠️ Versiyon bump'tan sonra git push **iki repoda da** yapılmalı (state senkron)
- ⚠️ Diğer instance'lar v1.0'dayken Memex v1.1 kuruldu — otomatik upgrade opsiyon olarak gönderilebilir ama **kullanıcı onayı şart**

---

## Best Practice Çerçeve

Bu pattern şu sistemlere benzer:
- npm/pip release pipeline (canlı dev → version bump → public package)
- React component library (storybook + npm publish)
- Linux distro release cycle (kernel.org → distro maintainer → user)

Memex farkı: **Sultan tek hem dev hem maintainer hem user**. O yüzden
bu komut her aşamayı görsel + onaylı yapar.
