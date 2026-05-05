# Memex v1.0 — Kurulum Rehberi

İki senaryo için ayrı talimatlar:
- **A) Sıfırdan yeni proje** (`/memex init`)
- **B) Mevcut Cortex'ten upgrade** (`/memex upgrade`)

---

## A) Yeni Proje — Sıfırdan Kurulum

### Ön Koşullar
- Next.js 15 (App Router) + Prisma 6, **veya** FastAPI + SQLModel
- PostgreSQL 14+ (pgvector opsiyonel)
- AI provider account (Anthropic / OpenAI / OpenRouter)

### 1. Prisma Schema

`prisma/schema-fragment.prisma`'yı kendi `schema.prisma`'na append et. Sonra:

```bash
npx prisma migrate dev --name add_memex
```

### 2. Environment Variables

`.env`'ye ekle:
```env
# Memex
MEMEX_DEFAULT_PROJECT=cortex_meta
MEMEX_AI_PROVIDER=anthropic   # veya openai, openrouter
MEMEX_EMBEDDING_MODEL=openai-text-embedding-3-small
MEMEX_EMBEDDING_DIMENSIONS=1536
ANTHROPIC_API_KEY=sk-...
```

### 3. Library Files

`scaffold/lib/*.ts.tpl` → `lib/memex/*.ts` olarak kopyala. Her dosyada:
- `{{instanceName}}` → seçtiğin isim (örn. "Cortex")
- `{{nameLower}}` → küçük harf (örn. "cortex")

### 4. API Endpoints

`scaffold/api/*.ts.tpl` → `app/api/memex/*` olarak kopyala.

### 5. Wiki Yapısı

`scaffold/wiki-template/` → `cortex/wiki/` (ya da seçtiğin path).

İçeriği:
- `_index.md` — master entry point
- `_open_questions.md` — açık sorular arşivi
- `_audit_history.md` — KPI trend
- Branch dirs: `kararlar/`, `konular/`, `sultan/`, ...

### 6. Slash Komutları

`scaffold/.claude/commands/*.md` → `.claude/commands/`'a kopyala:
- `memory-audit.md` — haftalık audit
- `memex.md` — context yükleme
- `dream.md` — günlük rüya cycle

### 7. Audit Pipeline

`scaffold/scripts/audit_*.py` → `scripts/`'a kopyala. Cron için:
```bash
cp scaffold/com.user.memory-audit.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.user.memory-audit.plist
```

### 8. Smoke Test

```bash
# Test ingest
curl -X POST http://localhost:3000/api/memex/ingest-text \
  -H "Content-Type: application/json" \
  -d '{"text":"İlk test capture","project":"cortex_meta","kind":"fact"}'

# Test recall
curl "http://localhost:3000/api/memex/captures?project=cortex_meta"

# Test audit
python3 scripts/audit_snapshot.py --dry-run
```

---

## B) Mevcut Cortex Upgrade (Sultan'ın Nexus'i)

Mevcut Cortex'i Memex v1.0 spec'ine taşımak için **idempotent migration**:

### 1. Backup (zorunlu)

```bash
cd /Users/sultan/Desktop/y/001/Nexus
git checkout -b memex-upgrade
pg_dump $DATABASE_URL > backup_pre_memex.sql
```

### 2. DB Migration

```sql
-- Idempotent migration. Veri kaybı yok, sadece kolon ekler.

-- 2a. Bi-temporal kolonlar (cortex_captures için)
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS valid_from TIMESTAMP DEFAULT NOW();
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS valid_to TIMESTAMP NULL;
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS superseded_by INTEGER REFERENCES cortex_captures(id);
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS conflicts_with INTEGER;

-- 2b. Project namespace (default: cortex_meta — geriye uyum)
DO $$ BEGIN
    CREATE TYPE memex_project AS ENUM ('cortex_meta', 'nexus', 'mmepanel', 'personal');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS project memex_project DEFAULT 'cortex_meta';

-- 2c. Author tracking (multi-AI ledger)
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS author VARCHAR(50) DEFAULT 'user';
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS source_session VARCHAR(100);

-- 2d. Embedding versioning
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS embedding_model_version VARCHAR(50);
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS embedded_at TIMESTAMP;

-- 2e. Aynı kolonlar cortex_pages için
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS valid_from TIMESTAMP DEFAULT NOW();
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS valid_to TIMESTAMP NULL;
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS superseded_by INTEGER REFERENCES cortex_pages(id);
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS project memex_project DEFAULT 'cortex_meta';
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS embedding_model_version VARCHAR(50);
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS embedded_at TIMESTAMP;

-- 2f. Embedding registry (yeni tablo)
CREATE TABLE IF NOT EXISTS memex_embedding_registry (
    id SERIAL PRIMARY KEY,
    model_version VARCHAR(50) UNIQUE NOT NULL,
    dimensions INTEGER NOT NULL,
    provider VARCHAR(50) NOT NULL,
    activated_at TIMESTAMP DEFAULT NOW(),
    deactivated_at TIMESTAMP,
    notes TEXT
);

-- 2g. Audit history tablosu
CREATE TABLE IF NOT EXISTS memex_audit_history (
    id SERIAL PRIMARY KEY,
    project memex_project NOT NULL,
    audit_at TIMESTAMP DEFAULT NOW(),
    total_files INTEGER NOT NULL,
    frontmatter_pct REAL NOT NULL,
    isolated_count INTEGER NOT NULL,
    open_questions INTEGER NOT NULL,
    duplicate_count INTEGER NOT NULL,
    score INTEGER NOT NULL,
    details JSONB DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_memex_audit_project_time ON memex_audit_history(project, audit_at);

-- 2h. İndeksler (bi-temporal sorgu için kritik)
CREATE INDEX IF NOT EXISTS idx_cortex_captures_temporal
  ON cortex_captures(project, valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_cortex_pages_temporal
  ON cortex_pages(project, valid_from, valid_to);
```

### 3. Prisma Schema Güncelle

Yukarıdaki SQL DB'ye uygulandıktan sonra:
```bash
npx prisma db pull        # DB'den schema'yı çek
npx prisma generate       # Client güncelle
```

### 4. Backfill (mevcut veri uyumluluğu)

```sql
-- Tüm mevcut capture'lar 'cortex_meta' projesinde, 'user' author
-- (zaten default, ama explicit:)
UPDATE cortex_captures SET project = 'cortex_meta' WHERE project IS NULL;
UPDATE cortex_pages SET project = 'cortex_meta' WHERE project IS NULL;

-- Embedding registry'ye mevcut model kaydı ekle (varsa)
INSERT INTO memex_embedding_registry (model_version, dimensions, provider, notes)
VALUES ('openai-text-embedding-3-small', 1536, 'openai', 'Cortex v1 baseline')
ON CONFLICT DO NOTHING;
```

### 5. API Endpoint'leri Genişlet

`/api/cortex/captures` PATCH endpoint'i — invalidate akışı için:
```typescript
// Eski karar yenisini iptal etti
PATCH /api/cortex/captures/{id}
Body: { valid_to: "2026-05-05T...", superseded_by: 42 }
```

`/api/cortex/captures` GET — time-travel:
```typescript
GET /api/cortex/captures?as_of=2026-03-15
// Sadece o tarihte aktif kararları döner
```

### 6. Time-Travel Helper

`lib/memex/temporal.ts`:
```typescript
export async function getActiveAt(date: Date, project: string) {
  return prisma.memexCapture.findMany({
    where: {
      project,
      valid_from: { lte: date },
      OR: [
        { valid_to: null },
        { valid_to: { gt: date } }
      ]
    }
  });
}
```

### 7. Smoke Test

```bash
# Mevcut tüm capture'ların project alanı dolu mu?
psql $DATABASE_URL -c "SELECT COUNT(*) FROM cortex_captures WHERE project IS NULL;"
# 0 olmalı

# Bi-temporal sorgu çalışıyor mu?
curl "http://localhost:3000/api/cortex/captures?as_of=2026-03-15"
```

---

## Kontrol Listesi (Kurulum Sonrası)

- [ ] DB migration uygulandı, `cortex_captures.valid_from` var
- [ ] Mevcut tüm capture'lar `project='cortex_meta'`
- [ ] `memex_embedding_registry`'ye baseline model kaydedildi
- [ ] `/memory-audit` slash komut çalışıyor (skor görünüyor)
- [ ] launchd plist yüklü (haftalık cron)
- [ ] PATCH /api/cortex/captures invalidate testi yapıldı
- [ ] Time-travel `?as_of=` testi yapıldı

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| Migration `permission denied` | `pg_dump` rolü olmasın, kullanıcı DDL yetkisi olsun |
| Prisma `db pull` schema'yı bozuyor | Önce backup, sonra hibrit: manuel schema fragment append |
| Audit script Python 3.10+ gerek | `match-case` syntax — `python3 --version` kontrol |
| `valid_to` set ettim, eski capture görünmüyor | `?as_of=` parametresi ile time-travel sorgu kullan |

---

## Sonraki Adımlar (v1.1+)

1. **pgvector aktivasyonu** — `prisma/schema.prisma`'da `Unsupported("vector(1536)")`
2. **Semantic search endpoint** — `/api/memex/search?q=...&semantic=true`
3. **Memify cycle** — haftalık consolidation (Cognee pattern)
4. **MCP federation** — başka Memex instance'larıyla bridge
