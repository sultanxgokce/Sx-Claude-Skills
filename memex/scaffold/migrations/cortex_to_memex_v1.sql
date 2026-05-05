-- ──────────────────────────────────────────────────────────────────────────
-- Memex v1.0 — Cortex Upgrade Migration (Idempotent, Zero Data Loss)
--
-- Mevcut Cortex DB'sini Memex v1.0 spec'ine yükseltir:
--  ✓ Bi-temporal (Graphiti pattern): valid_from / valid_to / superseded_by
--  ✓ Project namespace
--  ✓ Author tracking (multi-AI memory ledger)
--  ✓ Embedding versioning (Open Brain pattern)
--  ✓ Audit history tablosu
--  ✓ Embedding registry tablosu
--
-- Tüm ALTER'lar `IF NOT EXISTS` — idempotent, tekrar çalıştırılabilir.
-- Mevcut veri DOKUNULMAZ — sadece yeni kolonlar eklenir.
--
-- Çalıştırma:
--    psql $DATABASE_URL -f cortex_to_memex_v1.sql
--
-- Geri alma (rollback):
--    Yedeklemeyi kullan (pg_dump backup_pre_memex.sql)
-- ──────────────────────────────────────────────────────────────────────────

BEGIN;

-- ── 1. Project Namespace Enum ──
DO $$ BEGIN
    CREATE TYPE memex_project AS ENUM (
        'cortex_meta',   -- Memex'in kendi meta verisi
        'nexus',         -- Nexus projesi
        'mmepanel',      -- MMEpanel projesi
        'personal'       -- Kişisel notlar
    );
EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'memex_project enum zaten var, atlanıyor';
END $$;

-- ── 2. cortex_captures — Bi-Temporal + Namespace + Author + Embedding ──

ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS valid_from TIMESTAMP DEFAULT NOW();
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS valid_to TIMESTAMP NULL;
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS superseded_by TEXT;  -- UUID FK manual
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS project memex_project DEFAULT 'cortex_meta';
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS author VARCHAR(50) DEFAULT 'user';
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS source_session VARCHAR(100);
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS embedding_model_version VARCHAR(50);
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS embedded_at TIMESTAMP;
ALTER TABLE cortex_captures ADD COLUMN IF NOT EXISTS confidence REAL DEFAULT 0.5;

-- conflicts_with zaten var (string slug). UUID FK için alt tablo eklemiyoruz —
-- kullanıcı kullanım pattern'ine göre v1.1'de tipini güçlendirebilir.

-- FK constraint: superseded_by → cortex_captures.id (lazy ekle, hata vermesin)
DO $$ BEGIN
    ALTER TABLE cortex_captures
    ADD CONSTRAINT fk_cortex_captures_superseded
    FOREIGN KEY (superseded_by) REFERENCES cortex_captures(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'cortex_captures superseded_by FK zaten var';
WHEN others THEN
    RAISE NOTICE 'FK eklenemedi: %', SQLERRM;
END $$;

-- ── 3. cortex_pages — Aynı bi-temporal + namespace ──

ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS valid_from TIMESTAMP DEFAULT NOW();
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS valid_to TIMESTAMP NULL;
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS superseded_by TEXT;
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS project memex_project DEFAULT 'cortex_meta';
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS embedding_model_version VARCHAR(50);
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS embedded_at TIMESTAMP;
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
ALTER TABLE cortex_pages ADD COLUMN IF NOT EXISTS last_audit_at TIMESTAMP;

DO $$ BEGIN
    ALTER TABLE cortex_pages
    ADD CONSTRAINT fk_cortex_pages_superseded
    FOREIGN KEY (superseded_by) REFERENCES cortex_pages(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'cortex_pages superseded_by FK zaten var';
WHEN others THEN
    RAISE NOTICE 'FK eklenemedi: %', SQLERRM;
END $$;

-- ── 4. Embedding Registry (yeni tablo) ──
CREATE TABLE IF NOT EXISTS memex_embedding_registry (
    id SERIAL PRIMARY KEY,
    model_version VARCHAR(50) UNIQUE NOT NULL,
    dimensions INTEGER NOT NULL,
    provider VARCHAR(50) NOT NULL,
    activated_at TIMESTAMP DEFAULT NOW(),
    deactivated_at TIMESTAMP,
    notes TEXT
);

-- Cortex baseline kayıt (eğer mevcut embedding pipeline yoksa atlanır)
INSERT INTO memex_embedding_registry (model_version, dimensions, provider, notes)
VALUES ('cortex-v1-baseline', 0, 'none', 'Cortex v1 — embedding henüz kullanılmıyor (BM25 keyword-only)')
ON CONFLICT (model_version) DO NOTHING;

-- ── 5. Audit History Tablosu (yeni) ──
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
CREATE INDEX IF NOT EXISTS idx_memex_audit_project_time
    ON memex_audit_history(project, audit_at);

-- ── 6. İndeksler — Bi-temporal sorgu performansı ──

CREATE INDEX IF NOT EXISTS idx_cortex_captures_temporal
    ON cortex_captures(project, valid_from, valid_to);

CREATE INDEX IF NOT EXISTS idx_cortex_captures_author
    ON cortex_captures(author);

CREATE INDEX IF NOT EXISTS idx_cortex_captures_embedding_version
    ON cortex_captures(embedding_model_version)
    WHERE embedding_model_version IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cortex_pages_temporal
    ON cortex_pages(project, valid_from, valid_to);

-- ── 7. Backfill (geriye dönük uyum) ──

-- Tüm mevcut capture'lar 'cortex_meta' projesinde (zaten default)
UPDATE cortex_captures SET project = 'cortex_meta' WHERE project IS NULL;
UPDATE cortex_pages SET project = 'cortex_meta' WHERE project IS NULL;

-- valid_from default NOW(); ama mevcut kayıtlar createdAt'tan al
UPDATE cortex_captures
SET valid_from = COALESCE(created_at, NOW())
WHERE valid_from IS NULL;

UPDATE cortex_pages
SET valid_from = COALESCE(created_at, NOW())
WHERE valid_from IS NULL;

-- ── 8. İlk Audit Snapshot (manuel — Python script tetikler ayrıca) ──
-- (bu otomatik append edilir, /memory-audit cron tarafından)

COMMIT;

-- ──────────────────────────────────────────────────────────────────────────
-- Doğrulama Sorguları
-- ──────────────────────────────────────────────────────────────────────────

-- 1. Yeni kolonlar eklendi mi?
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'cortex_captures'
  AND column_name IN ('valid_from', 'valid_to', 'superseded_by', 'project', 'author');

-- 2. Tüm capture'lar project alanı dolu mu?
SELECT COUNT(*) AS missing_project
FROM cortex_captures
WHERE project IS NULL;
-- Beklenen: 0

-- 3. Embedding registry baseline var mı?
SELECT model_version, provider, activated_at
FROM memex_embedding_registry
WHERE model_version = 'cortex-v1-baseline';

-- 4. Time-travel sorgu testi (şu an aktif kararlar)
SELECT id, kind, ai_summary
FROM cortex_captures
WHERE project = 'cortex_meta'
  AND valid_from <= NOW()
  AND (valid_to IS NULL OR valid_to > NOW())
LIMIT 5;
