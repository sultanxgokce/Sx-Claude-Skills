---
name: ai-engineering-kit
type: agent
version: 1.0.0
description: >
  Claude ajan altyapısı — /ai-upgrade (repo kataloğu, araç yönetimi) +
  /ai-metodoloji (çalışma kalitesi denetimi). Stack bağımsız, her projede çalışır.
prerequisites: {}
install_target:
  commands: .claude/commands/
  skills: _agents/skills/
  research: _agents/ai-research/
author: sultanxgokce
source: https://github.com/sultanxgokce/MMEpanel
tags: [ai-agent, methodology, slash-commands, skills]
stacks: ["*"]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# AI Engineering Kit

Claude'un bir projede **nasıl çalıştığını** ölçen ve geliştiren ajan altyapısı.
İki slash komut kurar, iki log dosyası başlatır, bir repo kataloğu ile gelir.

| Komut | Soru | Ne Yapar |
|-------|------|----------|
| `/ai-upgrade` | Neye sahibiz? | Skill/MCP/repo envanteri, araç ekleme |
| `/ai-metodoloji` | Nasıl çalışıyoruz? | Bağlam, hafıza, reasoning, orchestration denetimi |

---

## Kurulum (Claude için talimat)

Bu skill `type: agent` — kod üretmez, dosyaları proje yapısına yerleştirir.

### Adım 1 — Komutları kopyala

`templates/commands/` içindeki her `.md` dosyasını projenin `.claude/commands/` dizinine kopyala.

```
templates/commands/ai-upgrade.md     → .claude/commands/ai-upgrade.md
templates/commands/ai-metodoloji.md  → .claude/commands/ai-metodoloji.md
```

`.claude/commands/` yoksa oluştur.

### Adım 2 — Skill dosyalarını kopyala

`templates/skills/` içindeki her klasörü projenin `_agents/skills/` dizinine kopyala.

```
templates/skills/ai-upgrade/     → _agents/skills/ai-upgrade/
templates/skills/ai-metodoloji/  → _agents/skills/ai-metodoloji/
```

`_agents/skills/` yoksa oluştur.

### Adım 3 — Research dizinini başlat

`templates/research/` içindeki dosyaları `_agents/ai-research/` dizinine kopyala.

```
templates/research/REPO_CATALOG.md   → _agents/ai-research/REPO_CATALOG.md
templates/research/SESSION_LOG.md    → _agents/ai-research/SESSION_LOG.md
templates/research/METODOLOJI_LOG.md → _agents/ai-research/METODOLOJI_LOG.md
templates/research/README.md         → _agents/ai-research/README.md
```

`_agents/ai-research/` yoksa oluştur.

### Adım 4 — SESSION_LOG'u başlat

`_agents/ai-research/SESSION_LOG.md` dosyasının en üstündeki `[PROJE_ADI]` ve `[TARİH]` placeholder'larını doldur:
- `[PROJE_ADI]` → mevcut projenin adı (dizin adından al)
- `[TARİH]` → bugünün tarihi (YYYY-MM-DD)

### Adım 5 — Doğrula

```
✅ .claude/commands/ai-upgrade.md mevcut
✅ .claude/commands/ai-metodoloji.md mevcut
✅ _agents/skills/ai-upgrade/SKILL.md mevcut
✅ _agents/skills/ai-metodoloji/SKILL.md mevcut
✅ _agents/ai-research/REPO_CATALOG.md mevcut
✅ _agents/ai-research/SESSION_LOG.md mevcut (proje adı doldurulmuş)
✅ _agents/ai-research/METODOLOJI_LOG.md mevcut
```

### Adım 6 — Nexus'a Kaydet

Kurulum tamamlandıktan sonra kullanıcıya şunu söyle:
> "Nexus AI Engineer Workbook > Skill Kataloğu'na bu kurulumu kaydetmek ister misin?"

Kullanıcı onaylarsa şu bilgileri kaydetmesini iste (manuel — Nexus API entegrasyonu olmadığı için):
- **Skill:** ai-engineering-kit v1.0.0
- **Proje:** [proje adı]
- **Kurulum tarihi:** [bugün]
- **Not:** (isteğe bağlı — projeye özel notlar)

Doğrulama tamamsa kullanıcıya şunu söyle:
> "AI Engineering Kit kuruldu. `/ai-upgrade` ile repo kataloğunu, `/ai-metodoloji` ile çalışma kalitesini yönetebilirsin."

---

## Özellikler

### /ai-upgrade
- Bilinen repo/skill/MCP kaynakları kataloğu (`REPO_CATALOG.md`)
- Her oturumda "Neye sahibiz?" sorusunu cevaplar
- Öneri → onay → kurulum → skor kayıt akışı
- Oturum bazlı önceki/sonraki skor karşılaştırması

### /ai-metodoloji
- 6 boyutlu metodoloji denetimi (bağlam, hafıza, skill, reasoning, orchestration, otomasyon)
- Git log analizi — iterasyon sayısı, doğrulama uyumu
- CLAUDE.md kural sağlığı kontrolü
- Stale memory tespiti
- Known-errors güncellik denetimi

### Başlangıç Repo Kataloğu (8 kaynak)
REPO_CATALOG.md ile hazır gelir:
- anthropics/skills, travisvn/awesome-claude-skills, alirezarezvani/claude-skills
- modelcontextprotocol/servers, yamadashy/repomix
- davila7/claude-code-templates, ComposioHQ/awesome-claude-plugins

---

## Güncelleme

Yeni versiyon çıktığında:
1. Sx-Claude-Skills reposundan yeni SKILL.md'yi çek
2. `templates/` değişikliklerini proje dosyalarına uygula
3. SESSION_LOG ve METODOLOJI_LOG korunur (proje geçmişi silinmez)
