# /ai-kesfet — AI Araç Keşif Sistemi

GitHub, web ve Anthropic duyurularını tarayarak yeni Claude skill'leri, MCP'leri ve araçları keşfeder.
Bulguları `_agents/ai-research/REPO_CATALOG.md`'ye ekler, `/ai-upgrade`'e hazır hale getirir.

---

## Çalıştırma Akışı

`_agents/skills/ai-kesfet/SKILL.md` dosyasını oku ve oradaki akışı takip et.

Kısa özet:
1. **Tara** — GitHub, Anthropic blog, awesome listeleri, HN/Reddit
2. **Filtrele** — Zaten katalogda var mı? MMEpanel'e uygun mu?
3. **Değerlendir** — Her yeni bulgu için kategori + öncelik + uyum notu
4. **REPO_CATALOG.md'ye ekle** — Standart format, durum: `yeni`
5. **Özet sun** — Kaç yeni araç bulundu, en önemlisi hangisi

---

## Kaynak Dosyalar

- **Detaylı akış:** `_agents/skills/ai-kesfet/SKILL.md`
- **Repo kataloğu:** `_agents/ai-research/REPO_CATALOG.md`
- **Oturum logu:** `_agents/ai-research/SESSION_LOG.md`

---

## Mod Seçenekleri

**Argümansız:** Tam tarama — tüm kaynakları tara, tüm kategorileri ara  
**`mcp`:** Sadece yeni MCP'leri ara  
**`skill`:** Sadece yeni skill'leri ara  
**`haber`:** Anthropic duyuruları + Claude Code güncellemeleri  
**`hızlı`:** Sadece en aktif 3 kaynak (awesome-claude-skills, MCP servers, Anthropic blog)
