---
name: memex
type: foundation
version: 1.0.0
description: >
  Yaşayan kişisel AI hafıza sistemi — bi-temporal knowledge graph,
  project namespace, embedding versioning. Cortex v1'in (Sultan) parametrik kopyası.
  Yeni projelere `/memex init <name>` ile tak-tak kurulur.
prerequisites:
  backend: PostgreSQL 14+ (pgvector opsiyonel), Next.js 15 + Prisma 6
  frontend: React 19, Tailwind CSS v4 (opsiyonel)
  ai: OpenRouter / Anthropic / OpenAI (provider seçilebilir)
stacks: [nextjs+prisma, fastapi+sqlmodel]
author: sultanxgokce
source: https://github.com/sultanxgokce/Nexus (Cortex v1 — bu paketin asıl prototipi)
tags: [memory, ai, knowledge-graph, bi-temporal, second-brain, cortex, memex]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
based_on:
  - Mem0 — fact extraction pattern
  - Letta (MemGPT) — hierarchical memory
  - Zep / Graphiti — bi-temporal knowledge graph
  - Cognee — memify periodic consolidation
---

# Memex — Yaşayan Kişisel AI Hafıza Skill'i

Vannevar Bush'un 1945'te tanımladığı *memory extender* (modern hyperlink'in atası)
fikrinin AI çağı için modern uygulaması. Sultan'ın Cortex'inin (Nexus projesinde)
**parametrik / paketlenmiş** hali.

> "Bir kez kur, her projende çalışsın. Tüm hayatını hatırlasın, çelişkileri korusun."

---

## ⭐ Niye Memex?

| Endüstri Çözümü | Eksiği | Memex Avantajı |
|-----------------|--------|----------------|
| Mem0 (fact extraction) | Conflict detection yok, stale fact birikir | Bi-temporal `valid_from/valid_to` |
| ChatGPT/Claude built-in | Kontrol edemezsin, hiyerarşi yok | Self-hosted, full ownership |
| Notion/Obsidian + AI plugin | İki ayrı sistem, senkron sıkıntısı | Markdown wiki + DB **tek source-of-truth** |
| Letta (MemGPT) | Tek-agent, multi-AI yok | Author tracking (Sultan/Claude/Codex) + memory ledger |
| Zep | Hosted, vendor lock-in | Self-hosted, Postgres |

---

## 🏛 Mimari (4 Direk)

### Direk 1: Bi-Temporal Knowledge Graph (Graphiti pattern)
Her capture/page'de:
- `valid_from` (TIMESTAMP) — ne zaman doğru oldu
- `valid_to` (TIMESTAMP NULL = hâlâ geçerli)
- `superseded_by` (REFERENCES self) — yeni karar eskiyi geçersiz kıldıysa

**Time-travel sorgu:** "Mart 2026'da aktif kararlar?" → `WHERE valid_from <= '2026-03' AND (valid_to > '2026-03' OR valid_to IS NULL)`

### Direk 2: Project Namespace
Her capture'da zorunlu `project ENUM(...)`. Default search scope = tek proje. Cross-project explicit flag ile.

### Direk 3: Embedding Versioning (Open Brain pattern)
Her embedding'de `embedding_model_version` + `embedded_at`. Model upgrade'inde **tüm rebuild** (parsiyel YASAK).

### Direk 4: Episodic vs Semantic Ayrımı
- `data/raw/notes/*.md` = **episodic** (raw, dokunulmaz)
- `wiki/**/*.md` = **semantic** (distilled, rebuild edilebilir)
- DB = **derived index** (re-buildable from sources)

---

## 🚀 Hızlı Kurulum

### Yeni Proje (sıfırdan)

```bash
cd /path/to/your/new/project
npx memex init <instance-name>
# Onboarding wizard 7 soru sorar:
#   1. Instance adı (Cortex / Codex / Atlas / ...)
#   2. Domain (öğrenme / iş / araştırma / kişisel / mixed)
#   3. Capture türleri (karar, keşif, uyarı, soru, fact, ...)
#   4. Wiki dili (TR / EN / ...)
#   5. DB tipi (PostgreSQL / SQLite)
#   6. Federation projesi var mı? (MCP bridge)
#   7. AI provider (Anthropic / OpenAI / OpenRouter)
```

Wizard sonunda:
- `prisma/schema.prisma` — bi-temporal + namespace + embedding versioning
- `lib/{config,memex,extractor,distill}.ts` — capture pipeline
- `app/api/memex/*` — REST endpoints (ingest-text, captures, pull-bridge)
- `wiki/{domains}/_index.md` — branch templates
- `.claude/commands/{memory-audit,memex,dream}.md` — slash komutlar
- `scripts/audit_snapshot.py` — haftalık KPI
- `INSTALL.md` — manuel adımlar (env, ilk migration, smoke test)

### Mevcut Cortex Sahibi (Sultan)

```bash
# Cortex'i Memex v1.0 spec'e yükselt (idempotent migration)
cd /Users/sultan/Desktop/y/001/Nexus
npx memex upgrade --instance Cortex
```

Uygulanan değişiklikler:
- DB: `valid_from/valid_to/superseded_by` kolonları eklenir (NULL-default)
- DB: `project` namespace zorunlu (existing rows: `project='cortex_meta'` default)
- DB: `embedding_model_version` + `embedded_at` metadata
- API: `/api/cortex/captures` PATCH (invalidate eski karar) + GET (time-travel)

---

## 📚 Dokümantasyon

- [docs/architecture.md](docs/architecture.md) — Mimari detayı
- [docs/migration.md](docs/migration.md) — Mevcut sistemden upgrade rehberi
- [docs/best-practices.md](docs/best-practices.md) — 6 yıllık ufuk için kurallar
- [docs/anti-patterns.md](docs/anti-patterns.md) — Kaçınılması gerekenler

---

## 🔧 Bakım

`/memory-audit` slash komutu (haftalık otomatik):
- KPI snapshot (frontmatter, izole, açık soru, DRY)
- `_audit_history.md`'ye trend
- Manuel `/memory-audit fix` — tamirat

`/dream` (günlük):
- Capture → distill → wiki
- Conflict scan
- Stale flag

---

## 🎯 Yol Haritası

| Versiyon | İçerik | Durum |
|----------|--------|-------|
| **v1.0** | Bi-temporal + namespace + embedding versioning + audit pipeline | 🟡 Bu commit |
| v1.1 | pgvector aktif + semantic search | ⏳ Faz 2 |
| v1.2 | Multi-AI memory ledger (author tracking) | ⏳ |
| v1.3 | Federation (MCP bridge to other Memex instances) | ⏳ |
| v2.0 | Tam template engine (Hygen/Plop), custom skill tanımı | ⏳ |

---

## 📜 Endüstri Kaynakları

- [Letta — Agent Memory](https://www.letta.com/blog/agent-memory)
- [Graphiti — Temporal Knowledge Graph](https://github.com/getzep/graphiti)
- [Cognee — Memify Pattern](https://www.cognee.ai/blog)
- [Mem0 — State of AI Agent Memory 2026](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
- [Open Brain — Rebuild Without Loss](https://www.mindstudio.ai/blog/open-brain)
- Vannevar Bush, *As We May Think* (1945) — Memex'in felsefi kökeni

---

## 🪪 Lisans & Sorumluluk

**Self-hosted, kullanıcının verisi.** Hiçbir verinin Sx-Claude-Skills sunucularına gitmez. Memex paketi yalnızca **scaffold + skill** sağlar.
