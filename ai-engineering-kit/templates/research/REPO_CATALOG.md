# AI Agent Engineering — Repo Kataloğu

> Projenin Claude AI ajan altyapısını geliştirmek için incelenen kaynaklar.
> Her `/ai-upgrade` çalıştırıldığında bu dosyadan okunur.
> Yeni repo eklendiğinde "Durum" ve "Değerlendirme" güncellenir.

**Proje:** [PROJE_ADI]
**Başlangıç tarihi:** [TARİH]

---

## Nasıl Okunur

| Alan | Açıklama |
|------|----------|
| **Kategori** | SKILLS / MCP / TOOL / TEMPLATE / UI |
| **Öncelik** | 🔴 Yüksek / 🟡 Orta / 🟢 Düşük |
| **Durum** | `yeni` / `değerlendirildi` / `entegre edildi` / `iptal` |

---

## SKILLS — Claude Skill Kaynakları

### 1. anthropics/skills
- **URL:** https://github.com/anthropics/skills
- **Kategori:** SKILLS — Resmi
- **Öncelik:** 🔴
- **Durum:** `değerlendirildi`
- **İçerik:** docx, pdf, xlsx, webapp-testing (Playwright), mcp-builder, skill-creator
- **Öneri:** `skill-creator` → yeni skill yazmayı hızlandırır; `mcp-builder` → custom MCP rehberi

---

### 2. travisvn/awesome-claude-skills
- **URL:** https://github.com/travisvn/awesome-claude-skills
- **Kategori:** SKILLS — Küratörlü Liste
- **Öncelik:** 🔴
- **Durum:** `değerlendirildi`
- **İçerik:** obra/superpowers (20+ skill), playwright-skill, claude-d3js-skill, loki-mode (multi-agent orchestration)
- **Öneri:** `obra/superpowers` → genel agent güçlendirme; `loki-mode` → multi-agent için

---

### 3. alirezarezvani/claude-skills
- **URL:** https://github.com/alirezarezvani/claude-skills
- **Kategori:** SKILLS — Kapsamlı Kütüphane
- **Öncelik:** 🔴
- **Durum:** `değerlendirildi`
- **İçerik:** 235 skill, 9 domain — **Self-Improving Agent (7 skill)**, Playwright Pro, Finance, Engineering POWERFUL (45 skill)
- **Öneri:** `Self-Improving Agent` → memory otomatik gelişir; `tech-debt-tracker` → kod borcu takibi

---

### 4. ComposioHQ/awesome-claude-plugins
- **URL:** https://github.com/ComposioHQ/awesome-claude-plugins
- **Kategori:** SKILLS/PLUGINS — Küratörlü
- **Öncelik:** 🟡
- **Durum:** `yeni` (README bulunamadı — yeniden kontrol gerekli)

---

## MCP — Model Context Protocol Kaynakları

### 5. modelcontextprotocol/servers
- **URL:** https://github.com/modelcontextprotocol/servers
- **Kategori:** MCP — Resmi Referans
- **Öncelik:** 🔴
- **Durum:** `değerlendirildi`
- **İçerik:** memory, sequential-thinking, filesystem, git, fetch, time + 50+ 3. parti server
- **Öneri:** `memory` → bilgi grafiği hafıza; `sequential-thinking` → karmaşık analiz için adım adım

---

## TOOLS — AI Agent Araçları

### 6. yamadashy/repomix
- **URL:** https://github.com/yamadashy/repomix
- **Kategori:** TOOL — Codebase Paketleyici
- **Öncelik:** 🟡
- **Durum:** `değerlendirildi`
- **İçerik:** Tüm repo'yu tek AI-dostu dosyaya paketler, Tree-sitter sıkıştırma (~%70 token azaltma)
- **Öneri:** Cross-AI review için; `npm install -g repomix`

---

## TEMPLATES — Proje Şablonları

### 7. davila7/claude-code-templates
- **URL:** https://github.com/davila7/claude-code-templates
- **Kategori:** TEMPLATE
- **Öncelik:** 🟡
- **Durum:** `değerlendirildi`
- **İçerik:** Hooks (pre-commit, post-completion), commands (/generate-tests, /check-security), 100+ şablon
- **Öneri:** `pre-commit hook` → build otomasyonu; `post-completion hook` → deploy sonrası aksiyon

---

## UI — Arayüz Kütüphaneleri

### 8. lucide-icons/lucide
- **URL:** https://github.com/lucide-icons/lucide
- **Kategori:** UI — İkon Kütüphanesi
- **Öncelik:** 🟢
- **Durum:** `değerlendirildi`
- **İçerik:** 1500+ SVG ikon, React/Vue/Angular paketleri
- **Öneri:** Frontend geliştirmede ikon seçimi için referans

---

## Değerlendirme Özeti

| Repo | Kategori | Öncelik | En Değerli |
|------|----------|---------|-----------|
| anthropics/skills | SKILLS | 🔴 | skill-creator, webapp-testing |
| travisvn/awesome-claude-skills | SKILLS | 🔴 | obra/superpowers, loki-mode |
| alirezarezvani/claude-skills | SKILLS | 🔴 | Self-Improving Agent |
| modelcontextprotocol/servers | MCP | 🔴 | memory, sequential-thinking |
| yamadashy/repomix | TOOL | 🟡 | Codebase paketleme |
| davila7/claude-code-templates | TEMPLATE | 🟡 | Pre/post hooks |
| ComposioHQ/awesome-claude-plugins | PLUGINS | 🟡 | Kontrol edilmeli |
| lucide-icons/lucide | UI | 🟢 | Frontend ikon referansı |
