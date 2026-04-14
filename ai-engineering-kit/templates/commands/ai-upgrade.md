# /ai-upgrade — AI Agent Mühendislik Sistemi

Bu komut projedeki Claude AI ajan altyapısını analiz eder, repo kataloğundan
iyileştirme önerileri sunar, uygular ve her oturumu loglar.

---

## Çalıştırma Akışı

`_agents/skills/ai-upgrade/SKILL.md` dosyasını oku ve akışı uygula.

**Özet:**
1. Mevcut durumu ölç — aktif skill'ler, MCP'ler, hook'lar, önceki skor
2. Boşluk analizi — `_agents/ai-research/REPO_CATALOG.md`'den uygulanmamış iyileştirmeler
3. En fazla 3 öneri sun — onay bekle
4. Uygula + doğrula — kanıtsız "tamam" deme
5. `_agents/ai-research/SESSION_LOG.md`'ye kaydet

---

## Kaynak Dosyalar

- **Detaylı akış:** `_agents/skills/ai-upgrade/SKILL.md`
- **Repo kataloğu:** `_agents/ai-research/REPO_CATALOG.md`
- **Oturum logu:** `_agents/ai-research/SESSION_LOG.md`

---

## Modlar

**Argümansız:** Tam analiz akışını başlat.

**Repo ekleme:** Kullanıcı GitHub URL paylaşırsa → WebFetch ile README çek →
kategori + öncelik belirle → REPO_CATALOG.md'ye ekle.

**Sadece skor:** "skor" veya "durum" yazılırsa → SESSION_LOG'dan son skoru göster.
